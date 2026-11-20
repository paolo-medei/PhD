import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
files={2010:'UGA_2010_UNPS_v03_M_STATA12/GSEC15b.dta',2011:'UGA_2011_UNPS_v02_M_Stata/GSEC15B.dta',2013:'UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC15B.dta',
2015:'UGA_2015_UNPS_v02_M_STATA14/household/gsec15b.dta',2018:'UGA_2018_UNPS_v02_M_STATA14/HH/GSEC15B.dta',2019:'UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec15b.dta'}
for y,f in files.items():
    df,m=pyreadstat.read_dta(B+f)
    print('=====',y,df.shape,list(df.columns))
    itv=[c for c in df.columns if c.lower() in('itmcd','ceb01')][0]
    uv=[c for c in df.columns if c.lower() in ('untcd','ceb03c')][0]
    il=m.value_labels[m.variable_to_label[itv]]
    print({k:v for k,v in il.items() if 115<=k<=125 or 1150<=k<=1260})
    fish=df[df[itv].isin([122,123,1221,1222,1231,1232,1233,1234,1235,1236,1237,1238])]
    ul=m.value_labels[m.variable_to_label[uv]]
    vc=fish.groupby(itv)[uv].value_counts()
    print(pd.DataFrame({'n':vc,'lab':[ul.get(u) for _,u in vc.index]}).to_string())
