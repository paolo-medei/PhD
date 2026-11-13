import pyreadstat
import pandas as pd

D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"
files = {
    "w1": D + "UGA_2010_UNPS_v03_M_STATA12/GSEC2.dta",
    "w2": D + "UGA_2011_UNPS_v02_M_Stata/GSEC2.dta",
    "w3": D + "UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC2.dta",
    "w4": D + "UGA_2015_UNPS_v02_M_STATA14/household/gsec2.dta",
    "w5": D + "UGA_2018_UNPS_v02_M_STATA14/HH/GSEC2.dta",
    "w6": D + "UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec2.dta",
}
for w, f in files.items():
    df, meta = pyreadstat.read_dta(f)
    print("==", w, df.shape, list(df.columns)[:12])
    for c in ["h2q3", "h2q4", "h2q7"]:
        print(c, df[c].value_counts(dropna=False).sort_index().to_dict())
    print("age", df["h2q8"].describe().to_dict(), "nnull", df["h2q8"].isna().sum())
    hid = [c for c in df.columns if c.lower() == "hhid"][0]
    heads = df[df.h2q4 == 1].groupby(hid).size()
    print("hh", df[hid].nunique(), "hh with heads", len(heads), "multi-head", (heads > 1).sum())
