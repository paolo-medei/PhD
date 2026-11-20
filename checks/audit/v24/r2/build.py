"""Round 2 rebuild: item rows -> unit conversion -> price screen (spec 1) -> products (tracks A/B) -> M17 (spec 2).
Usage from other scripts: build(country, year, screen=True, m17=True) -> (panel-like frame, screen counts dict)."""
import sys, re
sys.path.insert(0, '/home/claude/phd/checks/audit/v24'); sys.path.insert(0, '/home/claude/phd/checks/audit/v24/r2')
from common import *
from items import *
from maps import *

STD = {'TZA': {'milk': 'litre', 'milk_processed': 'litre', 'eggs': 'piece'},
       'UGA': {'milk': 'litre', 'milk_processed': 'litre', 'eggs': 'piece'},
       'MWI': {'milk': 'litre', 'eggs': 'piece'}, 'NGA': {}, 'ETH': {}}
def std_of(c, prod): return STD[c].get(prod, 'kg')

# ---------------- conversion factors (my reading of labels / official tables) ----------------
def tza_factor(y, prod, item, u, x):
    s = std_of('TZA', prod)
    if pd.isna(u): return np.nan
    u = int(u)
    if s == 'kg': return {1: 1.0, 2: 0.001}.get(u, np.nan)
    if s == 'litre': return {3: 1.0, 4: 0.001, 1: 1.0, 2: 0.001}.get(u, np.nan)      # milk: kg taken as litre (earlier audit)
    if s == 'piece':
        if u == 5: return 1.0
        if u == 2: return 1 / 55.0                                                     # 55 g per egg (earlier audit)
        if u == 1: return 1000 / 55.0
        if y == 2020 and u == 20: return 1.0                                           # 2020 eggs 'other (specify)' = pieces
    return np.nan

_NGA = {}
def _nga_tables():
    if _NGA: return _NGA
    c2, _ = pyreadstat.read_dta(B + 'NGA_2012_GHSP-W2_v02_M_STATA/food_conv_w2ph.dta')
    f2 = np.where(c2.g_cl == 1, c2.conv / 1000, c2.conv / 100)
    _NGA[2012] = {(int(a), int(b)): v for a, b, v in zip(c2.item_cd, c2.nsu_cd, f2)}
    c3, _ = pyreadstat.read_dta(B + 'NGA_2015_GHSP-W3_v02_M_Stata/food_conv_w3.dta')
    _NGA[2015] = {(int(a), int(b)): v for a, b, v in zip(c3.item_cd, c3.unit_cd, c3.conv_national) if pd.notna(v)}
    _NGA[2010] = {}
    return _NGA
NGA_FB = {2010: {1: 1.0, 2: 0.001, 3: 1.0, 4: 0.001}, 2012: {1: 1.0, 2: 0.001, 3: 1.0, 4: 0.01}, 2015: {1: 1.0, 2: 0.001, 3: 1.0, 4: 0.01}}
def nga_factor(y, prod, item, u, x):
    if pd.isna(u): return np.nan
    t = _nga_tables()[y]; u = int(u)
    if u in NGA_FB[y]: return NGA_FB[y][u]
    return t.get((int(item), u), np.nan)

GRAMS_RE = re.compile(r'\((\d+(?:\.\d+)?)\s*G\)')
def uga_factor(y, prod, item, u, x, coffee_grams=True):
    x = str(x).strip().upper(); s = std_of('UGA', prod)
    if prod == 'coffee' and coffee_grams == 'never': return np.nan
    if s == 'kg':
        if x.startswith('KILOGRAM'): return 1.0
        if x == 'GRAM': return 0.001
        m = GRAMS_RE.search(x)                      # spec 3: any label stating grams converts at that weight
        if m and (coffee_grams or prod != 'coffee'): return float(m.group(1)) / 1000
        return np.nan
    if s == 'piece':
        if x.startswith('NUMBER OF UNITS') or x.startswith('PIECE'): return 1.0
        if x == 'TRAY OF 30 EGGS': return 30.0
        return np.nan
    if s == 'litre':   # factors as revealed by the panel (old rule, unchanged in this round)
        return {'LITRE': 1.0, 'CUP/MUG(0.5LT)': 0.5, 'KILOGRAM (KG)': 1.0, 'NICE CUP(100G)- LARGE': 0.5, 'NICE CUP(50G)-SMALL': 0.5,
                'NICE CUP(60G)-MEDIUM': 0.5, 'PACKET (1 KG)': 1.0, 'PACKET (250 G)': 0.25, 'PACKET (500 G)': 0.5}.get(x, np.nan)
    return np.nan

