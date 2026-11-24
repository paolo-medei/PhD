#!/usr/bin/env python3
"""
Excel files of the all-food household budget (24 Nov 2026): one file with all countries and one per country (same columns,
same order), each with Data, README and Dictionary; one documentation workbook with Method, Categories, Item_x_round,
Quality_control, Official_check and Unit_weights.

usage: write_allfood_workbooks.py <_allfood_wide.csv.gz> <_qc.pkl> <official_food.csv> <food_category_map.csv> <_unit_weights.csv> <out dir>
"""
import sys, os, re, datetime, time
import numpy as np, pandas as pd, xlsxwriter

WIDE, QCF, OFFF, MAPF, WTF, OUTD = sys.argv[1:7]
TODAY = datetime.date.today().isoformat(); T0 = time.time()
def log(m): print(f"{m} ({time.time() - T0:.0f}s)", flush=True)
TEXT = {"country", "hhid", "panel_id", "region", "district", "subdistrict", "ea", "strata", "welfare_scale", "welfare_var", "not_collected",
        "sample", "price_source", "food_away_flag"}
D = pd.read_csv(WIDE, dtype={c: str for c in TEXT}, keep_default_na=False, na_values=[""], low_memory=False)
COLS = list(D.columns)
CATS = [c[:-6] for c in COLS if c.endswith("_value") and not c.startswith(("grp_", "food_"))]
GROUPS = [c[4:-6] for c in COLS if c.startswith("grp_") and c.endswith("_value")]
Q = pd.read_pickle(QCF)
CUR = {"ETH": "ETB", "TZA": "TZS", "MWI": "MWK", "NGA": "NGN", "UGA": "UGX"}
NEWC = ["cereals", "starches", "sugar_sweets", "vegetables", "fruits", "oils_fats", "spices_other", "beverages", "other_food"]
GRP = {"red_meat": ["beef", "goat_sheep", "pork", "processed_red_meat", "meat_other"], "poultry": ["poultry"], "fish": ["fish_fresh", "fish_processed"],
       "eggs": ["eggs"], "dairy": ["milk_fresh", "dairy_processed"], "pulses_nuts_seeds": ["pulses_dry", "pulses_fresh", "groundnuts", "soy", "nuts", "seeds"],
       "cereals": ["cereals"], "starches": ["starches"], "fruits_vegetables": ["fruits", "vegetables"], "oils_fats": ["oils_fats"],
       "sugar_sweets": ["sugar_sweets"], "beverages_other": ["beverages", "spices_other", "other_food"]}
UNIT = {c: ("litres (liquid drinks only)" if c == "beverages" else "none" if c in ("spices_other", "other_food") else "kg") for c in CATS}

