#!/usr/bin/env python3
"""
HARMONIZED HOUSEHOLD FOOD-CONSUMPTION DATASET, LONG FORMAT (v1, 23 Nov 2026)

Outputs
  food_items_long_<date>.csv.gz   one row per household x round x original food item: the same ~45 standardized
                                  columns for every country and round (kg by source, spending, status flags)
  households_<date>.csv.gz        one row per household x round: design, characteristics, official welfare
  food_dataset_documentation_<date>.xlsx   Households, Item_Classification, Item_Mapping, Data_Dictionary,
                                  Comparability_Matrix, Quality_Control

Rules
  - rows keep the most detailed item of the questionnaire (item_detail); `item` groups details that are the
    same product in every survey; combined categories are never split (e.g. meat_unspecified);
  - one column per concept: "quantity consumed out of purchases" is one column whatever its name in the file;
    concepts that differ stay apart (Nigeria 2010-2015 "quantity purchased in the last 7 days"; Nigeria
    2018-2023 "most recent purchase in the last 30 days");
  - 0 only for "not consumed" or "not from this source"; empty for missing; `not_collected` lists the
    variables that the round does not ask.

USE  python3 build_long_food_dataset.py <build dir> <item_map.csv> <item_classification.csv> <protein_coefficients.csv>
                                        <hh_info.csv> <wdi_gdp_pc_ppp.csv> <out dir>
"""
import datetime, math, os, re, sys, time
import numpy as np
import pandas as pd
import xlsxwriter

BUILD, MAPF, CLASSF, COEFF, HHINFO, GDPF, OUTD = sys.argv[1:8]
os.makedirs(OUTD, exist_ok=True)
TODAY = datetime.date.today().isoformat()
T0 = time.time()
COUNTRIES = ["ETH", "TZA", "MWI", "NGA", "UGA"]
ckey = lambda s: s.map(COUNTRIES.index) if s.name == "country" else s
KEY = ["country", "year", "hhid"]
EGG_KG, MILK_DENSITY = 0.055, 1.03
SVY = {("NGA", 2018), ("NGA", 2023)}                         # quantities x the file's own kg/l factor
ONLY_CONSUMED = {("NGA", 2010), ("UGA", 2010), ("UGA", 2011), ("UGA", 2013), ("UGA", 2015)}
CURRENCY = {"ETH": "ETB", "TZA": "TZS", "MWI": "MWK", "NGA": "NGN", "UGA": "UGX"}
num = lambda s: pd.to_numeric(s, errors="coerce")

# ------------------------------------------------------------------------------------------
# 1. classification, coefficients, unit labels
# ------------------------------------------------------------------------------------------
MAP = pd.read_csv(MAPF); MAP["round"] = MAP.year.apply(lambda y: int(math.floor(y)))
CL = pd.read_csv(CLASSF).set_index("item_detail")
CO = pd.read_csv(COEFF); CO["g_per_kg"] = CO.protein_g_per_100g * 10 * CO.edible_portion
STD = MAP.drop_duplicates(["country", "slot"]).set_index(["country", "slot"])["std"].to_dict()
DAIRY = set(MAP.loc[MAP.cat == "dairy", "slot"]); EGGS = set(MAP.loc[MAP.cat == "eggs", "slot"])
def coef(cc, s):
    x = CO[(CO.slot == s) & (CO.country == cc)]
    return (x if len(x) else CO[(CO.slot == s) & (CO.country == "*")]).iloc[0]
COEF = {(c, s): coef(c, s) for c, s in MAP[["country", "slot"]].drop_duplicates().itertuples(index=False)}
UC = pd.read_csv(os.path.join(BUILD, "unit_codes.csv"), dtype=str, keep_default_na=False, na_values=[""]); UC["year"] = UC.year.astype(int)
RV = pd.read_csv(os.path.join(BUILD, "role_vars.csv")); RV = RV[RV.exists].copy(); RV["year"] = RV.year.astype(int)
UVAR = RV[RV.role == "u_tot"].groupby(["country", "year"]).variable.apply(set).to_dict()     # unit variable(s) of the total
ULAB = {}
for c, y, v, code, lab in UC[["country", "year", "variable", "code", "label"]].itertuples(index=False):
    if v in UVAR.get((c, y), set()):
        ULAB.setdefault((c, y, str(code).replace(".0", "")), lab)
def label_kg(lab):
    if not isinstance(lab, str) or re.search(r"(?i)up to|to \d|above|-\s*\d|lt", lab):
        return np.nan
    m = re.search(r"\((\d+(?:\.\d+)?)\s?kgs?\)", lab, re.I)
    return float(m.group(1)) if m else np.nan
TZA_WT = {"1": 1.0, "2": 0.001, "3": 1.0, "4": 0.001}

# what each round collects (from role_vars: the questions found in the files)
HAS = RV.groupby(["country", "year"]).role.apply(set).to_dict()
def collected(c, y):
    r = HAS.get((c, y), set())
    return {"qty_total_kg": True,
            "qty_from_purchases_kg": not (c == "NGA" and y == 2010),
            "qty_purchased_kg": c == "NGA" and y in (2010, 2012, 2015),
            "qty_own_kg": True, "qty_gift_kg": True,
            "qty_away_kg": c == "UGA", "value_away": c == "UGA", "value_own": c == "UGA", "value_gift": c == "UGA",
            "exp_purchases": (c, y) not in SVY,
            "purchased_30d": (c, y) in SVY, "qty_last_purchase_kg": (c, y) in SVY, "value_last_purchase": (c, y) in SVY}
OPTIONAL = list(collected("ETH", 2011).keys())

# ------------------------------------------------------------------------------------------
# 2. household dataset
# ------------------------------------------------------------------------------------------
HR = pd.read_csv(os.path.join(BUILD, "hh_raw.csv"), dtype=str, keep_default_na=False, na_values=[""]); HR["year"] = HR.year.astype(int)
HS = pd.read_csv(os.path.join(BUILD, "hh_raw_sources.csv"), keep_default_na=False, na_values=[""])
HI = pd.read_csv(HHINFO, dtype={"hhid": str, "panel_id": str}, low_memory=False); HI["year"] = HI.year.astype(int)
MOD = pd.read_csv(os.path.join(BUILD, "module_households.csv"), dtype={"hhid": str, "module": str}, keep_default_na=False, na_values=[""])
MOD["year"] = MOD.year.astype(int)
FOODFILE = {("ETH", 2011): "sect5a_hh_w1", ("ETH", 2013): "sect5a_hh_w2", ("ETH", 2015): "sect5a_hh_w3", ("ETH", 2018): "sect6a_hh_w4", ("ETH", 2021): "sect6a_hh_w5",
            ("MWI", 2010): "hh_mod_g1", ("MWI", 2016): "hh_mod_g1", ("MWI", 2019): "hh_mod_g1", ("MWI", 2024): "hh_mod_g1",
            ("NGA", 2010): "sect10b_harvestw1", ("NGA", 2012): "sect10b_harvestw2", ("NGA", 2015): "sect10b_harvestw3", ("NGA", 2018): "sect10b_harvestw4",
            ("NGA", 2023): "sect5b_harvestw5", ("UGA", 2010): "GSEC15b", ("UGA", 2011): "GSEC15B", ("UGA", 2013): "GSEC15B", ("UGA", 2015): "gsec15b",
            ("UGA", 2018): "GSEC15B", ("UGA", 2019): "gsec15b"}
