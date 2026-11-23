#!/usr/bin/env python3
"""
HOUSEHOLD FOOD DATASET, WIDE: one row per household x round, never repeated (v1, 23 Nov 2026).

Columns decided with Paolo (23 Nov 2026, item by item):
  household: country, year, hhid, panel_id, weight, region, district, subdistrict, ea, strata, rural, hhsize, adulteq,
             int_month, int_year, head_female, head_age, welfare_annual, welfare_scale, welfare_var,
             cons_total_hh_annual, food_cons_hh_annual, not_collected
  18 food items x 7 columns: <item>_cons, _kg_tot, _kg_pur (consumed from purchases), _kg_own, _kg_gift, _exp (7 days), _kg_est
  no quintile, no protein, no group totals, no Nigeria 30-day purchase, no Uganda away-from-home quantity or values,
  no prepared food, butter-margarine, coconut, kola, insects, snails, "other (specify)" residuals.
Ethiopia 2011 and 2013 left out (one item for all meat). Items: the original items of item_classification.csv summed into 18 items (wide_items.csv): goat + sheep + goat-and-mutton,
  chicken + other poultry, fresh milk vs all processed dairy, fish fresh / processed / form not given, etc.
Units that the survey tables do not convert (heaps, pieces, cups, plates...): kilograms ESTIMATED from prices
  (Paolo: "stima con un peso questi pezzi o heap"): kg per unit = median over purchases in that unit of
  (amount paid / quantity) / price per kg of the same item, country and round (median over purchases in kg).
  Estimated kilograms are marked in <item>_kg_est = 1; the weights are in the sheet Unit_weights.
Outputs: one workbook with all countries and one per country, same columns in the same order.

usage: build_wide_food_dataset.py <build dir> <food_items_long.csv.gz> <households.csv.gz> <item_classification.csv>
                                  <wide_items.csv> <item_map.csv> <nga_head.csv> <out dir>
"""
import sys, os, re, math, time, datetime
import numpy as np, pandas as pd, xlsxwriter

BUILD, LONGF, HHF, CLASSF, WIDEF, MAPF, NGAHEAD, OUTD = sys.argv[1:9]
os.makedirs(OUTD, exist_ok=True)
T0 = time.time(); TODAY = datetime.date.today().isoformat()
COUNTRIES = ["ETH", "TZA", "MWI", "NGA", "UGA"]
SVY = {("NGA", 2018), ("NGA", 2023)}
NMIN = 5                                    # observations needed for a median price or weight
DROP = {("ETH", 2011), ("ETH", 2013)}       # Paolo, 23 Nov: out, their questionnaire has one item for all meat (no beef, poultry, fish)
ITEMS = ["beef", "goat_sheep", "pork", "processed_red_meat", "meat_other", "poultry", "eggs", "milk_fresh",
         "dairy_processed", "fish_fresh", "fish_processed", "pulses_dry", "pulses_fresh", "groundnuts", "soy", "nuts", "seeds"]
VARS = ["cons", "kg_tot", "kg_pur", "kg_own", "kg_gift", "exp", "kg_est"]
HCOLS = ["country", "year", "hhid", "panel_id", "weight", "region", "district", "subdistrict", "ea", "strata", "rural", "hhsize", "adulteq",
         "int_month", "int_year", "head_female", "head_age", "welfare_annual", "welfare_scale", "welfare_var",
         "cons_total_hh_annual", "food_cons_hh_annual", "not_collected"]
COLS = HCOLS + [f"{i}_{v}" for i in ITEMS for v in VARS]
TEXT = {"country", "hhid", "panel_id", "region", "district", "subdistrict", "ea", "strata", "welfare_scale", "welfare_var", "not_collected"}
def log(m): print(f"{m} ({time.time() - T0:.0f}s)", flush=True)

CL = pd.read_csv(CLASSF)
WI = pd.read_csv(WIDEF)
assert set(WI.wide_item) == set(ITEMS)
D2I = CL.set_index("item_detail")["item"].to_dict()                       # detail -> harmonized item
I2W = WI[~WI["item"].str.startswith("detail:")].set_index("item")["wide_item"].to_dict()      # harmonized item -> column item
DOV = {r["item"][7:]: r["wide_item"] for _, r in WI[WI["item"].str.startswith("detail:")].iterrows()}   # exceptions by original item
D2W = {d: DOV.get(d, I2W.get(i)) for d, i in D2I.items()}
KEEP = {d for d, w in D2W.items() if w}
MAP = pd.read_csv(MAPF); MAP["round"] = MAP.year.apply(lambda y: int(math.floor(y)))
UC = pd.read_csv(os.path.join(BUILD, "unit_codes.csv"), dtype=str, keep_default_na=False, na_values=[""]); UC["year"] = UC.year.astype(int)
def ncode(x):
    return None if not isinstance(x, str) or x.strip() == "" else x.strip().removesuffix(".0")
