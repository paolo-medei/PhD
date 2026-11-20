import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
MODE='ntile'
def quint(h):
    # unweighted equal-count fifths within year, ranked by welfare
    if MODE=='qcut': return h.groupby('year')['welfare'].transform(lambda s: pd.qcut(s.rank(method='first'),5,labels=[1,2,3,4,5]).astype(int))
    # dplyr::ntile-style: bucket = floor(5*(row_number-1)/n)+1
    return h.groupby('year')['welfare'].transform(lambda s: (np.floor(5*(s.rank(method='first')-1)/len(s))+1).astype(int))
rows=[]
for c in ['TZA','UGA','MWI','NGA','ETH']:
    p=load_panel(c)
    if c=='ETH': p['welfare']=p['nom_totcons_aeq']
    wc='hhweight' if 'hhweight' in p else 'weight'
    # household-year table
    if 'head_age' not in p: p['head_age']=0
    rows_per=p.groupby(['hhid','year']).size()
    h=p.groupby(['hhid','year']).agg(welfare=('welfare','first'),w=(wc,'first'),nwel=('welfare','nunique'),ae=('adulteq','first'),age=('head_age','first'),reg=('region','first')).reset_index()
    print(c,'rows per hh-year: min',rows_per.min(),'max',rows_per.max(),' hh-years with >1 distinct welfare value:',int((h.nwel>1).sum()))
    # estimation sample (same as MARGINS_01): welfare>0 with adult-equivalents and head age (TZA/MWI/ETH also weight+region; NGA welfare only)
    if c=='NGA': hv=h[h.welfare>0].copy()
    elif c=='UGA': hv=h[h.welfare>0].dropna(subset=['ae','age']).copy()
    else: hv=h[h.welfare>0].dropna(subset=['ae','w','reg','age']).copy()
    print(c,'households-years in quintile sample',len(hv),'of',len(h))
    hv['Q']=quint(hv)
    wb=pd.read_excel(X,sheet_name=f'{c}_14_participation_quintile').set_index('product')
    # also: row-level assignment (quintile computed on the long file) to show what would differ
    for prod in wb.index:
        f=p[(p['product']==prod)&(p.track=='A')].merge(hv[['hhid','year','Q']],on=['hhid','year'],how='inner')
        pc='purch_std' if 'purch_std' in f else 'purch_kg'
        res={}
        for nm,ind in [('consumed',f.consumed.fillna(0)),('buys',((f.exp>0)|(f[pc]>0)).astype(float))]:
            for wn in ['w','unw']:
                if wn=='w':
                    ww=f[wc].fillna(0); v=(ind*ww).groupby(f.Q).sum()/ww.groupby(f.Q).sum()
                else: v=ind.groupby(f.Q).mean()
                res[(nm,wn)]=(100*v).round(1)
        best=[k for k,v in res.items() if np.allclose(v.values,wb.loc[prod,['Q1','Q2','Q3','Q4','Q5']].values.astype(float),atol=0.051)]
        rows.append(dict(country=c,product=prod,workbook=wb.loc[prod].tolist(),rebuilt_consumed_w=res[('consumed','w')].tolist(),rebuilt_buys_w=res[('buys','w')].tolist(),rebuilt_consumed_unw=res[('consumed','unw')].tolist(),matching_definitions=best))
R=pd.DataFrame(rows); pd.set_option('display.width',300); pd.set_option('display.max_colwidth',60); print(R.to_string()); R.to_csv('m16_participation_quintile_check.csv',index=False)
print('max abs diff per row:'); print(pd.DataFrame({'c':R.country,'p':R['product'],'maxdiff':[max(abs(a-b) for a,b in zip(x,y)) for x,y in zip(R.workbook,R.rebuilt_buys_w)]}).to_string())
