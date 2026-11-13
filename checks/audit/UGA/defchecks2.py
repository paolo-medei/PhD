import sys
import numpy as np
import pandas as pd
import pyreadstat
sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R
pd.set_option("display.width", 250)
D = R.D
# w4 hsize anomaly
agg, _ = R.rd("w4", "agg")
ros, _ = R.rd("w4", "roster")
cov, _ = R.rd("w4", "cover", ["hhid", "hh"])
ros["rk"] = ros.hhid.map(cov.set_index("hhid").hh)
ros["res"] = pd.to_numeric(ros.h2q7, errors="coerce")
u = ros[ros.res.isin([1, 2])].groupby("rk").size()
a = agg.set_index("hh").hsize
d = pd.DataFrame({"ag": a, "usual": u.reindex(a.index)})
print((d.ag - d.usual).describe().to_dict(), (d.ag - d.usual).value_counts().head(10).to_dict())
eq = pd.read_csv("/home/claude/audit_uga/work/rebuild_hh_UGA.csv", dtype={"hhid": str})
# compare with h2q5 months? check usual members present only
up = ros[ros.res.isin([1])].groupby("rk").size()
print("agg==usual present only", (a == up.reindex(a.index)).mean())
uu = ros[ros.res.isin([1, 2, 3])].groupby("rk").size()
print("agg==1,2,3", (a == uu.reindex(a.index)).mean())
ros["m"] = pd.to_numeric(ros.h2q5, errors="coerce")
u6 = ros[ros.res.isin([1, 2]) & (ros.m >= 6)].groupby("rk").size()
print("agg==usual & months>=6", (a == u6.reindex(a.index)).mean())
# w2 hhsize under usual-only vs usual+regular
r2, _ = R.rd("w2", "roster")
r2["res"] = pd.to_numeric(r2.h2q7, errors="coerce")
print("w2 mean hhsize usual(1,2):", r2[r2.res.isin([1, 2])].groupby("HHID").size().mean(), "usual+regular:", r2[r2.res.isin([1, 2, 3, 4])].groupby("HHID").size().mean())
for w in ["w1", "w3", "w5"]:
    print(w, "mean agg hsize", eq[eq.wave == w].hhsize_agg.mean(), "mean usual+regular", eq[eq.wave == w].n_mem.mean())
# geovars 2018 for EA
for f in ["UGA_2018_UNPS_v02_M_STATA14/unps_geovars_2018_19.dta", "UGA_2015_UNPS_v02_M_STATA14/unps_geovars_2015_16.dta"]:
    df, m = pyreadstat.read_dta(D + f, metadataonly=True)
    print(f, [(k, v) for k, v in m.column_names_to_labels.items()][:12])
