import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
pd.set_option('display.width',250)
from eth_peek import files
for y,(f,p,cf) in files.items():
    df,m=pyreadstat.read_dta(B+f,encoding='latin1')
    uv=[x for x in df.columns if x in ('hh_s5aq03_b','s6aq03b')][0]
    ul=m.value_labels.get(m.variable_to_label.get(uv),{})
    c,mc=pyreadstat.read_dta(B+cf,encoding='latin1')
    print('CF unit labels', {k:v for k,v in mc.value_labels[mc.variable_to_label['unit_cd']].items() if k<12})
    it=183 if y==2015 else 704
    fi=df[df.item_cd==it]
    print('====',y,'unit labels',{k:v for k,v in ul.items() if k<12}, '... n labels',len(ul))
    c01=[x for x in df.columns if x in('hh_s5aq01','s6aq01')][0]
    print('consumed',fi[c01].value_counts(dropna=False).to_dict(), 'n hh', df.household_id.nunique())
    vc=fi[uv].value_counts()
    print({(k,ul.get(k)):v for k,v in vc.items()})
    if y==2015: print('item_cd_cf for fish', fi.item_cd_cf.value_counts().to_dict())
    oth=[x for x in df.columns if '03b' in x and ('oth' in x or '_os' in x)][0]
    print('other',fi[oth].replace('',np.nan).dropna().value_counts().to_dict())
