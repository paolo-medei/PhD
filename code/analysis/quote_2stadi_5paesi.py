"""Quote di spesa del sistema a due stadi per i 5 paesi (25 nov 2026).

Dalla base alimentare di tutte le voci (_allfood_wide_<data>.csv.gz, valori a 7 giorni a casa: acquisti +
autoconsumo + regali ai prezzi mediani locali) alle quote dei due stadi del LA/AIDS:
  stadio 1: staples, proteins, fruits_veg, other sul budget alimentare a casa
  stadio 2: 9 categorie proteiche (+ processed_red_meat, da classificare) sul budget proteico
Medie semplici delle quote famiglia per famiglia (come le quote medie del modello) e % di famiglie che consumano.
Tanzania 2020: solo il campione hh_sec_ja1, come nel LA/AIDS.
USO  python3 quote_2stadi_5paesi.py <_allfood_wide.csv.gz> <food_category_map.csv> <uscita.xlsx>
"""
import sys
import numpy as np
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

WIDE, MAPF, OUT = sys.argv[1:4]
PAESI = {"ETH": "Etiopia", "MWI": "Malawi", "NGA": "Nigeria", "TZA": "Tanzania", "UGA": "Uganda"}
S1 = {"staples": ["cereals", "starches"], "proteins": None, "fruits_veg": ["fruits", "vegetables"],
      "other": ["oils_fats", "sugar_sweets", "spices_other", "beverages", "other_food"]}
S2 = {"beef": ["beef"], "pork": ["pork"], "sheep_goat_other_meat": ["goat_sheep", "meat_other"], "poultry": ["poultry"],
      "fish": ["fish_fresh", "fish_processed"], "fluid_milk": ["milk_fresh"], "other_dairy": ["dairy_processed"], "eggs": ["eggs"],
      "plant_protein": ["pulses_dry", "pulses_fresh", "groundnuts", "soy", "nuts", "seeds"],
      "processed_red_meat": ["processed_red_meat"]}
NOMI = {"staples": "Staples", "proteins": "Proteine", "fruits_veg": "Frutta e verdura", "other": "Altro",
        "beef": "Manzo", "pork": "Maiale", "sheep_goat_other_meat": "Ovicaprini e altra carne", "poultry": "Pollame", "fish": "Pesce",
        "fluid_milk": "Latte fresco", "other_dairy": "Altri latticini", "eggs": "Uova", "plant_protein": "Proteine vegetali",
        "processed_red_meat": "Carne lavorata (da classificare)"}
CATS = sorted({c for v in list(S1.values()) + list(S2.values()) if v for c in v})

d = pd.read_csv(WIDE, usecols=["country", "year", "hhid", "weight", "sample", "food_home_value"] + [c + "_value" for c in CATS], low_memory=False)
d = d[~((d.country == "TZA") & (d["sample"] == "hh_sec_j1"))].copy()
for k, v in S2.items():
    d["V_" + k] = d[[c + "_value" for c in v]].fillna(0).sum(axis=1)
d["V_proteins"] = d[["V_" + k for k in S2]].sum(axis=1)
for k, v in S1.items():
    if v:
        d["V_" + k] = d[[c + "_value" for c in v]].fillna(0).sum(axis=1)
d["x_food"] = d[["V_" + k for k in S1]].sum(axis=1)
assert np.allclose(d.x_food, d.food_home_value.fillna(0), rtol=1e-9, atol=1e-6), "budget diverso da food_home_value"

# categoria rilevata nel round? (almeno una voce del questionario in quella categoria)
m = pd.read_csv(MAPF, dtype=str)
m = m[m.category != "header"]
ril = {(c, int(y), k): any(((m.country == c) & (m["round"] == y) & m.category.isin(v)).to_numpy())
       for c in PAESI for y in m.loc[m.country == c, "round"].unique() for k, v in S2.items()}


