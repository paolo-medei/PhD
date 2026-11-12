"""Usage: python3 -I checks/independent_estimates.py data/OUTPUT <folder with pids_*.csv>
(pids_*.csv from checks/dump_panel_ids.R).

Independent re-estimation (numpy) of the headline numbers from the panel CSVs.
Not a copy of the R code: weighted least squares with fixed effects absorbed by
weighted alternating projections, cluster-robust SEs (CR1)."""
import sys, numpy as np, pandas as pd
from scipy import stats
P = sys.argv[1]; S = sys.argv[2]   # panel folder (data/OUTPUT), folder with pids_*.csv
COLS = {"ETH": dict(q="purch_kg", w="weight", x="nom_totcons_aeq", hh="hh_size", urb="urban_code"),
        "TZA": dict(q="purch_std", w="hhweight", x="welfare", hh="hhsize", urb="urban"),
        "NGA": dict(q="purch_kg", w="hhweight", x="welfare", hh="hhsize", urb="urban")}

def load(cc):
    c = COLS[cc]
    d = pd.read_csv(f"{P}/panel_{cc}.csv", dtype={"hhid": str, "region": str, c["urb"]: str}, low_memory=False)
    d["qty"] = pd.to_numeric(d[c["q"]], errors="coerce")
    d["w"] = pd.to_numeric(d[c["w"]], errors="coerce"); d.loc[~(d.w > 0), "w"] = 1.0
    d["x"] = pd.to_numeric(d[c["x"]], errors="coerce")
    ae = pd.to_numeric(d["adulteq"], errors="coerce").fillna(pd.to_numeric(d[c["hh"]], errors="coerce"))
    d["ae"] = np.maximum(ae, 1)
    d["l_ae"] = np.log(d.ae)
    d["urban"] = d[c["urb"]].astype(str).str.strip().isin(["1", "1.0", "URBAN", "Urban"]).astype(float)
    d["unconv"] = pd.to_numeric(d["unconv"], errors="coerce").fillna(0)
    d["uv"] = pd.to_numeric(d["uv"], errors="coerce")
    pid = pd.read_csv(f"{S}/pids_{cc}.csv", dtype=str)
    assert not pid.duplicated(["hhid", "wave"]).any()
    d = d.merge(pid, on=["hhid", "wave"], how="left", validate="many_to_one")
    return d

def demean(cols, fes, w, tol=1e-10, it=500):
    M = cols.copy()
    for _ in range(it):
        old = M.copy()
        for f in fes:
            g = pd.Series(f).astype(str).values
            df = pd.DataFrame(M * w[:, None]); df["g"] = g
            sw = pd.Series(w).groupby(g).transform("sum").values
            means = df.groupby("g").transform("sum").values / sw[:, None]
            M = M - means
        if len(fes) == 1 or np.max(np.abs(M - old)) < tol: break
    return M

def wls(y, X, fes, w, cl=None):
    ok = np.isfinite(y) & np.all(np.isfinite(X), axis=1) & np.isfinite(w)
    for f in fes: ok &= pd.notna(pd.Series(f)).values
    if cl is not None: ok &= pd.notna(pd.Series(cl)).values
    y, X, w = y[ok], X[ok], w[ok]; fes = [np.asarray(f)[ok] for f in fes]
    M = demean(np.column_stack([y, X]), fes, w) if fes else np.column_stack([y, X - 0]) 
    if not fes:  # intercept
        M = np.column_stack([y, np.ones(len(y)), X]); yt, Xt = M[:, 0], M[:, 1:]
    else: yt, Xt = M[:, 0], M[:, 1:]
    sw = np.sqrt(w); b, *_ = np.linalg.lstsq(Xt * sw[:, None], yt * sw, rcond=None)
    e = yt - Xt @ b; XtWX_inv = np.linalg.pinv((Xt * w[:, None]).T @ Xt)
    n, k = Xt.shape
    if cl is None:
        s = Xt * (w * e)[:, None]; meat = s.T @ s; V = XtWX_inv @ meat @ XtWX_inv * n / (n - k); dfree = n - k
    else:
        g = np.asarray(cl)[ok]; s = pd.DataFrame(Xt * (w * e)[:, None]).groupby(g).sum().values
        G = s.shape[0]; V = XtWX_inv @ (s.T @ s) @ XtWX_inv * G / (G - 1) * (n - 1) / (n - k); dfree = G - 1
    se = np.sqrt(np.diag(V)); p = 2 * stats.t.sf(np.abs(b / se), dfree)
    off = 1 if not fes else 0
    return b[off:], p[off:], n

out = []
def rec(**k): out.append(k)