ULAB = {}
for c, y, code, lab in UC[["country", "year", "code", "label"]].itertuples(index=False):
    k = (c, y, ncode(code))
    if isinstance(lab, str) and lab.strip() and k not in ULAB:
        ULAB[k] = lab.strip()
def label_of(cc, y, u):
    """label of a unit code; Malawi 2010 (no labels in the file) and 2024 (labels = codes): the 2019/2016 code list"""
    if u is None:
        return None
    code = u.split("|")[0]; lab = ULAB.get((cc, y, code))
    if cc == "MWI" and (lab is None or lab.strip() in (code, re.sub(r"[A-Z]$", "", code))):
        lab = ULAB.get(("MWI", 2019, code)) or ULAB.get(("MWI", 2016, code))
    return lab
def metric_w(lab, dens, stated=True):
    """kg per unit when the unit is metric or (stated=True) its label states the weight, e.g. 'PACKET (150G)', 'TIN 1KG'.
    Litres and millilitres only for liquids (dens = 1.03 for milk, yoghurt, soured milk; None for solids: a volume of beans is not a weight)."""
    if not isinstance(lab, str):
        return np.nan
    l = re.sub(r"^\d+\.\s*", "", lab.strip().lower())
    if re.search(r"up to|\bto\s*\d|above|between|\d\s*-\s*\d", l):
        return np.nan
    if re.fullmatch(r"(kilo(gram(me)?)?s?|kgs?)(\s*\(kgs?\))?", l):
        return 1.0
    if re.fullmatch(r"(grams?|grammes?|gms?)", l):
        return 0.001
    if re.fullmatch(r"(litres?|liters?|ltrs?)", l):
        return dens if dens else np.nan
    if re.fullmatch(r"(millilitres?|milliliters?|mls?)", l):
        return 0.001 * dens if dens else np.nan
    if not stated:
        return np.nan
    m = re.search(r"(\d+(?:\.\d+)?)\s*(kgs?|kilograms?|grams?|gms?|g)\b", l)
    if m:
        v = float(m.group(1)); return v if m.group(2).startswith("k") else v / 1000
    return np.nan
STDU = MAP.drop_duplicates(["country", "slot"]).set_index(["country", "slot"])["std"].to_dict()
def dens(cc, d):
    return 1.03 if STDU.get((cc, d)) == "litre" else None
STATED = {"MWI", "UGA"}     # unit labels with the weight in them (MWI 'PACKET (150G)'); Nigeria 2010 labels belong to the crop unit list, not used
def plabel(lab, u):
    """key to pool a unit across rounds: same code and same words in the label (e.g. 'Whole fish(medium)' = 'Fish  Whole (medium)')"""
    return f"{u}#{' '.join(sorted(re.findall(r'[a-z]+', lab.lower())))}" if isinstance(lab, str) and u is not None else None
def is_other(lab):
    l = lab.strip().lower() if isinstance(lab, str) else ""
    return "specify" in l or l.startswith("other") or "900. other" in l or l in ("other", "others")

# ------------------------------------------------------------------------------------------
# 1. item rows of the long dataset (already converted kilograms) + raw quantities and units
# ------------------------------------------------------------------------------------------
LC = ["country", "year", "hhid", "item_detail", "consumption_status", "consumed", "qty_total_kg", "qty_from_purchases_kg", "qty_purchased_kg",
      "qty_own_kg", "qty_gift_kg", "qty_away_kg", "exp_purchases", "not_collected"]
LONG = pd.read_csv(LONGF, usecols=LC, dtype={"hhid": str, "country": "category", "item_detail": "category", "consumption_status": "category",
                                             "not_collected": "category"}, low_memory=False)
LONG = LONG[LONG.item_detail.isin(KEEP) & ~pd.Series(list(zip(LONG.country.astype(str), LONG.year)), index=LONG.index).isin(DROP)].copy()
LONG["item_detail"] = LONG.item_detail.astype(str); LONG["wide"] = LONG.item_detail.map(D2W)
log(f"long rows of the {len(ITEMS)} items: {len(LONG)}")
RAWC = ["hhid", "year", "slot", "cons", "q_tot", "u_tot", "us_tot", "q_pur", "u_pur", "us_pur", "q_own", "u_own", "us_own", "q_gift", "u_gift", "us_gift",
        "q_frompur", "u_frompur", "q_away", "exp", "q_lastpur", "u_lastpur", "us_lastpur", "val_lastpur", "cvn_lastpur"]
