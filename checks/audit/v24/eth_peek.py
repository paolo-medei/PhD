import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
pd.set_option('display.width',250)
files={2015:('ETH_2015_ESS_v03_M_STATA/Household/sect5a_hh_w3.dta','hh_s5aq','ETH_2015_ESS_v03_M_STATA/Food and Crop Conversion Factors/Food_CF_Wave3.dta'),
       2018:('ETH_2018_ESS_v04_M_Stata/sect6a_hh_w4.dta','s6aq','ETH_2018_ESS_v04_M_Stata/Food_CF_Wave4.dta'),
       2021:('ETH_2021_ESPS-W5_v02_M_Stata/sect6a_hh_w5.dta','s6aq','ETH_2021_ESPS-W5_v02_M_Stata/food_cf_wave5.dta')}
for y,(f,p,cf) in files.items():
    df,m=pyreadstat.read_dta(B+f,encoding='latin1')
    if y==2015: print(list(df.columns))
    il=m.value_labels[m.variable_to_label['item_cd']]
    print('====',y,{k:v for k,v in il.items() if 'ish' in str(v).lower() or k in (183,704)})
    c,mc=pyreadstat.read_dta(B+cf,encoding='latin1')
    ic=mc.value_labels[mc.variable_to_label['item_cd']]
    print('CF items fish',{k:v for k,v in ic.items() if 'ish' in str(v).lower()})
    fi=[k for k,v in il.items() if 'fish' in str(v).lower()]
    print(c[c.item_cd.isin(fi)|c.item_cd_cf.isin(fi)].drop(columns=['note']).to_string())
    uvar=[x for x in df.columns if x.endswith('03b') or x.endswith('03b_cd')]
    print(uvar)
