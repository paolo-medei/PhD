#!/usr/bin/env python3
"""
HOUSEHOLD DATASET ON PROTEIN-RICH FOODS, ORIGINAL VALUES ONLY (v2, 23 Nov 2026)

One row per country x round x household of the food module. Every value is copied from the
LSMS-ISA Stata files as it is: answers, quantities, unit codes, amounts paid, by source, for every
protein-rich food item; household design variables and the official consumption aggregate.
Nothing is converted, summed, recoded, imputed, trimmed or filled with zeros. An empty cell is an
empty (missing) value in the file, or an item / question that the round does not have.

Inputs (from the scripts in this folder)
  build_protein_dataset.R  long_<CC>.csv.gz (household x item, raw columns), module_households.csv, build_log.csv
  hh_raw.R                 hh_raw.csv, hh_raw_sources.csv (cover and aggregate variables, original names and labels)
  role_vars.R              role_vars.csv (original variable of each question by round, control totals from the raw files)
  unit_codes.R             unit_codes.csv (unit codes and labels)
Outputs
  <out>/ASF_protein_household_dataset_raw_<date>.xlsx  and the same Final_Household_Dataset as .csv.gz

USE  python3 assemble_dataset.py <build dir> <item_map.csv> <out dir>
"""
import csv, datetime, difflib, gzip, math, os, re, sys, time
import numpy as np
import pandas as pd
import xlsxwriter

BUILD, MAPF, OUTD = sys.argv[1:4]
os.makedirs(OUTD, exist_ok=True)
TODAY = datetime.date.today().isoformat()
XLSX = os.path.join(OUTD, f"ASF_protein_household_dataset_raw_{TODAY}.xlsx")
CSVF = os.path.join(OUTD, f"ASF_protein_household_dataset_raw_{TODAY}.csv.gz")
T0 = time.time()

COUNTRIES = ["ETH", "TZA", "MWI", "NGA", "UGA"]
ROUND_NAME = {
    ("ETH", 2011): "ERSS wave 1, 2011/12", ("ETH", 2013): "ESS wave 2, 2013/14", ("ETH", 2015): "ESS wave 3, 2015/16",
    ("ETH", 2018): "ESS wave 4, 2018/19", ("ETH", 2021): "ESPS wave 5, 2021/22",
    ("TZA", 2008): "NPS round 1, 2008/09", ("TZA", 2010): "NPS round 2, 2010/11", ("TZA", 2012): "NPS round 3, 2012/13",
    ("TZA", 2014): "NPS round 4, 2014/15", ("TZA", 2020): "NPS round 5, 2020/21",
    ("MWI", 2010): "IHS3, 2010/11", ("MWI", 2016): "IHS4, 2016/17", ("MWI", 2019): "IHS5, 2019/20", ("MWI", 2024): "IHS6, 2024/25",
    ("NGA", 2010): "GHS-Panel wave 1, 2010/11", ("NGA", 2012): "GHS-Panel wave 2, 2012/13", ("NGA", 2015): "GHS-Panel wave 3, 2015/16",
    ("NGA", 2018): "GHS-Panel wave 4, 2018/19", ("NGA", 2023): "GHS-Panel wave 5, 2023/24",
    ("UGA", 2010): "UNPS 2010/11", ("UGA", 2011): "UNPS 2011/12", ("UGA", 2013): "UNPS 2013/14", ("UGA", 2015): "UNPS 2015/16",
    ("UGA", 2018): "UNPS 2018/19", ("UGA", 2019): "UNPS 2019/20"}
FOOD_FILE = {
    ("ETH", 2011): "sect5a_hh_w1", ("ETH", 2013): "sect5a_hh_w2", ("ETH", 2015): "sect5a_hh_w3", ("ETH", 2018): "sect6a_hh_w4", ("ETH", 2021): "sect6a_hh_w5",
    ("TZA", 2008): "SEC_K1", ("TZA", 2010): "HH_SEC_K1", ("TZA", 2012): "HH_SEC_J1", ("TZA", 2014): "hh_sec_j1", ("TZA", 2020): "hh_sec_ja1 + hh_sec_j1",
    ("MWI", 2010): "hh_mod_g1", ("MWI", 2016): "hh_mod_g1", ("MWI", 2019): "hh_mod_g1", ("MWI", 2024): "hh_mod_g1",
    ("NGA", 2010): "sect10b_harvestw1", ("NGA", 2012): "sect10b_harvestw2", ("NGA", 2015): "sect10b_harvestw3", ("NGA", 2018): "sect10b_harvestw4", ("NGA", 2023): "sect5b_harvestw5",
    ("UGA", 2010): "GSEC15b", ("UGA", 2011): "GSEC15B", ("UGA", 2013): "GSEC15B", ("UGA", 2015): "gsec15b", ("UGA", 2018): "GSEC15B", ("UGA", 2019): "gsec15b"}
ONLY_CONSUMED = {("NGA", 2010), ("UGA", 2010), ("UGA", 2011), ("UGA", 2013), ("UGA", 2015)}
RECALL = {("NGA", 2018): "7 days; purchases: last 30 days, most recent purchase", ("NGA", 2023): "7 days; purchases: last 30 days, most recent purchase"}