UNITC = [c for c in RAWC if c.startswith("u")]
SRC = {"tot": "qty_total_kg", "pur": "qty_from_purchases_kg", "own": "qty_own_kg", "gift": "qty_gift_kg", "away": "qty_away_kg"}

WT_ROWS = []; OUT = []; EST_STATS = []
for cc in COUNTRIES:
    parts = []
    for ch in pd.read_csv(os.path.join(BUILD, f"long_{cc}.csv.gz"), usecols=lambda c: c in RAWC, dtype={c: str for c in ["hhid", "slot"] + UNITC},
                          keep_default_na=False, na_values=[""], low_memory=False, chunksize=500_000):
        ch = ch[(pd.to_numeric(ch.cons, errors="coerce") == 1) & ch.slot.isin(KEEP)]
        parts.append(ch)
    R = pd.concat(parts)
    for c in RAWC:
        if c not in R:
            R[c] = np.nan
    R["year"] = R.year.astype(float).astype(int)
    for c in UNITC:
        R[c] = R[c].map(ncode)
    L = LONG[(LONG.country == cc) & (LONG.consumption_status == "consumed")].copy()
    L = L.merge(R.rename(columns={"slot": "item_detail"}).drop(columns="cons"), on=["year", "hhid", "item_detail"], how="left", validate="1:1")
    L["item"] = L.item_detail.map(D2I)
    svy = np.array([(cc, y) in SVY for y in L.year])
    nga_early = (cc == "NGA") & ~svy
    def ukey(u, us):
        return [None if a is None else f"{a}|{b or ''}" for a, b in zip(u, us)]
    # unit of each source (Uganda: one unit for all sources; Nigeria 2018-2023: the unit of the total)
    UT = ukey(L.u_tot, L.us_tot)
    def src_unit(u, us):
        k = ukey(L[u], L[us]) if us else ukey(L[u], [None] * len(L))
        if cc == "UGA":
            k = [a or b for a, b in zip(k, UT)]
        return [t if s else a for a, t, s in zip(k, UT, svy)]
    SQ = {"tot": (L.q_tot, UT),
          "pur": (np.where(svy | (cc == "NGA"), L.q_frompur, L.q_pur), src_unit("u_frompur", None) if cc == "NGA" else src_unit("u_pur", "us_pur")),
          "own": (L.q_own, src_unit("u_own", "us_own")), "gift": (L.q_gift, src_unit("u_gift", "us_gift")),
          "away": (L.q_away, UT if cc == "UGA" else [None] * len(L))}
    if cc == "NGA":      # 2010: no question on consumption from purchases
        SQ["pur"] = (np.where(L.year == 2010, np.nan, SQ["pur"][0]), SQ["pur"][1])
    # purchases: quantity, unit, amount paid, kilograms when the unit converts
    pq = np.where(svy, L.q_lastpur, L.q_pur); pv = np.where(svy, L.val_lastpur, L.exp)
    pk = np.where(svy, L.q_lastpur * L.cvn_lastpur, np.where(nga_early, L.qty_purchased_kg, L.qty_from_purchases_kg))
    pu = [a if s else t for a, t, s in zip(ukey(L.u_lastpur, L.us_lastpur), src_unit("u_pur", "us_pur"), svy)]
    lw = np.array([metric_w(label_of(cc, y, u), dens(cc, d), cc in STATED) for y, u, d in zip(L.year, pu, L.item_detail)])
    pk = np.where(np.isnan(pk) & ~np.isnan(lw), pq * lw, pk)
    P = pd.DataFrame({"year": L.year, "item_detail": L.item_detail, "item": L.item, "wide": L.wide, "q": pq, "v": pv, "kg": pk, "unit": pu})
    P = P[(P.q > 0) & (P.v > 0)]
    K = P[P.kg > 0].assign(ppk=lambda d: d.v / d.kg)
    ppk = {}
    for lev, keys in [("item_detail", ["year", "item_detail"]), ("item", ["year", "item"]), ("wide", ["year", "wide"])]:
        g = K.groupby(keys).ppk.agg(["median", "size"])
        ppk[lev] = g[g["size"] >= NMIN]["median"].to_dict()
    U = P[P.kg.isna() & P.unit.notna()].copy()
    U["lab"] = [label_of(cc, y, u) for y, u in zip(U.year, U.unit)]
    U = U[~U.lab.map(is_other)]
    def find_ppk(y, d, i, w):
        for lev, k in [("item_detail", (y, d)), ("item", (y, i)), ("wide", (y, w))]:
            if k in ppk[lev]:
                return ppk[lev][k], lev
        return np.nan, None
    pp = [find_ppk(y, d, i, w) for y, d, i, w in zip(U.year, U.item_detail, U["item"], U.wide)]
    U["ppk"] = [a for a, b in pp]; U["ppk_level"] = [b for a, b in pp]
    U = U[U.ppk.notna()]
    U["w"] = (U.v / U.q) / U.ppk
    U["plab"] = [plabel(l, u) for l, u in zip(U.lab, U.unit)]       # pooled across rounds only with the same code and label
    WT = {}
    for lev, keys in [("round, item", ["year", "item_detail", "unit"]), ("round, items of the same product", ["year", "item", "unit"]),
                      ("all rounds, item", ["item_detail", "plab"]), ("all rounds, items of the same product", ["item", "plab"]),
                      ("all rounds, items of the same column", ["wide", "plab"])]:
        g = U.dropna(subset=[keys[-1]]).groupby(keys).agg(w=("w", "median"), n=("w", "size"), ppk_level=("ppk_level", lambda s: s.mode().iloc[0]))
        g = g[g.n >= NMIN]
        WT[lev] = g
    WD = {lev: {k: (r.w, int(r.n)) for k, r in g.iterrows()} for lev, g in WT.items()}
    def weight(y, d, i, u):
        if u is None:
            return np.nan, None, 0
        lab = label_of(cc, y, u)
        mw = metric_w(lab, dens(cc, d), cc in STATED)
        if mw == mw:
            return mw, "metric unit or weight stated in the unit label", 0
        if is_other(lab):
            return np.nan, None, 0
        pl = plabel(lab, u)
        for lev, k in [("round, item", (y, d, u)), ("round, items of the same product", (y, i, u)), ("all rounds, item", (d, pl)),
                       ("all rounds, items of the same product", (i, pl)), ("all rounds, items of the same column", (D2W[d], pl))]:
            if k[-1] is not None and k in WD[lev]:
                return WD[lev][k][0], lev, WD[lev][k][1]
        return np.nan, None, 0
    # fill the kilograms that the conversion tables leave empty
    L = L.reset_index(drop=True)
    years = L.year.to_numpy(); dets = L.item_detail.to_numpy(); its = L["item"].to_numpy()
    est = np.zeros(len(L), dtype=bool); used = {}; cache = {}
    for s_, (q, units) in SQ.items():
        col = SRC[s_]
        qv = np.asarray(q, dtype=float)
        if s_ == "tot" and cc == "UGA":
            qv = np.where(years >= 2018, np.nan, qv)          # Uganda 2018-2019: no total question
        cur = L[col].to_numpy(dtype=float).copy()
        for p in np.where(np.isnan(cur) & (qv > 0))[0]:
            key = (years[p], dets[p], its[p], units[p])
            if key not in cache:
                cache[key] = weight(*key)
            w, lev, n = cache[key]
            if w == w:
                cur[p] = qv[p] * w; used[(years[p], dets[p], units[p], lev)] = (w, n)
                if lev != "metric unit or weight stated in the unit label":
                    est[p] = True
        L[col] = cur
    if cc == "UGA":      # 2018-2019: total = sum of the sources (purchases at home, away, own, gifts), as in the long dataset
        late = (L.year >= 2018) & L.qty_total_kg.isna()
        parts_q = L[["q_pur", "q_away", "q_own", "q_gift"]]; parts_k = L[["qty_from_purchases_kg", "qty_away_kg", "qty_own_kg", "qty_gift_kg"]].to_numpy()
        ok = late & ~((parts_q.to_numpy() > 0) & np.isnan(parts_k)).any(axis=1) & (parts_q.fillna(0).to_numpy() > 0).any(axis=1)
        L.loc[ok, "qty_total_kg"] = np.nansum(np.where(parts_q.fillna(0).to_numpy() > 0, parts_k, 0.0)[ok.to_numpy()], axis=1)
    L["est"] = est.astype(float)
    for (y, d, u, lev), (w, n) in used.items():
        WT_ROWS.append(dict(country=cc, year=int(y), item_detail=d, item=D2W[d], unit_code=u.replace("|", " ").strip(), unit_label=label_of(cc, y, u),
                            kg_per_unit=round(float(w), 4), method="label" if lev.startswith("metric") else "price", source=lev, n_purchases=n if n else None))
    before = int((LONG[(LONG.country == cc) & (LONG.consumption_status == "consumed")].qty_total_kg.notna()).sum())
    EST_STATS.append(dict(country=cc, consumed_items=len(L), kg_before=before, kg_after=int(L.qty_total_kg.notna().sum()), rows_estimated=int(est.sum())))
    OUT.append(L[["year", "hhid", "item_detail", "qty_total_kg", "qty_from_purchases_kg", "qty_own_kg", "qty_gift_kg", "est"]].assign(country=cc))
    log(f"  {cc}: consumed item rows {len(L)}, kg {before} -> {int(L.qty_total_kg.notna().sum())}, estimated {int(est.sum())}")
    del R, L, P, K, U

