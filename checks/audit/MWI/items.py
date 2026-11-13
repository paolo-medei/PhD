import sys

import pandas as pd

pd.set_option("display.width", 300)
pd.set_option("display.max_columns", 80)
pd.set_option("display.max_colwidth", 40)
pairs = [x.split(":") for x in sys.argv[1:]]
cache = {}
for w, h in pairs:
    if w not in cache:
        cache[w] = pd.read_pickle(f"/home/claude/audit_mwi/work/items_{w}.pkl")
    g = cache[w]
    sub = g[(g.case_id == h) & (g.g01 == 1)]
    cols = ["wave", "case_id", "item", "conv_region"]
    for q in ["03", "04", "06", "07"]:
        cols += [f"q{q}", f"u{q}", f"t{q}", f"f{q}", f"rule{q}"]
    cols += ["spend", "price", "med", "trim"]
    print(sub[cols].to_string(index=False))