# ------------------------------------------------------------------------------------------
# README and Dictionary (inside every data file)
# ------------------------------------------------------------------------------------------
README = [
    ("What", "Household food budget for the LA/AIDS demand system: one row per household and round, never repeated. All foods of the 7-day "
             "food module, in 26 categories at home + food away from home. 5 countries, 23 rounds, " + f"{len(D):,} households."),
    ("Rounds", "ETH 2015, 2018, 2021 (2011-2013 left out); TZA 2008, 2010, 2012, 2014, 2020 (two samples, column sample); MWI 2010, 2016, 2019, 2024; "
               "NGA 2010, 2012, 2015, 2018, 2023 (post-harvest visit); UGA 2010, 2011, 2013, 2015, 2018, 2019."),
    ("Values", "Local currency, nominal, 7 days (ETB, TZS, MWK, NGN, UGX). Value = purchases + own production + gifts, valued. "
               "Own production and gifts = quantity x local median unit value of purchases of the same item in the same unit "
               "(enumeration area, else district, else region, else national; at least 5 purchases). Annual = x 365/7."),
    ("Shares", "<category>_share = <category>_value / food_home_value; the 26 shares sum to 1 (food_home_value > 0). "
               "Food away from home is NOT in the shares: food_away_share = food_away_value / food_total_value."),
    ("Imputed", "<category>_value_imp = part of the value imputed (no price, or an outlier set missing). "
                "Sensitivity without imputation: use <category>_value - <category>_value_imp and recompute the shares."),
    ("Quantities", "<category>_qty: kg (litres for beverages: liquid drinks only; none for spices_other and other_food). Empty when one consumed "
                   "item of the category has no quantity. <category>_qty_est = 1: some kilograms estimated from prices (units the survey tables do not convert)."),
    ("Groups", "grp_*: 12 aggregated groups for a smaller system (red meat, poultry, fish, eggs, dairy, pulses-nuts-seeds, cereals, starches, "
               "fruits-vegetables, oils-fats, sugar-sweets, beverages-spices-other)."),
    ("Not in the budget", "Tobacco, khat, kola nut; butter-margarine, insects, snails, wild birds, tinned meat or fish, 'other (specify)' "
                          "meat/fish/pulses (as in the protein dataset). See the documentation file, sheet Categories."),
    ("Empty cells", "A category the questionnaire of the round does not ask is empty (see not_collected), not zero. Households with no food at home "
                    "(they eat only away from home) have food_home_value = 0 and empty shares."),
    ("Nigeria 2018-2023", "No 7-day purchase value in the questionnaire: purchases = quantity consumed from purchases x unit value of the last purchase "
                          "(30 days); column price_source."),
    ("Documentation", f"ASF_food_budget_documentation_{TODAY}.xlsx: method, item-by-item categories, quality control, comparison with the official aggregates."),
]
def dict_rows():
    R = []
    base = {"country": "Country (ETH, TZA, MWI, NGA, UGA)", "year": "Round (first year of fieldwork)", "hhid": "Household identifier of the round",
            "panel_id": "Household identifier across rounds", "weight": "Household sampling weight", "region": "Region code", "district": "District / zone code",
            "subdistrict": "Sub-district code", "ea": "Enumeration area", "strata": "Sampling stratum", "rural": "1 rural, 0 urban", "hhsize": "Household size",
            "adulteq": "Adult equivalents", "int_month": "Interview month", "int_year": "Interview year", "head_female": "1 female head",
            "head_age": "Age of the head", "welfare_annual": "Welfare measure of Step I (annual)", "welfare_scale": "Scale of welfare_annual",
            "welfare_var": "Original variable of welfare_annual", "cons_total_hh_annual": "Total household consumption, annual (official aggregate)",
            "food_cons_hh_annual": "Food consumption, annual (official aggregate; see the protein dataset documentation)",
            "not_collected": "Categories not asked in the questionnaire of the round (their columns are empty), and data problems",
            "sample": "Tanzania 2020: hh_sec_ja1 (4,290 households) or hh_sec_j1 (419); empty elsewhere",
            "price_source": "Prices used for purchases: 7-day purchases, or last purchase in 30 days (Nigeria 2018-2023)",
            "food_home_value": "Food at home: sum of the 26 category values (denominator of the shares)", "food_home_value_imp": "Imputed part of food_home_value",
            "food_away_value": "Food away from home: meals, snacks and drinks bought and consumed away from home (value only, no prices)",
            "food_away_flag": "'not collected' (module missing for the household) or 'outlier set missing' (above 100 x the round's median)",
            "food_total_value": "food_home_value + food_away_value", "food_away_share": "food_away_value / food_total_value", "n_items": "Items consumed at home"}
    for c in COLS:
        if c in base:
            unit = "local currency, 7 days" if c.endswith("_value") or c.endswith("_imp") else ""
            R.append((c, base[c], unit))
            continue
        m = re.match(r"^(grp_)?(.+?)_(value_pur|value_own|value_gift|value_imp|value|qty_est|qty|n_items|share)$", c)
        g, cat, v = m.group(1), m.group(2), m.group(3)
        name = f"group {cat}" if g else cat
        txt = {"value": f"Value consumed at home, {name}", "value_pur": f"Value from purchases, {name}", "value_own": f"Value of own production, {name}",
               "value_gift": f"Value of gifts and other sources, {name}", "value_imp": f"Imputed part of {cat}_value",
               "qty": f"Quantity consumed, {name}", "qty_est": f"1 = some kg of {cat} estimated from prices", "n_items": f"Items of {cat} consumed",
               "share": f"Budget share of {name} in food at home"}[v]
        unit = {"value": "local currency, 7 days", "value_pur": "local currency, 7 days", "value_own": "local currency, 7 days",
                "value_gift": "local currency, 7 days", "value_imp": "local currency, 7 days", "qty": UNIT.get(cat, "") + ", 7 days",
                "qty_est": "0/1", "n_items": "count", "share": "0-1"}[v]
        if g: txt += " (" + " + ".join(GRP[cat]) + ")"
        R.append((c, txt, unit))
    return pd.DataFrame(R, columns=["Column", "Description", "Unit"])