FILLED = pd.concat(OUT)
LONG = LONG.merge(FILLED, on=["country", "year", "hhid", "item_detail"], how="left", suffixes=("", "_f"))
for c in ["qty_total_kg", "qty_from_purchases_kg", "qty_own_kg", "qty_gift_kg"]:
    LONG[c] = np.where(LONG.consumption_status == "consumed", LONG[c + "_f"], LONG[c])
LONG["est"] = np.where(LONG.consumption_status == "consumed", LONG.est, 0.0)
LONG = LONG.drop(columns=[c for c in LONG.columns if c.endswith("_f")])
log("estimation done")

# ------------------------------------------------------------------------------------------
# 2. household x item: strict sums (empty if any item of the column is unknown), then wide
# ------------------------------------------------------------------------------------------
LONG["country"] = LONG.country.astype(str)
VALS = {"kg_tot": "qty_total_kg", "kg_pur": "qty_from_purchases_kg", "kg_own": "qty_own_kg", "kg_gift": "qty_gift_kg", "exp": "exp_purchases"}
LONG["c_na"] = LONG.consumed.isna()
for v, col in VALS.items():
    LONG[v + "_na"] = LONG[col].isna()
A = LONG.groupby(["country", "year", "hhid", "wide"], sort=False).agg(
    cons=("consumed", "max"), c_na=("c_na", "any"), kg_est=("est", "max"),
    **{v: (col, "sum") for v, col in VALS.items()}, **{v + "_na": (v + "_na", "sum") for v in VALS}).reset_index()
