import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
import re
KW=re.compile(r'beef|goat|mutton|sheep|pork|pig|chicken|poultry|duck|bird|egg|milk|cheese|yog|cream|coffee|cocoa|meat|offal|liver|sausage|butter|ghee|fish|lamb|camel|bongo|ice|tea',re.I)
F={'TZA':['TZA_2008_NPS1_v02_M_STATA_English_labels/TZA_2008_NPS1_v02_M_STATA_English_labels/SEC_K1.dta','TZA_2020_NPS-R5_v02_M_STATA14/hh_sec_ja1.dta'],
   'UGA':['UGA_2010_UNPS_v03_M_STATA12/GSEC15b.dta','UGA_2018_UNPS_v02_M_STATA14/HH/GSEC15B.dta'],
   'MWI':['MWI_2010_IHS-III_v01_M_STATA8/MWI_2010_IHS-III_v01_M_STATA8/Full_Sample/Household/hh_mod_g1.dta','MWI_2024-2025_IHS-VI_v01_M_STATA14/hh_mod_g1.dta'],
   'NGA':['NGA_2015_GHSP-W3_v02_M_Stata/sect10b_harvestw3.dta'],
   'ETH':['ETH_2011_ERSS_v02_M_Stata8/sect5a_hh.dta','ETH_2015_ESS_v03_M_STATA/Household/sect5a_hh_w3.dta','ETH_2018_ESS_v04_M_Stata/sect6a_hh_w4.dta']}
c=sys.argv[1]
for f in F[c]:
    import glob,os
    if not os.path.exists(B+f): print('missing',f); continue
    _,m=pyreadstat.read_dta(B+f,metadataonly=True,encoding='latin1')
    for v in ['skcode','itemcode','itmcd','CEB01','hh_g02','item_cd']:
        if v in m.column_names:
            vl=m.value_labels.get(m.variable_to_label.get(v),{})
            print(f, {k:s for k,s in vl.items() if KW.search(str(s))})
