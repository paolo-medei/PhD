#!/usr/bin/env python3
"""
Review workbook of the food category mapping (output of food_categories_map.py).

Sheets: Read_me, To_decide, Summary (country x category), By_item (one row per country x item label),
Item_x_round (every item of every round, including excluded items, section headers and items nobody reports).

usage: food_categories_review.py <food_category_map.csv> <out.xlsx>
"""
import re, sys
import pandas as pd

MAPF, OUT = sys.argv[1:3]
x = pd.read_csv(MAPF, keep_default_na=False, na_values=[""])
ORDER = ["beef", "goat_sheep", "pork", "processed_red_meat", "meat_other", "poultry", "eggs", "milk_fresh", "dairy_processed",
         "fish_fresh", "fish_processed", "pulses_dry", "pulses_fresh", "groundnuts", "soy", "nuts", "seeds",
         "cereals", "starches", "sugar_sweets", "vegetables", "fruits", "oils_fats", "spices_other", "beverages", "other_food",
         "excluded", "header"]
rank = {k: i for i, k in enumerate(ORDER)}
x["k"] = x.category.map(rank)

def norm(s):
    s = str(s).lower()
    s = s.split(":")[-1] if ":" in s else s                      # Nigeria: "grain and flours: maize" -> "maize"
    return re.sub(r"\s+", " ", s).strip(" .")

x["item"] = x.clean_label.map(norm)
live = x[x.status.isin(["in food budget", "excluded"])].copy()

## By_item: one row per country x category x item label
bi = (live.groupby(["country", "k", "category", "item"])
      .agg(codes=("code", lambda s: ", ".join(str(int(c)) for c in sorted(set(s)))),
           rounds=("round", lambda s: ", ".join(str(r) for r in sorted(set(s)))),
           pct_hh=("pct_hh_consuming", "mean"), pct_value=("pct_purchase_value", "mean"),
           reason=("reason", "first"))
      .reset_index().sort_values(["country", "k", "pct_hh"], ascending=[True, True, False]).drop(columns="k"))
bi.columns = ["Country", "Category", "Item (label in the questionnaire)", "Codes", "Rounds",
              "% households consuming (mean of rounds)", "% of purchase value (mean of rounds)", "Why"]

## Summary: country x category, mean over rounds of the category's share of 7-day purchase value
rc = live.groupby(["country", "round", "category"]).agg(v=("pct_purchase_value", "sum"), n=("item", "nunique")).reset_index()
nopv = live.groupby(["country", "round"]).pct_purchase_value.apply(lambda s: s.notna().any())
rc = rc[rc.set_index(["country", "round"]).index.map(nopv)]
sm = rc.groupby(["country", "category"]).v.mean().unstack(0)
nit = live.groupby(["country", "category"]).item.nunique().unstack(0)
sm = sm.reindex([c for c in ORDER if c in sm.index])
nit = nit.reindex(sm.index)
summ = pd.concat({"% of purchase value": sm, "Distinct items": nit}, axis=1)

