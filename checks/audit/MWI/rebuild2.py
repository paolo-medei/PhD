"""Independent Python rebuild of panel_MWI.csv under the REVISED rules (coordinator message, round 2).

Run:  python3 -I /home/claude/audit_mwi/work/rebuild2.py [out=...] [--flags]
Differences from rebuild.py (round 1):
  1. 2024 Dzaleka camp households (cover-page camp == 1) dropped.
  2. Age shares over roster members of known age; two heads -> first listed on the roster.
  3. Size letters stripped from every unit code ("9A" -> "9", "22B" -> "22").
  4. Conversion table only for 508, 701, 702; never 509 (kg/gram only); never 702 teaspoon (20).
  5. 701: kg = 1, litre = 1, ml = 0.001, gram (18) not converted, coded packet 51 = table sachet (22) value.
  6. New 'Other (specify)' text rules (see other_specify()).
  7. Price trimming empties only the purchased quantity.
Flags for diagnosing remaining mismatches:
  --egg-metric        metric text amounts also applied to eggs
  --milk-nogram       '<number> gram' texts NOT converted for fresh milk (701)
"""
import re
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, "/home/claude/audit_mwi/work")
from load import FILES, CONV, ITEMS, read, num, txt, load_g1  # noqa: E402

OPTS = set(a for a in sys.argv[1:] if a.startswith("--"))
OUT = "/home/claude/audit_mwi/work/rebuild2_MWI.csv"
PKL = "/home/claude/audit_mwi/work/items2_{w}.pkl"
for a in sys.argv[1:]:
    if a.startswith("out="):
        OUT = a[4:]
        PKL = OUT.replace(".csv", "_items_{w}.pkl")

PROD_B = {504: "beef", 505: "goat_sheep", 507: "goat_sheep", 506: "pork", 508: "poultry", 509: "poultry",
          501: "eggs", 701: "milk", 702: "milk_processed", 902: "coffee"}
PROD_A = {504: "meat_agg", 505: "meat_agg", 507: "meat_agg", 506: "meat_agg", 508: "meat_agg", 509: "meat_agg",
          501: "eggs", 701: "milk", 902: "coffee"}
STD = {"beef": "kg", "goat_sheep": "kg", "pork": "kg", "poultry": "kg", "eggs": "piece", "milk": "litre",
       "milk_processed": "kg", "coffee": "kg", "meat_agg": "kg"}
TABLE_ITEMS = {508, 701, 702}

conv, _ = read(CONV)
conv["unit_code"] = txt(conv["unit_code"])
conv = conv[conv.unit_code != "23"]
TAB = conv.groupby(["region", "item_code", "unit_code"]).factor.mean().to_dict()


def sachet(region, item):
    return TAB.get((region, item, "22"), np.nan)


# ---------------------------------------------------------------- 'Other (specify)' text rules
NUM = r"(\d+(?:\.\d+)?)"
KG = r"(?:KILOGRAMMES|KILOGRAMME|KILOGRAMS|KILOGRAM|KILOS|KILO|KGS|KG)"
GR = r"(?:GRAMMES|GRAMME|GRAMMS|GRAMM|GRAMS|GRAM|GRMS|GRM|GS|G)"
ML = (r"(?:MILLILITRES|MILLILITRE|MILLILITERS|MILLILITER|MILILITRES|MILILITRE|MILLITRES|MILLITRE|MILLITERS|"
      r"MILLITER|MILLIMETRES|MILLIMETRE|MILLIGRAMS|MILLIGRAM|MLS|ML|MILS|MIL)")
NB = r"(?![A-Z])"   # unit word must end here
NA = r"(?<![A-Z])"  # and start here


def clean(text):
    t = (text or "").upper().strip()
    t = re.sub(r"\.+$", "", t).strip()
    t = re.sub(r"(\d),(\d)", r"\1.\2", t)
    return t


