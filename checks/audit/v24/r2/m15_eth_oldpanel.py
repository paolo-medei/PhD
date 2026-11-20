"""ETH cost-per-gram: search the reading that gives the workbook's 0.221."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
import m15_cost_per_gram as M
from common import *
p=pd.read_csv("/home/claude/work/v24/data/OUTPUT_run4_traced/panel_ETH.csv",dtype={"hhid":str},low_memory=False)
PROT={'beef':260,'goat_sheep':250,'pork':250,'poultry':270,'cheese':200,'milk':33,'eggs':126,'milk_processed':250}
def hh(rows, prot):
    q=rows[rows['product'].isin(prot)].copy(); q['ppu']=q['product'].map(prot)
    ok=(q.exp_conv>0)&(q.purch_kg>0)
    q['num']=q.exp_conv.where(ok,0); q['den']=(q.purch_kg*q.ppu).where(ok,0)
    h=q.groupby(['hhid','year']).agg(num=('num','sum'),den=('den','sum'),welfare=('nom_totcons_aeq','first'),adulteq=('adulteq','first'),w=('weight','first'),region=('region','first')).reset_index()
    h['cpg']=h.num/h.den; return h
V={'B only':p[p.track=='B'],'A+B all rows':p,'B + A(2011/13)':pd.concat([p[p.track=='B'],p[(p.track=='A')&p.year.isin([2011,2013])]]),
   'A only':p[p.track=='A']}
for nm,rows in V.items():
    for pn,pr in [('eggs126',PROT),('eggs6.9',{**PROT,'eggs':6.9}),('meat_agg260',{**PROT,'meat_agg':260})]:
        h=hh(rows,pr); b,se,pv,n=M.reg(h); print(f'{nm:16s} {pn:12s} {b:.4f} n={n}')
print('--- variants on B only, eggs 126 g/kg')
import statsmodels.api as sm
base=hh(p[p.track=='B'],PROT)
ex=p[p.track=='B'].groupby(['hhid','year']).agg(tca=('total_cons_ann','first'),zone=('zone','first'),hs=('hh_size','first'),urb=('urban_code','first')).reset_index()
h=base.merge(ex,on=['hhid','year'])
def reg2(s,wel='welfare',fe='region',w=True,ae='adulteq'):
    s=s[(s.cpg>0)&np.isfinite(s.cpg)&(s[wel]>0)&(s[ae]>0)&s.w.notna()&s[fe].notna()].copy()
    s['ry']=s[fe].astype(str)+'_'+s.year.astype(str)
    X=pd.get_dummies(s.ry,drop_first=True,dtype=float); X['lw']=np.log(s[wel]); X['lae']=np.log(s[ae]); X=sm.add_constant(X)
    m=(sm.WLS(np.log(s.cpg),X,weights=s.w) if w else sm.OLS(np.log(s.cpg),X)).fit()
    return round(m.params['lw'],4), len(s)
print('base',reg2(h)); print('total_cons_ann',reg2(h,'tca')); print('zone FE',reg2(h,fe='zone')); print('unweighted',reg2(h,w=False)); print('hh_size',reg2(h,ae='hs'))
for drop in ['cheese','milk','eggs','poultry','goat_sheep','beef']:
    pr={k:v for k,v in PROT.items() if k!=drop}; print('without',drop,reg2(hh(p[p.track=='B'],pr)))
for ch in [33,250,300]:
    print('cheese',ch,reg2(hh(p[p.track=='B'],{**PROT,'cheese':ch})))
print('--- welfare definitions')
print('nom_totcons_aeq vs total_cons_ann/adulteq: median ratio', (h.welfare/(h.tca/h.adulteq)).median(), ' share equal', np.isclose(h.welfare,h.tca/h.adulteq,rtol=1e-3).mean())
h['w_tca_ae']=h.tca/h.adulteq; h['w_tca_hs']=h.tca/h.hs
print('tca/adulteq',reg2(h,'w_tca_ae')); print('tca/hh_size',reg2(h,'w_tca_hs')); print('tca/hh_size, ae=hh_size',reg2(h,'w_tca_hs',ae='hs'))
