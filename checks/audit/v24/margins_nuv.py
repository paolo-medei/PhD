import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
M=pd.read_excel(X,sheet_name='MARGINS_01_three_margins')
pc={'TZA':'purch_std','UGA':'purch_std','MWI':'purch_std','NGA':'purch_kg','ETH':'purch_kg'}
for c in ['TZA','MWI','NGA','ETH','UGA']:
    p=load_panel(c); wc='hhweight' if 'hhweight' in p else 'weight'
    for prod in M[M.country==c]['product']:
        f=p[(p['product']==prod)&(p.track=='A')]
        s=f[f.welfare>0] if c=='NGA' else f[(f.welfare>0)].dropna(subset=['adulteq',wc,'region','head_age'])
        if c=='UGA': s=f[f.welfare>0].dropna(subset=['adulteq',wc,'region'])
        buy=(s.exp>0)|(s[pc[c]]>0)
        u=s.uv.where(buy&(s.uv>0))
        lu=np.log(u)
        med=lu.groupby(s.year).transform('median')
        r={}
        r['uv']=u.notna().sum()
        r['10x_year']=(u.notna()&((lu-med).abs()<np.log(10))).sum()
        sd=lu.groupby(s.year).transform('std'); mu=lu.groupby(s.year).transform('mean')
        r['3sd_year']=(u.notna()&((lu-mu).abs()<=3*sd)).sum()
        lo=u.groupby(s.year).transform(lambda x:x.quantile(.01)); hi=u.groupby(s.year).transform(lambda x:x.quantile(.99))
        r['p1p99_year']=(u.notna()&(u>=lo)&(u<=hi)).sum()
        r['full_conv']=(u.notna()&(s.unconv==0)).sum()
        r['qty_notna']=(u.notna()&s[[x for x in s.columns if x.startswith('qty')][0]].notna()).sum()
        mrow=M[(M.country==c)&(M['product']==prod)].iloc[0]
        print(c,prod,'n',len(s),mrow.n,'buyers',buy.sum(),mrow.n_buyers,'nuv_wb',mrow.n_unit_values,r)
