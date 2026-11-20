import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
import m15_cost_per_gram as M
from common import *
# ETH variants
p=load_panel('ETH','eggs','B'); print('ETH eggs purch_kg quantiles',p.purch_kg.quantile([.1,.5,.9]).to_dict(), 'uv median',p.uv.median())
p=load_panel('MWI','eggs','B'); print('MWI eggs purch quantiles',p.purch_std.quantile([.1,.5,.9]).to_dict())
orig=M.prot_per_unit
def run(c,f,label,wel=None):
    M.prot_per_unit=f
    h=M.build(c)
    if wel is not None:
        pp=load_panel(c,'beef','B').groupby(['hhid','year'])[wel].first()
        h=h.set_index(['hhid','year']); h['welfare']=pp; h=h.reset_index()
    print(c,label,[round(x,4) if isinstance(x,float) else x for x in M.reg(h)])
    M.prot_per_unit=orig
run('ETH',lambda c,a,s: orig(c,a,'kg') ,'eggs in kg (126 g/kg)')
run('ETH',lambda c,a,s: orig(c,a,'piece'),'eggs as pieces')
run('ETH',lambda c,a,s: orig(c,a,'kg'),'eggs kg, welfare=total_cons_ann','total_cons_ann')
run('MWI',lambda c,a,s: 33 if a=='milk_processed' else orig(c,a,s),'milk_processed 33')
run('MWI',lambda c,a,s: orig(c,a,s),'base')
import m15_cost_per_gram as MM
MM.PROT=dict(MM.PROT)
run('MWI',lambda c,a,s: np.nan if a=='milk_processed' else orig(c,a,s),'MWI without milk_processed')
run('ETH',lambda c,a,s: np.nan if a=='cheese' else orig(c,a,'kg'),'ETH eggs kg, no cheese')
run('ETH',lambda c,a,s: 33 if a=='cheese' else orig(c,a,'kg'),'ETH eggs kg, cheese 33')