## To_decide
dec = [
    ["1", "Khat (chat), Ethiopia", "ETH 2015 code 25, 2018-2021 code 806",
     "15.6-22.1% of households; 4.2-5.4% of 7-day purchase value",
     "Exclude, like tobacco. It is a stimulant leaf, not food; COICOP puts it with narcotics (02.3), next to tobacco (02.2). "
     "Kept inside the budget it would be the 4th-5th largest category in Ethiopia and would push every other share down.",
     "a) exclude (recommended)   b) beverages   c) other_food"],
    ["2", "Kola nut, Nigeria", "NGA 2015-2023 code 47",
     "9-13% of households; 0.3% of purchase value (2015)",
     "You chose spices_other (C2). Same logic as khat: COICOP lists cola nuts under narcotics (02.3). "
     "I would treat it like khat, whatever you decide for khat. The weight is small either way.",
     "a) same as khat (recommended)   b) keep in spices_other"],
    ["3", "Malawi 'cooked foods from vendors'", "MWI codes 820-838 (boiled maize, chips, mandazi, samosa, vendor meat/fish/eggs, restaurant meal...)",
     "up to 46% of households; about 3% of purchase value",
     "Excluded under your B3 b (food away from home). The World Bank Malawi consumption aggregate counts them as food, so the official "
     "food total will be about 3% above ours; that is expected, not an error. Mucuna (code 837 in 2019-2024) is a pulse and stays in pulses_dry.",
     "a) exclude (B3 b, current)   b) include, in other_food"],
]
dec = pd.DataFrame(dec, columns=["#", "Item", "Where", "How big", "My recommendation", "Options"])
info = pd.DataFrame([
    ["Uganda restaurant block, codes 157-161 (2010-2015) and 1603", "Excluded as food away from home. Evidence: soda and beer appear twice "
     "(151-152 at home, 158-159 again), and in 2018-2019 the same codes are labelled 'in Restaurants'. In 2010-2011 they are 8% of purchase value, in 2013-2019 below 0.3% because they move to the 'away from home' column."],
    ["Uganda 'purchases away from home' column (every item)", "Not counted, consistent with B3 b. Value = purchases for home + own production + gifts."],
    ["Tobacco (Uganda codes 155-156)", "Excluded (B2). In the other countries tobacco is not in the food module."],
    ["Butter-margarine, insects, snails, wild birds, tinned meat or fish, 'other (specify)' meat/fish/pulses", "Excluded (C3), as in the protein columns. "
     "Margarine alone (MWI 703, UGA 129/1291) is excluded for consistency with butter-margarine."],
    ["Malawi 804 'Other (specify)' of the sugar-fats-oil section", "other_food: it cannot be split between sugar and oil (0.1% of households)."],
    ["Malawi 812 yeast, baking powder, bicarbonate of soda", "spices_other."],
    ["Nigeria dried pepper (code 77) / ground pepper (code 144)", "Dried pepper -> vegetables in every round (as in the questionnaire section), ground pepper -> spices_other."],
    ["Nigeria meat pie / sausage roll", "cereals (pastry; 2-4% of households). The meat in it is not separable."],
    ["Ethiopia 'other prepared food consumed at home' / 'other purchased prepared food'", "other_food."],
    ["Infant feeding cereals (Malawi)", "other_food."],
    ["Tanzania 'honey, syrups, jams, marmalade, jellies, canned fruits'", "sugar_sweets (one item in the questionnaire)."],
    ["Uganda 2018 codes without a value label", "Label taken from the same code in 2019; the codes with no label and no household (115, 122, 123, 127, 131, 146, 176) are parent codes."],
], columns=["Item", "What I did"])

readme = [
    ["Food category mapping - for review before building the dataset (24 Nov 2026)"],
    [""],
    ["What it is", "Every food item of the 7-day food module, in every round, assigned to one category. 23 rounds, Ethiopia 2011-2013 left out."],
    ["Categories", "17 protein columns as in the household dataset + cereals, starches, sugar_sweets, vegetables, fruits, oils_fats, spices_other, beverages (alcohol included), other_food. 'excluded' = not in the food budget."],
    ["Check first", "Sheet To_decide: 3 questions. The rest of To_decide lists choices I made; tell me only if you disagree."],
    ["By_item", "One row per country and item label: easiest sheet to scan. Filter by Country or Category."],
    ["Item_x_round", "The full table: every code of every round, including section headers and items no household reports."],
    ["% households", "Households reporting the item in the round / households in the round (TZA 2020: each sample separately)."],
    ["% purchase value", "Item's 7-day purchase value / purchase value of all items in the module, raw values. Only to show the weight of each item. "
     "Not available for Nigeria 2018-2023 (no 7-day purchase value in those rounds)."],
    ["Not yet", "No household values, quantities or shares are built yet. They come after your answers."],
]

