"""Diff old (run4_traced) vs new panels: rows changed by column, per country-year-product-track (counts only)."""
import pandas as pd, numpy as np, sys
O='/home/claude/work/v24/data/OUTPUT_run4_traced/'; N='/home/claude/work/v24/data/OUTPUT/'
res=[]
for c in ['ETH','TZA','NGA','UGA','MWI']:
    a=pd.read_csv(O+f'panel_{c}.csv',dtype={'hhid':str},low_memory=False); b=pd.read_csv(N+f'panel_{c}.csv',dtype={'hhid':str},low_memory=False)
    k=['hhid','year','product','track']
    print(c,len(a),len(b),list(a.columns)==list(b.columns), set(b.columns)-set(a.columns), set(a.columns)-set(b.columns))
    m=a.merge(b,on=k,how='outer',suffixes=('_o','_n'),indicator=True)
    print('  merge',m._merge.value_counts().to_dict())
    cols=[x for x in a.columns if x not in k and x in b.columns]
    for col in cols:
        x=m[col+'_o']; y=m[col+'_n']
        if not (pd.api.types.is_numeric_dtype(x) and pd.api.types.is_numeric_dtype(y)): d=~((x.astype(str)==y.astype(str)))
        else: d=~((x.isna()&y.isna())|np.isclose(x.astype(float),y.astype(float),rtol=1e-9,atol=0))
        if d.sum(): 
            g=m[d].groupby(['year','product','track']).size()
            res.append(pd.DataFrame({'country':c,'col':col,'n':g}).reset_index())
            print('  ',col,int(d.sum()))
R=pd.concat(res); R.to_csv('/home/claude/phd/checks/audit/v24/r2/diff_old_new_counts.csv',index=False)
