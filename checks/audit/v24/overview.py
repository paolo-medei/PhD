import pandas as pd
D='/home/claude/work/v24/data/OUTPUT/'
for c in ['ETH','TZA','NGA','UGA','MWI']:
    p=pd.read_csv(D+f'panel_{c}.csv',dtype={'hhid':str},low_memory=False)
    print('==',c,p.shape)
    print(p.groupby(['year','track']).size().unstack())
    print(sorted(p['product'].unique()))
    f=p[p['product']=='fish']
    print(f.groupby(['year','track']).agg(n=('hhid','size'),cons=('consumed','mean'),buy=('exp',lambda s:(s>0).mean()),unconv=('unconv','mean')))
    if 'std' in p: print(f.groupby('year')['std'].unique())
