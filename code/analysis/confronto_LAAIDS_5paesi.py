"""Confronto fra i 5 paesi dei risultati del sistema di domanda a due stadi (LAAIDS_2stadi.R), con e senza effetti fissi regionali.

USO  python3 confronto_LAAIDS_5paesi.py <cartella OUTPUT con analisi_<paese>> <data minima dei risultati, es. 2026-11-25> <uscita.xlsx> [senza_es] [QUAIDS]
     senza_es: per risultati senza bootstrap (B piccolo): gli errori standard non vengono riportati
     QUAIDS:   legge i risultati del QUAIDS (cartelle ..._modello_QUAIDS_<data>) invece di quelli del LA/AIDS
Legge  analisi_<P>/risultati_LAAIDS_2stadi_<P>[_modello_QUAIDS]_<data>/risultati_LAAIDS_2stadi_<P>.xlsx            (con effetti fissi)
       analisi_<P>/risultati_LAAIDS_2stadi_<P>_senza_EF[_modello_QUAIDS]_<data>/risultati_LAAIDS_2stadi_<P>.xlsx   (senza)
"""
import glob
import os
import sys
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

CART, DATA, OUT = sys.argv[1:4]
NO_SE = "senza_es" in sys.argv[4:]      # point estimates only: do not report standard errors
QUAIDS = "QUAIDS" in sys.argv[4:]       # results of the QUAIDS (folders with the suffix _modello_QUAIDS)
MOD = "QUAIDS" if QUAIDS else "LA/AIDS"; SUF = "_modello_QUAIDS" if QUAIDS else ""
PAESI = {"TZA": "Tanzania", "ETH": "Etiopia", "MWI": "Malawi", "NGA": "Nigeria", "UGA": "Uganda"}
NOMI = {"staples": "Staples", "proteins": "Proteine", "fruits_veg": "Frutta e verdura", "other": "Altro",
        "beef": "Manzo", "sheep_goat": "Ovicaprini", "pork_other_meat": "Maiale e altra carne", "poultry": "Pollame",
        "fish": "Pesce", "fluid_milk": "Latte fresco", "other_dairy": "Altri latticini", "eggs": "Uova", "plant_protein": "Proteine vegetali",
        "meat": "CARNE (tutta)", "meat_and_fish": "CARNE E PESCE", "dairy": "LATTICINI (tutti)", "animal_source_foods": "TUTTI GLI ASF"}
S1 = ["staples", "proteins", "fruits_veg", "other"]
S2 = ["beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs", "plant_protein"]
AGG = ["meat", "meat_and_fish", "dairy", "animal_source_foods"]
SPEC = {"EF": ("con effetti fissi regionali (principale)", ""), "noEF": ("senza effetti fissi regionali", "_senza_EF")}


def leggi(p, spec, foglio):
    # the most recent results folder of that country and specification, dated DATA or later (a run can end after midnight)
    cand = sorted(glob.glob(os.path.join(CART, f"analisi_{p}", f"risultati_LAAIDS_2stadi_{p}{SPEC[spec][1]}{SUF}_20??-??-??")))
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
        return (x[col], x[colse] if colse and not NO_SE else None)
    return f


