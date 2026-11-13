import pandas as pd

p = pd.read_csv("/home/claude/audit_uga/panel_UGA.csv", dtype={"hhid": str, "region": str, "urban": str, "clusterid": str, "strataid": str})
print(p.dtypes)
print(p.groupby(["wave", "track", "product", "std"]).size().unstack(["track"]))
print(p.groupby("wave").hhid.nunique())
for w, g in p.groupby("wave"):
    print(w, g.hhid.str.len().value_counts().to_dict(), g.hhid.head(3).tolist(), g.clusterid.head(3).tolist(), g.region.unique()[:10], g.urban.unique(), g.strataid.unique()[:5])
print(p.describe().T)
ids = pd.read_csv("/home/claude/audit_uga/pids_UGA.csv", dtype=str)
print(ids.groupby("wave").size())
print(ids.pid.str.len().value_counts())
print(ids.groupby("pid").size().value_counts())
for w, g in ids.groupby("wave"):
    print(w, g.head(3).values.tolist())
