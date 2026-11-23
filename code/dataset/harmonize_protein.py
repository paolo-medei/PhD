#!/usr/bin/env python3
"""
HARMONIZED PROTEIN DATASET, one row per household and round (v1, 23 Nov 2026)

From the household x item tables of build_protein_dataset.R (original answers and quantities converted
with the surveys' own conversion tables or metric units) this script
  1. classifies every protein-rich item into three categories: animal (meat, eggs, dairy; no fish),
     fish (fish and seafood), plant (pulses, soy, groundnuts, nuts, seeds);
  2. converts every quantity to kilograms (litres of milk at 1.03 kg/l, eggs counted in pieces at 55 g);
  3. turns kilograms into grams of protein with documented coefficients (protein_coefficients.csv);
  4. sums by household, category and source (market, own production, gifts), per week and per adult
     equivalent per day, with strict rules: a total is missing if any consumed item of it cannot be
     converted, or if the category is not asked in the round; a lower bound over the converted items is
     given separately, with the number of items left out.
Missing values are never set to zero; zeros come only from items the household did not consume.

USE  python3 harmonize_protein.py <build dir> <item_map.csv> <protein_coefficients.csv> <hh_info.csv>
                                  <wdi_gdp_pc_ppp.csv> <out dir>
"""
import datetime, math, os, sys, time
import numpy as np
import pandas as pd

BUILD, MAPF, COEFF, HHINFO, GDPF, OUTD = sys.argv[1:7]
os.makedirs(OUTD, exist_ok=True)
TODAY = datetime.date.today().isoformat()
T0 = time.time()
COUNTRIES = ["ETH", "TZA", "MWI", "NGA", "UGA"]
CATS = ["animal", "fish", "plant"]
ckey = lambda s: s.map(COUNTRIES.index) if s.name == "country" else s

EGG_KG = 0.055            # one egg, gross weight (Tanzania 2020 survey calibration; Step I TRAP 6)
MILK_DENSITY = 1.03       # kg per litre of milk and liquid milk products
NGA_SURVEY_FACTOR = {("NGA", 2018), ("NGA", 2023)}       # quantities x the survey's own kg/l factor (q2_cvn)
NGA_PURCHASE_30D = NGA_SURVEY_FACTOR                     # purchase spending not on a 7-day recall

# ------------------------------------------------------------------------------------------
# 1. items, categories, coefficients
# ------------------------------------------------------------------------------------------
MAP = pd.read_csv(MAPF)
MAP["round"] = MAP["year"].apply(lambda y: int(math.floor(y)))
C = pd.read_csv(COEFF)
C["g_per_kg"] = C.protein_g_per_100g * 10 * C.edible_portion
CAT3 = C.drop_duplicates("slot").set_index("slot")["category"].to_dict()
def coef_row(cc, slot):
    x = C[(C.slot == slot) & (C.country == cc)]
    return (x if len(x) else C[(C.slot == slot) & (C.country == "*")]).iloc[0]
COEF = {(cc, s): coef_row(cc, s) for cc, s in MAP[["country", "slot"]].drop_duplicates().itertuples(index=False)}
STD = MAP.drop_duplicates(["country", "slot"]).set_index(["country", "slot"])["std"].to_dict()
DAIRY = set(MAP.loc[MAP.cat == "dairy", "slot"])
TZA_LITRE_CODES = {"3", "4", "3.0", "4.0"}                # Tanzania unit codes: 3 litre, 4 millilitre

def kg_factor(cc, slot):
    std = STD[(cc, slot)]
    return 1.0 if std == "kg" else (MILK_DENSITY if slot in DAIRY else 1.0) if std == "litre" else EGG_KG if std == "piece" else np.nan

# ------------------------------------------------------------------------------------------
# 2. household x item: kilograms and protein, total and by source
# ------------------------------------------------------------------------------------------
USE = ["hhid", "year", "slot", "code", "cons", "cons_raw", "u_tot", "q_tot", "q_pur", "q_away", "q_own", "q_gift", "q_frompur", "cvn_tot",
       "q_wt", "u_wt", "s_tot", "s_pur", "s_own", "s_gift", "s_away", "s_frompur", "exp", "flag"]
UC = pd.read_csv(os.path.join(BUILD, "unit_codes.csv"), dtype=str, keep_default_na=False, na_values=[""])
UC["year"] = UC.year.astype(int)
def label_kg(lab):
    """kilograms stated in a Uganda unit label: 'Sack (50 kgs)', 'Kimbo Tin (0.5kg)', 'Basket (5 kg)'; not ranges ('up to 1kg', '1 to 2 kg')"""
    import re
    if not isinstance(lab, str) or re.search(r"(?i)up to|to \d|above|-\s*\d|lt", lab):
        return np.nan
    m = re.search(r"\((\d+(?:\.\d+)?)\s?kgs?\)", lab, re.I)
    return float(m.group(1)) if m else np.nan
