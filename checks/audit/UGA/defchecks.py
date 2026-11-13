import sys
import numpy as np
import pandas as pd
import pyreadstat

sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R

pd.set_option("display.width", 250)
p = pd.read_csv("/home/claude/audit_uga/panel_UGA.csv", dtype={"hhid": str, "clusterid": str, "region": str, "urban": str})
hh = p.drop_duplicates(["wave", "hhid"])
print("--- welfare (annual) median by wave, and price base label")
print(hh.groupby("wave").welfare.median().round(0).to_dict())
for w in R.W:
    agg, am = R.rd(w, "agg")
    lab = am.column_names_to_labels
    wf = pd.to_numeric(agg["welfare"], errors="coerce")
    ratio = (wf / (pd.to_numeric(agg["cpexp30"], errors="coerce") / pd.to_numeric(agg["equiv"], errors="coerce")))
    print(w, "cpexp30 label:", lab.get("cpexp30"), "| welfare label:", lab.get("welfare"),
          "| welfare/(cpexp30/equiv) median", round(ratio.median(), 4), "share within 1%", round(((ratio - 1).abs() < 0.01).mean(), 3))

print("--- aggregate hsize vs roster counts")
for w in R.W:
    c = R.W[w]
    agg, am = R.rd(w, "agg")
    if "hsize" not in agg:
        print(w, "no hsize in aggregate")
        continue
    agg["hhid"] = R.idstr(agg[c["ahid"]])
    ros, rm = R.rd(w, "roster")
    ros["rk"] = R.idstr(ros[c["rhid"]])
    if w == "w4":
        cov2, _ = R.rd(w, "cover", ["hhid", "hh"])
        ros["rk"] = ros["rk"].map(cov2.set_index("hhid")["hh"])
    ros["res"] = pd.to_numeric(ros["h2q7"], errors="coerce")
    usual = ros[ros.res.isin([1, 2])].groupby("rk").size()
    ur = ros[ros.res.isin([1, 2, 3, 4])].groupby("rk").size()
    up = ros[ros.res.isin([1, 3])].groupby("rk").size()
    a = agg.drop_duplicates("hhid").set_index("hhid")["hsize"]
    print(w, "hsize==usual(1,2)", round((a == usual.reindex(a.index)).mean(), 3),
          "hsize==usual+regular(1-4)", round((a == ur.reindex(a.index)).mean(), 3),
          "hsize==present(1,3)", round((a == up.reindex(a.index)).mean(), 3), "n", len(a))

print("--- urban coding 2018: s1aq07 vs urban")
cov, cm = R.rd("w5", "cover")
print(pd.crosstab(cov.s1aq07.map(cm.value_labels["s1aq07"]), cov.urban.map(cm.value_labels["urban"])))
for w in ("w3", "w4"):
    cov, cm = R.rd(w, "cover")
    print(w, "urban values", cov.urban.value_counts().to_dict(), "labels", cm.value_labels[cm.variable_to_label["urban"]])

print("--- cluster id collisions 2018/2019 (district_subcounty_parish without county)")
cov, _ = R.rd("w5", "cover")
k = cov.groupby(["district_code", "subcounty_code", "parish_code"]).county_code.nunique()
print("w5 clusters", len(k), "with >1 county", int((k > 1).sum()), "hh in them",
      int(cov.set_index(["district_code", "subcounty_code", "parish_code"]).index.isin(k[k > 1].index).sum()))
print(k[k > 1].head(10))
cov6, _ = R.rd("w6", "cover")
for x in ("dc_2018", "cc_2018", "sc_2018", "pc_2018"):
    cov6[x] = pd.to_numeric(cov6[x], errors="coerce")
k6 = cov6.dropna(subset=["dc_2018", "sc_2018", "pc_2018"]).groupby(["dc_2018", "sc_2018", "pc_2018"]).cc_2018.nunique()
print("w6 clusters", len(k6), "with >1 county", int((k6 > 1).sum()))
print("panel clusters per wave", hh.groupby("wave").clusterid.nunique().to_dict(), "hh per cluster median", hh.groupby(["wave", "clusterid"]).size().groupby("wave").median().to_dict())
# EA codes in w1 vs w2 for the same household
c1, _ = R.rd("w1", "cover", ["HHID", "comm"])
c2, _ = R.rd("w2", "cover", ["HHID", "comm"])
m = c1.merge(c2, on="HHID", suffixes=("_1", "_2"))
print("w1 comm vs w2 comm for same HHID: equal share", (m.comm_1.astype(str) == m.comm_2.astype(str)).mean(), m.head(3).values.tolist())

print("--- weights")
for w in R.W:
    cov, cm = R.rd(w, "cover")
    print(w, {k: v for k, v in cm.column_names_to_labels.items() if k and ("wgt" in k.lower() or "mult" in k.lower() or "weight" in (v or "").lower())})
print("panel hhweight missing hh by wave", hh[hh.hhweight.isna()].groupby("wave").size().to_dict())

print("--- region coding")
print(hh.groupby("wave").region.value_counts(dropna=False).unstack().to_string())
cov, cm = R.rd("w1", "cover")
print("w1 region labels", cm.value_labels[cm.variable_to_label["region"]])

print("--- milk_processed rows in waves where the items do not exist")
print(p[p["product"] == "milk_processed"].groupby("wave").consumed.agg(["size", "sum"]).to_dict())

print("--- poultry & meat_agg quantity coverage")
b = p[(p.track == "B") & (p.consumed == 1)]
print(b.groupby(["wave", "product"]).apply(lambda g: pd.Series({"consumers": len(g), "qty_nonnull": g.qty_std.notna().sum(), "uv_nonnull": g.uv.notna().sum()})).unstack("product").to_string())
