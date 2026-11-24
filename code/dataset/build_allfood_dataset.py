#!/usr/bin/env python3
"""
HOUSEHOLD FOOD BUDGET, ALL FOODS: one row per household x round, for the LA/AIDS demand system (24 Nov 2026).

Decisions (Paolo, 24 Nov 2026):
  A1 all 5 countries, 23 rounds (Ethiopia 2011-2013 out); A2 Nigeria 2018-2023 kept, purchases valued with the prices of the
  last purchase (30 days), flagged; A3 Tanzania 2020: both samples, flagged (column sample).
  B1 alcohol inside beverages; B2 tobacco excluded; khat and kola nut excluded (stimulants);
  B3 a food away from home = a separate category, value only, no prices, no quantity.
  C 26 categories at home: the 17 protein columns of the protein dataset + cereals, starches, sugar_sweets, vegetables,
    fruits, oils_fats, spices_other, beverages, other_food. C3 items stay out (butter-margarine, insects, snails, wild birds,
    tinned meat or fish, "other (specify)" meat/fish/pulses): the budget does not reach 100% of reported food by design.
  D1 b value of own production and gifts = quantity x local median unit value of PURCHASES of the same item in the same unit
    (EA -> district -> region -> national, at least NMIN purchases); D2 a purchase (retail) prices.
  E1 a value still missing -> median value of the same item and source among households of the same area (same hierarchy),
    flagged; the imputed part of each category is in <category>_value_imp (sensitivity without imputation = value - value_imp).
  E2 a outliers -> missing, then imputed: unit values outside 1/10-10 times the national median of the item and unit;
    values above 100 times the national median value of the item and source.
  F quantities: kg (protein categories, cereals, starches, sugar, vegetables, fruits, oils), litres for beverages (liquid
    drinks only: dry tea, coffee, cocoa and hops have a value but no quantity), none for spices_other and other_food.
    Units the survey tables do not convert: kg estimated from prices (median paid per unit / median price per kg), flagged.
  G values 7 days, nominal local currency; value by source; n_items = items consumed; one Excel file + one per country.
  H2 a detailed categories + 12 aggregated groups. H3 denominator of the shares = sum of the 26 categories at home.

usage: build_allfood_dataset.py <allfood long dir> <wide_check.csv.gz> <module_households.csv> <item_map.csv>
                                <food_category_map.csv> <unit_codes.csv> <out dir>
"""
import sys, os, re, time, datetime
import numpy as np, pandas as pd, warnings
warnings.simplefilter("ignore", pd.errors.PerformanceWarning)

LONGD, WIDECHK, MODHH, MAPF, CATF, UNITF, OUTD = sys.argv[1:8]
os.makedirs(OUTD, exist_ok=True)
T0 = time.time(); TODAY = datetime.date.today().isoformat()
def log(m): print(f"{m} ({time.time() - T0:.0f}s)", flush=True)

COUNTRIES = ["ETH", "TZA", "MWI", "NGA", "UGA"]
SVY = {("NGA", 2018), ("NGA", 2023)}
NMIN = 5
CATS = ["beef", "goat_sheep", "pork", "processed_red_meat", "meat_other", "poultry", "eggs", "milk_fresh", "dairy_processed",
        "fish_fresh", "fish_processed", "pulses_dry", "pulses_fresh", "groundnuts", "soy", "nuts", "seeds",
        "cereals", "starches", "sugar_sweets", "vegetables", "fruits", "oils_fats", "spices_other", "beverages", "other_food"]
PROTEIN = set(CATS[:17])
NOQTY = {"spices_other", "other_food"}
GROUPS = {"red_meat": ["beef", "goat_sheep", "pork", "processed_red_meat", "meat_other"], "poultry": ["poultry"],
          "fish": ["fish_fresh", "fish_processed"], "eggs": ["eggs"], "dairy": ["milk_fresh", "dairy_processed"],
          "pulses_nuts_seeds": ["pulses_dry", "pulses_fresh", "groundnuts", "soy", "nuts", "seeds"], "cereals": ["cereals"],
          "starches": ["starches"], "fruits_vegetables": ["fruits", "vegetables"], "oils_fats": ["oils_fats"],
          "sugar_sweets": ["sugar_sweets"], "beverages_other": ["beverages", "spices_other", "other_food"]}
LEVELS = ["ea", "district", "region", "nat"]
DRY_BEV = re.compile(r"\btea\b(?!.*prepared)|coffee|cocoa|milo|gesho|hops|raw materi|chocolate drink", re.I)
PREPARED_TEA = re.compile(r"prepared tea", re.I)

# ------------------------------------------------------------------------------------------
# reference tables
# ------------------------------------------------------------------------------------------
CM = pd.read_csv(CATF, keep_default_na=False, na_values=[""])
CM["round"] = CM["round"].astype(int)
LAB = {(c, r, s if isinstance(s, str) else "", int(k)): l for c, r, s, k, l in CM[["country", "round", "sample", "code", "clean_label"]].itertuples(index=False)}
MAP = pd.read_csv(MAPF); MAP["round"] = MAP.year.astype(int)
STD = {(c, r, int(k)): s for c, r, k, s in MAP[["country", "round", "code", "std"]].itertuples(index=False)}
UC = pd.read_csv(UNITF, dtype=str, keep_default_na=False, na_values=[""]); UC["year"] = UC.year.astype(int)
def ncode(x):
    if x is None or (isinstance(x, float) and np.isnan(x)): return None
    x = str(x).strip()
    return None if x == "" or x.lower() == "nan" else x.removesuffix(".0")
