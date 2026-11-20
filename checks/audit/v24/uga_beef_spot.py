"""Spot check of an M15 input: UGA beef (item 117) 2010-2015 rebuilt from raw with the same unit rule as fish."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
import rebuild_uga as U
pan=load_panel('UGA','beef','B').set_index('hhid')
out=[]
for y in [2010,2011,2013,2015]:
    d,cv,ul=U.load(y); allhh=d.hhid.unique()
    it=d[d.item==117].copy(); it['tq']=it['tq_sum_away']
    r=finish(aggregate(it,lambda u: cv.get(u,np.nan)),allhh)
    j=pan[pan.year==y].join(r,rsuffix='_r')
    for col,rc in [('exp','exp_r'),('exp_conv','exp_conv_r'),('purch_std','purch'),('unconv','unconv_r'),('qty_std','qty_any')]:
        mm=cmp(j[col],j[rc]); out.append(dict(year=y,col=col,match=round(mm.mean(),5),nmis=int((~mm).sum())))
        if (~mm).sum(): print(y,col,j.loc[~mm,[col,rc]].head(3).to_string())
print(pd.DataFrame(out).to_string())
