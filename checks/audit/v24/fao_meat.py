import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
J=pd.read_pickle('fao_join.pkl')
pd.set_option('display.width',300)
P=J[J._merge=='both']
print(P[P['product'].isin(['beef','goat_sheep','pork','poultry'])].pivot_table(index=['country','year'],columns='product',values='coverage').round(2).to_string())
M=J[J['product']=='meat'][['country','year','kg_raw_wb','kg_trim100_wb','n_trimmed_wb','coverage','meats_included','fao_kg_wb','ratio_lsms_fao']]
out=[]
for _,r in M.iterrows():
    inc=r.meats_included.split('+')
    s=P[(P.country==r.country)&(P.year==r.year)&(P['product'].isin(inc))]
    out.append(dict(country=r.country,year=r.year,inc=r.meats_included,kg_raw=round(s.kg_raw.sum(),2),kg_raw_wb=r.kg_raw_wb,kg_trim=round(s.kg_trim100.sum(),2),kg_trim_wb=r.kg_trim100_wb,
        ntrim=s.n_trimmed.sum(),ntrim_wb=r.n_trimmed_wb,fao=round(s.fao_kg.sum(),2),fao_wb=r.fao_kg_wb,cov_wb=r.coverage,ratio_wb=r.ratio_lsms_fao,ratio=round(s.kg_trim100.sum()/s.fao_kg.sum(),2)))
O=pd.DataFrame(out); print(O.to_string())
