import pandas as pd, numpy as np, pyreadstat
B='/home/claude/v20home/Desktop/ASF_DATA/_unzipped/'
OUT='/home/claude/work/v24/data/OUTPUT/'
def rd(path, cols=None, labels=False):
    df,m=pyreadstat.read_dta(B+path, usecols=cols, apply_value_formats=labels)
    return df,m
def load_panel(c, product=None, track=None):
    p=pd.read_csv(OUT+f'panel_{c}.csv',dtype={'hhid':str},low_memory=False)
    if product is not None: p=p[p['product']==product]
    if track is not None: p=p[p.track==track]
    return p

def aggregate(it, conv):
    """it: item-level df with hhid, item, cons (1/0), tq,tu, pq,pu, ex, oq,ou, gq,gu.
       conv(unit) -> factor to std unit or nan. Returns household level."""
    it=it.copy()
    for a in ['t','p','o','g']:
        f=it[a+'u'].map(conv)
        it[a+'k']=it[a+'q']*f
        it[a+'ok']=f.notna()
    it['ex']=it['ex'].where(it['ex']>0)
    # purchase present = spending > 0 or purchased quantity >0
    it['buy']=(it['ex']>0)
    it['pconv']=it['buy'] & it['pok'] & (it['pq']>0)
    it['exc']=it['ex'].where(it['pconv'])
    it['pk_c']=it['pk'].where(it['pok'] & (it['pq']>0))   # purchased qty counted whenever unit converts (even if spending 0)
    g=it.groupby('hhid')
    r=pd.DataFrame({
      'consumed':g['cons'].max(),
      'exp':g['ex'].sum(min_count=1),
      'exp_conv':g['exc'].sum(min_count=1),
      'purch':g['pk_c'].sum(min_count=1),
      'nbuy':g['buy'].sum(),
      'nitem_buy':g['buy'].sum(), 'nitem_conv':g['pconv'].sum(),
      'nbuy_unconv':(it['buy']&~it['pconv']).groupby(it['hhid']).sum(),
      'qty_any':g['tk'].sum(min_count=1),
      'qty_allok':g.apply(lambda d: d['tk'].sum(min_count=1) if d.loc[d.tq>0,'tok'].all() else np.nan, include_groups=False),
    })
    r['unconv']=(r['nbuy_unconv']>0).astype(int)
    pos=((it[['tq','pq','oq','gq']].fillna(0)>0).any(axis=1)|(it['ex']>0)).groupby(it['hhid']).max()
    r['consumed_or_pos']=np.maximum(r['consumed'],pos.astype(int))
    r['uv']=r['exp_conv']/r['purch']
    return r

def finish(r, allhh):
    r=r.reindex(allhh)
    for c in ['consumed','consumed_or_pos','unconv','nitem_buy','nitem_conv']: r[c]=r[c].fillna(0)
    return r
def cmp(a, b, rtol=1e-6, atol=1e-9):
    """a,b Series aligned; returns match boolean (NaN==NaN)."""
    x=a.astype(float); y=b.astype(float)
    both_na=x.isna()&y.isna()
    close=np.isclose(x,y,rtol=rtol,atol=atol)
    return both_na|close
