import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
import statsmodels.api as sm
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
PROT={'beef':260,'goat_sheep':250,'pork':250,'poultry':270,'cheese':200}
def prot_per_unit(c,prod,std):
    if prod in PROT: return PROT[prod]
    if prod=='eggs': return 6.9 if std=='piece' else 126
    if prod=='milk': return 33
    if prod=='milk_processed': return 33 if std=='litre' else 250
    return np.nan
def build(c, variant='base'):
    p=load_panel(c,track='B')
    pc='purch_std' if 'purch_std' in p else 'purch_kg'
    if 'std' not in p: p['std']=np.where(p['product']=='eggs','piece','kg')  # ETH: no std column (assumption)
    p=p[p['product'].isin(['beef','goat_sheep','pork','poultry','eggs','milk','milk_processed','cheese'])].copy()
    p['ppu']=[prot_per_unit(c,a,b) for a,b in zip(p['product'],p['std'])]
    ok=p.exp_conv.notna()&(p.exp_conv>0)&(p[pc]>0)
    if variant=='uv_based': ok=ok&p.uv.notna()
    p['num']=p.exp_conv.where(ok,0); p['den']=(p[pc]*p.ppu).where(ok,0)
    wc='hhweight' if 'hhweight' in p else 'weight'; wel='welfare' if 'welfare' in p else 'nom_totcons_aeq'
    h=p.groupby(['hhid','year']).agg(num=('num','sum'),den=('den','sum'),welfare=(wel,'first'),adulteq=('adulteq','first'),w=(wc,'first'),region=('region','first')).reset_index()
    h['cpg']=h.num/h.den
    return h
def reg(h):
    s=h[(h.cpg>0)&np.isfinite(h.cpg)&(h.welfare>0)&(h.adulteq>0)&h.w.notna()&h.region.notna()].copy()
    s['ry']=s.region.astype(str)+'_'+s.year.astype(str)
    Xm=pd.get_dummies(s.ry,drop_first=True,dtype=float)
    Xm['lw']=np.log(s.welfare); Xm['lae']=np.log(s.adulteq); Xm=sm.add_constant(Xm)
    m=sm.WLS(np.log(s.cpg),Xm,weights=s.w).fit(cov_type='HC1')
    return m.params['lw'], m.bse['lw'], m.pvalues['lw'], len(s)
def main():
  rows=[]
  for c in ['TZA','UGA','MWI','NGA','ETH']:
    h=build(c)
    b,se,pv,n=reg(h)
    wb=pd.read_excel(X,sheet_name=f'{c}_22_four_margins'); v=wb.loc[wb['product'].str.startswith('COST'),'e_quantity_ae'].iloc[0]
    rows.append(dict(country=c,n_hh_positive_cost=n,elasticity=round(b,4),se=round(se,4),p=pv,workbook=v,median_cpg=h.cpg[h.cpg>0].median()))
    h.to_pickle(f'/home/claude/phd/checks/audit/v24/m15_{c}.pkl')
  R=pd.DataFrame(rows); print(R.to_string()); R.to_csv('m15_cost_per_gram_check.csv',index=False)
if __name__=='__main__': main()