DICT = dict_rows()

# ------------------------------------------------------------------------------------------
# data files
# ------------------------------------------------------------------------------------------
def write_data(df, path):
    wb = xlsxwriter.Workbook(path, {"constant_memory": True, "nan_inf_to_errors": False, "strings_to_numbers": False})
    hd = wb.add_format({"bold": True, "bg_color": "#DDEBF7", "border": 1})
    ws = wb.add_worksheet("Data")
    ws.freeze_panes(1, 3)
    for j, c in enumerate(COLS): ws.write_string(0, j, c, hd)
    textj = [j for j, c in enumerate(COLS) if c in TEXT]
    arr = df[COLS].astype(object).where(df[COLS].notna(), None).to_numpy()
    for i in range(arr.shape[0]):
        row = arr[i]
        for j in range(len(COLS)):
            v = row[j]
            if v is None: continue
            if j in textj: ws.write_string(i + 1, j, str(v))
            else:
                try: ws.write_number(i + 1, j, float(v))
                except (TypeError, ValueError): ws.write_string(i + 1, j, str(v))
    ws2 = wb.add_worksheet("README")
    b = wb.add_format({"bold": True, "valign": "top"}); wr = wb.add_format({"text_wrap": True, "valign": "top"})
    ws2.write(0, 0, f"Household food budget, all foods ({TODAY})", wb.add_format({"bold": True, "font_size": 13}))
    for i, (k, v) in enumerate(README, start=2): ws2.write(i, 0, k, b); ws2.write(i, 1, v, wr)
    ws2.set_column(0, 0, 18); ws2.set_column(1, 1, 130)
    ws3 = wb.add_worksheet("Dictionary")
    for j, c in enumerate(DICT.columns): ws3.write(0, j, c, hd)
    for i, r in enumerate(DICT.itertuples(index=False), start=1):
        for j, v in enumerate(r): ws3.write(i, j, v)
    ws3.set_column(0, 0, 30); ws3.set_column(1, 1, 95); ws3.set_column(2, 2, 28); ws3.freeze_panes(1, 0)
    wb.close()

if os.environ.get("DOC_ONLY") != "1":                     # DOC_ONLY=1: only the documentation workbook
    for cc in ["ETH", "TZA", "MWI", "NGA", "UGA"]:
        write_data(D[D.country == cc], os.path.join(OUTD, f"ASF_food_budget_{cc}_{TODAY}.xlsx")); log(f"{cc} written")
    write_data(D, os.path.join(OUTD, f"ASF_food_budget_{TODAY}.xlsx")); log("all countries written")

# ------------------------------------------------------------------------------------------
# documentation workbook
# ------------------------------------------------------------------------------------------
M = pd.read_csv(MAPF, keep_default_na=False, na_values=[""])
W = pd.read_csv(WTF)
O = pd.read_csv(OFFF, dtype={"hhid": str})
A = 365 / 7
tabs = []                                                  # (title, note, dataframe) of the Quality_control sheet

## 1 rows and households
r = pd.concat(Q["rows"]).fillna(0)
hh = D.groupby(["country", "year"]).agg(households=("hhid", "size"), no_food_at_home=("food_home_value", lambda s: int((s <= 0).sum())),
                                         food_at_home_items_mean=("n_items", "mean")).reset_index()
