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
r1 = rd("UGA_2010_UNPS_v03_M_STATA12/GSEC2.dta", ["HHID", "PID"])
r2 = rd("UGA_2011_UNPS_v02_M_Stata/GSEC2.dta", ["HHID", "PID"])
r3 = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC2.dta", ["hhid", "pid", "PID_Old", "HHID_old"])
r4 = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec2.dta", ["hhid", "pid"])
r5 = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC2.dta", ["hhid", "pid", "pid_unps", "t0_hhid"])
r6 = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec2.dta", ["hhid", "pid", "pid_unps_wave7"])

print("--- (a) w3 HHID_old not in w2")
c3["old"] = c3.HHID_old.map(lambda v: str(int(v)) if pd.notna(v) else None)
nn = c3[c3.old.notna() & ~c3.old.isin(c2.HHID)]
print(len(nn), "in w1:", nn.old.isin(c1.HHID).sum(), "in w2 HH_2005:", nn.old.isin(c2.HH_2005).sum())
print(nn[["hhid", "old", "rotate"]].head(10))
print("w3 old dup", c3.old.dropna().duplicated().sum())

print("--- (b) rotate=1 without HHID_old")
b = c3[(c3.rotate == 1) & c3.old.isna()]
print(b.hhid.str[-2:].value_counts().to_dict())
print(b[["hhid", "DynID"]].head())
print("rotate=1 with link suffix", c3[(c3.rotate == 1) & c3.old.notna()].hhid.str[-2:].value_counts().to_dict())
print("rotate=0 suffix", c3[c3.rotate == 0].hhid.str[-2:].value_counts().to_dict())

print("--- (c) 2013 roster PID_Old")
print(r3.head(5).to_string())
print("roster HHID_old vs cover HHID_old consistent?")
r3o = r3.dropna(subset=["HHID_old"]).groupby("hhid").HHID_old.nunique()
print("hh with >1 HHID_old in roster", (r3o > 1).sum())
r3["pold"] = r3.PID_Old.astype(str).str.strip()
print("PID_Old non-empty", (r3.pold != "").sum(), "in w2 PID:", r3.pold.isin(r2.PID).sum(), "in w1 PID", r3.pold.isin(r1.PID).sum())
# household-level: map members to w2 HHID by PID
print("w2 PID dups", r2.PID.duplicated().sum()); pmap = r2.drop_duplicates("PID").set_index("PID").HHID
r3["w2hh"] = r3.pold.map(pmap)
hh_from_pid = r3.dropna(subset=["w2hh"]).groupby("hhid").w2hh.agg(lambda s: s.value_counts().index[0])
cmp = c3.set_index("hhid").old.to_frame().join(hh_from_pid.rename("viapid"))
print("cover old vs modal member w2 HHID: both", (cmp.old.notna() & cmp.viapid.notna()).sum(),
      "agree", (cmp.old == cmp.viapid).sum(), "old only", (cmp.old.notna() & cmp.viapid.isna()).sum(),
      "pid only", (cmp.old.isna() & cmp.viapid.notna()).sum())
print(cmp[(cmp.old.notna()) & (cmp.viapid.notna()) & (cmp.old != cmp.viapid)].head(10))
print(cmp[(cmp.old.isna()) & (cmp.viapid.notna())].head(10))

print("--- (d) 2015 vs 2013 via roster pid")
print(r3[["hhid", "pid"]].head(3).to_string(), r4.head(3).to_string())
print("w4 pid in w3 pid:", r4.pid.isin(r3.pid).sum(), len(r4))
