import pandas as pd

p = pd.read_csv("/home/claude/audit_mwi/panel_MWI.csv", dtype={"hhid": str, "region": str, "urban": str, "clusterid": str, "strataid": str}, keep_default_na=True)
print(p.dtypes)
print(p.shape)
print(p.groupby(["wave", "year"]).size())
print(p.groupby(["wave"]).hhid.nunique())
print(p.groupby(["track", "product", "std"]).size())
print(p.groupby(["wave", "track"]).size())
for c in ["consumed", "unconv", "urban", "country", "head_female"]:
    print(c, p.groupby("wave")[c].value_counts(dropna=False).to_dict())
for c in ["qty_std", "purch_std", "own_std", "gift_std", "exp", "exp_conv", "uv", "hhsize", "welfare", "adulteq", "share_child", "share_elderly", "head_age", "hhweight", "strataid", "region", "clusterid"]:
    print(c, "nonmissing by wave", p.groupby("wave")[c].apply(lambda s: s.notna().sum()).to_dict())
print((p.qty_std == 0).sum(), (p.exp == 0).sum())
print(p.duplicated(["wave", "hhid", "product", "track"]).sum())
print(p[p.wave == "w4"].head(3).T)
