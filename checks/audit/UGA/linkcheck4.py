import glob
import pyreadstat
import pandas as pd

pd.set_option("display.width", 250)
D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"


def rd(f, cols=None):
    df, meta = pyreadstat.read_dta(D + f, usecols=cols)
    return df


c4 = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec1.dta")
c5 = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC1.dta")
c6 = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec1.dta")
c6["old"] = c6.hhidold.str.strip()
um = c6[(c6.old != "") & ~c6.old.isin(c5.hhid)]
targets = set(um.old)
print(len(targets))
# search all string columns in 2018 files for these values
for f in sorted(glob.glob(D + "UGA_2018_UNPS_v02_M_STATA14/**/*.dta", recursive=True)):
    try:
        df, meta = pyreadstat.read_dta(f)
    except Exception as e:
        continue
    for c in df.columns:
        if df[c].dtype == object or str(df[c].dtype) == "str":
            hit = df[c].astype(str).isin(targets).sum()
            if hit:
                print(f.split("/")[-1], c, hit)
# also check in 2019 hhid itself (self-reference?)
print("self", um.old.isin(c6.hhid).sum())
# 2018 unmatched t0 ids: look in 2015 hhid with same prefix
c5["t0"] = c5.t0_hhid.str.strip()
u5 = c5[~c5.t0.isin(c4.hhid)]
pref = c4.groupby(c4.hhid.str[:6]).hhid.apply(list)
for t in u5.t0.head(25):
    print(t, pref.get(t[:6], None))
# 2018 interview key vs hhid
print(c5[["hhid", "interview__key"]].head(3))
