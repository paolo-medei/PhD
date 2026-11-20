"""Round 2: item-level loaders from the raw .dta files (all food items, raw unit codes kept).
Standard columns: hhid, year, item, cons (1 yes / 0 no / NaN missing), ex (spending),
for k in t (total), p (purchase), o (own), g (gift): q_k quantity, u_k unit code, x_k other-specify text.
UGA has one unit for all sources (u_t=u_p=u_o=u_g) and away-from-home purchases (q_a, ex_a)."""
import sys; sys.path.insert(0, '/home/claude/phd/checks/audit/v24')
from common import *

def _rd(path, **kw):
    try: return pyreadstat.read_dta(B + path, **kw)
    except UnicodeDecodeError: return pyreadstat.read_dta(B + path, encoding='latin1', **kw)

def _std(df, hid, item, cons, ex, q, year, text=None):
    d = pd.DataFrame({'hhid': df[hid].astype(str).str.strip(), 'item': pd.to_numeric(df[item], errors='coerce'),
                      'ex': pd.to_numeric(df[ex], errors='coerce')})
    c = df[cons]
    d['cons'] = np.where(c == 1, 1.0, np.where(c == 2, 0.0, np.nan))
    for k, (qa, ua) in q.items():
        d['q_' + k] = pd.to_numeric(df[qa], errors='coerce')
        d['u_' + k] = df[ua]
        d['x_' + k] = df[text[k]] if text and text.get(k) in df else ''
    d['year'] = year
    return d

# ---------------- Tanzania ----------------
TZA_F = {
    2008: [('TZA_2008_NPS1_v02_M_STATA_English_labels/TZA_2008_NPS1_v02_M_STATA_English_labels/SEC_K1.dta', 'hhid', 'skcode', 'skq1', 'skq4',
            dict(t=('skq2_amount', 'skq2_meas'), p=('skq3_amount', 'skq3_meas'), o=('skq5_amount', 'skq5_meas'), g=('skq6_amount', 'skq6_meas')))],
    2010: [('TZA_2010_NPS-R2_v03_M_STATA8/TZA_2010_NPS-R2_v03_M_STATA8/HH_SEC_K1.dta', 'y2_hhid', 'itemcode', 'hh_k01_2', 'hh_k04',
            dict(t=('hh_k02_2', 'hh_k02_1'), p=('hh_k03_2', 'hh_k03_1'), o=('hh_k05_2', 'hh_k05_1'), g=('hh_k06_2', 'hh_k06_1')))],
    2012: [('TZA_2012_NPS-R3_v01_M_STATA8_English_labels/TZA_2012_NPS-R3_v01_M_STATA8_English_labels/HH_SEC_J1.dta', 'y3_hhid', 'itemcode', 'hh_j01', 'hh_j04',
            dict(t=('hh_j02_2', 'hh_j02_1'), p=('hh_j03_2', 'hh_j03_1'), o=('hh_j05_2', 'hh_j05_1'), g=('hh_j06_2', 'hh_j06_1')))],
    2014: [('TZA_2014_NPS-R4_v03_M_STATA11/TZA_2014_NPS-R4_v03_M_STATA11/hh_sec_j1.dta', 'y4_hhid', 'itemcode', 'hh_j01', 'hh_j04',
            dict(t=('hh_j02_2', 'hh_j02_1'), p=('hh_j03_2', 'hh_j03_1'), o=('hh_j05_2', 'hh_j05_1'), g=('hh_j06_2', 'hh_j06_1')))],
    2020: [('TZA_2020_NPS-R5_v02_M_STATA14/hh_sec_ja1.dta', 'y5_hhid', 'itemcode', 'hh_ja01', 'hh_ja04',
            dict(t=('hh_ja02_2', 'hh_ja02_1'), p=('hh_ja03_2', 'hh_ja03_1'), o=('hh_ja05_2', 'hh_ja05_1'), g=('hh_ja06_2', 'hh_ja06_1'))),
           ('TZA_2020_NPS-R5_v02_M_STATA14/hh_sec_j1.dta', 'y5_hhid', 'itemcode', 'hh_j01', 'hh_j04',
            dict(t=('hh_j02_2', 'hh_j02_1'), p=('hh_j03_2', 'hh_j03_1'), o=('hh_j05_2', 'hh_j05_1'), g=('hh_j06_2', 'hh_j06_1')))],
}
def load_tza(y):
    out = []
    for f, hid, it, cons, ex, q in TZA_F[y]:
        df, _ = _rd(f)
        d = _std(df, hid, it, cons, ex, q, y)
        for k in 'tpog': d['u_' + k] = pd.to_numeric(d['u_' + k], errors='coerce')
        d['src'] = f.split('/')[-1]
        out.append(d)
    return pd.concat(out, ignore_index=True)

