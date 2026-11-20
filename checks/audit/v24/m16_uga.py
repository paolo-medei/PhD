import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
def nt(s): return (np.floor(5*(s.rank(method='first')-1)/len(s))+1).astype(int)
p=load_panel('UGA')
h=p.groupby(['hhid','year']).agg(welfare=('welfare','first'),w=('hhweight','first'),ae=('adulteq','first'),age=('head_age','first'),reg=('region','first')).reset_index()
f=p[(p['product']=='meat_agg')&(p.track=='A')]
for nm,hs in [('welfare',h[h.welfare.notna()]),('welfare+weight',h[h.welfare.notna()&h.w.notna()]),('welfare+ae+age',h.dropna(subset=['welfare','ae','age'])),('welfare+region',h.dropna(subset=['welfare','reg'])),('meat_agg rows only',h[h.welfare.notna()].merge(f[['hhid','year']],on=['hhid','year']))]:
    hs=hs.copy(); hs['Q']=hs.groupby('year').welfare.transform(nt)
    g=f.merge(hs[['hhid','year','Q']],on=['hhid','year'])
    ind=((g.exp>0)|(g.purch_std>0)).astype(float); ww=g.hhweight.fillna(0)
    print(nm,len(hs),(100*(ind*ww).groupby(g.Q).sum()/ww.groupby(g.Q).sum()).round(3).tolist())