# the question of each item column: column suffix, role name in the build, meaning
ROLES = [("consumed_yn", "cons_raw", "Consumed in the last 7 days? (code of the file; 1 yes, 2 no)"),
         ("qty_total", "q_tot", "Quantity consumed in total, last 7 days (in unit_total)"),
         ("unit_total", "u_tot", "Unit code of the total quantity (Unit_Codes); Uganda: the unit of all sources; Nigeria 2018-2023: also of the sources"),
         ("unit_total_other", "uo_tot", "Text of the 'other (specify)' unit of the total"),
         ("unit_total_size", "us_tot", "Size / sub-unit code of the total (Malawi; Nigeria 2018-2023)"),
         ("qty_purchased", "q_pur", "Quantity purchased, last 7 days (Uganda: purchased and consumed at home)"),
         ("unit_purchased", "u_pur", "Unit code of the quantity purchased"),
         ("unit_purchased_other", "uo_pur", "Text of the 'other (specify)' unit of the purchase"),
         ("unit_purchased_size", "us_pur", "Malawi: size / sub-unit code of the purchase"),
         ("value_purchased", "exp_pur", "Amount paid for the purchases of the last 7 days, local currency (Uganda: purchases consumed at home)"),
         ("qty_own", "q_own", "Quantity from own production"),
         ("unit_own", "u_own", "Unit code of the quantity from own production"),
         ("unit_own_other", "uo_own", "Text of the 'other (specify)' unit of own production"),
         ("unit_own_size", "us_own", "Malawi: size / sub-unit code of own production"),
         ("qty_gift", "q_gift", "Quantity from gifts and other sources"),
         ("unit_gift", "u_gift", "Unit code of the quantity from gifts"),
         ("unit_gift_other", "uo_gift", "Text of the 'other (specify)' unit of gifts"),
         ("unit_gift_size", "us_gift", "Malawi: size / sub-unit code of gifts"),
         ("qty_away", "q_away", "Uganda: quantity purchased and consumed away from home"),
         ("value_away", "val_away", "Uganda: value of purchases consumed away from home"),
         ("value_own", "val_own", "Uganda: value of own production"),
         ("value_gift", "val_gift", "Uganda: value of gifts"),
         ("qty_from_purchases", "q_frompur", "Nigeria 2012-2018: quantity consumed out of purchases (2018: in unit_total)"),
         ("unit_from_purchases", "u_frompur", "Nigeria 2012-2015: unit code of the quantity consumed out of purchases"),
         ("purchased_30d_yn", "pur30_yn", "Nigeria 2018-2023: purchased in the last 30 days? (1 yes, 2 no)"),
         ("qty_last_purchase", "q_lastpur", "Nigeria 2018-2023: quantity of the most recent purchase (last 30 days)"),
         ("unit_last_purchase", "u_lastpur", "Nigeria 2018-2023: unit code of the most recent purchase"),
         ("unit_last_purchase_size", "us_lastpur", "Nigeria 2018-2023: size code of the most recent purchase"),
         ("value_last_purchase", "val_lastpur", "Nigeria 2018-2023: amount spent on the most recent purchase"),
         ("conv_factor_total_file", "cvn_tot", "Nigeria 2018-2023: kg/litre conversion factor of the total quantity, as given in the survey file"),
         ("conv_factor_last_purchase_file", "cvn_lastpur", "Nigeria 2018-2023: kg/litre conversion factor of the purchase quantity, as given in the survey file"),
         ("other_item_code", "os_item", "Nigeria 2018-2023: code of the item specified under an 'other' item (item_os_cd, e.g. 821 guinea fowl under 82); labels in Data_Dictionary B"),
         ("qty_weight_estimate", "q_wt", "Tanzania 2020 main sample: weight estimate of the quantity (non-standard units)"),
         ("unit_weight_estimate", "u_wt", "Tanzania 2020 main sample: unit of the weight estimate")]
RNAME = {b: a for a, b, _ in ROLES}
RDESC = {a: c for a, _, c in ROLES}
TEXT_ROLES = {a for a, b, _ in ROLES if b.startswith("u")}          # unit codes and unit texts are kept as text

# ------------------------------------------------------------------------------------------
# 1. item map, household variables, control totals
# ------------------------------------------------------------------------------------------
MAP = pd.read_csv(MAPF)
MAP["round"] = MAP["year"].apply(lambda y: int(math.floor(y)))
SLOT = MAP.drop_duplicates("slot").set_index("slot")[["cat", "sub", "in_total"]]
CAT_ORDER = ["meat", "fish", "eggs", "dairy", "plant", "asf_mixed"]
SUB_ORDER = ["red", "white", "minor", "processed", "mixed", "fresh", "dried_smoked_salted", "canned_packaged", "fish_product",
             "unspecified", "eggs", "milk_fresh", "milk_powder_tinned", "yoghurt_fermented", "cheese", "butter_ghee",
             "milk_products", "ice_cream", "fats_mixed", "infant_formula", "pulses", "pulses_processed", "soy", "pulses_fresh",
             "groundnuts", "nuts", "seeds", "pulse_nut_other", "nuts_low_protein", "meat_or_fish_tinned", "other_specify", "prepared_vendor"]
first_seen = {s: i for i, s in enumerate(MAP["slot"].drop_duplicates())}
SLOTS = sorted(SLOT.index, key=lambda s: (CAT_ORDER.index(SLOT.at[s, "cat"]), SUB_ORDER.index(SLOT.at[s, "sub"]), first_seen[s]))
BL = pd.read_csv(os.path.join(BUILD, "build_log.csv"))
ROUNDS = sorted([(c, int(y)) for c, y in zip(BL.country, BL.year)], key=lambda r: (COUNTRIES.index(r[0]), r[1]))
RSET = set(ROUNDS)
RLAB = [f"{c}_{y}" for c, y in ROUNDS]
ASKED = MAP.groupby(["country", "round"])["slot"].apply(set).to_dict()
ckey = lambda s: s.map(COUNTRIES.index) if s.name == "country" else s