H = MOD[KEY + ["module"]].merge(HR, on=KEY, how="left", indicator=True)
H["in_household_files"] = (H._merge == "both").astype(int); H = H.drop(columns="_merge")
H["food_module_file"] = [m if isinstance(m, str) else FOODFILE[(c, y)] for c, y, m in zip(H.country, H.year, H.module)]
H = H.merge(HI[KEY + ["panel_id", "hhsize", "head_female", "head_age", "share_child", "share_elderly", "welfare"]].rename(
    columns={"hhsize": "hhsize_step1", "welfare": "welfare_step1"}), on=KEY, how="left")
src = lambda col: HS[HS.column == col].set_index(["country", "year"]).variable.to_dict()
for c in ["weight", "hhsize", "adulteq"] + [a for a in HR.columns if a.startswith("agg_")]:
    if c in H:
        H[c] = num(H[c])
# household size: file; if the file has none (Malawi 2010, Uganda 2011), the roster count of Step I
H["hhsize_source"] = np.where(H.hhsize.notna(), "aggregate/cover file", np.where(H.hhsize_step1.notna(), "roster count (Step I)", None))
H["hhsize"] = H.hhsize.fillna(H.hhsize_step1)
H["adulteq_source"] = np.where(H.adulteq.notna(), "official aggregate", "not in the files")
# rural from the value labels of the original urban/rural variable
VL = HS[HS.column == "urban_rural"].set_index(["country", "year"]).value_labels.to_dict()
def rural_codes(lbl):
    if not isinstance(lbl, str):
        return None
    return {p.split("=", 1)[0].strip() for p in lbl.split(";") if re.search(r"(?i)rural", p.split("=", 1)[-1])}
H["rural"] = [np.nan if not isinstance(u, str) else float(u.replace(".0", "") in (rural_codes(VL.get((c, y))) or set())) for c, y, u in zip(H.country, H.year, H.urban_rural)]
H["refugee_camp"] = num(H.refugee_camp_sample)
H["panel_id"] = np.where(H.country.eq("NGA") & H.year.isin([2018, 2023]), H.hhid, H.panel_id)
# welfare: the official per-person variable where the file has one; the annual standardized measure
def g(col): return H[col] if col in H else pd.Series(np.nan, index=H.index)
W = pd.Series(np.nan, index=H.index); WO = pd.Series(np.nan, index=H.index); WV = pd.Series(None, index=H.index, dtype=object)
WF = pd.Series(None, index=H.index, dtype=object)
for (c, y), ix in H.groupby(["country", "year"]).groups.items():
    if c == "ETH":
        WO[ix] = g("agg_nom_totcons_aeq")[ix]; W[ix] = WO[ix]; WV[ix] = "nom_totcons_aeq"; WF[ix] = "nom_totcons_aeq"
    elif c == "TZA" and y < 2020:
        W[ix] = g("agg_expmR")[ix] / H.adulteq[ix]; WV[ix] = "none (expmR and adulteq in the file)"; WF[ix] = "expmR / adulteq"
    elif c == "TZA":
        WO[ix] = g("agg_expmR_pae")[ix]; W[ix] = WO[ix] * 365 / 28; WV[ix] = "expmR_pae (per 28 days)"; WF[ix] = "expmR_pae x 365/28"
    elif c == "MWI" and y == 2010:
        W[ix] = g("agg_rexpagg")[ix] / H.hhsize[ix]; WV[ix] = "none (rexpagg in the file)"; WF[ix] = "rexpagg / hhsize (roster count)"
    elif c == "MWI":
        WO[ix] = g("agg_rexpaggpc")[ix]; W[ix] = WO[ix]; WV[ix] = "rexpaggpc"; WF[ix] = "rexpaggpc"
    elif c == "NGA":
        v = {2010: "agg_totcons", 2012: "agg_totcons", 2015: "agg_totcons", 2018: "agg_totcons_pc", 2023: "agg_totcons_adj"}[y]
        WO[ix] = g(v)[ix]; W[ix] = WO[ix]; WV[ix] = v[4:]; WF[ix] = v[4:]
    elif c == "UGA":
        WO[ix] = g("agg_welfare")[ix]; W[ix] = WO[ix] * 12; WV[ix] = "welfare (monthly)"; WF[ix] = "welfare x 12"
H["welfare_official"] = WO; H["welfare_official_var"] = WV; H["welfare_annual"] = W; H["welfare_formula"] = WF
H["welfare_scale"] = H.country.map({"ETH": "per adult equivalent", "TZA": "per adult equivalent", "UGA": "per adult equivalent", "MWI": "per person", "NGA": "per person"})
PRICES = {"ETH": "nominal", "TZA": "real (NPS spatial-temporal deflator)", "MWI": "real (prices of the survey's base month)", "UGA": "constant prices (2005/06 in 2010-2013, 2009/10 in 2015-2019)"}
H["welfare_prices"] = [("spatially and temporally adjusted, 2023 prices" if y == 2023 else "nominal") if c == "NGA" else PRICES[c] for c, y in zip(H.country, H.year)]
def wq(d):
    w = d.weight * d.hhsize
    ok = d.welfare_annual.notna() & w.notna() & (w > 0)
    q = pd.Series(np.nan, index=d.index)
    if ok.sum() >= 5:
        s = d[ok].sort_values("welfare_annual"); cw = (s.weight * s.hhsize).cumsum() / (s.weight * s.hhsize).sum()
        q[s.index] = np.minimum(np.floor(cw.to_numpy() * 5 - 1e-12) + 1, 5)
    return q
H["welfare_quintile"] = pd.concat([wq(d) for _, d in H.groupby(["country", "year"])])
H["welfare_quintile_official"] = np.where(H.country == "ETH", g("agg_cons_quint"), np.where(H.country == "UGA", g("agg_quints"), np.nan))
H["cons_total_hh_annual"] = np.select([H.country == "ETH", H.country == "TZA", H.country == "MWI", H.country == "UGA"],
                                      [g("agg_total_cons_ann"), g("agg_expm"), g("agg_expagg"), g("agg_nrrexp30") * 12], np.nan)
H["cons_total_hh_var"] = np.select([H.country == "ETH", H.country == "TZA", H.country == "MWI", (H.country == "UGA") & g("agg_nrrexp30").notna()],
                                   ["total_cons_ann (nominal)", "expm (nominal)", "expagg (nominal)", "nrrexp30 x 12 (nominal)"], None)
H["food_cons_hh_annual"] = np.select([H.country == "ETH", (H.country == "TZA") & (H.year < 2020), H.country == "MWI", (H.country == "UGA") & g("agg_fnrfxp30").notna()],
                                     [g("agg_food_cons_ann"), g("agg_foodbev"), g("agg_rexp_cat011"), g("agg_fnrfxp30") * 12], np.nan)
