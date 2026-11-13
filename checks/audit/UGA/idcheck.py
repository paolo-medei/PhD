import pyreadstat
import pandas as pd

D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"


def rd(f, cols=None):
    df, meta = pyreadstat.read_dta(D + f, usecols=cols)
    return df


def s(x):
    print(x.dtype, x.head(3).tolist(), x.astype(str).str.len().value_counts().to_dict())


print("== 2010")
f = rd("UGA_2010_UNPS_v03_M_STATA12/GSEC15b.dta", ["hh"])
c = rd("UGA_2010_UNPS_v03_M_STATA12/GSEC1.dta", ["HHID"])
p = rd("UGA_2010_UNPS_v03_M_STATA12/pov2010_11.dta")
r = rd("UGA_2010_UNPS_v03_M_STATA12/GSEC2.dta", ["HHID"])
s(f.hh); s(c.HHID); s(p.hh); s(r.HHID)
fh = set(f.hh.dropna().astype("int64").astype(str))
print("food in cover", len(fh & set(c.HHID)), len(fh))
ph = set(p.hh.astype("int64").astype(str)) if p.hh.dtype != object else set(p.hh)
print("food in pov", len(fh & ph), "pov n", len(ph))
print("food in roster", len(fh & set(r.HHID)))

print("== 2011")
f = rd("UGA_2011_UNPS_v02_M_Stata/GSEC15B.dta", ["HHID"])
c = rd("UGA_2011_UNPS_v02_M_Stata/GSEC1.dta", ["HHID"])
p = rd("UGA_2011_UNPS_v02_M_Stata/UNPS 2011-12 Consumption Aggregate.dta")
r = rd("UGA_2011_UNPS_v02_M_Stata/GSEC2.dta", ["HHID"])
s(f.HHID); s(c.HHID); s(p.HHID); s(r.HHID)
fh = set(f.HHID)
print("food in cover", len(fh & set(c.HHID)), len(fh), "pov", len(fh & set(p.HHID)), len(p), "roster", len(fh & set(r.HHID)))
print(p["round"].value_counts().to_dict(), p.HHID.duplicated().sum())

print("== 2013")
f = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC15B.dta", ["hhid"])
c = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC1.dta", ["hhid"])
p = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/UNPS 2013-14 Consumption Aggregate.dta")
p2 = rd("UGA_2013_UNPS_v02_M_STATA14/pov2013_14.dta")
r = rd("UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC2.dta", ["hhid"])
s(p.hhid); s(p2.hhid)
fh = set(f.hhid)
print("food in cover", len(fh & set(c.hhid)), len(fh), "pov", len(fh & set(p.hhid)), "pov2", len(fh & set(p2.hhid)), "roster", len(fh & set(r.hhid)))
m = p.merge(p2, on="hhid", suffixes=("", "_2"))
for v in ["equiv", "hsize", "welfare", "cpexp30"]:
    print(v, (abs(m[v] - m[v + "_2"]) < 1e-6).mean())

print("== 2015")
f = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec15b.dta", ["hhid", "hh"])
c = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec1.dta", ["hhid", "hh"])
p = rd("UGA_2015_UNPS_v02_M_STATA14/pov2015_16.dta")
r = rd("UGA_2015_UNPS_v02_M_STATA14/household/gsec2.dta", ["hhid"])
s(p.hh); s(r.hhid)
print("food hh in cover hh", len(set(f.hh) & set(c.hh)), "food hhid in cover hhid", len(set(f.hhid) & set(c.hhid)), len(set(f.hh)))
fp = f.drop_duplicates()
print("food hh->hhid consistent with cover:", len(fp.merge(c, on=["hhid", "hh"])), len(fp))
print("pov hh in cover hh", len(set(p.hh) & set(c.hh)), "in cover hhid", len(set(p.hh) & set(c.hhid)))
print("roster hhid in cover hh", len(set(r.hhid) & set(c.hh)), "in cover hhid", len(set(r.hhid) & set(c.hhid)))
print("food hh in pov", len(set(f.hh) & set(p.hh)), len(set(f.hhid) & set(p.hh)))

print("== 2018")
f = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC15B.dta", ["hhid"])
c = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC1.dta", ["hhid"])
p = rd("UGA_2018_UNPS_v02_M_STATA14/pov2018_19.dta")
r = rd("UGA_2018_UNPS_v02_M_STATA14/HH/GSEC2.dta", ["hhid"])
fh = set(f.hhid)
print("food in cover", len(fh & set(c.hhid)), len(fh), "pov", len(fh & set(p.hhid)), len(p), "roster", len(fh & set(r.hhid)))
print("== 2019")
f = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec15b.dta", ["hhid"])
c = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec1.dta", ["hhid"])
p = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/pov2019_20.dta")
r = rd("UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec2.dta", ["hhid"])
fh = set(f.hhid)
print("food in cover", len(fh & set(c.hhid)), len(fh), "pov", len(fh & set(p.hhid)), len(p), "roster", len(fh & set(r.hhid)))
print("pov dup", p.hhid.duplicated().sum())
