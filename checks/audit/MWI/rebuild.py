"""Independent Python rebuild of panel_MWI.csv from the raw Malawi IHS Stata files.

Run:  python3 -I /home/claude/audit_mwi/work/rebuild.py [options]
Writes /home/claude/audit_mwi/work/rebuild_MWI.csv plus item-level detail.

Options (alternative readings of the declared rules, used to diagnose mismatches):
  --egg-metric       kg / gram also converted for eggs (1 kg = 1 piece, literal "kilogram = 1")
  --strict-metric    'Other (specify)' metric parsing limited to the spellings in the SPEC
  --trimA-pooled     track-A meat_agg trimmed against a pooled meat median (default: A = sum of trimmed B)
"""
import re
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, "/home/claude/audit_mwi/work")
from load import FILES, CONV, ITEMS, read, num, txt, load_g1  # noqa: E402

OPTS = set(a for a in sys.argv[1:] if a.startswith("--"))
OUT = "/home/claude/audit_mwi/work/rebuild_MWI.csv"
for a in sys.argv[1:]:
    if a.startswith("out="):
        OUT = a[4:]

PROD_B = {504: "beef", 505: "goat_sheep", 507: "goat_sheep", 506: "pork", 508: "poultry", 509: "poultry",
          501: "eggs", 701: "milk", 702: "milk_processed", 902: "coffee"}
PROD_A = {504: "meat_agg", 505: "meat_agg", 507: "meat_agg", 506: "meat_agg", 508: "meat_agg", 509: "meat_agg",
          501: "eggs", 701: "milk", 902: "coffee"}
STD = {"beef": "kg", "goat_sheep": "kg", "pork": "kg", "poultry": "kg", "eggs": "piece", "milk": "litre",
       "milk_processed": "kg", "coffee": "kg", "meat_agg": "kg"}
TABLE_ITEMS = {508, 509, 701, 702}

# ----------------------------------------------------------------------------------------------
# conversion table
conv, _ = read(CONV)
conv["unit_code"] = txt(conv["unit_code"])
conv = conv[conv.unit_code != "23"]  # 'Other (specify)' rows handled by the text rules
TAB = conv.groupby(["region", "item_code", "unit_code"]).factor.mean().to_dict()
SACHET = {(r, i): TAB.get((r, i, "22")) for r in (1, 2, 3) for i in (701, 702)}

# ----------------------------------------------------------------------------------------------
# 'Other (specify)' parser
NUM = r"(\d+(?:[.,]\d+)?)"
if "--strict-metric" in OPTS:
    MASS_KG = r"(?:KILOGRAMS?|KILOGRAMMES?|KG)"
    MASS_G = r"(?:GRAMS?)"
    VOL_ML = r"(?:MILLILITRES?|ML)"
    VOL_L = r"(?!x)x"  # never
else:
    MASS_KG = r"(?:KILOGRAMMES?|KILOGRAMS?|KGS?)"
    MASS_G = r"(?:GRAMMES?|GRAMMS?|GRAMS?|G)"
    VOL_ML = r"(?:MILLILITRES?|MILLILITERS?|MILLITRES?|MILLITERS?|MILITRES?|MLS?)"
    VOL_L = r"(?:LITRES?|LITERS?)"


def metric(text):
    """Return (kind, factor) where kind is 'mass' or 'vol' and factor is in kg or litre per unit."""
    t = text.upper()
    for pat, kind, mult in ((MASS_KG, "mass", 1.0), (VOL_ML, "vol", 0.001), (VOL_L, "vol", 1.0),
                            (MASS_G, "mass", 0.001)):
        # number immediately before the unit word ("500 GRAM", "300G", "0.3 KILOGRAM")
        m = re.search(NUM + r"\s*" + pat + r"(?![A-Z])", t)
        if m:
            return kind, float(m.group(1).replace(",", ".")) * mult
        # bare unit word ("GRAMS", "MILLILITRES", "ML"); a bare 'G' is not accepted
        if pat == MASS_G:
            pat = pat.replace("|G)", ")")
        m = re.search(r"(?<![A-Z])" + pat + r"(?![A-Z])", t)
        if m:
            if re.search(r"\bHALF\b", t):
                return kind, 0.5 * mult
            return kind, mult
    return None


def other_specify(item, text, region):
    t = (text or "").upper().strip()
    if not t:
        return np.nan, "os_blank"
    std = STD[PROD_B[item]]
    m = metric(t)
    if m is not None:
        kind, f = m
        if std == "kg" and kind == "mass":
            return f, "os_metric"
        if std == "litre":
            return f, "os_metric"
        # metric volume for a kg product, or anything metric for eggs: not convertible
    if item == 501:
        if re.search(r"TRAY|TREY", t):
            return 30.0, "os_tray"
        if re.search(r"DOZEN", t):
            return 12.0, "os_dozen"
        if re.search(r"PIECE", t):
            return 1.0, "os_piece"
    if item in (508, 509):
        if re.search(r"WHOLE|FULL|CHICKEN", t):
            return 1.26, "os_whole"
    if item in (701, 702):
        if re.search(r"SACHET|SATCHET", t):
            return SACHET[(region, item)], "os_sachet"
    return np.nan, "os_other"


