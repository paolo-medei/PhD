"""Row-by-row comparison of panel_MWI.csv with the independent rebuild.

python3 -I compare.py [rebuild.csv] [out_rates.csv]
"""
import sys

import numpy as np
import pandas as pd

REB = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/audit_mwi/work/rebuild_MWI.csv"
RATES = sys.argv[2] if len(sys.argv) > 2 else "/home/claude/audit_mwi/work/match_rates_tmp.csv"
KEYS = ["wave", "hhid", "product", "track"]
TEXT = ["std", "region", "urban", "clusterid", "country", "strataid"]
DT = {c: str for c in ["hhid"] + TEXT}

theirs = pd.read_csv("/home/claude/audit_mwi/panel_MWI.csv", dtype=DT)
mine = pd.read_csv(REB, dtype=DT)
print("rows theirs", len(theirs), "mine", len(mine))
m = theirs.merge(mine, on=KEYS, how="outer", suffixes=("_t", "_m"), indicator=True)
print(m["_merge"].value_counts())
cols = [c for c in theirs.columns if c not in KEYS]


def eq(a, b, text):
    if text:
        a = a.fillna("<NA>").astype(str)
        b = b.fillna("<NA>").astype(str)
        return a == b
    a = pd.to_numeric(a, errors="coerce").astype(float)
    b = pd.to_numeric(b, errors="coerce").astype(float)
    both_na = a.isna() & b.isna()
    close = (a - b).abs() <= 1e-6 * np.maximum(a.abs(), b.abs())
    return both_na | (close.fillna(False) & a.notna() & b.notna())


both = m[m["_merge"] == "both"].copy()
rows = []
for c in cols:
    ok = eq(both[c + "_t"], both[c + "_m"], c in TEXT)
    both["ok_" + c] = ok
    for w, sub in both.groupby("wave"):
        rows.append({"wave": w, "column": c, "n": len(sub), "share_match": ok[sub.index].mean(),
                     "n_mismatch": int((~ok[sub.index]).sum())})
    rows.append({"wave": "all", "column": c, "n": len(both), "share_match": ok.mean(),
                 "n_mismatch": int((~ok).sum())})
r = pd.DataFrame(rows)
r.to_csv(RATES, index=False)
pd.set_option("display.width", 250)
pd.set_option("display.max_rows", 500)
print(r.pivot(index="column", columns="wave", values="n_mismatch").loc[cols].to_string())
both.to_pickle("/home/claude/audit_mwi/work/merged.pkl")