UGA_KG = {(int(y), str(c).replace(".0", "")): label_kg(l) for y, c, l in UC[UC.country == "UGA"][["year", "code", "label"]].itertuples(index=False)}
TZA_WT = {"1": 1.0, "2": 0.001, "3": 1.0, "4": 0.001, "1.0": 1.0, "2.0": 0.001, "3.0": 1.0, "4.0": 0.001}
ITEMS = []
for cc in COUNTRIES:
    L = pd.read_csv(os.path.join(BUILD, f"long_{cc}.csv.gz"), usecols=lambda c: c in USE, dtype={"hhid": str, "u_tot": str, "u_wt": str, "slot": str},
                    low_memory=False, keep_default_na=False, na_values=[""])
    for c in USE:
        if c not in L.columns:
            L[c] = np.nan
    L["year"] = L["year"].astype(float).astype(int); L["country"] = cc
    L["category"] = L.slot.map(CAT3)
    L = L[L.category != "excluded"].copy()
    co = pd.DataFrame([COEF[(cc, s)] for s in L.slot], index=L.index)
    L["g_per_kg"] = co.g_per_kg.to_numpy(); L["coef_quality"] = co.quality.to_numpy()
    tz = (L.slot == "milk_canned_powder") & L.u_tot.isin(TZA_LITRE_CODES)            # by volume: evaporated milk
    L.loc[tz, "g_per_kg"] = 6.81 * 10
    f = np.array([kg_factor(cc, s) for s in L.slot])
    svy = np.array([(cc, y) in NGA_SURVEY_FACTOR for y in L.year])
    kg = lambda s, q: np.where(svy, L[q] * L.cvn_tot, L[s] * f)
    L["kg_tot"] = kg("s_tot", "q_tot")
    if cc == "UGA":
        L["kg_market"] = (L.s_pur + L.s_away) * f
    elif cc == "NGA":
        L["kg_market"] = np.where(svy, L.q_frompur * L.cvn_tot, np.where(L.year == 2010, L.s_pur, L.s_frompur) * f)
    else:
        L["kg_market"] = L.s_pur * f
    L["kg_own"] = kg("s_own", "q_own"); L["kg_gift"] = kg("s_gift", "q_gift")
    # a source with quantity 0 has no unit in the file: its kilograms are 0, not missing
    mq = np.where(svy | ((cc == "NGA") & (L.year.isin([2012, 2015]))), L.q_frompur, L.q_pur)
    L.loc[(pd.Series(mq, index=L.index) == 0) & L.kg_market.isna(), "kg_market"] = 0.0
    L.loc[(L.q_own == 0) & L.kg_own.isna(), "kg_own"] = 0.0
    L.loc[(L.q_gift == 0) & L.kg_gift.isna(), "kg_gift"] = 0.0
    L["conv_method"] = np.where(svy, "survey kg/l factor of the file (q2_cvn)", "survey table or metric unit (build)")
    L.loc[L.kg_tot.isna() & (L.cons == 1), "conv_method"] = "not converted"
    if cc == "TZA":      # 2020: the survey's own weight estimate of quantities in local units (hh_ja02b)
        w = L.u_wt.map(TZA_WT)
        fill = L.kg_tot.isna() & (L.cons == 1) & L.q_wt.notna() & w.notna() & (L.year == 2020)
        L.loc[fill, "kg_tot"] = L.q_wt[fill] * w[fill]; L.loc[fill, "conv_method"] = "survey weight estimate (hh_ja02b)"
    if cc == "UGA":      # units whose label states kilograms (sacks, tins, baskets, packets)
        k = pd.Series([UGA_KG.get((y, str(u).replace(".0", "")), np.nan) for y, u in zip(L.year, L.u_tot)], index=L.index)
        fill = L.kg_tot.isna() & (L.cons == 1) & k.notna() & (np.array([STD[(cc, s_)] for s_ in L.slot]) == "kg")
        qs = L[["q_pur", "q_away", "q_own", "q_gift"]]
        L.loc[fill, "kg_tot"] = qs[fill].sum(axis=1, min_count=1) * k[fill]
        L.loc[fill, "kg_market"] = (qs.q_pur.fillna(0) + qs.q_away.fillna(0))[fill] * k[fill]
        L.loc[fill, "kg_own"] = qs.q_own.fillna(0)[fill] * k[fill]; L.loc[fill, "kg_gift"] = qs.q_gift.fillna(0)[fill] * k[fill]
        L.loc[fill, "conv_method"] = "kilograms stated in the unit label"
    L.loc[L.cons != 1, "conv_method"] = None
    L.loc[(L.cons == 1) & (np.array([STD[(cc, s_)] for s_ in L.slot]) == "piece") & L.kg_tot.notna(), "conv_method"] = "eggs: pieces at 55 g"
    for k in ["kg_tot", "kg_market", "kg_own", "kg_gift"]:
        L.loc[L.cons == 0, k] = 0.0                                          # not consumed: zero, as in the build
    for k in ["tot", "market", "own", "gift"]:
        L[f"prot_{k}"] = L[f"kg_{k}"] * L.g_per_kg
        L.loc[L.cons == 0, f"prot_{k}"] = 0.0
    L["exp7"] = np.where([(cc, y) in NGA_PURCHASE_30D for y in L.year], np.nan, L.exp)
    L["outlier"] = (L.flag.fillna(0).astype(int) & 7) > 0
    ITEMS.append(L[["country", "year", "hhid", "slot", "code", "category", "cons", "cons_raw", "conv_method", "kg_tot", "kg_market", "kg_own", "kg_gift",
                    "g_per_kg", "coef_quality", "prot_tot", "prot_market", "prot_own", "prot_gift", "exp7", "outlier"]])
    print(f"  {cc}: {len(L)} item rows ({time.time() - T0:.0f}s)", flush=True)
IT = pd.concat(ITEMS, ignore_index=True)
del ITEMS

# ------------------------------------------------------------------------------------------
# 3. household totals by category (strict) and lower bounds
# ------------------------------------------------------------------------------------------
c1 = IT.cons == 1
IT["_asked"] = 1
IT["_cna"] = IT.cons.isna().astype(int)
IT["_c1"] = c1.astype(int)
IT["_unconv"] = (c1 & IT.prot_tot.isna()).astype(int)
IT["_kgna"] = (c1 & IT.kg_tot.isna()).astype(int)
for k in ["market", "own", "gift"]:
    IT[f"_{k}na"] = (c1 & IT[f"prot_{k}"].isna()).astype(int)
IT["_expna"] = (IT.exp7.isna()).astype(int)
IT["_approx"] = (c1 & IT.coef_quality.eq("C")).astype(int)
IT["_out"] = (c1 & IT.outlier).astype(int)
KEY = ["country", "year", "hhid"]
agg = {"_asked": "sum", "_cna": "sum", "_c1": "sum", "_unconv": "sum", "_kgna": "sum", "_marketna": "sum", "_ownna": "sum", "_giftna": "sum",
       "_expna": "sum", "_approx": "sum", "_out": "sum", "prot_tot": "sum", "kg_tot": "sum", "prot_market": "sum", "prot_own": "sum",
       "prot_gift": "sum", "exp7": "sum"}