def tabella(g, pesata=False):
    """quote medie e % che consuma per un gruppo di famiglie (un paese, o un paese x round)"""
    f = g[g.x_food > 0]
    if pesata:
        f = f[f.weight.notna() & (f.weight > 0)]                            # famiglie senza peso: fuori dalle medie pesate
    p = f[f.V_proteins > 0]
    wf = f.weight if pesata else pd.Series(1.0, index=f.index)
    wp = p.weight if pesata else pd.Series(1.0, index=p.index)
    r = {"famiglie_cibo": len(f), "famiglie_proteine": len(p)}
    for k in S1:
        r["q1_" + k] = np.average(f["V_" + k] / f.x_food, weights=wf)
        r["c1_" + k] = np.average(f["V_" + k] > 0, weights=wf)
    for k in S2:
        r["q2_" + k] = np.average(p["V_" + k] / p.V_proteins, weights=wp)
        r["c2_" + k] = np.average(p["V_" + k] > 0, weights=wp)
        r["qc_" + k] = np.average(f["V_" + k] / f.x_food, weights=wf)       # quota sul budget alimentare
    return r


righe = []
for (c, y), g in d.groupby(["country", "year"]):
    r = tabella(g)
    r.update(paese=PAESI[c], codice=c, round=int(y))
    for k in S2:
        if not ril[(c, int(y), k)]:
            r["q2_" + k] = r["c2_" + k] = r["qc_" + k] = np.nan           # non rilevata nel questionario
    righe.append(r)
R = pd.DataFrame(righe)
P, PW = [], []
for c, g in d.groupby("country"):
    for pes, lst in ((False, P), (True, PW)):
        r = tabella(g, pesata=pes)
        r.update(paese=PAESI[c], codice=c, round=" ".join(str(int(y)) for y in sorted(g.year.unique())))
        for k in S2:
            if not any(ril[(c, int(y), k)] for y in g.year.unique()):
                r["q2_" + k] = r["c2_" + k] = r["qc_" + k] = np.nan
        lst.append(r)
P, PW = pd.DataFrame(P), pd.DataFrame(PW)
for X in (P, PW):
    # categoria proteica piu' consumata: candidata a equazione residua; categorie consumate da meno del 5%
    X["piu_consumata"] = [NOMI[max([k for k in S2 if k != "processed_red_meat" and pd.notna(x["c2_" + k])], key=lambda k: x["c2_" + k])] for _, x in X.iterrows()]
    X["meno_del_5pct"] = [", ".join(NOMI[k] for k in S2 if k != "processed_red_meat" and pd.notna(x["c2_" + k]) and x["c2_" + k] < 0.05) for _, x in X.iterrows()]

# ---------------------------------------------------------------- Excel
F = "Arial"
TIT, HDR, NOTE = Font(name=F, bold=True, size=12), Font(name=F, bold=True, size=10, color="FFFFFF"), Font(name=F, size=9, italic=True, color="555555")
BODY, BOLD = Font(name=F, size=10), Font(name=F, size=10, bold=True)
FILL_H, FILL_1, FILL_2 = PatternFill("solid", fgColor="1F4E78"), PatternFill("solid", fgColor="DDEBF7"), PatternFill("solid", fgColor="E2EFDA")
GRIGIO = PatternFill("solid", fgColor="F2F2F2")
thin = Side(style="thin", color="BFBFBF")
B = Border(top=thin, bottom=thin, left=thin, right=thin)


wb = Workbook()
wb.remove(wb.active)
STAGE1 = list(S1); STAGE2 = list(S2)
K_P = [("Paese", "paese"), ("Round", "round"), ("Famiglie", "famiglie_cibo")]
K_P2 = [("Paese", "paese"), ("Round", "round"), ("Famiglie con proteine", "famiglie_proteine")]


def blocco(ws, r, titolo, df, pref, cats, chiavi, fill, fmt="0.0%"):
    ws.cell(r, 1, titolo).font = BOLD
    r += 1
    head = [h for h, _ in chiavi] + [NOMI[k] for k in cats]
    for j, h in enumerate(head, 1):
        c = ws.cell(r, j, h); c.font = HDR; c.fill = FILL_H; c.alignment = Alignment(wrap_text=True, horizontal="center", vertical="center"); c.border = B
    ws.row_dimensions[r].height = 32
    for _, x in df.iterrows():
        r += 1
        for j, (_, col) in enumerate(chiavi, 1):
            c = ws.cell(r, j, x[col]); c.font = BODY; c.border = B
            if col.startswith("famiglie"):
                c.number_format = "#,##0"
        for j, k in enumerate(cats, len(chiavi) + 1):
            v = x[pref + k]
            c = ws.cell(r, j); c.font = BODY; c.border = B
            if pd.isna(v):
                c.value = "n.r."; c.fill = GRIGIO; c.alignment = Alignment(horizontal="center")
            else:
                c.value = float(v); c.fill = fill; c.number_format = fmt
    return r + 2