A.loc[A.c_na & (A.cons != 1), "cons"] = np.nan
for v in VALS:
    A.loc[A[v + "_na"] > 0, v] = np.nan          # strict: one unknown original item makes the column unknown
A = A.drop(columns=["c_na"] + [v + "_na" for v in VALS])
for v in ["kg_tot", "kg_pur", "kg_own", "kg_gift"]:
    A[v] = A[v].round(4)
A["exp"] = A["exp"].round(2)
W = A.pivot(index=["country", "year", "hhid"], columns="wide", values=VARS)
W.columns = [f"{i}_{v}" for v, i in W.columns]
W = W.reset_index()
log(f"wide: {len(W)} households")

# not collected in the round: items absent from the questionnaire, variables not asked
NCV = {"qty_from_purchases_kg": "kg_pur", "exp_purchases": "exp", "qty_own_kg": "kg_own", "qty_gift_kg": "kg_gift"}
NC = {}
asked = LONG.groupby(["country", "year"]).wide.apply(set).to_dict()
ncl = LONG.drop_duplicates(["country", "year"]).set_index(["country", "year"]).not_collected.to_dict()
for (c, y), s in asked.items():
    miss = [f"{i}_*" for i in ITEMS if i not in s]
    v = [f"*_{NCV[x.strip()]}" for x in str(ncl.get((c, y)) or "").split(",") if x.strip() in NCV]
    v += ["*_exp"] * ((c, y) in SVY) + ["*_kg_pur"] * ((c, y) == ("NGA", 2010))
    NC[(c, y)] = ", ".join(dict.fromkeys(miss + v))

# ------------------------------------------------------------------------------------------
# 3. household variables
# ------------------------------------------------------------------------------------------
H = pd.read_csv(HHF, dtype={"hhid": str, "panel_id": str, "region": str, "district": str, "subdistrict": str, "ea": str, "strata": str}, low_memory=False)
H = H[~pd.Series(list(zip(H.country, H.year)), index=H.index).isin(DROP)].copy()
NH = pd.read_csv(NGAHEAD, dtype={"hhid": str})
H = H.merge(NH[["country", "year", "hhid", "head_female", "head_age"]], on=["country", "year", "hhid"], how="left", suffixes=("", "_nga"))
for c in ["head_female", "head_age"]:
    H[c] = np.where(H.country == "NGA", H[c + "_nga"], H[c])
H["welfare_var"] = H.welfare_formula
for c in ["welfare_annual", "cons_total_hh_annual", "food_cons_hh_annual"]:
    H[c] = H[c].round(2)
H["not_collected"] = [NC.get((c, y)) for c, y in zip(H.country, H.year)]
X = H[[c for c in HCOLS]].merge(W, on=["country", "year", "hhid"], how="left", validate="1:1")
for c in COLS:
    if c not in X:
        X[c] = np.nan