G = IT.groupby(KEY + ["category"]).agg(agg)
HH = pd.read_csv(os.path.join(BUILD, "module_households.csv"), dtype={"hhid": str, "module": str}, keep_default_na=False, na_values=[""])
HH["year"] = HH.year.astype(int)
HH = HH[["country", "year", "hhid", "module"]].sort_values(KEY, key=ckey).reset_index(drop=True)
idx = pd.MultiIndex.from_frame(HH[KEY])
T = pd.DataFrame(index=idx)
for c in CATS + ["unsplit"]:
    g = G.xs(c, level="category").reindex(idx) if c in G.index.get_level_values("category") else pd.DataFrame(index=idx, columns=list(agg), dtype=float)
    asked = g["_asked"].fillna(0)
    nan_any = (g["_cna"] > 0) | (g["_unconv"] > 0)
    T[f"n_items_asked_{c}"] = asked
    T[f"consumed_{c}"] = np.where(asked == 0, np.nan, np.where(g["_c1"] > 0, 1.0, np.where(g["_cna"] > 0, np.nan, 0.0)))
    T[f"prot_{c}_g_wk"] = np.where((asked == 0) | nan_any, np.nan, g["prot_tot"])
    T[f"prot_{c}_g_wk_lb"] = np.where(asked == 0, np.nan, g["prot_tot"])
    T[f"n_items_unconverted_{c}"] = np.where(asked == 0, np.nan, g["_unconv"] + g["_cna"])
    T[f"kg_{c}_wk"] = np.where((asked == 0) | (g["_cna"] > 0) | (g["_kgna"] > 0), np.nan, g["kg_tot"])
    for k in ["market", "own", "gift"]:
        T[f"prot_{c}_{k}_g_wk"] = np.where((asked == 0) | (g["_cna"] > 0) | (g[f"_{k}na"] > 0), np.nan, g[f"prot_{k}"])
    T[f"exp_{c}_wk"] = np.where((asked == 0) | (g["_expna"] > 0), np.nan, g["exp7"])
    T[f"n_items_approx_coef_{c}"] = np.where(asked == 0, np.nan, g["_approx"])
    T[f"n_items_outlier_{c}"] = np.where(asked == 0, np.nan, g["_out"])
T = T.reset_index()
# unsplit (Malawi tinned meat or fish, "other" of the meat-fish group): exists only in Malawi; elsewhere these
# foods are asked inside meat or fish, so the absence of the item is not a missing value
uns = T["n_items_asked_unsplit"] > 0
T["prot_asf_g_wk"] = T.prot_animal_g_wk + T.prot_fish_g_wk + np.where(uns, T.prot_unsplit_g_wk, 0.0)
T["prot_asf_g_wk_lb"] = T.prot_animal_g_wk_lb + T.prot_fish_g_wk_lb.fillna(np.nan) + np.where(uns, T.prot_unsplit_g_wk_lb, 0.0)
T["prot_total_g_wk"] = T.prot_asf_g_wk + T.prot_plant_g_wk
T["prot_total_g_wk_lb"] = T.prot_asf_g_wk_lb + T.prot_plant_g_wk_lb

# ------------------------------------------------------------------------------------------
# 4. household variables
# ------------------------------------------------------------------------------------------
HI = pd.read_csv(HHINFO, dtype={"hhid": str, "panel_id": str, "region": str, "cluster": str, "strata": str, "urban_code": str}, low_memory=False)
HI["year"] = HI.year.astype(int)
HR = pd.read_csv(os.path.join(BUILD, "hh_raw.csv"), dtype=str, keep_default_na=False, na_values=[""])
HR["year"] = HR.year.astype(int)
# Nigeria 2018 and 2023 are not in Step I: the same variables, from the files, with the Step I rules
n = HR[(HR.country == "NGA") & HR.year.isin([2018, 2023])].copy()
num = lambda s: pd.to_numeric(s, errors="coerce")
NG = pd.DataFrame({"country": "NGA", "year": n.year, "hhid": n.hhid, "weight": num(n.weight), "hhsize": num(n.hhsize), "adulteq": num(n.hhsize),
                   "welfare": np.where(n.year == 2018, num(n.agg_totcons_pc), num(n.agg_totcons_adj)), "region": n.region,
                   "state": n.district, "lga": n.subdistrict, "cluster": n.district + "_" + n.subdistrict + "_" + n.ea, "strata": n.strata,
                   "urban_code": n.urban_rural, "rural": np.where(n.urban_rural.isna(), np.nan, (n.urban_rural == "2").astype(float)),
                   "panel_id": n.hhid})
HI = pd.concat([HI, NG], ignore_index=True)
D = HH.merge(HI, on=KEY, how="left", indicator=True)
D["in_household_files"] = (D._merge == "both").astype(int); D = D.drop(columns="_merge")
D = D.merge(HR[KEY + ["int_month", "int_year"]], on=KEY, how="left")
GDP = pd.read_csv(GDPF); D = D.merge(GDP, on=["country", "year"], how="left")
D["welfare_quintile"] = D.groupby(["country", "year"]).welfare.transform(lambda s: pd.qcut(s.rank(method="first"), 5, labels=False) + 1 if s.notna().sum() >= 5 else np.nan)
WDEF = {"ETH": "nominal annual consumption per adult equivalent (nom_totcons_aeq)",
        "TZA": "real annual consumption per adult equivalent (expmR / adulteq; 2020: expmR_pae x 365/28)",
        "MWI": "real annual consumption per person (rexpagg / hhsize)",
        "NGA": "annual consumption per person (2010-2015 totcons; 2018 totcons_pc; 2023 totcons_adj, spatially adjusted, 2023 prices)",
        "UGA": "monthly consumption per adult equivalent x 12 (welfare, 2005/06 or 2009/10 prices)"}
D["welfare_definition"] = D.country.map(WDEF)
D["adulteq_type"] = np.where(D.country.isin(["MWI", "NGA"]), "household size (no scale in the aggregate)", "official adult-equivalent scale")
D["currency"] = D.country.map({"ETH": "ETB", "TZA": "TZS", "MWI": "MWK", "NGA": "NGN", "UGA": "UGX"})
D["survey_round"] = D.country + "_" + D.year.astype(str)
D["hh_uid"] = D.survey_round + "_" + D.hhid
D["food_module_file"] = D["module"]
D = D.merge(T, on=KEY, how="left")
for c in CATS + ["asf", "total"]:
    D[f"prot_{c}_g_day_ae"] = D[f"prot_{c}_g_wk"] / 7 / D.adulteq
    D[f"prot_{c}_g_day_ae_lb"] = D[f"prot_{c}_g_wk_lb"] / 7 / D.adulteq

