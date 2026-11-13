"""Independent rebuild of panel_UGA.csv from the raw UNPS Stata files.

Run with: python -I rebuild.py
Writes /home/claude/audit_uga/work/rebuild_UGA.csv and rebuild_items_UGA.csv
"""
import re
import sys
import numpy as np
import pandas as pd
import pyreadstat

D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"
# RULE: "eggs" = original SPEC.md; "all" = + general 10x/0.1x outlier rule; "v3" = + revised spec
# (Nice cup = 0.5 l, egg x30 / /30 rescaling, consumed from data, roster rules, clusters with county,
#  Kampala -> Central, milk_processed only 2018-19). Default v3.
RULE = sys.argv[1] if len(sys.argv) > 1 else "v3"
V3 = RULE == "v3"
SUFFIX = "" if V3 else "_" + RULE
OUT = "/home/claude/audit_uga/work/"

W = {
    "w1": dict(year=2010, base="UGA_2010_UNPS_v03_M_STATA12/",
               food="GSEC15b.dta", fhid="hh", item="itmcd", unit="untcd", cons="h15bq3a",
               q=("h15bq4", "h15bq6", "h15bq8", "h15bq10"), v=("h15bq5", "h15bq7", "h15bq9", "h15bq11"),
               cover="GSEC1.dta", chid="HHID", roster="GSEC2.dta", rhid="HHID",
               agg="pov2010_11.dta", ahid="hh"),
    "w2": dict(year=2011, base="UGA_2011_UNPS_v02_M_Stata/",
               food="GSEC15B.dta", fhid="HHID", item="itmcd", unit="untcd", cons="h15bq3a",
               q=("h15bq4", "h15bq6", "h15bq8", "h15bq10"), v=("h15bq5", "h15bq7", "h15bq9", "h15bq11"),
               cover="GSEC1.dta", chid="HHID", roster="GSEC2.dta", rhid="HHID",
               agg="UNPS 2011-12 Consumption Aggregate.dta", ahid="HHID"),
    "w3": dict(year=2013, base="UGA_2013_UNPS_v02_M_STATA14/",
               food="Stata/GSEC15B.dta", fhid="hhid", item="itmcd", unit="untcd", cons="h15bq3a",
               q=("h15bq4", "h15bq6", "h15bq8", "h15bq10"), v=("h15bq5", "h15bq7", "h15bq9", "h15bq11"),
               cover="Stata/GSEC1.dta", chid="hhid", roster="Stata/GSEC2.dta", rhid="hhid",
               agg="pov2013_14.dta", ahid="hhid"),
    "w4": dict(year=2015, base="UGA_2015_UNPS_v02_M_STATA14/",
               food="household/gsec15b.dta", fhid="hh", item="itmcd", unit="untcd", cons="h15bq3a",
               q=("h15bq4", "h15bq6", "h15bq8", "h15bq10"), v=("h15bq5", "h15bq7", "h15bq9", "h15bq11"),
               cover="household/gsec1.dta", chid="hh", roster="household/gsec2.dta", rhid="hhid",
               agg="pov2015_16.dta", ahid="hh"),
    "w5": dict(year=2018, base="UGA_2018_UNPS_v02_M_STATA14/",
               food="HH/GSEC15B.dta", fhid="hhid", item="CEB01", unit="CEB03C", cons="CEB03",
               q=("CEB06", "CEB08", "CEB10", "CEB012"), v=("CEB07", "CEB09", "CEB11", "CEB013"),
               cover="HH/GSEC1.dta", chid="hhid", roster="HH/GSEC2.dta", rhid="hhid",
               agg="pov2018_19.dta", ahid="hhid"),
    "w6": dict(year=2019, base="UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/",
               food="HH/gsec15b.dta", fhid="hhid", item="CEB01", unit="CEB03C", cons="CEB03",
               q=("CEB06", "CEB08", "CEB10", "CEB012"), v=("CEB07", "CEB09", "CEB11", "CEB013"),
               cover="HH/gsec1.dta", chid="hhid", roster="HH/gsec2.dta", rhid="hhid",
               agg="pov2019_20.dta", ahid="hhid"),
}