wb = Workbook(); wb.remove(wb.active)
for spec in ["EF", "noEF"]:
    lab = SPEC[spec][0]
    # elasticita'
    ws = wb.create_sheet(f"elasticita_{spec}")
    ws["A1"] = f"Elasticita' del {MOD} a due stadi - {lab}"; ws["A1"].font = TIT
    ws["A2"] = "Rispetto al budget alimentare (o proteico). Medie sulle famiglie. Tra parentesi l'errore standard del bootstrap a cluster (200 repliche). - = categoria non presente (Etiopia: niente maiale)."
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
    # tabella principale: spesa totale, con e senza control function, aggregati, nuovi acquirenti
    ws = wb.create_sheet(f"principale_{spec}")
    ws["A1"] = f"TABELLA PRINCIPALE - elasticita' rispetto alla SPESA TOTALE - {lab}"; ws["A1"].font = TIT
    ws["A2"] = (f"{MOD} a due stadi. Medie sulle famiglie. Spesa totale = elasticita' sul budget alimentare x theta (primo passo della control function). "
                "Proteine e aggregati: non condizionate. Tra parentesi l'errore standard del bootstrap a cluster (200 repliche)."
                + (" Blocco senza control function: bootstrap di robustezza, 100 repliche con il QUAIDS (fuori tempo con 200)." if QUAIDS else ""))
    ws["A2"].font = SUB
    r = 4
    r = blocco(ws, r, "Con control function (principale)", S2 + AGG + S1, valore(spec, "main_expenditure", "total_expenditure", "se"))
    r = blocco(ws, r, "Senza control function", S2 + AGG + S1, valore(spec, "main_expenditure", "total_expenditure_no_CF", "se_no_CF"))
    me = [leggi(p, spec, "main_expenditure") for p in PAESI]
    if any(d is not None and "total_expenditure_other_model" in d.columns for d in me):   # only if the other model was estimated
        r = blocco(ws, r, "Con l'altro modello di domanda (" + ("LA/AIDS" if QUAIDS else "QUAIDS") + ")", S2 + AGG + S1,
                   valore(spec, "main_expenditure", "total_expenditure_other_model", "se_other_model"))
    r = blocco(ws, r, "Solo famiglie che gia' comprano (con control function)", S2 + AGG, valore(spec, "main_expenditure", "current_buyers", "current_buyers_se"),
               "il resto dell'elasticita' viene da famiglie che iniziano a comprare (o comprano piu' spesso)")
    pct = valore(spec, "main_expenditure", "pct_from_new_buyers")
    r0 = r
    r = blocco(ws, r, "Quota dell'elasticita' dovuta ai NUOVI acquirenti", S2 + AGG,
               lambda p, c: None if pct(p, c) is None else (pct(p, c)[0] / 100, None),
               "negativa = a parita' di prezzi un budget piu' alto riduce la probabilita' di consumare (es. uova e ovicaprini in Tanzania)")
    for row in ws.iter_rows(min_row=r0, max_row=r):
        for c in row[1:]:
            if isinstance(c.value, float) and c.number_format == "0.00":
                c.number_format = "0%"
    r = blocco(ws, r, "Elasticita' di prezzo propria (Marshall), con control function", S2 + AGG + S1, valore(spec, "main_own_price", "marshall", "marshall_se"),
               "aggregati: tutti i prezzi del gruppo aumentano insieme dell'1%")
    r = blocco(ws, r, "Elasticita' di prezzo propria (Marshall), senza control function", S2 + AGG + S1, valore(spec, "main_own_price", "marshall_no_CF", "marshall_no_CF_se"))
    th = valore(spec, "main_expenditure", "theta", "se_theta")
    ws.cell(r, 1, "theta (budget alimentare / spesa totale)").font = BOLD
    for j, p in enumerate(PAESI, 2):
        v = th(p, "staples")
        if v is not None:
            ws.cell(r, j, float(v[0])).number_format = "0.000"
    ws.column_dimensions["A"].width = 26
    for j in range(2, 8):
        ws.column_dimensions[get_column_letter(j)].width = 13
    # per quintile e area (foglio main_by_group dei risultati), con l'errore standard del bootstrap
    ws = wb.create_sheet(f"quintili_area_{spec}")
    ws["A1"] = f"Elasticita' rispetto alla SPESA TOTALE per quintile e area - {lab}"; ws["A1"].font = TIT
    ws["A2"] = ("Stesso modello per paese: cambiano solo le famiglie su cui si fa la media. Quintili nazionali di consumo per adulto equivalente "
                "(Q1 = 20% piu' povero). Tra parentesi l'errore standard del bootstrap a cluster (200 repliche). Celle con meno di 200 famiglie: imprecise.")
    ws["A2"].font = SUB
    r = 4
    cache3 = {}

    def gruppo(g, col, colse=None):
        def f(p, cat, spec=spec):
            if p not in cache3:
                cache3[p] = leggi(p, spec, "main_by_group")
            d = cache3[p]
            if d is None:
                return None
            x = d[(d.group == g) & (d.category == cat)]
            return None if x.empty else (x.iloc[0][col], None if (NO_SE or colse is None) else x.iloc[0][colse])
        return f
    TIT_G = {"Q1": "Q1 (20% piu' povero)", "Q2": "Q2", "Q3": "Q3", "Q4": "Q4", "Q5": "Q5 (20% piu' ricco)", "rural": "Famiglie rurali", "urban": "Famiglie urbane"}
    for g, t in TIT_G.items():
        r = blocco(ws, r, t, S2 + AGG, gruppo(g, "total_expenditure", "se"))
    r0 = r
    r = blocco(ws, r, "Quota dovuta ai NUOVI acquirenti - Q1", S2 + AGG, lambda p, c: (lambda v: None if v is None else (v[0] / 100, None))(gruppo("Q1", "pct_from_new_buyers")(p, c)))
    r = blocco(ws, r, "Quota dovuta ai NUOVI acquirenti - Q5", S2 + AGG, lambda p, c: (lambda v: None if v is None else (v[0] / 100, None))(gruppo("Q5", "pct_from_new_buyers")(p, c)))
    for row in ws.iter_rows(min_row=r0, max_row=r):                  # the two blocks of shares: percentages
        for c in row[1:]:
            if isinstance(c.value, float) and c.number_format == "0.00":
                c.number_format = "0%"
    ws.column_dimensions["A"].width = 24
    for j in range(2, 8):
        ws.column_dimensions[get_column_letter(j)].width = 13
    # robustezza
    ws = wb.create_sheet(f"robustezza_{spec}")
    ws["A1"] = f"Robustezza delle elasticita' NON CONDIZIONATE rispetto al budget alimentare - {lab}"; ws["A1"].font = TIT
    ws["A2"] = "Rispetto al budget alimentare. Altra residua = stadio 2 con un'altra categoria omessa (pesce; latte fresco in Etiopia); senza CF = senza control function; al punto medio = metodo usato fino al 25/11."
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
            return None if x.empty else (x.iloc[0][col], None if NO_SE else x.iloc[0][colse])
        return f
    r = blocco(ws, r, "Modello principale", S2, rob("main_expenditure", "main_expenditure_se"))
    r = blocco(ws, r, "Altra categoria residua nello stadio 2", S2, rob("alt_residual_expenditure", "alt_residual_expenditure_se"))
    r = blocco(ws, r, "Senza control function", S2, rob("no_CF_expenditure", "no_CF_expenditure_se"))
    r = blocco(ws, r, "Al punto medio (una famiglia con tutti i valori medi: metodo precedente)", S2, rob("at_means_expenditure", "at_means_expenditure_se"))
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
        "F strumenti stadio 1", "F strumenti stadio 2", "successful bootstrap replications", "bootstrap clusters", "demand model",
        "QUAIDS iterations stage 1 (1 = LA/AIDS)", "QUAIDS iterations stage 2 (1 = LA/AIDS)"]