# round-level comparability
ROUND_ISSUES = {
    ("ETH", 2011): "one item for all meat (no split, fish possibly inside); no fish item; 11 items", ("ETH", 2013): "one item for all meat (no split, fish possibly inside); no fish item; 11 items",
    ("ETH", 2015): "fish: one item, form not asked", ("ETH", 2018): "fish: one item, form not asked; 2,783 item rows missing in the file",
    ("ETH", 2021): "fish: one item, form not asked",
    ("TZA", 2020): "two samples with different item lists (hh_sec_ja1, hh_sec_j1)",
    ("MWI", 2010): "red meat, fish and other poultry in pieces or heaps not converted (official table not used, as in Step I)",
    ("MWI", 2016): "red meat, fish and other poultry in pieces or heaps not converted", ("MWI", 2019): "red meat, fish and other poultry in pieces or heaps not converted",
    ("MWI", 2024): "red meat, fish and other poultry in pieces or heaps not converted; refugee camp sample without welfare",
    ("NGA", 2010): "no survey conversion table: only metric units converted; only consumed items listed",
    ("NGA", 2018): "quantities converted with the file's own factors; purchase spending on a 30-day recall (not used)",
    ("NGA", 2023): "quantities converted with the file's own factors; purchase spending on a 30-day recall (not used); welfare spatially adjusted",
    ("UGA", 2010): "only consumed items listed; fish in heaps mostly not converted", ("UGA", 2011): "only consumed items listed; fish in heaps mostly not converted; no household size",
    ("UGA", 2013): "only consumed items listed; fish in heaps mostly not converted", ("UGA", 2015): "only consumed items listed; fish in heaps mostly not converted",
    ("UGA", 2018): "fish in heaps mostly not converted", ("UGA", 2019): "fish in heaps mostly not converted"}
D["round_cautions"] = [ROUND_ISSUES.get((c, y), "") for c, y in zip(D.country, D.year)]

COLS = (["hh_uid", "country", "year", "survey_round", "hhid", "panel_id", "food_module_file", "in_household_files", "weight", "region", "cluster", "strata",
         "rural", "refugee_camp", "int_month", "int_year", "hhsize", "adulteq", "adulteq_type", "head_female", "head_age", "share_child", "share_elderly",
         "welfare", "welfare_definition", "welfare_quintile", "food_cons_annual_official", "currency", "gdp_pc_ppp_const2021"]
        + [f"{v}_{c}" for c in CATS for v in ["n_items_asked", "consumed"]]
        + [f"prot_{c}_g_wk" for c in CATS] + [f"prot_{c}_g_day_ae" for c in CATS]
        + [f"prot_{c}_{k}_g_wk" for c in CATS for k in ["market", "own", "gift"]]
        + [f"kg_{c}_wk" for c in CATS] + [f"exp_{c}_wk" for c in CATS]
        + ["prot_asf_g_wk", "prot_total_g_wk", "prot_asf_g_day_ae", "prot_total_g_day_ae"]
        + [f"prot_{c}_g_wk_lb" for c in CATS] + [f"prot_{c}_g_day_ae_lb" for c in CATS] + ["prot_asf_g_wk_lb", "prot_total_g_wk_lb", "prot_total_g_day_ae_lb"]
        + [f"n_items_unconverted_{c}" for c in CATS] + [f"n_items_approx_coef_{c}" for c in CATS] + [f"n_items_outlier_{c}" for c in CATS]
        + ["n_items_asked_unsplit", "prot_unsplit_g_wk", "round_cautions"])
D = D[COLS]
assert not D.duplicated(KEY).any()
print(f"  dataset: {len(D)} households, {len(COLS)} columns ({time.time() - T0:.0f}s)", flush=True)

# ------------------------------------------------------------------------------------------
# 5. checks
# ------------------------------------------------------------------------------------------
# (a) totals recomputed from the item table with another path: pivot of the items, then sums with all-or-nothing
chk = []
P = IT.assign(p=np.where(IT.cons == 0, 0.0, IT.prot_tot)).pivot_table(index=KEY, columns="category", values="p", aggfunc=lambda s: s.sum(min_count=len(s)) if s.notna().all() else np.nan)
P = P.reindex(pd.MultiIndex.from_frame(D[KEY]))
for c in CATS:
    a = P[c].to_numpy() if c in P else np.full(len(D), np.nan); b = D[f"prot_{c}_g_wk"].to_numpy()
    chk.append(dict(check=f"prot_{c}_g_wk recomputed from the items", same_missing=bool((np.isnan(a) == np.isnan(b)).all()),
                    max_abs_difference=float(np.nanmax(np.abs(a - b))) if (~np.isnan(a) & ~np.isnan(b)).any() else 0.0))
CHK = pd.DataFrame(chk)
# (b) coverage: consumed items with protein computed, by round and category
cov = IT[IT.cons == 1].groupby(["country", "year", "category"]).agg(consumed_items=("cons", "size"), with_protein=("prot_tot", lambda s: int(s.notna().sum())),
                                                                   approx_coef=("coef_quality", lambda s: int((s == "C").sum()))).reset_index()
cov["pct_with_protein"] = (100 * cov.with_protein / cov.consumed_items).round(1)
COV = cov.pivot_table(index=["country", "year"], columns="category", values="pct_with_protein").reset_index().sort_values(["country", "year"], key=ckey)
# (c) missing versus zero, by round
mz = []
for (c, y), g in D.groupby(["country", "year"]):
    row = {"country": c, "year": y, "households": len(g)}
    for k in CATS:
        v = g[f"prot_{k}_g_wk"]
        row[f"{k}: zero"] = int((v == 0).sum()); row[f"{k}: positive"] = int((v > 0).sum()); row[f"{k}: missing"] = int(v.isna().sum())
    mz.append(row)
