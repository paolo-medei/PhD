# ONE WORKBOOK WITH ALL THE LA/AIDS RESULTS OF THE 5 COUNTRIES, CROSS-PRICE ELASTICITIES INCLUDED (27 Nov 2026)
#
# Starts from the 5-country workbook of confronto_LAAIDS_5paesi.py (all its sheets are kept as they are) and adds:
#   incrociate_proteine   selected cross-price elasticities, animal-source foods vs plant proteins, compensated (Hicks)
#                         and uncompensated (Marshall), with bootstrap standard errors (from elasticita_incrociate.R)
#   matrici_marshall      for every country the full matrix of UNCONDITIONAL uncompensated price elasticities of the
#   matrici_hicks         protein categories (rows = category that reacts, columns = price that changes: the 9 protein
#                         categories, then staples, fruits and vegetables, other foods), and below it the matrix of the
#                         bootstrap standard errors. Same numbers as the sheets unc_marshall / unc_hicks of each country.
# Nothing is estimated here: the script only copies numbers already computed by LAAIDS_2stadi.R.
#
# Usage: python3 risultati_LAAIDS_completi.py <5-country workbook> <Elasticita_incrociate_5paesi.xlsx>
#                                             <folder with analisi_<P>/> <date of the runs> <output.xlsx>
import sys
import pandas as pd
from openpyxl import load_workbook
from openpyxl.styles import Alignment, Font, PatternFill

CINQUE, INCR, CART, DATA, OUT = sys.argv[1:6]
PAESI = {"TZA": "Tanzania", "ETH": "Etiopia", "MWI": "Malawi", "NGA": "Nigeria", "UGA": "Uganda"}
NOMI = {"beef": "Manzo", "sheep_goat": "Ovicaprini", "pork_other_meat": "Maiale e altra carne", "poultry": "Pollame",
        "fish": "Pesce", "fluid_milk": "Latte fresco", "other_dairy": "Altri latticini", "eggs": "Uova",
        "plant_protein": "Proteine vegetali", "staples": "Staples", "fruits_veg": "Frutta e verdura", "other": "Altro"}
GRUPPI = {"meat": "carne", "fish": "pesce", "dairy": "latticini", "eggs": "uova", "ASF": "tutti gli ASF"}
NAVY = PatternFill("solid", fgColor="002060")
GRIGIO = PatternFill("solid", fgColor="DCE5F0")

wb = load_workbook(CINQUE)

def titolo(ws, r, testo, size=12):
    ws.cell(r, 1, testo).font = Font(bold=True, size=size)

def intestazione(ws, r, valori):
    for j, v in enumerate(valori, start=1):
        c = ws.cell(r, j, v); c.font = Font(bold=True, color="FFFFFF"); c.fill = NAVY
        c.alignment = Alignment(wrap_text=True, vertical="center")

# ---------- 1. selected cross-price elasticities: groups of ASF vs plant proteins ----------
ws = wb.create_sheet("incrociate_proteine")
titolo(ws, 1, "Elasticita' incrociate: alimenti di origine animale (ASF) e proteine vegetali", 13)
ws.cell(2, 1, "Non condizionate (Edgerton 1997), medie sulle famiglie, versione con effetti fissi regionali. Domanda di un gruppo = "
              "categorie pesate con la quota media nel budget alimentare; prezzo di un gruppo = tutti i suoi prezzi salgono insieme "
              "dell'1%. Sotto ogni stima l'errore standard del bootstrap (200 repliche); * = significativa al 5%. Hicks = compensata "
              "(senza effetto reddito: + sostituti, - complementi); Marshall = non compensata. Le proteine vegetali sono l'equazione "
              "residua dello stadio 2 (adding-up). Etiopia, pesce: risultato della Gambella, non nazionale.")
