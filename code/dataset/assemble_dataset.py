#!/usr/bin/env python3
"""
HARMONIZED HOUSEHOLD DATASET ON PROTEIN-RICH FOODS: wide table and workbook (v1, 23 Nov 2026)

Takes the outputs of
  build_protein_dataset.R  long_<CC>.csv.gz (household x item), module_households.csv, build_log.csv
  hh_info.R                hh_info.csv (household variables used in Step I)
  unit_codes.R             unit_codes.csv (unit codes and labels of each round)
and writes
  <out>/ASF_protein_household_dataset_<date>.xlsx   one row per country x round x household, plus documentation
  <out>/ASF_protein_household_dataset_<date>.csv.gz the same Final_Household_Dataset sheet, for R or Stata

Rules: nothing is deleted or corrected. Raw answers are kept next to the harmonized values.
Not consumed = 0, consumed but not convertible or not reported = empty (NA), item not in that
round's questionnaire = empty (see Comparability_Matrix). No NA is turned into 0.

USE  python3 assemble_dataset.py <build dir> <item_map.csv> <panels dir> <wdi_gdp_pc_ppp.csv> <out dir>
"""
import csv, datetime, difflib, gzip, math, os, re, sys, time
import numpy as np
import pandas as pd
import xlsxwriter

BUILD, MAPF, PANELS, GDPF, OUTD = sys.argv[1:6]
os.makedirs(OUTD, exist_ok=True)
TODAY = datetime.date.today().isoformat()
XLSX = os.path.join(OUTD, f"ASF_protein_household_dataset_{TODAY}.xlsx")
CSVF = os.path.join(OUTD, f"ASF_protein_household_dataset_{TODAY}.csv.gz")
T0 = time.time()

COUNTRIES = ["ETH", "TZA", "MWI", "NGA", "UGA"]
SURVEY = {"ETH": "ERSS/ESS/ESPS", "TZA": "NPS", "MWI": "IHS", "NGA": "GHS-Panel, post-harvest visit", "UGA": "UNPS"}
CURRENCY = {"ETH": "ETB", "TZA": "TZS", "MWI": "MWK", "NGA": "NGN", "UGA": "UGX"}
ROUND_NAME = {
    ("ETH", 2011): "ERSS wave 1, 2011/12", ("ETH", 2013): "ESS wave 2, 2013/14", ("ETH", 2015): "ESS wave 3, 2015/16",
    ("ETH", 2018): "ESS wave 4, 2018/19", ("ETH", 2021): "ESPS wave 5, 2021/22",
    ("TZA", 2008): "NPS round 1, 2008/09", ("TZA", 2010): "NPS round 2, 2010/11", ("TZA", 2012): "NPS round 3, 2012/13",
    ("TZA", 2014): "NPS round 4, 2014/15", ("TZA", 2020): "NPS round 5, 2020/21",
    ("MWI", 2010): "IHS3, 2010/11", ("MWI", 2016): "IHS4, 2016/17", ("MWI", 2019): "IHS5, 2019/20", ("MWI", 2024): "IHS6, 2024/25",
    ("NGA", 2010): "GHS-Panel wave 1, 2010/11", ("NGA", 2012): "GHS-Panel wave 2, 2012/13", ("NGA", 2015): "GHS-Panel wave 3, 2015/16",
    ("UGA", 2010): "UNPS 2010/11", ("UGA", 2011): "UNPS 2011/12", ("UGA", 2013): "UNPS 2013/14", ("UGA", 2015): "UNPS 2015/16",
    ("UGA", 2018): "UNPS 2018/19", ("UGA", 2019): "UNPS 2019/20"}
FOOD_FILE = {
    ("ETH", 2011): "sect5a_hh_w1", ("ETH", 2013): "sect5a_hh_w2", ("ETH", 2015): "sect5a_hh_w3", ("ETH", 2018): "sect6a_hh_w4", ("ETH", 2021): "sect6a_hh_w5",
    ("TZA", 2008): "SEC_K1", ("TZA", 2010): "HH_SEC_K1", ("TZA", 2012): "HH_SEC_J1", ("TZA", 2014): "hh_sec_j1", ("TZA", 2020): "hh_sec_ja1 + hh_sec_j1",
    ("MWI", 2010): "hh_mod_g1", ("MWI", 2016): "hh_mod_g1", ("MWI", 2019): "hh_mod_g1", ("MWI", 2024): "hh_mod_g1",
    ("NGA", 2010): "sect10b_harvestw1", ("NGA", 2012): "sect10b_harvestw2", ("NGA", 2015): "sect10b_harvestw3",
    ("UGA", 2010): "GSEC15b", ("UGA", 2011): "GSEC15B", ("UGA", 2013): "GSEC15B", ("UGA", 2015): "gsec15b", ("UGA", 2018): "GSEC15B", ("UGA", 2019): "gsec15b"}
CONV_TABLE = {"ETH": "Food_CF_Wave1-5 (national mean factor by item and unit)", "TZA": "none (metric codes 1-5 only)",
              "MWI": "ihs_foodconversion_factor_2020 (by region, item, unit)", "NGA": "food_conv_w2ph / food_conv_w3 (2012, 2015); none in 2010",
              "UGA": "none (metric content of the unit label)"}
ONLY_CONSUMED = {("NGA", 2010), ("UGA", 2010), ("UGA", 2011), ("UGA", 2013), ("UGA", 2015)}

# ------------------------------------------------------------------------------------------
# 1. item map: harmonized items (slots) and their categories
# ------------------------------------------------------------------------------------------
MAP = pd.read_csv(MAPF)
MAP["round"] = MAP["year"].apply(lambda y: int(math.floor(y)))
SLOT = MAP.drop_duplicates("slot").set_index("slot")[["cat", "sub", "in_total"]]
STD = MAP.drop_duplicates(["country", "slot"]).set_index(["country", "slot"])["std"].to_dict()
UNIT_SFX = {"kg": "kg", "litre": "l", "piece": "pc"}
CAT_ORDER = ["meat", "fish", "eggs", "dairy", "plant", "asf_mixed"]
SUB_ORDER = ["red", "white", "minor", "processed", "mixed", "fresh", "dried_smoked_salted", "canned_packaged", "fish_product",
             "unspecified", "eggs", "milk_fresh", "milk_powder_tinned", "yoghurt_fermented", "cheese", "butter_ghee",
             "milk_products", "ice_cream", "fats_mixed", "infant_formula", "pulses", "pulses_processed", "soy", "pulses_fresh",
             "groundnuts", "nuts", "seeds", "pulse_nut_other", "nuts_low_protein", "meat_or_fish_tinned", "other_specify",
             "prepared_vendor"]
first_seen = {s: i for i, s in enumerate(MAP["slot"].drop_duplicates())}
SLOTS = sorted(SLOT.index, key=lambda s: (CAT_ORDER.index(SLOT.at[s, "cat"]), SUB_ORDER.index(SLOT.at[s, "sub"]), first_seen[s]))
ROUNDS = sorted({(c, int(y)) for c, y in zip(MAP.country, MAP["round"])}, key=lambda r: (COUNTRIES.index(r[0]), r[1]))
ASKED = MAP.groupby(["country", "round"])["slot"].apply(set).to_dict()

# ------------------------------------------------------------------------------------------
# 2. item variables, harmonized and raw, in the order they appear for each item
# ------------------------------------------------------------------------------------------
SRC = ["tot", "pur", "own", "gift", "away", "frompur"]
SRC_LABEL = {"tot": "total consumed", "pur": "purchased", "own": "own production", "gift": "gifts and other sources",
             "away": "purchased and consumed away from home (Uganda)", "frompur": "consumed out of purchases (Nigeria 2012-2015)"}
HARM = ["cons", "exp"] + [f"qty_{s}_{u}" for s in SRC for u in ["kg", "l", "pc"]] + ["flag"]
RAW = [("raw_cons", "cons_raw")]
for s in ["tot", "pur", "own", "gift"]:
    RAW += [(f"raw_q_{s}", f"q_{s}"), (f"raw_unit_{s}", f"u_{s}"), (f"raw_unit_other_{s}", f"uo_{s}"), (f"raw_unit_size_{s}", f"us_{s}")]
    if s == "pur":
        RAW += [("raw_exp_pur", "exp_pur")]
RAW += [("raw_q_away", "q_away"), ("raw_val_away", "val_away"), ("raw_val_own", "val_own"), ("raw_val_gift", "val_gift"),
        ("raw_q_frompur", "q_frompur"), ("raw_unit_frompur", "u_frompur"), ("raw_q_weight", "q_wt"), ("raw_unit_weight", "u_wt")]
TEXT_RAW = {"u_tot", "u_pur", "u_own", "u_gift", "uo_tot", "uo_pur", "uo_own", "uo_gift", "us_tot", "us_pur", "us_own", "us_gift", "u_frompur", "u_wt"}
NUM_RAW = [c for _, c in RAW if c not in TEXT_RAW]
ITEMVARS = HARM + [n for n, _ in RAW]
RAWSRC = dict(RAW)