MZ = pd.DataFrame(mz).sort_values(["country", "year"], key=ckey)
# (d) distribution of grams per adult equivalent per day, consumers only, weighted medians not used (raw quantiles)
dist = []
for (c, y), g in D.groupby(["country", "year"]):
    for k in CATS + ["asf"]:
        v = g[f"prot_{k}_g_day_ae"]; v = v[v > 0]
        if len(v):
            dist.append(dict(country=c, year=y, category=k, consumers_with_value=len(v), p10=round(v.quantile(.1), 1), median=round(v.median(), 1),
                             p90=round(v.quantile(.9), 1), p99=round(v.quantile(.99), 1), above_200g=int((v > 200).sum())))
DIST = pd.DataFrame(dist).sort_values(["country", "year", "category"], key=ckey)

# ------------------------------------------------------------------------------------------
# 6. write
# ------------------------------------------------------------------------------------------
CSVF = os.path.join(OUTD, f"protein_harmonized_{TODAY}.csv.gz"); D.to_csv(CSVF, index=False)
ITF = os.path.join(OUTD, f"protein_harmonized_items_{TODAY}.csv.gz")
IT[["country", "year", "hhid", "slot", "code", "category", "cons", "conv_method", "kg_tot", "kg_market", "kg_own", "kg_gift", "g_per_kg", "coef_quality", "prot_tot",
    "prot_market", "prot_own", "prot_gift", "exp7", "outlier"]].to_csv(ITF, index=False)
for name, df in [("qc_totals", CHK), ("qc_coverage", COV), ("qc_missing_zero", MZ), ("qc_distribution", DIST)]:
    df.to_csv(os.path.join(OUTD, f"{name}.csv"), index=False)
IT[IT.cons == 1].groupby(["country", "year", "category", "slot", "coef_quality"]).agg(consumed=("cons", "size"), with_kg=("kg_tot", lambda s: int(s.notna().sum())),
    with_protein=("prot_tot", lambda s: int(s.notna().sum())), median_kg=("kg_tot", "median"), g_per_kg=("g_per_kg", "first")).reset_index().to_csv(os.path.join(OUTD, "qc_items.csv"), index=False)
print(f"written {CSVF} and {ITF} ({time.time() - T0:.0f}s)")
print(CHK.to_string()); print(COV.to_string())

# ------------------------------------------------------------------------------------------
# 7. round comparability, documentation and workbook
# ------------------------------------------------------------------------------------------
import xlsxwriter
RV = pd.read_csv(os.path.join(BUILD, "role_vars.csv")); RV = RV[RV.exists]; RV["year"] = RV.year.astype(int)
ROUNDS = sorted({(c, int(y)) for c, y in zip(D.country, D.year)}, key=lambda r: (COUNTRIES.index(r[0]), r[1]))
RLAB = [f"{c}_{y}" for c, y in ROUNDS]
covd = cov.set_index(["country", "year", "category"])
rt = []
for c, y in ROUNDS:
    g = D[(D.country == c) & (D.year == y)]
    row = {"country": c, "year": y, "households": len(g), "consumption recall": "7 days",
           "purchase spending": "last 30 days, most recent purchase: not used" if (c, y) in NGA_PURCHASE_30D else "7 days",
           "quantity conversion": {"ETH": "official Food_CF table (kg per unit); metric units", "TZA": "metric units (codes 1-5); 2020: survey weight estimates",
                                   "MWI": "metric units, 'other' text, official 2020 table (not for red meat, fish, other poultry)",
                                   "NGA": "survey conversion table (2012, 2015), metric labels (2010), kg/l factor of the file (2018, 2023)",
                                   "UGA": "metric content of the unit label; chicken 1.3 kg per bird"}[c],
           "cautions": ROUND_ISSUES.get((c, y), "")}
    for k in CATS:
        asked = int(g[f"n_items_asked_{k}"].max()) if g[f"n_items_asked_{k}"].notna().any() else 0
        pc = covd.pct_with_protein.get((c, y, k), np.nan)
        nonmiss = round(100 * g[f"prot_{k}_g_wk"].notna().mean(), 1)
        status = "not available" if asked == 0 else "comparable" if (pc >= 90 or np.isnan(pc)) and nonmiss >= 90 else "caution" if nonmiss >= 50 else "low coverage"
        if c == "ETH" and y in (2011, 2013) and k == "animal":
            status = "caution"
        row.update({f"{k}: items asked": asked, f"{k}: % consumed items with protein": pc, f"{k}: % households with protein": nonmiss, f"{k}: status": status})
    rt.append(row)
RT = pd.DataFrame(rt)
st = RT.set_index(["country", "year"])
for k in CATS:
    D[f"round_status_{k}"] = [st.at[(c, y), f"{k}: status"] for c, y in zip(D.country, D.year)]
COLS = COLS[:-1] + [f"round_status_{k}" for k in CATS] + ["round_cautions"]
D = D[COLS]
D.to_csv(CSVF, index=False)

def avail(col):
    nn = D.groupby(["country", "year"])[col].apply(lambda s: s.notna().any())
    rs = [k for k, v in nn.items() if v]
    out = []
    for c in COUNTRIES:
        ys = [str(y) for cc, y in rs if cc == c]
        if ys:
            out.append(f"{c} {', '.join(ys)}")
    return "; ".join(out)

