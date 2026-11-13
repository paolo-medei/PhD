"""Reference v2: adjusted to the coordinator's documented decisions (fixes 4.1-4.3 + zero-purchase rule)."""
import sys; sys.path.insert(0, "/tmp/claude-0/-home-claude/7ac6c5ea-bbde-5aa6-a290-e032a3cd70ac/scratchpad/verify_ETH")
from common import *; from cmp import *
from roster import ROS
from mprice import COM, STD, PR
import rebuild as R1
OUT = "/tmp/claude-0/-home-claude/7ac6c5ea-bbde-5aa6-a290-e032a3cd70ac/scratchpad/verify_ETH/"

def food_rows(w):
    out, allhh, df, m = load_food(w)
    o = out[['hhid','product','consumed','qty_kg','purch_kg','own_kg','gift_kg','exp']].copy()
    o['exp_conv'] = o.exp.where(o.purch_kg>0)                      # NEW: zero purchased qty -> not convertible
    o['unconv'] = ((o.exp>0) & ~(o.purch_kg>0)).astype(float)
    rows=[]
    if w in ('w3','w4','w5'):
        b = o.copy(); b['unconv'] = b.unconv.where(b.exp.notna())
        b['uv'] = b.exp_conv/b.purch_kg; b.loc[~(b.uv>0)|~np.isfinite(b.uv),'uv']=np.nan
        b['track']='B'; rows.append(b)
        mt = o[o['product'].isin(['beef','goat_sheep','poultry'])].groupby('hhid')
        agg = pd.DataFrame({'consumed': mt.consumed.max()})
        for k in ['qty_kg','purch_kg','own_kg','gift_kg','exp','exp_conv']: agg[k]=mt[k].sum(min_count=1)
        agg['unconv'] = mt.unconv.max(); agg=agg.reset_index(); agg['product']='meat_agg'
        a = pd.concat([agg, o[o['product'].isin(['milk','cheese','eggs','coffee'])]], ignore_index=True)
    else:
        a = o.copy()
    for k in ['qty_kg','purch_kg','own_kg','gift_kg','exp','exp_conv']: a[k]=a[k].where(a[k]!=0)
    a['uv'] = a.exp_conv/a.purch_kg; a.loc[~(a.uv>0)|~np.isfinite(a.uv),'uv']=np.nan
    a['track']='A'; rows.append(a)
    r = pd.concat(rows, ignore_index=True); r['wave']=w
    return r, allhh

CORR = {'w2':('hh_s1q04h','hh_s1q04e'), 'w3':('hh_s1q04h','hh_s1q04e')}
def roster_v2(w):
    rc = ROS[w]; r,_ = rd(rc['f']); r['hhid']=sid(r[rc['hid']])
    if rc['mem']: r = r[r[rc['mem']]!=2]          # NA kept
    age = pd.to_numeric(r[rc['age']],errors='coerce'); sex = r[rc['sex']]
    if w in CORR:
        ca, cs = CORR[w]
        age = pd.to_numeric(r[ca],errors='coerce').combine_first(age)
        sex = r[cs].combine_first(sex)
    r = r.assign(age=age, fem=(sex==2).astype(float).where(sex.notna()), child=(age<15).astype(float).where(age.notna()), eld=(age>=60).astype(float).where(age.notna()))
    g = r.groupby('hhid')
    ro = pd.DataFrame({'n_members':g.size(),'share_child':g.child.mean(),'share_elderly':g.eld.mean(),'share_female':g.fem.mean()})
    hd = r[r[rc['rel']]==1].groupby('hhid').agg(head_age=('age','first'), head_female=('fem','first'), n_heads=('age','size'))
    return ro.join(hd).reset_index()

def community_v2(w):
    f,it,un,wt,pr = COM[w]; df,m = rd(D[w]+f)
    price = pd.to_numeric(df[pr],errors='coerce'); amt = pd.to_numeric(df[wt],errors='coerce')
    if w=='w1':
        price = price + pd.to_numeric(df['cs10b1q07_f2'],errors='coerce').fillna(0)/100
        amt = amt + pd.to_numeric(df['cs10b1q07_e2'],errors='coerce').fillna(0)/1000
    ea = sid(df['ea_id2']) if 'ea_id2' in df.columns else sid(df['ea_id'])
    x = pd.DataFrame({'ea':ea,'item':df[it],'unit':df[un],'price':price,'amt':amt})
    x = x[x.item.isin(PR)].copy(); x['product']=x.item.map(PR)
    x['amt1'] = x.amt.where(x.amt.notna() & (x.amt!=0), 1.0)
    return x

def mkt_v2(w, drop_gt=50):
    x = community_v2(w)
    ok = x.apply(lambda r: r['unit'] in STD[w].get(r['product'],[]), axis=1)
    s = x[ok & x['product'].isin(['milk','eggs','coffee']) & (x.amt1<=drop_gt)].copy()
    s['pu'] = s.price/s.amt1
    s = s[s.pu>0]
    return s.groupby(['ea','product']).pu.median().rename('mkt_price').reset_index()

def build():
    allrows=[]
    for w in ['w1','w2','w3','w4','w5']:
        fr,_ = food_rows(w)
        h = R1.hh_vars(w).drop(columns=['n_members','share_child','share_elderly','share_female','head_age','head_female'])
        h = h.merge(roster_v2(w), on='hhid', how='left')
        h = h.merge(R1.coffee(w), on='hhid', how='left'); h['coffee_grower']=h.coffee_grower.fillna(0)
        r = fr.merge(h, on='hhid', how='left')
        r = r.merge(mkt_v2(w), left_on=['ea_id_own','product'], right_on=['ea','product'], how='left').drop(columns=['ea'])
        r['ea_id'] = r['ea_id_own']; r['year']=YEAR[w]; r['country']='ETH'
        allrows.append(r)
    return pd.concat(allrows, ignore_index=True)
if __name__=='__main__':
    me = build(); me.to_csv(OUT+'rebuilt_panel_ETH_v2.csv', index=False); print(me.shape)
