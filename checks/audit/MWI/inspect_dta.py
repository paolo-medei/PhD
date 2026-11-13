import sys
import pyreadstat

path = sys.argv[1]
nrows = int(sys.argv[2]) if len(sys.argv) > 2 else 0
df, meta = pyreadstat.read_dta(path, metadataonly=(nrows == 0), row_limit=nrows if nrows else 0)
print("FILE", path, "nrows", meta.number_rows)
for c in meta.column_names:
    lab = meta.column_names_to_labels.get(c)
    vl = meta.variable_to_label.get(c)
    print(f"{c}\t{lab}\t[{vl}]")
if len(sys.argv) > 3:
    for vname in sys.argv[3].split(","):
        vl = meta.variable_to_label.get(vname)
        if vl:
            print("VALUE LABELS", vname, vl)
            for k, v in meta.value_labels[vl].items():
                print("   ", repr(k), "=", v)
