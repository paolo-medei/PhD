import pyreadstat, pandas as pd, numpy as np
R='/home/claude/work/final/data/_unzipped/'
D={'w1':R+'ETH_2011_ERSS_v02_M_Stata8/','w2':R+'ETH_2013_ESS_v03_M_STATA/','w3':R+'ETH_2015_ESS_v03_M_STATA/','w4':R+'ETH_2018_ESS_v04_M_Stata/','w5':R+'ETH_2021_ESPS-W5_v02_M_Stata/'}
YEAR={'w1':2011,'w2':2013,'w3':2015,'w4':2018,'w5':2021}
def rd(f, **kw):
    try: return pyreadstat.read_dta(f, **kw)
    except UnicodeDecodeError: return pyreadstat.read_dta(f, encoding='latin1', **kw)
def sid(s):
    """id as clean string"""
    s = s.astype(str).str.strip()
    return s.replace({'': np.nan, 'nan': np.nan})
FOOD = {
 'w1': dict(f=D['w1']+'sect5a_hh_w1.dta', hid='household_id', item='hh_s5aq00', cons='hh_s5aq01',
            q=dict(qty=('hh_s5aq02_a','hh_s5aq02_b'), purch=('hh_s5aq03_a','hh_s5aq03_b'), own=('hh_s5aq05_a','hh_s5aq05_b'), gift=('hh_s5aq06_a','hh_s5aq06_b')),
            exp='hh_s5aq04', cf=D['w1']+'Food_CF_Wave1.dta', cfitem='item_cd',
            items={18:'meat_agg',19:'milk',20:'cheese',21:'eggs',24:'coffee'}, cfmap={18:18,19:19,20:20,21:21,24:24}),
 'w2': dict(f=D['w2']+'sect5a_hh_w2.dta', hid='household_id2', item='hh_s5aq00', cons='hh_s5aq01',
            q=dict(qty=('hh_s5aq02_a','hh_s5aq02_cf_unit'), purch=('hh_s5aq03_a','hh_s5aq03_cf_unit'), own=('hh_s5aq05_a','hh_s5aq05_cf_unit'), gift=('hh_s5aq06_a','hh_s5aq06_cf_unit')),
            exp='hh_s5aq04', cf=D['w2']+'Food_CF_Wave2.dta', cfitem='item_cd',
            items={18:'meat_agg',19:'milk',20:'cheese',21:'eggs',24:'coffee'}, cfmap={18:18,19:19,20:20,21:21,24:24}),
 'w3': dict(f=D['w3']+'Household/sect5a_hh_w3.dta', hid='household_id2', item='item_cd', cons='hh_s5aq01',
            q=dict(qty=('hh_s5aq02_a','hh_s5aq02_b'), purch=('hh_s5aq03_a','hh_s5aq03_b'), own=('hh_s5aq05_a','hh_s5aq05_b'), gift=('hh_s5aq06_a','hh_s5aq06_b')),
            exp='hh_s5aq04', cf=D['w3']+'Food and Crop Conversion Factors/Food_CF_Wave3.dta', cfitem='item_cd_cf',
            items={180:'goat_sheep',181:'beef',182:'poultry',183:'fish',19:'milk',20:'cheese',21:'eggs',24:'coffee'},
            cfmap={180:180,181:181,182:182,183:183,19:19,20:20,21:21,24:24}),
 'w4': dict(f=D['w4']+'sect6a_hh_w4.dta', hid='household_id', item='item_cd', cons='s6aq01',
            q=dict(qty=('s6aq02a','s6aq02b'), purch=('s6aq03a','s6aq03b'), own=('s6aq05a','s6aq05b'), gift=('s6aq06a','s6aq06b')),
            exp='s6aq04', cf=D['w4']+'Food_CF_Wave4.dta', cfitem='item_cd_cf',
            items={701:'goat_sheep',702:'beef',703:'poultry',704:'fish',705:'milk',706:'cheese',709:'eggs',801:'coffee'},
            cfmap={701:180,702:181,703:182,704:183,705:19,706:20,709:21,801:24}),
 'w5': dict(f=D['w5']+'sect6a_hh_w5.dta', hid='household_id', item='item_cd', cons='s6aq01',
            q=dict(qty=('s6aq02a','s6aq02b'), purch=('s6aq03a','s6aq03b'), own=('s6aq05a','s6aq05b'), gift=('s6aq06a','s6aq06b')),
            exp='s6aq04', cf=D['w5']+'food_cf_wave5.dta', cfitem='item_cd_cf',
            items={701:'goat_sheep',702:'beef',703:'poultry',704:'fish',705:'milk',706:'cheese',709:'eggs',801:'coffee'},
            cfmap={701:180,702:181,703:182,704:183,705:19,706:20,709:21,801:24}),
}
def load_food(w):
    c = FOOD[w]
    df,m = rd(c['f'])
    df['hhid'] = sid(df[c['hid']])
    allhh = df['hhid'].dropna().unique()
    sub = df[df[c['item']].isin(list(c['items']))].copy()
    sub['item'] = sub[c['item']].astype(int)
    sub['product'] = sub['item'].map(c['items'])
    sub['cfitem'] = sub['item'].map(c['cfmap'])
    cf,_ = rd(c['cf'])
    cf = cf[[c['cfitem'],'unit_cd','mean_cf_nat']].dropna(subset=[c['cfitem'],'unit_cd'])
    cf.columns=['cfitem','unit','cf']
    cf['cfitem']=cf.cfitem.astype(int); cf['unit']=cf.unit.astype(int)
    assert not cf.duplicated(['cfitem','unit']).any()
    out = sub[['hhid','item','product','cfitem']].copy()
    s01 = sub[c['cons']]
    out['consumed'] = np.where(s01==1,1.0,np.where(s01==2,0.0,np.nan))
    for k,(qa,qb) in c['q'].items():
        q = pd.to_numeric(sub[qa], errors='coerce')
        u = pd.to_numeric(sub[qb], errors='coerce')
        tmp = pd.DataFrame({'cfitem':sub['cfitem'].values,'unit':u.values})
        tmp['unit'] = tmp['unit'].astype('Int64')
        tmp = tmp.merge(cf.astype({'unit':'Int64'}), on=['cfitem','unit'], how='left')
        out[k+'_raw'] = q.values; out[k+'_unit']=u.values; out[k+'_cf']=tmp['cf'].values
        out[k+'_kg'] = q.values*tmp['cf'].values
    out['exp'] = pd.to_numeric(sub[c['exp']], errors='coerce').values
    return out, allhh, df, m