def factors(c, y, d, extra=None):
    """add f_k (factor to the product's standard unit) for k in t,p,o,g"""
    if c == 'ETH':
        cf, cfitem = extra
        cf = cf[[cfitem, 'unit_cd', 'mean_cf_nat']].dropna(subset=[cfitem, 'unit_cd'])
        T = {(int(a), int(b)): v for a, b, v in zip(cf[cfitem], cf.unit_cd, cf.mean_cf_nat)}
        cfi = d.item.map(lambda i: ETH_CFMAP.get(int(i), int(i)) if pd.notna(i) else np.nan)
        for k in 'tpog':
            d['f_' + k] = [T.get((int(i), int(u)), np.nan) if pd.notna(u) and pd.notna(i) else np.nan for i, u in zip(cfi, d['u_' + k])]
        return d
    fn = {'TZA': tza_factor, 'NGA': nga_factor, 'UGA': (lambda y, p, i, u, x: uga_factor(y, p, i, u, x, coffee_grams=('never' if extra == 'no_coffee' else extra != 'no_coffee_grams')))}.get(c)
    if fn is not None:
        cache = {}
        for k in 'tpog':
            out = []
            for prod, i, u, x in zip(d['product'], d.item, d['u_' + k], d['x_' + k]):
                key = (prod, i, u)
                if key not in cache: cache[key] = fn(y, prod, i, u, x)
                out.append(cache[key])
            d['f_' + k] = out
        return d
    # MWI: factor table revealed from the old panel (learn_mwi.py), passed in `extra` = {(product,item,u,X,region): f}
    tab = extra
    t2 = {}
    for (pr, it, u, x, rg), f in tab.items():
        if pd.notna(f): t2.setdefault((pr, it, u, x), []).append(f)
    t2 = {k: pd.Series(v).mode().iloc[0] for k, v in t2.items()}
    reg = d.hhid.str[0]
    for k in 'tpog':
        out = []
        for pr, it, u, x, rg in zip(d['product'], d.item, d['u_' + k].astype(str), d['x_' + k].map(lambda z: str(z).strip().upper()), reg):
            key = (pr, it, u, x, rg)
            if pr == 'eggs' and (u == '9' or (u == '23' and x in ('PIECE', 'PIECES'))): out.append(1.0); continue   # one egg
            if key in tab: out.append(tab[key]); continue
            if (pr, it, u, x) in t2: out.append(t2[(pr, it, u, x)]); continue
            out.append(mwi_std_rule(pr, u, x))
        d['f_' + k] = out
    return d

def mwi_std_rule(pr, u, x):
    """fallback for keys not seen in single-item households: metric codes and metric other-specify text"""
    s = std_of('MWI', pr)
    if s == 'kg':
        if u == '1': return 1.0
        if u == '18': return 0.001
    if s == 'litre':
        if u == '15': return 1.0
        if u == '19': return 0.001
    if u == '23':
        t = x.replace(' ', '')
        m = re.match(r'^(\d+(?:\.\d+)?)(KG|KGS|KILOGRAM|KILOGRAMS|KILOGRAMME|KILO|KILOS)$', t)
        if m and s == 'kg': return float(m.group(1))
        m = re.match(r'^(\d+(?:\.\d+)?)(G|GR|GRAM|GRAMS|GRAMME|GRAMMES|GMS)$', t)
        if m and s == 'kg': return float(m.group(1)) / 1000
    return np.nan