H["food_cons_hh_var"] = np.select([H.country == "ETH", (H.country == "TZA") & (H.year < 2020), H.country == "MWI", (H.country == "UGA") & g("agg_fnrfxp30").notna()],
                                  ["food_cons_ann (nominal)", "foodbev (nominal, food and non-alcoholic beverages)", "rexp_cat011 (real)", "fnrfxp30 x 12 (nominal)"], None)
GDP = pd.read_csv(GDPF); H = H.merge(GDP, on=["country", "year"], how="left")
H["weight_var"] = [src("weight").get((c, y)) for c, y in zip(H.country, H.year)]
H["survey_round"] = H.country + "_" + H.year.astype(str); H["hh_uid"] = H.survey_round + "_" + H.hhid; H["currency"] = H.country.map(CURRENCY)
HCOLS = ["hh_uid", "country", "year", "survey_round", "hhid", "panel_id", "food_module_file", "in_household_files", "weight", "weight_var",
         "region", "district", "subdistrict", "ea", "strata", "rural", "urban_rural", "refugee_camp", "int_month", "int_year",
         "hhsize", "hhsize_source", "adulteq", "adulteq_source", "head_female", "head_age", "share_child", "share_elderly",
         "welfare_annual", "welfare_formula", "welfare_scale", "welfare_prices", "welfare_official", "welfare_official_var",
         "welfare_quintile", "welfare_quintile_official", "cons_total_hh_annual", "cons_total_hh_var", "food_cons_hh_annual", "food_cons_hh_var",
         "currency", "gdp_pc_ppp_const2021", "welfare_step1"]
H = H.rename(columns={"urban_rural": "urban_rural_code"}); HCOLS[HCOLS.index("urban_rural")] = "urban_rural_code"
H = H[HCOLS].sort_values(KEY, key=ckey).reset_index(drop=True)
assert not H.duplicated(KEY).any()
print(f"households: {len(H)} ({time.time() - T0:.0f}s)", flush=True)

# ------------------------------------------------------------------------------------------
# 3. long dataset
# ------------------------------------------------------------------------------------------
USE = ["hhid", "year", "slot", "code", "row_in_module", "cons", "cons_raw", "q_tot", "u_tot", "q_pur", "q_away", "q_own", "q_gift", "q_frompur", "exp",
       "val_away", "val_own", "val_gift", "s_tot", "s_pur", "s_own", "s_gift", "s_away", "s_frompur", "cvn_tot", "cvn_lastpur", "q_lastpur",
       "val_lastpur", "pur30_yn", "q_wt", "u_wt", "flag"]
HJ = H[KEY + ["hh_uid", "survey_round", "weight", "hhsize", "adulteq", "welfare_annual", "welfare_quintile", "rural", "currency"]]
LCOLS = ["hh_uid", "country", "year", "survey_round", "hhid", "weight", "hhsize", "adulteq", "welfare_annual", "welfare_quintile", "rural",
         "item_code_orig", "item_detail", "item", "food_group", "food_supergroup", "item_comparability",
         "consumption_status", "consumed", "qty_total_orig", "unit_total_orig", "unit_total_label",
         "qty_total_kg", "qty_from_purchases_kg", "qty_purchased_kg", "qty_own_kg", "qty_gift_kg", "qty_away_kg",
         "exp_purchases", "value_away", "value_own", "value_gift", "purchased_30d", "qty_last_purchase_kg", "value_last_purchase",
         "qty_status", "conv_method", "protein_g", "protein_coef_quality", "flag_outlier", "flag_inconsistent", "not_collected", "currency"]
