import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
pd.set_option('display.width',250)
files={2010:'NGA_2010_GHSP-W1_v03_M_STATA/Post Harvest Wave 1/Household/sect10b_harvestw1.dta',2012:'NGA_2012_GHSP-W2_v02_M_STATA/Post Harvest Wave 2/Household/sect10b_harvestw2.dta',2015:'NGA_2015_GHSP-W3_v02_M_Stata/sect10b_harvestw3.dta'}
for y,f in files.items():
    df,m=pyreadstat.read_dta(B+f)
    il=m.value_labels[m.variable_to_label['item_cd']]
    print('=====',y,{k:v for k,v in il.items() if 90<=k<=110})
    ul=m.value_labels[m.variable_to_label['s10bq3b']]
    print('units',ul)
    fish=df[df.item_cd.between(100,107)]
    print(fish.groupby('item_cd').s10bq1.value_counts().unstack().to_string())
    vc=fish.s10bq3b.value_counts()
    print({(k,ul.get(k)):v for k,v in vc.items()})
    print('hhid',df.hhid.dtype,df.hhid.head(2).tolist(),df.hhid.nunique())
c2,m2=pyreadstat.read_dta(B+'NGA_2012_GHSP-W2_v02_M_STATA/food_conv_w2ph.dta')
print(m2.value_labels)
print(c2[c2.item_cd.between(100,107)].to_string())
c3,m3=pyreadstat.read_dta(B+'NGA_2015_GHSP-W3_v02_M_Stata/food_conv_w3.dta')
print(c3[c3.item_cd.between(100,107)].drop(columns=['note']).to_string())