# ---------------- price screen ----------------
def price_screen(c, d, strict=True, eggs_band=3.0):
    """d: item rows of one wave with c_k converted quantities. Returns d (modified) and counts."""
    d = d.copy()
    ok = (d.ex > 0) & (d.c_p > 0)
    d['price'] = np.where(ok, d.ex / d.c_p, np.nan)
    med = d.groupby('product').price.transform('median')
    hi = (d.price > 10 * med) if strict else (d.price >= 10 * med)
    lo = (d.price < 0.1 * med) if strict else (d.price <= 0.1 * med)
    n_resc = 0
    same = {k: (d['u_' + k].astype(str) == d['u_p'].astype(str)) & (d['x_' + k].astype(str).str.strip().str.upper() == d['x_p'].astype(str).str.strip().str.upper()) if c == 'MWI'
            else (d['u_' + k].astype(str) == d['u_p'].astype(str)) for k in 'tog'}
    if c in ('TZA', 'UGA', 'MWI'):
        eg = d['product'] == 'eggs'
        up = eg & hi & (d.price / 30 > med / eggs_band) & (d.price / 30 < med * eggs_band)
        dn = eg & lo & (d.price * 30 > med / eggs_band) & (d.price * 30 < med * eggs_band)
        fac = pd.Series(1.0, index=d.index); fac[up] = 30.0; fac[dn] = 1 / 30.0
        resc = up | dn
        n_resc = int(resc.sum())
        d.loc[resc, 'c_p'] = d.loc[resc, 'c_p'] * fac[resc]
        for k in 'tog':
            m = resc & (same[k] | (c == 'UGA'))
            d.loc[m, 'c_' + k] = d.loc[m, 'c_' + k] * fac[m]
        d.loc[resc, 'price'] = d.loc[resc, 'ex'] / d.loc[resc, 'c_p']
        hi = (d.price > 10 * med) if strict else (d.price >= 10 * med)
        lo = (d.price < 0.1 * med) if strict else (d.price <= 0.1 * med)
    bad = (hi | lo) & d.price.notna()
    n_emp = int(bad.sum())
    n_oth = 0; n_oth_rows = 0
    anyo = pd.Series(False, index=d.index)
    for k in 'tog':
        m = bad & (same[k] | (c == 'UGA')) & d['c_' + k].notna()
        n_oth += int(m.sum()); anyo |= m
        d.loc[m, 'c_' + k] = np.nan
    n_oth_rows = int(anyo.sum())
    d.loc[bad, 'c_p'] = np.nan
    d['screened'] = bad
    return d, dict(purch_emptied=n_emp, eggs_rescaled=n_resc, other_cells_emptied=n_oth, other_rows_emptied=n_oth_rows,
                   other_nontotal_cells=int(sum(((bad & (same[k] | (c == 'UGA'))) & True).sum() for k in []) ))

# ---------------- aggregation to products ----------------
def aggregate_products(c, d, allhh, items_of):
    rows = []
    d = d.copy()
    d['exx'] = d.ex.where(d.ex > 0)
    d['pconv'] = d.c_p > 0
    d['exc'] = d.exx.where(d.pconv)
    d['unc'] = (d.exx.notna() & ~d.pconv).astype(int)
    def agg(sub, prod):
        g = sub.groupby('hhid')
        r = pd.DataFrame({'qty': g.c_t.sum(min_count=1), 'purch': g.c_p.sum(min_count=1), 'own': g.c_o.sum(min_count=1),
                          'gift': g.c_g.sum(min_count=1), 'exp': g.exx.sum(min_count=1), 'exp_conv': g.exc.sum(min_count=1),
                          'unconv': g.unc.max(), 'ex0': (sub.ex == 0).groupby(sub.hhid).any()}).reindex(allhh)
        r['unconv'] = r.unconv.fillna(0)
        r['product'] = prod
        return r
    out = {}
    for prod, its in items_of.items():
        out[prod] = agg(d[d['product'] == prod], prod)
    return out, d

def finalize(c, y, prods, track_a):
    rows = []
    for prod, r in prods.items():
        rows.append(r.assign(track='B'))
    meats = [m for m in MEATS if m in prods]
    if c == 'ETH' and y <= 2013:
        rows = [r.assign(track='A') for p, r in prods.items()]
    else:
        for p in track_a:
            if p == 'meat_agg':
                continue
            if p in prods: rows.append(prods[p].assign(track='A'))
    P = pd.concat(rows).reset_index().rename(columns={'index': 'hhid'})
    P['year'] = y
    return P