Q = "consumed items of the category"
DOC = {
 "hh_uid": ("Unique key", "country_year_hhid", "-", "text", ""),
 "country": ("ISO3 country code", "-", "-", "text", ""),
 "year": ("First year of fieldwork of the round", "-", "-", "year", ""),
 "survey_round": ("Country and round", "country_year", "-", "text", ""),
 "hhid": ("Household identifier of the round", "as in the food module", "food module household id", "text", "text, leading zeros kept"),
 "panel_id": ("Identifier of the same household across rounds", "Step I panel_ids(); Nigeria 2018-2023: hhid (stable in the GHS-Panel)", "household ids of the panels", "text", "Malawi not linked (cross-sections)"),
 "food_module_file": ("Food module file of the household", "-", "-", "text", "Tanzania 2020: two samples"),
 "in_household_files": ("1 if the household is found in the household (aggregate / cover) files", "-", "-", "0/1", "0: household variables empty"),
 "weight": ("Household sampling weight", "as in the survey", "ETH pw*, TZA hhweight / y3_weight, MWI hh_wgt, NGA hhweight / wt_wave4 / wt_cross_wave5, UGA wgt10 / mult / wgt_X / h_xwgt_W5 / wgt", "weight",
            "cross-sectional weights; do not pool rounds without rescaling"),
 "region": ("Region used for fixed effects in Step I", "survey codes", "ETH saq01, TZA region, MWI district, NGA zone, UGA region", "code", "codes are country-specific"),
 "cluster": ("Enumeration area / cluster", "survey codes", "EA id (Nigeria: state_lga_ea; Uganda 2018-19: parish)", "code", ""),
 "strata": ("Sampling stratum", "survey codes", "Tanzania strataid", "code", "Tanzania only"),
 "rural": ("1 = rural, 0 = urban", "from the raw codes: ETH, TZA 1 = rural; NGA sector 2 = rural; MWI, UGA 0 = rural", "rural / saq14, urban, reside, sector, urban", "0/1", ""),
 "refugee_camp": ("Malawi 2024: 1 = Dzaleka refugee camp sample", "camp", "hh_mod_a_filt camp", "0/1", "no welfare aggregate"),
 "int_month": ("Month of interview", "as in the file", "TZA intmonth, MWI smonth, UGA month", "month", "not available for Ethiopia and Nigeria"),
 "int_year": ("Year of interview", "as in the file", "TZA intyear, MWI syear, UGA year", "year", ""),
 "hhsize": ("Household size", "as in the aggregate / panel", "hh_size, hhsize, hsize", "persons", "Malawi 2010 and Uganda 2011 from the roster count (Step I)"),
 "adulteq": ("Adult equivalents", "official scale; Malawi and Nigeria: household size", "adulteq, equiv", "adult equivalents", "scales differ by country; see adulteq_type"),
 "adulteq_type": ("Which adult-equivalent measure", "-", "-", "text", ""),
 "head_female": ("1 = female head", "from the roster (Step I)", "roster sex, relationship", "0/1", "Nigeria not available"),
 "head_age": ("Age of the household head", "from the roster (Step I)", "roster age", "years", "Nigeria not available"),
 "share_child": ("Share of members under 15", "from the roster (Step I)", "roster age", "share", "Nigeria not available"),
 "share_elderly": ("Share of members aged 60 or more", "from the roster (Step I)", "roster age", "share", "Nigeria not available"),
 "welfare": ("Consumption-based welfare measure of Step I", "see welfare_definition", "official consumption aggregates", "local currency per year",
             "definitions, price bases and currencies differ: use within country-round (logs with fixed effects) or the quintile; not comparable in level across countries"),
 "welfare_definition": ("Definition of welfare in the country", "-", "-", "text", ""),
 "welfare_quintile": ("Welfare quintile within country and round", "rank of welfare, unweighted, 1 = poorest", "welfare", "1-5", "relative position: comparable across countries"),
 "food_cons_annual_official": ("Annual food consumption of the official aggregate", "Step I food_spend()", "food_cons_ann, foodbevR, rexp_cat011, sum of fd*, food module", "local currency per year",
                               "Nigeria 2018-2023 not computed (components of the file appear per capita, period not documented)"),
 "currency": ("Currency of the monetary variables", "-", "-", "text", ""),
 "gdp_pc_ppp_const2021": ("GDP per capita, PPP, of the country and year", "WDI NY.GDP.PCAP.PP.KD", "World Bank WDI", "constant 2021 international $", "country-year level"),
 "round_cautions": ("Known limits of the round", "-", "-", "text", "see Comparability"),
}
for k in CATS:
    nm = {"animal": "animal-source foods other than fish (meat, eggs, dairy)", "fish": "fish and seafood", "plant": "plant protein foods (pulses, soy, groundnuts, nuts, seeds)"}[k]
    lim = {"animal": "Ethiopia 2011-2013: one item for all meat, possibly with fish; Malawi: red meat and other poultry in pieces not converted; meat weights include bone",
           "fish": "Malawi and Uganda: fish in heaps or whole pieces mostly not converted; Ethiopia: form not asked; dried and fresh fish differ about three times in protein",
           "plant": "only protein-rich plant foods: cereals, roots and vegetables are NOT included; Uganda: volume units (cups) not converted"}[k]
    DOC.update({
     f"n_items_asked_{k}": (f"Number of items of {nm} in the round's questionnaire for the household", "count of the items mapped to the category", "item list of the food module", "items", "lists differ by round: see Comparability_Matrix"),
     f"consumed_{k}": (f"1 if the household consumed any item of {nm} in the last 7 days", "max of the item answers; missing if none consumed and some not answered, or none asked",
                       "consumed yes/no of each item (and quantities)", "0/1", ""),
     f"prot_{k}_g_wk": (f"Grams of protein from {nm} consumed in the last 7 days", "sum over items of kg consumed x protein g/kg; missing if any consumed item has no kg or no coefficient, or the category is not asked",
                        "quantity consumed in total and unit of each item; protein_coefficients.csv", "grams per week", lim),
     f"prot_{k}_g_day_ae": (f"Grams of protein from {nm} per adult equivalent per day", f"prot_{k}_g_wk / 7 / adulteq", "as above", "grams per adult equivalent per day", lim + "; adult-equivalent scales differ"),
     f"prot_{k}_market_g_wk": (f"Grams of protein from {nm} that came from purchases", "as prot, with the quantity from purchases", "quantity from purchases (Uganda: at home and away; Nigeria 2012-2023: consumed out of purchases; 2010: purchased)", "grams per week", lim),
     f"prot_{k}_own_g_wk": (f"Grams of protein from {nm} from own production", "as prot, with the quantity from own production", "quantity from own production", "grams per week", lim),
     f"prot_{k}_gift_g_wk": (f"Grams of protein from {nm} from gifts and other sources", "as prot, with the quantity from gifts", "quantity from gifts", "grams per week", lim),
     f"kg_{k}_wk": (f"Kilograms of {nm} consumed in the last 7 days", "sum of kg (milk at 1.03 kg/l, eggs at 55 g)", "quantities and units", "kg per week", "weights of different foods: use protein to compare"),
     f"exp_{k}_wk": (f"Purchase spending on {nm}, last 7 days", "sum of the amounts paid; 0 for items not bought", "amount paid of each item", "local currency per week",
                     "Nigeria 2018-2023 missing (30-day most recent purchase); Uganda: purchases consumed at home; own production and gifts not valued"),
     f"prot_{k}_g_wk_lb": (f"Lower bound of prot_{k}_g_wk: sum over the consumed items that can be converted", "as prot, leaving out the items not converted", "as above", "grams per week",
                           f"NOT a full measure: n_items_unconverted_{k} items left out"),
     f"prot_{k}_g_day_ae_lb": (f"Lower bound per adult equivalent per day", f"prot_{k}_g_wk_lb / 7 / adulteq", "as above", "grams per adult equivalent per day", "lower bound"),
     f"n_items_unconverted_{k}": (f"Consumed items of {nm} without protein (unit or coefficient missing) or not answered", "count", "-", "items", ""),
     f"n_items_approx_coef_{k}": (f"Consumed items of {nm} whose protein coefficient is approximate (quality C)", "count", "protein_coefficients.csv", "items", ""),
     f"n_items_outlier_{k}": (f"Consumed items of {nm} with an implausible price, quantity or spending (Step I thresholds M17/M18)", "count of flags 1, 2, 4 of the build", "-", "items",
                              "values kept: drop or trim at the analysis stage"),
     f"round_status_{k}": (f"Comparability of {nm} in the round", "comparable: >= 90% of consumed items and households with protein; caution: 50-90%; low coverage: < 50%; not available: not asked",
                           "Comparability sheet", "text", ""),
    })
