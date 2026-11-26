# Compares the two-stage LA/AIDS (main model) with the two-stage QUAIDS (Banks, Blundell and Lewbel 1997), country by
# country, with the SAME script, data and specification (regional fixed effects); only MODELLO differs.
#
# Why this check: in the LA/AIDS the expenditure elasticity of a household is about 1 + beta/w. For a luxury (beta > 0)
# the share w rises with income, so the elasticity falls towards 1; for a necessity (beta < 0) w falls and the
# elasticity falls further below 1. A decline of the elasticity from Q1 to Q5 is therefore partly built into the
# LA/AIDS. The QUAIDS adds lambda (ln x)^2 / b(p): the elasticity can then rise or fall with income on its own, so
# the decline across quintiles is tested rather than assumed.
#
# Usage: python3 confronto_LAAIDS_QUAIDS.py <folder with analisi_<P>/> <date of the LA/AIDS runs> <output.xlsx>
# Both models have cluster-bootstrap standard errors (200 replications) when the full QUAIDS runs are available
# (folders ..._modello_QUAIDS_<date>); the SE of lambda is the SUR one, which ignores that Phi, phi and v_hat are
# estimated: read its t-value as indicative only.
import glob, sys
import pandas as pd
from openpyxl.styles import Alignment, Font, PatternFill

CART, DATA, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
PAESI = {"TZA": "Tanzania", "ETH": "Etiopia", "MWI": "Malawi", "NGA": "Nigeria", "UGA": "Uganda"}
CATS = ["beef", "sheep_goat", "pork_other_meat", "poultry", "meat", "fish", "fluid_milk", "other_dairy", "dairy", "eggs",
        "animal_source_foods", "plant_protein", "staples", "proteins", "fruits_veg", "other"]
NOMI = {"beef": "Manzo", "sheep_goat": "Ovicaprini", "pork_other_meat": "Maiale e altra carne", "poultry": "Pollame",
        "meat": "CARNE (tutta)", "fish": "Pesce", "fluid_milk": "Latte fresco", "other_dairy": "Altri latticini",
        "dairy": "LATTICINI (tutti)", "eggs": "Uova", "animal_source_foods": "TUTTI GLI ASF", "plant_protein": "Proteine vegetali",
        "staples": "Staples", "proteins": "Proteine", "fruits_veg": "Frutta e verdura", "other": "Altro"}

def file_la(p):
    return f"{CART}/analisi_{p}/risultati_LAAIDS_2stadi_{p}_{DATA}/risultati_LAAIDS_2stadi_{p}.xlsx"

def file_qu(p):
    f = sorted(glob.glob(f"{CART}/analisi_{p}/risultati_LAAIDS_2stadi_{p}_modello_QUAIDS_*/*.xlsx"))
    return f[-1] if f else None

