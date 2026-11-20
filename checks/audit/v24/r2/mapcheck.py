"""Check item->product maps on spending (exp) and consumed against the new panel, track B (and A where B absent)."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24'); sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from common import *
from items import *
from maps import *
c=sys.argv[1]
pan=load_panel(c)
out=[]
for y in YEARS[c]:
    r=LOADERS[c](y); d=r[0] if isinstance(r,tuple) else r
    allhh=d.hhid.unique()
    d['exx']=d.ex.where(d.ex>0)
    pos=(d[[x for x in d.columns if x.startswith('q_')]].fillna(0)>0).any(axis=1)|(d.exx>0)
    d['consx']=np.where(pos,1.0,d.cons)
    mp=dict(MAPS[c])
    if c=='ETH' and y<=2013: mp={'milk':[19],'cheese':[20],'eggs':[21],'coffee':[24],'meat_agg':[18]}
    for prod,items in mp.items():
        if prod=='meat_agg_old': continue
        s=d[d.item.isin(items)]
        g=s.groupby('hhid'); e=g.exx.sum(min_count=1).reindex(allhh); cs=g.consx.max().reindex(allhh)
        tr='A' if (c=='ETH' and y<=2013) else 'B'
        P=pan[(pan.year==y)&(pan['product']==prod)&(pan.track==tr)].set_index('hhid')
        if len(P)==0: out.append(dict(year=y,product=prod,n=0)); continue
        j=P[['exp','consumed']].join(pd.DataFrame({'e':e,'cs':cs}),how='left')
        me=cmp(j.exp,j.e).mean(); mc=cmp(j.consumed,j.cs.fillna(0)).mean()
        out.append(dict(year=y,product=prod,n=len(P),exp_match=round(me,5),cons_match=round(mc,5),exp_mis=int((~cmp(j.exp,j.e)).sum())))
print(c); print(pd.DataFrame(out).to_string())