DOC.update({
 "prot_asf_g_wk": ("Grams of protein from all animal-source foods (animal + fish; Malawi also the unsplit meat-or-fish items)", "prot_animal_g_wk + prot_fish_g_wk (+ prot_unsplit_g_wk)", "as above", "grams per week", "missing where fish is missing or not asked"),
 "prot_total_g_wk": ("Grams of protein from the three categories", "prot_asf_g_wk + prot_plant_g_wk", "as above", "grams per week", "protein-rich foods only: cereals, roots and vegetables not included"),
 "prot_asf_g_day_ae": ("prot_asf per adult equivalent per day", "prot_asf_g_wk / 7 / adulteq", "", "grams per adult equivalent per day", ""),
 "prot_total_g_day_ae": ("prot_total per adult equivalent per day", "prot_total_g_wk / 7 / adulteq", "", "grams per adult equivalent per day", "protein-rich foods only"),
 "prot_asf_g_wk_lb": ("Lower bound of prot_asf", "sum of the lower bounds", "", "grams per week", "lower bound"),
 "prot_total_g_wk_lb": ("Lower bound of prot_total", "sum of the lower bounds", "", "grams per week", "lower bound"),
 "prot_total_g_day_ae_lb": ("Lower bound of prot_total per adult equivalent per day", "prot_total_g_wk_lb / 7 / adulteq", "", "grams per adult equivalent per day", "lower bound"),
 "n_items_asked_unsplit": ("Malawi: items of meat or fish that cannot be split (tinned meat or fish; 'other' of the group)", "count", "", "items", "Malawi only"),
 "prot_unsplit_g_wk": ("Malawi: protein from the unsplit meat-or-fish items", "kg x 250 g/kg (tinned); 'other' not computed", "", "grams per week", "Malawi only; counted in prot_asf, not in animal or fish"),
})
dd = []
for i, c in enumerate(D.columns):
    d = DOC.get(c, ("", "", "", "", ""))
    dd.append({"col": i + 1, "variable": c, "definition": d[0], "formula": d[1], "original variables": d[2], "unit": d[3], "countries and rounds with values": avail(c),
               "non-missing": int(D[c].notna().sum()), "comparability limits": d[4]})
DD = pd.DataFrame(dd)
missing_doc = [c for c in D.columns if c not in DOC]
assert not missing_doc, missing_doc

FC = MAP.copy()
FC["category"] = FC.slot.map(CAT3)
FC = FC.merge(C[["country", "slot", "composition_item", "protein_g_per_100g", "edible_portion", "g_per_kg", "source", "quality"]].rename(columns={"country": "coef_country"}),
              on="slot", how="left")
FC = FC[(FC.coef_country == FC.country) | ((FC.coef_country == "*") & ~FC.set_index(["country", "slot"]).index.isin(
    [tuple(x) for x in C[C.country != "*"][["country", "slot"]].values]))]
FC = FC[["country", "year", "code", "label", "slot", "cat", "sub", "category", "std", "composition_item", "protein_g_per_100g", "edible_portion", "g_per_kg", "source", "quality", "note"]]
FC = FC.sort_values(["country", "year", "category", "slot"], key=ckey)
QV = []
ROLE_NAMES = {"cons_raw": "consumed in the last 7 days (yes/no)", "q_tot": "quantity consumed, total", "u_tot": "unit of the total", "q_pur": "quantity from purchases",
              "exp_pur": "amount paid (7 days)", "q_own": "quantity from own production", "q_gift": "quantity from gifts", "q_away": "purchased and consumed away (Uganda)",
              "val_own": "value of own production (Uganda)", "val_gift": "value of gifts (Uganda)", "q_frompur": "consumed out of purchases (Nigeria)", "pur30_yn": "purchased in the last 30 days (Nigeria 2018-2023)",
              "q_lastpur": "quantity of the most recent purchase", "val_lastpur": "amount of the most recent purchase", "cvn_tot": "kg/l factor of the file", "q_wt": "weight estimate (Tanzania 2020)"}
for b, nm in ROLE_NAMES.items():
    row = {"question": nm, "role": b}
    for (c, y), rl in zip(ROUNDS, RLAB):
        g = RV[(RV.country == c) & (RV.year == y) & (RV.role == b)]
        row[rl] = " / ".join(f"{v}: {l}" for v, l in zip(g.variable, g.label.fillna(""))) if len(g) else None
    row["used in the harmonized dataset"] = {"cons_raw": "yes: consumed_*", "q_tot": "yes: kg and protein", "u_tot": "yes: conversion", "q_pur": "yes: market source",
        "exp_pur": "yes: exp_* (not Nigeria 2018-2023)", "q_own": "yes: own source", "q_gift": "yes: gift source", "q_away": "yes: market source (Uganda)",
        "val_own": "no: valued only in Uganda", "val_gift": "no: valued only in Uganda", "q_frompur": "yes: market source (Nigeria 2012-2023)",
        "pur30_yn": "no: 30-day recall", "q_lastpur": "no: 30-day recall", "val_lastpur": "no: 30-day recall", "cvn_tot": "yes: conversion (Nigeria 2018-2023)", "q_wt": "yes: conversion (Tanzania 2020)"}[b]
    QV.append(row)