righe, quint, lam, conv = [], [], [], []
for p, nome in PAESI.items():
    fq = file_qu(p)
    if fq is None:
        print(p, "QUAIDS results missing"); continue
    la, qu = pd.ExcelFile(file_la(p)), pd.ExcelFile(fq)
    m_la = pd.read_excel(la, "main_expenditure").set_index("category")
    m_qu = pd.read_excel(qu, "main_expenditure").set_index("category")
    g_la = pd.read_excel(la, "main_by_group").set_index(["group", "category"])
    g_qu = pd.read_excel(qu, "main_by_group").set_index(["group", "category"])
    pr_la = pd.read_excel(la, "main_own_price").set_index("category")
    pr_qu = pd.read_excel(qu, "main_own_price").set_index("category")
    for k in CATS:
        if k not in m_la.index or k not in m_qu.index:
            continue
        r = {"Paese": nome, "Categoria": NOMI[k],
             "LA/AIDS": m_la.loc[k, "total_expenditure"], "LA/AIDS es": m_la.loc[k, "se"],
             "QUAIDS": m_qu.loc[k, "total_expenditure"], "QUAIDS es": m_qu.loc[k, "se"]}
        r["Differenza"] = r["QUAIDS"] - r["LA/AIDS"]
        r["Differenza in es"] = r["Differenza"] / r["LA/AIDS es"] if r["LA/AIDS es"] else None
        r["Prezzo LA/AIDS"] = pr_la.loc[k, "marshall"] if k in pr_la.index else None
        r["Prezzo QUAIDS"] = pr_qu.loc[k, "marshall"] if k in pr_qu.index else None
        righe.append(r)
        q = {"Paese": nome, "Categoria": NOMI[k]}
        for mod, g in (("LA", g_la), ("QU", g_qu)):
            for grp in ["Q1", "Q2", "Q3", "Q4", "Q5", "rural", "urban"]:
                q[f"{mod} {grp}"] = g.loc[(grp, k), "total_expenditure"] if (grp, k) in g.index else None
            q[f"{mod} Q1-Q5"] = (q[f"{mod} Q1"] - q[f"{mod} Q5"]) if q[f"{mod} Q1"] is not None and q[f"{mod} Q5"] is not None else None
        q["Calo Q1-Q5 conservato?"] = (None if q["LA Q1-Q5"] is None or q["QU Q1-Q5"] is None else
                                       ("si" if q["QU Q1-Q5"] > 0 and q["LA Q1-Q5"] > 0 else ("no" if q["LA Q1-Q5"] > 0 else "-")))
        quint.append(q)
    # lambda: coefficient of the quadratic term in every share equation (both stages), with the SUR standard error
    for st in ["s1", "s2"]:
        c = pd.read_excel(qu, f"{st}_SUR_coefficients")
        c = c[c.coefficient.str.endswith("_Q_quaids")]
        for _, r in c.iterrows():
            lam.append({"Paese": nome, "Stadio": st, "Equazione": r.coefficient.split("_")[0], "lambda": r.estimate,
                        "es SUR": r.se_sur, "t": r.estimate / r.se_sur if r.se_sur else None})
    ck = pd.read_excel(qu, "checks").set_index("check").value
    conv.append({"Paese": nome, **{k: ck[k] for k in ck.index if "QUAIDS" in str(k) or "demand model" in str(k)}})

R, QT, L, C = pd.DataFrame(righe), pd.DataFrame(quint), pd.DataFrame(lam), pd.DataFrame(conv)
note = pd.DataFrame({"Nota": [
    "Confronto QUAIDS (modello principale dal 26/11/2026) e LA/AIDS, stesso script, stessi dati, effetti fissi regionali; errori standard: bootstrap a cluster, 200 repliche.",
    "Elasticita' rispetto alla spesa totale, medie sulle famiglie. 'Differenza in es' = (QUAIDS - LA/AIDS) / errore standard bootstrap del LA/AIDS.",
    "Perche' il test: nel LA/AIDS l'elasticita' e' circa 1 + beta/w, quindi il calo da Q1 a Q5 e' in parte imposto dalla forma funzionale.",
    "Il QUAIDS aggiunge lambda (ln x)^2 / b(p) nelle quote e il quadrato del budget nei probit: l'elasticita' puo' cambiare con il reddito liberamente.",
    "Foglio quintili: 'Calo Q1-Q5 conservato?' = si se il calo dal quintile piu' povero al piu' ricco c'e' in entrambi i modelli.",
    "Foglio lambda: t calcolato con l'errore standard SUR, che ignora che Phi, phi e v_hat sono stimati: solo indicativo.",
]})
with pd.ExcelWriter(OUT, engine="openpyxl") as w:
    note.to_excel(w, "leggimi", index=False)
    R.to_excel(w, "medie", index=False)
    QT.to_excel(w, "quintili_area", index=False)
    L.to_excel(w, "lambda", index=False)
    C.to_excel(w, "convergenza", index=False)
    for ws in w.book.worksheets:
        for col in ws.columns:
            ws.column_dimensions[col[0].column_letter].width = 26 if col[0].column_letter in "AB" else 12
        for c in ws[1]:
            c.font = Font(bold=True, color="FFFFFF"); c.fill = PatternFill("solid", fgColor="002060")
            c.alignment = Alignment(wrap_text=True, vertical="center")
        for row in ws.iter_rows(min_row=2):
            for c in row:
                if isinstance(c.value, float):
                    c.number_format = "0.000"
    w.book["leggimi"].column_dimensions["A"].width = 140
print("salvato", OUT)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 30)
print(R.round(2).to_string(index=False))
print(QT[["Paese", "Categoria", "LA Q1", "LA Q5", "QU Q1", "QU Q5", "LA Q1-Q5", "QU Q1-Q5", "Calo Q1-Q5 conservato?"]].round(2).to_string(index=False))
print(L.round(3).to_string(index=False))
print(C.to_string(index=False))
