import pandas as pd

p = pd.read_csv("/home/claude/audit_uga/panel_UGA.csv", dtype={"hhid": str, "region": str, "urban": str, "clusterid": str, "strataid": str})
for c in ["qty_std", "purch_std", "own_std", "gift_std", "exp", "exp_conv", "uv", "welfare", "hhweight"]:
    print(c, "zeros", (p[c] == 0).sum(), "neg", (p[c] < 0).sum(), "nonnull", p[c].notna().sum())
print(p.groupby(["wave", "product", "track"])[["consumed", "unconv"]].sum().unstack("track"))
print(p.groupby(["wave", "product", "track"])[["qty_std", "purch_std", "exp"]].count().unstack("track"))
# compare track A vs B for same product
a = p[p.track == "A"].set_index(["wave", "hhid", "product"])
b = p[p.track == "B"].set_index(["wave", "hhid", "product"])
j = a.join(b, lsuffix="_A", rsuffix="_B", how="inner")
for c in ["consumed", "qty_std", "purch_std", "exp", "exp_conv", "unconv"]:
    eq = (j[c + "_A"] == j[c + "_B"]) | (j[c + "_A"].isna() & j[c + "_B"].isna())
    print("A vs B", c, eq.groupby(level=["wave", "product"]).mean().unstack().round(4).to_dict())
