"""Validate cover-page links with person ids: was the current head a member of the linked predecessor?"""
import sys
import numpy as np
import pandas as pd

sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R

pd.set_option("display.width", 250)
links = pd.read_csv("/home/claude/audit_uga/work/pids_rebuild.csv", dtype=str)


def ros(w, cols):
    df, _ = R.rd(w, "roster", cols)
    return df


r1 = ros("w1", ["HHID", "PID", "h2q4"]); r2 = ros("w2", ["HHID", "PID", "h2q4"])
r3 = ros("w3", ["hhid", "pid", "PID_Old", "h2q4"]); r4 = ros("w4", ["hhid", "pid", "h2q4"])
r5 = ros("w5", ["hhid", "pid", "pid_unps", "h2q4"])
c4, _ = R.rd("w4", "cover", ["hhid", "hh"])
r4["hh"] = r4.hhid.map(c4.set_index("hhid").hh)
print("PID formats", r1.PID.head(2).tolist(), r2.PID.head(2).tolist(), r3.PID_Old.head(2).tolist(), r4.pid.head(2).tolist(), r5.pid_unps.dropna().head(2).tolist())
# person -> household in previous wave
mem = {
    "w1": set(zip(r1.HHID.str.strip(), r1.PID.str.strip())),
    "w2": set(zip(r2.HHID.str.strip(), r2.PID.str.strip())),
    "w3": set(zip(r3.hhid, r3.pid.str.strip())),
    "w4": set(zip(r4.hh, r4.pid.str.strip())),
}
# current heads with their id in the predecessor wave's person-id system
heads = {
    "w2": r2[pd.to_numeric(r2.h2q4, errors="coerce") == 1].assign(hk=lambda d: d.HHID.str.strip(), prev=lambda d: d.PID.str.strip())[["hk", "prev"]],
    "w3": r3[pd.to_numeric(r3.h2q4, errors="coerce") == 1].assign(hk=lambda d: d.hhid, prev=lambda d: d.PID_Old.str.strip())[["hk", "prev"]],
    "w4": r4[pd.to_numeric(r4.h2q4, errors="coerce") == 1].assign(hk=lambda d: d.hh, prev=lambda d: d.pid.str.strip())[["hk", "prev"]],
    "w5": r5[pd.to_numeric(r5.h2q4, errors="coerce") == 1].assign(hk=lambda d: d.hhid, prev=lambda d: d.pid_unps.astype(str).str.strip())[["hk", "prev"]],
}
res = []
for w in ["w2", "w3", "w4", "w5"]:
    lk = links[(links.wave == w) & links.pred.notna()]
    h = heads[w].groupby("hk").prev.apply(list)
    out = []
    for r in lk.itertuples():
        hp = h.get(r.hhid, [])
        hp = [x for x in hp if x and x != "nan"]
        if not hp:
            out.append("head has no earlier person id")
        elif any((r.pred, x) in mem[r.pred_wave] for x in hp):
            out.append("head was member of linked hh")
        else:
            out.append("head was NOT member of linked hh")
    lk = lk.assign(check=out)
    print(w, lk.check.value_counts().to_dict())
    lk.to_csv(f"/home/claude/audit_uga/work/linkcheck_{w}.csv", index=False)
    # where was the head instead?
    bad = lk[lk.check == "head was NOT member of linked hh"]
    if len(bad):
        pm = {}
        for (hk, pid) in mem[{"w2": "w1", "w3": "w2", "w4": "w3", "w5": "w4"}[w]]:
            pm[pid] = hk
        if w == "w3":
            for (hk, pid) in mem["w1"]:
                pm.setdefault(pid, hk)
        bad = bad.assign(head_was_in=[",".join(sorted({pm.get(x, "?") for x in h.get(hh, [])})) for hh in bad.hhid])
        print(bad[["hhid", "pred", "head_was_in"]].head(12).to_string())
        print("  head found elsewhere in same dynasty prefix:",
              int(sum(1 for a, b in zip(bad.pred, bad.head_was_in) if b != "?" and str(b)[:8] == str(a)[:8])), "of", len(bad))
