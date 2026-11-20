import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
files={2010:'MWI_2010_IHS-III_v01_M_STATA8/MWI_2010_IHS-III_v01_M_STATA8/Full_Sample/Household/hh_mod_g1.dta',2016:'MWI_2016_IHS-IV_v04_M_STATA14/MWI_2016_IHS-IV_v04_M_STATA14/household/hh_mod_g1.dta',2019:'MWI_2019_IHS-V_v06_M_Stata/HH_MOD_G1.dta',2024:'MWI_2024-2025_IHS-VI_v01_M_STATA14/hh_mod_g1.dta'}
for y,f in files.items():
    df,m=pyreadstat.read_dta(B+f)
    il=m.value_labels.get(m.variable_to_label.get('hh_g02'),{})
    print('=====',y, {k:v for k,v in il.items() if 500<=k<=520 or 5000<=k<=5200})
    fish=df[df.hh_g02.isin([502,503,513,5021,5022,5023,5031,5032,5033,5121,5122,5123])]
    print('items',fish.hh_g02.value_counts().sort_index().to_dict())
    print('g01',fish.hh_g01.value_counts(dropna=False).to_dict())
    print('g04b dtype',fish.hh_g04b.dtype, fish.hh_g04b.value_counts().head(25).to_dict())
    if 'hh_g04b_label' in fish:
        ul=m.value_labels.get(m.variable_to_label.get('hh_g04b_label'),{})
        vc=fish.hh_g04b_label.value_counts()
        print({ (k,ul.get(k)):v for k,v in vc.items()})
        print('g04c',fish.hh_g04c.value_counts().head(10).to_dict(), m.value_labels.get(m.variable_to_label.get('hh_g04c'),{}) and list(m.value_labels.get(m.variable_to_label.get('hh_g04c')).items())[:12])
    os_col=[c for c in fish.columns if c.startswith('hh_g04b_o')][0]
    print('other specify',fish[os_col].replace('',np.nan).dropna().value_counts().head(30).to_dict())
