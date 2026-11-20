"""(e) cost per gram of protein from the new panels; rule of spec 4 (= round-1 rule)."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
import m15_cost_per_gram as M
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-20_20-36/RESULTS_2026-11-20_20-36.xlsx'
orig=M.prot_per_unit
rows=[]
for c in ['ETH','TZA','NGA','UGA','MWI']:
    h=M.build(c); b,se,pv,n=M.reg(h)
    wb=pd.read_excel(X,sheet_name=f'{c}_22_four_margins'); v=wb.loc[wb['product'].str.startswith('COST'),'e_quantity_ae'].iloc[0]
    rows.append(dict(country=c,elasticity=round(b,4),se=round(se,4),n_hh=n,workbook=v,match_3dp=round(b,3)==round(v,3)))
R=pd.DataFrame(rows); print(R.to_string())
R.to_csv('/home/claude/phd/checks/audit/v24/r2/m15_new_check.csv',index=False)
