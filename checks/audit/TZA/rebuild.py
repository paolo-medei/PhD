"""Independent rebuild of the TZA household x product panel from raw LSMS-ISA NPS Stata files.
Variables identified from .dta labels (see report.md). Output: mine_food.parquet (food part), mine_hh.parquet (hh part)."""
import pyreadstat, pandas as pd, numpy as np, sys
PC = '--pipeconv' in sys.argv
SUF = '_pc' if PC else ''

R = '/home/claude/work/final/data/_unzipped/'
W1 = R + 'TZA_2008_NPS1_v02_M_STATA_English_labels/TZA_2008_NPS1_v02_M_STATA_English_labels/'
W2 = R + 'TZA_2010_NPS-R2_v03_M_STATA8/TZA_2010_NPS-R2_v03_M_STATA8/'
W3 = R + 'TZA_2012_NPS-R3_v01_M_STATA8_English_labels/TZA_2012_NPS-R3_v01_M_STATA8_English_labels/'
W4 = R + 'TZA_2014_NPS-R4_v03_M_STATA11/TZA_2014_NPS-R4_v03_M_STATA11/'
W5 = R + 'TZA_2020_NPS-R5_v02_M_STATA14/'
OUT = '/tmp/claude-0/-home-claude/7ac6c5ea-bbde-5aa6-a290-e032a3cd70ac/scratchpad/verify_TZA/'

# ---------------- food module -----------------
# columns: hhid, item, q1 (consumed yes=1), tu,tq (total), pu,pq (purchased), exp, ou,oq (own), gu,gq (gifts)
FOOD = {
    'w1': (W1 + 'SEC_K1.dta', 'hhid', 'skcode',
           ['skq1', 'skq2_meas', 'skq2_amount', 'skq3_meas', 'skq3_amount', 'skq4', 'skq5_meas', 'skq5_amount', 'skq6_meas', 'skq6_amount']),
    'w2': (W2 + 'HH_SEC_K1.dta', 'y2_hhid', 'itemcode',
           ['hh_k01_2', 'hh_k02_1', 'hh_k02_2', 'hh_k03_1', 'hh_k03_2', 'hh_k04', 'hh_k05_1', 'hh_k05_2', 'hh_k06_1', 'hh_k06_2']),
    'w3': (W3 + 'HH_SEC_J1.dta', 'y3_hhid', 'itemcode',
           ['hh_j01', 'hh_j02_1', 'hh_j02_2', 'hh_j03_1', 'hh_j03_2', 'hh_j04', 'hh_j05_1', 'hh_j05_2', 'hh_j06_1', 'hh_j06_2']),
    'w4': (W4 + 'hh_sec_j1.dta', 'y4_hhid', 'itemcode',
           ['hh_j01', 'hh_j02_1', 'hh_j02_2', 'hh_j03_1', 'hh_j03_2', 'hh_j04', 'hh_j05_1', 'hh_j05_2', 'hh_j06_1', 'hh_j06_2']),
    'w5': (W5 + 'hh_sec_ja1.dta', 'y5_hhid', 'itemcode',
           ['hh_ja01', 'hh_ja02_1', 'hh_ja02_2', 'hh_ja03_1', 'hh_ja03_2', 'hh_ja04', 'hh_ja05_1', 'hh_ja05_2', 'hh_ja06_1', 'hh_ja06_2']),
    # 2020 standard module answered by the 419 households with j1_selection==2 (not in the pipeline panel)
    'w5J1': (W5 + 'hh_sec_j1.dta', 'y5_hhid', 'itemcode',
             ['hh_j01', 'hh_j02_1', 'hh_j02_2', 'hh_j03_1', 'hh_j03_2', 'hh_j04', 'hh_j05_1', 'hh_j05_2', 'hh_j06_1', 'hh_j06_2']),
}
NEW = ['q1', 'tu', 'tq', 'pu', 'pq', 'exp', 'ou', 'oq', 'gu', 'gq']