LONGF = os.path.join(OUTD, f"food_items_long_{TODAY}.csv.gz")
first = True; QC = []; STAT = []; CONV = []; QORIG = []
DOC_ONLY = os.environ.get("DOC_ONLY") == "1"      # rebuild only the workbook from the statistics of a previous run
for cc in ([] if DOC_ONLY else COUNTRIES):
    L = pd.read_csv(os.path.join(BUILD, f"long_{cc}.csv.gz"), usecols=lambda c: c in USE, dtype={"hhid": str, "u_tot": str, "u_wt": str, "slot": str},
                    low_memory=False, keep_default_na=False, na_values=[""])
    for c in USE:
        if c not in L.columns:
            L[c] = np.nan
    L["year"] = L.year.astype(float).astype(int); L["country"] = cc
    L = L.sort_values(["year", "hhid", "slot"]).reset_index(drop=True)
    svy = np.array([(cc, y) in SVY for y in L.year])
    f = np.array([1.0 if STD[(cc, s)] == "kg" else (MILK_DENSITY if s in DAIRY else 1.0) if STD[(cc, s)] == "litre"
                  else EGG_KG if s in EGGS else np.nan for s in L.slot])                 # pieces: eggs only (coconuts stay unconverted)
    c0 = L.cons == 0; c1 = L.cons == 1
    tot = np.where(svy, L.q_tot * L.cvn_tot, L.s_tot * f)
    if cc == "NGA":
        fp = np.where(svy, L.q_frompur * L.cvn_tot, np.where(L.year.isin([2012, 2015]), L.s_frompur * f, np.nan))
        pu = np.where(L.year.isin([2010, 2012, 2015]), L.s_pur * f, np.nan)
    else:
        fp = L.s_pur * f; pu = np.full(len(L), np.nan)
    own = np.where(svy, L.q_own * L.cvn_tot, L.s_own * f); gift = np.where(svy, L.q_gift * L.cvn_tot, L.s_gift * f)
    away = L.s_away * f if cc == "UGA" else np.full(len(L), np.nan)
    X = pd.DataFrame({"qty_total_kg": tot, "qty_from_purchases_kg": fp, "qty_purchased_kg": pu, "qty_own_kg": own, "qty_gift_kg": gift, "qty_away_kg": away}, index=L.index)
    method = pd.Series(np.where(svy, "survey kg/l factor in the file", "survey conversion table or metric unit"), index=L.index, dtype=object)
    if cc == "TZA":      # items counted in pieces (eggs, coconut) but recorded in kg or g: kilograms directly
        u = L.u_tot.fillna("").str.replace(".0", "", regex=False)
        fill = X.qty_total_kg.isna() & c1 & u.isin(["1", "2"]) & L.q_tot.notna()
        X.loc[fill, "qty_total_kg"] = L.q_tot[fill] * u[fill].map({"1": 1.0, "2": 0.001}); method[fill] = "metric unit (kg, g) of an item counted in pieces"
        w = L.u_wt.fillna("").str.replace(".0", "", regex=False).map(TZA_WT)
        fill = X.qty_total_kg.isna() & c1 & L.q_wt.notna() & w.notna()
        X.loc[fill, "qty_total_kg"] = L.q_wt[fill] * w[fill]; method[fill] = "survey weight estimate (Tanzania 2020)"
    if cc == "UGA":
        k = pd.Series([label_kg(ULAB.get((cc, y, str(u).replace(".0", "")))) for y, u in zip(L.year, L.u_tot)], index=L.index)
        isk = np.array([STD[(cc, s)] == "kg" for s in L.slot])
        fill = X.qty_total_kg.isna() & c1 & k.notna() & isk
        qs = L[["q_pur", "q_away", "q_own", "q_gift"]][fill]
        X.loc[fill, "qty_total_kg"] = qs.sum(axis=1, min_count=1) * k[fill]
        X.loc[fill, "qty_from_purchases_kg"] = qs.q_pur.fillna(0) * k[fill]; X.loc[fill, "qty_away_kg"] = qs.q_away.fillna(0) * k[fill]
        X.loc[fill, "qty_own_kg"] = qs.q_own.fillna(0) * k[fill]; X.loc[fill, "qty_gift_kg"] = qs.q_gift.fillna(0) * k[fill]
        method[fill] = "kilograms stated in the unit label"
    eggs = np.array([STD[(cc, s)] == "piece" and s in EGGS for s in L.slot]) & ~svy
    method[eggs] = "pieces at 55 g per egg"
    # zeros: not consumed, or a source with quantity 0 (the file then has no unit)
    mq = np.where(svy | (L.year.isin([2012, 2015]) & (cc == "NGA")), L.q_frompur, L.q_pur) if cc == "NGA" else L.q_pur
    for col, q in [("qty_from_purchases_kg", mq), ("qty_purchased_kg", L.q_pur), ("qty_own_kg", L.q_own), ("qty_gift_kg", L.q_gift), ("qty_away_kg", L.q_away)]:
        X.loc[(pd.Series(q, index=L.index) == 0) & X[col].isna(), col] = 0.0
    for col in X.columns:
        X.loc[c0, col] = 0.0
    # values (Uganda): a source not used is 0, as for quantities
    V = pd.DataFrame(index=L.index)
    for col, raw, q in [("value_away", "val_away", "q_away"), ("value_own", "val_own", "q_own"), ("value_gift", "val_gift", "q_gift")]:
        v = L[raw].copy()
        if cc == "UGA":
            v[v.isna() & (c0 | (c1 & L[q].isna()))] = 0.0
        V[col] = v
    out = pd.DataFrame({"country": cc, "year": L.year, "hhid": L.hhid, "item_code_orig": L.code, "item_detail": L.slot})
    for col in ["item", "food_group", "food_supergroup", "item_comparability"]:
        out[col] = L.slot.map(CL[col]).to_numpy()
    unc = ((cc == "ETH") & L.slot.isin(["eth_pea_code8", "eth_pea_code9"])) | ((cc == "UGA") & (L.year <= 2015) & (L.slot == "groundnuts_shelled"))
    out.loc[unc, "item_comparability"] = "uncertain"
    rim = L.row_in_module.fillna(1)
    out["consumption_status"] = np.select([c1, c0 & (rim == 1), c0 & (rim == 0), L.cons.isna() & (rim == 0)],
                                          ["consumed", "not_consumed", "not_listed", "no_record"], "not_answered")
    out["consumed"] = L.cons
    out["qty_total_orig"] = L.q_tot; out["unit_total_orig"] = L.u_tot.str.replace(r"\.0$", "", regex=True)
    out["unit_total_label"] = [ULAB.get((cc, y, u)) if isinstance(u, str) else None for y, u in zip(L.year, out.unit_total_orig)]
    for col in X.columns:
        out[col] = X[col]
    out["exp_purchases"] = np.where(svy, np.nan, L.exp)
    for col in V.columns:
        out[col] = V[col]
    out["purchased_30d"] = np.where(L.pur30_yn == 1, 1.0, np.where(L.pur30_yn == 2, 0.0, np.nan))
    out["qty_last_purchase_kg"] = L.q_lastpur * L.cvn_lastpur; out["value_last_purchase"] = L.val_lastpur
    noq = L[["q_tot", "q_pur", "q_own", "q_gift", "q_away", "q_frompur"]].isna().all(axis=1)
    out["qty_status"] = np.select([c0, c1 & X.qty_total_kg.notna(), c1 & noq, c1], ["not_consumed", "converted", "no_quantity", "not_convertible"], "not_answered")
    method[~c1] = None; method[c1 & X.qty_total_kg.isna()] = "not converted"
    out["conv_method"] = method
    co = pd.DataFrame([COEF[(cc, s)] for s in L.slot], index=L.index)
    gk = co.g_per_kg.to_numpy().copy()
    gk[((L.slot == "milk_canned_powder") & L.u_tot.fillna("").str.replace(".0", "", regex=False).isin(["3", "4"])).to_numpy()] = 68.1
    out["protein_g"] = np.where(L.slot.map(lambda s: CL.at[s, "food_group"] in ("prepared_food", "fats_mixed", "other_plant")), np.nan, X.qty_total_kg * gk)
    out.loc[c0 & out.protein_g.isna() & ~L.slot.map(lambda s: CL.at[s, "food_group"] in ("prepared_food", "fats_mixed", "other_plant")) & pd.notna(gk), "protein_g"] = 0.0
    out["protein_coef_quality"] = co.quality.to_numpy()
    fl = L.flag.fillna(0).astype(int)
    out["flag_outlier"] = np.where(c1, ((fl & 7) > 0).astype(float), np.nan)
    out["flag_inconsistent"] = np.where(c1, ((fl & 56) > 0).astype(float), np.nan)
    nc = {y: ", ".join(k for k, v in collected(cc, y).items() if not v) for y in L.year.unique()}
    out["not_collected"] = L.year.map(nc)
    for col, ok in [(k, None) for k in OPTIONAL]:
        if col in out:
            notc = L.year.map({y: not collected(cc, y)[col] for y in L.year.unique()}).to_numpy()
            out.loc[notc, col] = np.nan
    out = out.merge(HJ, on=KEY, how="left")
    assert not out.duplicated(KEY + ["item_detail"]).any(), cc
    if first:
        out[LCOLS].to_csv(LONGF + ".tmp", index=False)
    else:
        out[LCOLS].to_csv(LONGF + ".tmp", index=False, mode="a", header=False)
    first = False
    # statistics for the quality report
    for (y, grp), d in out.groupby(["year", "food_group"]):
        cons = d[d.consumption_status == "consumed"]
        STAT.append(dict(country=cc, year=y, food_group=grp, rows=len(d), consumed=len(cons), not_consumed=int((d.consumption_status == "not_consumed").sum()),
                         not_listed=int((d.consumption_status == "not_listed").sum()), no_record=int((d.consumption_status == "no_record").sum()),
                         not_answered=int((d.consumption_status == "not_answered").sum()), converted=int((cons.qty_status == "converted").sum()),
                         not_convertible=int((cons.qty_status == "not_convertible").sum()), no_quantity=int((cons.qty_status == "no_quantity").sum()),
                         outliers=int(cons.flag_outlier.sum()), inconsistent=int(cons.flag_inconsistent.sum())))
    cm = out[out.consumption_status == "consumed"]
    CONV.append(cm.groupby(["country", "year", "food_group", "qty_status", "conv_method"], dropna=False).size().rename("n").reset_index())
    QORIG.append(out.groupby(["country", "year"]).agg(rows=("item_detail", "size"), consumed=("consumption_status", lambda x: int((x == "consumed").sum())),
                                                      q_nm=("qty_total_orig", lambda x: int(x.notna().sum())), q_sum=("qty_total_orig", "sum")).reset_index())
    # sources add up to the total?
    cons = out[(out.consumption_status == "consumed") & out.qty_total_kg.notna()]
    sm = cons[["qty_from_purchases_kg", "qty_own_kg", "qty_gift_kg"]].sum(axis=1, min_count=3)
    if cc == "UGA":
        sm = sm + cons.qty_away_kg.fillna(0)
    if cc == "NGA":
        sm = np.where(cons.year == 2010, cons[["qty_purchased_kg", "qty_own_kg", "qty_gift_kg"]].sum(axis=1, min_count=3), sm)
    rel = np.abs(np.asarray(sm, dtype=float) - cons.qty_total_kg.to_numpy()) / cons.qty_total_kg.replace(0, np.nan).to_numpy()
    for y in sorted(cons.year.unique()):
        m = (cons.year == y).to_numpy(); r = rel[m]
        QC.append(dict(country=cc, year=y, consumed_with_kg=int(m.sum()), sources_all_known=int((~np.isnan(r)).sum()),
                       sources_equal_total_within_1pct=int((r <= 0.01).sum()), sources_differ_more_than_10pct=int((r > 0.10).sum())))
    print(f"  {cc}: {len(out)} rows ({time.time() - T0:.0f}s)", flush=True)
    del L, out, X, cm, cons