X = X[COLS].sort_values(["country", "year", "hhid"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s).reset_index(drop=True)
assert not X.duplicated(["country", "year", "hhid"]).any()
assert len(X) == len(H)
log(f"dataset: {X.shape}")

# ------------------------------------------------------------------------------------------
# 4. documentation sheets (the same in every workbook; Items and Unit_weights by country)
# ------------------------------------------------------------------------------------------
RV = pd.read_csv(os.path.join(BUILD, "role_vars.csv")); RV = RV[RV.exists].copy(); RV["year"] = RV.year.astype(int)
HS = pd.read_csv(os.path.join(BUILD, "hh_raw_sources.csv"), keep_default_na=False, na_values=[""])
ROUNDS = sorted({(c, int(y)) for c, y in zip(H.country, H.year)}, key=lambda r: (COUNTRIES.index(r[0]), r[1]))
ROLES = {"cons": lambda c, y: ["cons_raw"],
         "kg_tot": lambda c, y: (["q_tot", "u_tot"] + (["cvn_tot"] if (c, y) in SVY else []) + (["q_wt", "u_wt"] if (c, y) == ("TZA", 2020) else []))
                                if not (c == "UGA" and y >= 2018) else ["u_tot", "q_pur", "q_away", "q_own", "q_gift"],
         "kg_pur": lambda c, y: [] if (c, y) == ("NGA", 2010) else (["q_frompur", "u_frompur"] if c == "NGA" else ["q_pur", "u_pur"]),
         "kg_own": lambda c, y: ["q_own", "u_own"], "kg_gift": lambda c, y: ["q_gift", "u_gift"],
         "exp": lambda c, y: [] if (c, y) in SVY else ["exp_pur"]}
def orig(v, c, y):
    r = RV[(RV.country == c) & (RV.year == y) & RV.role.isin(ROLES[v](c, y))]
    return ", ".join(dict.fromkeys(r.variable)) if len(r) else "not collected"
IDEF = {"cons": ("1 if the household consumed the item in the last 7 days, 0 if not", "0/1",
                 "1 if any original item of the column was consumed; 0 if none; empty if an original item has no answer"),
        "kg_tot": ("Quantity consumed in total, last 7 days", "kg", "sum of the original items of the column; empty if one of them has no quantity in kg"),
        "kg_pur": ("Quantity consumed that came from purchases, last 7 days", "kg", "as kg_tot. Uganda: purchases consumed at home"),
        "kg_own": ("Quantity consumed from own production, last 7 days", "kg", "as kg_tot"),
        "kg_gift": ("Quantity consumed from gifts and other sources, last 7 days", "kg", "as kg_tot"),
        "exp": ("Amount paid for the purchases, last 7 days", "local currency", "sum over the original items; Nigeria 2010-2015: amount paid for the quantity purchased (question on purchases, not on consumption)"),
        "kg_est": ("1 if some kilograms of the column come from a weight estimated from prices (sheet Unit_weights)", "0/1", "")}
HDEF = {
 "country": ("ISO3 country code", "text", ""), "year": ("First year of fieldwork of the round", "year", ""),
 "hhid": ("Household id of the round, as in the food module", "text", "with country and year: unique"),
 "panel_id": ("Same household across rounds", "text", "survey tracking ids (Step I); Nigeria 2018-2023: hhid; Malawi: not built"),
 "weight": ("Household sampling weight", "weight", "original"), "region": ("Region", "code", "original code"), "district": ("District / zone / state", "code", "original code"),
 "subdistrict": ("Woreda (ETH), LGA (NGA), subcounty (UGA)", "code", "original code"), "ea": ("Enumeration area", "code", "original code"),
 "strata": ("Sampling stratum", "code", "original code"), "rural": ("1 rural, 0 urban", "0/1", "recode of the original urban/rural code with its value labels"),
 "hhsize": ("Household size", "persons", "aggregate or cover file; Malawi 2010 and Uganda 2011: count of the roster"),
 "adulteq": ("Adult equivalents of the official aggregate", "adult equivalents", "original; not in the files of Malawi 2010 and 2024 and of Nigeria"),
 "int_month": ("Month of the interview", "month", "original; not taken for Ethiopia (Ethiopian calendar), Nigeria, Malawi 2010, Tanzania 2012"), "int_year": ("Year of the interview", "year", "as int_month"),
 "head_female": ("1 if the household head is a woman", "0/1", "roster: sex of the member with relationship = head"),
 "head_age": ("Age of the household head", "years", "roster"),

 "welfare_annual": ("Official consumption aggregate per adult equivalent (ETH, TZA, UGA) or per person (MWI, NGA), annual", "local currency per year",
                    "official variable; brought to one year and to one person when the file has another period or the household total (see welfare_var); equal to the Step I welfare"),
 "welfare_scale": ("per adult equivalent or per person", "text", ""), "welfare_var": ("Original variable and formula of welfare_annual", "text", ""),
 "cons_total_hh_annual": ("Total consumption of the household, annual", "local currency per year", "official aggregate; Uganda x 12 (monthly); Nigeria not available"),
 "food_cons_hh_annual": ("Food consumption of the household, annual", "local currency per year", "official aggregate; not available as one variable in Nigeria, Tanzania 2020, Uganda 2010-2015 and 2019"),
 "not_collected": ("Columns that the round does not ask: their cells are empty for every household of the round", "text", "item_* = item not in the questionnaire; *_var = question not asked"),
}
DD = []
for v in HCOLS:
    d, u, h = HDEF[v]
    src = HS[HS.column == ("urban_rural" if v == "rural" else v)]
    by = "; ".join(f"{c} {int(y)}: {x}" for c, y, x in src[["country", "year", "variable"]].itertuples(index=False))
    if v in ("welfare_annual", "cons_total_hh_annual", "food_cons_hh_annual"):
        f = {"welfare_annual": "welfare_formula", "cons_total_hh_annual": "cons_total_hh_var", "food_cons_hh_annual": "food_cons_hh_var"}[v]
        by = "; ".join(f"{c} {int(y)}: {x}" for (c, y), x in H.groupby(["country", "year"], sort=False)[f].first().items() if isinstance(x, str))
    if v in ("head_female", "head_age"):
        by = "ETH, TZA, MWI, UGA: household roster (relationship to head, sex, age), as in Step I; NGA: sect1_harvestw1-w5 (s1q3 = 1 head; s1q2 sex; age s1q4, 2023 s1q6)"
    DD.append(dict(column=v, definition=d, unit=u, how=h, original_variables_by_round=by))
for v in VARS:
    d, u, h = IDEF[v]
    DD.append(dict(column=f"<item>_{v}", definition=d, unit=u, how=h,
                   original_variables_by_round="" if v == "kg_est" else "; ".join(f"{c} {y}: {orig(v, c, y)}" for c, y in ROUNDS)))
DD = pd.DataFrame(DD)
IT = WI.groupby("wide_item").apply(lambda d: "; ".join(f"{i}" + (f" ({n})" if isinstance(n, str) else "") for i, n in zip(d["item"], d.note)), include_groups=False)
IDOC = pd.DataFrame([dict(column=f"{i}_*", contains=IT[i]) for i in ITEMS])
MP = MAP.merge(CL[["item_detail", "item"]], left_on="slot", right_on="item_detail", how="left")
MP["column"] = MP["item_detail"].map(D2W).fillna("dropped")
MP = MP[~pd.Series(list(zip(MP.country, MP["round"])), index=MP.index).isin(DROP)]
MP = MP[["country", "round", "code", "label", "item_detail", "item", "column"]].rename(columns={"round": "year", "code": "item_code_orig", "label": "item_label_orig"})
MP = MP.sort_values(["country", "year", "column", "item_detail"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s)
WTS = pd.DataFrame(WT_ROWS).sort_values(["country", "year", "item", "item_detail", "unit_code"], key=lambda s: s.map(COUNTRIES.index) if s.name == "country" else s)
ES = pd.DataFrame(EST_STATS)
COV = []
for (c, y), d in X.groupby(["country", "year"], sort=False):
    for i in ITEMS:
        cons = d[f"{i}_cons"] == 1
        if d[f"{i}_cons"].notna().any():
            COV.append(dict(country=c, year=y, item=i, households_consuming=int(cons.sum()), with_kg_tot=int((cons & d[f"{i}_kg_tot"].notna()).sum()),
                            with_estimated_kg=int((cons & (d[f"{i}_kg_est"] == 1)).sum()), with_exp=int((cons & d[f"{i}_exp"].notna()).sum())))
COV = pd.DataFrame(COV)
COV["share_with_kg"] = (COV.with_kg_tot / COV.households_consuming.replace(0, np.nan)).round(3)
SUMM = pd.DataFrame([("rows", len(X), "households x rounds"), ("duplicated country-year-hhid", int(X.duplicated(["country", "year", "hhid"]).sum()), ""),
                     ("columns", len(COLS), f"{len(HCOLS)} household + {len(ITEMS)} items x {len(VARS)}"),
                     ("consumed item rows with kg before the estimated weights", int(ES.kg_before.sum()), f"of {int(ES.consumed_items.sum())} (all original items of the {len(ITEMS)} columns)"),
                     ("consumed item rows with kg after the estimated weights", int(ES.kg_after.sum()), ""),
                     ("estimated unit weights", len(WTS), "sheet Unit_weights")], columns=["check", "value", "note"])
README = pd.DataFrame([
    ("Data", "one row per household x round (never repeated); the same columns in the same order in every workbook"),
    ("rule", "0 = not consumed / source not used; empty = missing; empty for a whole round = not collected (column not_collected)"),
    ("rounds", "23 rounds: Ethiopia 2011 and 2013 are left out because their questionnaire has a single item for all meat"),
    ("items", "18 items, each the sum of original questionnaire items (sheet Items, sheet Item_mapping); combined original items are never split"),
    ("kilograms", "survey conversion tables and metric units; heaps, pieces, cups, plates: weight estimated from prices (<item>_kg_est = 1, sheet Unit_weights)"),
    ("welfare", "official aggregate, annual, per adult equivalent or per person (welfare_scale, welfare_var)"),
    ("money", "local currency: ETB, TZS, MWK, NGN, UGX; exp is at 7 days, welfare and consumption totals per year"),
], columns=["", ""])

# ------------------------------------------------------------------------------------------
# 5. workbooks
# ------------------------------------------------------------------------------------------
def write(path, data, cc=None):
    wb = xlsxwriter.Workbook(path, {"constant_memory": True})
    hd = wb.add_format({"bold": True, "bg_color": "#DCE6F1", "border": 1, "text_wrap": True, "valign": "top"})
    tt = wb.add_format({"bold": True, "font_size": 12})
    def table(ws, r, df):
        for j, c in enumerate(df.columns):
            ws.write_string(r, j, str(c), hd)
        r += 1
        for row in df.itertuples(index=False):
            for j, v in enumerate(row):
                if v is None or (isinstance(v, float) and np.isnan(v)):
                    continue
                if isinstance(v, (int, float, np.integer, np.floating)) and not isinstance(v, bool):
                    ws.write_number(r, j, float(v))
                else:
                    ws.write_string(r, j, str(v)[:32000])
            r += 1
        return r + 1
    ws = wb.add_worksheet("Data"); ws.freeze_panes(1, 3); ws.set_column(0, 2, 12); ws.set_column(3, len(COLS), 11)
    for j, c in enumerate(COLS):
        ws.write_string(0, j, c, hd)
    vals = data.to_numpy(dtype=object); tx = [c in TEXT for c in COLS]
    for r in range(len(vals)):
        row = vals[r]
        for j in range(len(COLS)):
            v = row[j]
            if v is None or (isinstance(v, float) and v != v):
                continue
            if tx[j]:
                ws.write_string(r + 1, j, str(v))
            else:
                ws.write_number(r + 1, j, float(v))
    sel = (lambda d: d[d.country == cc]) if cc else (lambda d: d)
    for name, blocks, widths in [
        ("README", [(None, README)], [(0, 0, 14), (1, 1, 140)]),
        ("Dictionary", [(None, DD)], [(0, 0, 24), (1, 1, 60), (2, 2, 18), (3, 3, 60), (4, 4, 120)]),
        ("Items", [(None, IDOC)], [(0, 0, 22), (1, 1, 160)]),
        ("Item_mapping", [(None, sel(MP))], [(0, 2, 10), (3, 3, 45), (4, 6, 26)]),
        ("Unit_weights", [(None, sel(WTS))], [(0, 2, 12), (3, 5, 22), (6, 6, 14), (7, 7, 34)]),
        ("Quality_control", [("Summary", SUMM), ("Consumed item rows with kilograms, before and after the estimated weights", sel(ES)),
                             ("Households consuming each item, with kilograms and spending", sel(COV))], [(0, 0, 40), (1, 8, 14)])]:
        w = wb.add_worksheet(name); r = 0
        for title, df in blocks:
            if title:
                w.write_string(r, 0, title, tt); r += 1
            r = table(w, r, df)
        for a, b, wd in widths:
            w.set_column(a, b, wd)
    wb.close()
    log(f"written {path} ({os.path.getsize(path) / 1e6:.1f} MB)")

X.to_csv(os.path.join(OUTD, f"_wide_check_{TODAY}.csv.gz"), index=False)          # for the checks only (not delivered)
WTS.to_csv(os.path.join(OUTD, f"_unit_weights_{TODAY}.csv"), index=False)
if os.environ.get("NOXL") != "1":
    write(os.path.join(OUTD, f"ASF_household_food_{TODAY}.xlsx"), X)
    for cc in COUNTRIES:
        write(os.path.join(OUTD, f"ASF_household_food_{cc}_{TODAY}.xlsx"), X[X.country == cc], cc)
print(SUMM.to_string()); print(ES.to_string())
