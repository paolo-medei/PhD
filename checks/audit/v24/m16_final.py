"""M16: quintiles assigned once per household-year (dplyr::ntile-style equal-count fifths, unweighted, within year, among households with welfare),
joined to all rows; participation table = weighted share buying (exp>0 or purchased qty>0), track A, pooled years.
Two averaging samples are compared: (a) all rows with a quintile, (b) the estimation sample used in MARGINS_01."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
def nt(s): return (np.floor(5*(s.rank(method='first')-1)/len(s))+1).astype(int)
def qb(s): return (pd.cut(s,bins=np.quantile(s,[0,.2,.4,.6,.8,1]),labels=False,include_lowest=True)+1).astype(int)
METHOD=sys.argv[1] if len(sys.argv)>1 else 'ntile'
rows=[]
for c in ['TZA','UGA','MWI','NGA','ETH']:
    p=load_panel(c)
    if c=='ETH': p['welfare']=p['nom_totcons_aeq']
    if 'head_age' not in p: p['head_age']=0
    wc='hhweight' if 'hhweight' in p else 'weight'
    h=p.groupby(['hhid','year']).agg(welfare=('welfare','first')).reset_index(); h=h[h.welfare.notna()].copy()
    h['Q']=h.groupby('year').welfare.transform(nt if METHOD=='ntile' else qb)
    sizes=h.groupby(['year','Q']).size().unstack(); print(c,METHOD,'households per quintile (min/max over years):',int(sizes.min().min()),int(sizes.max().max()), 'max within-year imbalance',int((sizes.max(axis=1)-sizes.min(axis=1)).max()))
    J=p.merge(h[['hhid','year','Q']],on=['hhid','year'],how='left')
    nq=J.groupby(['hhid','year']).Q.nunique()
    two=int((nq>1).sum())
    wb=pd.read_excel(X,sheet_name=f'{c}_14_participation_quintile').set_index('product')
    pc='purch_std' if 'purch_std' in p else 'purch_kg'
    for prod in wb.index:
        f=J[(J['product']==prod)&(J.track=='A')&J.Q.notna()]
        if c=='NGA': est=f[f.welfare>0]
        elif c=='UGA': est=f[f.welfare>0].dropna(subset=['adulteq','head_age'])
        else: est=f[f.welfare>0].dropna(subset=['adulteq',wc,'region','head_age'])
        out={}
        for nm,g in [('all',f),('est',est)]:
            ind=((g.exp>0)|(g[pc]>0)).astype(float); ww=g[wc].fillna(0)
            out[nm]=(100*(ind*ww).groupby(g.Q).sum()/ww.groupby(g.Q).sum()).round(1).tolist()
        w=wb.loc[prod,['Q1','Q2','Q3','Q4','Q5']].astype(float).tolist()
        rows.append(dict(country=c,product=prod,hh_years_in_two_quintiles=two,workbook=w,rebuilt_all=out['all'],rebuilt_est=out['est'],
            maxdiff_all=round(max(abs(a-b) for a,b in zip(w,out['all'])),2),maxdiff_est=round(max(abs(a-b) for a,b in zip(w,out['est'])),2)))
R=pd.DataFrame(rows); pd.set_option('display.width',300); pd.set_option('display.max_colwidth',40); print(R.to_string()); R.to_csv(f'm16_participation_quintile_check_{METHOD}.csv',index=False)
