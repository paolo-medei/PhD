import sys
import pandas as pd
import pyreadstat

path = sys.argv[1]
df, meta = pyreadstat.read_dta(path, apply_value_formats=False)
print(df.dtypes)
print(df.shape)
for c in meta.column_names:
    print(c, meta.column_names_to_labels.get(c), meta.variable_to_label.get(c))
for c, vl in meta.variable_to_label.items():
    print("VL", c, vl, len(meta.value_labels[vl]))
pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 50)
pd.set_option("display.max_rows", 500)
itemcol = "item_code"
print("itemcol", itemcol)
sub = df[df[itemcol].isin([501, 504, 505, 506, 507, 508, 509, 701, 702, 902])]
print(sub.sort_values(list(sub.columns[:4])).to_string())
vl = meta.variable_to_label.get("unit_code") or meta.variable_to_label.get("unitcode")
for c, vl in meta.variable_to_label.items():
    if "unit" in c.lower():
        print(c, meta.value_labels[vl])
