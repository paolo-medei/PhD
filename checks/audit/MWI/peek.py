import sys
import pandas as pd
import pyreadstat

path = sys.argv[1]
items = [int(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else None
df, meta = pyreadstat.read_dta(path, apply_value_formats=False)
print(df.dtypes)
print(df.shape)
# value labels of item code
for vname in ["hh_g02", "hh_g01", "hh_g03b_label", "hh_g04b_label", "hh_g03c"]:
    vl = meta.variable_to_label.get(vname)
    if vl:
        labs = meta.value_labels[vl]
        if vname == "hh_g02" and items:
            print(vname, {k: v for k, v in labs.items() if k in items})
        elif vname != "hh_g02":
            print(vname, vl, labs)
if items:
    sub = df[df["hh_g02"].isin(items)]
    pd.set_option("display.width", 250)
    pd.set_option("display.max_columns", 50)
    print(sub[sub["hh_g01"] == 1].head(15))
    for c in sub.columns:
        if c.endswith("b") or c.endswith("b_label"):
            print(c, sub[c].value_counts(dropna=False).head(40).to_dict())
