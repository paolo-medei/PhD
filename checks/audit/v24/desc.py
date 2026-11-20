import sys, pyreadstat
f=sys.argv[1]
nrows=int(sys.argv[2]) if len(sys.argv)>2 else 0
df,m=pyreadstat.read_dta(f,metadataonly=True)
print(f, m.number_rows)
for v in m.column_names:
    lab=m.column_names_to_labels.get(v)
    vl=m.variable_to_label.get(v)
    print(f'  {v:20s} {lab}  [{vl}]')
if nrows:
    for vl,d in m.value_labels.items():
        items=list(d.items())
        print('VL',vl,len(items),items[:nrows])