# Track-B products: item codes (checked against each wave's value labels below)
PRODUCTS = {
    "beef": [117, 1171, 1172, 1173],          # Beef (+ liver/offal/roasted, 2018-19 codes; absent in data)
    "pork": [118, 1181, 1182],                # Pork (118 is an empty header row in 2018-19; 1181 holds the data)
    "goat_sheep": [119, 1191, 1192, 1193],    # Goat meat
    "poultry": [121, 1211, 1212, 1213, 1214, 1215],  # all chicken items
    "eggs": [124, 1241, 1242, 1243],
    "milk": [125],                            # fresh milk
    "milk_processed": [1252, 1254],           # fermented milk, yoghurt
    "coffee": [148, 1481, 1482],
}
STD = {"beef": "kg", "pork": "kg", "goat_sheep": "kg", "poultry": "kg", "eggs": "piece", "milk": "litre",
       "milk_processed": "litre", "coffee": "kg", "meat_agg": "kg"}
ITEM2PROD = {c: p for p, cs in PRODUCTS.items() for c in cs}
LIQUID = {"milk", "milk_processed"}
MEATS = {"beef", "pork", "goat_sheep", "poultry"}


def rd(w, key, cols=None):
    df, meta = pyreadstat.read_dta(D + W[w]["base"] + W[w][key], usecols=cols)
    return df, meta


def idstr(s):
    """Household id to exact string (float ids are integers < 2^53)."""
    if s.dtype.kind == "f":
        return s.map(lambda v: str(int(v)) if pd.notna(v) else None)
    return s.astype(str).str.strip()


def unit_factor(label, product):
    """Conversion factor to the product's standard unit, from the unit LABEL. None = not converted."""
    if not isinstance(label, str) or product == "coffee":
        return None
    l = label.strip().lower()
    if product == "eggs":
        if l.startswith("number of units") or l.startswith("piece"):
            return 1.0
        if l.startswith("tray of 30"):
            return 30.0
        return None
    if l == "kilogram (kg)":
        return 1.0
    if l == "gram":
        return 0.001
    if l == "litre":
        return 1.0 if product in LIQUID else None
    m = re.fullmatch(r"packet\s*\(\s*([\d.]+)\s*(kg|g)\s*\)", l)
    if m:
        x = float(m.group(1))
        return x if m.group(2) == "kg" else x / 1000.0
    m = re.fullmatch(r"sacket\s*\(\s*([\d.]+)\s*g\s*\)", l)
    if m:
        return float(m.group(1)) / 1000.0
    if re.fullmatch(r"nido tin\s*\(\s*400\s*g\s*\)", l):
        return 0.4
    if V3 and product == "milk" and l.startswith("nice cup"):
        return 0.5  # revised spec 1: milk "Nice cup" (any size) = 0.5 litre
    if product in LIQUID:
        if re.fullmatch(r"cup/mug\s*\(\s*0\.5\s*lt\s*\)", l):
            return 0.5
        if re.fullmatch(r"glass\s*\(\s*0\.25\s*lt\s*\)", l):
            return 0.25
    return None


def load_food(w):
    c = W[w]
    df, meta = rd(w, "food")
    ilab = meta.value_labels[meta.variable_to_label[c["item"]]]
    ulab = meta.value_labels[meta.variable_to_label[c["unit"]]]
    df["hhid"] = idstr(df[c["fhid"]])
    df["item"] = pd.to_numeric(df[c["item"]], errors="coerce")
    df["unit"] = pd.to_numeric(df[c["unit"]], errors="coerce")
    df["item_label"] = df["item"].map(lambda x: ilab.get(x, ilab.get(int(x), None)) if pd.notna(x) else None)
    df["unit_label"] = df["unit"].map(lambda x: ulab.get(x, ulab.get(int(x), None)) if pd.notna(x) else None)
    df["cons"] = pd.to_numeric(df[c["cons"]], errors="coerce")
    for k, col in zip(("qh", "qa", "qo", "qg"), c["q"]):
        df[k] = pd.to_numeric(df[col], errors="coerce")
    for k, col in zip(("vh", "va", "vo", "vg"), c["v"]):
        df[k] = pd.to_numeric(df[col], errors="coerce")
    allhh = df["hhid"].dropna().unique()
    df["product"] = df["item"].map(ITEM2PROD)
    it = df[df["product"].notna()].copy()
    it["wave"] = w
    it = it[["wave", "hhid", "item", "item_label", "product", "unit", "unit_label", "cons",
             "qh", "vh", "qa", "va", "qo", "vo", "qg", "vg"]]
    return it, allhh, ilab