RV = pd.read_csv(os.path.join(BUILD, "role_vars.csv"))
RV = RV[RV.exists].copy(); RV["year"] = RV["year"].astype(int)
HS = pd.read_csv(os.path.join(BUILD, "hh_raw_sources.csv"), keep_default_na=False, na_values=[""])
HS["_inr"] = [(a, int(b)) in RSET for a, b in zip(HS.country, HS.year)]
HR = pd.read_csv(os.path.join(BUILD, "hh_raw.csv"), dtype=str, keep_default_na=False, na_values=[""])
HR["year"] = HR["year"].astype(int)
MOD = pd.read_csv(os.path.join(BUILD, "module_households.csv"), dtype={"hhid": str, "module": str}, keep_default_na=False, na_values=[""])
MOD["year"] = MOD["year"].astype(int)
MOD = MOD[[(c, y) in RSET for c, y in zip(MOD.country, MOD.year)]].copy()
MOD["food_module_file"] = [m if isinstance(m, str) else FOOD_FILE[(c, y)] for c, y, m in zip(MOD.country, MOD.year, MOD["module"])]
H = MOD[["country", "year", "hhid", "food_module_file"]].merge(HR, on=["country", "year", "hhid"], how="left", indicator="_m")
H["_in_cover"] = H["_m"] == "both"
H = H.drop(columns="_m").sort_values(["country", "year", "hhid"], key=ckey).reset_index(drop=True)
assert not H.duplicated(["country", "year", "hhid"]).any()
HHROLES = ["weight", "region", "district", "subdistrict", "ea", "strata", "urban_rural", "hhsize", "adulteq", "int_month", "int_year", "refugee_camp_sample"]
AGGCOLS = sorted(c for c in HR.columns if c.startswith("agg_"))
HHCOLS = ["country", "year", "hhid", "food_module_file"] + [c for c in HHROLES + AGGCOLS if c in H.columns and H[c].notna().any()]
# a household column is a number only if the variable is numeric in the Stata file of every round
HHTEXT = {"country", "hhid", "food_module_file"} | (set(HHCOLS) & set(HS.loc[HS.stata_type == "string", "column"]))


def show(a):
    """numbers as Stata shows them: values stored as 4-byte floats back to their 7 significant digits"""
    a = a.copy()
    m = np.isfinite(a) & (a != 0) & (a != np.round(a))
    if m.any():
        v = a[m]; f = v.astype(np.float32).astype(np.float64)
        is32 = np.abs(f - v) <= 1e-13 * np.abs(v)
        d = 6 - np.floor(np.log10(np.abs(v)))
        r = np.array([round(x, int(k)) if k > 0 else x for x, k in zip(v, d)])
        a[m] = np.where(is32, r, v)
    return a


# ------------------------------------------------------------------------------------------
# 2. item columns that hold at least one value; control totals of the dataset
# ------------------------------------------------------------------------------------------
def read_long(cc):
    raw = {b for _, b, _ in ROLES}
    dt = {c: str for c in ["hhid", "slot"] + [b for a, b, _ in ROLES if a in TEXT_ROLES]}
    L = pd.read_csv(os.path.join(BUILD, f"long_{cc}.csv.gz"), dtype=dt, low_memory=False, keep_default_na=False, na_values=[""],
                    usecols=lambda c: c in raw | {"hhid", "slot", "year", "code"})
    L["year"] = L["year"].astype(float).astype(int)
    L = L[[(cc, y) in RSET for y in L.year]].copy()
    for a, b, _ in ROLES:
        if b not in L.columns:
            L[b] = np.nan
        if a not in TEXT_ROLES:
            L[b] = pd.to_numeric(L[b], errors="coerce")
    if cc == "UGA":                        # the builder repeats Uganda's single unit for every source: kept once
        for b in ["u_pur", "u_own", "u_gift"]:
            L[b] = np.nan
    return L.rename(columns=RNAME)


print("pass 1: columns", flush=True)
NONEMPTY = set(); AVAIL = {}; ITEMQC = []
for cc in COUNTRIES:
    if not any(c == cc for c, _ in ROUNDS):
        continue
    L = read_long(cc)
    assert not L.duplicated(["year", "hhid", "slot"]).any(), cc
    for a, b, _ in ROLES:
        nn = L[["year", "slot"]].assign(_n=L[a].notna()).groupby(["year", "slot"])["_n"].any()
        for (y, s) in nn.index[nn]:
            NONEMPTY.add((s, a)); AVAIL.setdefault((s, a), set()).add((cc, y))
        for y, g in L.groupby("year"):
            x = g[a]
            if x.notna().any():
                ITEMQC.append(dict(country=cc, year=y, role=b, column=a, non_missing_dataset=int(x.notna().sum()),
                                   sum_dataset=float(pd.to_numeric(x, errors="coerce").sum()), distinct_dataset=int(x.dropna().nunique())))
    print(f"  {cc}: {L.hhid.nunique()} households in item rows ({time.time() - T0:.0f}s)", flush=True)
    del L
ITEMCOLS = [f"{s}__{a}" for s in SLOTS for a, _, _ in ROLES if (s, a) in NONEMPTY]
COLS = HHCOLS + ITEMCOLS
POS = {c: i for i, c in enumerate(COLS)}
TEXTCOLS = HHTEXT | {c for c in ITEMCOLS if c.split("__")[1] in TEXT_ROLES}
print(f"  {len(COLS)} columns: {len(HHCOLS)} household, {len(ITEMCOLS)} item", flush=True)