# ---------------- Uganda ----------------
UGA_F = {2010: ('UGA_2010_UNPS_v03_M_STATA12/GSEC15b.dta', 'hh'), 2011: ('UGA_2011_UNPS_v02_M_Stata/GSEC15B.dta', 'HHID'),
         2013: ('UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC15B.dta', 'hhid'), 2015: ('UGA_2015_UNPS_v02_M_STATA14/household/gsec15b.dta', 'hh'),
         2018: ('UGA_2018_UNPS_v02_M_STATA14/HH/GSEC15B.dta', 'hhid'), 2019: ('UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec15b.dta', 'hhid')}
def load_uga(y):
    f, idv = UGA_F[y]
    df, m = _rd(f)
    if y <= 2015:
        ul = m.value_labels[m.variable_to_label['untcd']]
        hid = df[idv].map(lambda x: str(int(x)) if isinstance(x, float) else str(x))
        d = pd.DataFrame({'hhid': hid, 'item': df.itmcd, 'cons': np.where(df.h15bq3a == 1, 1.0, np.where(df.h15bq3a == 2, 0.0, np.nan)),
                          'unit': df.untcd, 'q_p': df.h15bq4, 'ex': df.h15bq5, 'q_a': df.h15bq6, 'ex_a': df.h15bq7,
                          'q_o': df.h15bq8, 'q_g': df.h15bq10, 'q_tot': df.h15bq14})
    else:
        ul = m.value_labels[m.variable_to_label['CEB03C']]
        d = pd.DataFrame({'hhid': df[idv].astype(str), 'item': df.CEB01, 'cons': np.where(df.CEB03 == 1, 1.0, np.where(df.CEB03 == 2, 0.0, np.nan)),
                          'unit': df.CEB03C, 'q_p': df.CEB06, 'ex': df.CEB07, 'q_a': df.CEB08, 'ex_a': df.CEB09,
                          'q_o': df.CEB10, 'q_g': df.CEB012, 'q_tot': np.nan})
    d['q_t'] = d[['q_p', 'q_a', 'q_o', 'q_g']].sum(axis=1, min_count=1)
    for k in 'tpog': d['u_' + k] = d['unit']; d['x_' + k] = d['unit'].map(lambda u: str(ul.get(u, '')).strip())
    d['year'] = y
    return d, ul

# ---------------- Malawi ----------------
MWI_F = {2010: 'MWI_2010_IHS-III_v01_M_STATA8/MWI_2010_IHS-III_v01_M_STATA8/Full_Sample/Household/hh_mod_g1.dta',
         2016: 'MWI_2016_IHS-IV_v04_M_STATA14/MWI_2016_IHS-IV_v04_M_STATA14/household/hh_mod_g1.dta',
         2019: 'MWI_2019_IHS-V_v06_M_Stata/HH_MOD_G1.dta', 2024: 'MWI_2024-2025_IHS-VI_v01_M_STATA14/hh_mod_g1.dta'}
def load_mwi(y):
    df, m = _rd(MWI_F[y])
    oth = {a: [c for c in df.columns if c.startswith(f'hh_g0{a}b_o')][0] for a in '3467'}
    sub = {a: (f'hh_g0{a}c' if f'hh_g0{a}c' in df else None) for a in '3467'}
    d = pd.DataFrame({'hhid': df.case_id.astype(str), 'item': pd.to_numeric(df.hh_g02, errors='coerce'),
                      'cons': np.where(df.hh_g01 == 1, 1.0, np.where(df.hh_g01 == 2, 0.0, np.nan)), 'ex': pd.to_numeric(df.hh_g05, errors='coerce')})
    for a, k in zip('3467', 'tpog'):
        d['q_' + k] = pd.to_numeric(df[f'hh_g0{a}a'], errors='coerce')
        d['u_' + k] = df[f'hh_g0{a}b'].astype(str).str.strip().replace({'nan': ''})
        d['x_' + k] = df[oth[a]].astype(str).str.strip().replace({'nan': ''})
        d['s_' + k] = df[sub[a]].astype(str) if sub[a] else ''
    d['year'] = y
    return d

# ---------------- Nigeria ----------------
NGA_F = {2010: 'NGA_2010_GHSP-W1_v03_M_STATA/Post Harvest Wave 1/Household/sect10b_harvestw1.dta',
         2012: 'NGA_2012_GHSP-W2_v02_M_STATA/Post Harvest Wave 2/Household/sect10b_harvestw2.dta',
         2015: 'NGA_2015_GHSP-W3_v02_M_Stata/sect10b_harvestw3.dta'}