import gzip, shutil, gc
gc.collect()
if not DOC_ONLY:
    with open(LONGF + ".tmp", "rb") as fi, gzip.open(LONGF, "wb", compresslevel=6) as fo:
        shutil.copyfileobj(fi, fo)
    os.remove(LONGF + ".tmp")
    STAT = pd.DataFrame(STAT); QSRC = pd.DataFrame(QC); CONV = pd.concat(CONV); QORIG = pd.concat(QORIG)
    HF = os.path.join(OUTD, f"households_{TODAY}.csv.gz"); H.to_csv(HF, index=False)
    print(f"written {LONGF} ({os.path.getsize(LONGF) / 1e6:.0f} MB), {HF} ({time.time() - T0:.0f}s)", flush=True)
    for d, n in [(STAT, "qc_status"), (QSRC, "qc_sources"), (CONV, "qc_conversion"), (QORIG, "qc_rows")]:
        d.to_csv(os.path.join(OUTD, f"{n}.csv"), index=False)
else:
    STAT, QSRC, CONV, QORIG = (pd.read_csv(os.path.join(OUTD, f"{n}.csv")) for n in ["qc_status", "qc_sources", "qc_conversion", "qc_rows"])

# ------------------------------------------------------------------------------------------
# 4. documentation workbook
# ------------------------------------------------------------------------------------------
ROUNDS = sorted({(c, int(y)) for c, y in zip(H.country, H.year)}, key=lambda r: (COUNTRIES.index(r[0]), r[1])); RLAB = [f"{c}_{y}" for c, y in ROUNDS]

# which original variables feed each harmonized variable, by round
def roles_for(var, c, y):
    if var == "consumed": return ["cons_raw"]
    if var == "qty_total_kg":
        r = ["q_tot", "u_tot"] + (["cvn_tot"] if (c, y) in SVY else []) + (["q_wt", "u_wt"] if (c, y) == ("TZA", 2020) else [])
        return r if c != "UGA" or y <= 2015 else ["u_tot", "q_pur", "q_away", "q_own", "q_gift"]
    if var == "qty_from_purchases_kg": return [] if (c, y) == ("NGA", 2010) else (["q_frompur", "u_frompur"] if c == "NGA" else ["q_pur", "u_pur"])
    if var == "qty_purchased_kg": return ["q_pur", "u_pur"] if c == "NGA" and y <= 2015 else []
    return {"qty_own_kg": ["q_own", "u_own"], "qty_gift_kg": ["q_gift", "u_gift"], "qty_away_kg": ["q_away"] if c == "UGA" else [],
            "exp_purchases": ["exp_pur"] if (c, y) not in SVY else [], "value_away": ["val_away"], "value_own": ["val_own"], "value_gift": ["val_gift"],
            "purchased_30d": ["pur30_yn"], "qty_last_purchase_kg": ["q_lastpur", "u_lastpur", "cvn_lastpur"], "value_last_purchase": ["val_lastpur"]}.get(var, [])
def orig(var, c, y):
    if var in OPTIONAL and not collected(c, y)[var]:
        return "not collected"
    v = RV[(RV.country == c) & (RV.year == y) & RV.role.isin(roles_for(var, c, y))]
    return ", ".join(dict.fromkeys(v.variable)) if len(v) else "not collected"
QVARS = ["consumed", "qty_total_kg", "qty_from_purchases_kg", "qty_purchased_kg", "qty_own_kg", "qty_gift_kg", "qty_away_kg", "exp_purchases",
         "value_away", "value_own", "value_gift", "purchased_30d", "qty_last_purchase_kg", "value_last_purchase"]
DEFN = {
 "consumed": ("1 if the item was consumed in the last 7 days, 0 if not", "0/1",
              "the yes/no answer; 1 also when a quantity or spending is reported with a 'no' (flag_inconsistent); 0 for items not listed in rounds that list only consumed items (consumption_status = not_listed)", ""),
 "qty_total_kg": ("Quantity consumed in total, last 7 days", "kg", "original quantity x kg per unit: survey conversion tables, metric units, file factors (Nigeria 2018-2023), weight estimates (Tanzania 2020), kg stated in the unit label (Uganda); milk 1.03 kg/l; eggs 55 g",
                  "empty when the unit cannot be converted (qty_status = not_convertible)"),
 "qty_from_purchases_kg": ("Quantity consumed that came from purchases (Uganda: purchased and consumed at home)", "kg", "as qty_total_kg, on the quantity from purchases", "Nigeria 2010: not collected"),
 "qty_purchased_kg": ("Quantity purchased in the last 7 days (purchases, not consumption)", "kg", "as qty_total_kg", "Nigeria 2010-2015 only: a different question from qty_from_purchases_kg"),
 "qty_own_kg": ("Quantity consumed from own production", "kg", "as qty_total_kg", "Nigeria 2018-2023: in the unit of the total"),
 "qty_gift_kg": ("Quantity consumed from gifts and other sources", "kg", "as qty_total_kg", ""),
 "qty_away_kg": ("Quantity purchased and consumed away from home", "kg", "as qty_total_kg", "Uganda only"),
 "exp_purchases": ("Amount paid for the purchases of the last 7 days", "local currency", "the amount reported; 0 if not consumed or not bought; empty if bought without amount",
                   "Nigeria 2010-2015: purchases (q3) rather than consumption from purchases; Nigeria 2018-2023 not collected on 7 days; Uganda: purchases consumed at home"),
 "value_away": ("Value of the purchases consumed away from home", "local currency", "as reported", "Uganda only"),
 "value_own": ("Value of the consumption from own production", "local currency", "as reported", "Uganda only (imputed by the respondent)"),
 "value_gift": ("Value of the consumption from gifts", "local currency", "as reported", "Uganda only"),
 "purchased_30d": ("1 if the item was purchased in the last 30 days", "0/1", "recode of the answer (1 yes, 2 no)", "Nigeria 2018-2023 only"),
 "qty_last_purchase_kg": ("Quantity of the most recent purchase (last 30 days)", "kg", "quantity x the file's kg/l factor", "Nigeria 2018-2023 only"),
 "value_last_purchase": ("Amount spent on the most recent purchase (last 30 days)", "local currency", "as reported", "Nigeria 2018-2023 only"),
}
CA = []
for v in QVARS:
    row = {"variable": v, "definition": DEFN[v][0], "unit": DEFN[v][1]}
    for (c, y), rl in zip(ROUNDS, RLAB):
        row[rl] = orig(v, c, y)
    row["note"] = DEFN[v][3]; CA.append(row)
