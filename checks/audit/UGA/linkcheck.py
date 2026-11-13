import pyreadstat
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"


def rd(f, cols=None):
    df, meta = pyreadstat.read_dta(D + f, usecols=cols)
    return df


c1 = rd("UGA_2010_UNPS_v03_M_STATA12/GSEC1.dta")
c2 = rd("UGA_2011_UNPS_v02_M_Stata/GSEC1.dta")
c3 = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC1.dta")
c4 = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec1.dta")
c5 = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC1.dta")
c6 = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec1.dta")

print("w2 HHID in w1:", c2.HHID.isin(c1.HHID).sum(), len(c2))
print(pd.crosstab(c2.HHID.isin(c1.HHID), c2.wave))
print("w2 HH_2005 in w1", c2.HH_2005.isin(c1.HHID).sum())
x = c2[~c2.HHID.isin(c1.HHID)]
print(x[["HHID", "HH_2005", "wave"]].head(15))
print("w2 not in w1, HHID==HH_2005", (x.HHID == x.HH_2005).sum(), "of", len(x))

# 2013 HHID_old float
print("HHID_old dtype", c3.HHID_old.dtype, c3.HHID_old.notna().sum())
ho = c3.HHID_old.dropna()
print("max", ho.max(), "> 2^53:", (ho > 2**53).sum())
hs = ho.astype("int64").astype(str)
print("HHID_old (int str) in w2 HHID:", hs.isin(c2.HHID).sum(), "in w1", hs.isin(c1.HHID).sum(), "of", len(hs))
bad = hs[~hs.isin(c2.HHID)]
print(bad.head(20).tolist(), len(bad))
print(pd.crosstab(c3.rotate, c3.HHID_old.notna()))
print("dup HHID_old in w3", hs.duplicated().sum())
# try reading HHID_old exact from raw stata? check type in metadata
_, meta = pyreadstat.read_dta(D + "UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC1.dta", metadataonly=True)
print("orig types", meta.original_variable_types.get("HHID_old"), meta.readstat_variable_types.get("HHID_old"))
_, meta = pyreadstat.read_dta(D + "UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC2.dta", metadataonly=True)
print("roster HHID_old types", meta.original_variable_types.get("HHID_old"), meta.original_variable_types.get("PID_Old"))

# 2015 vs 2013
print("w4 hh pattern:", c4.hh.str[7:9].value_counts().to_dict(), c4.hh.str[-2:].value_counts().to_dict())
cand = c4.hh.str.slice(0, 7) + "04" + c4.hh.str.slice(9)
print("w4 hh with 05->04 in w3:", cand.isin(c3.hhid).sum(), "of", len(c4))
print(pd.crosstab(c4.rotate, cand.isin(c3.hhid)))
print("w4 hhid vs hh consistency:", ((c4.hh.str[:6] + c4.hh.str[-2:]) == c4.hhid).mean())
m = c4.assign(cand=cand).merge(c3[["hhid", "DynID"]], left_on="cand", right_on="hhid", how="left", suffixes=("", "_3"))
print("DynID agree w3-w4 among matched", (m.DynID == m.DynID_3)[m.hhid_3.notna()].mean())
print(c3.hhid.str[7:9].value_counts().to_dict(), c3.hhid.str[-2:].value_counts().to_dict())

# 2018 vs 2015
print("t0_hhid in w4 hhid", c5.t0_hhid.isin(c4.hhid).sum(), "of", len(c5), "dups", c5.t0_hhid.duplicated().sum())
y = c5[~c5.t0_hhid.isin(c4.hhid)]
print(y[["hhid", "t0_hhid", "hwgt_W7"]].head(10), len(y))
print("t0 suffix", c5.t0_hhid.str[-2:].value_counts().to_dict())
d = c5[c5.t0_hhid.duplicated(keep=False)].sort_values("t0_hhid")
print(d[["hhid", "t0_hhid", "hwgt_W7"]])

# 2019 vs 2018
print("hhidold in w5 hhid", c6.hhidold.isin(c5.hhid).sum(), "of", len(c6), "dups", c6.hhidold.duplicated().sum())
z = c6[~c6.hhidold.isin(c5.hhid)]
print(z[["hhid", "hhidold"]].head(10), len(z))
d = c6[c6.hhidold.duplicated(keep=False)].sort_values("hhidold")
print(d[["hhid", "hhidold"]].head(20), len(d))
