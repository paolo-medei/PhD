"""MWI: the unit factors are not part of this round's spec (IHS conversion tables, region-specific, plus other-specify parsing).
They are revealed from the OLD panel (run4_traced, which already applied the old Malawi screen):
implied factor = panel quantity / raw quantity, from households with one item row in the product, for each source.
Key = (year, product, item, unit code, other-specify text, region). Returned as a dict per year."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24'); sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from build import *
SRC={'t':'qty_std','p':'purch_std','o':'own_std','g':'gift_std'}
def norm(x): return str(x).strip().upper()
def learn(which='old'):
    path=('/home/claude/work/v24/data/OUTPUT_run4_traced/' if which=='old' else OUT)+'panel_MWI.csv'
    pan=pd.read_csv(path,dtype={'hhid':str},low_memory=False); pan=pan[pan.track=='B']
    tabs={}
    for y in YEARS['MWI']:
        d=load_mwi(y); i2p={i:p for p,its in MAPS['MWI'].items() for i in its}
        d=d[d.item.isin(i2p)].copy(); d['product']=d.item.map(i2p); d['region']=d.hhid.str[0]
        P=pan[pan.year==y].set_index(['hhid','product'])
        recs=[]
        for k,col in SRC.items():
            s=d[d['q_'+k]>0]
            n=s.groupby(['hhid','product']).size()
            one=n[n==1].index
            s=s.set_index(['hhid','product']).loc[lambda x: x.index.isin(one)]
            v=P[col].reindex(s.index)
            f=(v.values/s['q_'+k].values)
            recs.append(pd.DataFrame({'product':s.index.get_level_values(1),'item':s.item.values,'u':s['u_'+k].astype(str).values,
                                      'x':s['x_'+k].map(norm).values,'region':s.region.values,'f':np.round(f,9)}))
        R=pd.concat(recs)
        g=R.groupby(['product','item','u','x','region']).f
        t=g.agg(lambda s: s.dropna().mode().iloc[0] if s.notna().any() else np.nan)
        tabs[y]={k:v for k,v in t.items()}
    return tabs
if __name__=='__main__':
    T=learn('old'); pd.to_pickle(T,'/home/claude/phd/checks/audit/v24/r2/mwi_factors_learned.pkl')
    print({y:(len(t),sum(pd.notna(v) for v in t.values())) for y,t in T.items()})