def read_long(cc):
    dt = {c: str for c in TEXT_RAW | {"hhid", "slot", "conv_method"}}
    L = pd.read_csv(os.path.join(BUILD, f"long_{cc}.csv.gz"), dtype=dt, low_memory=False, keep_default_na=False, na_values=[""])
    L["year"] = L["year"].astype(float).astype(int)
    for c in NUM_RAW + ["s_tot", "s_pur", "s_own", "s_gift", "s_away", "s_frompur", "cons", "exp", "flag", "code"]:
        if c not in L.columns:
            L[c] = np.nan
        L[c] = pd.to_numeric(L[c], errors="coerce")
    if cc == "UGA":                      # one unit for all sources: kept once, in raw_unit_tot
        for c in ["u_pur", "u_own", "u_gift"]:
            L[c] = np.nan
    L["flag"] = L["flag"].where(L["cons"] == 1)          # the checks apply to consumed items only
    L["std"] = [STD[(cc, s)] for s in L["slot"]]
    L["cat"] = L["slot"].map(SLOT["cat"]); L["sub"] = L["slot"].map(SLOT["sub"]); L["in_total"] = L["slot"].map(SLOT["in_total"])
    for s in SRC:
        for u, sfx in UNIT_SFX.items():
            L[f"qty_{s}_{sfx}"] = L[f"s_{s}"].where(L["std"] == u)
    for n, c in RAW:
        L[n] = L[c]
    return L


# ------------------------------------------------------------------------------------------
# 3. household variables
# ------------------------------------------------------------------------------------------
H = pd.read_csv(os.path.join(BUILD, "hh_info.csv"), dtype={"hhid": str, "panel_id": str, "region": str, "zone": str, "woreda": str,
                                                          "state": str, "lga": str, "cluster": str, "strata": str, "urban_code": str, "wave": str},
                keep_default_na=False, na_values=[""], low_memory=False)