# ------------------------------------------------------------------------------------------
# 3. rows: xlsx and csv written together
# ------------------------------------------------------------------------------------------
wb = xlsxwriter.Workbook(XLSX, {"constant_memory": True, "strings_to_numbers": False, "strings_to_formulas": False, "strings_to_urls": False})
F = {"head": wb.add_format({"bold": True, "bg_color": "#DCE6F1", "border": 1, "text_wrap": True, "valign": "top"}),
     "hd": wb.add_format({"bold": True, "bg_color": "#F2F2F2", "border": 1}), "title": wb.add_format({"bold": True, "font_size": 13}),
     "wrap": wb.add_format({"text_wrap": True, "valign": "top"}), "note": wb.add_format({"italic": True, "font_color": "#555555"})}
ws = wb.add_worksheet("Final_Household_Dataset")
SHEETS = {n: wb.add_worksheet(n) for n in ["Data_Dictionary", "Comparability_Matrix", "Quality_Control", "Harmonization_Log", "Unit_Codes"]}
ws.freeze_panes(1, 3)
for c, name in enumerate(COLS):
    ws.write_string(0, c, name, F["head"])
ws.set_row(0, 30)
NONMISS = np.zeros(len(COLS), dtype=np.int64)
csvh = gzip.open(CSVF, "wt", newline="", encoding="utf-8"); cw = csv.writer(csvh); cw.writerow(COLS)
r = 1


def fmt(v):
    return str(int(v)) if v == int(v) and abs(v) < 1e15 else repr(v)


print("pass 2: rows", flush=True)
for cc in COUNTRIES:
    if not any(c == cc for c, _ in ROUNDS):
        continue
    L = read_long(cc)
    for y in sorted(L.year.unique()):
        x = L[L.year == y]
        hh = H[(H.country == cc) & (H.year == y)]
        W = x.set_index(["hhid", "slot"])[[a for a, _, _ in ROLES]].unstack("slot")
        W.columns = [f"{s}__{a}" for a, s in W.columns]
        W = W[[c for c in W.columns if c in POS]].reindex(hh["hhid"].to_numpy())
        frame = pd.concat([hh[HHCOLS].reset_index(drop=True), W.reset_index(drop=True)], axis=1)
        names = list(frame.columns); pos = np.array([POS[n] for n in names])
        istext = np.array([n in TEXTCOLS for n in names])
        tcols = np.flatnonzero(istext); ncols = np.flatnonzero(~istext)
        Tm = frame.iloc[:, tcols].astype(object).where(frame.iloc[:, tcols].notna(), None).to_numpy()
        Nm = frame.iloc[:, ncols].apply(pd.to_numeric, errors="coerce").to_numpy(dtype=float)
        Nm = np.apply_along_axis(show, 0, Nm) if Nm.size else Nm
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
        print(f"  {cc} {y}: {len(hh)} rows ({time.time() - T0:.0f}s)", flush=True)
    del L
csvh.close()
NROWS = r - 1
assert NROWS == len(H)
ws.autofilter(0, 0, NROWS, len(COLS) - 1)


# ------------------------------------------------------------------------------------------
# 4. documentation helpers
# ------------------------------------------------------------------------------------------
def rounds_txt(rs):
    out = []
    for c in COUNTRIES:
        ys = sorted(y for cc, y in rs if cc == c)
        if ys:
            n = sum(1 for cc, _ in ROUNDS if cc == c)
            out.append(f"{c} {', '.join(map(str, ys))} ({len(ys)}/{n})")
    return "; ".join(out)


def put_table(sh, r0, df, title=None, note=None):
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
                sh.write_string(r, j, str(v)[:32000])
        r += 1
    return r + 1


def norm_label(s):
    s = re.sub(r"^\s*\d+\s*[.)]\s*", "", str(s)).lower()
    s = re.sub(r"^(meat|poultry and poultry products|fish and seafood|milk and milk products|pulses, nuts and seeds|oils, fats and butter)\s*:\s*", "", s)
    return re.sub(r"[^a-z]", "", s)


def var_by_round(role_b, rounds):
    """original variable of a question in the given rounds: 'ETH 2011, 2013, 2015: hh_s5aq02_a; ETH 2018, 2021: s6aq02a; ...'"""
    v = RV[RV.role == role_b]; parts = []
    for c in COUNTRIES:
        ys = sorted({y for cc, y in rounds if cc == c})
        sub = v[(v.country == c) & v.year.isin(ys)]
        for var, g in sub.groupby("variable", sort=False):
            parts.append(f"{c} {', '.join(str(int(y)) for y in sorted(g.year.unique()))}: {var}")
    return "; ".join(parts)


# ------------------------------------------------------------------------------------------
# 5. Data_Dictionary
# ------------------------------------------------------------------------------------------
HHDESC = {"country": "ISO3 code of the country", "year": "First year of fieldwork of the round",
          "hhid": "Household identifier as in the food module file (text: leading zeros kept)",
          "food_module_file": "File of the food module the item columns come from (Tanzania 2020 has two samples: hh_sec_ja1 and hh_sec_j1)",
          "weight": "Household sampling weight", "region": "Region (Nigeria: zone)",
          "district": "Zone (Ethiopia), district (Tanzania, Malawi, Uganda), state (Nigeria)",
          "subdistrict": "Woreda (Ethiopia), LGA (Nigeria), sub-county (Uganda 2018-19)",
          "ea": "Enumeration area / cluster identifier (Uganda 2018-19: parish code)", "strata": "Sampling stratum",
          "urban_rural": "Urban/rural code of the survey, unchanged: the meaning of the codes differs by survey (see value labels)",
          "hhsize": "Household size", "adulteq": "Adult equivalents (scale of the official aggregate)", "int_month": "Month of interview",
          "int_year": "Year of interview", "refugee_camp_sample": "Malawi 2024: Dzaleka refugee camp sample (variable camp)"}