with pd.ExcelWriter(OUT, engine="xlsxwriter") as w:
    wb = w.book
    hd = wb.add_format({"bold": True, "bg_color": "#DDEBF7", "border": 1, "text_wrap": True, "valign": "top"})
    wrap = wb.add_format({"text_wrap": True, "valign": "top"})
    p1 = wb.add_format({"num_format": "0.0", "valign": "top"})
    b = wb.add_format({"bold": True, "font_size": 13})

    ws = wb.add_worksheet("Read_me"); w.sheets["Read_me"] = ws
    ws.write(0, 0, readme[0][0], b)
    for i, r in enumerate(readme[2:], start=2):
        ws.write(i, 0, r[0], wb.add_format({"bold": True, "valign": "top"})); ws.write(i, 1, r[1], wrap)
    ws.set_column(0, 0, 18); ws.set_column(1, 1, 120)

    dec.to_excel(w, sheet_name="To_decide", index=False, startrow=1)
    ws = w.sheets["To_decide"]
    ws.write(0, 0, "Questions for you", b)
    for j, c in enumerate(dec.columns): ws.write(1, j, c, hd)
    for j, wd in enumerate([4, 28, 34, 30, 80, 40]): ws.set_column(j, j, wd, wrap)
    r0 = len(dec) + 4
    ws.write(r0 - 1, 0, "Choices I made (answer only if you disagree)", b)
    info.to_excel(w, sheet_name="To_decide", index=False, startrow=r0, startcol=1)
    for j, c in enumerate(info.columns): ws.write(r0, j + 1, c, hd)

    s = summ.copy(); s.columns = [f"{a} - {c}" for a, c in s.columns]; s = s.reset_index().rename(columns={"category": "Category"})
    s.to_excel(w, sheet_name="Summary", index=False, startrow=1)
    ws = w.sheets["Summary"]
    ws.write(0, 0, "Share of 7-day purchase value by category (mean over rounds, raw values, %) and number of distinct items", b)
    for j, c in enumerate(s.columns): ws.write(1, j, c, hd)
    ws.set_column(0, 0, 20); ws.set_column(1, len(s.columns), 14, p1); ws.set_row(1, 30)

    bi.to_excel(w, sheet_name="By_item", index=False)
    ws = w.sheets["By_item"]
    for j, c in enumerate(bi.columns): ws.write(0, j, c, hd)
    for j, wd in enumerate([8, 18, 50, 16, 34, 14, 14, 70]): ws.set_column(j, j, wd, p1 if j in (5, 6) else None)
    ws.freeze_panes(1, 0); ws.autofilter(0, 0, len(bi), len(bi.columns) - 1); ws.set_row(0, 30)

    full = x.sort_values(["country", "round", "sample", "code"])[["country", "round", "sample", "code", "label_original", "label_source",
           "category", "status", "reason", "protein_item_detail", "hh_consuming", "n_hh_round", "pct_hh_consuming", "pct_purchase_value"]]
    full.columns = ["Country", "Round", "Sample (TZA 2020)", "Code", "Label (original)", "Label note", "Category", "Status", "Why",
                    "Protein detail item", "Households consuming", "Households in round", "% households", "% purchase value"]
    full.to_excel(w, sheet_name="Item_x_round", index=False)
    ws = w.sheets["Item_x_round"]
    for j, c in enumerate(full.columns): ws.write(0, j, c, hd)
    for j, wd in enumerate([8, 7, 12, 7, 46, 18, 18, 20, 60, 22, 12, 12, 11, 11]): ws.set_column(j, j, wd, p1 if j in (12, 13) else None)
    ws.freeze_panes(1, 0); ws.autofilter(0, 0, len(full), len(full.columns) - 1); ws.set_row(0, 30)

print(OUT, "| By_item rows:", len(bi), "| Item_x_round rows:", len(full))
print(summ.round(1).to_string())