H["year"] = H["year"].astype(int)
MOD = pd.read_csv(os.path.join(BUILD, "module_households.csv"), dtype={"hhid": str, "module": str}, keep_default_na=False, na_values=[""])
MOD["year"] = MOD["year"].astype(int)
H = H.merge(MOD.rename(columns={"n_item_rows": "n_food_items_module", "module": "food_module_tza"}), on=["country", "year", "hhid"], how="outer", indicator=True)
assert (H["_merge"] == "both").all(), H["_merge"].value_counts()
H = H.drop(columns="_merge")
GDP = pd.read_csv(GDPF).rename(columns={"gdp_pc_ppp_const2021": "gdp_pc_ppp_const2021"})
H = H.merge(GDP, on=["country", "year"], how="left")
H["survey_round"] = H["country"] + "_" + H["year"].astype(str)
H["survey"] = H["country"].map(SURVEY)
H["round_name"] = [ROUND_NAME[(c, y)] for c, y in zip(H.country, H.year)]
H["currency"] = H["country"].map(CURRENCY)
H["hh_uid"] = H["country"] + "_" + H["year"].astype(str) + "_" + H["hhid"]
H["recall_days"] = 7
H["only_consumed_items_listed"] = [int((c, y) in ONLY_CONSUMED) for c, y in zip(H.country, H.year)]
H = H.sort_values(["country", "year", "hhid"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s).reset_index(drop=True)
assert not H.duplicated(["country", "year", "hhid"]).any()
assert not H["hh_uid"].duplicated().any()

HHCOLS = ["hh_uid", "country", "survey", "survey_round", "round_name", "year", "wave", "hhid", "panel_id",
          "weight", "region", "zone", "woreda", "state", "lga", "cluster", "strata", "rural", "urban_code", "refugee_camp",
          "hhsize", "adulteq", "n_members", "share_child", "share_elderly", "share_female", "head_age", "head_female",
          "welfare", "welfare_quintile", "total_cons_ann_eth", "food_cons_annual_official",
          "food_exp_7d_module", "n_food_items_module", "food_module_tza", "currency", "recall_days", "only_consumed_items_listed",
          "gdp_pc_ppp_const2021"]
HHTEXT = {"hh_uid", "country", "survey", "survey_round", "round_name", "wave", "hhid", "panel_id", "region", "zone", "woreda",
          "state", "lga", "cluster", "strata", "urban_code", "food_module_tza", "currency"}

# ------------------------------------------------------------------------------------------
# 4. derived totals: which items each one adds up
# ------------------------------------------------------------------------------------------
ASF_CATS = {"meat", "fish", "eggs", "dairy", "asf_mixed"}
GROUPS = [  # name, label, rule on (cat, sub, in_total), quantity unit(s) or None
    ("meat_red", "red meat (beef, goat, mutton, pork, camel)", lambda c, s, t: c == "meat" and s == "red", ["kg"]),
    ("meat_white", "white meat (poultry)", lambda c, s, t: c == "meat" and s == "white", ["kg"]),
    ("meat_minor", "minor meats (game, offal, insects, snails, other)", lambda c, s, t: c == "meat" and s == "minor", ["kg"]),
    ("meat_processed", "processed meat (sausages, canned)", lambda c, s, t: c == "meat" and s == "processed", ["kg"]),
    ("meat_unsplit", "single meat item, Ethiopia 2011-2013", lambda c, s, t: c == "meat" and s == "mixed", ["kg"]),
    ("meat", "all meat (excludes vendor meals)", lambda c, s, t: c == "meat" and t == 1, ["kg"]),
    ("fish_fresh", "fresh or frozen fish and seafood", lambda c, s, t: c == "fish" and s == "fresh", ["kg"]),
    ("fish_dried", "dried, smoked or salted fish", lambda c, s, t: c == "fish" and s == "dried_smoked_salted", ["kg"]),
    ("fish_canned", "canned or packaged fish", lambda c, s, t: c == "fish" and s == "canned_packaged", ["kg"]),
    ("fish_product", "fish products (soup, sauce)", lambda c, s, t: c == "fish" and s == "fish_product", ["kg"]),
    ("fish_unspecified", "fish, form not stated", lambda c, s, t: c == "fish" and s == "unspecified", ["kg"]),
    ("fish", "all fish and seafood (excludes vendor meals)", lambda c, s, t: c == "fish" and t == 1, ["kg"]),
    ("eggs", "eggs (excludes vendor eggs)", lambda c, s, t: c == "eggs" and t == 1, ["pc", "kg"]),
    ("dairy_milk_fresh", "fresh milk", lambda c, s, t: c == "dairy" and s == "milk_fresh", ["l"]),
    ("dairy_processed", "processed dairy (powder or tinned milk, yoghurt and soured milk, cheese, butter and ghee, other milk products, ice cream)",
     lambda c, s, t: c == "dairy" and t == 1 and s != "milk_fresh", None),
    ("dairy", "all dairy (excludes infant formula and butter mixed with margarine)", lambda c, s, t: c == "dairy" and t == 1, None),
    ("asf_mixed", "meat or fish not separable (Malawi tinned meat or fish, other of the group)", lambda c, s, t: c == "asf_mixed", None),
    ("asf", "all animal-source foods: meat + fish + eggs + dairy + not separable", lambda c, s, t: c in ASF_CATS and t == 1, None),
    ("plant_pulses", "dry pulses, pulse flours and soy", lambda c, s, t: c == "plant" and s in ("pulses", "pulses_processed", "soy"), ["kg"]),
    ("plant_pulses_fresh", "fresh beans and peas", lambda c, s, t: c == "plant" and s == "pulses_fresh", ["kg"]),
    ("plant_groundnuts", "groundnuts and groundnut products", lambda c, s, t: c == "plant" and s == "groundnuts", ["kg"]),
    ("plant_nuts", "tree nuts (cashew, macadamia, almonds)", lambda c, s, t: c == "plant" and s == "nuts", ["kg"]),
    ("plant_seeds", "oil seeds (sesame, melon, sunflower, linseed, niger seed, ogbono)", lambda c, s, t: c == "plant" and s == "seeds", ["kg"]),
    ("plant_other", "other pulses, nuts or seeds", lambda c, s, t: c == "plant" and s == "pulse_nut_other", ["kg"]),
    ("plant", "all plant protein foods (excludes coconut, kola, vendor groundnuts)", lambda c, s, t: c == "plant" and t == 1, ["kg"]),
    ("protein", "all protein-rich foods: animal-source + plant", lambda c, s, t: t == 1, None),
    ("vendor", "cooked food bought from vendors (Malawi): meat, chicken, fish, eggs, groundnuts", lambda c, s, t: s == "prepared_vendor", None),
    ("not_counted", "kept but not counted in any total: infant formula, butter mixed with margarine, coconut, kola",
     lambda c, s, t: t == 0 and s != "prepared_vendor", None),
]
GMEMB = {g: {s for s in SLOTS if rule(SLOT.at[s, "cat"], SLOT.at[s, "sub"], SLOT.at[s, "in_total"])} for g, _, rule, _ in GROUPS}


def totals(L, Hc):
    """household totals of one country from the long table"""
    idx = pd.MultiIndex.from_frame(Hc[["year", "hhid"]])
    L = L.assign(_ena=L["exp"].isna().astype(int), _c1=(L["cons"] == 1).astype(int), _cna=L["cons"].isna().astype(int),
                 _unc=((L["cons"] == 1) & L["s_tot"].isna()).astype(int))
    out = {}
    for g, _, _, qunits in GROUPS:
        x = L[L["slot"].isin(GMEMB[g])]
        if not len(x):
            continue
        a = x.groupby(["year", "hhid"]).agg(e=("exp", "sum"), ena=("_ena", "sum"), c1=("_c1", "sum"), cna=("_cna", "sum"), unc=("_unc", "sum")).reindex(idx)
        out[f"exp_{g}"] = np.where(a["ena"] > 0, np.nan, a["e"])
        out[f"cons_{g}"] = np.where(a["c1"] > 0, 1.0, np.where(a["cna"] > 0, np.nan, 0.0))
        out[f"cons_{g}"][a["c1"].isna().to_numpy()] = np.nan
        if g in ("asf", "protein"):
            out[f"nmiss_exp_{g}"] = a["ena"].to_numpy()
        if qunits:
            for u in qunits:
                std = {"kg": "kg", "l": "litre", "pc": "piece"}[u]
                y = x[x["std"] == std]
                if not len(y):
                    continue
                b = y.groupby(["year", "hhid"]).agg(q=("s_tot", "sum"), unc=("_unc", "sum")).reindex(idx)
                out[f"qty_{g}_{u}"] = np.where(b["unc"] > 0, np.nan, b["q"])
            out[f"nunconv_{g}"] = a["unc"].to_numpy()
    return pd.DataFrame(out, index=Hc.index)


# order of the derived columns
DERIVED = []
for g, _, _, qunits in GROUPS:
    DERIVED += [f"exp_{g}", f"cons_{g}"]
    if g in ("asf", "protein"):
        DERIVED += [f"nmiss_exp_{g}"]
    if qunits:
        DERIVED += [f"qty_{g}_{u}" for u in qunits] + [f"nunconv_{g}"]

# ------------------------------------------------------------------------------------------
# 5. pass 1 over the countries: totals, item columns that are not empty, statistics
# ------------------------------------------------------------------------------------------
print("pass 1: totals and columns")
TOT = []; NONEMPTY = set(); AVAIL = {}; ITEMSTATS = []; CONVM = {}
for cc in COUNTRIES:
    L = read_long(cc)
    Hc = H[H.country == cc]
    assert set(zip(Hc.year, Hc.hhid)) == set(zip(L.year, L.hhid)), cc     # same households in both
    assert not L.duplicated(["year", "hhid", "slot"]).any(), cc
    TOT.append(totals(L, Hc))
    for v in ITEMVARS:
        nn = L[["year", "slot"]].assign(_n=L[v].notna()).groupby(["year", "slot"])["_n"].any()
        for (y, s) in nn.index[nn]:
            NONEMPTY.add((s, v)); AVAIL.setdefault((s, v), set()).add((cc, y))
    for (y, s), g in L.groupby(["year", "slot"]):
        c1 = g["cons"] == 1
        f = g["flag"].fillna(0).astype(int)
        ITEMSTATS.append(dict(country=cc, year=y, slot=s, code=int(g["code"].iloc[0]) if g["code"].nunique() == 1 else "/".join(map(str, sorted(g["code"].dropna().astype(int).unique()))),
                              households=len(g), consumed=int(c1.sum()), not_consumed=int((g["cons"] == 0).sum()), consumption_missing=int(g["cons"].isna().sum()),
                              bought=int((g["exp"] > 0).sum()), exp_missing_among_consumed=int((c1 & g["exp"].isna()).sum()),
                              qty_not_convertible_among_consumed=int((c1 & g["s_tot"].isna()).sum()),
                              flag_price=int(((f & 1) > 0).sum()), flag_qty=int(((f & 2) > 0).sum()), flag_exp=int(((f & 4) > 0).sum()),
                              flag_no_but_qty=int(((f & 8) > 0).sum()), flag_yes_no_qty=int(((f & 16) > 0).sum()),
                              flag_purchase=int(((f & 32) > 0).sum()), flag_unconv=int(((f & 64) > 0).sum()),
                              median_unit_value=float(np.nanmedian((g["exp_pur"] / g["s_pur"]).where((g["exp_pur"] > 0) & (g["s_pur"] > 0)))) if ((g["exp_pur"] > 0) & (g["s_pur"] > 0)).any() else np.nan))
        CONVM[(cc, y, s)] = "; ".join(sorted(g["conv_method"].dropna().unique()))
    print(f"  {cc}: {len(Hc)} households, {len(L)} item rows ({time.time() - T0:.0f}s)")
    del L
TOT = pd.concat(TOT).reindex(H.index)
DERIVED = [d for d in DERIVED if d in TOT.columns and TOT[d].notna().any()]
ITEMSTATS = pd.DataFrame(ITEMSTATS)
ITEMCOLS = [f"{s}__{v}" for s in SLOTS for v in ITEMVARS if (s, v) in NONEMPTY]
COLS = HHCOLS + DERIVED + ITEMCOLS
print(f"  {len(COLS)} columns: {len(HHCOLS)} household, {len(DERIVED)} derived, {len(ITEMCOLS)} item")
POS = {c: i for i, c in enumerate(COLS)}
TEXTCOLS = HHTEXT | {c for c in ITEMCOLS if RAWSRC.get(c.split("__")[1], "") in TEXT_RAW}

# ------------------------------------------------------------------------------------------
# 6. pass 2: write the rows (xlsx and csv together), verify the totals from the wide columns
# ------------------------------------------------------------------------------------------
wb = xlsxwriter.Workbook(XLSX, {"constant_memory": True, "strings_to_numbers": False, "strings_to_formulas": False, "strings_to_urls": False,
                                "nan_inf_to_errors": False})
F = {"head": wb.add_format({"bold": True, "bg_color": "#DCE6F1", "border": 1, "text_wrap": True, "valign": "top"}),
     "hd": wb.add_format({"bold": True, "bg_color": "#F2F2F2", "border": 1}),
     "title": wb.add_format({"bold": True, "font_size": 13}), "bold": wb.add_format({"bold": True}),
     "wrap": wb.add_format({"text_wrap": True, "valign": "top"}), "note": wb.add_format({"italic": True, "font_color": "#555555"}),
     "red": wb.add_format({"bold": True, "font_color": "#C00000", "text_wrap": True, "valign": "top"})}
ws = wb.add_worksheet("Final_Household_Dataset")
SHEETS = {n: wb.add_worksheet(n) for n in ["Data_Dictionary", "Comparability_Matrix", "Quality_Control", "Harmonization_Log", "Unit_Codes"]}
ws.freeze_panes(1, 8)
for c, name in enumerate(COLS):
    ws.write_string(0, c, name, F["head"])
ws.set_row(0, 30)
NONMISS = np.zeros(len(COLS), dtype=np.int64)
csvh = gzip.open(CSVF, "wt", newline="", encoding="utf-8")
cw = csv.writer(csvh); cw.writerow(COLS)
VERIFY = []
r = 1


def fmt(v):
    if isinstance(v, str):
        return v
    if v == int(v) and abs(v) < 1e15:
        return str(int(v))
    return "%.10g" % v


print("pass 2: rows")
for cc in COUNTRIES:
    L = read_long(cc)
    for y in sorted(L.year.unique()):
        x = L[L.year == y]
        hh = H[(H.country == cc) & (H.year == y)]
        tt = TOT.loc[hh.index]
        vars_here = [v for v in ITEMVARS]
        W = x.set_index(["hhid", "slot"])[vars_here].unstack("slot")
        W.columns = [f"{s}__{v}" for v, s in W.columns]
        W = W[[c for c in W.columns if c in POS]].reindex(hh["hhid"].to_numpy())
        # check: totals recomputed from the wide item columns, with the items asked to each household
        # (Tanzania 2020: two samples with different item lists, year 2020 and 2020.1 of the map)
        parts = [(np.ones(len(hh), bool), ASKED.get((cc, y), set()))]
        if (cc, y) == ("TZA", 2020):
            mod = hh["food_module_tza"].to_numpy()
            parts = [(mod == "hh_sec_ja1", set(MAP[(MAP.country == cc) & (MAP.year == 2020)].slot)),
                     (mod == "hh_sec_j1", set(MAP[(MAP.country == cc) & (MAP.year == 2020.1)].slot))]
        for g, _, _, _ in GROUPS:
            if f"exp_{g}" not in tt.columns:
                continue
            for k, (sel, asked) in enumerate(parts):
                cols = [f"{s}__exp" for s in GMEMB[g] & asked if f"{s}__exp" in W.columns]
                if not cols or not sel.any():
                    continue
                Wk = W[cols][sel]
                alt = Wk.sum(axis=1, min_count=len(cols)).where(Wk.notna().all(axis=1)).to_numpy()
                ref = tt[f"exp_{g}"].to_numpy()[sel]
                both = ~np.isnan(alt) & ~np.isnan(ref)
                VERIFY.append(dict(country=cc, year=y, sample=["all", "hh_sec_j1"][k] if len(parts) > 1 and k else ("hh_sec_ja1" if len(parts) > 1 else "all"),
                                   total=f"exp_{g}", items=len(cols), households=int(sel.sum()),
                                   non_missing=int((~np.isnan(ref)).sum()), same_missing_pattern=bool((np.isnan(alt) == np.isnan(ref)).all()),
                                   max_abs_difference=float(np.max(np.abs(alt[both] - ref[both]))) if both.any() else 0.0))
        blocks = [(hh[HHCOLS].reset_index(drop=True), HHCOLS), (tt[DERIVED].reset_index(drop=True), DERIVED), (W.reset_index(drop=True), list(W.columns))]
        frame = pd.concat([b for b, _ in blocks], axis=1)
        names = list(frame.columns); pos = np.array([POS[n] for n in names])
        istext = np.array([n in TEXTCOLS for n in names])
        tcols = [i for i in range(len(names)) if istext[i]]; ncols = [i for i in range(len(names)) if not istext[i]]
        Tm = frame.iloc[:, tcols].astype(object).where(frame.iloc[:, tcols].notna(), None).to_numpy()
        Nm = frame.iloc[:, ncols].apply(pd.to_numeric, errors="coerce").to_numpy(dtype=float)
        tpos = pos[tcols]; npos = pos[ncols]
        NONMISS[tpos] += (Tm != None).sum(axis=0)  # noqa: E711
        NONMISS[npos] += (~np.isnan(Nm)).sum(axis=0)
        for i in range(len(frame)):
            row = [""] * len(COLS)
            tr = Tm[i]; nr = Nm[i]
            for j in np.flatnonzero(tr != None):  # noqa: E711
                v = str(tr[j]); p = tpos[j]; ws.write_string(r, p, v); row[p] = v
            for j in np.flatnonzero(~np.isnan(nr)):
                v = float(nr[j]); p = npos[j]; ws.write_number(r, p, v); row[p] = fmt(v)
            cw.writerow(row); r += 1
        print(f"  {cc} {y}: {len(hh)} rows, row {r - 1} ({time.time() - T0:.0f}s)")
    del L
csvh.close()
NROWS = r - 1
assert NROWS == len(H)
VERIFY = pd.DataFrame(VERIFY)
ws.autofilter(0, 0, NROWS, len(COLS) - 1)

# ------------------------------------------------------------------------------------------
# 7. helpers for the documentation sheets
# ------------------------------------------------------------------------------------------
RLAB = [f"{c}_{y}" for c, y in ROUNDS]


def rounds_txt(rs):
    """('ETH',2011),('ETH',2013)... -> 'ETH 2011-2021 (5/5); TZA 2020 (1/5)'"""
    out = []
    for c in COUNTRIES:
        ys = sorted(y for cc, y in rs if cc == c)
        if not ys:
            continue
        n = sum(1 for cc, _ in ROUNDS if cc == c)
        out.append(f"{c} {', '.join(map(str, ys))} ({len(ys)}/{n})")
    return "; ".join(out)


def put_table(sh, r0, df, title=None, note=None, widths=None):
    """writes a table in order (constant_memory: rows only go down); returns the next free row"""
    r = r0
    if title:
        sh.write_string(r, 0, title, F["title"]); r += 1
    if note:
        sh.write_string(r, 0, note, F["note"]); r += 1
    for j, c in enumerate(df.columns):
        sh.write_string(r, j, str(c), F["hd"])
    r += 1
    for row in df.itertuples(index=False):
        for j, v in enumerate(row):
            if v is None or (isinstance(v, float) and np.isnan(v)):
                continue
            if isinstance(v, (bool, np.bool_)):
                sh.write_string(r, j, "yes" if v else "no")
            elif isinstance(v, (int, float, np.integer, np.floating)):
                sh.write_number(r, j, float(v))
            else:
                sh.write_string(r, j, str(v))
        r += 1
    return r + 1


def norm_label(s):
    s = re.sub(r"^\s*\d+\s*[.)]\s*", "", str(s)).lower()
    s = re.sub(r"^(meat|poultry and poultry products|fish and seafood|milk and milk products|pulses, nuts and seeds|oils, fats and butter)\s*:\s*", "", s)
    return re.sub(r"[^a-z]", "", s)


# ------------------------------------------------------------------------------------------
# 8. Comparability_Matrix
# ------------------------------------------------------------------------------------------
GROUP_NOTES = {
    "meat_red": "Partially comparable. Not separable in Ethiopia 2011-2013 (one meat item). Tanzania beef includes minced meat and sausages, pork includes sausages and bacon (processed meat sits in red meat there). Malawi pieces of red meat are not converted to kg.",
    "meat_white": "Partially comparable. Poultry is one item in Ethiopia, Nigeria (chicken + other poultry) and Tanzania 2008-2014; split by type in Tanzania 2020 and Uganda 2018-19 (broiler, kroiler, local, off-layer); Malawi 2010 one chicken item, 2016-2024 whole birds and pieces separate.",
    "meat_minor": "Partially comparable: the list of minor meats differs by country (game, offal, insects, snails, rabbit, mice). Malawi and Nigeria ask more of them.",
    "meat_processed": "Partially comparable: asked in Malawi, Nigeria and Uganda only (in Tanzania inside beef and pork).",
    "meat_unsplit": "Ethiopia 2011-2013 only: one item for all meat; whether fish was reported here is not stated (uncertain).",
    "meat": "Comparable at the category level in every round, with the caveats above. Excludes cooked meat from vendors (Malawi).",
    "fish_fresh": "Partially comparable: not asked in Ethiopia; Tanzania 2008-2014 fresh fish includes seafood and dagaa; Nigeria frozen fish counted here.",
    "fish_dried": "Partially comparable: Tanzania dried fish label also includes canned fish (overlap with the canned item); Uganda silverfish (mukene) form not stated (put in unspecified).",
    "fish_canned": "Partially comparable: asked in Tanzania, Nigeria, Uganda and Malawi (Malawi tinned meat or fish is not separable: asf_mixed).",
    "fish_product": "Malawi only.",
    "fish_unspecified": "Ethiopia 2015-2021 has one fish item with form not asked; not asked at all in Ethiopia 2011-2013.",
    "fish": "Comparable at the category level except Ethiopia 2011-2013 (no fish item: total is empty, not zero).",
    "eggs": "Fully comparable in expenditure. Quantity in pieces (Tanzania, Malawi, Uganda) or kg (Ethiopia, Nigeria: the official tables convert pieces to kg). Malawi vendor-boiled eggs kept apart (vendor).",
    "dairy_milk_fresh": "Fully comparable item (fresh milk, species not stated); quantity in litres.",
    "dairy_processed": "Partially comparable: the list of processed products differs (Ethiopia butter/ghee and ayib cheese; Malawi powder, chambiko, cheese; Uganda bongo, ghee, cheese from 2018). Butter mixed with margarine is excluded where it is one item (Tanzania, Nigeria, Uganda).",
    "dairy": "Comparable at the category level; quantities not summed (litres and kg).",
    "asf_mixed": "Not harmonizable to a category: Malawi tinned meat or fish, and the 'other' of the meat, fish and animal products group. Counted only in the animal-source total.",
    "asf": "Comparable across rounds and countries in expenditure, within the coverage differences above (Ethiopia 2011-2013 has no fish item).",
    "plant_pulses": "Partially comparable: item lists differ a lot (Ethiopia 8-12 pulses, Tanzania one item for all pulses, Malawi 8-10, Nigeria 4-6, Uganda 3-5).",
    "plant_pulses_fresh": "Fresh beans and peas, Tanzania and Malawi; whether fresh or dry is not always stated (uncertain). Kept as own subtotal.",
    "plant_groundnuts": "Partially comparable: one item in Malawi 2010 and Nigeria 2010; shelled and unshelled split later; Uganda label changes from unshelled to shelled in 2018 (weight not comparable).",
    "plant_nuts": "Partially comparable: Tanzania one item (cashew, almonds, other nuts), Malawi macadamia/cashew, Nigeria and Uganda none.",
    "plant_seeds": "Country-specific: Ethiopia linseed, niger seed, sesame, sunflower; Nigeria melon seeds and ogbono; Uganda simsim; Tanzania seeds and nut products.",
    "plant_other": "Residual 'other' items: not harmonizable at item level; counted in the plant total.",
    "plant": "Comparable at the category level only (item lists differ).",
    "protein": "Comparable in expenditure at the level of the five categories; item coverage differs by round (see the matrix).",
    "vendor": "Malawi only (cooked food from vendors).",
    "not_counted": "Kept for completeness: infant formula, butter mixed with margarine, coconut, kola.",
}
gcov = []
for g, lab, _, _ in GROUPS:
    row = {"total": f"exp_{g}", "what it adds up": lab}
    for (c, y), rl in zip(ROUNDS, RLAB):
        n = len(GMEMB[g] & ASKED.get((c, y), set()))
        row[rl] = n if n else None
    row["comparability"] = GROUP_NOTES.get(g, "")
    gcov.append(row)
GCOV = pd.DataFrame(gcov)

SPECIAL_NH = {"eth_pea_code8", "eth_pea_code9", "meat_fish_other_specify", "dairy_other_specify", "pulses_nuts_other_specify"}
items = []
for s in SLOTS:
    m = MAP[MAP.slot == s]
    row = {"item (slot)": s, "category": SLOT.at[s, "cat"], "subcategory": SLOT.at[s, "sub"],
           "counted in totals": "yes" if SLOT.at[s, "in_total"] == 1 else ("vendor subtotal" if SLOT.at[s, "sub"] == "prepared_vendor" else "no"),
           "standard unit": "; ".join(f"{c} {STD[(c, s)]}" for c in COUNTRIES if (c, s) in STD)}
    for (c, y), rl in zip(ROUNDS, RLAB):
        mm = m[(m.country == c) & (m["round"] == y)]
        row[rl] = " / ".join(f"{int(cd)}: {lb}" + (" [hh_sec_j1 sample]" if yy == 2020.1 else "") for cd, lb, yy in zip(mm.code, mm.label, mm.year)) if len(mm) else None
    notes = "; ".join(sorted({n for n in m.note.dropna()}))
    within = []; worst = 0   # 0 fully, 1 partially, 2 not comparable, 3 not harmonizable
    for c in COUNTRIES:
        mc = m[m.country == c]
        if not len(mc):
            continue
        n = sum(1 for cc, _ in ROUNDS if cc == c); k = mc["round"].nunique()
        labs = [norm_label(x) for x in mc.label]
        same = all(difflib.SequenceMatcher(None, labs[0], x).ratio() >= 0.8 for x in labs)
        nc = " ".join(mc.note.dropna())
        if s in SPECIAL_NH or "CONFLICT" in nc:
            lev, why, w = "not harmonizable", "identity of the item unresolved or residual 'other' item", 3
        elif "LABEL CHANGE" in nc:
            lev, why, w = "not comparable (quantities)", "item definition changes between rounds", 2
        elif k == n and same:
            lev, why, w = "fully", f"{k}/{n} rounds, same item", 0
        else:
            why = []
            if k < n:
                why.append(f"asked in {k}/{n} rounds")
            if not same:
                why.append("label differs between rounds")
            lev, why, w = "partially", ", ".join(why), 1
        within.append(f"{c}: {lev} ({why})"); worst = max(worst, w)
    ncty = m.country.nunique()
    if s in SPECIAL_NH:
        across = "not harmonizable at item level (counted in the category total only)"
    elif ncty > 1:
        scope = any(k in notes for k in ("includes", "mixes", "overlaps", "pieces not converted"))
        across = f"item level in {ncty} countries" + (", scope differs (see notes)" if scope else "")
        worst = max(worst, 1 if scope else 0)
    else:
        across = "country-specific item: compare at subcategory or category level"
    uncertain = [k for k in ("not stated", "overlaps", "CONFLICT", "LABEL CHANGE", "whether") if k in notes]
    row.update({"within country": " | ".join(within), "across countries": across,
                "overall level": ["Fully comparable", "Partially comparable", "Not comparable", "Not harmonizable"][worst],
                "uncertain": "yes: " + notes if uncertain else None,
                "notes": notes or None,
                "consumed rows with quantity converted (%)": round(100 * (1 - ITEMSTATS[ITEMSTATS.slot == s].qty_not_convertible_among_consumed.sum() / max(ITEMSTATS[ITEMSTATS.slot == s].consumed.sum(), 1)), 1),
                "conversion method": " | ".join(sorted({f"{c}: {CONVM[(c, y, s)]}" for (c, y, ss) in CONVM if ss == s and CONVM[(c, y, s)]}))})
    items.append(row)
ITEMS = pd.DataFrame(items)
sh = SHEETS["Comparability_Matrix"]
r = 0
sh.write_string(r, 0, "COMPARABILITY MATRIX", F["title"]); r += 1
for t in ["Levels. Fully comparable: same item in every round of the country, same label, quantities in the same standard unit. "
          "Partially comparable: asked in some rounds only, label or scope changes, or the same item has a different scope in another country. "
          "Not comparable: the definition changes between rounds (quantities cannot be compared). Not harmonizable: identity unresolved or residual 'other' item.",
          "Cells of the round columns: original item code and questionnaire label. Empty = item not in that round's questionnaire: its columns are empty for those households.",
          "All rounds: 7-day recall. Nigeria: post-harvest visit. Uganda 2010-2015 and Nigeria 2010 list only consumed items: items not listed are 'not consumed'."]:
    sh.write_string(r, 0, t, F["note"]); r += 1
r += 1
r = put_table(sh, r, GCOV, "A. Totals: number of items each total adds up, by round (empty = no item of that kind asked)")
r = put_table(sh, r, ITEMS, "B. Items by round: original code and label, comparability level")
sh.set_column(0, 0, 26); sh.set_column(1, 4, 14); sh.set_column(5, 5 + len(RLAB), 22)

# ------------------------------------------------------------------------------------------
# 9. Data_Dictionary
# ------------------------------------------------------------------------------------------
HHDOC = {
    "hh_uid": ("key", "text", "", "Unique key: country_year_hhid. One row per country x round x household; no duplicates."),
    "country": ("household", "text", "", "ISO3 country code: ETH Ethiopia, TZA Tanzania, MWI Malawi, NGA Nigeria, UGA Uganda."),
    "survey": ("household", "text", "", "LSMS-ISA survey programme."),
    "survey_round": ("household", "text", "", "Country and first year of fieldwork, e.g. ETH_2011; the round labels of the Comparability_Matrix."),
    "round_name": ("household", "text", "", "Name and fieldwork years of the round."),
    "year": ("household", "number", "year", "First year of fieldwork."),
    "wave": ("household", "text", "", "Wave label used in the Step I pipeline (w1, w2, ...)."),
    "hhid": ("household", "text", "", "Household identifier as in the round's files (kept as text: leading zeros matter)."),
    "panel_id": ("household", "text", "", "Identifier linking the same household across rounds (Step I panel_ids(), PART 9). Empty: no link (new or split households; Malawi not linked)."),
    "weight": ("design", "number", "", "Household sampling weight of the round, as in the Step I panels (from the consumption aggregate or the cover file). Empty where the survey files give none; not set to 1."),
    "region": ("design", "text", "", "Region code as in the survey (Ethiopia region, Tanzania region, Malawi district, Nigeria zone, Uganda region)."),
    "zone": ("design", "text", "", "Ethiopia zone; Nigeria geopolitical zone."),
    "woreda": ("design", "text", "", "Ethiopia woreda."),
    "state": ("design", "text", "", "Nigeria state."),
    "lga": ("design", "text", "", "Nigeria local government area."),
    "cluster": ("design", "text", "", "Enumeration area / cluster identifier (used for cluster-robust errors and cluster prices)."),
    "strata": ("design", "text", "", "Sampling stratum (Tanzania only in the Step I panels)."),
    "rural": ("design", "0/1", "", "1 = rural, 0 = urban, from the raw codes: Ethiopia and Tanzania 1 = rural; Nigeria sector 2 = rural; Malawi and Uganda 0 = rural."),
    "urban_code": ("design", "text", "", "Raw urban/rural (sector) code of the survey, unchanged."),
    "refugee_camp": ("design", "0/1", "", "Malawi 2024 only: 1 = Dzaleka refugee camp household (in the food module, not in the Step I panel: no consumption aggregate)."),
    "hhsize": ("demography", "number", "persons", "Household size."),
    "adulteq": ("demography", "number", "adult equivalents", "Adult equivalents of the official aggregate. Malawi and Nigeria have no scale: equal to household size (as in Step I)."),
    "n_members": ("demography", "number", "persons", "Members in the roster (Ethiopia)."),
    "share_child": ("demography", "share", "", "Share of members under 15."),
    "share_elderly": ("demography", "share", "", "Share of members aged 60 or more."),
    "share_female": ("demography", "share", "", "Share of female members (Ethiopia)."),
    "head_age": ("demography", "number", "years", "Age of the household head."),
    "head_female": ("demography", "0/1", "", "1 = female head."),
    "welfare": ("welfare", "number", "local currency per year", "Welfare measure of Step I, on the scale of each country's official aggregate: Ethiopia nominal annual consumption per adult equivalent; Tanzania real annual consumption per adult equivalent (2020: 28-day value x 365/28); Malawi real annual consumption per person; Nigeria annual consumption per person; Uganda monthly consumption per adult equivalent x 12. Not comparable in level across countries."),
    "welfare_quintile": ("welfare", "1-5", "", "Quintile of welfare within country and round, unweighted (as rule M16 of Step I)."),
    "total_cons_ann_eth": ("welfare", "number", "ETB per year", "Ethiopia: total annual household consumption of the official aggregate."),
    "food_cons_annual_official": ("welfare", "number", "local currency per year", "Annual food consumption of the official aggregate (food_spend() of Step I PART 14b, the robustness check)."),
    "food_exp_7d_module": ("welfare", "number", "local currency, 7 days", "Sum of the 7-day purchase value of ALL items of the food module, protein-rich or not. It excludes own production and gifts, so it is food spending, not food consumption."),
    "n_food_items_module": ("welfare", "number", "items", "Rows of the household in the food module (all items)."),
    "food_module_tza": ("design", "text", "", "Tanzania only: food module file. 2020 has two samples, hh_sec_ja1 (main, new item list) and hh_sec_j1 (419 households, old list)."),
    "currency": ("household", "text", "", "Currency of all values of the row."),
    "recall_days": ("household", "number", "days", "Recall period of the food module (7 days in all rounds included)."),
    "only_consumed_items_listed": ("household", "0/1", "", "1 = the round lists only consumed items (Nigeria 2010, Uganda 2010-2015): an item not listed counts as not consumed."),
    "gdp_pc_ppp_const2021": ("country", "number", "constant 2021 international $", "GDP per capita, PPP (WDI NY.GDP.PCAP.PP.KD) of the country and year, as for the income axis of Step I."),
}
ITEMDOC = {
    "cons": ("harmonized", "0/1", "", "Consumed in the last 7 days: 1 if the answer is yes or any quantity or spending is reported; 0 if the answer is no (or, in rounds listing only consumed items, the item is not listed); empty if not answered."),
    "exp": ("harmonized", "number", "local currency, 7 days", "Purchase spending: the value reported if positive; 0 if not consumed or not bought (quantity bought 0 or spending 0; Uganda: no quantity and no value bought); empty if bought but no value. Uganda: purchases consumed at home (as in Step I)."),
    "flag": ("harmonized", "bitmask", "", "Consumed items only (empty otherwise). 0 = no problem. Sum of: 1 implied price outside 1/10-10 x the median of the item in the round; 2 total quantity over 100 x the median; 4 spending over 100 x the median (thresholds of Step I rules M17/M18, here flagged, not removed); 8 answer 'no' but quantity or spending reported; 16 answer 'yes' without quantity or spending; 32 purchase incoherent (quantity bought without positive spending, or spending with quantity bought 0); 64 quantity consumed not convertible to the standard unit."),
    "raw_cons": ("raw", "code", "", "Raw answer to 'consumed in the last 7 days?' (1 yes, 2 no). Empty in rounds that list only consumed items."),
    "raw_exp_pur": ("raw", "number", "local currency", "Raw amount paid for the purchases of the last 7 days (Uganda: purchases consumed at home)."),
    "raw_q_away": ("raw", "number", "raw unit", "Uganda: quantity bought and consumed away from home."),
    "raw_val_away": ("raw", "number", "UGX", "Uganda: value of purchases consumed away from home."),
    "raw_val_own": ("raw", "number", "UGX", "Uganda: value of own production consumed."),
    "raw_val_gift": ("raw", "number", "UGX", "Uganda: value of gifts and other sources."),
    "raw_q_frompur": ("raw", "number", "raw unit", "Nigeria 2012-2015: quantity consumed out of purchases."),
    "raw_unit_frompur": ("raw", "code (text)", "", "Nigeria 2012-2015: unit of the quantity consumed out of purchases (Unit_Codes)."),
    "raw_q_weight": ("raw", "number", "raw unit", "Tanzania 2020: weight estimate of the quantity in non-standard units (hh_ja02b). Kept, not used for conversion."),
    "raw_unit_weight": ("raw", "code (text)", "", "Tanzania 2020: unit of the weight estimate (Unit_Codes)."),
}
for s_ in ["tot", "pur", "own", "gift"]:
    ITEMDOC[f"raw_q_{s_}"] = ("raw", "number", "raw unit", f"Raw quantity, {SRC_LABEL[s_]}, in the unit of raw_unit_{s_}.")
    ITEMDOC[f"raw_unit_{s_}"] = ("raw", "code (text)", "", f"Raw unit code of the quantity {SRC_LABEL[s_]} (labels in Unit_Codes)." + (" Uganda: one unit for all sources, kept here only." if s_ == "tot" else ""))
    ITEMDOC[f"raw_unit_other_{s_}"] = ("raw", "text", "", f"Text of the 'other (specify)' unit, {SRC_LABEL[s_]} (Ethiopia, Malawi, Nigeria).")
    ITEMDOC[f"raw_unit_size_{s_}"] = ("raw", "code (text)", "", f"Malawi: size or sub-unit of the unit, {SRC_LABEL[s_]}.")
for s_ in SRC:
    for u, ul in [("kg", "kg"), ("l", "litres"), ("pc", "pieces")]:
        ITEMDOC[f"qty_{s_}_{u}"] = ("harmonized", "number", ul, f"Quantity {SRC_LABEL[s_]}, last 7 days, in {ul} (official conversion tables or metric units only). 0 if not consumed; empty if consumed but the unit is not convertible.")

dd = []
for i, c in enumerate(COLS):
    nm = int(NONMISS[i])
    base = {"col": i + 1, "column": c, "non-missing": nm, "% non-missing": round(100 * nm / NROWS, 2)}
    if c in HHDOC:
        blk, typ, unit, desc = HHDOC[c]
        avail = rounds_txt({(a, b) for a, b in zip(H.country, H.year)} if c not in H.columns else
                           {(a, b) for a, b, v in zip(H.country, H.year, H[c].notna()) if v})
        dd.append({**base, "block": blk, "item (slot)": None, "category": None, "subcategory": None, "variable": c,
                   "type": typ, "unit": unit, "description": desc, "available in": avail})
    elif c in DERIVED:
        kind, g = c.split("_", 1)
        if kind == "nmiss":
            g = g.replace("exp_", "", 1)
        if kind == "qty":
            g, u = g.rsplit("_", 1)
        lab = dict((a, b) for a, b, _, _ in GROUPS)[g]
        desc = {"exp": f"Total purchase spending, last 7 days, on {lab}: sum of the item 'exp' columns of the items asked in the round. Empty if any of them is missing, or if no such item is asked in the round (not zero).",
                "cons": f"1 if any item of {lab} is consumed; 0 if all asked items are not consumed; empty if none consumed and some not answered, or none asked.",
                "qty": f"Total quantity consumed, last 7 days, of {lab}, in {u}: sum of qty_tot_{u} of the items. Empty if any consumed item is not convertible (see nunconv_{g}).",
                "nunconv": f"Number of consumed items of {lab} whose quantity is not convertible to the standard unit.",
                "nmiss": f"Number of asked items of {lab} with purchase spending missing (when > 0, exp_{g} is empty)."}[kind]
        rs = {(cc, y) for (cc, y) in ROUNDS if GMEMB[g] & ASKED.get((cc, y), set())}
        dd.append({**base, "block": "derived total", "item (slot)": None, "category": g, "subcategory": None, "variable": kind,
                   "type": {"exp": "number", "cons": "0/1", "qty": "number", "nunconv": "count", "nmiss": "count"}[kind],
                   "unit": {"exp": "local currency, 7 days", "qty": {"kg": "kg", "l": "litres", "pc": "pieces"}.get(c.rsplit("_", 1)[-1], "")}.get(kind, ""),
                   "description": desc, "available in": rounds_txt(rs)})
    else:
        s, v = c.split("__")
        blk, typ, unit, desc = ITEMDOC[v]
        if v in ("raw_cons", "raw_q_tot", "raw_q_pur", "raw_q_own", "raw_q_gift") or v.startswith("raw_unit"):
            pass
        dd.append({**base, "block": f"item: {blk}", "item (slot)": s, "category": SLOT.at[s, "cat"], "subcategory": SLOT.at[s, "sub"],
                   "variable": v, "type": typ, "unit": unit, "description": desc, "available in": rounds_txt(AVAIL.get((s, v), set()))})
DD = pd.DataFrame(dd)[["col", "column", "block", "item (slot)", "category", "subcategory", "variable", "type", "unit", "description",
                       "available in", "non-missing", "% non-missing"]]
sh = SHEETS["Data_Dictionary"]
r = 0
sh.write_string(r, 0, "DATA DICTIONARY", F["title"]); r += 1
for t in [f"Final_Household_Dataset: {NROWS} rows (households), {len(COLS)} columns: {len(HHCOLS)} household, {len(DERIVED)} derived totals, {len(ITEMCOLS)} item columns for {len(SLOTS)} harmonized items.",
          "Item columns are named <item>__<variable>. Harmonized: cons, exp, qty_<source>_<unit>, flag. Raw: raw_* (the questionnaire answers, unchanged; unit codes as text).",
          "Missing and zero: 0 = not consumed / not bought; empty = not answered, not convertible, or item not in that round (Comparability_Matrix tells which). No empty value was turned into 0.",
          "Values are in local currency (column currency) and refer to the last 7 days. Item codes and labels of each round are in the Comparability_Matrix."]:
    sh.write_string(r, 0, t, F["note"]); r += 1
r += 1
r = put_table(sh, r, DD)
sh.set_column(0, 0, 5); sh.set_column(1, 1, 34); sh.set_column(2, 8, 14); sh.set_column(9, 9, 90, F["wrap"]); sh.set_column(10, 10, 40)

# ------------------------------------------------------------------------------------------
# 10. Quality_Control
# ------------------------------------------------------------------------------------------
BL = pd.read_csv(os.path.join(BUILD, "build_log.csv"))
IS = ITEMSTATS.copy()
per_round = IS.groupby(["country", "year"]).agg(items_asked=("slot", "nunique"), item_rows=("households", "sum"), consumed=("consumed", "sum"),
                                                 not_consumed=("not_consumed", "sum"), consumption_missing=("consumption_missing", "sum"),
                                                 bought=("bought", "sum"), exp_missing_among_consumed=("exp_missing_among_consumed", "sum"),
                                                 qty_not_convertible=("qty_not_convertible_among_consumed", "sum"),
                                                 flag_price=("flag_price", "sum"), flag_qty=("flag_qty", "sum"), flag_exp=("flag_exp", "sum"),
                                                 flag_no_but_qty=("flag_no_but_qty", "sum"), flag_yes_no_qty=("flag_yes_no_qty", "sum"),
                                                 flag_purchase=("flag_purchase", "sum")).reset_index()
per_round["% consumed with quantity converted"] = (100 * (1 - per_round.qty_not_convertible / per_round.consumed)).round(1)
hhround = H.groupby(["country", "year"]).agg(households_in_dataset=("hhid", "size"), with_weight=("weight", lambda s: s.notna().sum()),
                                              with_welfare=("welfare", lambda s: s.notna().sum()), with_rural=("rural", lambda s: s.notna().sum()),
                                              with_panel_id=("panel_id", lambda s: s.notna().sum()),
                                              with_food_aggregate=("food_cons_annual_official", lambda s: s.notna().sum()),
                                              refugee_camp=("refugee_camp", lambda s: int((s == 1).sum()))).reset_index()
hhround = BL[["country", "year", "households", "items_mapped", "item_rows", "duplicated_hh_item"]].rename(
    columns={"households": "households_in_food_module", "item_rows": "item_rows_built"}).merge(hhround, on=["country", "year"], how="outer")
hhround["rows_equal_module_households"] = hhround.households_in_food_module == hhround.households_in_dataset
hhround["item_rows_equal_households_x_items"] = hhround.item_rows_built == per_round.set_index(["country", "year"]).reindex(
    list(zip(hhround.country, hhround.year)))["item_rows"].to_numpy()
hhround = hhround.sort_values(["country", "year"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s)
per_round = per_round.sort_values(["country", "year"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s)

# comparison with the Step I panels (the six products present everywhere)
PROD = {"beef": "beef", "goat": "goat_sheep", "mutton": "goat_sheep", "goat_mutton": "goat_sheep", "pork": "pork", "chicken": "poultry",
        "poultry": "poultry", "poultry_other": "poultry", "chicken_whole": "poultry", "chicken_off_layer": "poultry", "chicken_broiler": "poultry",
        "chicken_kroiler": "poultry", "chicken_local": "poultry", "eggs": "eggs", "eggs_farm": "eggs", "eggs_local": "eggs", "milk_fresh": "milk"}
cmp_rows = []
for cc in COUNTRIES:
    p = pd.read_csv(os.path.join(PANELS, f"panel_{cc}.csv"), dtype={"hhid": str}, low_memory=False,
                    usecols=lambda c: c in ("hhid", "product", "track", "consumed", "exp", "year"))
    p = p[p.track == "B"]
    L = read_long(cc)
    L["product"] = L.slot.map(PROD)
    x = L[L["product"].notna()]
    hx = x.groupby(["product", "year", "hhid"]).agg(cons=("cons", "max"), exp=("exp", "sum"), f=("flag", lambda s: int(np.bitwise_or.reduce(s.fillna(0).astype(int).to_numpy())))).reset_index()
    camp = set(H[(H.country == cc) & (H.refugee_camp == 1)].hhid)
    for (pr, y), g in hx.groupby(["product", "year"]):
        pp = p[(p["product"] == pr) & (p.year == y)]
        if not len(pp):
            continue
        a_c = set(pp.hhid[pp.consumed == 1]); b_c = set(g.hhid[g.cons == 1])
        a_b = set(pp.hhid[pp.exp > 0]); b_b = set(g.hhid[g.exp > 0])
        why = []
        extra = (b_c - a_c) | (b_b - a_b)
        if extra & camp:
            why.append(f"{len(extra & camp)} refugee-camp households (not in Step I)")
        rest = extra - camp
        if rest:
            fl = g[g.hhid.isin(rest)].f
            n8 = int(((fl & 8) > 0).sum()); nout = int(((fl & 5) > 0).sum())
            if n8:
                why.append(f"{n8} answered 'no' but reported a quantity (flag 8, consumed here, not in Step I)")
            if nout:
                why.append(f"{nout} purchases with implausible price or spending: removed in Step I (M17/M18), kept here with flag 1/4")
            if len(rest) - n8 - nout > 0:
                why.append(f"{len(rest) - n8 - nout} other")
        cmp_rows.append(dict(country=cc, product=pr, year=y, consumers_step1=len(a_c), consumers_here=len(b_c), buyers_step1=len(a_b), buyers_here=len(b_b),
                             spending_step1=float(pp.exp.sum()), spending_here=float(g.exp.sum()),
                             ratio_spending=round(float(g.exp.sum()) / float(pp.exp.sum()), 4) if pp.exp.sum() else np.nan,
                             missing_here_not_step1=len((a_c | a_b) - (b_c | b_b)), explanation="; ".join(why) or None))
    del L
CMP = pd.DataFrame(cmp_rows)

vsum = VERIFY.groupby("total").agg(checks=("year", "size"), all_same_missing_pattern=("same_missing_pattern", "all"),
                                    max_abs_difference=("max_abs_difference", "max"), non_missing=("non_missing", "sum")).reset_index()
ex = TOT["exp_protein"]; md = H["food_exp_7d_module"]
viol = int(((ex > md + 1e-6) & ex.notna() & md.notna()).sum())
share = (TOT["exp_asf"] / H["food_exp_7d_module"]).where(H["food_exp_7d_module"] > 0)
shr = pd.DataFrame({"country": H.country, "year": H.year, "asf_share_of_module_spending": share}).groupby(["country", "year"])["asf_share_of_module_spending"].median().round(3).reset_index()
summary = pd.DataFrame([
    ("rows of Final_Household_Dataset", NROWS, "equal to the households of the 23 food modules", NROWS == int(BL.households.sum())),
    ("duplicated hh_uid", int(H.hh_uid.duplicated().sum()), "must be 0", not H.hh_uid.duplicated().any()),
    ("duplicated country x year x hhid", int(H.duplicated(["country", "year", "hhid"]).sum()), "must be 0", True),
    ("duplicated household x item rows in the long tables", int(BL.duplicated_hh_item.sum()), "must be 0", int(BL.duplicated_hh_item.sum()) == 0),
    ("households dropped between food module and dataset", int((hhround.households_in_food_module - hhround.households_in_dataset).abs().sum()), "must be 0", bool(hhround.rows_equal_module_households.all())),
    ("item rows = households x asked items, every round", int(hhround.item_rows_equal_households_x_items.sum()), "rounds where true (of 23)", bool(hhround.item_rows_equal_households_x_items.all())),
    ("item consumption not answered (kept empty, not 0)", int(IS.consumption_missing.sum()), "item rows; Ethiopia 2018 (2,783) and 2021 (478) have no row for the item", True),
    ("consumed with purchase spending missing (kept empty)", int(IS.exp_missing_among_consumed.sum()), "item rows", True),
    ("consumed with quantity not convertible (kept empty)", int(IS.qty_not_convertible_among_consumed.sum()), "item rows (flag 64)", True),
    ("derived totals recomputed from the item columns", int(len(VERIFY)), "total x round checks; max abs difference " + str(float(VERIFY.max_abs_difference.max())), bool(VERIFY.same_missing_pattern.all() and VERIFY.max_abs_difference.max() < 1e-6)),
    ("protein spending above the module's food spending", viol, "households; must be 0", viol == 0),
    ("outliers removed", 0, "none: flagged only (flag 1/2/4)", True),
    ("empty values turned into 0", 0, "none: zeros come only from 'not consumed', 'not bought', or items absent in rounds listing only consumed items", True),
], columns=["check", "value", "note", "pass"])
sh = SHEETS["Quality_Control"]
r = 0
sh.write_string(r, 0, "QUALITY CONTROL", F["title"]); r += 1
r = put_table(sh, r + 1, summary, "1. Summary of the checks")
r = put_table(sh, r, hhround, "2. Households by round: food module, dataset, household variables available")
r = put_table(sh, r, per_round, "3. Item rows by round: consumed, not consumed, missing, convertible, flags")
r = put_table(sh, r, CMP, "4. Comparison with the Step I panels (traccia B): consumers, buyers and spending for the six products present everywhere",
              "Differences are explained; the dataset keeps what Step I removes (outliers, answers 'no' with a quantity, refugee camp).")
r = put_table(sh, r, vsum, "5. Derived totals: recomputed from the item columns of the wide table, compared with the totals built from the long table")
r = put_table(sh, r, shr, "6. Median share of animal-source spending in the module's 7-day food spending (sanity check)")
r = put_table(sh, r, IS.sort_values(["country", "year", "slot"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s),
              "7. Every item in every round: counts, flags, median unit value (local currency per standard unit)")
sh.set_column(0, 0, 42); sh.set_column(1, 30, 13)

# ------------------------------------------------------------------------------------------
# 11. Harmonization_Log
# ------------------------------------------------------------------------------------------
LOG = [
    ("D01", "unit", "all", "One row per country x round x household of the food module; key hh_uid. All households of each module are kept, also those without Step I household variables.", "Requested structure; no silent drops.", "applied"),
    ("D02", "items", "all", "Each original item code of each round is mapped to one harmonized item (slot); the label is checked against a pattern in every round; one code per item per round (make_item_map.py, item_map.csv).", "Codes move and change meaning between rounds (Ethiopia 201 = butter/ghee in 2015, horsebeans from 2018; Nigeria 44 and 114).", "applied"),
    ("D03", "categories", "all", "Meat: red (beef, goat, mutton, pork, camel), white (poultry), minor (game, offal, insects, snails, rabbit, mice, other), processed (sausages, corned beef, canned meat). Fish: fresh (incl. frozen), dried/smoked/salted, canned/packaged, product, unspecified. Snails (listed under fish in Nigeria) are minor meat. Tanzania beef (with minced meat and sausages) and pork (with sausages and bacon) stay in red meat.", "Your categories; the survey items do not allow a cleaner split.", "NEEDS YOUR APPROVAL"),
    ("D04", "totals", "TZA, NGA, UGA, MWI", "Kept but not counted in any total: infant formula; butter mixed with margarine where they are one item (Tanzania, Nigeria, Uganda); coconut and kola nut (low in protein). Total: exp_not_counted.", "Not animal-source or not protein-rich.", "NEEDS YOUR APPROVAL"),
    ("D05", "totals", "MWI", "Cooked food from vendors (meat, chicken, fish, boiled eggs, groundnuts) is its own subtotal exp_vendor, outside the animal-source and protein totals.", "Prepared meals, not food bought for home preparation; only Malawi asks them in this module.", "NEEDS YOUR APPROVAL"),
    ("D06", "totals", "MWI", "Tinned meat or fish (512) and the 'other' of the meat and fish group (515) cannot go to meat or fish: category asf_mixed, counted in the animal-source total only.", "Not separable.", "NEEDS YOUR APPROVAL"),
    ("D07", "totals", "TZA, MWI", "Fresh beans and peas are counted in the plant-protein total, with their own subtotal exp_plant_pulses_fresh.", "Fresh shelled beans and peas are protein foods; green pods are not, and the labels do not always say which.", "NEEDS YOUR APPROVAL"),
    ("D08", "consumption", "all", "cons = 1 if the answer is yes or any quantity or spending is reported; 0 if the answer is no; in rounds listing only consumed items (Nigeria 2010, Uganda 2010-2015) an item not listed is 0. Contradictions are flagged: 8 ('no' with quantity, 27 cases, here consumed; Step I uses the answer), 16 ('yes' without any quantity).", "Reported quantities are information; the answer is kept in raw_cons.", "NEEDS YOUR APPROVAL"),
    ("D09", "missing vs zero", "all", "Not consumed: quantities 0 and spending 0. Consumed but not convertible: quantity empty. Bought but no value: spending empty. Not answered: empty. Item not in the round: empty. Uganda fills only the sources used: a source with no quantity and no value is 0 (structural zero of the questionnaire).", "Requested: no NA turned into 0.", "applied"),
    ("D10", "spending", "all", "exp = 7-day purchase spending. Own production and gifts have no value in Ethiopia, Tanzania, Malawi and Nigeria; Uganda values them (raw_val_own, raw_val_gift) and its exp is purchases consumed at home only (purchases away from home in raw_val_away), as in Step I.", "Same definition as Step I.", "applied"),
    ("D11", "units", "all", "Quantities are converted only with the surveys' official conversion tables or with units of metric content: Ethiopia Food_CF national factors; Tanzania codes 1-5; Malawi metric codes, 'other (specify)' text and the 2020 table; Nigeria survey tables 2012-2015 with metric fallback, 2010 metric labels; Uganda metric content of the unit label. Step I decisions kept: Tanzania eggs 55 g; Uganda chicken 1.3 kg per bird; Uganda 'Nice cup' of milk 0.5 l. Local units without a factor stay unconverted (flag 64).", "No invented factors.", "applied"),
    ("D12", "units", "MWI", "The official 2020 factor table is NOT used for red meat, fish and other poultry (implied prices contradict it, as in Step I); it is used for whole chicken, fresh and powdered milk (as in Step I) and, new in this dataset, for pulses, groundnuts, nuts, seeds and soy.", "Without the table most plant items in Malawi have no quantity; Step I did not use plant items.", "NEEDS YOUR APPROVAL"),
    ("D13", "units", "ETH, NGA", "Eggs: pieces in Tanzania, Malawi and Uganda; kg in Ethiopia and Nigeria (their official tables convert pieces to kg). Two columns (_pc and _kg); no conversion between them.", "Converting would need an egg weight (55 g, as Tanzania); you may want qty_eggs_pc for all.", "NEEDS YOUR APPROVAL"),
    ("D14", "units", "all", "No summed dairy quantity (litres and kg mixed); fresh milk in litres. Tanzania powdered or tinned milk: litres counted as kg.", "Units differ.", "applied"),
    ("D15", "outliers", "all", "Outliers are flagged, not removed: flag 1 (implied price outside 1/10-10 x median), 2 (quantity > 100 x median), 4 (spending > 100 x median), thresholds of Step I rules M17/M18 computed by item and round. Step I sets them to missing.", "Original data preserved; the user decides.", "NEEDS YOUR APPROVAL"),
    ("D16", "items", "ETH", "Ethiopia 2011 and 2013 codes 8 and 9: the module calls them chick pea and field pea, the conversion table the other way round. Kept as eth_pea_code8 and eth_pea_code9 (in the pulses total), not linked to chickpea / field_pea of 2015-2021.", "Identity unresolved.", "NEEDS YOUR APPROVAL"),
    ("D17", "units", "TZA", "Tanzania 2020 weight estimates of non-standard units (hh_ja02b) are kept raw (raw_q_weight, raw_unit_weight) but not used for conversion.", "Step I does not use them; using them would make 2020 more convertible than 2008-2014.", "NEEDS YOUR APPROVAL"),
    ("D18", "sources", "NGA", "Nigeria: post-harvest visit only (as Step I). 2012-2015 also ask the quantity consumed out of purchases (q5): converted as qty_frompur; the totals use the total consumed (q2).", "Purchases (q3) refer to buying, q5 to eating.", "applied"),
    ("D19", "weights", "TZA, UGA, MWI", "Weights as in the Step I panels; where a household has none (Tanzania 2010 2%, 2012 3%; Uganda 2015 1%; Malawi 2024 camp households have the cover weight) the weight is empty, not 1.", "Requested: no automatic values.", "NEEDS YOUR APPROVAL"),
    ("D20", "welfare", "all", "welfare on each country's Step I scale (see Data_Dictionary); welfare_quintile within country and round, unweighted. Levels are not comparable across countries (currency, nominal vs real, per capita vs per adult equivalent).", "Same as Step I.", "applied"),
    ("D21", "demography", "MWI, NGA", "adulteq = household size in Malawi and Nigeria (the aggregates have no scale), as in Step I. Nigeria panels have no demographic shares.", "Same as Step I.", "applied"),
    ("D22", "food spending", "all", "Total food spending: food_exp_7d_module = 7-day purchase spending on all items of the module (not food consumption); food_cons_annual_official = food part of the official aggregate.", "Your scope: other foods only as total food spending.", "applied"),
    ("D23", "design", "ETH, TZA", "rural from the raw codes (ETH, TZA 1 = rural; NGA 2 = rural; MWI, UGA 0 = rural). The urban column of Step I prep() is inverted for Ethiopia and Tanzania (found in Step II A).", "Correct coding.", "applied"),
    ("D24", "Step I", "MWI", "Malawi 522 chicken pieces (2016-2024) is in this dataset (white meat) but NOT in the Step I item list ITEMS_MW: Step I undercounts poultry in Malawi 2016-2024.", "Found while building the item map.", "ACTION FOR STEP I"),
    ("D25", "units", "UGA", "Uganda records one unit for all sources: kept once, in raw_unit_tot.", "Avoid four identical columns.", "applied"),
    ("D26", "format", "all", "Unit codes are stored as text (Malawi codes such as '9A'); labels in a sixth sheet, Unit_Codes. Item codes and labels by round in the Comparability_Matrix.", "Reading tools guess types from the first rows and would turn '9A' into missing.", "NEEDS YOUR APPROVAL (extra sheet)"),
    ("D27", "flags", "all", "flag is filled for consumed items only; empty for items not consumed or not asked.", "The checks apply only to reported consumption.", "applied"),
    ("D28", "design", "MWI", "Malawi 2024 Dzaleka refugee camp households (386) are in the food module and kept, refugee_camp = 1. They are not in Step I and have no welfare aggregate.", "No silent drops; easy to exclude.", "NEEDS YOUR APPROVAL"),
    ("D29", "coverage", "NGA", "Nigeria 2018 (wave 4) and 2023 (wave 5) are NOT included: the archives were not found extracted on the computer. Wave 4 purchases use a different recall and spending definition (TRAP N2) and need a decision when added.", "Pending files.", "PENDING"),
    ("D30", "coverage", "TZA", "Tanzania 2020 has two samples: hh_sec_ja1 (4,290 households, new item list that splits poultry) and hh_sec_j1 (419 households, old list); food_module_tza tells which.", "Survey design.", "applied"),
]
LOGDF = pd.DataFrame(LOG, columns=["id", "area", "scope", "decision", "why", "status"])
SRCDF = pd.DataFrame([dict(country=c, year=y, round=ROUND_NAME[(c, y)], survey=SURVEY[c], food_module_file=FOOD_FILE[(c, y)], recall="7 days",
                           conversion_table=CONV_TABLE[c], only_consumed_items_listed="yes" if (c, y) in ONLY_CONSUMED else "no",
                           households=int(BL[(BL.country == c) & (BL.year == y)].households.iloc[0]),
                           items_mapped=int(BL[(BL.country == c) & (BL.year == y)].items_mapped.iloc[0]),
                           currency=CURRENCY[c]) for c, y in ROUNDS])
CODE = pd.DataFrame([("make_item_map.py", "item rules: original code -> harmonized item, with label checks", "item_map.csv"),
                     ("build_protein_dataset.R", "reads the raw food modules, converts units, builds household x item tables", "long_<CC>.csv.gz, module_households.csv, build_log.csv"),
                     ("hh_info.R", "household variables from the Step I panels and functions of ASF_completo.R", "hh_info.csv"),
                     ("unit_codes.R", "unit codes and labels of each round", "unit_codes.csv"),
                     ("assemble_dataset.py", "wide table, totals, checks and this workbook", "this .xlsx and the .csv.gz")], columns=["script (code/dataset/)", "what it does", "output"])
sh = SHEETS["Harmonization_Log"]
r = 0
sh.write_string(r, 0, "HARMONIZATION LOG", F["title"]); r += 1
sh.write_string(r, 0, f"Built {TODAY} from the raw World Bank LSMS-ISA archives. Rows with status NEEDS YOUR APPROVAL are choices that change the totals or the item set.", F["note"]); r += 2
r = put_table(sh, r, LOGDF, "A. Decisions")
r = put_table(sh, r, SRCDF, "B. Sources by round")
r = put_table(sh, r, CODE, "C. Code (repository folder code/dataset)")
sh.set_column(0, 0, 10); sh.set_column(1, 2, 16); sh.set_column(3, 3, 110, F["wrap"]); sh.set_column(4, 4, 60, F["wrap"]); sh.set_column(5, 5, 26)

# ------------------------------------------------------------------------------------------
# 12. Unit_Codes
# ------------------------------------------------------------------------------------------
UC = pd.read_csv(os.path.join(BUILD, "unit_codes.csv"), dtype=str, keep_default_na=False, na_values=[""])
UC["rows_protein_items"] = pd.to_numeric(UC["rows_protein_items"])
sh = SHEETS["Unit_Codes"]
r = put_table(sh, 0, UC, "UNIT CODES of the food modules (annex)", "rows_protein_items: item rows of the protein-rich items using the code. Codes without label: observed in the data, not labelled in the file.")
sh.set_column(0, 3, 14); sh.set_column(4, 4, 10); sh.set_column(5, 5, 40)

wb.close()
print(f"written {XLSX} ({os.path.getsize(XLSX) / 1e6:.1f} MB) and {CSVF} ({os.path.getsize(CSVF) / 1e6:.1f} MB), {NROWS} rows x {len(COLS)} columns, {time.time() - T0:.0f}s")
CMP.to_csv(os.path.join(OUTD, "qc_step1_comparison.csv"), index=False)
VERIFY.to_csv(os.path.join(OUTD, "qc_verify_totals.csv"), index=False)
summary.to_csv(os.path.join(OUTD, "qc_summary.csv"), index=False)
ITEMSTATS.to_csv(os.path.join(OUTD, "qc_items.csv"), index=False)