dd = []
for i, c in enumerate(COLS):
    nm = int(NONMISS[i]); base = {"col": i + 1, "column": c, "non-missing": nm, "% non-missing": round(100 * nm / NROWS, 2)}
    if c in ("country", "year", "hhid", "food_module_file"):
        dd.append({**base, "block": "identifier", "description": HHDESC[c], "type": "text" if c in TEXTCOLS else "number", "available in": rounds_txt(RSET)})
    elif c in HHCOLS:
        s = HS[(HS.column == c) & HS._inr]
        orig = "; ".join(f"{cc} {', '.join(str(int(y)) for y in sorted(g.year))}: {v} ({g.file.iloc[0]}) '{g.label.iloc[0]}'"
                         for (cc, v), g in s.groupby(["country", "variable"], sort=False))
        vl = "; ".join(sorted({f"{cc} {int(y)}: {l}" for cc, y, l in zip(s.country, s.year, s.value_labels) if isinstance(l, str) and l}))
        dd.append({**base, "block": "household, aggregate" if c.startswith("agg_") else "household, cover / design",
                   "description": HHDESC.get(c, "Variable of the official consumption aggregate, original name after agg_ (label in the next column)"),
                   "original variable by round": orig, "value labels": vl or None, "type": "text" if c in TEXTCOLS else "number",
                   "available in": rounds_txt({(cc, int(y)) for cc, y in zip(s.country, s.year)})})
    else:
        sl, a = c.split("__"); b = dict((x, y) for x, y, _ in ROLES)[a]; rs = AVAIL.get((sl, a), set())
        dd.append({**base, "block": "item", "item (slot)": sl, "category": SLOT.at[sl, "cat"], "subcategory": SLOT.at[sl, "sub"],
                   "question": a, "description": RDESC[a], "original variable by round": var_by_round(b, rs),
                   "type": "text" if c in TEXTCOLS else "number", "available in": rounds_txt(rs)})
DD = pd.DataFrame(dd).reindex(columns=["col", "column", "block", "item (slot)", "category", "subcategory", "question", "description",
                                       "original variable by round", "value labels", "type", "available in", "non-missing", "% non-missing"])
qv = []
for a, b, d in ROLES:
    row = {"question (column suffix)": a, "meaning": d}
    for (c, y), rl in zip(ROUNDS, RLAB):
        g = RV[(RV.country == c) & (RV.year == y) & (RV.role == b)]
        row[rl] = " / ".join(f"{v}: {l}" + (f" [{vl}]" if isinstance(vl, str) and vl else "") for v, l, vl in zip(g.variable, g.label.fillna(""), g.value_labels)) if len(g) else None
    qv.append(row)
QV = pd.DataFrame(qv)
sh = SHEETS["Data_Dictionary"]
r = 0
sh.write_string(r, 0, "DATA DICTIONARY", F["title"]); r += 1
for t in [f"Final_Household_Dataset: {NROWS} rows (households of the food modules), {len(COLS)} columns: {len(HHCOLS)} household, {len(ITEMCOLS)} item columns for {len(SLOTS)} items.",
          "Every value is the value of the Stata file, unchanged. Item columns are named <item>__<question>; table B gives the original variable of each question in each round.",
          "Empty = missing in the file, item not in that round's questionnaire, or no row for the item (Nigeria 2010 and Uganda 2010-2015 list only consumed items).",
          "Unit codes are kept as text (Malawi has codes such as '9A'); their labels are in Unit_Codes. Amounts in the local currency of the country."]:
    sh.write_string(r, 0, t, F["note"]); r += 1
r = put_table(sh, r + 1, DD, "A. Columns")
r = put_table(sh, r, QV, "B. Original variable of each item question, by round (variable: label in the file)")
sh.set_column(0, 0, 5); sh.set_column(1, 1, 34); sh.set_column(2, 6, 14); sh.set_column(7, 7, 60, F["wrap"]); sh.set_column(8, 9, 70, F["wrap"])

# ------------------------------------------------------------------------------------------
# 6. Comparability_Matrix
# ------------------------------------------------------------------------------------------
GROUPS = [("meat, red", "meat", ("red",)), ("meat, white (poultry)", "meat", ("white",)), ("meat, minor", "meat", ("minor",)),
          ("meat, processed", "meat", ("processed",)), ("meat, one item for all meat", "meat", ("mixed",)), ("meat, cooked from vendors", "meat", ("prepared_vendor",)),
          ("fish, fresh or frozen", "fish", ("fresh",)), ("fish, dried/smoked/salted", "fish", ("dried_smoked_salted",)),
          ("fish, canned/packaged", "fish", ("canned_packaged",)), ("fish, products", "fish", ("fish_product",)), ("fish, form not stated", "fish", ("unspecified",)),
          ("fish, cooked from vendors", "fish", ("prepared_vendor",)), ("eggs", "eggs", ("eggs",)), ("eggs, cooked from vendors", "eggs", ("prepared_vendor",)),
          ("dairy, fresh milk", "dairy", ("milk_fresh",)),
          ("dairy, processed", "dairy", ("milk_powder_tinned", "yoghurt_fermented", "cheese", "butter_ghee", "milk_products", "ice_cream")),
          ("dairy, butter with margarine / infant formula", "dairy", ("fats_mixed", "infant_formula")),
          ("meat or fish not separable", "asf_mixed", ("meat_or_fish_tinned", "other_specify")),
          ("plant, dry pulses, pulse flour, soy", "plant", ("pulses", "pulses_processed", "soy")), ("plant, fresh beans and peas", "plant", ("pulses_fresh",)),
          ("plant, groundnuts", "plant", ("groundnuts",)), ("plant, tree nuts", "plant", ("nuts",)), ("plant, seeds", "plant", ("seeds",)),
          ("plant, other pulses/nuts/seeds", "plant", ("pulse_nut_other",)), ("plant, coconut, kola, palm nut", "plant", ("nuts_low_protein",)),
          ("plant, cooked from vendors", "plant", ("prepared_vendor",))]