QV = pd.DataFrame(QV)
CONV = pd.DataFrame([
    ("all", "kilograms", "quantity x factor of the unit", "official conversion tables of the surveys or units of metric content (build_protein_dataset.R)"),
    ("all", "litres of milk and liquid dairy", "x 1.03 kg per litre", "density of milk"),
    ("TZA, MWI, UGA", "eggs counted in pieces", "x 0.055 kg per egg", "Tanzania NPS 2020 calibration (Step I TRAP 6); Nigeria's own factor is 0.045 kg"),
    ("ETH", "local units", "national mean factor of Food_CF (kg per unit) for the item and unit", "Food_CF_Wave1-5"),
    ("TZA 2020", "local units (heap, piece, cup...)", "survey weight estimate hh_ja02b (kg, g, l, ml)", "new in this dataset; not in Step I"),
    ("MWI", "local units", "official 2020 factor table (by region, item, unit), except red meat, fish and other poultry", "Step I decision: implied prices contradict the table for those items"),
    ("NGA 2012, 2015", "local units", "survey conversion table (food_conv_w2ph, food_conv_w3)", ""),
    ("NGA 2018, 2023", "all units", "q2 quantity x q2_cvn (kg/l factor given in the file)", "sources (q5-q7, q3-q5) in the unit of the total"),
    ("UGA", "local units", "kilograms or litres stated in the label (tins, sacks, packets, cups of 0.5 l for liquids); chicken 1.3 kg per bird; 'Nice cup' 0.5 l",
     "cups and glasses of dry foods not converted (would need a density)"),
    ("all", "protein", "kg x protein g per 100 g x 10 x edible portion", "protein_coefficients.csv: A table match, B proxy, C approximate, X not computed"),
], columns=["scope", "what", "conversion", "source / note"])

XL = os.path.join(OUTD, f"protein_harmonized_{TODAY}.xlsx")
wb = xlsxwriter.Workbook(XL, {"constant_memory": True, "nan_inf_to_errors": False})
H1 = wb.add_format({"bold": True, "bg_color": "#DCE6F1", "border": 1, "text_wrap": True, "valign": "top"})
TT = wb.add_format({"bold": True, "font_size": 13}); NT = wb.add_format({"italic": True, "font_color": "#555555"}); WR = wb.add_format({"text_wrap": True, "valign": "top"})
def sheet(name, blocks, widths=None, notes=()):
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
                else: ws.write_string(r, j, str(v))
            r += 1
        r += 1
    for (a, b, w) in (widths or []): ws.set_column(a, b, w)
    return ws
ws = sheet("Harmonized_Dataset", [(None, D)], [(0, 0, 22), (1, len(D.columns), 13)])
ws.freeze_panes(1, 2)
sheet("Data_Dictionary", [(None, DD)], [(0, 0, 5), (1, 1, 28), (2, 3, 55), (4, 4, 45), (5, 5, 18), (6, 6, 40), (8, 8, 60)],
      ["One row per household and round of the food modules (LSMS-ISA). Grams of protein from protein-rich foods only (no cereals, roots, vegetables).",
       "Missing values are never set to zero: a total is missing if any consumed item cannot be converted or is not answered, or if the category is not asked. *_lb = lower bounds over the converted items."])
sheet("Comparability", [("A. Rounds and categories", RT), ("B. Food questions of the questionnaires, by round", QV)], [(0, 1, 10), (2, 30, 18)],
      ["status: comparable = 90% or more of the consumed items and of the households have protein; caution = 50-90%; low coverage = under 50%; not available = not asked.",
       "Consumption is asked on a 7-day recall in every round; purchase spending is on 7 days except Nigeria 2018-2023 (30 days, most recent purchase: not used)."])
sheet("Food_Classification", [(None, FC)], [(0, 2, 8), (3, 3, 45), (4, 8, 16), (9, 9, 45), (13, 13, 40)],
      ["Every original item code of every round, its harmonized item (slot), its category and the protein coefficient used. category: animal, fish, plant; unsplit (Malawi meat-or-fish); excluded."])
sheet("Protein_Coefficients", [(None, C)], [(0, 1, 18), (2, 2, 10), (3, 3, 60), (6, 6, 45), (8, 8, 60)],
      ["Protein per 100 g of edible portion, raw. g_per_kg = protein x 10 x edible_portion, applied to the kilograms recorded. Meat and fish weights include bone (share unknown), as in Step I.",
       "quality: A = the food of the table; B = proxy of a similar food; C = approximate (form or mix not stated); X = not computed. WAFCT 2012 = FAO/INFOODS West African Food Composition Table; USDA = FoodData Central SR Legacy.",
       "Values transcribed from the cited tables: check them against the tables before publication."])
sheet("Unit_Conversion", [("A. Rules", CONV), ("B. Consumed items with protein computed, % by round and category", COV)], [(0, 0, 14), (1, 1, 30), (2, 2, 60), (3, 3, 60)])
sheet("Quality_Control", [("A. Totals recomputed from the item table", CHK), ("B. Missing versus zero, households by round", MZ),
                          ("C. Protein per adult equivalent per day, consumers with a value (grams)", DIST)], [(0, 0, 40), (1, 20, 12)],
      [f"{len(D)} households, {int(D.duplicated(KEY).sum())} duplicated keys; item file: {os.path.basename(ITF)} (household x item: kg, protein, method)."])
wb.close()
print(f"written {XL} ({os.path.getsize(XL) / 1e6:.1f} MB)")
print(RT[["country", "year"] + [f"{k}: status" for k in CATS] + [f"{k}: % households with protein" for k in CATS]].to_string())