for cc in ["ETH", "TZA", "NGA"]:
    d = load(cc)
    ctrl = ["l_ae", "urban"] + [v for v in ["share_child", "share_elderly", "head_age", "head_female"]
                               if v in d and pd.to_numeric(d[v], errors="coerce").notna().mean() > .5]
    for v in ctrl: d[v] = pd.to_numeric(d[v], errors="coerce")
    A = d[d.track == "A"].copy(); A["l_x"] = np.log(A.x.where(A.x > 0))
    # ---- 1. decomposition, meat, year by year ------------------------------
    for y, g in A[A["product"] == "meat_agg"].groupby("year"):
        b = g[(g.uv > 0) & (g.qty > 0) & (g.x > 0) & (g.unconv == 0)]
        q1, q99 = np.quantile(b.uv, [.01, .99]); b = b[(b.uv >= q1) & (b.uv <= q99)]
        X = b[["l_x"] + ctrl].values
        bq, pq, n = wls(np.log(b.uv.values), X, [b.region.values], b.w.values)
        bn, pn, _ = wls(np.log(b.qty.values), X, [b.region.values], b.w.values)
        rec(country=cc, check="decomposition meat", cell=str(y), stat="e_quality", mine=bq[0], p=pq[0], n=n)
        rec(country=cc, check="decomposition meat", cell=str(y), stat="e_quantity", mine=bn[0], p=pn[0], n=n)
    # ---- 2. participation by quintile, meat ---------------------------------
    H = A[(A["product"] == "meat_agg") & (A.x > 0)].copy()
    H["qt"] = H.groupby("year").x.transform(lambda s: pd.qcut(s.rank(method="first"), 5, labels=False) + 1)
    H["buys"] = (H.qty > 0).astype(float)
    for q, g in H.groupby("qt"):
        rec(country=cc, check="participation meat by quintile", cell=f"Q{q}", stat="pct", mine=100 * np.average(g.buys, weights=g.w), p=np.nan, n=len(g))
    # ---- 3. permanent vs transitory, household FE, long differences ---------
    lvl = A[(A["product"] == "meat_agg") & (A.x > 0)].drop_duplicates(["hhid", "year"])
    ym = lvl.groupby("year").apply(lambda g: np.average(np.log(g.x), weights=g.w), include_groups=False)
    B = A[(A["product"] == "meat_agg") & (A.x > 0) & (A.uv > 0) & (A.qty > 0) & (A.unconv == 0) & A.pid.notna()].copy()
    B = B[B.groupby("pid").year.transform("nunique") > 1]
    B["lxd"] = B.l_x - B.year.map(ym)
    for tag, col in [("nominale (come v21)", "l_x"), ("corretto: deflazionato per anno", "lxd")]:
        B["perm"] = B.groupby("pid")[col].transform("mean"); B["trans"] = B[col] - B.perm
        X = B[["perm", "trans", "l_ae"]].values
        bq, pq, n = wls(np.log(B.uv.values), X, [B.year.values], B.w.values, cl=B.pid.values)
        bn, pn, _ = wls(np.log(B.qty.values), X, [B.year.values], B.w.values, cl=B.pid.values)
        for nm, v, pp in [("quality_perm", bq[0], pq[0]), ("quality_trans", bq[1], pq[1]),
                          ("quantity_perm", bn[0], pn[0]), ("quantity_trans", bn[1], pn[1])]:
            rec(country=cc, check="permanent vs transitory meat", cell=tag, stat=nm, mine=v, p=pp, n=n)
        Xa = B[["perm", "l_ae"]].values
        ba, pa, _ = wls(np.log(B.uv.values), Xa, [B.year.values], B.w.values, cl=B.pid.values)
        rec(country=cc, check="attenuation meat", cell=tag, stat="quality_mean_welfare", mine=ba[0], p=pa[0], n=n)
    X = B[["l_x", "l_ae"]].values
    bq, pq, n = wls(np.log(B.uv.values), X, [B.pid.values, B.year.values], B.w.values, cl=B.pid.values)
    bn, pn, _ = wls(np.log(B.qty.values), X, [B.pid.values, B.year.values], B.w.values, cl=B.pid.values)
    rec(country=cc, check="household FE meat", cell="pid + year", stat="e_quality_FE", mine=bq[0], p=pq[0], n=n)
    rec(country=cc, check="household FE meat", cell="pid + year", stat="e_quantity_FE", mine=bn[0], p=pn[0], n=n)
    L = B.sort_values("year").groupby("pid").agg(fy=("year", "first"), ly=("year", "last"), lx0=("l_x", "first"), lx1=("l_x", "last"),
        u0=("uv", "first"), u1=("uv", "last"), q0=("qty", "first"), q1=("qty", "last"), a0=("l_ae", "first"), a1=("l_ae", "last"), w=("w", "first")).reset_index()
    L = L[(L.ly - L.fy) >= 2]
    L["d_lx"] = L.lx1 - L.lx0; L["d_luv"] = np.log(L.u1) - np.log(L.u0); L["d_lq"] = np.log(L.q1) - np.log(L.q0); L["d_lae"] = L.a1 - L.a0
    L["pair"] = L.fy.astype(str) + "-" + L.ly.astype(str)
    for tag, fes in [("nominale (come v21)", []), ("corretto: effetti fissi coppia di anni", [L.pair.values])]:
        X = L[["d_lx", "d_lae"]].values
        bq, pq, n = wls(L.d_luv.values, X, fes, L.w.values)
        bn, pn, _ = wls(L.d_lq.values, X, fes, L.w.values)
        rec(country=cc, check="long differences meat", cell=tag, stat="quality_longdiff", mine=bq[0], p=pq[0], n=n)
        rec(country=cc, check="long differences meat", cell=tag, stat="quantity_longdiff", mine=bn[0], p=pn[0], n=n)

pd.DataFrame(out).to_csv(f"{S}/mine.csv", index=False)
print(pd.DataFrame(out).round(4).to_string())
