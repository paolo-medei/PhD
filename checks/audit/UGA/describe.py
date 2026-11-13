import sys
import pyreadstat

path = sys.argv[1]
show_vals = len(sys.argv) > 2 and sys.argv[2] == "v"
df, meta = pyreadstat.read_dta(path, metadataonly=True)
print("FILE", path, "nrows", meta.number_rows)
for c in meta.column_names:
    lab = meta.column_names_to_labels.get(c)
    vl = meta.variable_to_label.get(c)
    print(f"  {c:20s} | {lab} | vl={vl}")
    if show_vals and vl and vl in meta.value_labels:
        vals = meta.value_labels[vl]
        if len(vals) <= 400:
            for k, v in vals.items():
                print(f"        {k}: {v}")
