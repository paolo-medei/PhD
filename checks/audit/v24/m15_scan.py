import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
import m15_cost_per_gram as M
from common import *
orig=M.prot_per_unit
for f in [33,60,100,150,200,250]:
    M.prot_per_unit=lambda c,a,s,f=f: f if a=='milk_processed' else orig(c,a,s)
    print('MWI milk_processed',f,round(M.reg(M.build('MWI'))[0],5))
M.prot_per_unit=lambda c,a,s: orig(c,a,'kg')
h=M.build('ETH')
import statsmodels.api as sm
p=load_panel('ETH','beef','B').groupby(['hhid','year']).agg(zone=('zone','first'),urban=('urban_code','first'),hh_size=('hh_size','first')).reset_index()
h=h.merge(p,on=['hhid','year'])
for nm,s in [('base',h),('w>0',h[h.w>0])]:
    print('ETH',nm,[round(x,4) for x in M.reg(s)[:2]])
s=h[(h.cpg>0)&(h.welfare>0)&(h.adulteq>0)].copy()
for fe in ['region','zone']:
    s['ry']=s[fe].astype(str)+'_'+s.year.astype(str)
    Xm=pd.get_dummies(s.ry,drop_first=True,dtype=float); Xm['lw']=np.log(s.welfare); Xm['lae']=np.log(s.adulteq); Xm=sm.add_constant(Xm)
    for wn,w in [('w',s.w),('unw',None)]:
        m=(sm.WLS(np.log(s.cpg),Xm,weights=w) if w is not None else sm.OLS(np.log(s.cpg),Xm)).fit()
        print('ETH FE',fe,wn,round(m.params['lw'],4))
    Xm['lae']=np.log(s.hh_size)
    m=sm.WLS(np.log(s.cpg),Xm,weights=s.w).fit(); print('ETH FE',fe,'log hh_size instead of adulteq',round(m.params['lw'],4))
