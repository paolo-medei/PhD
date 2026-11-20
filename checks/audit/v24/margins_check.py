import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
import itertools
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
M=pd.read_excel(X,sheet_name='MARGINS_01_three_margins')
out=[]
for c in ['TZA','UGA','MWI','NGA','ETH']:
    p=load_panel(c); wc='hhweight' if 'hhweight' in p else 'weight'
    adq='adulteq'
    for prod in M[M.country==c]['product']:
        tr='A'
        f=p[(p['product']==prod)&(p.track==tr)]
        base=f[(f.welfare>0 if 'welfare' in f else f.nom_totcons_aeq>0)]
        cand={'welfare>0':base}
        # try extra requirements
        for extra in [[adq],[adq,wc],[adq,wc,'region'],[adq,wc,'region','hhsize'],[adq,wc,'region','head_age'],[adq,wc,'region','share_child','share_elderly','head_age','head_female']]:
            ex=[e for e in extra if e in f]
            cand['+'.join(ex)]=base.dropna(subset=ex)
        mrow=M[(M.country==c)&(M['product']==prod)].iloc[0]
        best=None
        for k,s in cand.items():
            n=len(s); nb=(s.exp>0).sum(); nu=((s.exp>0)&s.uv.notna()).sum()
            P=np.average((s.exp>0),weights=s[wc])
            if n==mrow.n: best=(k,n,nb,nu,P); break
        if best is None:
            k,s='+'.join(ex),cand['+'.join(ex)]; best=(k+' (no exact n)',len(s),(s.exp>0).sum(),((s.exp>0)&s.uv.notna()).sum(),np.average((s.exp>0),weights=s[wc]))
        k,n,nb,nu,P=best
        out.append(dict(country=c,product=prod,sample=k,n_wb=mrow.n,n=n,nbuy_wb=mrow.n_buyers,nbuy=nb,nuv_wb=mrow.n_unit_values,nuv=nu,cov=nu/nb,P_wb=mrow.P,P=P,
                        has_qty=pd.notna(mrow.e_qty)))
O=pd.DataFrame(out); pd.set_option('display.width',250); print(O.round(5).to_string())
O.to_csv('margins_coverage_check.csv',index=False)
