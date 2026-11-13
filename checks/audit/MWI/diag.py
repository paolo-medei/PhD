import sys

import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
pd.set_option("display.max_rows", 500)
b = pd.read_pickle("/home/claude/audit_mwi/work/merged.pkl")
cols = sys.argv[1].split(",")
show = sys.argv[2].split(",") if len(sys.argv) > 2 else []
bad = b[~b[["ok_" + c for c in cols]].all(axis=1)]
print(len(bad), "rows", bad.hhid.nunique(), "hh")
out = ["wave", "hhid", "product", "track"]
for c in cols + show:
    out += [c + "_t", c + "_m"]
print(bad[out].to_string())
