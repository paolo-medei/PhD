import pyreadstat
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"
files = {
    "w1": (D + "UGA_2010_UNPS_v03_M_STATA12/GSEC15b.dta", "hh", "itmcd", "h15bq3a"),
    "w2": (D + "UGA_2011_UNPS_v02_M_Stata/GSEC15B.dta", "HHID", "itmcd", "h15bq3a"),
    "w3": (D + "UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC15B.dta", "hhid", "itmcd", "h15bq3a"),
    "w4": (D + "UGA_2015_UNPS_v02_M_STATA14/household/gsec15b.dta", "hh", "itmcd", "h15bq3a"),
    "w5": (D + "UGA_2018_UNPS_v02_M_STATA14/HH/GSEC15B.dta", "hhid", "CEB01", "CEB03"),
    "w6": (D + "UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec15b.dta", "hhid", "CEB01", "CEB03"),
}
for w, (f, hid, it, cons) in files.items():
    df, meta = pyreadstat.read_dta(f)
    print("==", w, df.shape, "hh", df[hid].nunique(), "items", df[it].nunique())
    print("consumed flag", df[cons].value_counts(dropna=False).to_dict())
    dup = df.duplicated([hid, it]).sum()
    print("dup hh-item", dup)
    print(df[hid].astype(str).str.len().value_counts().to_dict())
    asf = df[df[it].isin([117, 118, 119, 121, 124, 125, 148, 1181, 1211, 1212, 1213, 1214, 1252, 1254])]
    print(pd.crosstab(asf[it], asf[cons].fillna(-9)))
    if w == "w1":
        print("itmcd==h15bq2", (pd.to_numeric(df.itmcd, errors="coerce") == pd.to_numeric(df.h15bq2, errors="coerce")).mean())
        print("untcd==h15bq3c", (pd.to_numeric(df.untcd, errors="coerce") == pd.to_numeric(df.h15bq3c, errors="coerce")).mean())
        x = df[pd.to_numeric(df.untcd, errors="coerce") != pd.to_numeric(df.h15bq3c, errors="coerce")]
        print(x[["hh", "itmcd", "h15bq2", "untcd", "h15bq3c", "h15bq4", "h15bq5"]].head(20))
        print(len(x))
