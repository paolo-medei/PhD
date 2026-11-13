import sys
import pandas as pd
import pyreadstat

path = sys.argv[1]
df, meta = pyreadstat.read_dta(path, apply_value_formats=False)
print(df[["hh_b04", "hh_b05a"]].map(type).value_counts())
print("nonnumeric b04", df["hh_b04"][pd.to_numeric(df["hh_b04"], errors="coerce").isna()].value_counts(dropna=False))
print("nonnumeric b05a", df["hh_b05a"][pd.to_numeric(df["hh_b05a"], errors="coerce").isna()].value_counts(dropna=False))
g = df.groupby("case_id")
print("visits per hh", g["visit"].nunique().value_counts())
both = g["visit"].nunique()
both = both[both > 1].index
sub = df[df.case_id.isin(both)]
print("rows in hh with both visits", len(sub))
print("dup id_code within hh", sub.duplicated(["case_id", "id_code"]).sum())
print("dup id_code within hh all", df.duplicated(["case_id", "id_code"]).sum())
print(sub[["case_id", "id_code", "visit", "hh_b03", "hh_b04", "hh_b05a"]].head(30))
heads = df[pd.to_numeric(df.hh_b04, errors="coerce") == 1].groupby("case_id").size()
print("heads per hh", heads.value_counts())
print("hh with no head", set(df.case_id) - set(heads.index))
print(meta.column_names)
