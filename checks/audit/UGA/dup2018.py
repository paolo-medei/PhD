import sys
import pandas as pd
sys.path.insert(0, "/home/claude/audit_uga/work")
import rebuild as R
pd.set_option("display.width", 250)
f, _ = R.rd("w5", "food")
r, _ = R.rd("w5", "roster", ["hhid", "pid", "pid_unps", "h2q3", "h2q4", "h2q8", "h2q7"])
pairs = [("1ef4272d96c04493bc66559cc7f9cd98", "2ac0a1e73f624dfc91343ac47f68c9f4"), ("8467c8fd86c64da5b6fa2b6040eea6c7", "d286b822c04f4839a7f6c9c473384156"),
         ("37ff9ca27dec476fae3ab23cb6e6e3bb", "5dc7dd81d1334c3fa6d23a1ebff23c21"), ("456103859120412ba80e3e5d4c19890d", "ebcbdd6393f1445392d57880f2c6f016"),
         ("96ccd06ae58743748ddf9498fd5144d5", "d757910c0fa54b81b0713ac9ab54d567")]
cols = ["CEB01", "CEB03", "CEB03C", "CEB06", "CEB07", "CEB10", "CEB11"]
for a, b in pairs:
    fa = f[(f.hhid == a) & (f.CEB03 == 1)][cols].reset_index(drop=True)
    fb = f[(f.hhid == b) & (f.CEB03 == 1)][cols].reset_index(drop=True)
    same = fa.shape == fb.shape and fa.fillna(-1).equals(fb.fillna(-1))
    ra = r[r.hhid == a][["pid_unps", "h2q3", "h2q4", "h2q8", "h2q7"]].fillna("").values.tolist()
    rb = r[r.hhid == b][["pid_unps", "h2q3", "h2q4", "h2q8", "h2q7"]].fillna("").values.tolist()
    print(a[:8], b[:8], "food items", len(fa), len(fb), "identical food:", same)
    print("   roster a:", ra[:6]); print("   roster b:", rb[:6])
