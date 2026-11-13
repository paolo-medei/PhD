import numpy as np
import pandas as pd

mb = pd.read_pickle("/home/claude/audit_uga/work/merged.pkl")
raw = pd.read_csv("/home/claude/audit_uga/work/match_rates_raw.csv")
p_rows = mb.groupby("wave").size()
# key columns: row sets are identical (outer merge found no left_only/right_only rows)
keys = pd.DataFrame([dict(wave=w, column=c, n=int(n), share_match=1.0, n_mismatch=0)
                     for w, n in p_rows.items() for c in ["hhid", "product", "track"]])
# panel links: predecessor agreement per wave
pc = pd.read_pickle("/home/claude/audit_uga/work/pids_cmp.pkl")
pl = pc.groupby("wave").apply(lambda g: pd.Series(dict(n=len(g), share_match=round(g.same.mean(), 6), n_mismatch=int((~g.same).sum())))).reset_index()
pl["column"] = "pid (pids_UGA.csv, predecessor link)"
out = pd.concat([keys, raw, pl], ignore_index=True)[["wave", "column", "n", "share_match", "n_mismatch"]]
order = ["hhid", "product", "track", "std", "consumed", "qty_std", "purch_std", "own_std", "gift_std", "exp", "exp_conv", "unconv", "uv",
         "welfare", "adulteq", "hhsize", "share_child", "share_elderly", "head_age", "head_female", "region", "urban", "clusterid",
         "hhweight", "country", "year", "strataid", "pid (pids_UGA.csv, predecessor link)"]
out["o"] = out.column.map({c: i for i, c in enumerate(order)})
out = out.sort_values(["o", "wave"]).drop(columns="o")
out["n"] = out["n"].astype(int); out["n_mismatch"] = out["n_mismatch"].astype(int)
out.to_csv("/home/claude/audit_uga/match_rates.csv", index=False)
allw = out.groupby("column", sort=False).apply(lambda g: pd.Series(dict(n=g.n.sum(), share=round(1 - g.n_mismatch.sum() / g.n.sum(), 6), mism=g.n_mismatch.sum())))
print(allw.loc[order].to_string())

# causes of household-level mismatches
hh = mb.drop_duplicates(["wave", "hhid"]).copy()
hh["in_agg"] = hh.welfare_p.notna()
for c in ["hhsize", "share_child", "share_elderly", "head_age", "head_female", "clusterid"]:
    bad = hh[~hh["eq_" + c]]
    print(c, "households:", bad.groupby("wave").size().to_dict(),
          "| not in consumption aggregate:", bad[~bad.in_agg].groupby("wave").size().to_dict(),
          "| in aggregate:", bad[bad.in_agg].groupby("wave").size().to_dict())
print(hh[~hh.eq_share_child & hh.in_agg][["wave", "hhid", "share_child_p", "share_child_r"]].head(5).to_string())
print(hh[~hh.eq_share_elderly & hh.in_agg][["wave", "hhid", "share_elderly_p", "share_elderly_r"]].head(5).to_string())
print("hh not in aggregate per wave:", hh[~hh.in_agg].groupby("wave").size().to_dict())