r = r.merge(hh, on=["country", "year"], how="left")
tabs.append(("1. Rows and households", "Consumed item rows of the food module by type. duplicated_hh_item: the same item twice for a household (Uganda 2013: "
             "7 items recorded twice, in two different units; both rows kept and summed). no_category must be 0. Households with no food at home eat only away from home.",
             r[["country", "year", "households", "consumed_rows", "at_home", "food_away_items", "excluded_items", "no_category", "duplicated_hh_item",
                "no_food_at_home", "food_at_home_items_mean"]].round(1)))
## 2 shares
S = D[[f"{c}_share" for c in CATS]].sum(axis=1, min_count=1)
ok = D.food_home_value > 0
tabs.append(("2. Budget shares sum to 1", "Sum of the 26 shares, households with food at home.",
             pd.DataFrame({"households": [int(ok.sum())], "min_sum": [S[ok].min()], "max_sum": [S[ok].max()], "households_off_by_more_than_1e-9": [int(((S[ok] - 1).abs() > 1e-9).sum())]})))
## 3 valuation
v = pd.concat(Q["valuation"])
def grp(m):
    if m.startswith("imputed"): return "imputed (median of the area, E1)"
    if m == "not valued": return "not valued (no price, nothing to impute from)"
    if m.startswith("outlier unit value"): return "reported, outlier unit value: re-valued at the area price (E2)"
    if "unit value" in m and "household" not in m: return "quantity x area unit value of purchases (D1)"
    if "price per kg" in m: return "kg x area price per kg (when the unit has no price)"
    return m
v["method"] = v.method.map(grp)
t = v.groupby(["country", "source", "method"]).agg(items=("n", "sum"), value=("value", "sum")).reset_index()
t["% of items"] = 100 * t["items"] / t.groupby(["country", "source"])["items"].transform("sum")
t["% of value"] = 100 * t.value / t.groupby(["country", "source"]).value.transform("sum")
t["source"] = t.source.map({"pur": "purchases", "own": "own production", "gift": "gifts", "unk": "source unknown (consumed, no quantity)"})
tabs.append(("3. How each value was obtained", "Item rows with a positive component, by source. Purchases are the amount the household reports paying, "
             "except Nigeria 2012-2015 (quantity consumed from purchases x the household's own unit value) and 2018-2023 (x unit value of the last purchase).",
             t.drop(columns="value").round(1)))
## 4 imputed share
ip = D.groupby(["country", "year"]).apply(lambda d: pd.Series({"food_home_value": d.food_home_value.sum(), "imputed": d.food_home_value_imp.sum()}),
                                          include_groups=False).reset_index()
ip["% imputed"] = 100 * ip.imputed / ip.food_home_value
tabs.append(("4. Imputed part of food at home", "Sum over households (unweighted). Sensitivity: value - value_imp.", ip[["country", "year", "% imputed"]].round(2)))
## 5 outliers
o = pd.concat(Q["outliers"]).fillna({"source": ""})
o = o.groupby(["country", "rule", "source"]).n.sum().reset_index()
tabs.append(("5. Outliers set missing (E2)", "Then re-valued or imputed; food away from home is value only and stays missing.", o))
## 6 quantities
q = pd.concat(Q["quantity"])
q["how"] = q.how.replace({"survey conversion or metric unit": "converted", "metric content stated in the unit label": "converted",
                          "survey weight estimate (Tanzania 2020)": "converted", "estimated from prices (F2)": "estimated from prices",
                          "no quantity for this category or item": "no quantity by design"})
tq = q[q.how != "no quantity by design"].groupby(["category", "how"]).rows.sum().unstack().fillna(0)
tq = (100 * tq.div(tq.sum(axis=1), axis=0)).reindex([c for c in CATS if c in tq.index]).round(1).reset_index()
miss = pd.DataFrame({"category": CATS, "% households with the category but no quantity": [
    100 * ((D[f"{c}_qty"].isna()) & (D[f"{c}_n_items"].fillna(0) > 0)).sum() / max((D[f"{c}_n_items"].fillna(0) > 0).sum(), 1) if c not in ("spices_other", "other_food") else np.nan for c in CATS]})