def other_specify(item, text, region):
    t = clean(text)
    if not t:
        return np.nan, "os_blank"
    std = STD[PROD_B[item]]
    if item == 501:
        if re.fullmatch(r"(TRAY|TREY|TRY|CRATE|CRETE)S?", t):
            return 30.0, "os_tray"
        if re.search(r"DOZEN", t):
            return 12.0, "os_dozen"
        if re.fullmatch(r"(PIECE|PEACE|PEICE)S?\s*(\(.*\))?", t):
            return 1.0, "os_piece"
        if "--egg-metric" not in OPTS:
            return np.nan, "os_other"
    if item == 508:
        if t.startswith("HALF") and re.search(r"CHICKEN|WHOLE", t):
            return 0.63, "os_half_chicken"
        if (re.search(r"WHOLE|FULL", t) or re.fullmatch(r"(\d+ )?CHICKENS?", t)) and not re.search(r"HALF|PIECES? OF", t):
            return 1.26, "os_whole"
    # '<number> unit' amounts
    m = re.search(NA + NUM + r"\s*" + KG + NB, t)
    if m:
        return float(m.group(1)), "os_num_kg"
    m = re.search(NA + NUM + r"\s*" + GR + NB, t)
    if m and not (item == 701 and "--milk-nogram" in OPTS):
        return float(m.group(1)) / 1000, "os_num_g"
    if item == 701:
        m = re.search(NA + NUM + r"\s*" + ML + NB, t)
        if m:
            return float(m.group(1)) / 1000, "os_num_ml"
    if re.search(NA + r"HALF\s+" + KG + NB, t):
        return 0.5, "os_half_kg"
    if re.search(NA + KG + NB, t):
        return 1.0, "os_bare_kg"
    if std == "kg" and re.search(NA + GR + NB, t):
        return 0.001, "os_bare_g"
    if item == 701 and re.search(NA + ML + NB, t):
        return 0.001, "os_bare_ml"
    if item in (701, 702) and re.search(r"SACHET|SATCHET|SACHE|SATCHE", t):
        return sachet(region, item), "os_sachet"
    if item == 701 and t in ("PACKET", "PACKETS", "PACKET (SMALL)", "PACKET UNSPECIFIED"):
        return sachet(region, item), "os_packet"
    return np.nan, "os_other"


def factor(item, unit, text, region):
    u = re.sub(r"[A-Z]+$", "", unit)  # drop size letters from every code
    if unit == "":
        return np.nan, "nounit"
    if u == "23":
        return other_specify(item, text, region)
    if item == 501:
        if u == "9":
            return 1.0, "egg_piece"
        return np.nan, "not_converted"
    if u == "1":
        return 1.0, "kg"
    if u == "18":
        if item == 701:
            return np.nan, "milk_gram"
        return 0.001, "g"
    if item == 701:
        if u == "15":
            return 1.0, "l"
        if u == "19":
            return 0.001, "ml"
        if u == "51":
            return sachet(region, item), "milk_packet51"
    if item == 702 and u == "20":
        return np.nan, "teaspoon_excluded"
    if item in TABLE_ITEMS:
        f = TAB.get((region, item, u))
        if f is not None and not np.isnan(f):
            return f, "table"
        return np.nan, "table_miss"
    return np.nan, "not_converted"


