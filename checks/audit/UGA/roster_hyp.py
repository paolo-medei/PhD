import sys
import numpy as np
import pandas as pd
import pyreadstat

sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R

pd.set_option("display.width", 250)
mb = pd.read_pickle("/home/claude/audit_uga/work/merged.pkl")
hh = mb.drop_duplicates(["wave", "hhid"]).set_index(["wave", "hhid"])
out = []
for w in R.W:
    c = R.W[w]
    ros, rm = R.rd(w, "roster")
    ros["rk"] = R.idstr(ros[c["rhid"]])
    if w == "w4":
        cov2, _ = R.rd(w, "cover", ["hhid", "hh"])
        ros["rk"] = ros["rk"].map(cov2.set_index("hhid")["hh"])
    ros["res"] = pd.to_numeric(ros["h2q7"], errors="coerce")
    ros["age"] = pd.to_numeric(ros["h2q8"], errors="coerce")
    ros["rel"] = pd.to_numeric(ros["h2q4"], errors="coerce")
    ros["sex"] = pd.to_numeric(ros["h2q3"], errors="coerce")
    mem = ros[ros["res"].isin([1, 2, 3, 4])]
    print(w, "members", len(mem), "members with missing age", mem["age"].isna().sum(), "missing sex", mem["sex"].isna().sum())
    g = mem.groupby("rk")
    known = g["age"].count()
    sc = g["age"].apply(lambda a: (a < 15).sum()) / known
    se = g["age"].apply(lambda a: (a >= 60).sum()) / known
    x = hh.loc[w][["share_child_p", "share_elderly_p", "welfare_p", "head_age_p", "head_female_p", "hhsize_p"]].copy()
    x["sc_known"] = sc
    x["se_known"] = se
    inagg = x["welfare_p"].notna()
    def eq(a, b):
        return (np.abs(a - b) <= 1e-6) | (a.isna() & b.isna())
    print("  known-age denominator: share_child match (in aggregate)", eq(x.sc_known, x.share_child_p)[inagg].mean(),
          " share_elderly", eq(x.se_known, x.share_elderly_p)[inagg].mean())
    print("  panel roster vars NA <=> welfare NA:", pd.crosstab(x.welfare_p.isna(), x.share_child_p.isna()).to_dict())
    print("  hhsize NA vs welfare NA:", pd.crosstab(x.welfare_p.isna(), x.hhsize_p.isna()).to_dict())
    heads = mem[mem.rel == 1]
    nh = heads.groupby("rk").size()
    multi = nh[nh > 1].index
    allheads = ros[ros.rel == 1].groupby("rk").size()
    print("  hh with >1 head among members:", len(multi), " >1 head in full roster:", int((allheads > 1).sum()))
    for h in multi:
        print("   ", h, heads[heads.rk == h][["age", "sex", "res"]].values.tolist(), "panel:", x.loc[h, ["head_age_p", "head_female_p"]].tolist() if h in x.index else None)
    # heads that are not members
    nonmem_head = ros[(ros.rel == 1) & ~ros.res.isin([1, 2, 3, 4])]
    print("  heads with non-member residence status:", len(nonmem_head), nonmem_head.res.value_counts(dropna=False).to_dict())