tabs.append(("6. Quantities: consumed item rows by how the kilograms were obtained (%)", "Units with no conversion: kg per unit = median paid per unit / median price per kg (Unit_weights).",
             tq.merge(miss, on="category", how="left").round(1)))
## 7 food away
fa = D.groupby(["country", "year"]).apply(lambda d: pd.Series({
    "% households with food away": 100 * (d.food_away_value > 0).mean(), "% of food total (sum)": 100 * d.food_away_value.sum() / d.food_total_value.sum(),
    "households not collected": int((d.food_away_flag == "not collected").sum()), "outliers set missing": int((d.food_away_flag == "outlier set missing").sum())}), include_groups=False).reset_index()
src = {"ETH": "food-away module: 5D (2015), 6B4 (2018-2021), 8 meal groups", "NGA": "food-away module 10A (5A in 2023), 9 meal groups",
       "TZA": "section F, individual roster: 7 groups summed over members", "MWI": "food module: cooked foods from vendors (codes 820-838), amount paid",
       "UGA": "food module: restaurant block (157-161, 1603) + 'purchases consumed away from home' of every item"}
fa["source"] = fa.country.map(src)
tabs.append(("7. Food away from home (value only)", "", fa.round(1)))
## 8 official
X = D[["country", "year", "hhid", "weight", "hhsize", "food_home_value", "food_away_value", "food_total_value"]].merge(O, on=["country", "year", "hhid"], how="inner")
pc = X.country == "NGA"                                    # Nigeria's official food aggregates are per person
for c in ["food_home_value", "food_away_value", "food_total_value"]:
    X[c] = X[c] * A / np.where(pc, X.hhsize, 1.0)
def oc(d):
    w = d.weight.fillna(0); m = d.off_home > 0
    return pd.Series({"households matched": len(d),
        "food at home: median ratio": (d.food_home_value / d.off_home)[m].median(),
        "food at home: weighted total ratio": (w * d.food_home_value).sum() / (w * d.off_home).sum(),
        "food away: weighted total ratio": (w * d.food_away_value).sum() / (w * d.off_away).sum() if (d.off_away.fillna(0) > 0).any() else np.nan,
        "official variables": d.off_note.iloc[0]})
oo = X.groupby(["country", "year"]).apply(oc, include_groups=False).reset_index()
tabs.append(("8. Comparison with the official food aggregates (D3)", "Ratio = this dataset (x 365/7) / official. Nigeria: official per person, ours divided by household size. "
             "Malawi 2016-2019: official values are real (deflated), ours nominal. Ethiopia 2015: the official food aggregate is about 30% below ours in every "
             "source (purchases alone, reported amounts, are 77% of it), so the gap comes from the official aggregate, not from our valuation. "
             "Uganda: no food aggregate in the files.", oo.round(2)))
## 9 excluded food
ex = M[M.status == "excluded"].groupby(["country", "round", "reason"]).agg(**{"% households": ("pct_hh_consuming", "max"), "% purchase value": ("pct_purchase_value", "sum")}).reset_index()
tabs.append(("9. Food left out of the budget", "Per item group: max % of households consuming one of its items; % of the round's 7-day purchase value (raw).", ex.round(2)))
## 10 Uganda check
u = pd.concat(Q["check_uga"])
u["valued / reported (sum)"] = u.sum_valued / u.sum_reported
tabs.append(("10. Uganda: own production and gifts valued at purchase prices vs the values households reported", "Items valued at the area unit value and with a reported value. "
             "Purchase prices are above the values households give to their own production (median ratio 1.0-1.1, sum 1.1-1.3).",
             u[["year", "source", "n", "median_ratio", "p25", "p75", "valued / reported (sum)"]].round(2)))