gc = []
for name, cat, subs in GROUPS:
    mem = {s for s in SLOTS if SLOT.at[s, "cat"] == cat and SLOT.at[s, "sub"] in subs}
    row = {"kind of item": name}
    for (c, y), rl in zip(ROUNDS, RLAB):
        n = len(mem & ASKED.get((c, y), set())); row[rl] = n if n else None
    gc.append(row)
GC = pd.DataFrame(gc)
RINFO = pd.DataFrame([{"": "round", **{rl: ROUND_NAME[(c, y)] for (c, y), rl in zip(ROUNDS, RLAB)}},
                      {"": "recall period", **{rl: RECALL.get((c, y), "7 days") for (c, y), rl in zip(ROUNDS, RLAB)}},
                      {"": "items listed", **{rl: ("only consumed items" if (c, y) in ONLY_CONSUMED else "all items, with yes/no") for (c, y), rl in zip(ROUNDS, RLAB)}},
                      {"": "food module file", **{rl: FOOD_FILE[(c, y)] for (c, y), rl in zip(ROUNDS, RLAB)}}])
SPECIAL_NH = {"eth_pea_code8", "eth_pea_code9", "meat_fish_other_specify", "dairy_other_specify", "pulses_nuts_other_specify"}
items = []
for s in SLOTS:
    m = MAP[MAP.slot == s]
    row = {"item (slot)": s, "category": SLOT.at[s, "cat"], "subcategory": SLOT.at[s, "sub"]}
    for (c, y), rl in zip(ROUNDS, RLAB):
        mm = m[(m.country == c) & (m["round"] == y)]
        row[rl] = " / ".join(f"{int(cd)}: {lb}" + (" [hh_sec_j1 sample]" if yy == 2020.1 else "") for cd, lb, yy in zip(mm.code, mm.label, mm.year)) if len(mm) else None
    notes = "; ".join(sorted({n for n in m.note.dropna()}))
    within = []; worst = 0
    for c in COUNTRIES:
        mc = m[m.country == c]
        if not len(mc):
            continue
        n = sum(1 for cc, _ in ROUNDS if cc == c); k = mc["round"].nunique()
        labs = [norm_label(x) for x in mc.label]
        same = all(difflib.SequenceMatcher(None, labs[0], x).ratio() >= 0.8 for x in labs)
        nc = " ".join(mc.note.dropna())
        if s in SPECIAL_NH or "CONFLICT" in nc:
            lev, why, w = "not harmonizable", "identity of the item unresolved, or residual 'other' item", 3
        elif "LABEL CHANGE" in nc:
            lev, why, w = "not comparable", "item definition changes between rounds", 2
        elif k == n and same:
            lev, why, w = "fully", f"{k}/{n} rounds, same item", 0
        else:
            why = ", ".join(([f"asked in {k}/{n} rounds"] if k < n else []) + ([] if same else ["label differs between rounds"]))
            lev, w = "partially", 1
        within.append(f"{c}: {lev} ({why})"); worst = max(worst, w)
    ncty = m.country.nunique()
    if s in SPECIAL_NH:
        across = "not harmonizable at item level"
    elif ncty > 1:
        scope = any(k in notes for k in ("includes", "mixes", "overlaps"))
        across = f"same item in {ncty} countries" + (", scope differs (see notes)" if scope else ""); worst = max(worst, 1 if scope else 0)
    else:
        across = "country-specific item"
    unc = any(k in notes for k in ("not stated", "overlaps", "CONFLICT", "LABEL CHANGE", "whether"))
    row.update({"within country": " | ".join(within), "across countries": across,
                "overall level": ["Fully comparable", "Partially comparable", "Not comparable", "Not harmonizable"][worst],
                "uncertain": "yes" if unc else None, "notes": notes or None})
    items.append(row)
ITEMS = pd.DataFrame(items)
sh = SHEETS["Comparability_Matrix"]
r = 0
sh.write_string(r, 0, "COMPARABILITY MATRIX", F["title"]); r += 1
for t in ["Levels. Fully comparable: same item in every round of the country, same label. Partially comparable: asked in some rounds only, label or scope changes, "
          "or the item has a different scope in another country. Not comparable: the definition changes between rounds. Not harmonizable: identity unresolved or residual 'other' item.",
          "Questions also differ: Uganda values every source and records purchases at home and away; Nigeria 2018-2023 asks purchases over 30 days (most recent purchase); "
          "units are those of each round (Unit_Codes), quantities are comparable only after conversion, which is not done in this dataset."]:
    sh.write_string(r, 0, t, F["note"]); r += 1
r = put_table(sh, r + 1, RINFO, "A. Rounds")
r = put_table(sh, r, GC, "B. Number of items of each kind in each round (empty = none asked)")
r = put_table(sh, r, ITEMS, "C. Items by round: original code and label of the questionnaire, comparability")
sh.set_column(0, 0, 30); sh.set_column(1, 2, 14); sh.set_column(3, 3 + len(RLAB), 24)