# ---------------------------------------------------------------- households
def household_vars(wave):
    F = FILES[wave]
    a, _ = read(F["a"])
    a["case_id"] = txt(a["case_id"])
    out = pd.DataFrame({"case_id": a["case_id"]})
    out["camp"] = num(a["camp"]) if "camp" in a else 0.0
    if wave == "w1":
        out["region"] = num(a["hh_a01"]).astype("Int64").astype("string")
        out["conv_region"] = (num(a["hh_a01"]) // 100).astype("Int64")
    else:
        out["region"] = num(a["district"]).astype("Int64").astype("string")
        out["conv_region"] = num(a["region"]).astype("Int64")
    out["urban"] = np.where(num(a["reside"]) == 1, "1", "0")
    out["clusterid"] = txt(a["ea_id"])
    out["hhweight"] = num(a["hh_wgt"])

    b, _ = read(F["b"])
    b["case_id"] = txt(b["case_id"])
    b["_ord"] = np.arange(len(b))
    idc = "id_code" if "id_code" in b else ("pid" if "pid" in b else "PID")
    b["_id"] = num(b[idc])
    b = b.sort_values(["case_id", "_id", "_ord"])
    b["age"] = num(b["hh_b05a"])
    b["rel"] = num(b["hh_b04"])
    b["sex"] = num(b["hh_b03"])
    gb = b.groupby("case_id")
    ros = pd.DataFrame({
        "n_roster": gb.size(),
        "n_known": gb.age.count(),
        "n_child": gb.age.apply(lambda s: (s < 15).sum()),
        "n_old": gb.age.apply(lambda s: (s >= 60).sum()),
    })
    ros["share_child"] = ros.n_child / ros.n_known.where(ros.n_known > 0)
    ros["share_elderly"] = ros.n_old / ros.n_known.where(ros.n_known > 0)
    heads = b[b.rel == 1].groupby("case_id").first()[["age", "sex"]]
    heads = heads.rename(columns={"age": "head_age"})
    heads["head_female"] = np.where(heads.sex.isna(), np.nan, (heads.sex == 2).astype(float))
    ros = ros.join(heads[["head_age", "head_female"]])
    out = out.merge(ros.reset_index(), on="case_id", how="left")

    agg, _ = read(F["agg"])
    agg["case_id"] = txt(agg["case_id"])
    if wave == "w1":
        agg = agg[["case_id", "rexpagg"]].merge(out[["case_id", "n_roster"]], on="case_id", how="left")
        agg["hhsize"] = agg["n_roster"].astype(float)
        agg = agg.drop(columns="n_roster")
    else:
        agg = agg[["case_id", "rexpagg", "hhsize"]]
    agg["welfare"] = agg.rexpagg / agg.hhsize
    agg["adulteq"] = agg.hhsize
    out = out.merge(agg[["case_id", "hhsize", "welfare", "adulteq"]], on="case_id", how="left")
    return out


def build_wave(wave):
    g, _ = load_g1(wave)
    hv = household_vars(wave)
    drop = set(hv.case_id[hv.camp == 1])
    hv = hv[~hv.case_id.isin(drop)]
    g = g[~g.case_id.isin(drop)]
    hh_all = pd.Index(g.case_id.unique(), name="case_id")
    g = g[g.item.isin(ITEMS)].copy()
    g["item"] = g.item.astype(int)
    g = g.merge(hv[["case_id", "conv_region"]], on="case_id", how="left")

    for q in ["03", "04", "06", "07"]:
        keys = g[["item", f"u{q}", f"t{q}", "conv_region"]].drop_duplicates()
        res = [factor(i, u, t, int(r) if pd.notna(r) else -1) for i, u, t, r in keys.itertuples(index=False)]
        keys[f"f{q}"] = [x[0] for x in res]
        keys[f"rule{q}"] = [x[1] for x in res]
        g = g.merge(keys, on=["item", f"u{q}", f"t{q}", "conv_region"], how="left")
        g[f"c{q}"] = g[f"q{q}"] * g[f"f{q}"]

    g["prod"] = g.item.map(PROD_B)
    g["price"] = np.where((g.spend > 0) & (g.c04 > 0), g.spend / g.c04, np.nan)
    med = g.groupby("prod").price.median()
    g["med"] = g["prod"].map(med)
    # egg rescale (inferred, not defined in the revised rules): a purchase priced above 10x the egg
    # median is read as trays of 30; the purchased quantity is multiplied by 30 and re-checked.
    g["egg_rescaled"] = (g.item == 501) & (g.price > 10 * g.med) & ("--no-egg-rescale" not in OPTS)
    g.loc[g.egg_rescaled, "c04"] = g.loc[g.egg_rescaled, "c04"] * 30
    g.loc[g.egg_rescaled, "price"] = g.loc[g.egg_rescaled, "price"] / 30
    g["trim"] = (g.price > 10 * g.med) | (g.price < g.med / 10)
    g["k03"] = g.c03
    g["k04"] = g.c04.where(~g.trim)
    g["k06"] = g.c06
    g["k07"] = g.c07
    g["wave"] = wave
    g.to_pickle(PKL.format(w=wave))

    frames = []
    for track, pmap in (("B", PROD_B), ("A", PROD_A)):
        sub = g[g.item.isin(pmap.keys())].copy()
        sub["product"] = sub.item.map(pmap)
        sub["conv_ok"] = sub.k04 > 0
        sub["exp_conv_i"] = sub.spend.where(sub.conv_ok)
        sub["unconv_i"] = (sub.spend > 0) & ~sub.conv_ok
        sub["cons_i"] = sub.g01 == 1

        def s(x):
            return x.sum(min_count=1)

        agg = sub.groupby(["case_id", "product"]).agg(
            consumed=("cons_i", "max"),
            qty_std=("k03", s), purch_std=("k04", s), own_std=("k06", s), gift_std=("k07", s),
            exp=("spend", s), exp_conv=("exp_conv_i", s), unconv=("unconv_i", "max"))
        prods = sorted(set(pmap.values()))
        grid = pd.MultiIndex.from_product([hh_all, prods], names=["case_id", "product"])
        agg = agg.reindex(grid).reset_index()
        agg["consumed"] = agg.consumed.fillna(False).astype(int)
        agg["unconv"] = agg.unconv.fillna(False).astype(int)
        agg["track"] = track
        frames.append(agg)
    p = pd.concat(frames, ignore_index=True)
    for c in ["qty_std", "purch_std", "own_std", "gift_std", "exp", "exp_conv"]:
        p[c] = p[c].where(p[c] != 0)
    p["uv"] = np.where((p.exp_conv > 0) & (p.purch_std > 0), p.exp_conv / p.purch_std, np.nan)
    p["std"] = p["product"].map(STD)
    p = p.merge(hv.drop(columns=["camp", "conv_region"]), on="case_id", how="left")
    p = p.rename(columns={"case_id": "hhid"})
    p["country"] = "MWI"
    p["wave"] = wave
    p["year"] = FILES[wave]["year"]
    p["strataid"] = pd.NA
    return p


COLS = ["hhid", "product", "std", "track", "consumed", "qty_std", "purch_std", "own_std", "gift_std", "exp",
        "exp_conv", "unconv", "hhsize", "share_child", "share_elderly", "head_age", "head_female", "welfare",
        "adulteq", "region", "urban", "clusterid", "hhweight", "country", "wave", "year", "strataid", "uv"]

if __name__ == "__main__":
    parts = []
    for w in ["w1", "w2", "w3", "w4"]:
        p = build_wave(w)
        print(w, p.shape, p.hhid.nunique(), flush=True)
        parts.append(p)
    allp = pd.concat(parts, ignore_index=True)
    allp[COLS].to_csv(OUT, index=False)
    print("wrote", OUT, allp.shape)