CA = pd.DataFrame(CA)
# items x rounds
CB = []
IM = MAP.merge(CL.reset_index()[["item_detail", "item", "item_label", "food_group", "food_supergroup", "item_comparability"]], left_on="slot", right_on="item_detail", how="left")
for it, gdf in IM.groupby("item", sort=False):
    row = {"item": it, "item_label": gdf.item_label.iloc[0], "food_group": gdf.food_group.iloc[0], "food_supergroup": gdf.food_supergroup.iloc[0]}
    for (c, y), rl in zip(ROUNDS, RLAB):
        x = gdf[(gdf.country == c) & (gdf["round"] == y)]
        row[rl] = "; ".join(f"{d} ({int(k)})" for d, k in zip(x.slot, x.code)) if len(x) else None
    row["comparability"] = ", ".join(sorted(set(gdf.item_comparability)))
    CB.append(row)
GORD = ["meat", "poultry", "other_animal", "eggs", "dairy", "fats_mixed", "fish_seafood", "meat_fish_mixed", "pulses", "pulses_fresh", "soy", "groundnuts", "nuts",
        "seeds", "pulses_nuts_seeds_other", "other_plant", "prepared_food"]
CB = pd.DataFrame(CB).sort_values("food_group", key=lambda s: s.map(GORD.index))
CC = pd.DataFrame([{"": "consumption recall", **{rl: "7 days" for rl in RLAB}},
                   {"": "purchases", **{rl: ("last 30 days, most recent purchase" if (c, y) in SVY else "7 days (purchased quantity and amount)" if c == "NGA" else "7 days (consumption out of purchases and amount)") for (c, y), rl in zip(ROUNDS, RLAB)}},
                   {"": "items listed", **{rl: ("only consumed items" if (c, y) in ONLY_CONSUMED else "all items, yes/no") for (c, y), rl in zip(ROUNDS, RLAB)}},
                   {"": "welfare variable", **{rl: H[(H.country == c) & (H.year == y)].welfare_formula.dropna().iloc[0] if H[(H.country == c) & (H.year == y)].welfare_formula.notna().any() else None for (c, y), rl in zip(ROUNDS, RLAB)}},
                   {"": "adult equivalents", **{rl: ("official" if H[(H.country == c) & (H.year == y)].adulteq.notna().any() else "not in the files") for (c, y), rl in zip(ROUNDS, RLAB)}},
                   {"": "households", **{rl: int(((H.country == c) & (H.year == y)).sum()) for (c, y), rl in zip(ROUNDS, RLAB)}}])
# item mapping table
MP = IM[["country", "year", "code", "label", "slot", "item", "item_label", "food_group", "food_supergroup", "item_comparability", "note"]].rename(
    columns={"code": "item_code_orig", "label": "item_label_orig", "slot": "item_detail", "note": "mapping_note"})
MP["item_comparability"] = np.where(((MP.country == "ETH") & MP.item_detail.isin(["eth_pea_code8", "eth_pea_code9"])) |
                                    ((MP.country == "UGA") & (MP.year <= 2015) & (MP.item_detail == "groundnuts_shelled")), "uncertain", MP.item_comparability)
MP["round_file"] = np.where(MP.year == 2020.1, "hh_sec_j1 sample", "")
MP["year"] = MP.year.apply(lambda y: int(math.floor(y)))
MP = MP.merge(CO[["country", "slot", "protein_g_per_100g", "edible_portion", "quality", "source"]].rename(columns={"country": "cc", "slot": "item_detail", "quality": "protein_coef_quality",
              "source": "protein_coef_source"}), on="item_detail", how="left")