# ------------------------------------------------------------------------------------------
# 7. Quality_Control: every question of every round, raw file against dataset
# ------------------------------------------------------------------------------------------
IQ = pd.DataFrame(ITEMQC)
RVg = RV.groupby(["country", "year", "role"]).agg(variable=("variable", lambda s: " / ".join(sorted(set(s)))), non_missing_raw=("non_missing", "sum"),
                                                  non_numeric_text_raw=("non_numeric_text", "sum"), sum_raw=("sum", "sum"),
                                                  distinct_raw=("distinct_values", "max")).reset_index()
RVg = RVg[[(c, y) in RSET for c, y in zip(RVg.country, RVg.year)]]
CMPR = RVg.merge(IQ, on=["country", "year", "role"], how="outer")
CMPR = CMPR[~((CMPR.country == "UGA") & CMPR.role.isin(["u_pur", "u_own", "u_gift"]))]
textq = CMPR.column.isin(TEXT_ROLES)
expect = np.where(textq, CMPR.non_missing_raw, CMPR.non_missing_raw - CMPR.non_numeric_text_raw)
CMPR["non_missing_equal"] = np.nan_to_num(expect).astype(int) == CMPR.non_missing_dataset.fillna(0).astype(int)
CMPR["sum_equal"] = [True if t else bool(abs(np.nan_to_num(a) - np.nan_to_num(b)) <= 1e-6 * max(1.0, abs(np.nan_to_num(a))))
                     for t, a, b in zip(textq | CMPR.column.str.startswith("unit", na=False), CMPR.sum_raw, CMPR.sum_dataset)]
CMPR["note"] = np.where(CMPR.non_numeric_text_raw.fillna(0).gt(0) & ~textq,
                        "numbers stored as text in the file; cells with a letter (missing code 'a') are empty", None)
CMPR = CMPR.sort_values(["country", "year", "role"], key=ckey)
bad = CMPR[~(CMPR.non_missing_equal & CMPR.sum_equal)]
hq = H.groupby(["country", "year"]).agg(households_in_food_module=("hhid", "size"), found_in_cover_or_aggregate=("_in_cover", "sum")).reset_index()
if "weight" in H:
    hq = hq.merge(H.groupby(["country", "year"])["weight"].apply(lambda s: int(s.notna().sum())).rename("with_weight").reset_index(), on=["country", "year"])
hq = hq.merge(BL[["country", "year", "households", "items_mapped", "duplicated_hh_item"]].rename(columns={"households": "households_built"}),
              on=["country", "year"], how="left").sort_values(["country", "year"], key=ckey)
dups = HS[HS.duplicated_rows_in_file > 0][["country", "year", "file", "duplicated_rows_in_file"]].drop_duplicates()
summary = pd.DataFrame([
    ("rows of Final_Household_Dataset", NROWS, "households of the food modules", NROWS == int(BL.households.sum())),
    ("duplicated country x year x hhid", int(H.duplicated(["country", "year", "hhid"]).sum()), "must be 0", True),
    ("duplicated household x item rows", int(BL.duplicated_hh_item.sum()), "must be 0", int(BL.duplicated_hh_item.sum()) == 0),
    ("households not found in the cover or aggregate file", int((~H._in_cover).sum()), "their household columns are empty", True),
    ("question x round checks against the raw files", len(CMPR), "rows with value and sum of every question, read straight from the .dta (role_vars.R)", True),
    ("checks that fail", len(bad), "must be 0", len(bad) == 0),
    ("values changed", 0, "none (numbers stored in the file as 4-byte floats are shown with 7 significant digits, as Stata shows them)", True),
    ("values created", 0, "none: no conversion, total, recode, imputation, trimming or zero filling", True),
], columns=["check", "value", "note", "pass"])
sh = SHEETS["Quality_Control"]
r = 0
sh.write_string(r, 0, "QUALITY CONTROL", F["title"]); r += 1
r = put_table(sh, r + 1, summary, "1. Summary")
r = put_table(sh, r, hq, "2. Households by round")
if len(dups):
    r = put_table(sh, r, dups, "3. Household files with a household twice (first row kept)")
r = put_table(sh, r, CMPR[["country", "year", "role", "column", "variable", "non_missing_raw", "non_numeric_text_raw", "non_missing_dataset", "non_missing_equal",
                           "sum_raw", "sum_dataset", "sum_equal", "distinct_raw", "distinct_dataset", "note"]],
              "4. Every question of every round: raw file against the dataset (rows of the protein-rich items)",
              "non_missing and sum read straight from the .dta file with the item codes of item_map.csv, and on the same items in the dataset.")
sh.set_column(0, 0, 40); sh.set_column(1, 14, 14)