def scrivi_paesi(ws, X, titolo):
    ws["A1"] = titolo; ws["A1"].font = TIT
    ws["A2"] = ("Medie semplici delle quote delle famiglie (come le quote medie del LA/AIDS)." if X is P else
                "Medie PESATE con il peso campionario (rappresentative della popolazione delle famiglie).") + \
               " n.r. = non rilevata nel questionario. Valori a 7 giorni a casa: acquisti + autoconsumo + regali ai prezzi mediani locali."
    ws["A2"].font = NOTE
    r = 4
    r = blocco(ws, r, "Stadio 1 - quota del budget alimentare a casa", X, "q1_", STAGE1, K_P, FILL_1)
    r = blocco(ws, r, "Stadio 1 - % di famiglie che consumano", X, "c1_", STAGE1, K_P, FILL_1)
    r = blocco(ws, r, "Stadio 2 - quota CONDIZIONATA del budget proteico (famiglie con spesa proteica > 0)", X, "q2_", STAGE2, K_P2, FILL_2)
    r = blocco(ws, r, "Stadio 2 - % di famiglie che consumano (tra quelle con spesa proteica > 0)", X, "c2_", STAGE2, K_P2, FILL_2)
    r = blocco(ws, r, "Stadio 2 - quota del budget ALIMENTARE (per confronto)", X, "qc_", STAGE2, K_P, FILL_2)
    ws.cell(r, 1, "Per la scelta dell'equazione residua e delle categorie stimabili").font = BOLD
    r += 1
    for j, h in enumerate(["Paese", "Categoria proteica piu' consumata (candidata residua)", "Categorie consumate da meno del 5% delle famiglie"], 1):
        c = ws.cell(r, j, h); c.font = HDR; c.fill = FILL_H; c.alignment = Alignment(wrap_text=True, vertical="center"); c.border = B
    ws.row_dimensions[r].height = 32
    for _, x in X.iterrows():
        r += 1
        for j, v in enumerate([x.paese, x.piu_consumata, x.meno_del_5pct], 1):
            c = ws.cell(r, j, v); c.font = BODY; c.border = B
    ws.column_dimensions["A"].width = 12; ws.column_dimensions["B"].width = 24; ws.column_dimensions["C"].width = 40
    for j in range(4, 16):
        ws.column_dimensions[get_column_letter(j)].width = 13
    ws.freeze_panes = "A4"


scrivi_paesi(wb.create_sheet("per_paese"), P, "Quote di spesa del sistema a due stadi - 5 paesi, tutti i round insieme")
scrivi_paesi(wb.create_sheet("per_paese_pesata"), PW, "Quote di spesa del sistema a due stadi - 5 paesi, medie pesate")
K_R = [("Paese", "paese"), ("Round", "round"), ("Famiglie", "famiglie_cibo")]
K_R2 = [("Paese", "paese"), ("Round", "round"), ("Famiglie con proteine", "famiglie_proteine")]
for nome, titolo, pref, cats, chiavi, fill in [
        ("stadio1_round", "Stadio 1 per round - quota del budget alimentare a casa", "q1_", STAGE1, K_R, FILL_1),
        ("stadio1_consumo", "Stadio 1 per round - % di famiglie che consumano", "c1_", STAGE1, K_R, FILL_1),
        ("stadio2_round", "Stadio 2 per round - quota condizionata del budget proteico", "q2_", STAGE2, K_R2, FILL_2),
        ("stadio2_consumo", "Stadio 2 per round - % di famiglie che consumano (tra quelle con spesa proteica > 0)", "c2_", STAGE2, K_R2, FILL_2),
        ("stadio2_su_cibo", "Stadio 2 per round - quota del budget alimentare", "qc_", STAGE2, K_R, FILL_2)]:
    ws = wb.create_sheet(nome)
    ws["A1"] = titolo; ws["A1"].font = TIT
    ws["A2"] = "Medie semplici delle quote delle famiglie. n.r. = non rilevata nel questionario di quel round."; ws["A2"].font = NOTE
    blocco(ws, 4, "", R.sort_values(["codice", "round"]), pref, cats, chiavi, fill)
    ws.column_dimensions["A"].width = 12; ws.column_dimensions["B"].width = 8; ws.column_dimensions["C"].width = 12
    for j in range(4, 16):
        ws.column_dimensions[get_column_letter(j)].width = 13
    ws.freeze_panes = "D6"
