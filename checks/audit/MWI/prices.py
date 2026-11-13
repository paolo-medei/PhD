"""Unit values by item x purchase-unit rule: do the declared conversions agree with the price data?"""
import numpy as np
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_rows", 1000)
rows = []
for w in ["w1", "w2", "w3", "w4"]:
    g = pd.read_pickle(f"/home/claude/audit_mwi/work/items_{w}.pkl")
    g = g[(g.spend > 0) & (g.q04 > 0)].copy()
    g["uv_unit"] = g.spend / g.q04            # price per reported unit
    g["uv_std"] = g.spend / g.c04             # price per std unit after conversion
    g["unitkey"] = np.where(g.u04 == "23", "23:" + g.t04.str.slice(0, 18), g.u04)
    rows.append(g)
g = pd.concat(rows)
anchor_rule = {501: "egg_piece", 701: "l"}
out = []
for (w, it), sub in g.groupby(["wave", "item"]):
    a_rule = anchor_rule.get(it, "kg")
    anchor = sub[sub.rule04 == a_rule].uv_std.median()
    n_anchor = (sub.rule04 == a_rule).sum()
    for (rule, uk), s2 in sub.groupby(["rule04", "unitkey"]):
        if len(s2) < 3 and rule not in ("table", "os_whole", "os_sachet", "os_tray"):
            continue
        out.append(dict(wave=w, item=it, rule=rule, unit=uk, n=len(s2), med_price_per_unit=s2.uv_unit.median(),
                        med_price_std=s2.uv_std.median(), anchor_rule=a_rule, anchor_med=anchor, n_anchor=n_anchor,
                        ratio_to_anchor=s2.uv_std.median() / anchor if anchor else np.nan,
                        implied_std_per_unit=s2.uv_unit.median() / anchor if anchor else np.nan,
                        share_trimmed=s2.trim.mean()))
o = pd.DataFrame(out)
o.to_csv("/home/claude/audit_mwi/work/unit_values.csv", index=False)
print(o[o.n >= 3].to_string(index=False, float_format=lambda x: f"{x:.4g}"))
