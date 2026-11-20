"""MWI: item purchase rows whose unit key is unconvertible in the revealed table but has an official IHS factor; would they be screened?"""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from build import *
T=pd.read_pickle('/home/claude/phd/checks/audit/v24/r2/mwi_factors_learned.pkl')
cf,_=pyreadstat.read_dta(B+'MWI_2019_IHS-V_v06_M_Stata/ihs_foodconversion_factor_2020.dta')
cf['Otherunit']=cf.Otherunit.astype(str).str.strip().str.upper(); cf['unit_code']=cf.unit_code.astype(str).str.strip()
CF={(int(i),u,o if u=='23' else '',str(int(r))):f for i,u,o,r,f in zip(cf.item_code,cf.unit_code,cf.Otherunit,cf.region,cf.factor)}
for y in [2010,2016,2019,2024]:
    P,counts,d2=build('MWI',y,screen=True,do_m17=False,extra_tab=T[y])
    d=d2.copy(); d['region']=d.hhid.str[0]
    d['u']=d.u_p.astype(str).str.replace(r'[A-Z]$','',regex=True)
    cand=d[(d.ex>0)&(d.q_p>0)&d.f_p.isna()].copy()
    cand['cf']=[CF.get((int(i),u,str(x).strip().upper() if u=='23' else '',r),np.nan) for i,u,x,r in zip(cand.item,cand.u_p.astype(str),cand.x_p,cand.region)]
    cand=cand[cand.cf.notna()]
    med=d.assign(pr=np.where((d.ex>0)&(d.c_p>0),d.ex/d.c_p,np.nan)).groupby('product').pr.median()
    cand['price']=cand.ex/(cand.q_p*cand.cf); cand['ratio']=cand.price/cand['product'].map(med)
    print(y, len(cand), 'with official factor; flagged by screen:', int(((cand.ratio>10)|(cand.ratio<0.1)).sum()))
    nf=cand[cand['product']!='fish']
    print('   non-fish candidates flagged:', int(((nf.ratio>10)|(nf.ratio<0.1)).sum()), nf[(nf.ratio>10)|(nf.ratio<0.1)][['product','item','u_p','x_p','region','q_p','ex','cf','ratio']].round(3).to_string(index=False))
    # are these keys ever converted elsewhere in the panel (learned table)?

