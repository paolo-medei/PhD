import sys, itertools; sys.path.insert(0,'/home/claude/phd/checks/audit/v24'); sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from common import *; from items import *
c,prod,years,cands=sys.argv[1],sys.argv[2],[int(x) for x in sys.argv[3].split(',')],[int(x) for x in sys.argv[4].split(',')]
pan=load_panel(c,prod,'B')
for y in years:
    r=LOADERS[c](y); d=r[0] if isinstance(r,tuple) else r
    d['exx']=d.ex.where(d.ex>0); P=pan[pan.year==y].set_index('hhid')
    best=[]
    for k in range(1,len(cands)+1):
        for s in itertools.combinations(cands,k):
            e=d[d.item.isin(s)].groupby('hhid').exx.sum(min_count=1).reindex(P.index)
            best.append((cmp(P.exp,e).mean(),s))
    best.sort(reverse=True); print(c,prod,y,best[:3])
