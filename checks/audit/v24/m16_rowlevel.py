"""Counterfactual: quintiles assigned on the long file (one per row, all products/tracks) vs once per household-year; compare all _14 tables."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
def nt(s): return (np.floor(5*(s.rank(method='first')-1)/len(s))+1).astype(int)
rows=[]
for c in ['TZA','UGA','MWI','NGA','ETH']:
    p=load_panel(c)
    if c=='ETH': p['welfare']=p['nom_totcons_aeq']
    wc='hhweight' if 'hhweight' in p else 'weight'; pc='purch_std' if 'purch_std' in p else 'purch_kg'
    p=p[p.welfare.notna()].copy()
    p['Qrow']=p.groupby('year').welfare.transform(nt)
    h=p.groupby(['hhid','year']).welfare.first().reset_index(); h['Qhh']=h.groupby('year').welfare.transform(nt)
    p=p.merge(h[['hhid','year','Qhh']],on=['hhid','year'])
    two=int((p.groupby(['hhid','year']).Qrow.nunique()>1).sum())
    wb=pd.read_excel(X,sheet_name=f'{c}_14_participation_quintile').set_index('product')
    for prod in wb.index:
        f=p[(p['product']==prod)&(p.track=='A')]
        ind=((f.exp>0)|(f[pc]>0)).astype(float); ww=f[wc].fillna(0)
        w=wb.loc[prod,['Q1','Q2','Q3','Q4','Q5']].astype(float).values
        r={}
        for q in ['Qrow','Qhh']:
            v=(100*(ind*ww).groupby(f[q]).sum()/ww.groupby(f[q]).sum()).values
            r[q]=v; r[q+'_exact']=int((np.round(v,1)==w).sum())
        rows.append(dict(country=c,product=prod,hhyears_split_by_rowlevel=two,cells_exact_rowlevel=r['Qrow_exact'],cells_exact_hhlevel=r['Qhh_exact'],
                         rowlevel=np.round(r['Qrow'],3).tolist(),hhlevel=np.round(r['Qhh'],3).tolist(),workbook=w.tolist()))
R=pd.DataFrame(rows); pd.set_option('display.width',300); pd.set_option('display.max_colwidth',45); print(R.to_string())
print('total exact cells: row-level',R.cells_exact_rowlevel.sum(),' household-level',R.cells_exact_hhlevel.sum(),' of',5*len(R))
R.to_csv('m16_rowlevel_vs_hhlevel.csv',index=False)
