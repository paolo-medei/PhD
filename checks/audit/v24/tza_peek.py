import pyreadstat, pandas as pd
B='/home/claude/v20home/Desktop/ASF_DATA/_unzipped/'
df,m=pyreadstat.read_dta(B+'TZA_2020_NPS-R5_v02_M_STATA14/hh_sec_ja1.dta')
print({k:v for k,v in m.value_labels['ITEMCODE'].items() if 800<=k<1000 or 8000<=k<10000})
print(m.value_labels['hh_ja02_1'])
f=df[df.itemcode.between(8000,8200)|df.itemcode.between(800,899)]
print(f.groupby('itemcode').hh_ja01.value_counts().unstack())
for v in ['hh_ja02_1','hh_ja02b_1','hh_ja03_1','hh_ja05_1','hh_ja06_1']:
    print(v, f[v].value_counts(dropna=False).to_dict())
print(f[f.hh_ja01==1][['hh_ja02_1','hh_ja02_2','hh_ja02b_1','hh_ja02b_2','hh_ja03_1','hh_ja03_2','hh_ja04','hh_ja05_1','hh_ja05_2','hh_ja06_1','hh_ja06_2']].head(30))
print(df.y5_hhid.nunique())
df2,m2=pyreadstat.read_dta(B+'TZA_2020_NPS-R5_v02_M_STATA14/hh_sec_j1.dta')
print({k:v for k,v in m2.value_labels['ITEMCODE'].items() if 800<=k<1000 or 8000<=k<10000})
print(df2.y5_hhid.nunique(), len(set(df2.y5_hhid)&set(df.y5_hhid)))
f2=df2[df2.itemcode.between(800,899)]
print(f2.groupby('itemcode').hh_j01.value_counts().unstack())
for v in ['hh_j02_1','hh_j03_1']:
    print(v, f2[v].value_counts(dropna=False).to_dict())
print(df2.j1_selection.value_counts())
