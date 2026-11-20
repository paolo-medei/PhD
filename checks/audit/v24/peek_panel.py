import pandas as pd,sys
c=sys.argv[1]
p=pd.read_csv(f'/home/claude/work/v24/data/OUTPUT/panel_{c}.csv',dtype={'hhid':str},low_memory=False)
f=p[(p['product']=='fish')&(p.track=='B')]
for y,g in f.groupby('year'):
    print(y, g.hhid.str.len().value_counts().to_dict(), g.hhid.head(3).tolist(), g.hhid.nunique(), len(g))
    print(g[g.consumed==1].head(5).to_string())
print(f.describe().T.to_string())
print(f.unconv.value_counts(dropna=False))
print(pd.crosstab(f.consumed, f.unconv.fillna(-1)))
