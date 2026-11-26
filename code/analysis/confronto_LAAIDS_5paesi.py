"""Confronto fra i 5 paesi dei risultati del LA/AIDS a due stadi (LAAIDS_2stadi.R), con e senza effetti fissi regionali.

USO  python3 confronto_LAAIDS_5paesi.py <cartella OUTPUT con analisi_<paese>> <data minima dei risultati, es. 2026-11-25> <uscita.xlsx>
Legge  analisi_<P>/risultati_LAAIDS_2stadi_<P>_<data>/risultati_LAAIDS_2stadi_<P>.xlsx            (con effetti fissi)
       analisi_<P>/risultati_LAAIDS_2stadi_<P>_senza_EF_<data>/risultati_LAAIDS_2stadi_<P>.xlsx   (senza)
"""
import glob
import os
import sys
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

CART, DATA, OUT = sys.argv[1:4]
PAESI = {"TZA": "Tanzania", "ETH": "Etiopia", "MWI": "Malawi", "NGA": "Nigeria", "UGA": "Uganda"}
NOMI = {"staples": "Staples", "proteins": "Proteine", "fruits_veg": "Frutta e verdura", "other": "Altro",
        "beef": "Manzo", "sheep_goat": "Ovicaprini", "pork_other_meat": "Maiale e altra carne", "poultry": "Pollame",
        "fish": "Pesce", "fluid_milk": "Latte fresco", "other_dairy": "Altri latticini", "eggs": "Uova", "plant_protein": "Proteine vegetali"}
S1 = ["staples", "proteins", "fruits_veg", "other"]
S2 = ["beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs", "plant_protein"]
SPEC = {"EF": ("con effetti fissi regionali (principale)", ""), "noEF": ("senza effetti fissi regionali", "_senza_EF")}


def leggi(p, spec, foglio):
    # the most recent results folder of that country and specification, dated DATA or later (a run can end after midnight)
    cand = sorted(glob.glob(os.path.join(CART, f"analisi_{p}", f"risultati_LAAIDS_2stadi_{p}{SPEC[spec][1]}_20??-??-??")))
    cand = [c for c in cand if c[-10:] >= DATA and os.path.exists(os.path.join(c, f"risultati_LAAIDS_2stadi_{p}.xlsx"))]
    if not cand:
        return None
    f = os.path.join(cand[-1], f"risultati_LAAIDS_2stadi_{p}.xlsx")
    try:
        return pd.read_excel(f, sheet_name=foglio)
    except ValueError:                      # sheet missing (results of an older version)
        return None


F = "Arial"
TIT, SUB, HDR = Font(name=F, bold=True, size=12), Font(name=F, size=9, italic=True, color="555555"), Font(name=F, bold=True, size=10, color="FFFFFF")
BODY, BOLD, SE = Font(name=F, size=10), Font(name=F, size=10, bold=True), Font(name=F, size=9, color="666666")
FH = PatternFill("solid", fgColor="1F4E78"); F2 = PatternFill("solid", fgColor="DDEBF7"); GR = PatternFill("solid", fgColor="F2F2F2")
thin = Side(style="thin", color="BFBFBF"); BD = Border(top=thin, bottom=thin, left=thin, right=thin)


def blocco(ws, r, titolo, righe, valori, nota=None):
    """righe: categorie; valori(p, cat) -> (stima, es) o None. Una colonna per paese con stima e, sotto, l'errore standard."""
    ws.cell(r, 1, titolo).font = BOLD
    if nota:
        ws.cell(r, 3, nota).font = SUB
    r += 1
    for j, h in enumerate(["Categoria"] + [PAESI[p] for p in PAESI], 1):
        c = ws.cell(r, j, h); c.font = HDR; c.fill = FH; c.border = BD; c.alignment = Alignment(horizontal="center")
    for cat in righe:
        r += 1
        ws.cell(r, 1, NOMI[cat]).font = BODY; ws.cell(r, 1).border = BD
        ws.cell(r + 1, 1, "  (es)").font = SE
        for j, p in enumerate(PAESI, 2):
            v = valori(p, cat)
            c = ws.cell(r, j); c2 = ws.cell(r + 1, j)
            c.border = BD
            if v is None or pd.isna(v[0]):
                c.value = "-"; c.fill = GR; c.alignment = Alignment(horizontal="center")
            else:
                c.value = float(v[0]); c.number_format = "0.00"; c.font = BODY; c.fill = F2
                if v[1] is not None and not pd.isna(v[1]):
                    c2.value = float(v[1]); c2.number_format = "(0.00)"; c2.font = SE
            c2.alignment = Alignment(horizontal="center")
        r += 1
    return r + 2


def valore(spec, foglio, col, colse=None, key="category"):
    cache = {}

    def f(p, cat):
        if p not in cache:
            cache[p] = leggi(p, spec, foglio)
        d = cache[p]
        if d is None or cat not in set(d[key]):
            return None
        x = d[d[key] == cat].iloc[0]
        return (x[col], x[colse] if colse else None)
    return f