ULAB = {}
for c, y, code, lab in UC[["country", "year", "code", "label"]].itertuples(index=False):
    k = (c, y, ncode(code))
    if isinstance(lab, str) and lab.strip() and k not in ULAB: ULAB[k] = lab.strip()
def ulabel(cc, y, key):
    if not isinstance(key, str): return None
    code = key.split("|")[0]; lab = ULAB.get((cc, y, code))
    if cc == "MWI" and (lab is None or lab.strip() in (code, re.sub(r"[A-Z]$", "", code))):
        lab = ULAB.get(("MWI", 2019, code)) or ULAB.get(("MWI", 2016, code))
    return lab
def is_other(lab):
    l = lab.strip().lower() if isinstance(lab, str) else ""
    return "specify" in l or l.startswith("other") or l in ("other", "others")
def metric_w(lab, liquid):
    """std units per unit when the label is metric or states the content ('PACKET (150G)'); litres only for liquids"""
    if not isinstance(lab, str): return np.nan
    l = re.sub(r"^\d+\.\s*", "", lab.strip().lower())
    if re.search(r"up to|\bto\s*\d|above|between|\d\s*-\s*\d", l): return np.nan
    if re.fullmatch(r"(kilo(gram(me)?)?s?|kgs?)(\s*\(kgs?\))?", l): return 1.0
    if re.fullmatch(r"(grams?|grammes?|gms?)", l): return 0.001
    if re.fullmatch(r"(litres?|liters?|ltrs?)", l): return 1.0 if liquid else np.nan
    if re.fullmatch(r"(millilitres?|milliliters?|mls?)", l): return 0.001 if liquid else np.nan
    m = re.search(r"(\d+(?:\.\d+)?)\s*(kgs?|kilograms?|grams?|gms?|g)\b", l)
    if m:
        v = float(m.group(1)); return v if m.group(2).startswith("k") else v / 1000
    if liquid:
        m = re.search(r"(\d+(?:\.\d+)?)\s*(ml|millilit\w*|lt?r?s?|litres?)\b", l)
        if m:
            v = float(m.group(1)); return v / 1000 if m.group(2).startswith("m") else v
    return np.nan

## household columns: the same 23 as the protein dataset (one row per household x round)
HCOLS = ["country", "year", "hhid", "panel_id", "weight", "region", "district", "subdistrict", "ea", "strata", "rural", "hhsize", "adulteq",
         "int_month", "int_year", "head_female", "head_age", "welfare_annual", "welfare_scale", "welfare_var",
         "cons_total_hh_annual", "food_cons_hh_annual", "not_collected"]
H = pd.read_csv(WIDECHK, usecols=HCOLS, dtype={c: str for c in ["hhid", "panel_id", "region", "district", "subdistrict", "ea", "strata", "not_collected"]},
                keep_default_na=False, na_values=[""], low_memory=False)
MH = pd.read_csv(MODHH, usecols=["hhid", "country", "year", "module"], dtype={"hhid": str, "module": str}, keep_default_na=False, na_values=[""])
H = H.merge(MH, on=["country", "year", "hhid"], how="left")
H["sample"] = np.where((H.country == "TZA") & (H.year == 2020), H.module.fillna(""), "")
H = H.drop(columns="module")
log(f"households: {len(H)}")

# ------------------------------------------------------------------------------------------
# helpers
# ------------------------------------------------------------------------------------------
def ukey(u, us):
    return [None if ncode(a) is None else f"{ncode(a)}|{ncode(b) or ''}" for a, b in zip(u, us)]

def hier(obs, base, val, q):
    """median of obs[val] by base keys + area level, first level with >= NMIN observations; returns (value, level) aligned to q"""
    out = pd.Series(np.nan, index=q.index); lev = pd.Series(None, index=q.index, dtype=object)
    for L in LEVELS:
        keys = base + ([] if L == "nat" else [L])
        o = obs.dropna(subset=keys + [val])
        g = o.groupby(keys, observed=True)[val].agg(["median", "size"])
        g = g[g["size"] >= NMIN]["median"].rename("_m").reset_index()
        need = out.isna()
        if not need.any() or g.empty: continue
        m = q.loc[need, keys].merge(g, on=keys, how="left")["_m"].to_numpy()
        idx = out.index[need]
        out.loc[idx] = m; lev.loc[idx[~np.isnan(m)]] = L
    return out, lev

def national_bounds(obs, base, val):
    g = obs.groupby(base, observed=True)[val].agg(["median", "size"]).reset_index()
    return g[g["size"] >= NMIN].rename(columns={"median": "_med"}).drop(columns="size")

QC = {k: [] for k in ["rows", "valuation", "quantity", "fafh", "check_uga", "outliers"]}
WEIGHTS = []
DATA = []