# item codes (from value labels)
ITEMS = {
    'goat_sheep': [801],          # GOAT MEAT
    'beef': [802],                # BEEF INCLUDING MINCED SAUSAGE
    'pork': [803],                # PORK INCLUDING SAUSAGES AND BACON
    'poultry': [804, 8041, 8042], # CHICKEN AND OTHER POULTRY (2020: 8041 chicken, 8042 other poultry)
    'eggs': [807],
    'milk': [901],                # FRESH MILK
    'cheese': [902],              # MILK PRODUCTS (LIKE CREAM, CHEESE, YOGHURT ETC)
    'coffee': [1102],             # COFFEE AND COCOA
}
STD = {'goat_sheep': 'kg', 'beef': 'kg', 'pork': 'kg', 'poultry': 'kg', 'cheese': 'kg', 'coffee': 'kg', 'milk': 'litre', 'eggs': 'piece'}
item2prod = {c: p for p, cs in ITEMS.items() for c in cs}


def conv(u, q, std, wave, prod):
    """convert quantity q in unit u (1 kg,2 g,3 l,4 ml,5 piece) to std; zero/NA -> NA; non-convertible -> NA"""
    u = pd.to_numeric(u, errors='coerce'); q = pd.to_numeric(q, errors='coerce')
    f = pd.Series(np.nan, index=u.index)
    if std == 'kg':
        f[u == 1] = 1.0; f[u == 2] = 0.001
    elif std == 'litre':
        f[u == 3] = 1.0; f[u == 4] = 0.001
    elif std == 'piece':
        f[u == 5] = 1.0
        if wave == 'w5' and prod == 'eggs':
            f[u == 20] = 1.0   # student's rule: 2020 eggs in 'OTHER (SPECIFY)' = pieces
        if PC and prod == 'eggs':   # pipeline convention discovered in audit: 55 g per egg
            f[u == 2] = 1 / 55.0; f[u == 1] = 1000 / 55.0
    if PC and std == 'litre':       # pipeline convention discovered in audit: milk kg = litre
        f[u == 1] = 1.0; f[u == 2] = 0.001
    out = q * f
    out[~(q > 0)] = np.nan
    return out


def load_food(w):
    f, h, ic, cols = FOOD[w]
    d, m = pyreadstat.read_dta(f, usecols=[h, ic] + cols)
    d = d.rename(columns=dict(zip([h, ic] + cols, ['hhid', 'item'] + NEW)))
    d['hhid'] = d['hhid'].astype(str)
    hh_all = d['hhid'].unique()
    d = d[d['item'].isin(item2prod)].copy()
    d['product'] = d['item'].map(item2prod)
    wv = 'w5' if w.startswith('w5') else w
    rows = []
    for p, g in d.groupby('product'):
        g = g.copy(); s = STD[p]
        g['cons'] = (g.q1 == 1).astype(float)
        g.loc[g.q1.isna(), 'cons'] = np.nan   # missing answer -> NA
        g['qty'] = conv(g.tu, g.tq, s, wv, p)
        g['pur'] = conv(g.pu, g.pq, s, wv, p)
        g['own'] = conv(g.ou, g.oq, s, wv, p)
        g['gif'] = conv(g.gu, g.gq, s, wv, p)
        g['ex'] = pd.to_numeric(g.exp, errors='coerce')
        g.loc[~(g.ex > 0), 'ex'] = np.nan
        # non-consumers: all NA
        for c in ['qty', 'pur', 'own', 'gif', 'ex']:
            g.loc[g.cons != 1, c] = np.nan
        rows.append(g)
    d = pd.concat(rows)
    # aggregate multiple item codes per product (only 2020 poultry 8041+8042)
    def nsum(x):
        return x.sum(min_count=1)
    agg = d.groupby(['hhid', 'product']).agg(cons=('cons', 'max'), qty=('qty', nsum), pur=('pur', nsum), own=('own', nsum),
                                             gif=('gif', nsum), ex=('ex', nsum),
                                             # any component with spending but non-convertible purchase
                                             any_unconv=('ex', lambda s: False)).reset_index()
    # unconv / exp_conv at item level then summed (matters only for 2020 poultry)
    d['exconv'] = np.where(d.pur.notna(), d.ex, np.nan)
    d['unc'] = ((d.ex > 0) & d.pur.isna()).astype(int)
    a2 = d.groupby(['hhid', 'product']).agg(exconv=('exconv', nsum), unc=('unc', 'max')).reset_index()
    agg = agg.drop(columns='any_unconv').merge(a2, on=['hhid', 'product'])
    agg['std'] = agg['product'].map(STD)
    agg['track'] = 'B'
    # track A
    A = agg[agg['product'].isin(['milk', 'eggs', 'coffee'])].copy(); A['track'] = 'A'
    meats = d[d['product'].isin(['beef', 'goat_sheep', 'pork', 'poultry'])]
    M = meats.groupby('hhid').agg(cons=('cons', 'max'), qty=('qty', nsum), pur=('pur', nsum), own=('own', nsum), gif=('gif', nsum),
                                  ex=('ex', nsum), exconv=('exconv', nsum), unc=('unc', 'max')).reset_index()
    M['product'] = 'meat_agg'; M['std'] = 'kg'; M['track'] = 'A'
    out = pd.concat([agg, A, M], ignore_index=True)
    out['wave'] = wv
    out['src'] = w
    return out, hh_all