wb = Workbook(); wb.remove(wb.active)
for spec in ["EF", "noEF"]:
    lab = SPEC[spec][0]
    # elasticita'
    ws = wb.create_sheet(f"elasticita_{spec}")
    ws["A1"] = f"Elasticita' del LA/AIDS a due stadi - {lab}"; ws["A1"].font = TIT
    ws["A2"] = "Ai valori medi del campione. Tra parentesi l'errore standard del bootstrap a cluster (200 repliche). - = categoria non presente (Etiopia: niente maiale)."
    ws["A2"].font = SUB
    r = 4
    r = blocco(ws, r, "Stadio 1 - elasticita' rispetto al budget alimentare", S1, valore(spec, "s1_expenditure", "expenditure_elasticity", "se"))
    r = blocco(ws, r, "Stadio 1 - elasticita' di prezzo propria (Marshall)", S1, valore(spec, "s1_own_price", "marshall", "marshall_se"))
    r = blocco(ws, r, "Stadio 2 CONDIZIONATO - elasticita' rispetto al budget proteico", S2, valore(spec, "s2_expenditure", "expenditure_elasticity", "se"))
    r = blocco(ws, r, "Stadio 2 CONDIZIONATO - elasticita' di prezzo propria (Marshall)", S2, valore(spec, "s2_own_price", "marshall", "marshall_se"))
    r = blocco(ws, r, "NON CONDIZIONATE - elasticita' rispetto al budget alimentare", S2, valore(spec, "unc_expenditure", "expenditure_elasticity", "se"))
    r = blocco(ws, r, "NON CONDIZIONATE - elasticita' di prezzo propria (Marshall)", S2, valore(spec, "unc_own_price", "marshall", "marshall_se"))
    r = blocco(ws, r, "NON CONDIZIONATE - elasticita' di prezzo propria (Hicks, compensata)", S2, valore(spec, "unc_own_price", "hicks", "hicks_se"))
    ws.column_dimensions["A"].width = 24
    for j in range(2, 8):
        ws.column_dimensions[get_column_letter(j)].width = 13
    # spesa totale e nuovi acquirenti
    ws = wb.create_sheet(f"spesa_totale_{spec}")
    ws["A1"] = f"Elasticita' rispetto alla SPESA TOTALE e quota della risposta dovuta a nuovi acquirenti - {lab}"; ws["A1"].font = TIT
    ws["A2"] = "Spesa totale = elasticita' sul budget alimentare x theta (elasticita' del budget alimentare alla spesa totale, primo passo della control function). Approssimazione."
    ws["A2"].font = SUB
    r = 4
    r = blocco(ws, r, "Proteine (non condizionate) - elasticita' rispetto alla spesa totale", S2,
               valore(spec, "rob_total_expenditure", "elasticity_total_expenditure", "se"))
    r = blocco(ws, r, "Gruppi dello stadio 1 - elasticita' rispetto alla spesa totale", S1,
               valore(spec, "rob_total_expenditure", "elasticity_total_expenditure", "se"))
    cache = {}

    def nuovi(p, cat, spec=spec):
        if p not in cache:
            cache[p] = leggi(p, spec, "rob_decomposition")
        d = cache[p]
        if d is None:
            return None
        x = d[(d.category == cat) & (d.system == "stage 2 (conditional)")]
        return None if x.empty else (x.iloc[0].pct_from_new_buyers / 100, None)
    r = blocco(ws, r, "Stadio 2 - quota dell'elasticita' di spesa dovuta a famiglie che INIZIANO a comprare", S2, nuovi,
               "il resto: famiglie che gia' comprano e spendono di piu'")
    for row in ws.iter_rows(min_row=r - 2 - 2 * len(S2), max_row=r):
        for c in row[1:]:
            if isinstance(c.value, float) and c.number_format == "0.00":
                c.number_format = "0%"
    ws.column_dimensions["A"].width = 24
    for j in range(2, 8):
        ws.column_dimensions[get_column_letter(j)].width = 13
    # robustezza
    ws = wb.create_sheet(f"robustezza_{spec}")
    ws["A1"] = f"Robustezza delle elasticita' NON CONDIZIONATE rispetto al budget alimentare - {lab}"; ws["A1"].font = TIT
    ws["A2"] = "Altra residua = stadio 2 con un'altra categoria omessa (pesce; latte fresco in Etiopia); senza CF = senza control function."
    ws["A2"].font = SUB
    r = 4
    cache2 = {}

    def rob(col, colse):
        def f(p, cat, spec=spec):
            if p not in cache2:
                cache2[p] = leggi(p, spec, "rob_comparison")
            d = cache2[p]
            if d is None:
                return None
            x = d[(d.category == cat) & (d.system == "unconditional")]
            return None if x.empty else (x.iloc[0][col], x.iloc[0][colse])
        return f
    r = blocco(ws, r, "Modello principale", S2, rob("main_expenditure", "main_expenditure_se"))
    r = blocco(ws, r, "Altra categoria residua nello stadio 2", S2, rob("alt_residual_expenditure", "alt_residual_expenditure_se"))
    r = blocco(ws, r, "Senza control function", S2, rob("no_CF_expenditure", "no_CF_expenditure_se"))
    ws.column_dimensions["A"].width = 24
    for j in range(2, 8):
        ws.column_dimensions[get_column_letter(j)].width = 13