def load_nga(y):
    df, m = _rd(NGA_F[y])
    q = {'t': '2', 'p': '3', 'o': '5', 'g': '6'} if y == 2010 else {'t': '2', 'p': '3', 'o': '6', 'g': '7'}
    d = pd.DataFrame({'hhid': df.hhid.astype('Int64').astype(str), 'item': df.item_cd, 'ex': df.s10bq4,
                      'cons': np.where(df.s10bq1 == 1, 1.0, np.where(df.s10bq1 == 2, 0.0, np.nan)), 'zone': df.zone})
    for k, n in q.items():
        d['q_' + k] = df[f's10bq{n}a']; d['u_' + k] = pd.to_numeric(df[f's10bq{n}b'], errors='coerce')
        d['x_' + k] = df[f's10bq{n}b_os'] if f's10bq{n}b_os' in df else ''
    d['year'] = y
    return d

# ---------------- Ethiopia ----------------
ETH_F = {
 2011: dict(f='ETH_2011_ERSS_v02_M_Stata8/sect5a_hh_w1.dta', hid='household_id', item='hh_s5aq00', cons='hh_s5aq01', ex='hh_s5aq04',
            q=dict(t=('hh_s5aq02_a', 'hh_s5aq02_b'), p=('hh_s5aq03_a', 'hh_s5aq03_b'), o=('hh_s5aq05_a', 'hh_s5aq05_b'), g=('hh_s5aq06_a', 'hh_s5aq06_b')),
            cf='ETH_2011_ERSS_v02_M_Stata8/Food_CF_Wave1.dta', cfitem='item_cd'),
 2013: dict(f='ETH_2013_ESS_v03_M_STATA/sect5a_hh_w2.dta', hid='household_id2', item='hh_s5aq00', cons='hh_s5aq01', ex='hh_s5aq04',
            q=dict(t=('hh_s5aq02_a', 'hh_s5aq02_cf_unit'), p=('hh_s5aq03_a', 'hh_s5aq03_cf_unit'), o=('hh_s5aq05_a', 'hh_s5aq05_cf_unit'), g=('hh_s5aq06_a', 'hh_s5aq06_cf_unit')),
            cf='ETH_2013_ESS_v03_M_STATA/Food_CF_Wave2.dta', cfitem='item_cd'),
 2015: dict(f='ETH_2015_ESS_v03_M_STATA/Household/sect5a_hh_w3.dta', hid='household_id2', item='item_cd', cons='hh_s5aq01', ex='hh_s5aq04',
            q=dict(t=('hh_s5aq02_a', 'hh_s5aq02_b'), p=('hh_s5aq03_a', 'hh_s5aq03_b'), o=('hh_s5aq05_a', 'hh_s5aq05_b'), g=('hh_s5aq06_a', 'hh_s5aq06_b')),
            cf='ETH_2015_ESS_v03_M_STATA/Food and Crop Conversion Factors/Food_CF_Wave3.dta', cfitem='item_cd_cf'),
 2018: dict(f='ETH_2018_ESS_v04_M_Stata/sect6a_hh_w4.dta', hid='household_id', item='item_cd', cons='s6aq01', ex='s6aq04',
            q=dict(t=('s6aq02a', 's6aq02b'), p=('s6aq03a', 's6aq03b'), o=('s6aq05a', 's6aq05b'), g=('s6aq06a', 's6aq06b')),
            cf='ETH_2018_ESS_v04_M_Stata/Food_CF_Wave4.dta', cfitem='item_cd_cf'),
 2021: dict(f='ETH_2021_ESPS-W5_v02_M_Stata/sect6a_hh_w5.dta', hid='household_id', item='item_cd', cons='s6aq01', ex='s6aq04',
            q=dict(t=('s6aq02a', 's6aq02b'), p=('s6aq03a', 's6aq03b'), o=('s6aq05a', 's6aq05b'), g=('s6aq06a', 's6aq06b')),
            cf='ETH_2021_ESPS-W5_v02_M_Stata/food_cf_wave5.dta', cfitem='item_cd_cf'),
}
def load_eth(y):
    c = ETH_F[y]
    df, m = _rd(c['f'])
    d = _std(df, c['hid'], c['item'], c['cons'], c['ex'], c['q'], y)
    for k in 'tpog': d['u_' + k] = pd.to_numeric(d['u_' + k], errors='coerce')
    d['region'] = pd.to_numeric(df['saq01'], errors='coerce')
    cf, _ = _rd(c['cf'])
    return d, cf, c['cfitem']

LOADERS = {'TZA': load_tza, 'UGA': load_uga, 'MWI': load_mwi, 'NGA': load_nga, 'ETH': load_eth}
YEARS = {'TZA': [2008, 2010, 2012, 2014, 2020], 'UGA': [2010, 2011, 2013, 2015, 2018, 2019], 'MWI': [2010, 2016, 2019, 2024],
         'NGA': [2010, 2012, 2015], 'ETH': [2011, 2013, 2015, 2018, 2021]}
