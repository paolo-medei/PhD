#!/usr/bin/env python3
"""
Every food item of the 7-day food modules -> one harmonized category (24 Nov 2026).

Categories decided with Paolo (24 Nov 2026):
  - the 17 protein columns of the wide dataset, unchanged (wide_items.csv);
  - 9 new ones: cereals, starches, sugar_sweets, vegetables, fruits, oils_fats, spices_other, beverages
    (alcoholic drinks included, B1 b), other_food;
  - excluded from the food budget: tobacco (B2), food away from home (B3 b: restaurant items, Malawi cooked
    foods from vendors), and the items already left out of the protein columns (C3: butter-margarine,
    insects, snails, wild birds, tinned meat or fish, "other (specify)" pulses/nuts and meat/fish);
  - coconut -> fruits, kola nut -> spices_other (C2).
Ethiopia 2011 and 2013 stay out (single item for all meat, decision of 23 Nov).

The output is the review table: one row per item x round, with the households reporting the item and its
share of the round's 7-day purchase value (raw, all items of the module), so the weight of each decision is visible.

usage: food_categories_map.py <item_inventory.csv> <item_map.csv> <item_classification.csv> <wide_items.csv>
                              <item_hh_counts.csv> <module_households.csv> <out.csv>
"""
import re, sys
import pandas as pd

INV, MAPF, CLASSF, WIDEF, CNTF, MODHH, OUT = sys.argv[1:8]

inv = pd.read_csv(INV)
inv = inv[~((inv.country == "ETH") & inv.year.isin([2011, 2013]))].copy()
mp = pd.read_csv(MAPF)[["country", "year", "code", "slot"]]
cl = pd.read_csv(CLASSF).set_index("item_detail")["item"]
wi = pd.read_csv(WIDEF)
i2w = wi[~wi["item"].str.startswith("detail:")].set_index("item")["wide_item"].to_dict()
dov = {r["item"][7:]: r["wide_item"] for _, r in wi[wi["item"].str.startswith("detail:")].iterrows()}
cnt = pd.read_csv(CNTF)[["country", "year", "code", "hh_consuming", "purchase_value_sum"]]
x = inv.merge(mp, on=["country", "year", "code"], how="left").merge(cnt, on=["country", "year", "code"], how="left")
x[["hh_consuming", "purchase_value_sum"]] = x[["hh_consuming", "purchase_value_sum"]].fillna(0)

## Uganda 2018: some codes have no value label; take the label of the same code in the nearest other round
x["label_source"] = ""
for i in x.index[x.label.isna()]:
    o = x[(x.country == x.at[i, "country"]) & (x.code == x.at[i, "code"]) & x.label.notna()]
    if len(o):
        j = (o.year - x.at[i, "year"]).abs().idxmin()
        x.at[i, "label"], x.at[i, "label_source"] = o.at[j, "label"], f"label taken from {int(o.at[j, 'year'])}"

## households per round (TZA 2020: two files, two samples)
mh = pd.read_csv(MODHH, usecols=["hhid", "country", "year"], dtype={"hhid": str})
nhh = mh.groupby(["country", "year"]).hhid.nunique().to_dict()
nhh_tza20 = {"hh_sec_ja1": x[(x.country == "TZA") & x.file.str.contains("hh_sec_ja1")].rows.max(),
             "hh_sec_j1": x[(x.country == "TZA") & (x.year == 2020.1)].rows.max()}

## protein items: the wide dataset's column, or the reason they are left out
PROT_OUT = {"prepared_food": ("excluded", "food away from home: cooked food from vendors (B3)"),
            "butter_margarine": ("excluded", "butter-margarine, left out of the protein columns (C3)"),
            "insects": ("excluded", "insects, left out (C3)"), "snails": ("excluded", "snails, left out (C3)"),
            "wild_birds_insects": ("excluded", "wild birds and insects, left out (C3)"),
            "meat_fish_canned": ("excluded", "tinned meat or fish (one item), left out (C3)"),
            "animal_other": ("excluded", "other (specify) meat/fish, left out (C3)"),
            "pulses_nuts_seeds_other": ("excluded", "other (specify) pulses/nuts/seeds, left out (C3)"),
            "coconut": ("fruits", "coconut -> fruits (C2)"), "kola_nut": ("spices_other", "kola nut -> spices and other (C2)")}