r = 4
for misura, nome in (("hicks", "COMPENSATE (Hicks)"), ("marshall", "NON COMPENSATE (Marshall)")):
    x = pd.read_excel(INCR, misura)
    for verso, testo in (("plant protein demand <- ASF price", "Domanda di proteine vegetali quando sale dell'1% il prezzo di ..."),
                         ("ASF demand <- plant protein price", "Domanda di ... quando sale dell'1% il prezzo delle proteine vegetali")):
        titolo(ws, r, nome + " - " + testo); r += 1
        intestazione(ws, r, ["Gruppo"] + list(PAESI.values())); r += 1
        for g, gnome in GRUPPI.items():
            sel = x[(x.direction == verso) & ((x.price == g) | (x.demand == g))].set_index("code")
            ws.cell(r, 1, gnome)
            ws.cell(r + 1, 1, "(es)")
            for j, p in enumerate(PAESI, start=2):
                z = sel.loc[p]
                c = ws.cell(r, j, round(float(z.estimate), 3)); c.number_format = "0.000"
                if bool(z.significant_5pct): c.font = Font(bold=True)
                c = ws.cell(r + 1, j, round(float(z.se), 3)); c.number_format = "(0.000)"
            if g == "ASF":
                for j in range(1, 7): ws.cell(r, j).fill = GRIGIO
            r += 2
        r += 1
ws.column_dimensions["A"].width = 30
for col in "BCDEF": ws.column_dimensions[col].width = 12

# ---------- 2. full matrices of unconditional price elasticities, every country ----------
for tipo, nome in (("marshall", "NON COMPENSATE (Marshall)"), ("hicks", "COMPENSATE (Hicks)")):
    ws = wb.create_sheet("matrici_" + tipo)
    titolo(ws, 1, "Matrici delle elasticita' di prezzo NON CONDIZIONATE, " + nome + ", versione con effetti fissi regionali", 13)
    ws.cell(2, 1, "Righe = categoria che reagisce; colonne = prezzo che cambia dell'1% (le 9 categorie proteiche, poi i gruppi dello "
                  "stadio 1). Diagonale = elasticita' al proprio prezzo. Sotto ogni matrice gli errori standard del bootstrap (200 repliche). "
                  "Rispetto al budget alimentare, entrambi gli stadi riottimizzati (Edgerton 1997). Fogli unc_" + tipo + " e unc_" + tipo +
                  "_se dei file per paese.")
    r = 4
    for p, pnome in PAESI.items():
        f = f"{CART}/analisi_{p}/risultati_LAAIDS_2stadi_{p}_{DATA}/risultati_LAAIDS_2stadi_{p}.xlsx"
        for foglio, etichetta in (("unc_" + tipo, pnome), ("unc_" + tipo + "_se", pnome + " - errori standard")):
            m = pd.read_excel(f, foglio).set_index("category")
            titolo(ws, r, etichetta); r += 1
            intestazione(ws, r, ["Reagisce \\ prezzo di"] + [NOMI.get(c, c) for c in m.columns]); r += 1
            for k in m.index:
                ws.cell(r, 1, NOMI.get(k, k))
                for j, c in enumerate(m.columns, start=2):
                    v = m.loc[k, c]
                    cell = ws.cell(r, j, None if pd.isna(v) else round(float(v), 3)); cell.number_format = "0.000"
                    if foglio == "unc_" + tipo and k == c: cell.font = Font(bold=True)          # own-price on the diagonal
                r += 1
            r += 1
        r += 1
    ws.column_dimensions["A"].width = 24
    for j in range(2, 15): ws.column_dimensions[ws.cell(1, j).column_letter].width = 11

# ---------- 3. readme: describe the new sheets ----------
lg = wb["leggimi"]
n = lg.max_row + 2
for i, (a, b) in enumerate([
        ("Fogli aggiunti (27/11/2026)", ""),
        ("incrociate_proteine", "Elasticita' incrociate fra gruppi di ASF (carne, pesce, latticini, uova, tutti) e proteine vegetali, Hicks e Marshall, con errori standard (elasticita_incrociate.R)."),
        ("matrici_marshall / matrici_hicks", "Matrici complete delle elasticita' di prezzo non condizionate di ogni paese, con gli errori standard sotto.")]):
    lg.cell(n + i, 1, a).font = Font(bold=True)
    lg.cell(n + i, 2, b)
wb.save(OUT)
print("written", OUT, wb.sheetnames)