# ------------------------------------------------------------------------------------------
# per country
# ------------------------------------------------------------------------------------------
FA = pd.read_csv(os.path.join(LONGD, "fafh_modules_hh.csv"), dtype={"hhid": str})
UNITC = ["u_tot", "us_tot", "u_pur", "us_pur", "u_own", "us_own", "u_gift", "us_gift", "u_frompur", "u_lastpur", "us_lastpur", "u_wt"]
for cc in COUNTRIES:
    L = pd.read_csv(os.path.join(LONGD, f"allfood_long_{cc}.csv.gz"), dtype={c: str for c in ["hhid", "module", "category"] + UNITC},
                    keep_default_na=False, na_values=[""], low_memory=False)
    for c in ["q_tot", "q_pur", "exp_pur", "exp", "q_own", "q_gift", "q_away", "val_away", "val_own", "val_gift", "q_frompur", "q_wt",
              "q_lastpur", "val_lastpur", "cvn_tot", "cvn_lastpur", "s_tot", "s_pur", "s_own", "s_gift", "s_frompur", "cons", "cons_raw"]:
        L[c] = pd.to_numeric(L[c], errors="coerce") if c in L else np.nan
    for c in UNITC:
        if c not in L: L[c] = None
    L["year"] = L.year.astype(int)
    L = L[L.cons == 1].copy()
    n_rows0 = len(L)
    L["module"] = L.module.fillna("")
    L["sample"] = np.where((cc == "TZA") & (L.year == 2020), L.module, "")
    ## area of the household (prices and imputation); Malawi 2010 has no region: from the district code
    A = H[H.country == cc][["year", "hhid", "ea", "district", "region"]].copy()
    if cc == "MWI":
        dnum = pd.to_numeric(A.district, errors="coerce")
        A["region"] = np.where(A.region.isna() & dnum.notna(), (dnum // 100).astype("Int64").astype(str), A.region)
    for c in ["ea", "district", "region"]:
        A[c] = A[c].astype(str).where(A[c].notna(), None)
        A[c] = A.year.astype(str) + "#" + A[c].fillna("")
        A.loc[A[c].str.endswith("#"), c] = None
    L = L.merge(A, on=["year", "hhid"], how="left")
    L["nat"] = L.year.astype(str)
    L["label"] = [LAB.get((cc, y, s, int(k)), "") for y, s, k in zip(L.year, L["sample"], L.code)]
    home = L.category.isin(CATS); away_rows = L.category == "food_away"; excl = L.category == "excluded"
    QC["rows"].append(L.groupby("year").agg(consumed_rows=("code", "size")).assign(
        at_home=L[home].groupby("year").size(), food_away_items=L[away_rows].groupby("year").size(),
        excluded_items=L[excl].groupby("year").size(), no_category=L[L.category.isna()].groupby("year").size(),
        duplicated_hh_item=L.groupby(["year", "module", "hhid", "code"]).size().gt(1).groupby(level=0).sum()).reset_index().assign(country=cc))
    svy = np.array([(cc, y) in SVY for y in L.year])
    nga_mid = (cc == "NGA") & L.year.isin([2012, 2015]).to_numpy()
    nga_10 = (cc == "NGA") & (L.year == 2010).to_numpy()
    liquid_std = np.array([STD.get((cc, y, int(k)), "litre" if cat == "beverages" else "kg") == "litre" for y, k, cat in zip(L.year, L.code, L.category)])
    piece_std = np.array([STD.get((cc, y, int(k))) == "piece" for y, k in zip(L.year, L.code)]) & ~svy
    eggs = piece_std & (L.category == "eggs").to_numpy()
    ## standard unit -> reported quantity: kg; milk and liquid dairy litres x 1.03; eggs counted in pieces x 55 g; coconuts in pieces not converted
    dens = np.where(liquid_std & L.category.isin(PROTEIN).to_numpy(), 1.03, np.where(eggs, 0.055, np.where(piece_std, np.nan, 1.0)))
    dens = np.where(svy, 1.0, dens)                        # Nigeria 2018-2023: the file's kg factor, as in the protein dataset

    # ---------- units and quantities of each source ----------
    UT = ukey(L.u_tot, L.us_tot)
    if cc == "UGA":
        UP = UO = UG = UT
    else:
        UP = ukey(L.u_pur, L.us_pur); UO = ukey(L.u_own, L.us_own); UG = ukey(L.u_gift, L.us_gift)
    UO = [t if s else o for o, t, s in zip(UO, UT, svy)]; UG = [t if s else o for o, t, s in zip(UG, UT, svy)]
    UFP = ukey(L.u_frompur, [None] * len(L)) if cc == "NGA" else UP
    UFP = [t if s else f for f, t, s in zip(UFP, UT, svy)]
    L["uk_pur"], L["uk_own"], L["uk_gift"], L["uk_tot"], L["uk_fp"] = UP, UO, UG, UT, UFP
    ## consumption from purchases: Nigeria 2012-2023 asks it apart from the purchase itself
    L["qc_pur"] = np.where(svy | nga_mid, L.q_frompur, L.q_pur)
    L["kc_pur"] = np.where(svy, L.q_frompur * L.cvn_tot, np.where(nga_mid, L.s_frompur, L.s_pur))
    L["k_own"] = np.where(svy, L.q_own * L.cvn_tot, L.s_own); L["k_gift"] = np.where(svy, L.q_gift * L.cvn_tot, L.s_gift)
    ## the purchase that gives the price: quantity, unit, value, kg
    L["pp_q"] = np.where(svy, L.q_lastpur, L.q_pur)
    L["pp_v"] = np.where(svy, L.val_lastpur, L.exp)
    L["pp_u"] = [a if s else b for a, b, s in zip(ukey(L.u_lastpur, L.us_lastpur), UP, svy)]
    L["pp_k"] = np.where(svy, L.q_lastpur * L.cvn_lastpur, L.s_pur)
    lw = np.array([metric_w(ulabel(cc, y, u), lq) for y, u, lq in zip(L.year, L.pp_u, liquid_std)])
    L["pp_k"] = np.where(np.isnan(L.pp_k) & ~np.isnan(lw) & ~piece_std, L.pp_q * lw, L.pp_k)      # pieces: the price stays per piece

    # ---------- unit values of purchases (D1 b), outliers out (E2) ----------
    P = L[(L.pp_q > 0) & (L.pp_v > 0) & L.pp_u.notna()][["year", "code", "pp_u", "ea", "district", "region", "nat"]].copy()
    P["p"] = (L.pp_v / L.pp_q)[P.index]
    b = national_bounds(P, ["year", "code", "pp_u"], "p")
    P = P.merge(b, on=["year", "code", "pp_u"], how="left").set_index(P.index)
    P["out"] = (P.p > 10 * P._med) | (P.p < P._med / 10)
    L["price_outlier"] = False; L.loc[P.index[P.out.to_numpy()], "price_outlier"] = True
    Pk = P[~P.out].rename(columns={"pp_u": "uk"})
    K = L[(L.pp_k > 0) & (L.pp_v > 0)][["year", "code", "ea", "district", "region", "nat"]].copy()
    K["pk"] = (L.pp_v / L.pp_k)[K.index]
    bk = national_bounds(K, ["year", "code"], "pk")
    K = K.merge(bk, on=["year", "code"], how="left").set_index(K.index)
    K = K[~((K.pk > 10 * K._med) | (K.pk < K._med / 10))]

    def price_unit(ukcol):
        q = L[["year", "code", "ea", "district", "region", "nat"]].assign(uk=L[ukcol])
        return hier(Pk, ["year", "code", "uk"], "p", q)
    def price_kg():
        return hier(K, ["year", "code"], "pk", L[["year", "code", "ea", "district", "region", "nat"]])
    pkg, pkg_lev = price_kg()

    # ---------- value of each source ----------
    V = {}; M = {}          # value and how it was obtained
    def value_from_q(q, kg, ukcol, method_prefix=""):
        pu, lev = price_unit(ukcol)
        v = q * pu; how = pd.Series(np.where(~np.isnan(v), "unit value " + lev.fillna(""), None), index=L.index, dtype=object)
        k = np.isnan(v) & (q > 0) & ~np.isnan(kg * pkg) & (kg > 0)
        v = np.where(k, kg * pkg, v); how[k] = "price per kg " + pkg_lev[k].fillna("")
        return pd.Series(v, index=L.index), how
    # purchases
    vq, hq = value_from_q(L.qc_pur, L.kc_pur, "uk_fp")
    rep = L.exp.where(~svy & ~nga_mid)
    own_uv = np.where(nga_mid & (L.q_pur > 0) & (L.exp > 0) & (pd.Series(L.uk_fp) == pd.Series(L.uk_pur)).to_numpy() & ~L.price_outlier,
                      L.qc_pur * L.exp / L.q_pur, np.nan)
    vp = np.select([~svy & ~nga_mid & (rep > 0) & ~L.price_outlier, ~svy & ~nga_mid & (rep == 0), nga_mid & ~np.isnan(own_uv),
                    (svy | nga_mid) & (L.qc_pur == 0), (L.qc_pur > 0) & vq.notna(), nga_mid & L.qc_pur.isna() & (L.exp > 0),
                    (svy | nga_mid) & L.qc_pur.isna()],
                   [rep, 0.0, own_uv, 0.0, vq, L.exp, 0.0], np.nan)
    hp = np.select([~svy & ~nga_mid & (rep > 0) & ~L.price_outlier, ~svy & ~nga_mid & (rep == 0), nga_mid & ~np.isnan(own_uv),
                    (svy | nga_mid) & (L.qc_pur == 0), (L.qc_pur > 0) & vq.notna(), nga_mid & L.qc_pur.isna() & (L.exp > 0),
                    (svy | nga_mid) & L.qc_pur.isna()],
                   ["reported", "zero", "household's own unit value", "zero", "q x " + hq.fillna(""), "reported (no quantity from purchases)", "zero"], "missing")
    ## not bought: no purchase quantity and no amount paid (the other sources, or the "unknown source" case below, carry the item)
    nb = ~svy & ~nga_mid & np.isnan(vp) & (L.q_pur.isna() | (L.q_pur == 0)) & L.exp.isna()
    vp = np.where(nb, 0.0, vp); hp = np.where(nb, "zero", hp)
    ## reported purchase with an outlier unit value: re-valued at the area price (E2), else imputed
    ro = ~svy & ~nga_mid & (rep > 0) & L.price_outlier.to_numpy()
    vp = np.where(ro & vq.notna(), vq, vp); hp = np.where(ro & vq.notna(), "outlier unit value, q x " + hq.fillna(""), np.where(ro, "missing (outlier unit value)", hp))
    V["pur"] = pd.Series(vp, index=L.index); M["pur"] = pd.Series(hp, index=L.index)
    # own production and gifts
    for s, q, k, ukc, rv in [("own", L.q_own, L.k_own, "uk_own", L.val_own), ("gift", L.q_gift, L.k_gift, "uk_gift", L.val_gift)]:
        v, h = value_from_q(q, k, ukc)
        zero = q.isna() | (q == 0)
        if cc == "UGA":                       # reported value: used only when no price exists (D1: check, not source)
            ur = np.isnan(v) & (rv > 0)
            v = np.where(ur, rv, v); h[ur] = "reported value (no price)"
            zero = zero & ~(rv > 0)
        v = np.where(zero, 0.0, v); h[zero] = "zero"
        h[np.isnan(v) & ~zero] = "missing"
        V[s] = pd.Series(v, index=L.index); M[s] = h
    ## consumed, but no source has a quantity or a value: total value unknown
    unk = (V["pur"].fillna(0) == 0) & (V["own"].fillna(0) == 0) & (V["gift"].fillna(0) == 0) & \
          ~((M["pur"] == "missing") | (M["own"] == "missing") | (M["gift"] == "missing")) & \
          L[["q_tot", "q_pur", "q_own", "q_gift", "q_frompur", "exp", "q_away", "val_away", "val_own", "val_gift", "q_wt"]].fillna(0).le(0).all(axis=1)
    V["unk"] = pd.Series(np.where(unk, np.nan, 0.0), index=L.index); M["unk"] = pd.Series(np.where(unk, "missing", "zero"), index=L.index)

    # ---------- value outliers (E2) and imputation (E1) ----------
    for s in ["pur", "own", "gift"]:
        o = L[["year", "code"]].assign(v=V[s])
        b = national_bounds(o[o.v > 0], ["year", "code"], "v")
        m = o.merge(b, on=["year", "code"], how="left")["_med"].to_numpy()
        out = (V[s] > 100 * m).to_numpy()
        QC["outliers"].append(pd.DataFrame({"year": L.year[out], "source": s}).groupby(["year", "source"]).size().rename("n").reset_index().assign(country=cc, rule="value > 100 x national median of item and source"))
        V[s] = V[s].where(~out); M[s] = M[s].where(~out, "missing (value outlier)")
    QC["outliers"].append(L[L.price_outlier].groupby("year").size().rename("n").reset_index().assign(country=cc, source="purchase", rule="unit value outside 1/10-10 x national median of item and unit"))
    IMP = {}
    tot_known = (V["pur"].fillna(0) + V["own"].fillna(0) + V["gift"].fillna(0)).where(V["pur"].notna() & V["own"].notna() & V["gift"].notna())
    for s in ["pur", "own", "gift", "unk"]:
        need = V[s].isna()
        obs_v = tot_known if s == "unk" else V[s]
        obs = L[["year", "code", "ea", "district", "region", "nat"]].assign(v=obs_v)
        obs = obs[(obs.v > 0) & ~M[s].str.startswith("missing").fillna(False) if s != "unk" else (obs.v > 0)]
        iv, ilev = hier(obs, ["year", "code"], "v", L.loc[need, ["year", "code", "ea", "district", "region", "nat"]])
        IMP[s] = pd.Series(0.0, index=L.index); IMP[s].loc[iv.index] = iv.fillna(0).to_numpy()
        M[s].loc[iv.index] = np.where(iv.notna(), "imputed: median of area " + ilev.fillna(""), "not valued")
        V[s] = V[s].fillna(IMP[s])
    for s in V: V[s] = V[s].fillna(0.0)
    L["v_pur"], L["v_own"], L["v_gift"], L["v_unk"] = V["pur"], V["own"], V["gift"], V["unk"]
    L["v_imp"] = sum(IMP[s] for s in IMP)
    L["v_tot"] = L.v_pur + L.v_own + L.v_gift + L.v_unk
    for s in ["pur", "own", "gift", "unk"]:
        mm = M[s].fillna("missing").str.replace(r" (ea|district|region|nat)$", r" \1", regex=True)
        g = pd.DataFrame({"year": L.year, "home": home, "method": mm, "value": V[s]})
        g = g[g.home & (g.method != "zero")].groupby(["year", "method"]).agg(n=("value", "size"), value=("value", "sum")).reset_index()
        QC["valuation"].append(g.assign(country=cc, source=s))
    if cc == "UGA":                           # check: own and gift valued at purchase prices vs the values households reported
        for s, rv in [("own", L.val_own), ("gift", L.val_gift)]:
            ok = home & (rv > 0) & M[s].str.startswith("unit value").fillna(False)
            r = (L[f"v_{s}"] / rv)[ok]
            QC["check_uga"].append(pd.DataFrame({"year": L.year[ok], "r": r}).groupby("year").r.agg(
                n="size", median_ratio="median", p25=lambda x: x.quantile(.25), p75=lambda x: x.quantile(.75)).reset_index().assign(source=s, sum_valued=L[f"v_{s}"][ok].groupby(L.year[ok]).sum().values, sum_reported=rv[ok].groupby(L.year[ok]).sum().values))

    # ---------- quantities (F) ----------
    UGAQ = L[["q_pur", "q_own", "q_gift"]].fillna(0).sum(axis=1).where(L[["q_pur", "q_own", "q_gift"]].notna().any(axis=1))
    qbase = UGAQ if cc == "UGA" else L.q_tot
    kg = np.where(svy, L.q_tot * L.cvn_tot, L[["s_pur", "s_own", "s_gift"]].sum(axis=1, min_count=3) if cc == "UGA" else L.s_tot)
    kg = pd.Series(kg, index=L.index)
    how = pd.Series(np.where(kg.notna(), "survey conversion or metric unit", None), index=L.index, dtype=object)
    if cc == "TZA":                          # 2020: the survey's own weight of local units
        wf = L.u_wt.map(lambda u: {"1": 1.0, "2": 0.001, "3": 1.0, "4": 0.001}.get(ncode(u)))
        f = kg.isna() & L.q_wt.notna() & wf.notna()
        kg[f] = L.q_wt[f] * wf[f]; how[f] = "survey weight estimate (Tanzania 2020)"
    lt = np.array([metric_w(ulabel(cc, y, u), lq) for y, u, lq in zip(L.year, L.uk_tot, liquid_std)])
    f = kg.isna() & ~np.isnan(lt) & qbase.notna()
    kg[f] = qbase[f] * lt[f]; how[f] = "metric content stated in the unit label"
    direct_kg = f & piece_std                  # items counted in pieces but recorded in kg or g: already kilograms
    ## F2: kg per unit from prices, for the units nothing converts: median (paid / quantity) in the unit / median price per kg
    U = L[(L.pp_q > 0) & (L.pp_v > 0) & L.pp_u.notna() & L.pp_k.isna() & ~L.price_outlier][["year", "code", "pp_u"]].copy()
    U["lab"] = [ulabel(cc, y, u) for y, u in zip(U.year, U.pp_u)]
    U = U[~U.lab.map(is_other)]
    natk = K.groupby(["year", "code"]).pk.agg(["median", "size"]); natk = natk[natk["size"] >= NMIN]["median"].to_dict()
    U["w"] = [(v / q) / natk[(y, c)] if (y, c) in natk else np.nan for y, c, v, q in zip(U.year, U.code, L.pp_v[U.index], L.pp_q[U.index])]
    U = U.dropna(subset=["w"])
    U["plab"] = [f"{u.split('|')[0]}#{' '.join(sorted(re.findall(r'[a-z]+', str(l).lower())))}" for u, l in zip(U.pp_u, U.lab)]
    w1 = U.groupby(["year", "code", "pp_u"]).w.agg(["median", "size"]); w1 = w1[w1["size"] >= NMIN]
    w2 = U.groupby(["code", "plab"]).w.agg(["median", "size"]); w2 = w2[w2["size"] >= NMIN]
    for (y, c, u), r in w1.iterrows(): WEIGHTS.append(dict(country=cc, year=y, code=c, item=LAB.get((cc, y, "", int(c)), LAB.get((cc, y, "hh_sec_ja1", int(c)), "")), unit=u, unit_label=ulabel(cc, y, u), level="round, item", kg_per_unit=r["median"], purchases=int(r["size"])))
    for (c, p), r in w2.iterrows(): WEIGHTS.append(dict(country=cc, year=None, code=c, item="", unit=p, unit_label="", level="all rounds, item (same unit code and label)", kg_per_unit=r["median"], purchases=int(r["size"])))
    w1d = w1["median"].to_dict(); w2d = w2["median"].to_dict()
    need = kg.isna() & qbase.notna() & (qbase > 0) & L.uk_tot.notna()
    est = []
    for i, y, c, u in zip(L.index[need], L.year[need], L.code[need], L.uk_tot[need]):
        lab = ulabel(cc, y, u)
        if is_other(lab): est.append(np.nan); continue
        w = w1d.get((y, c, u))
        if w is None: w = w2d.get((c, f"{u.split('|')[0]}#{' '.join(sorted(re.findall(r'[a-z]+', str(lab).lower())))}"))
        est.append(np.nan if w is None else w)
    est = np.array(est, dtype=float)
    idx = L.index[need]
    kg.loc[idx] = qbase[idx] * est; how.loc[idx[~np.isnan(est)]] = "estimated from prices (F2)"
    kg = kg * np.where(direct_kg, 1.0, dens)
    how[kg.isna() & how.notna()] = None
    noq = L.category.isin(NOQTY) | ((L.category == "beverages") & (L.label.str.contains(DRY_BEV) & ~L.label.str.contains(PREPARED_TEA)))
    kg[noq] = np.nan; how[noq] = "no quantity for this category or item"
    L["qty"] = kg; L["qty_est"] = (how == "estimated from prices (F2)").astype(int)
    qq = pd.DataFrame({"year": L.year, "category": L.category, "how": how.fillna("not convertible")})[home]
    QC["quantity"].append(qq.groupby(["year", "category", "how"]).size().rename("rows").reset_index().assign(country=cc))

    # ---------- food away from home (value only) ----------
    fa_rows = L[away_rows]
    fv = (fa_rows.exp.fillna(0) + fa_rows.val_away.fillna(0) + fa_rows.val_own.fillna(0) + fa_rows.val_gift.fillna(0)) if cc == "UGA" else fa_rows.exp.fillna(0)
    fa_in = fa_rows.assign(fv=fv).groupby(["year", "hhid"]).fv.sum().rename("fa_items").reset_index() if len(fa_rows) else pd.DataFrame(columns=["year", "hhid", "fa_items"])
    QC["fafh"].append(fa_rows.groupby("year").agg(rows=("code", "size"), bought_no_value=("exp", lambda s: int(((s.isna()) & (fa_rows.loc[s.index, "q_pur"] > 0)).sum())),
                      own_or_gift_not_valued=("q_own", lambda s: int(((s > 0) | (fa_rows.loc[s.index, "q_gift"] > 0)).sum()) if cc != "UGA" else 0)).reset_index().assign(country=cc, source="items of the food module"))
    ua = L[home].groupby(["year", "hhid"]).val_away.sum(min_count=1).rename("fa_away_col").reset_index() if cc == "UGA" else pd.DataFrame(columns=["year", "hhid", "fa_away_col"])

    # ---------- household x category ----------
    athome = (L.v_tot > 0) | (L[["q_pur", "q_own", "q_gift", "q_frompur", "exp"]].fillna(0) > 0).any(axis=1) | ((cc != "UGA") & (L.q_tot.fillna(0) > 0))
    L = L[~(home & ~athome)] if cc == "UGA" else L
    home = L.category.isin(CATS)
    Lh = L[home].assign(qty_na=lambda d: d.qty.isna() & ~d.category.isin(NOQTY) & (d.v_tot > 0) & ~((d.category == "beverages") & d.label.str.contains(DRY_BEV) & ~d.label.str.contains(PREPARED_TEA)))
    g = Lh.groupby(["year", "hhid", "category"]).agg(value=("v_tot", "sum"), value_pur=("v_pur", "sum"), value_own=("v_own", "sum"),
            value_gift=("v_gift", "sum"), value_imp=("v_imp", "sum"), qty=("qty", "sum"), qty_na=("qty_na", "max"), qty_est=("qty_est", "max"),
            n_items=("code", "nunique"))
    g.loc[g.qty_na.astype(bool), "qty"] = np.nan          # one consumed item without a quantity: the category has no quantity
    g = g.drop(columns="qty_na")
    W = g.unstack("category")
    W.columns = [f"{c}_{v}" for v, c in W.columns]
    W = W.reset_index()
    Hc = H[H.country == cc].merge(W, on=["year", "hhid"], how="left")
    for c in CATS:
        for v in ["value", "value_pur", "value_own", "value_gift", "value_imp", "n_items", "qty_est"]:
            col = f"{c}_{v}"
            Hc[col] = Hc[col].fillna(0) if col in Hc else 0.0
        q = f"{c}_qty"
        if c in NOQTY: Hc[q] = np.nan
        else: Hc[q] = Hc[q].where(Hc[f"{c}_n_items"] > 0, 0.0) if q in Hc else 0.0
    Hc["food_home_value"] = Hc[[f"{c}_value" for c in CATS]].sum(axis=1)
    Hc["food_home_value_imp"] = Hc[[f"{c}_value_imp" for c in CATS]].sum(axis=1)
    for c in CATS: Hc[f"{c}_share"] = Hc[f"{c}_value"] / Hc.food_home_value.where(Hc.food_home_value > 0)
    for gname, cs in GROUPS.items():
        Hc[f"grp_{gname}_value"] = Hc[[f"{c}_value" for c in cs]].sum(axis=1)
        Hc[f"grp_{gname}_share"] = Hc[f"grp_{gname}_value"] / Hc.food_home_value.where(Hc.food_home_value > 0)
    ## food away: module (ETH, NGA, TZA) + items of the food module (MWI vendors, UGA restaurants) + UGA away-from-home column
    fm = FA[FA.country == cc][["year", "hhid", "fafh_module"]]
    for t in (fa_in, ua):
        t["year"] = t.year.astype(int); t["hhid"] = t.hhid.astype(str)
    Hc = Hc.merge(fm, on=["year", "hhid"], how="left").merge(fa_in, on=["year", "hhid"], how="left").merge(ua, on=["year", "hhid"], how="left")
    Hc["fa_items"] = pd.to_numeric(Hc.fa_items); Hc["fa_away_col"] = pd.to_numeric(Hc.fa_away_col)
    if cc in ("ETH", "NGA", "TZA"):
        cover = Hc.groupby("year").fafh_module.apply(lambda s: s.notna().mean())
        only_yes = Hc.year.map(cover) < 0.9                    # module listing only the meals eaten: absent = 0
        Hc["food_away_value"] = np.where(Hc.fafh_module.isna() & only_yes, 0.0, Hc.fafh_module)
        QC["fafh"].append(pd.DataFrame({"year": cover.index, "share_hh_in_module": cover.values}).assign(country=cc, source="food-away module"))
    elif cc == "MWI":
        Hc["food_away_value"] = Hc.fa_items.fillna(0.0)
    else:
        Hc["food_away_value"] = Hc.fa_items.fillna(0.0) + Hc.fa_away_col.fillna(0.0)
    ## outliers: above 100 x the round's median positive value -> missing (E2), not imputed (no price, value only)
    med = Hc[Hc.food_away_value > 0].groupby("year").food_away_value.median()
    fo = Hc.food_away_value > 100 * Hc.year.map(med)
    QC["outliers"].append(Hc[fo].groupby("year").size().rename("n").reset_index().assign(country=cc, source="food away", rule="above 100 x the round's median (set missing)"))
    Hc.loc[fo, "food_away_value"] = np.nan
    Hc["food_away_flag"] = np.where(fo, "outlier set missing", np.where(Hc.food_away_value.isna(), "not collected", ""))
    Hc = Hc.drop(columns=["fafh_module", "fa_items", "fa_away_col"])
    Hc["food_total_value"] = Hc.food_home_value + Hc.food_away_value
    Hc["food_away_share"] = Hc.food_away_value / Hc.food_total_value.where(Hc.food_total_value > 0)
    Hc["n_items"] = Hc[[f"{c}_n_items" for c in CATS]].sum(axis=1)
    Hc["price_source"] = np.where(Hc.year.isin([2018, 2023]) & (cc == "NGA"), "last purchase, 30 days (A2)", "purchases, 7 days")
    DATA.append(Hc)
    log(f"{cc}: {n_rows0} consumed rows, {home.sum()} at home, {away_rows.sum()} away items, {excl.sum()} excluded; {len(Hc)} households")

D = pd.concat(DATA, ignore_index=True)
## items the file has but no household reports, where the round before shows wide consumption (data problems, kept as they are)
ANOMALY = {("UGA", 2019): "sugar_sweets: sugar (code 147) reported by no household in the 2019 file (67% in 2018)",
           ("ETH", 2021): "beverages: tella (code 805) reported by no household in the 2021 file (9% in 2018)"}
## not_collected rebuilt from the item table: the categories with no item in the questionnaire of the round (any sample),
## e.g. Ethiopia has no pork item; the protein dataset's notes on its own columns (*_exp, *_kg_pur) do not apply here
## (an item counts when the file has rows for it; in the rounds that list only the items consumed, its value label is enough)
ONLY_CONS = {("NGA", 2010), ("UGA", 2010), ("UGA", 2011), ("UGA", 2013), ("UGA", 2015)}
inq = (CM.rows_in_file > 0) | pd.Series([(c, r) in ONLY_CONS for c, r in zip(CM.country, CM["round"])], index=CM.index)
HAS = CM[CM.category.isin(CATS) & inq].groupby(["country", "round"]).category.agg(set).to_dict()
NC = {k: ", ".join(f"{c}_*" for c in CATS if c not in v) for k, v in HAS.items()}
D["not_collected"] = [NC.get((c, y), "") for c, y in zip(D.country, D.year)]
for (c, y), t in ANOMALY.items():
    m = (D.country == c) & (D.year == y)
    D.loc[m, "not_collected"] = [t if not isinstance(v, str) or v == "" else f"{v}; {t}" for v in D.loc[m, "not_collected"]]
D["not_collected"] = D.not_collected.replace("", np.nan)
CCOLS = []
for c in CATS:
    CCOLS += [f"{c}_value", f"{c}_value_pur", f"{c}_value_own", f"{c}_value_gift", f"{c}_value_imp", f"{c}_qty", f"{c}_qty_est", f"{c}_n_items", f"{c}_share"]
TCOLS = ["food_home_value", "food_home_value_imp", "food_away_value", "food_away_flag", "food_total_value", "food_away_share", "n_items", "sample", "price_source"]
GCOLS = [f"grp_{g}_{v}" for g in GROUPS for v in ["value", "share"]]
COLS = HCOLS + ["sample", "price_source"] + TCOLS[:7] + CCOLS + GCOLS
D = D[COLS].copy()
for c in [f"{c}_n_items" for c in CATS] + [f"{c}_qty_est" for c in CATS] + ["n_items"]:
    D[c] = D[c].astype("Int64")
## categories the questionnaire of the round does not ask (not_collected, as in the protein dataset): empty, not zero
for t in D.not_collected.dropna().unique():
    m = D.not_collected == t
    for cat in re.findall(r"([a-z_]+)_\*", t):
        if cat in CATS:
            assert (D.loc[m, f"{cat}_value"].fillna(0) == 0).all(), (t, cat)
            D.loc[m, [f"{cat}_{v}" for v in ["value", "value_pur", "value_own", "value_gift", "value_imp", "qty", "qty_est", "n_items", "share"]]] = pd.NA
D.to_csv(os.path.join(OUTD, f"_allfood_wide_{TODAY}.csv.gz"), index=False)
pd.to_pickle({k: v for k, v in QC.items()}, os.path.join(OUTD, f"_qc_{TODAY}.pkl"))
pd.DataFrame(WEIGHTS).to_csv(os.path.join(OUTD, f"_unit_weights_{TODAY}.csv"), index=False)
log(f"done: {len(D)} rows x {len(D.columns)} columns")