# ---------------- household level -----------------
def rd(f, cols=None):
    d, _ = pyreadstat.read_dta(f, usecols=cols)
    return d


def hh_vars():
    H = {}
    # w1: aggregate TZY1.HH.Consumption (2008 folder) ; cover SEC_A_T for clusterid/strataid
    a = rd(W1 + 'TZY1.HH.Consumption.dta'); c = rd(W1 + 'SEC_A_T.dta')
    a = a.merge(c[['hhid', 'clusterid', 'strataid', 'hh_weight', 'hh_weight_trimmed', 'region', 'rural']].rename(columns={'region': 'region_a'}), on='hhid', how='outer')
    H['w1'] = pd.DataFrame({'hhid': a.hhid, 'adulteq': a.adulteq, 'hhsize': a.hhsize, 'urban': a.urban, 'region': a.region,
                            'hhweight': a.hhweight, 'welfare': a.expmR / a.adulteq, 'clusterid': a.clusterid, 'strataid': a.strataid,
                            'alt_cluster': a.cluster, 'alt_strata': a.strata, 'alt_w': a.hh_weight, 'alt_wt': a.hh_weight_trimmed, 'alt_region': a.region_a})
    # w2
    a = rd(W2 + 'TZY2.HH.Consumption.dta'); c = rd(W2 + 'HH_SEC_A.dta', ['y2_hhid', 'y2_weight', 'y2_rural', 'clusterid', 'strataid', 'region'])
    a = c.merge(a, on='y2_hhid', how='left', suffixes=('_a', ''))
    H['w2'] = pd.DataFrame({'hhid': a.y2_hhid, 'adulteq': a.adulteq, 'hhsize': a.hhsize, 'urban': a.urban, 'region': a.region,
                            'hhweight': a.hhweight, 'welfare': a.expmR / a.adulteq, 'clusterid': a.clusterid, 'strataid': a.strataid,
                            'alt_w': a.y2_weight, 'alt_region': a.region_a, 'alt_urban': 2 - a.y2_rural})
    # w3: aggregate has no weight -> HH_SEC_A y3_weight / Y3_weights
    a = rd(W3 + 'ConsumptionNPS3.dta'); c = rd(W3 + 'HH_SEC_A.dta', ['y3_hhid', 'y3_rural', 'clusterid', 'strataid', 'y3_weight', 'hh_a01_1'])
    wt = rd(W3 + 'Y3_weights.dta')
    a = c.merge(a, on='y3_hhid', how='left').merge(wt, on='y3_hhid', how='left')
    H['w3'] = pd.DataFrame({'hhid': a.y3_hhid, 'adulteq': a.adulteq, 'hhsize': a.hhsize, 'urban': a.urban, 'region': a.region,
                            'hhweight': a.y3_weight, 'welfare': a.expmR / a.adulteq, 'clusterid': a.clusterid, 'strataid': a.strataid,
                            'alt_w': a.y3_panelweight, 'alt_region': a.hh_a01_1, 'alt_urban': 2 - a.y3_rural})
    # w4
    a = rd(W4 + 'consumptionNPS4.dta'); c = rd(W4 + 'hh_sec_a.dta', ['y4_hhid', 'y4_rural', 'strataid', 'clusterid', 'y4_weights', 'hh_a01_1'])
    a = c.merge(a, on='y4_hhid', how='left')
    a20 = rd(W5 + 'consumption_real_y4.dta', ['y4_hhid', 'expmR_pae', 'adulteq', 'hhweight']).rename(columns={'expmR_pae': 'pae20', 'adulteq': 'ae20', 'hhweight': 'w20'})
    a = a.merge(a20, on='y4_hhid', how='left')
    H['w4'] = pd.DataFrame({'hhid': a.y4_hhid, 'adulteq': a.adulteq, 'hhsize': a.hhsize, 'urban': a.urban, 'region': a.region,
                            'hhweight': a.hhweight, 'welfare': a.expmR / a.adulteq, 'clusterid': a.clusterid, 'strataid': a.strataid,
                            'alt_w': a.y4_weights, 'alt_region': a.hh_a01_1, 'alt_urban': 2 - a.y4_rural, 'alt_cluster': a.cluster, 'alt_strata': a.strata,
                            'alt_pae28_y5file': a.pae20, 'alt_ae_y5file': a.ae20})
    # w5
    a = rd(W5 + 'consumption_real_y5.dta'); c = rd(W5 + 'hh_sec_a.dta', ['y5_hhid', 'clusterid', 'strataid', 'y5_crossweight', 'y5_rural', 'hh_a01_1', 'j1_selection'])
    a = c.merge(a, on='y5_hhid', how='left')
    H['w5'] = pd.DataFrame({'hhid': a.y5_hhid, 'adulteq': a.adulteq, 'hhsize': a.hhsize, 'urban': a.urban, 'region': a.region,
                            'hhweight': a.hhweight, 'welfare': a.expmR_pae, 'clusterid': a.clusterid, 'strataid': a.strataid,
                            'alt_w': a.y5_crossweight, 'alt_region': a.hh_a01_1, 'alt_urban': 2 - a.y5_rural, 'alt_cluster': a.cluster,
                            'alt_strata': a.strata, 'alt_welfare_annual': a.expm / a.adulteq, 'j1_selection': a.j1_selection})
    for w, df in H.items():
        df['wave'] = w
        df['hhid'] = df['hhid'].astype(str)
    return H


