import sys
import pandas as pd

sys.path.insert(0, "/home/claude/audit_mwi/work")
from load import load_g1, ITEMS  # noqa: E402

rows = []
for w in ["w1", "w2", "w3", "w4"]:
    g, meta = load_g1(w)
    print(w, "rows", len(g), "hh", g.case_id.nunique(), "g01 values", g.g01.value_counts(dropna=False).to_dict())
    print(w, "items per hh", g.groupby("case_id").size().describe().to_dict())
    g = g[g.item.isin(ITEMS)]
    print(w, "dup hh-item", g.duplicated(["case_id", "item"]).sum())
    # u vs ul agreement
    for q in ["03", "04", "06", "07"]:
        if f"ul{q}" in g:
            a = pd.to_numeric(g[f"u{q}"].str.extract(r"^(\d+)")[0], errors="coerce")
            dis = g[(a.fillna(-1) != g[f"ul{q}"].fillna(-1))]
            if len(dis):
                print(w, q, "u vs ul disagree", len(dis), dis[[f"u{q}", f"ul{q}"]].value_counts().head(10).to_dict())
    for q in ["03", "04", "06", "07"]:
        t = g[(g[f"q{q}"].fillna(0) != 0) | (g[f"u{q}"] != "")]
        vc = t.groupby(["item", f"u{q}", f"t{q}"]).size().reset_index(name="n")
        vc["wave"] = w
        vc["q"] = q
        vc = vc.rename(columns={f"u{q}": "unit", f"t{q}": "text"})
        rows.append(vc)
r = pd.concat(rows)
r.to_csv("/home/claude/audit_mwi/work/unit_dump.csv", index=False)
pd.set_option("display.width", 250)
pd.set_option("display.max_rows", 2000)
pv = r.groupby(["item", "unit", "wave"]).n.sum().unstack("wave").fillna(0).astype(int)
print(pv.to_string())