PREP = {"prepared_meat", "prepared_chicken", "prepared_fish", "prepared_eggs", "prepared_groundnuts"}

## non-protein items: code overrides first, then label rules in this order (first match wins)
OVR = {("MWI", 117): ("cereals", "'Other (specify)' of the cereals section"),
       ("MWI", 209): ("starches", "'Other (specify)' of the roots-tubers section"),
       ("MWI", 414): ("vegetables", "'Other (specify)' of the vegetables section"),
       ("MWI", 610): ("fruits", "'Other (specify)' of the fruits section"),
       ("MWI", 804): ("other_food", "'Other (specify)' of the sugar-fats-oil section: cannot tell sugar from oil"),
       ("MWI", 818): ("spices_other", "'Other (specify)' of the spices-miscellaneous section"),
       ("MWI", 916): ("beverages", "'Other (specify)' of the beverages section"),
       ("NGA", 95): ("processed_red_meat", "canned beef / corned beef (no rows in 2023)"),
       ("UGA", 118): ("pork", "parent code: households report the sub-codes 1181-1183"),
       ("UGA", 121): ("poultry", "parent code: households report the sub-codes 1211-1215")}
RULES = [
    ("excluded:tobacco", r"cigar|tobacco"),
    ("excluded:fafh", r"restaurant|vendor|meal eaten"),
    ("excluded:c3", r"margarine"),
    ("excluded:khat", r"\bchat\b|\bkat\b|khat"),
    ("other_food", r"infant|baby"),
    ("spices_other", r"yeast|baking"),
    ("vegetables", r"dried peppers?|dry pepper"),
    ("beverages", r"juice|chocolate drink|malt drink|soft drink|\bdrinks?\b|\bsoda|\bwater\b(?!\s*melon)|bottelled water|\btea\b|\bcoffee|cocoa|milo|\bbeer|brew|\bwine\b|spirit|\bgin\b|waragi|liquor|kachasu|chibuku|masese|thobwa|maheu|squash|\btella\b|\bpito\b|burkutu|alcoh|alchol|gesho|\bhops\b|zobo|kunu"),
    ("sugar_sweets", r"honey|\bjams?\b|jelly|jellies|marmalade|mamalede|syrup|sweets|candy|chocolate|confection|\bsugar|freezes"),
    ("oils_fats", r"\boils?\b|shea ?butter|animal fat|\bfats?\b"),
    ("spices_other", r"salt|spice|condiment|berbere|red pepper|ground pepper|grinded pepper|hot sauce|tomato sauce|maggi|ginger"),
    ("vegetables", r"leaves|leafy"),
    ("starches", r"cassava|sweet ?potato|\byams?\b|yarms|cocoyam|potato|plantain|cooking banana|matooke|kocho|\bbula\b|godere|\bgari\b|fufu|arrow ?root|other starches|roots and tuber|tuber or stem|muruchi|kabalagala|pancake"),
    ("fruits", r"banana|orange|citrus|tangerine|naartje|lemon|lime|mango|papaya|pawpaw|avocado|guava|pineapple|apple|passion|melon|jackfruit|peach|wild fruit|\bfruits?\b|fruites|agbalumo|cherry|\bpear\b|\bdate\b|cashew fruit"),
    ("vegetables", r"onion|tomato|cabbage|kale|spinach|rape|tanaposi|nkhwani|okra|therere|pumpkin|cucumber|carrot|beet|egg ?plant|garden egg|aubergine|pepper|chili|garlic|mushroom|moringa|dodo|nakati|vegetable|viungo|chiness|baobab|kuka"),
    ("cereals", r"teff|wheat|barley|maize|\bcorn|sorghum|millet|\brice\b|oats|cereal|grain|injera|bread|loaf|\bbuns?\b|cake|biscuit|biscuts|scone|muffin|doughnut|pofpof|pasta|macaroni|macaroini|spaghetti|noodle|semo|custard|\bpap\b|akanu|fonio|acha|chapati|samosa|cornflakes|popcorn|meat pie|flour|gramill|\bufa\b|mandazi"),
    ("other_food", r"other foods|other ?\(specify\)|prepared food"),
]
EXCL_WHY = {"tobacco": "tobacco: not food (B2)", "fafh": "food away from home (B3)",
            "c3": "margarine, like butter-margarine in the protein columns (C3)",
            "khat": "khat (chat): stimulant leaf, treated like tobacco - TO CONFIRM"}

