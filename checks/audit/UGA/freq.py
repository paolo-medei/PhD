import sys
import pyreadstat
import pandas as pd

path, itemvar, unitvar = sys.argv[1], sys.argv[2], sys.argv[3]
codes = [int(x) for x in sys.argv[4].split(",")] if len(sys.argv) > 4 else None
df, meta = pyreadstat.read_dta(path)
il = meta.value_labels.get(meta.variable_to_label.get(itemvar), {})
ul = meta.value_labels.get(meta.variable_to_label.get(unitvar), {})
if codes:
    df = df[df[itemvar].isin(codes)]
print("rows", len(df))
g = df.groupby([itemvar, unitvar], dropna=False).size().reset_index(name="n")
for _, r in g.iterrows():
    it = r[itemvar]
    un = r[unitvar]
    print(f"{it!s:8} {il.get(it, '?')[:30]:30s} unit={un!s:8} {str(ul.get(un, '?'))[:30]:30s} n={r['n']}")