def add_meat_agg(c, y, d, allhh):
    """track A meat_agg = all meat item rows of the wave (B meats)"""
    if c == 'ETH' and y <= 2013: return None
    sub = d[d['product'].isin(MEATS)]
    g = sub.groupby('hhid')
    r = pd.DataFrame({'qty': g.c_t.sum(min_count=1), 'purch': g.c_p.sum(min_count=1), 'own': g.c_o.sum(min_count=1),
                      'gift': g.c_g.sum(min_count=1), 'exp': g.exx.sum(min_count=1), 'exp_conv': g.exc.sum(min_count=1),
                      'unconv': g.unc.max()}).reindex(allhh)
    r['unconv'] = r.unconv.fillna(0); r['product'] = 'meat_agg'; r['track'] = 'A'
    return r.reset_index().rename(columns={'index': 'hhid'}).assign(year=y)

def m17(P):
    P = P.copy()
    g = P.groupby(['year', 'product', 'track'])
    mq = g.qty.transform(lambda s: s[s > 0].median()); mp = g.purch.transform(lambda s: s[s > 0].median())
    flag = (P.qty > 100 * mq) | (P.purch > 100 * mp)
    P['m17'] = flag
    for k in ['qty', 'purch', 'own', 'gift', 'exp_conv']: P.loc[flag, k] = np.nan
    P.loc[flag & (P.exp > 0), 'unconv'] = 1
    return P

def build(c, y, screen=True, do_m17=True, strict=True, extra_tab=None, mapping=None):
    r = LOADERS[c](y)
    if c == 'ETH': d, cf, cfitem = r; extra = (cf, cfitem)
    elif c == 'UGA': d, ul = r; extra = extra_tab
    else: d = r; extra = extra_tab
    allhh = d.hhid.unique()
    mp = dict(mapping or MAPS[c])
    mp.pop('meat_agg_old', None)
    if c == 'ETH' and y <= 2013: mp = {'milk': [19], 'cheese': [20], 'eggs': [21], 'coffee': [24], 'meat_agg': [18]}
    if c == 'NGA' and y != 2010: mp['milk_processed'] = [i for i in mp['milk_processed'] if i != 114]   # cheese (wara) only in 2010's group
    i2p = {i: p for p, its in mp.items() for i in its}
    d = d[d.item.isin(i2p)].copy()
    d['product'] = d.item.map(i2p)
    if c == 'ETH' and y <= 2013:
        pass
    d = factors(c, y, d, extra)
    d['ex'] = pd.to_numeric(d['ex'], errors='coerce').astype(float)
    for k in 'tpog':
        q = pd.to_numeric(d['q_' + k], errors='coerce').astype(float)
        d['c_' + k] = (q * pd.to_numeric(d['f_' + k], errors='coerce').astype(float)).where(q > 0)
    counts = {}
    if screen:
        d, counts = price_screen(c, d, strict=strict)
    prods, d2 = aggregate_products(c, d, allhh, mp)
    P = finalize(c, y, prods, TRACK_A[c])
    ma = add_meat_agg(c, y, d2, allhh)
    if ma is not None: P = pd.concat([P, ma], ignore_index=True)
    if c == 'ETH':
        # ETH conventions: unconv defined for purchasers only (track B); track A zeros -> NA
        z = (P.track == 'B') & P.exp.isna() & (P.ex0 == True)          # spending reported as 0 is kept as 0
        P.loc[z, 'exp'] = 0.0; P.loc[z, 'unconv'] = 0.0
        P.loc[z & (P.purch > 0), 'exp_conv'] = 0.0
        P.loc[(P.track == 'B') & ~(P.exp.notna()), 'unconv'] = np.nan
    if do_m17: P = m17(P)
    for k in ['qty', 'purch', 'own', 'gift', 'exp', 'exp_conv', 'unconv']: P[k] = P[k].astype(float)
    P['uv'] = P.exp_conv / P.purch
    P.loc[~(P.uv > 0) | ~np.isfinite(P.uv), 'uv'] = np.nan
    return P, counts, d2
