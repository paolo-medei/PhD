import sys
import pyreadstat
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
path = sys.argv[1]
cols = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] else None
n = int(sys.argv[3]) if len(sys.argv) > 3 else 8
df, meta = pyreadstat.read_dta(path, usecols=cols)
print(df.head(n).to_string())
print(df.dtypes.to_string())
for c in df.columns:
    nu = df[c].nunique(dropna=False)
    print(f"{c}: nunique={nu} nnull={df[c].isna().sum()}", (df[c].value_counts(dropna=False).head(12).to_dict() if nu < 40 else ""))
