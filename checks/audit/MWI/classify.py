"""Assign every mismatching (row, column) to an explained pattern."""
import re

import numpy as np
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_rows", 500)
b = pd.read_pickle("/home/claude/audit_mwi/work/merged.pkl")
QCOLS = ["qty_std", "purch_std", "own_std", "gift_std", "exp_conv", "unconv", "uv"]
HCOLS = ["share_child", "share_elderly", "head_age", "head_female"]
PB = {504: "beef", 505: "goat_sheep", 507: "goat_sheep", 506: "pork", 508: "poultry", 509: "poultry",
      501: "eggs", 701: "milk", 702: "milk_processed", 902: "coffee"}
PA = {k: ("meat_agg" if 504 <= k <= 509 else v) for k, v in PB.items() if k != 702}

items = {w: pd.read_pickle(f"/home/claude/audit_mwi/work/items_{w}.pkl") for w in ["w1", "w2", "w3", "w4"]}

# camp households (2024)
import sys
sys.path.insert(0, "/home/claude/audit_mwi/work")
from load import FILES, read, txt  # noqa: E402
a4, _ = read(FILES["w4"]["a"], ["case_id", "camp"])
camp = set(txt(a4.case_id)[a4.camp == 1])

PATTERNS = [
    ("decimal comma in metric text (CSV reads '0,3 KILOGRAMMES' as 3 kg)", r"\d,\d"),
    ("HALF KG (metric amount, CSV not converted)", r"HALF KG"),
    ("HALF CHICKEN (CSV not converted)", r"HALF CHICKEN"),
    ("CHICKENS plural (CSV not converted)", r"CHICKENS"),
    ("GARAMSACHET: my sachet rule gives 7.5 kg, CSV empty (truth 0.5 kg)", r"GARAMSACHET"),
    ("egg 'PIECE (MEDIUM)' (CSV not converted)", r"PIECE \(MEDIUM\)"),
    ("misspelt metric unit (MILLITER/MILLITRE/MILITRE/MILLILITERS/MLS/GRAMM/trailing '.')",
     r"MILLITERS?|MILLITRES?|MILITRE|MILLILITERS|^MLS$|GRAMMS?$|MILLILITRES\.$"),
    ("sachet text with qualifier for fresh milk ('SATCHET (SMALL)', 'MEDIUM SACHET'; CSV not converted)",
     r"^(SATCHET \(SMALL\)|MEDIUM SACHET)$"),
    ("powdered-milk sachet (CSV never applies the sachet rule to 702)", r"SACHET|SATCHET"),
]


def item_texts(w, h, prod, track):
    g = items[w]
    pm = PB if track == "B" else PA
    its = [k for k, v in pm.items() if v == prod]
    s = g[(g.case_id == h) & g.item.isin(its) & (g.g01 == 1)]
    texts = []
    for q in ["03", "04", "06", "07"]:
        for it, u, t, f, r in s[["item", f"u{q}", f"t{q}", f"f{q}", f"rule{q}"]].itertuples(index=False):
            if u == "23":
                texts.append((it, t))
    return texts


rows = []
for col in QCOLS + HCOLS:
    bad = b[~b["ok_" + col]]
    for r in bad.itertuples():
        w, h, prod, track = r.wave, r.hhid, r.product, r.track
        cause = None
        if col in HCOLS:
            cause = ("Dzaleka camp household not in consumption aggregate: CSV blanks roster variables"
                     if h in camp else "roster member with missing age: CSV drops him/her from the denominator")
        else:
            texts = item_texts(w, h, prod, track)
            for name, pat in PATTERNS:
                hit = [t for it, t in texts if re.search(pat, t)]
                if name.startswith("powdered") and not any(it == 702 for it, t in texts if re.search(pat, t)):
                    continue
                if name.startswith("sachet text") and not any(it == 701 for it, t in texts if re.search(pat, t)):
                    continue
                if hit:
                    cause = name
                    break
            if cause is None:
                cause = "UNEXPLAINED"
        rows.append(dict(wave=w, column=col, pattern=cause, hhid=h, product=prod, track=track,
                         csv=getattr(r, col + "_t"), rebuild=getattr(r, col + "_m")))
c = pd.DataFrame(rows)
c.to_csv("/home/claude/audit_mwi/work/mismatch_classified.csv", index=False)
print(c.groupby(["pattern", "column", "wave"]).size().unstack("wave").fillna(0).astype(int).to_string())
print(c.groupby("pattern").agg(rows=("hhid", "size"), hh=("hhid", "nunique")).to_string())
print("unexplained", (c.pattern == "UNEXPLAINED").sum())
