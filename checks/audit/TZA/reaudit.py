"""Re-audit of the revised panel (/home/claude/work/cI/...): reference adjusted to the coordinator's decisions."""
import importlib.util, sys, pandas as pd, numpy as np
OUT = '/tmp/claude-0/-home-claude/7ac6c5ea-bbde-5aa6-a290-e032a3cd70ac/scratchpad/verify_TZA/'
MP_KG = '--mpkg' in sys.argv   # variant: apply milk kg=litre convention also to milk_processed
sys.argv = [sys.argv[0], '--pipeconv']
spec = importlib.util.spec_from_file_location('rb', OUT + 'rebuild.py'); rb = importlib.util.module_from_spec(spec); spec.loader.exec_module(rb)
rb.ITEMS.pop('cheese'); rb.ITEMS['milk_processed'] = [902]
rb.STD.pop('cheese'); rb.STD['milk_processed'] = 'litre'
rb.item2prod.clear(); rb.item2prod.update({c: p for p, cs in rb.ITEMS.items() for c in cs})
orig_conv = rb.conv


def conv(u, q, std, wave, prod):
    if prod == 'milk_processed' and not MP_KG:
        rb.PC = False; out = orig_conv(u, q, std, wave, prod); rb.PC = True; return out
    return orig_conv(u, q, std, wave, prod)


rb.conv = conv
F = pd.concat([rb.load_food(w)[0] for w in ['w1', 'w2', 'w3', 'w4', 'w5', 'w5J1']], ignore_index=True)
F = F.rename(columns={'cons': 'consumed', 'qty': 'qty_std', 'pur': 'purch_std', 'own': 'own_std', 'gif': 'gift_std', 'ex': 'exp', 'exconv': 'exp_conv', 'unc': 'unconv'})
F['uv'] = F.exp_conv / F.purch_std
H = pd.read_pickle(OUT + 'mine_hh.pkl')
H['region'] = pd.to_numeric(H.region, errors='coerce').fillna(pd.to_numeric(H.alt_region, errors='coerce'))
H['urban'] = H.urban.fillna(H.alt_urban)
H.loc[H.wave.isin(['w2', 'w4']), 'hhweight'] = H.loc[H.wave.isin(['w2', 'w4']), 'hhweight'].fillna(H.alt_w)
H.loc[H.wave == 'w5', 'welfare'] = H.loc[H.wave == 'w5', 'welfare'] * 365 / 28      # E1 decision
RV = pd.read_pickle(OUT + 'mine_roster_vars.pkl')[['wave', 'hhid', 'm_share_child', 'm_share_elderly', 'm_head_age', 'm_head_female']]
RV.columns = ['wave', 'hhid', 'share_child', 'share_elderly', 'head_age', 'head_female']
HH = H[['wave', 'hhid', 'adulteq', 'hhsize', 'urban', 'region', 'hhweight', 'welfare', 'clusterid', 'strataid']].merge(RV, on=['wave', 'hhid'], how='left')
HH['country'] = 'TZA'; HH['year'] = HH.wave.map({'w1': 2008, 'w2': 2010, 'w3': 2012, 'w4': 2014, 'w5': 2020})
key = ['wave', 'hhid', 'product', 'track']
M = F[key + ['std', 'consumed', 'qty_std', 'purch_std', 'own_std', 'gift_std', 'exp', 'exp_conv', 'unconv', 'uv', 'src']].merge(HH, on=['wave', 'hhid'], how='left')
p = pd.read_csv('/home/claude/work/cI/data/OUTPUT/panel_TZA.csv', dtype={'hhid': str, 'clusterid': str, 'strataid': str, 'region': str})
A = p.merge(M, on=key, how='outer', suffixes=('', '_m'), indicator=True)
print(A.groupby('wave')._merge.value_counts().unstack().to_string())
A = A[A._merge == 'both']


def cmp(a, b):
    if c in ('std',):
        ok = a.astype(str) == b.astype(str); return ok, ~ok & False, ~ok
    an = pd.to_numeric(a, errors='coerce'); bn = pd.to_numeric(b, errors='coerce')
    bn2 = an.isna() & bn.isna(); on = an.isna() ^ bn.isna()
    cl = np.isclose(an.fillna(0), bn.fillna(0), rtol=1e-4, atol=1e-12) & an.notna() & bn.notna()
    return bn2 | cl, on, ~(bn2 | cl | on)


rows = []; ex = []
COLS = ['std', 'consumed', 'qty_std', 'purch_std', 'own_std', 'gift_std', 'exp', 'exp_conv', 'unconv', 'uv', 'adulteq', 'hhsize', 'urban', 'region',
        'hhweight', 'welfare', 'share_child', 'share_elderly', 'head_age', 'head_female', 'clusterid', 'strataid', 'country', 'year']
for c in COLS:
    for w, g in A.groupby('wave'):
        ok, na, val = cmp(g[c], g[c + '_m'])
        rows.append(dict(country='TZA', wave=w, column=c, n_compared=len(g), pct_equal=round(100 * ok.mean(), 3), n_na_mismatch=int(na.sum()),
                         n_value_mismatch=int(val.sum()), hh=int(g.loc[~ok, 'hhid'].nunique()),
                         prods=str(g.loc[~ok, 'product'].value_counts().to_dict()), src=str(g.loc[~ok, 'src'].value_counts().to_dict())))
        if (~ok).any():
            ex.append(f'--- {w} {c}\n' + g.loc[~ok, key + ['src', c, c + '_m']].head(4).to_string())
R = pd.DataFrame(rows)
tag = '_mpkg' if MP_KG else ''
R.to_csv(OUT + f'reaudit_rates{tag}.csv', index=False)
open(OUT + f'reaudit_examples{tag}.txt', 'w').write('\n'.join(ex))
print(R[R.pct_equal < 100].drop(columns=['country']).to_string())
A.to_pickle(OUT + f'reaudit_merged{tag}.pkl')
