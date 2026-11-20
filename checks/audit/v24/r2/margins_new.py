import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-20_20-36/RESULTS_2026-11-20_20-36.xlsx'
M=pd.read_excel(X,sheet_name='MARGINS_01_three_margins')
pc={'TZA':'purch_std','UGA':'purch_std','MWI':'purch_std','NGA':'purch_kg','ETH':'purch_kg'}
rows=[]
for c in ['TZA','MWI','NGA','ETH','UGA']:
    p=load_panel(c); wc='hhweight' if 'hhweight' in p else 'weight'
    if c=='ETH': p['welfare']=p['nom_totcons_aeq']
    for prod in M[M.country==c]['product']:
        f=p[(p['product']==prod)&(p.track=='A')]
        if c=='NGA': s=f[f.welfare>0]
        elif c=='UGA': s=f[f.welfare>0].dropna(subset=['adulteq','head_age'])
        else: s=f[(f.welfare>0)].dropna(subset=['adulteq',wc,'region','head_age'])
        buy=(s.exp>0)|(s[pc[c]]>0)
        res={}
        for nm,cond in [('uv',buy&(s.uv>0)),('uv_fullconv',buy&(s.uv>0)&(s.unconv==0))]:
            u=s.uv.where(cond)
            lo=u.groupby(s.year).transform(lambda x:x.quantile(.01)); hi=u.groupby(s.year).transform(lambda x:x.quantile(.99))
            res[nm]=int(u.notna().sum()); res[nm+'_trim']=int((u.notna()&(u>=lo)&(u<=hi)).sum())
        mrow=M[(M.country==c)&(M['product']==prod)].iloc[0]
        rows.append(dict(country=c,product=prod,n_wb=mrow.n,n=len(s),buyers_wb=mrow.n_buyers,buyers=int(buy.sum()),nuv_wb=mrow.n_unit_values,**res,
             cov_wb=mrow.n_unit_values/mrow.n_buyers,cov_uv_any=res['uv']/buy.sum(),P_wb=mrow.P,P=np.average(buy,weights=s[wc].fillna(0)),qty_reported=pd.notna(mrow.e_qty)))
R=pd.DataFrame(rows); pd.set_option('display.width',250); print(R.round(4).to_string()); R.to_csv('r2/margins_coverage_check_new.csv',index=False)
