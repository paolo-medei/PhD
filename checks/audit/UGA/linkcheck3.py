import pyreadstat
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"


def rd(f, cols=None):
    df, meta = pyreadstat.read_dta(D + f, usecols=cols)
    return df


c3 = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC1.dta")
c4 = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec1.dta")
c5 = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC1.dta")
c6 = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec1.dta")
r3 = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC2.dta", ["hhid", "pid", "h2q4", "h2q7"])
r4 = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec2.dta", ["hhid", "pid", "h2q4", "h2q7"])
r5 = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC2.dta", ["hhid", "pid", "pid_unps", "t0_hhid", "h2q4", "h2q7"])
r6 = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec2.dta", ["hhid", "pid", "pid_unps_wave7", "h2q4", "h2q7"])

print("--- (d) w4->w3")
c4["cand"] = c4.hh.str.slice(0, 7) + "04" + c4.hh.str.slice(9)
c4["struct"] = c4.cand.where(c4.cand.isin(c3.hhid))
# roster-based: modal w3 hhid of members (by pid), head-based
pm3 = r3.drop_duplicates("pid").set_index("pid").hhid
r4["w3hh"] = r4.pid.map(pm3)
hv = r4.dropna(subset=["w3hh"]).groupby("hhid").w3hh.agg(lambda s: s.value_counts().index[0])
head = r4[r4.h2q4 == 1].dropna(subset=["w3hh"]).groupby("hhid").w3hh.first()
c4["viapid"] = c4.hhid.map(hv)
c4["viahead"] = c4.hhid.map(head)
print("struct n", c4.struct.notna().sum(), "viapid n", c4.viapid.notna().sum(), "viahead", c4.viahead.notna().sum())
both = c4.struct.notna() & c4.viapid.notna()
print("both", both.sum(), "agree", (c4.struct == c4.viapid)[both].sum())
print(c4[both & (c4.struct != c4.viapid)][["hh", "struct", "viapid", "viahead", "rotate"]].head(15))
print("viapid only", (c4.struct.isna() & c4.viapid.notna()).sum())
print(c4[c4.struct.isna() & c4.viapid.notna()][["hh", "viapid", "viahead", "rotate", "DynID"]].head(10))
print("struct-only", (c4.struct.notna() & c4.viapid.isna()).sum())
print("struct dup targets", c4.struct.dropna().duplicated().sum())
print("w4 hh suffix for struct NA:", c4[c4.struct.isna()].hh.str[-2:].value_counts().to_dict())

print("--- (e) w5 t0_hhid")
h4 = set(c4.hhid)
c5["t0"] = c5.t0_hhid.str.strip()
um = c5[~c5.t0.isin(h4)]
print("unmatched", len(um), "len dist", um.t0.str.len().value_counts().to_dict())
print("unmatched with 6-char prefix in w4:", um.t0.str[:6].isin(c4.hhid.str[:6]).sum())
print("hwgt_W7 present among unmatched", um.hwgt_W7.notna().sum(), "among matched", c5[c5.t0.isin(h4)].hwgt_W7.notna().sum())
print(um[["hhid", "t0", "hwgt_W7"]].head(30).to_string())
# roster based w5 -> w4: pid_unps
print(r5[["hhid", "pid", "pid_unps", "t0_hhid"]].dropna(subset=["pid"]).head(5).to_string())
pm4 = r4.drop_duplicates("pid").set_index("pid").hhid
r5["w4hh"] = r5.pid_unps.map(pm4)
hv5 = r5.dropna(subset=["w4hh"]).groupby("hhid").w4hh.agg(lambda s: s.value_counts().index[0])
c5["viapid"] = c5.hhid.map(hv5)
m = c5.t0.isin(h4)
print("matched t0 agree with viapid", (c5.t0 == c5.viapid)[m & c5.viapid.notna()].mean(), (m & c5.viapid.notna()).sum())
print("unmatched t0 with viapid", (~m & c5.viapid.notna()).sum())
print(c5[~m & c5.viapid.notna()][["hhid", "t0", "viapid", "hwgt_W7"]].head(20))
dd = c5[c5.t0.duplicated(keep=False)].sort_values("t0")
print(dd[["hhid", "t0", "viapid", "hwgt_W7", "wgt"]])

print("--- (f) w6 hhidold")
h5 = set(c5.hhid)
c6["old"] = c6.hhidold.str.strip()
um = c6[~c6.old.isin(h5)]
print("unmatched", len(um), "empty", (um.old == "").sum())
pm5 = r5.dropna(subset=["pid"]).drop_duplicates("pid").set_index("pid").hhid
r6["w5hh"] = r6.pid_unps_wave7.map(pm5)
print(r6[["hhid", "pid", "pid_unps_wave7"]].head(3).to_string())
hv6 = r6.dropna(subset=["w5hh"]).groupby("hhid").w5hh.agg(lambda s: s.value_counts().index[0])
c6["viapid"] = c6.hhid.map(hv6)
m = c6.old.isin(h5)
print("matched agree", (c6.old == c6.viapid)[m & c6.viapid.notna()].mean(), (m & c6.viapid.notna()).sum())
print("unmatched with viapid", (~m & c6.viapid.notna()).sum(), "of", (~m).sum())
print(c6[~m][["hhid", "old", "viapid"]].head(10))
dd = c6[m & c6.old.duplicated(keep=False)]
print("dup nonempty targets", len(dd))
print("w6 old in w4 hhid?", um.old.isin(c4.hhid).sum(), "in w5 t0", um.old.isin(c5.t0).sum())