def convert(it):
    it = it.copy()
    it["f"] = [unit_factor(l, p) for l, p in zip(it["unit_label"], it["product"])]
    it["f"] = it["f"].astype(float)
    for k in ("qh", "qa", "qo", "qg"):
        it[k + "_c"] = it[k] * it["f"]
    tot = it[["qh", "qa", "qo", "qg"]].sum(axis=1, min_count=1)
    it["qt_c"] = tot * it["f"]
    # Price outlier rule (RULE):
    #  "eggs" = original SPEC: eggs only, price > 10 x wave median price per egg
    #  "all"  = updated spec: every product, price > 10 x or < 0.1 x the wave median price of that
    #           product (median over the wave's item rows of the product with value>0 and conv qty>0)
    # A trimmed item row has ALL its converted quantities emptied.
    it["trim"] = 0
    it["rescale"] = 1.0
    it["med_price"] = np.nan
    qcols = ["qh_c", "qa_c", "qo_c", "qg_c", "qt_c"]
    prods = ["eggs"] if RULE == "eggs" else sorted(it["product"].unique())
    for (w, p), g in it[it["product"].isin(prods)].groupby(["wave", "product"]):
        ok = (g["vh"] > 0) & (g["qh_c"] > 0)
        if not ok.any():
            continue
        pr = g.loc[ok, "vh"] / g.loc[ok, "qh_c"]
        med = pr.median()  # computed once, before any rescaling
        it.loc[g.index, "med_price"] = med
        if V3 and p == "eggs":
            # revised spec 2: trays recorded as pieces (x30) / pieces recorded as trays (/30)
            up = pr[(pr > 10 * med) & (pr / 30 > med / 3) & (pr / 30 < 3 * med)].index
            dn = pr[(pr < med / 10) & (pr * 30 > med / 3) & (pr * 30 < 3 * med)].index
            it.loc[up, qcols] = it.loc[up, qcols] * 30
            it.loc[dn, qcols] = it.loc[dn, qcols] / 30
            it.loc[up, "rescale"] = 30.0
            it.loc[dn, "rescale"] = 1 / 30
            pr = it.loc[pr.index, "vh"] / it.loc[pr.index, "qh_c"]
            print("v3", w, "eggs rescaled x30:", len(up), " /30:", len(dn))
        bad = pr[(pr > 10 * med) | ((pr < med / 10) if RULE != "eggs" else False)].index
        it.loc[bad, "trim"] = 1
        it.loc[bad, ["qh_c", "qa_c", "qo_c", "qg_c", "qt_c"]] = np.nan
        print(RULE, w, p, "median price", med, "n", int(ok.sum()), "trimmed", len(bad),
              "high", int((pr > 10 * med).sum()), "low", int((pr < med / 10).sum()))
    return it


def possum(s):
    s = s[s > 0]
    return s.sum() if len(s) else np.nan


def aggregate(it, prodname):
    it = it.assign(cons_any=(it["cons"] == 1) | (V3 & (it[["qh", "qa", "qo", "qg", "vh"]].gt(0).any(axis=1))))
    g = it.groupby(["wave", "hhid"])
    out = pd.DataFrame({
        "consumed": g["cons_any"].apply(lambda s: int(s.any())),
        "qty_std": g["qt_c"].apply(possum),
        "purch_std": g["qh_c"].apply(possum),
        "own_std": g["qo_c"].apply(possum),
        "gift_std": g["qg_c"].apply(possum),
        "exp": g["vh"].apply(possum),
    })
    conv = it[it["qh_c"] > 0]
    out["exp_conv"] = conv.groupby(["wave", "hhid"])["vh"].apply(possum).reindex(out.index)
    it2 = it.assign(uc=((it["vh"] > 0) & ~(it["qh_c"] > 0)).astype(int))
    out["unconv"] = it2.groupby(["wave", "hhid"])["uc"].max().reindex(out.index)
    out["product"] = prodname
    return out.reset_index()


