"""Rebuild cross-wave household links from cover pages and compare with pids_UGA.csv.

Rule (cover-page link variables):
  w1 (2010/11): HHID ("Unique HH Identifier Across Panel Waves") is the root.
  w2 (2011/12): HHID is in the same id system -> linked to the w1 household with the same HHID.
  w3 (2013/14): HHID_old ("link to previous waves 2005/06-2011/12"), read as exact integer string,
                linked to the w2 household with that HHID, else the w1 household with that HHID.
  w4 (2015/16): the cover page has NO link variable. Structural rule: hh 'Hxxxxx-05-ss' is linked to
                w3 hhid 'Hxxxxx-04-ss' (same EA+household+split suffix) when it exists.
  w5 (2018/19): t0_hhid ("Full wave5 UNPS household ID") linked to the w4 8-char hhid.
  w6 (2019/20): hhidold ("Unique hh identifier for wave7") linked to the w5 hhid.
  Everything else starts a new chain. pid = id of the chain's first household.
"""
import sys
import numpy as np
import pandas as pd

sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 30)


def cov(w, cols=None):
    df, _ = R.rd(w, "cover", cols)
    return df


c1, c2, c3, c4, c5, c6 = (cov(w) for w in R.W)
# each wave: own id as used in the panel (food-module id) + predecessor (wave, id)
L = []
L.append(pd.DataFrame({"wave": "w1", "hhid": c1.HHID.str.strip(), "pred_wave": None, "pred": None}))
w1ids = set(c1.HHID.str.strip())
c2["HHID"] = c2.HHID.str.strip()
L.append(pd.DataFrame({"wave": "w2", "hhid": c2.HHID, "pred_wave": np.where(c2.HHID.isin(w1ids), "w1", None),
                       "pred": c2.HHID.where(c2.HHID.isin(w1ids))}))
w2ids = set(c2.HHID)
old = c3.HHID_old.map(lambda v: str(int(v)) if pd.notna(v) else None)
pw = np.where(old.isin(w2ids), "w2", np.where(old.isin(w1ids), "w1", None))
L.append(pd.DataFrame({"wave": "w3", "hhid": c3.hhid, "pred_wave": pw, "pred": old.where(pd.Series(pw).notna().values)}))
cand = c4.hh.str.slice(0, 7) + "04" + c4.hh.str.slice(9)
ok = cand.isin(set(c3.hhid))
L.append(pd.DataFrame({"wave": "w4", "hhid": c4.hh, "pred_wave": np.where(ok, "w3", None), "pred": cand.where(ok)}))
m4 = c4.set_index("hhid").hh  # 8-char -> panel id
t0 = c5.t0_hhid.str.strip()
ok = t0.isin(m4.index)
L.append(pd.DataFrame({"wave": "w5", "hhid": c5.hhid, "pred_wave": np.where(ok, "w4", None), "pred": t0.map(m4).where(ok)}))
ho = c6.hhidold.str.strip()
ok = ho.isin(set(c5.hhid))
L.append(pd.DataFrame({"wave": "w6", "hhid": c6.hhid, "pred_wave": np.where(ok, "w5", None), "pred": ho.where(ok)}))
links = pd.concat(L, ignore_index=True)
links["pred_wave"] = links.pred_wave.where(links.pred.notna())

# roots
root = {}
for w in R.W:
    for r in links[links.wave == w].itertuples():
        if r.pred is not None and isinstance(r.pred, str):
            root[(w, r.hhid)] = root[(r.pred_wave, r.pred)]
        else:
            root[(w, r.hhid)] = r.hhid if w in ("w1", "w2") else f"{w}_{r.hhid}"
links["pid_mine"] = [root[(w, h)] for w, h in zip(links.wave, links.hhid)]
links.to_csv("/home/claude/audit_uga/work/pids_rebuild.csv", index=False)

dup_mine = links.groupby(["wave", "pid_mine"]).size()
print("my links: pids used twice within a wave:", dup_mine[dup_mine > 1].groupby("wave").size().to_dict())
print("links per wave:", links.groupby("wave").pred.apply(lambda s: s.notna().sum()).to_dict(), "of", links.groupby("wave").size().to_dict())

# ---- compare with the panel's pids
P = pd.read_csv("/home/claude/audit_uga/pids_UGA.csv", dtype=str)
print("panel pids rows", len(P), "dups", P.duplicated(["wave", "hhid"]).sum())
dup_p = P.groupby(["wave", "pid"]).size()
print("panel: pids used twice within a wave:", dup_p[dup_p > 1].groupby("wave").size().to_dict())
cmp = links.merge(P, on=["wave", "hhid"], how="outer", indicator=True)
print(cmp._merge.value_counts().to_dict())
# panel predecessor: most recent earlier-wave household with same pid
order = {w: i for i, w in enumerate(R.W)}
P["wi"] = P.wave.map(order)
pp = {}
for pid, g in P.sort_values("wi").groupby("pid"):
    rows = list(g.itertuples())
    for i, r in enumerate(rows):
        prev = [x for x in rows[:i] if x.wi < r.wi]
        pp[(r.wave, r.hhid)] = (prev[-1].wave, prev[-1].hhid) if prev else (None, None)
cmp["pp_wave"] = [pp.get((w, h), (None, None))[0] for w, h in zip(cmp.wave, cmp.hhid)]
cmp["pp"] = [pp.get((w, h), (None, None))[1] for w, h in zip(cmp.wave, cmp.hhid)]
cmp["mine_has"] = cmp.pred.notna()
cmp["pan_has"] = cmp.pp.notna()
cmp["same"] = (cmp.pred.fillna("") == cmp.pp.fillna("")) & (cmp.pred_wave.fillna("") == cmp.pp_wave.fillna(""))
print(cmp.groupby("wave").apply(lambda g: pd.Series({
    "n": len(g), "agree": int(g.same.sum()), "both_link_differ": int((g.mine_has & g.pan_has & ~g.same).sum()),
    "mine_only": int((g.mine_has & ~g.pan_has).sum()), "panel_only": int((~g.mine_has & g.pan_has).sum())})).to_string())
cmp.to_pickle("/home/claude/audit_uga/work/pids_cmp.pkl")
for w in R.W:
    g = cmp[(cmp.wave == w) & ~cmp.same]
    if len(g):
        print("==", w, "disagreements", len(g))
        print(g[["hhid", "pred_wave", "pred", "pp_wave", "pp", "pid_mine", "pid"]].head(25).to_string())