cols = [x for x in cols if x in C.columns]
for j, h in enumerate(cols, 1):
    cc = ws.cell(3, j, h); cc.font = HDR; cc.fill = FH; cc.border = BD; cc.alignment = Alignment(wrap_text=True, vertical="center")
ws.row_dimensions[3].height = 60
for i, (_, x) in enumerate(C.iterrows(), 4):
    for j, h in enumerate(cols, 1):
        v = x[h]
        try:
            v = float(v)                        # the checks sheet can hold numbers as text (it also has the model name)
        except (TypeError, ValueError):
            pass
        cc = ws.cell(i, j, v); cc.font = BODY; cc.border = BD
        if not isinstance(v, str):
            cc.number_format = "#,##0" if float(v) > 100 else "0.0"
for j in range(1, len(cols) + 1):
    ws.column_dimensions[get_column_letter(j)].width = 16
ws = wb.create_sheet("letteratura")
ws["A1"] = "Elasticita' di spesa in altri studi (per confronto). Base: rispetto a cosa e' calcolata l'elasticita'."; ws["A1"].font = TIT
ws["A2"] = "'da verificare' = la base non e' stata controllata sul testo. Confrontare con i fogli principale_* (spesa totale) o elasticita_* (budget alimentare)."
ws["A2"].font = SUB
LETT = [
    ("Weliwita, Nyange & Tsujii (2003)", "Tanzania", "HBS 1991/92", "budget alimentare", "carne 0,82; pesce 1,05; latticini 0,87; legumi 1,01", ""),
    ("Nsabimana (2024), UNU-WIDER WP 2024/22", "Tanzania", "NPS 2012/13", "budget alimentare", "carne 0,96-0,97; latte 1,24",
     "QUAIDS + Shonkwiler-Yen, al punto medio, spesa non strumentata, 9 gruppi; il pesce non e' un gruppo a parte"),
    ("Tafere & Worku (2012), ESSP WP 38", "Etiopia", "HICES 2004/05", "spesa totale", "manzo 0,94; ovicaprini 0,67; altra carne 0,54; latticini 0,42", ""),
    ("Ecker & Qaim (2008, 2011)", "Malawi", "IHS2 2004/05", "da verificare", "carne rossa 1,34; carne bianca 1,12; pesce 1,04; uova 1,21; latticini 0,81; legumi 0,87", ""),
    ("Aborisade, Carpio & Boonsaeng (2024)", "Nigeria", "LSMS", "budget della carne (condizionata)", "manzo 1,07; pollame 1,43; altre carni 0,86; pesce 0,86-1,05",
     "confrontare con lo stadio 2 condizionato, ma il nostro gruppo comprende anche latticini, uova e proteine vegetali"),
    ("Parkhi, Liverpool-Tasie & Reardon (2022)", "Nigeria", "LSMS", "da verificare", "manzo ~1,0; pollame 1,6-1,7; uova 1,25-1,28; latte 1,04-1,12; pesce 0,73-0,94",
     "working paper: non citare senza permesso degli autori"),
    ("Boysen (2012, 2016)", "Uganda", "UNHS 2005/06", "da verificare", "prodotti zootecnici 1,14-1,19; pesce 0,75; fagioli 0,54-0,60", ""),
    ("Melo et al. (2015); Colen et al. (2018), meta-analisi", "vari", "molti studi", "reddito / spesa totale", "carne 0,96; pesce 0,78; uova 0,75; latticini 0,83; legumi 0,21-0,50", "medie della meta-analisi")]