ws = wb.create_sheet("note")
NOTE_T = [
    ("Fonte", "Dataset alimentare di tutte le voci del 24 nov 2026 (ASF_food_budget): valore a 7 giorni del cibo consumato a casa = acquisti + autoconsumo + regali, "
              "con prezzi mediani locali (EA -> distretto -> regione -> paese, almeno 5 acquisti). Pasti fuori casa esclusi. Tanzania: stessi numeri dello script LA/AIDS (quote medie uguali al millesimo)."),
    ("Stadio 1", "Staples = cereali + tuberi e amidacei; Proteine = le categorie dello stadio 2; Frutta e verdura; Altro = oli e grassi, zucchero e dolci, spezie e sale, bevande, altri cibi."),
    ("Stadio 2", "Manzo; Maiale; Ovicaprini e altra carne (capra, pecora, altre carni domestiche e selvatiche, frattaglie); Pollame; Pesce (fresco e trasformato); "
                 "Latte fresco; Altri latticini (latte in polvere e in scatola, yogurt, formaggio, burro e ghee di latte, latte fermentato, formula); Uova; "
                 "Proteine vegetali (legumi secchi e freschi, arachidi, soia, frutta a guscio, semi)."),
    ("Da decidere", "Carne lavorata (processed_red_meat): Malawi 2024 salsicce e carne macinata, Nigeria carne in scatola (corned beef), Uganda 2018-2019 salsicce. "
                    "Quota sempre sotto lo 0,5% del budget proteico. Va messa in una delle 9 categorie (proposta: Ovicaprini e altra carne) prima del LA/AIDS."),
    ("Quote", "Medie semplici delle quote famiglia per famiglia, come le quote medie dell'indice di Stone. Stadio 2: solo famiglie con spesa proteica > 0. "
              "Foglio per_paese_pesata: le stesse medie pesate con il peso campionario."),
    ("n.r.", "Non rilevata: nessuna voce di quella categoria nel questionario del round (es. maiale in Etiopia). Diverso da zero."),
    ("Round", "Etiopia 2015, 2018, 2021 (2011 e 2013 esclusi: una sola voce per tutta la carne); Malawi 2010, 2016, 2019, 2024; Nigeria 2010, 2012, 2015, 2018, 2023; "
              "Tanzania 2008, 2010, 2012, 2014, 2020 (solo campione hh_sec_ja1); Uganda 2010, 2011, 2013, 2015, 2018, 2019."),
    ("Codice", "quote_2stadi_5paesi.py (github.com/paolo-medei/PhD, code/analysis)."),
]
ws["A1"] = "Note"; ws["A1"].font = TIT
for i, (a_, b_) in enumerate(NOTE_T, 3):
    ws.cell(i, 1, a_).font = BOLD
    c = ws.cell(i, 2, b_); c.font = BODY; c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[i].height = 45
ws.column_dimensions["A"].width = 14; ws.column_dimensions["B"].width = 140
wb.move_sheet("note", offset=-(len(wb.sheetnames) - 1))
wb.save(OUT)
pd.set_option("display.width", 250)
print(P[["paese", "famiglie_cibo"] + ["q1_" + k for k in S1]].round(3).to_string(index=False))
print(P[["paese", "famiglie_proteine"] + ["q2_" + k for k in S2]].round(3).to_string(index=False))
print(P[["paese"] + ["c2_" + k for k in S2]].round(3).to_string(index=False))
print(P[["paese", "piu_consumata", "meno_del_5pct"]].to_string(index=False))
print("max processed_red_meat q2:", R["q2_processed_red_meat"].max(), " qc:", R["qc_processed_red_meat"].max())