def classify(r):
    c, code = r.country, int(r.code)
    lab = re.sub(r"^\s*\d+\.\s*", "", str(r.label)).strip()
    if r.rows == 0 and c == "MWI" and (code % 100 == 0 or code in (809, 819)):
        return "header", "section header of the questionnaire, no data"
    if isinstance(r.slot, str):                                       # protein item of the existing map
        item = cl.get(r.slot)
        w = dov.get(r.slot, i2w.get(item))
        if w:
            return w, "protein column of the wide dataset"
        if item in PREP:
            return "excluded", PROT_OUT["prepared_food"][1]
        return PROT_OUT.get(item, ("excluded", f"protein item {item} not in the columns"))
    if c == "MWI" and 820 <= code <= 838:
        return "excluded", "food away from home: Malawi 'cooked foods from vendors' section (codes 820-838)"
    if c == "UGA" and (157 <= code <= 161 or code == 1603):
        return "excluded", "food away from home: Uganda restaurant block (codes 157-161, 1603; 'in Restaurants' in 2018-2019)"
    if (c, code) in OVR:
        return OVR[(c, code)]
    for cat, rx in RULES:
        if re.search(rx, lab.lower()):
            if cat.startswith("excluded:"):
                return "excluded", EXCL_WHY[cat[9:]]
            return cat, "label rule"
    return "UNCLASSIFIED", "no rule"

res = x.apply(lambda r: pd.Series(classify(r), index=["category", "reason"]), axis=1)
x = pd.concat([x, res], axis=1)
x["round"] = x.year.astype(int)
x["sample"] = [re.sub(r"\.dta$", "", f.split("/")[-1]) if c == "TZA" and int(y) == 2020 else "" for c, y, f in zip(x.country, x.year, x.file)]
x["n_hh_round"] = [nhh_tza20[s] if s else nhh.get((c, int(y)), float("nan")) for c, y, s in zip(x.country, x.year, x["sample"])]
x["pct_hh_consuming"] = 100 * x.hh_consuming / x.n_hh_round
tot = x.groupby(["country", "year"]).purchase_value_sum.transform("sum")
x["pct_purchase_value"] = (100 * x.purchase_value_sum / tot).where(tot > 0)
x["in_data"] = (x.rows > 0) & (x.hh_consuming > 0)
x["status"] = x.category.map(lambda k: "header" if k == "header" else ("excluded" if k == "excluded" else
              ("unclassified" if k == "UNCLASSIFIED" else "in food budget")))
x.loc[~x.in_data & (x.status != "header"), "status"] = "no household reports it"
x["clean_label"] = x.label.astype(str).str.replace(r"^\s*\d+\.\s*", "", regex=True).str.replace(r"\s+", " ", regex=True).str.strip()
x = x[["country", "round", "sample", "code", "clean_label", "label", "label_source", "slot", "category", "status", "reason",
       "hh_consuming", "n_hh_round", "pct_hh_consuming", "pct_purchase_value", "rows", "file"]].rename(
       columns={"slot": "protein_item_detail", "rows": "rows_in_file", "label": "label_original"})
x.to_csv(OUT, index=False)
print(x.groupby("status").size().to_string())
d = x[x.status == "in food budget"]
print(d.groupby("category").size().sort_values(ascending=False).to_string())
u = x[x.status == "unclassified"]
print("unclassified with data:", len(u)); print(u[["country", "round", "code", "clean_label"]].to_string(index=False))