for j, h in enumerate(["Studio", "Paese", "Dati", "Base", "Elasticita' di spesa", "Nota"], 1):
    c = ws.cell(4, j, h); c.font = HDR; c.fill = FH; c.border = BD
for i, x in enumerate(LETT, 5):
    for j, v in enumerate(x, 1):
        c = ws.cell(i, j, v); c.font = BODY; c.border = BD; c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[i].height = 32
for j, w in enumerate([34, 10, 14, 22, 58, 58], 1):
    ws.column_dimensions[get_column_letter(j)].width = w
ws = wb.create_sheet("leggimi")
NOTE = [("Modello", MOD + " a due stadi (separabilita' debole assunta)" + (" - QUAIDS di Banks, Blundell e Lewbel (1997) con indice di Stone per a(p) e b(p) esatto, "
                    "stimato per iterazioni; modello principale dal 26/11/2026 perche' il termine quadratico e' significativo in 34 equazioni su 54" if QUAIDS else "") + ": stadio 1 budget alimentare a casa fra staples, proteine, frutta e verdura, altro; "
                    "stadio 2 budget proteico fra 9 categorie (8 in Etiopia). Shonkwiler-Yen per gli zeri, control function per la spesa, SUR con omogeneita' "
                    "e simmetria, elasticita' non condizionate con Edgerton (1997). Script: LAAIDS_2stadi.R."),
        ("Categorie", "Ovicaprini = capra e pecora. Maiale e altra carne = maiale + altre carni (domestiche e selvatiche, frattaglie, piccoli animali) + carne "
                      "lavorata (salsicce, corned beef). Etiopia: niente maiale nel questionario, la carne di cammello (4 famiglie, 2021) e' nel manzo."),
        ("Effetti fissi", "Versione principale con effetti fissi regionali (una dummy per regione in tutte le equazioni). Senza, in Uganda l'elasticita' di prezzo "
                          "propria delle proteine nello stadio 1 e' positiva; le elasticita' di spesa cambiano poco. Fogli *_noEF: la versione senza."),
        ("Come leggere", "Fogli principale_*: la tabella da usare, rispetto alla SPESA TOTALE (come quasi tutta la letteratura), con e senza control function, "
                         "categorie e aggregati (carne, carne e pesce, latticini, tutti gli ASF). Condizionate: a budget proteico fisso. Non condizionate: "
                         "rispetto al budget alimentare, rifacendo le scelte dei due stadi."),
        ("Medie", "Dal 26/11/2026 le elasticita' sono MEDIE SULLE FAMIGLIE (derivata media / quota media). Prima erano calcolate al punto medio, che con "
                  "Shonkwiler-Yen gonfia i prodotti comprati da poche famiglie (Tanzania, carne rispetto alla spesa totale, LA/AIDS: 1,78 al punto medio, 1,58 come media). "
                  "Il vecchio metodo e' nei fogli robustezza_*."),
        ("Campione", "Quintili di consumo totale per ADULTO EQUIVALENTE (scala OCSE modificata). Escluse le famiglie con budget alimentare implausibile "
                     "(cibo dei 7 giorni x 52 > 3 volte il consumo totale annuo). Fogli quintili_area_*: risultati per quintile e area rurale/urbana."),
        ("Letteratura", "Foglio letteratura: valori di altri studi su paesi simili, con la base (spesa alimentare o totale). Confrontare solo sulla stessa base."),
        ("Paesi", "Tanzania 2008-2020 (5 round), Etiopia 2015-2021 (3), Malawi 2010-2024 (4), Nigeria 2010-2023 (5), Uganda 2010-2019 (6)."),
        ("Codice", "confronto_LAAIDS_5paesi.py, LAAIDS_2stadi.R (github.com/paolo-medei/PhD, code/analysis).")]