ROSTER = {
    'w1': (W1 + 'SEC_B_C_D_E1_F_G1_U.dta', 'hhid', 'sbq2', 'sbq4', 'sbq5'),
    'w2': (W2 + 'HH_SEC_B.dta', 'y2_hhid', 'hh_b02', 'hh_b04', 'hh_b05'),
    'w3': (W3 + 'HH_SEC_B.dta', 'y3_hhid', 'hh_b02', 'hh_b04', 'hh_b05'),
    'w4': (W4 + 'hh_sec_b.dta', 'y4_hhid', 'hh_b02', 'hh_b04', 'hh_b05'),
    'w5': (W5 + 'hh_sec_b.dta', 'y5_hhid', 'hh_b02', 'hh_b04', 'hh_b05'),
}


def roster(w):
    f, h, sx, ag, rel = ROSTER[w]
    d, m = pyreadstat.read_dta(f, usecols=[h, sx, ag, rel])
    d = d.rename(columns={h: 'hhid', sx: 'sex', ag: 'age', rel: 'rel'})
    d['hhid'] = d.hhid.astype(str)
    return d, m


if __name__ == '__main__':
    foods = []; hhsets = {}
    for w in FOOD:
        o, hh = load_food(w); foods.append(o); hhsets[w] = hh
        print(w, len(o), len(hh))
    F = pd.concat(foods, ignore_index=True)
    F.to_pickle(OUT + 'mine_food' + SUF + '.pkl')
    H = hh_vars()
    pd.concat(H.values(), ignore_index=True).to_pickle(OUT + 'mine_hh.pkl')
    rs = []
    for w in ROSTER:
        d, m = roster(w); d['wave'] = w; rs.append(d)
        print(w, 'sex labels', m.variable_value_labels.get(ROSTER[w][2]), 'rel head code', {k: v for k, v in (m.variable_value_labels.get(ROSTER[w][4]) or {}).items() if k <= 2})
    pd.concat(rs, ignore_index=True).to_pickle(OUT + 'mine_roster.pkl')
