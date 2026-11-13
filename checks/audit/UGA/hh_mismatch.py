import numpy as np
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 40)
mb = pd.read_pickle("/home/claude/audit_uga/work/merged.pkl")
hh = mb.drop_duplicates(["wave", "hhid"])
hv = pd.read_csv("/home/claude/audit_uga/work/rebuild_hh_UGA.csv", dtype={"hhid": str, "clusterid": str})
for c in ["hhsize", "share_child", "share_elderly", "head_age", "head_female", "clusterid"]:
    bad = hh[~hh["eq_" + c]]
    print("=====", c, bad.groupby("wave").size().to_dict())
    x = bad[["wave", "hhid", c + "_p", c + "_r"]].merge(hv[["wave", "hhid", "n_mem", "n_heads", "hhsize_agg"]], on=["wave", "hhid"], how="left")
    print(x.head(40).to_string())