## 11 anomalies
an = pd.DataFrame([["UGA", 2019, "Sugar (code 147): all 3,059 households answer 'no' (67% consume it in 2018). Sugar_sweets is understated in UGA 2019; "
                    "codes 1081/1082 (cassava dry/flour) and 1741-1743 (arrowroot, sugarcane, jackfruit) also change a lot from 2018. Kept as in the file, flagged in not_collected."],
                   ["ETH", 2021, "Tella (code 805): no household reports it (9% in 2018; Tigray not surveyed in 2021). Kept as in the file, flagged in not_collected."]],
                  columns=["country", "year", "problem"])
tabs.append(("11. Data problems found in the files", "", an))

meth = [
    ("1 Items", "All items of the 7-day food module of every round (2,388 item x round codes), each assigned to one category (sheet Categories). "
                "Items no household reports and section headers are listed but carry no data."),
    ("2 Sources", "Purchases, own production, gifts/other sources, as asked by each questionnaire. Uganda's 'purchases consumed away from home' goes to food away from home."),
    ("3 Purchases", "The amount paid for the quantity consumed from purchases (reported). Nigeria 2012-2015 asks the purchase apart: quantity consumed from purchases x "
                    "the household's own unit value (amount paid / quantity bought, same unit), else the area unit value. Nigeria 2018-2023: no 7-day amount; "
                    "quantity consumed from purchases x unit value of the last purchase (30 days) of the same item and unit in the area (A2)."),
    ("4 Unit values (D1 b, D2 a)", "Amount paid / quantity bought, by item and unit (with its size code where the survey has one). Median at the enumeration area "
                                   "if at least 5 purchases, else district, region, national. Unit values outside 1/10-10 times the national median of the item and unit are dropped (E2)."),
    ("5 Own production and gifts", "Quantity x the area median unit value of the same item in the same unit. If the unit has no price: kg x area median price per kg "
                                   "of the item. Uganda: if neither exists, the value the household reported (D1: otherwise only a check, table 10)."),
    ("6 Outliers (E2)", "Reported purchase with an outlier unit value: re-valued at the area unit value. Any value above 100 times the national median of the "
                        "item and source: set missing."),
    ("7 Imputation (E1 a)", "Missing value -> median value of the same item and source among households of the same area (same hierarchy). Consumed with no "
                            "quantity at all -> median total value of the item. The imputed part is kept in <category>_value_imp."),
    ("8 Quantities (F)", "Survey conversion tables and metric units as in the protein dataset (Ethiopia Food_CF; Malawi 2020 table; Nigeria conversion tables and "
                         "the file's kg factor 2018-2023; Tanzania 2020 weight estimates; Uganda unit labels). Remaining units: kg per unit from prices "
                         "(median paid per unit / median price per kg of the item, round level, else all rounds with the same unit code and label), flagged _qty_est. "
                         "Milk and liquid dairy litres x 1.03; eggs 55 g; beverages in litres, liquid drinks only."),
    ("9 Food away from home (B3 a)", "Value only, no prices, no quantity, not in the shares. Sources in Quality_control table 7. Above 100 x the round's median: missing."),
    ("10 Shares (H3)", "Denominator = food_home_value, the sum of the 26 categories. 12 groups (grp_*) for a smaller system (H2 a)."),
    ("11 Not in the budget", "Tobacco (B2), khat and kola nut (stimulants), C3 items. Ethiopia 2011-2013 out (one item for all meat)."),
    ("12 Code", "github.com/paolo-medei/PhD, code/dataset: food_categories_map.py, build_allfood_long.R (with build_protein_dataset.R), build_allfood_dataset.py, "
                "official_food_aggregates.R, write_allfood_workbooks.py. No household data in the repository."),
]
DOC = os.path.join(OUTD, f"ASF_food_budget_documentation_{TODAY}.xlsx")
with pd.ExcelWriter(DOC, engine="xlsxwriter") as w:
    wb = w.book; hd = wb.add_format({"bold": True, "bg_color": "#DDEBF7", "border": 1, "text_wrap": True, "valign": "top"})
    b = wb.add_format({"bold": True, "font_size": 12}); wr = wb.add_format({"text_wrap": True, "valign": "top"}); it = wb.add_format({"italic": True, "text_wrap": True})
    ws = wb.add_worksheet("Method"); w.sheets["Method"] = ws
    ws.write(0, 0, "Method of the household food budget, all foods", b)
    for i, (k, v_) in enumerate(meth, start=2): ws.write(i, 0, k, wb.add_format({"bold": True, "valign": "top"})); ws.write(i, 1, v_, wr)
    ws.set_column(0, 0, 26); ws.set_column(1, 1, 130)
    ## categories
    live = M[M.status.isin(["in food budget", "excluded", "food away from home"])].copy()
    live["item"] = live.clean_label.str.lower().str.replace(r"^.*:", "", regex=True).str.replace(r"\s+", " ", regex=True).str.strip(" .")
    bi = live.groupby(["country", "category", "item"]).agg(codes=("code", lambda s: ", ".join(str(int(c)) for c in sorted(set(s)))),
                                                         rounds=("round", lambda s: ", ".join(str(r_) for r_ in sorted(set(s)))),
                                                         pct_hh=("pct_hh_consuming", "mean"), why=("reason", "first")).reset_index()
    order = {c: i for i, c in enumerate(CATS + ["food_away", "excluded"])}
    bi = bi.assign(k=bi.category.map(order)).sort_values(["country", "k", "pct_hh"], ascending=[True, True, False]).drop(columns="k")
    bi.columns = ["Country", "Category", "Item", "Codes", "Rounds", "% households consuming (mean of rounds)", "Why"]
    bi.round(1).to_excel(w, sheet_name="Categories", index=False)
    ws = w.sheets["Categories"]
    for j, c in enumerate(bi.columns): ws.write(0, j, c, hd)
    for j, wd in enumerate([8, 18, 46, 16, 34, 14, 80]): ws.set_column(j, j, wd)
    ws.freeze_panes(1, 0); ws.autofilter(0, 0, len(bi), len(bi.columns) - 1)
    full = M.sort_values(["country", "round", "sample", "code"])[["country", "round", "sample", "code", "label_original", "category", "status", "reason",
                                                                   "hh_consuming", "pct_hh_consuming", "pct_purchase_value"]]
    full.round(2).to_excel(w, sheet_name="Item_x_round", index=False)
    ws = w.sheets["Item_x_round"]
    for j, c in enumerate(full.columns): ws.write(0, j, c, hd)
    for j, wd in enumerate([8, 7, 12, 7, 46, 18, 22, 70, 12, 11, 11]): ws.set_column(j, j, wd)
    ws.freeze_panes(1, 0); ws.autofilter(0, 0, len(full), len(full.columns) - 1)
    ## quality control: tables one under the other
    ws = wb.add_worksheet("Quality_control"); w.sheets["Quality_control"] = ws
    r0 = 0
    for title, note, df in tabs:
        ws.write(r0, 0, title, b); r0 += 1
        if note: ws.merge_range(r0, 0, r0, 9, note, it); ws.set_row(r0, 15 * max(1, len(note) // 150 + 1)); r0 += 1
        df = df.reset_index(drop=True)
        for j, c in enumerate(df.columns): ws.write(r0, j, str(c), hd)
        for i, row in enumerate(df.itertuples(index=False), start=1):
            for j, val in enumerate(row):
                if isinstance(val, (float, np.floating)) and np.isnan(val): continue
                ws.write(r0 + i, j, val.item() if hasattr(val, "item") else val)
        r0 += len(df) + 3
    ws.set_column(0, 0, 22); ws.set_column(1, 12, 16)
    W.round(4).to_excel(w, sheet_name="Unit_weights", index=False)
    ws = w.sheets["Unit_weights"]
    for j, c in enumerate(W.columns): ws.write(0, j, c, hd)
    ws.set_column(0, 8, 16); ws.freeze_panes(1, 0)
log("documentation written")
print(oo.round(2).to_string())
