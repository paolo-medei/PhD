import sys
import numpy as np
import pandas as pd
sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R
pd.set_option("display.width", 250)
p = pd.read_csv("/home/claude/audit_uga/panel_UGA.csv", dtype={"hhid": str})
b = p[p.track == "B"]
x = b[(b.consumed == 0) & (b[["qty_std", "purch_std", "own_std", "gift_std", "exp"]].notna().any(axis=1))]
print("rows consumed=0 but non-empty qty/exp:", x.groupby(["wave", "product"]).size().to_dict())
it = pd.read_csv("/home/claude/audit_uga/work/rebuild_items_UGA.csv", dtype={"hhid": str})
print("item rows with cons flag != 1 but data:", it[(it.cons != 1) & it[["qh", "vh", "qo", "qg", "qa"]].gt(0).any(axis=1)].groupby(["wave", "product"]).size().to_dict())
# share of purchase value not converted, by product & wave
it["unc_val"] = np.where(it.vh > 0, np.where(it.qh_c > 0, 0, it.vh), 0)
s = it[it.vh > 0].groupby(["wave", "product"]).apply(lambda g: round(g.unc_val.sum() / g.vh.sum(), 3)).unstack()
print("share of home-purchase value with no converted quantity:\n", s.to_string())
milk = it[(it["product"] == "milk") & (it.vh > 0) & ~(it.qh_c > 0)]
print("milk unconverted purchases by unit label:", milk.groupby(["wave", "unit_label"]).size().to_dict())
print("trimmed rows (new rule):", it[it.trim == 1].groupby(["wave", "product"]).size().to_dict())
print(it[it.trim == 1][["wave", "product", "item_label", "unit_label", "qh", "vh", "qo", "med_price"]].to_string())
# 2018 hh referenced by 2019 hhidold but missing from 2018 cover
c5, _ = R.rd("w5", "cover"); c6, _ = R.rd("w6", "cover"); c4, _ = R.rd("w4", "cover")
r5, _ = R.rd("w5", "roster", ["hhid", "t0_hhid"])
ho = c6.hhidold.str.strip()
miss = set(ho[(ho != "") & ~ho.isin(c5.hhid)])
t0r = r5[r5.hhid.isin(miss)].drop_duplicates("hhid")
print("2019 links to 2018 hh absent from 2018 cover:", len(miss), "of which roster t0_hhid in 2015 hhid:", int(t0r.t0_hhid.str.strip().isin(c4.hhid).sum()))
f5, _ = R.rd("w5", "food", ["hhid"])
print("  of these in 2018 food module:", len(miss & set(f5.hhid)))
t0 = c5.t0_hhid.str.strip()
um = c5[~t0.isin(c4.hhid)]
print("2018 unmatched t0_hhid: len5", int((um.t0_hhid.str.strip().str.len() == 5).sum()), "len8", int((um.t0_hhid.str.strip().str.len() == 8).sum()),
      "with panel weight hwgt_W7 (len5/len8):", int(um[um.t0_hhid.str.strip().str.len() == 5].hwgt_W7.notna().sum()), int(um[um.t0_hhid.str.strip().str.len() == 8].hwgt_W7.notna().sum()))