def factor(item, unit, text, region):
    std = STD[PROD_B[item]]
    u = unit
    if item == 501 and re.fullmatch(r"9[A-Z]", u):
        u = "9"
    if u == "":
        return np.nan, "nounit"
    if u == "1":
        if std == "piece" and "--egg-metric" not in OPTS:
            return np.nan, "egg_kg"
        return 1.0, "kg"
    if u == "18":
        if std == "piece" and "--egg-metric" not in OPTS:
            return np.nan, "egg_g"
        return 0.001, "g"
    if item == 701 and u == "15":
        return 1.0, "l"
    if item == 701 and u == "19":
        return 0.001, "ml"
    if item == 501 and u == "9":
        return 1.0, "egg_piece"
    if u == "23":
        return other_specify(item, text, region)
    if item in TABLE_ITEMS:
        f = TAB.get((region, item, u))
        if f is not None and not np.isnan(f):
            return f, "table"
        return np.nan, "table_miss"
    return np.nan, "not_converted"


# ----------------------------------------------------------------------------------------------
def household_vars(wave):
    F = FILES[wave]
    a, _ = read(F["a"])
    a["case_id"] = txt(a["case_id"])
    out = pd.DataFrame({"case_id": a["case_id"]})
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
    b["age"] = num(b["hh_b05a"])
    b["rel"] = num(b["hh_b04"])
    b["sex"] = num(b["hh_b03"])
    gb = b.groupby("case_id")
    ros = pd.DataFrame({
        "n_roster": gb.size(),
        "n_child": gb.age.apply(lambda s: (s < 15).sum()),
        "n_old": gb.age.apply(lambda s: (s >= 60).sum()),
    })
    ros["share_child"] = ros.n_child / ros.n_roster
    ros["share_elderly"] = ros.n_old / ros.n_roster
    heads = b[b.rel == 1].groupby("case_id").agg(head_age=("age", "mean"),
                                                 head_female=("sex", lambda s: (s == 2).mean()),
                                                 n_heads=("sex", "size"))
    ros = ros.join(heads)
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
    hh_all = pd.Index(g.case_id.unique(), name="case_id")
    g = g[g.item.isin(ITEMS)].copy()
    g["item"] = g.item.astype(int)
    hv = household_vars(wave)
    g = g.merge(hv[["case_id", "conv_region"]], on="case_id", how="left")

    # conversion factors per source
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
    g["trim"] = (g.price > 10 * g.med) | (g.price < g.med / 10)
    if "--trimA-pooled" in OPTS:
        g["prodA"] = g.item.map(PROD_A)
        medA = g.groupby("prodA").price.median()
        g["trimA"] = (g.price > 10 * g.prodA.map(medA)) | (g.price < g.prodA.map(medA) / 10)
    for q in ["03", "04", "06", "07"]:
        g[f"k{q}"] = g[f"c{q}"].where(~g.trim)
        if "--trimA-pooled" in OPTS:
            g[f"kA{q}"] = g[f"c{q}"].where(~g.trimA)
    g["wave"] = wave
    g.to_pickle(f"/home/claude/audit_mwi/work/items_{wave}.pkl")

    frames = []
    for track, pmap in (("B", PROD_B), ("A", PROD_A)):
        sub = g[g.item.isin(pmap.keys())].copy()
        sub["product"] = sub.item.map(pmap)
        pre = "kA" if (track == "A" and "--trimA-pooled" in OPTS) else "k"
        sub["conv_ok"] = sub[f"{pre}04"] > 0
        sub["spend_pos"] = sub.spend > 0
        sub["exp_conv_i"] = sub.spend.where(sub.conv_ok)
        sub["unconv_i"] = sub.spend_pos & ~sub.conv_ok
        sub["cons_i"] = sub.g01 == 1

        def s(x):
            return x.sum(min_count=1)

        agg = sub.groupby(["case_id", "product"]).agg(
            consumed=("cons_i", "max"),
            qty_std=(f"{pre}03", s), purch_std=(f"{pre}04", s), own_std=(f"{pre}06", s), gift_std=(f"{pre}07", s),
            exp=("spend", s), exp_conv=("exp_conv_i", s), unconv=("unconv_i", "max"))
        # full grid of households x products
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
    p = p.merge(hv, on="case_id", how="left")
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
        print(w, p.shape, p.hhid.nunique())
        parts.append(p)
    allp = pd.concat(parts, ignore_index=True)
    allp[COLS].to_csv(OUT, index=False)
    print("wrote", OUT, allp.shape)