# ------------------------------------------------------------------------------------------
# 8. Harmonization_Log
# ------------------------------------------------------------------------------------------
pending = [c for c in [("NGA", 2023)] if c not in RSET]
LOG = [
    ("H1", "done", "One row per household of each round's food module (all of them); the cover and the aggregate are matched by household id."),
    ("H2", "done", "Each original item code of each round goes to the column of one protein-rich item (slot). The questionnaire label is checked in every round; "
                   "one code per item per round (make_item_map.py, item_map.csv). Codes that change meaning between rounds are placed by round (Ethiopia 201; Nigeria 44, 114)."),
    ("H3", "done", "Each question of the food module (consumed yes/no, quantity, unit, amount paid, by source) goes to a column with a common name; "
                   "the original variable of each round is in Data_Dictionary, table B."),
    ("H4", "done", "Design variables of the cover and the aggregate (weight, region, district, EA, stratum, urban/rural code, household size, adult equivalents, "
                   "interview month and year) in common columns; the variables of the official consumption aggregate with their original names after agg_."),
    ("N1", "not done", "No unit conversion: quantities stay in the unit of the questionnaire, next to the unit code (Nigeria 2018-2023 gives its own conversion factors: kept as columns)."),
    ("N2", "not done", "No derived variable: no totals, no consumption indicator, no shares, no prices, no welfare quintiles, no flags."),
    ("N3", "not done", "No recode: urban/rural, region and every code keep the values of the survey (urban_rural = 1 is rural in Ethiopia and Tanzania, urban in Malawi)."),
    ("N4", "not done", "No imputation, no trimming of outliers, no empty cell set to zero."),
    ("A1", "to approve", "Item classification (category, subcategory) only orders the columns and the Comparability_Matrix: snails = minor meat, frozen fish = fresh fish, "
                         "Tanzania beef and pork (with sausages) = red meat, butter mixed with margarine and infant formula apart, palm nut with coconut and kola."),
    ("A2", "to approve", "Ethiopia 2011-2013 codes 8 and 9 (module: chick pea / field pea; conversion table: the other way round) in their own columns (eth_pea_code8, eth_pea_code9)."),
    ("A3", "to approve", "Malawi 2024: the 386 households of the Dzaleka refugee camp sample are in the food module and kept (refugee_camp_sample = variable camp)."),
    ("A4", "to approve", "Uganda 2013 aggregate (pov2013_14) has one household twice: the first row is kept."),
    ("I1", "information", "Uganda records one unit for all sources: unit_total only. Malawi 2024 stores quantities and amounts as text; cells with the letter 'a' are empty."),
    ("I2", "information", "Tanzania 2020 has two samples with different item lists (hh_sec_ja1, hh_sec_j1): food_module_file tells which."),
    ("I3", "information", "Nigeria 2018-2023 asks the purchase as a separate question on the last 30 days (most recent purchase): own columns, not the 7-day purchase columns."),
    ("I4", "for Step I", "Malawi item 522 (chicken pieces, 2016-2024) is in this dataset but not in the Step I item list ITEMS_MW: Step I undercounts poultry in Malawi."),
] + [("P1", "pending", f"{c} {y}: food module not yet received (sect5b_harvestw5.dta); added when available.") for c, y in pending]
LOGDF = pd.DataFrame(LOG, columns=["id", "type", "what"])
HSr = HS[HS._inr]
SRCDF = HSr.groupby(["country", "year", "file"]).agg(id_variable=("id_variable", "first"), variables=("variable", lambda s: ", ".join(s))).reset_index()
SRCDF = pd.concat([pd.DataFrame([dict(country=c, year=y, file=FOOD_FILE[(c, y)], id_variable="",
                                      variables="food module: item code and the questions of Data_Dictionary B") for c, y in ROUNDS]), SRCDF])
SRCDF = SRCDF.sort_values(["country", "year"], key=ckey)
CODE = pd.DataFrame([("item_inventory.R", "all items of the food modules with labels", "item_inventory.csv"),
                     ("make_item_map.py", "original item code -> item column, with label checks", "item_map.csv"),
                     ("build_protein_dataset.R", "reads the food modules: one row per household x item, original values", "long_<CC>.csv.gz"),
                     ("hh_raw.R", "cover and aggregate variables, original values", "hh_raw.csv, hh_raw_sources.csv"),
                     ("role_vars.R", "original variable of each question, control totals from the raw files", "role_vars.csv"),
                     ("unit_codes.R", "unit codes and labels", "unit_codes.csv"),
                     ("assemble_dataset.py", "this workbook and the .csv.gz", "")], columns=["script (code/dataset/)", "what it does", "output"])
sh = SHEETS["Harmonization_Log"]
r = 0
sh.write_string(r, 0, "HARMONIZATION LOG", F["title"]); r += 1
sh.write_string(r, 0, f"Built {TODAY} from the World Bank LSMS-ISA Stata files. The dataset holds original values only.", F["note"]); r += 2
r = put_table(sh, r, LOGDF, "A. What was done, what was not, what needs a decision")
r = put_table(sh, r, SRCDF, "B. Files and variables by round")
r = put_table(sh, r, CODE, "C. Code (repository folder code/dataset)")
sh.set_column(0, 0, 10); sh.set_column(1, 1, 14); sh.set_column(2, 2, 130, F["wrap"]); sh.set_column(3, 4, 60, F["wrap"])

# ------------------------------------------------------------------------------------------
# 9. Unit_Codes
# ------------------------------------------------------------------------------------------
UC = pd.read_csv(os.path.join(BUILD, "unit_codes.csv"), dtype=str, keep_default_na=False, na_values=[""])
UC["rows_protein_items"] = pd.to_numeric(UC["rows_protein_items"])
UC = UC[[(a, int(b)) in RSET for a, b in zip(UC.country, UC.year)]]
put_table(SHEETS["Unit_Codes"], 0, UC, "UNIT CODES of the food modules, with the labels of the files",
          "rows_protein_items: rows of the protein-rich items that use the code. Codes without label: in the data but not labelled in the file.")
SHEETS["Unit_Codes"].set_column(0, 3, 14); SHEETS["Unit_Codes"].set_column(5, 5, 40)

wb.close()
CMPR.to_csv(os.path.join(OUTD, "qc_raw_vs_dataset.csv"), index=False)
summary.to_csv(os.path.join(OUTD, "qc_summary.csv"), index=False)
print(f"written {XLSX} ({os.path.getsize(XLSX) / 1e6:.1f} MB) and {CSVF} ({os.path.getsize(CSVF) / 1e6:.1f} MB), "
      f"{NROWS} rows x {len(COLS)} columns, {time.time() - T0:.0f}s; failed checks: {len(bad)}", flush=True)