ws["A1"] = f"Confronto {MOD} a due stadi - 5 paesi" + (" - SOLO STIME PUNTUALI, SENZA BOOTSTRAP (errori standard non riportati)" if NO_SE else "")
ws["A1"].font = TIT
for i, (a, b) in enumerate(NOTE, 3):
    ws.cell(i, 1, a).font = BOLD
    c = ws.cell(i, 2, b); c.font = BODY; c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[i].height = 48
ws.column_dimensions["A"].width = 14; ws.column_dimensions["B"].width = 140
wb.move_sheet("leggimi", offset=-(len(wb.sheetnames) - 1))
# Blocks without a standard error (e.g. the share of the elasticity due to new buyers, which is a ratio and has
# no bootstrap SE): drop the "(es)" label when the whole row is empty, so the reader does not see blank SE rows.
for w in wb.worksheets:
    for row in w.iter_rows():
        if row[0].value == "  (es)" and all(c.value in (None, "") for c in row[1:]):
            row[0].value = None
if NO_SE:   # point estimates only: remove the "(es)" labels and say so in the subtitles
    for w in wb.worksheets:
        for row in w.iter_rows():
            for c in row:
                if c.value == "  (es)":
                    c.value = None
                elif isinstance(c.value, str) and "Tra parentesi l'errore standard del bootstrap a cluster (200 repliche)." in c.value:
                    c.value = c.value.replace("Tra parentesi l'errore standard del bootstrap a cluster (200 repliche).", "STIME PUNTUALI: errori standard non ancora disponibili (bootstrap in corso).")
wb.save(OUT)
print("salvato", OUT, wb.sheetnames)
