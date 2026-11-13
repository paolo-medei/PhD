import numpy as np
import pandas as pd

TXT = ["hhid", "std", "region", "urban", "clusterid", "country", "strataid", "product", "track"]
p = pd.read_csv("/home/claude/audit_uga/panel_UGA.csv", dtype={c: str for c in TXT})
import sys
SUF = sys.argv[1] if len(sys.argv) > 1 else ""
r = pd.read_csv("/home/claude/audit_uga/work/rebuild_UGA" + SUF + ".csv", dtype={c: str for c in TXT})
r["strataid"] = np.nan
key = ["wave", "hhid", "product", "track"]
print("panel rows", len(p), "rebuild rows", len(r), "panel dup keys", p.duplicated(key).sum(), "rebuild dup", r.duplicated(key).sum())
m = p.merge(r, on=key, how="outer", suffixes=("_p", "_r"), indicator=True)
print(m["_merge"].value_counts())
print(m[m._merge != "both"].groupby(["wave", "_merge"]).size())
cols = [c for c in p.columns if c not in key]
res = []
mb = m[m._merge == "both"].copy()
for c in cols:
    a, b = mb[c + "_p"], mb[c + "_r"]
    if c in TXT:
        eq = (a.astype(str) == b.astype(str)) | (a.isna() & b.isna())
    else:
        a = pd.to_numeric(a, errors="coerce"); b = pd.to_numeric(b, errors="coerce")
        eq = (np.abs(a - b) <= 1e-6 * np.maximum(np.abs(a), np.abs(b))) | (a.isna() & b.isna())
    mb["eq_" + c] = eq
    for w, g in mb.groupby("wave"):
        res.append(dict(wave=w, column=c, n=len(g), share_match=round(g["eq_" + c].mean(), 6), n_mismatch=int((~g["eq_" + c]).sum())))
res = pd.DataFrame(res)
res.to_csv("/home/claude/audit_uga/work/match_rates_raw" + SUF + ".csv", index=False)
piv = res.pivot(index="column", columns="wave", values="n_mismatch")
print(piv.loc[cols].to_string())
mb.to_pickle("/home/claude/audit_uga/work/merged" + SUF + ".pkl")
