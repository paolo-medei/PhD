import pandas as pd, numpy as np
new=pd.read_csv('/home/claude/work/cI/data/OUTPUT/panel_NGA.csv',dtype={'hhid':str,'clusterid':str})
old=pd.read_csv('/home/claude/work/cE/data/OUTPUT/panel_NGA.csv',dtype={'hhid':str,'clusterid':str})
K=['wave','hhid','product','track']
m=old.merge(new,on=K,suffixes=('_o','_n'))
print('rows', len(new), len(m))
# which columns/waves/products changed old->new
for c in [c for c in new.columns if c not in K]:
    a=m[c+'_o']; b=m[c+'_n']
    if not (pd.api.types.is_numeric_dtype(a) and pd.api.types.is_numeric_dtype(b)): d=a.astype(str)!=b.astype(str)
    else: d=~((a.isna()&b.isna())|np.isclose(a.fillna(-1e9),b.fillna(-1e9),rtol=1e-4))
    if d.sum(): print(c, m[d].groupby(['wave','product']).size().to_dict())
B=new[(new.track=='B')|(new['product']=='meat_agg')]
print('(1) W2 eggs median uv', B[(B.wave=='w2')&(B['product']=='eggs')].uv.median(), ' W2 milk_processed', B[(B.wave=='w2')&(B['product']=='milk_processed')].uv.median())
print('(2) W1 milk_processed consumers', B[(B.wave=='w1')&(B['product']=='milk_processed')].consumed.sum())
print('(3) hh100132', new[(new.wave=='w2')&(new.hhid=='100132')&(new['product']=='milk_processed')][['track','exp','exp_conv','purch_kg','unconv','uv']].to_dict('records'))
print('    any exp_conv notna with purch_kg NA:', (new.exp_conv.notna()&new.purch_kg.isna()).sum())
it=pd.read_pickle('items_conv.pkl')
cont=it[(it.wave=='w1')&it['item'].isin([80,82,83,84,90,91,92,93,100,101,102,103,110,111,113,114,120])&(it.consumed==1)&it.up.notna()&~it.up.isin([1,2,3,4])&(it.qp>0)]
print('(4) W1 item rows with purchase in container unit', len(cont), '; W1 unconv=1 rows (B+meat_agg)', B[(B.wave=='w1')].unconv.sum(), ' W1 fish mean purch_kg', round(B[(B.wave=='w1')&(B['product']=='fish')].purch_kg.mean(),2), ' W1 beef p1 uv', B[(B.wave=='w1')&(B['product']=='beef')].uv.quantile(.01))
for w,g in new.drop_duplicates(['wave','hhid']).groupby('wave'):
    print('(5)',w,'clusterid n', g.clusterid.nunique(), '(state,lga,ea) n', g.groupby(['state','lga','ea']).ngroups, 'format ok', (g.clusterid==g.state.astype(str)+'_'+g.lga.astype(str)+'_'+g.ea.astype(str)).all())