# controlli e quote
ws = wb.create_sheet("controlli")
ws["A1"] = "Controlli per paese (versione con effetti fissi; i campioni sono gli stessi senza)"; ws["A1"].font = TIT
righe = []
for p in PAESI:
    c = leggi(p, "EF", "checks"); fs = leggi(p, "EF", "first_stage")
    if c is None:
        continue
    d = dict(zip(c.check, c.value))
    d["paese"] = PAESI[p]
    if fs is not None:
        d["F strumenti stadio 1"] = fs[fs.stage.str.startswith("stage 1")].joint_F_cluster.iloc[0]
        d["F strumenti stadio 2"] = fs[fs.stage.str.startswith("stage 2")].joint_F_cluster.iloc[0]
    righe.append(d)
C = pd.DataFrame(righe)
cols = ["paese", "households in the stage-1 estimation", "households in the stage-2 estimation", "mean share of the food budget imputed (%)",
        "mean share of the protein budget imputed (%)", "stage 2: households NOT consuming the residual 'plant_protein' (%) - zeros not modelled",
        "F strumenti stadio 1", "F strumenti stadio 2", "successful bootstrap replications", "bootstrap clusters"]
cols = [x for x in cols if x in C.columns]
for j, h in enumerate(cols, 1):
    cc = ws.cell(3, j, h); cc.font = HDR; cc.fill = FH; cc.border = BD; cc.alignment = Alignment(wrap_text=True, vertical="center")
ws.row_dimensions[3].height = 60
for i, (_, x) in enumerate(C.iterrows(), 4):
    for j, h in enumerate(cols, 1):
        v = x[h]
        cc = ws.cell(i, j, v if isinstance(v, str) else float(v)); cc.font = BODY; cc.border = BD
        if not isinstance(v, str):
            cc.number_format = "#,##0" if float(v) > 100 else "0.0"
for j in range(1, len(cols) + 1):
    ws.column_dimensions[get_column_letter(j)].width = 16
ws = wb.create_sheet("leggimi")
NOTE = [("Modello", "LA/AIDS a due stadi (separabilita' debole assunta): stadio 1 budget alimentare a casa fra staples, proteine, frutta e verdura, altro; "
                    "stadio 2 budget proteico fra 9 categorie (8 in Etiopia). Shonkwiler-Yen per gli zeri, control function per la spesa, SUR con omogeneita' "
                    "e simmetria, elasticita' non condizionate con Edgerton (1997). Script: LAAIDS_2stadi.R."),
        ("Categorie", "Ovicaprini = capra e pecora. Maiale e altra carne = maiale + altre carni (domestiche e selvatiche, frattaglie, piccoli animali) + carne "
                      "lavorata (salsicce, corned beef). Etiopia: niente maiale nel questionario, la carne di cammello (4 famiglie, 2021) e' nel manzo."),
        ("Effetti fissi", "Versione principale con effetti fissi regionali (una dummy per regione in tutte le equazioni). Senza, in Uganda l'elasticita' di prezzo "
                          "propria delle proteine nello stadio 1 e' positiva; le elasticita' di spesa cambiano poco. Fogli *_noEF: la versione senza."),
        ("Come leggere", "Condizionate: a budget proteico fisso. Non condizionate: rispetto al budget alimentare, rifacendo le scelte dei due stadi. "
                         "Spesa totale: x theta, piu' vicine alle elasticita' al reddito della letteratura."),
        ("Paesi", "Tanzania 2008-2020 (5 round), Etiopia 2015-2021 (3), Malawi 2010-2024 (4), Nigeria 2010-2023 (5), Uganda 2010-2019 (6)."),
        ("Codice", "confronto_LAAIDS_5paesi.py, LAAIDS_2stadi.R (github.com/paolo-medei/PhD, code/analysis).")]
ws["A1"] = "Confronto LA/AIDS a due stadi - 5 paesi"; ws["A1"].font = TIT
for i, (a, b) in enumerate(NOTE, 3):
    ws.cell(i, 1, a).font = BOLD
    c = ws.cell(i, 2, b); c.font = BODY; c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[i].height = 48
ws.column_dimensions["A"].width = 14; ws.column_dimensions["B"].width = 140
wb.move_sheet("leggimi", offset=-(len(wb.sheetnames) - 1))
wb.save(OUT)
print("salvato", OUT, wb.sheetnames)
