import sys
import pandas as pd
import pyreadstat

path = sys.argv[1]
vars_ = sys.argv[2].split(",")
df, meta = pyreadstat.read_dta(path, apply_value_formats=False, usecols=None)
print(df.shape, "unique case_id", df["case_id"].nunique() if "case_id" in df else None)
for v in vars_:
    if v not in df.columns:
        print("MISSING", v)
        continue
    print("==", v, meta.column_names_to_labels.get(v), df[v].dtype)
    vl = meta.variable_to_label.get(v)
    if vl:
        print("  labels:", meta.value_labels[vl])
    vc = df[v].value_counts(dropna=False)
    print("  nunique", df[v].nunique(dropna=False))
    print("  ", vc.head(12).to_dict())
    if df[v].dtype.kind in "fi":
        print("  describe", df[v].describe().to_dict())