MP = MP[(MP.cc == MP.country) | ((MP.cc == "*") & ~MP.set_index(["country", "item_detail"]).index.isin([tuple(x) for x in CO[CO.country != "*"][["country", "slot"]].values]))].drop(columns="cc")
MP = MP.sort_values(["country", "year", "food_group", "item_detail"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else (s.map(GORD.index) if s.name == "food_group" else s))
ICLS = CL.reset_index().merge(MAP.groupby("slot").apply(lambda d: "; ".join(f"{c} {', '.join(str(int(math.floor(y))) for y in sorted(set(g.year)))}" for c, g in d.groupby("country")),
                                                         include_groups=False).rename("asked in"), left_on="item_detail", right_index=True)
ICLS = ICLS[["food_supergroup", "food_group", "item", "item_label", "item_detail", "item_comparability", "note", "asked in"]].sort_values(
    ["food_group", "item", "item_detail"], key=lambda s: s.map(GORD.index) if s.name == "food_group" else s)

# data dictionary
LDOC = [
 ("hh_uid", "Unique household key", "text", "country_year_hhid", ""), ("country", "ISO3 country code", "text", "", ""), ("year", "First year of fieldwork", "year", "", ""),
 ("survey_round", "Country and round", "text", "country_year", ""), ("hhid", "Household id of the round", "text", "as in the food module", "leading zeros kept"),
 ("weight", "Household sampling weight", "weight", "copied from the household dataset", ""), ("hhsize", "Household size", "persons", "copied from the household dataset", ""),
 ("adulteq", "Adult equivalents", "adult equivalents", "copied from the household dataset", "empty for Malawi 2010/2024 and Nigeria (not in the files)"),
 ("welfare_annual", "Annual consumption per adult equivalent or per person", "local currency per year", "copied from the household dataset", "see welfare_formula"),
 ("welfare_quintile", "Welfare quintile within country and round (population-weighted)", "1-5", "copied from the household dataset", ""),
 ("rural", "1 rural, 0 urban", "0/1", "copied from the household dataset", ""),
 ("item_code_orig", "Item code of the questionnaire", "code", "as in the food module", "codes are round-specific: see Item_Mapping"),
 ("item_detail", "Most detailed harmonized item (one per original item)", "text", "item_map.csv", ""),
 ("item", "Harmonized food item (details of the same product grouped)", "text", "item_classification.csv", "sum the rows of an item to compare across surveys"),
 ("food_group", "Food group", "text", "item_classification.csv", ""), ("food_supergroup", "animal_source, plant, mixed", "text", "item_classification.csv", ""),
 ("item_comparability", "direct, subtype, combined, residual, uncertain", "text", "item_classification.csv; Item_Mapping", "combined and residual items are not comparable with single products"),
 ("consumption_status", "consumed; not_consumed; not_listed (rounds listing only consumed items: counted as not consumed); no_record (no row in the file); not_answered", "text", "answer and presence of the row", ""),
] + [(v, DEFN[v][0], DEFN[v][1], DEFN[v][2], DEFN[v][3]) for v in QVARS] + [
 ("qty_total_orig", "Quantity consumed in total, as recorded", "unit of unit_total_orig", "original variable", "Uganda 2018-19: no total question (sum of sources)"),
 ("unit_total_orig", "Unit code of the total quantity, as recorded", "code (text)", "original variable", "labels in unit_total_label"),
 ("unit_total_label", "Label of the unit code", "text", "value labels of the file", "Malawi 2010: the unit variable has no value labels in the file (codes as in the IHS questionnaire), so empty"),
 ("qty_status", "converted; not_convertible; no_quantity; not_consumed; not_answered", "text", "", ""),
 ("conv_method", "How qty_total_kg was obtained", "text", "", "Unit_Conversion rules in Data_Dictionary B"),
 ("protein_g", "Grams of protein in qty_total_kg", "grams per week", "qty_total_kg x protein g/100 g x 10 x edible portion (protein_coefficients.csv)", "not computed for prepared food, butter-margarine, coconut, kola; see protein_coef_quality"),
 ("protein_coef_quality", "A table match, B proxy, C approximate, X not computed", "text", "protein_coefficients.csv", ""),
 ("flag_outlier", "1 if implied price, quantity or spending is implausible (Step I thresholds M17/M18)", "0/1", "consumed items only", "values kept"),
 ("flag_inconsistent", "1 if the answer and the quantities disagree ('no' with quantity, 'yes' without, bought without amount)", "0/1", "consumed items only", "values kept"),
 ("not_collected", "Harmonized variables not asked in this round (their empty cells mean 'not collected')", "text", "", ""),
 ("currency", "Currency of the monetary variables", "text", "", "")]
HDOC = {
 "hh_uid": ("Unique household key", "text", "country_year_hhid"), "country": ("ISO3 country code", "text", ""), "year": ("First year of fieldwork", "year", ""),
 "survey_round": ("Country and round", "text", ""), "hhid": ("Household id of the round", "text", "food module"),
 "panel_id": ("Same household across rounds", "text", "Step I panel_ids(); Nigeria 2018-2023: hhid"), "food_module_file": ("Food module file", "text", "Tanzania 2020: two samples"),
 "in_household_files": ("1 if found in the cover or aggregate files", "0/1", ""), "weight": ("Household sampling weight", "weight", "see weight_var"),
 "weight_var": ("Original weight variable", "text", ""), "region": ("Region code", "code", "ETH saq01, TZA region, MWI region, NGA zone, UGA region"),
 "district": ("District code", "code", "ETH zone saq02, TZA district, MWI district, NGA state, UGA district"), "subdistrict": ("Sub-district", "code", "ETH woreda, NGA lga, UGA subcounty"),
 "ea": ("Enumeration area / cluster", "code", "EA id"), "strata": ("Sampling stratum", "code", ""),
 "rural": ("1 rural, 0 urban", "0/1", "from urban_rural_code and the value labels of each file"), "urban_rural_code": ("Original urban/rural code", "code", "ETH rural/saq14, TZA urban, MWI reside, NGA rururb/sector, UGA urban"),
 "refugee_camp": ("Malawi 2024 refugee camp sample", "0/1", "camp"), "int_month": ("Month of interview", "month", "TZA intmonth, MWI smonth, UGA month"), "int_year": ("Year of interview", "year", ""),
 "hhsize": ("Household size", "persons", "aggregate/cover; Malawi 2010 and Uganda 2011: roster count (hhsize_source)"), "hhsize_source": ("Source of hhsize", "text", ""),
 "adulteq": ("Adult equivalents of the official aggregate", "adult equivalents", "adulteq, equiv"), "adulteq_source": ("Source of adulteq", "text", ""),
 "head_female": ("1 female head", "0/1", "roster (Step I); Nigeria not available"), "head_age": ("Age of the head", "years", "roster (Step I)"),
 "share_child": ("Share of members under 15", "share", "roster (Step I)"), "share_elderly": ("Share of members 60+", "share", "roster (Step I)"),
 "welfare_annual": ("Annual consumption per adult equivalent (ETH, TZA, UGA) or per person (MWI, NGA)", "local currency per year", "see welfare_formula: identical to the Step I welfare"),
 "welfare_formula": ("How welfare_annual is obtained from the official aggregate", "text", ""), "welfare_scale": ("per adult equivalent or per person", "text", ""),
 "welfare_prices": ("Price basis of welfare_annual", "text", ""), "welfare_official": ("The official per-person welfare variable of the file, unchanged", "as in the file", "see welfare_official_var"),
 "welfare_official_var": ("Name of the official welfare variable (none: computed from the household total)", "text", ""),
 "welfare_quintile": ("Quintile of welfare_annual within country and round, population-weighted (weight x hhsize)", "1-5", "Step I used unweighted household quintiles"),
 "welfare_quintile_official": ("Quintile in the file", "1-5", "ETH cons_quint, UGA quints"),
 "cons_total_hh_annual": ("Total household consumption, annual", "local currency per year", "see cons_total_hh_var"), "cons_total_hh_var": ("Original variable", "text", ""),
 "food_cons_hh_annual": ("Household food consumption, annual", "local currency per year", "see food_cons_hh_var; Nigeria and Tanzania 2020 not available as one variable"),
 "food_cons_hh_var": ("Original variable", "text", ""), "currency": ("Currency", "text", ""), "gdp_pc_ppp_const2021": ("GDP per capita PPP of the country-year", "constant 2021 int. $", "WDI"),
 "welfare_step1": ("Welfare of the Step I panels (check)", "local currency per year", "equal to welfare_annual"),
}
DD = pd.DataFrame([dict(dataset="food_items_long", variable=v, definition=d, unit=u, harmonization=h, limitations=l,
                        original_variables_by_round="; ".join(f"{rl}: {orig(v, c, y)}" for (c, y), rl in zip(ROUNDS, RLAB)) if v in QVARS else "") for v, d, u, h, l in LDOC]
                  + [dict(dataset="households", variable=v, definition=d, unit=u, harmonization=h, limitations="",
                          original_variables_by_round="; ".join(f"{c} {int(y)}: {x}" for c, y, x in HS[HS.column == v][["country", "year", "variable"]].itertuples(index=False)))
                     for v, (d, u, h) in HDOC.items()])
assert set(LCOLS) <= set(DD.variable), set(LCOLS) - set(DD.variable)
assert set(HCOLS) <= set(DD.variable), set(HCOLS) - set(DD.variable)
UCONV = pd.DataFrame([("ETH", "local units: national mean kg per unit of Food_CF_Wave1-5 for the item and unit; metric units"),
                      ("TZA", "metric codes 1-5; 2020: the survey's weight estimate of local units (hh_ja02b) when the item has no piece factor; eggs and coconuts recorded in kg or g. "
                       "Eggs counted in pieces stay at 55 g even when the household also gave a weight, so sources reported in grams can differ slightly from the total"),
                      ("MWI", "metric units, 'other (specify)' text, official 2020 factor table (not for red meat, fish, other poultry: implied prices contradict it, Step I)"),
                      ("NGA", "2012, 2015: survey conversion tables; 2010: metric labels only; 2018, 2023: quantity x the kg/l factor given in the file (q2_cvn)"),
                      ("UGA", "kg or litres stated in the unit label (tins, sacks, baskets, packets; cups of 0.5 l for liquids); chicken 1.3 kg per bird"),
                      ("all", "milk and liquid dairy: 1.03 kg per litre; eggs counted in pieces: 55 g per egg (Tanzania 2020 calibration; Nigeria's own factor is 45 g)")],
                     columns=["country", "conversion to kg"])
COVG = CONV.assign(ok=np.where(CONV.qty_status == "converted", CONV.n, 0)).groupby(["country", "year", "food_group"])[["ok", "n"]].sum()
COVG = (100 * COVG.ok / COVG.n).round(1).unstack("food_group")
COVG = COVG.reindex(columns=[g for g in GORD if g in COVG.columns]).reset_index().sort_values(["country", "year"], key=ckey)
METH = CONV.groupby(["country", "year", "conv_method"]).n.sum().unstack("conv_method").fillna(0).astype(int).reset_index().sort_values(["country", "year"], key=ckey)
# checks
raw = RV[RV.role.isin(["q_tot", "exp_pur"])].groupby(["country", "year", "role"]).agg(non_missing=("non_missing", "sum"), total=("sum", "sum")).reset_index()
ds = QORIG[["country", "year", "q_nm", "q_sum"]]
chk = raw[raw.role == "q_tot"].merge(ds, on=["country", "year"], how="right")
chk["difference"] = chk.non_missing - chk.q_nm
chk["note"] = np.select([chk.role.isna(), chk.difference.fillna(0) != 0],
                        ["no question on the total in this round: qty_total_orig empty, qty_total_kg = sum of the sources",
                         "the file stores quantities as text; cells with the letter 'a' (missing code) stay empty"], "equal")
chk = chk.drop(columns="role")
CHKQ = chk.rename(columns={"non_missing": "raw_nonmissing_q_tot", "total": "raw_sum_q_tot", "q_nm": "dataset_nonmissing_qty_total_orig", "q_sum": "dataset_sum_qty_total_orig"})
SUMM = pd.DataFrame([
    ("rows of food_items_long", int(QORIG.rows.sum()), "households x items asked in their round"),
    ("duplicated household x round x item_detail", 0, "checked while writing (assertion)"),
    ("households", len(H), "food module households of 25 rounds"),
    ("duplicated households", int(H.duplicated(KEY).sum()), ""),
    ("welfare_annual equal to Step I welfare", int(((H.welfare_annual - H.welfare_step1).abs() < 1e-6 * H.welfare_step1.abs().clip(lower=1)).sum()), f"of {int(H.welfare_step1.notna().sum())} households with Step I welfare"),
    ("consumed items with qty_total_kg", int(CONV[CONV.qty_status == "converted"].n.sum()), f"of {int(QORIG.consumed.sum())} consumed items"),
    ("empty cells set to zero", 0, "zeros only for not consumed or source with quantity 0"),
], columns=["check", "value", "note"])

XL = os.path.join(OUTD, f"food_dataset_documentation_{TODAY}.xlsx")
wb = xlsxwriter.Workbook(XL, {"constant_memory": True, "nan_inf_to_errors": False})
H1 = wb.add_format({"bold": True, "bg_color": "#DCE6F1", "border": 1, "text_wrap": True, "valign": "top"})
TT = wb.add_format({"bold": True, "font_size": 13}); NT = wb.add_format({"italic": True, "font_color": "#555555"})
def sheet(name, blocks, widths=(), notes=()):
    ws = wb.add_worksheet(name); r = 0
    for t in notes:
        ws.write_string(r, 0, t, NT); r += 1
    if notes: r += 1
    for title, df in blocks:
        if title:
            ws.write_string(r, 0, title, TT); r += 1
        for j, c in enumerate(df.columns): ws.write_string(r, j, str(c), H1)
        r += 1
        for row in df.itertuples(index=False):
            for j, v in enumerate(row):
                if v is None or (isinstance(v, float) and np.isnan(v)): continue
                if isinstance(v, (bool, np.bool_)): ws.write_string(r, j, "yes" if v else "no")
                elif isinstance(v, (int, float, np.integer, np.floating)): ws.write_number(r, j, float(v))
                else: ws.write_string(r, j, str(v)[:32000])
            r += 1
        r += 1
    for a, b, w in widths: ws.set_column(a, b, w)
    return ws
README = pd.DataFrame([
    ("food_items_long_<date>.csv.gz", f"{int(QORIG.rows.sum()):,} rows x {len(LCOLS)} columns", "one row per household x round x original food item (protein-rich foods of the questionnaires)"),
    ("households_<date>.csv.gz", f"{len(H):,} rows x {len(HCOLS)} columns", "one row per household x round; also in the sheet Households"),
    ("this workbook", "", "Households, Item_Classification, Item_Mapping, Data_Dictionary, Comparability_Matrix, Quality_Control"),
    ("join", "", "food_items_long and households share country, year, hhid (and hh_uid)"),
    ("rules", "", "0 = not consumed / not from that source; empty = missing; not_collected lists what the round does not ask; combined categories are never split"),
    ("R", "", "read.csv(gzfile('food_items_long_<date>.csv.gz'), colClasses = c(hhid = 'character', unit_total_orig = 'character'))"),
], columns=["file", "size", "content"])
sheet("README", [(None, README)], [(0, 0, 32), (1, 1, 26), (2, 2, 120)])
ws = sheet("Households", [(None, H)], [(0, 0, 22), (1, len(HCOLS), 13)]); ws.freeze_panes(1, 1)
sheet("Item_Classification", [(None, ICLS)], [(0, 1, 16), (2, 4, 30), (5, 5, 14), (6, 7, 50)],
      ["item_detail = one original item; item = the harmonized product (sum its details to compare across surveys); food_group and food_supergroup for broader groups.",
       "item_comparability: direct = the same product everywhere; subtype = a country-specific split of the item; combined = one original category for several products (not split, not comparable with single products); residual = 'other'."])
sheet("Item_Mapping", [(None, MP)], [(0, 2, 8), (3, 3, 45), (4, 6, 24), (10, 10, 50)],
      ["Every original item code of every round and its harmonized item. Codes change meaning between rounds: always map by country, year and code."])
sheet("Data_Dictionary", [("A. Variables", DD), ("B. Conversion of quantities to kilograms", UCONV)], [(0, 1, 22), (2, 2, 60), (3, 3, 18), (4, 5, 60), (6, 6, 120)])
sheet("Comparability_Matrix", [("A. Harmonized consumption variables: original variables by round", CA), ("B. Harmonized items by round: item details (original code)", CB),
                               ("C. Rounds", CC)], [(0, 0, 26), (1, 1, 40), (2, 30, 22)],
      ["'not collected' = the round does not ask it: the cells are empty for every household of the round."])
sheet("Quality_Control", [("A. Summary", SUMM), ("B. Status of the item rows by round and food group", STAT),
                          ("C. Consumed items with quantity in kg, % by round and food group", COVG), ("D. How quantities were converted (consumed items)", METH),
                          ("E. Sources against the total (consumed items with kg)", QSRC), ("F. Original quantities against the raw files", CHKQ)],
      [(0, 0, 34), (1, 20, 13)])
wb.close()
print(f"written {XL} ({os.path.getsize(XL) / 1e6:.1f} MB) ({time.time() - T0:.0f}s)")
print(SUMM.to_string()); print(CHKQ.to_string())
