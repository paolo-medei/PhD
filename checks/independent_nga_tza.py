"""Independent re-count of the headline participation numbers, written from the
questionnaires without reusing any pipeline code.

Nigeria 2010-2015 and Tanzania 2008-2020: share of households that BOUGHT meat
in the last 7 days, poorest vs richest fifth of welfare (within year), weighted.
'Bought' = reported a positive amount spent on any meat item (the pipeline uses
a positive converted purchased quantity, so small differences are expected
where the unit could not be converted).

Usage: python3 checks/independent_nga_tza.py <folder with one subfolder per survey>
"""
import sys, glob, os
import numpy as np, pandas as pd, pyreadstat

ROOT = sys.argv[1] if len(sys.argv) > 1 else "data/_unzipped"

def find(hint, stem):
    hits = [p for p in glob.glob(os.path.join(ROOT, hint + "*", "**", "*.dta"), recursive=True)
            if os.path.basename(p).lower() == stem.lower() + ".dta"]
    if not hits: raise FileNotFoundError(f"{hint}: {stem}")
    return hits[0]

def read(hint, stem, cols):
    df, _ = pyreadstat.read_dta(find(hint, stem), usecols=cols)
    return df

def quintile_shares(hh):
    """hh: one row per household with columns year, welfare, weight, bought."""
    out = []
    for y, g in hh.dropna(subset=["welfare"]).query("welfare > 0").groupby("year"):
        g = g.sort_values("welfare", kind="mergesort")
        g["q"] = np.ceil(np.arange(1, len(g) + 1) * 5 / len(g)).astype(int)   # like dplyr::ntile
        out.append(g)
    a = pd.concat(out)
    a["weight"] = a["weight"].where(a["weight"] > 0, 1).fillna(1)
    return {q: round(100 * np.average(a.loc[a.q == q, "bought"], weights=a.loc[a.q == q, "weight"]), 1)
            for q in (1, 5)}

# ---------------- Nigeria: food module sect10b, welfare = totcons (per capita)
MEAT_NG = {80, 82, 90, 91, 92, 93}
rows = []
for yr, w in [(2010, 1), (2012, 2), (2015, 3)]:
    f = read(f"NGA_{yr}", f"sect10b_harvestw{w}", ["hhid", "item_cd", "s10bq4"])
    f["meat_spend"] = np.where(f["item_cd"].isin(MEAT_NG) & (f["s10bq4"] > 0), 1, 0)
    hhs = f.groupby("hhid", as_index=False)["meat_spend"].max()          # every household in the module
    a = read(f"NGA_{yr}", f"cons_agg_wave{w}_visit2", ["hhid", "totcons", "hhweight"])
    m = hhs.merge(a, on="hhid", how="inner")
    rows.append(pd.DataFrame({"year": yr, "welfare": m["totcons"], "weight": m["hhweight"], "bought": m["meat_spend"]}))
print("NGA meat buyers % (Q1, Q5):", quintile_shares(pd.concat(rows)))

# ---------------- Tanzania: food module, welfare per adult equivalent
MEAT_TZ = {801, 802, 803, 804, 8041, 8042}
cfg = [(2008, "SEC_K1", "hhid", "skcode", "skq4", "TZY1.HH.Consumption", "expmR", "hhweight", None),
       (2010, "HH_SEC_K1", "y2_hhid", "itemcode", "hh_k04", "TZY2.HH.Consumption", "expmR", "hhweight", None),
       (2012, "HH_SEC_J1", "y3_hhid", "itemcode", "hh_j04", "ConsumptionNPS3", "expmR", None, ("HH_SEC_A", "y3_weight")),
       (2014, "hh_sec_j1", "y4_hhid", "itemcode", "hh_j04", "consumptionNPS4", "expmR", "hhweight", None),
       (2020, "hh_sec_ja1", "y5_hhid", "itemcode", "hh_ja04", "consumption_real_y5", "expmR_pae", "hhweight", None)]
rows = []
for yr, food, idv, item, spend, agg, wel, wgt, wsrc in cfg:
    f = read(f"TZA_{yr}", food, [idv, item, spend])
    f["meat_spend"] = np.where(f[item].isin(MEAT_TZ) & (f[spend] > 0), 1, 0)
    hhs = f.groupby(idv, as_index=False)["meat_spend"].max()
    acols = [idv, wel, "adulteq"] + ([wgt] if wgt else [])
    a = read(f"TZA_{yr}", agg, acols)
    if wsrc:
        c = read(f"TZA_{yr}", wsrc[0], [idv, wsrc[1]]).drop_duplicates(idv)
        a = a.merge(c, on=idv, how="left").rename(columns={wsrc[1]: "w"})
    else:
        a = a.rename(columns={wgt: "w"})
    pae = a[wel] if wel == "expmR_pae" else a[wel] / a["adulteq"].clip(lower=1)
    a = a.assign(welfare=pae)
    m = hhs.merge(a, on=idv, how="inner")
    rows.append(pd.DataFrame({"year": yr, "welfare": m["welfare"], "weight": m["w"], "bought": m["meat_spend"]}))
print("TZA meat buyers % (Q1, Q5):", quintile_shares(pd.concat(rows)))