def household_vars(w):
    c = W[w]
    # ---- cover page
    cov, cm = rd(w, "cover")
    cov["hhid"] = idstr(cov[c["chid"]])
    ulab = cm.value_labels[cm.variable_to_label["urban"]]
    cov["urban_lab"] = pd.to_numeric(cov["urban"], errors="coerce").map(ulab)
    cov["urban_s"] = np.where(cov["urban_lab"].astype(str).str.strip().str.lower() == "urban", "1", "0")
    cov.loc[cov["urban_lab"].isna(), "urban_s"] = None
    reg = pd.to_numeric(cov["region"], errors="coerce")
    if V3 and w == "w1":
        rl = cm.value_labels[cm.variable_to_label["region"]]
        kla = [k for k, v in rl.items() if v.strip().lower() == "kampala"]
        cen = [k for k, v in rl.items() if v.strip().lower() == "central"]
        reg = reg.replace({kla[0]: cen[0]})  # revised spec 6: Kampala (0) -> Central (1)
    cov["region_s"] = reg.map(lambda v: str(int(v)) if pd.notna(v) else None)
    if w in ("w1", "w2"):
        cov["cluster_s"] = cov["comm"].astype(str).str.strip() if cov["comm"].dtype.kind in "OSU" or str(cov["comm"].dtype) == "str" else pd.to_numeric(cov["comm"]).map(lambda v: str(int(v)) if pd.notna(v) else None)
    elif w in ("w3", "w4"):
        cov["cluster_s"] = pd.to_numeric(cov["ea"], errors="coerce").map(lambda v: str(int(v)) if pd.notna(v) else None)
    else:
        if V3:  # revised spec 5: include the county code
            cols = ("district_code", "county_code", "subcounty_code", "parish_code") if w == "w5" else ("dc_2018", "cc_2018", "sc_2018", "pc_2018")
        else:
            cols = ("district_code", "subcounty_code", "parish_code") if w == "w5" else ("dc_2018", "sc_2018", "pc_2018")
        parts = [pd.to_numeric(cov[x], errors="coerce").map(lambda v: str(int(v)) if pd.notna(v) else None) for x in cols]
        cov["cluster_s"] = [None if any(not isinstance(p, str) for p in t) else "_".join(t) for t in zip(*parts)]
    wcol = {"w1": "wgt10", "w2": "mult", "w3": "wgt_X", "w4": "h_xwgt_W5", "w5": "wgt", "w6": "wgt"}[w]
    cov["hhweight"] = pd.to_numeric(cov[wcol], errors="coerce")
    covv = cov[["hhid", "region_s", "urban_s", "cluster_s", "hhweight"]].rename(
        columns={"region_s": "region", "urban_s": "urban", "cluster_s": "clusterid"})
    # ---- roster
    ros, rm = rd(w, "roster")
    ros["rk"] = idstr(ros[c["rhid"]])
    if w == "w4":  # roster keyed by the 8-char hhid; map to the 'hh' id used in the food module
        cov2, _ = rd(w, "cover", ["hhid", "hh"])
        ros["rk"] = ros["rk"].map(cov2.set_index("hhid")["hh"])
    sexlab = rm.value_labels[rm.variable_to_label["h2q3"]]
    female_code = [k for k, v in sexlab.items() if v.strip().lower() == "female"]
    assert len(female_code) == 1, sexlab
    reslab = rm.value_labels[rm.variable_to_label["h2q7"]]
    mem_codes = [k for k, v in reslab.items() if re.match(r"(usual|regular) member (present|absent)$", v.strip().lower())]
    assert len(mem_codes) == 4, reslab
    ros["res"] = pd.to_numeric(ros["h2q7"], errors="coerce")
    ros["age"] = pd.to_numeric(ros["h2q8"], errors="coerce")
    ros["rel"] = pd.to_numeric(ros["h2q4"], errors="coerce")
    ros["sex"] = pd.to_numeric(ros["h2q3"], errors="coerce")
    ros["line"] = pd.to_numeric(ros["h2q1"] if "h2q1" in ros else ros["pid"], errors="coerce")
    usual_codes = [k for k, v in reslab.items() if re.match(r"usual member (present|absent)$", v.strip().lower())]
    assert len(usual_codes) == 2, reslab
    ros["order"] = np.arange(len(ros))  # order of listing in the roster file
    mem = ros[ros["res"].isin(mem_codes)].copy()
    g = mem.groupby("rk")
    den = g["age"].count() if V3 else g.size()  # revised spec 4: members of known age
    rv = pd.DataFrame({
        "n_mem": g.size(),
        "n_usual": ros[ros["res"].isin(usual_codes)].groupby("rk").size(),
        "share_child": g["age"].apply(lambda a: (a < 15).sum()) / den.where(den > 0),
        "share_elderly": g["age"].apply(lambda a: (a >= 60).sum()) / den.where(den > 0),
    })
    heads = mem[mem["rel"] == 1].sort_values(["rk", "order" if V3 else "line"])
    nheads = heads.groupby("rk").size()
    h1 = heads.drop_duplicates("rk").set_index("rk")
    rv["head_age"] = h1["age"]
    rv["head_female"] = (h1["sex"] == female_code[0]).astype(float).where(h1["sex"].notna())
    rv["n_heads"] = nheads
    rv.index.name = "hhid"
    rv = rv.reset_index()
    # ---- consumption aggregate
    agg, am = rd(w, "agg")
    agg["hhid"] = idstr(agg[c["ahid"]])
    av = pd.DataFrame({"hhid": agg["hhid"], "welfare": pd.to_numeric(agg["welfare"], errors="coerce") * 12,
                       "adulteq": pd.to_numeric(agg["equiv"], errors="coerce")})
    av["hhsize_agg"] = pd.to_numeric(agg["hsize"], errors="coerce") if "hsize" in agg else np.nan
    ndup = av.duplicated("hhid").sum()
    if ndup:
        print(w, "aggregate exact-duplicate rows dropped:", ndup)
    av = av.drop_duplicates("hhid")
    hv = covv.merge(rv, on="hhid", how="outer").merge(av, on="hhid", how="outer")
    if w != "w2":
        hv["hhsize"] = hv["hhsize_agg"]
    else:  # aggregate has no hsize: roster count (v3: USUAL members only, present or absent)
        hv["hhsize"] = hv["n_usual"] if V3 else hv["n_mem"]
    hv["wave"] = w
    return hv


def main():
    items, hh_all, rows = [], {}, []
    for w in W:
        it, allhh, ilab = load_food(w)
        # print the labels of the chosen item codes (selection by label)
        for p, cs in PRODUCTS.items():
            print(w, p, [(k, ilab.get(k, "-")) for k in cs if k in ilab])
        items.append(it)
        hh_all[w] = allhh
    it = convert(pd.concat(items, ignore_index=True))
    it.to_csv(OUT + "rebuild_items_UGA" + SUFFIX + ".csv", index=False)
    pieces = []
    for p in PRODUCTS:
        sub = it[it["product"] == p]
        a = aggregate(sub, p)
        a["track"] = "B"
        pieces.append(a)
        if p in ("milk", "eggs", "coffee"):
            pieces.append(a.assign(track="A"))
    meat = it[it["product"].isin(MEATS)]
    a = aggregate(meat, "meat_agg")
    a["track"] = "A"
    pieces.append(a)
    prod = pd.concat(pieces, ignore_index=True)
    # full grid: every food-module household x every product of its track
    grid = []
    for w, hhs in hh_all.items():
        bl = [x for x in PRODUCTS if not (V3 and x == "milk_processed" and w in ("w1", "w2", "w3", "w4"))]
        for tr, plist in (("B", bl), ("A", ["meat_agg", "milk", "eggs", "coffee"])):
            grid.append(pd.MultiIndex.from_product([[w], hhs, plist, [tr]], names=["wave", "hhid", "product", "track"]).to_frame(index=False))
    grid = pd.concat(grid, ignore_index=True)
    panel = grid.merge(prod, on=["wave", "hhid", "product", "track"], how="left")
    panel["consumed"] = panel["consumed"].fillna(0).astype(int)
    panel["unconv"] = panel["unconv"].fillna(0).astype(int)
    panel["uv"] = np.where((panel["exp_conv"] > 0) & (panel["purch_std"] > 0), panel["exp_conv"] / panel["purch_std"], np.nan)
    panel["std"] = panel["product"].map(STD)
    hv = pd.concat([household_vars(w) for w in W], ignore_index=True)
    panel = panel.merge(hv, on=["wave", "hhid"], how="left")
    panel["year"] = panel["wave"].map({w: W[w]["year"] for w in W})
    panel["country"] = "UGA"
    panel.to_csv(OUT + "rebuild_UGA" + SUFFIX + ".csv", index=False)
    hv.to_csv(OUT + "rebuild_hh_UGA.csv", index=False)
    print(panel.groupby(["wave", "track"]).size())


if __name__ == "__main__":
    main()
