"""Final fish comparison: rebuild (base rules) vs panel, all countries; writes fish_match_rates.csv, fish_summary.csv, fish_mismatches.csv"""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
import rebuild_tza as T, rebuild_uga as U, rebuild_mwi as M, rebuild_nga as N, rebuild_eth as E
def get(c,y):
    if c=='TZA':
        it=pd.concat(T.load(y),ignore_index=True); allhh=it.hhid.unique(); it=it[it.item.isin(T.FISH)]
        conv=T.conv
    elif c=='UGA':
        d,cv,ul=U.load(y); allhh=d.hhid.unique(); it=d[d.item.isin(U.FISH_OLD if y<=2015 else U.FISH_NEW)].copy()
        it['tq']=it['tq_sum_away']; conv=lambda u: cv.get(u,np.nan)
    elif c=='MWI':
        d=M.load(y); allhh=d.hhid.unique(); it=d[d.item.isin(M.FISH[y])].copy(); conv=lambda x:x
    elif c=='NGA':
        d=N.load(y); allhh=d.hhid.unique(); it=d[d.item.isin(N.FISH)].copy(); conv=lambda x:x
    elif c=='ETH':
        it,allhh=E.load(y); conv=lambda x:x
    r=finish(aggregate(it,conv),allhh)
    # item-level conversion share among purchases
    it2=it.copy(); f=it2['pu'].map(conv); it2['buy']=it2.ex>0; it2['pconv']=it2.buy & f.notna() & (it2.pq>0)
    return r, it2
YEARS={'TZA':[2008,2010,2012,2014,2020],'UGA':[2010,2011,2013,2015,2018,2019],'MWI':[2010,2016,2019,2024],'NGA':[2010,2012,2015],'ETH':[2015,2018,2021]}
rates=[]; summ=[]; mis=[]
for c,ys in YEARS.items():
    pan=load_panel(c,'fish')
    qc='qty_std' if 'qty_std' in pan else 'qty_kg'; pc='purch_std' if 'purch_std' in pan else 'purch_kg'
    wc='hhweight' if 'hhweight' in pan else 'weight'
    # track A vs B identity
    for y in ys:
        P=pan[(pan.year==y)&(pan.track=='B')].set_index('hhid')
        A=pan[(pan.year==y)&(pan.track=='A')].set_index('hhid')
        if len(A):
            cols=['consumed',qc,pc,'exp','exp_conv','unconv','uv']
            AB=all(cmp(A.loc[P.index,k],P[k]).all() for k in cols) and len(A)==len(P)
        else: AB=None
        r,it=get(c,y)
        j=P.join(r,rsuffix='_r',how='left')
        for col,rc in [('consumed','consumed_or_pos'),('exp','exp_r'),('exp_conv','exp_conv_r'),(pc,'purch'),('unconv','unconv_r'),('uv','uv_r'),(qc,'qty_any')]:
            a=j[col]; b=j[rc]
            if c=='ETH' and col=='unconv': b=b.where(j['exp'].notna())           # ETH: unconv defined only for purchasers
            if c=='ETH' and col in('exp','exp_conv'): b=b.where(~((j['exp']==0)&b.isna()),0.0)  # ETH keeps a reported 0 spend
            mm=cmp(a,b)
            rates.append(dict(country=c,year=y,column=col,n=len(j),match_rate=round(mm.mean(),6),n_mismatch=int((~mm).sum()),trackA_equals_B=AB))
            for h in j.index[~mm]: mis.append(dict(country=c,year=y,hhid=h,column=col,panel=a[h],rebuild=b[h]))
        # summaries
        w=P[wc]
        def s(df,pref):
            buy=(df['exp']>0); conv=buy&(df['unconv']==0)
            return {pref+'share_consume':df['consumed'].mean(), pref+'share_buy':buy.mean(), pref+'total_exp':df['exp'].sum(),
                    pref+'wshare_consume':np.average(df['consumed'].fillna(0),weights=w.fillna(0)) if w.notna().any() else np.nan,
                    pref+'hh_buyers_fully_converted':conv.sum()/buy.sum(), pref+'hh_buyers_with_uv':(buy&df['uv'].notna()).sum()/buy.sum(),
                    pref+'median_uv':df.loc[df['uv'].notna(),'uv'].median()}
        Pp=P.rename(columns={qc:'qty',pc:'purch'})
        rr=r.reindex(P.index).rename(columns={'consumed_or_pos':'consumed_x'}); rr['consumed']=rr['consumed_x']
        row=dict(country=c,year=y,n_hh=len(P)); row.update(s(Pp,'panel_')); row.update(s(rr,'rebuild_'))
        row['item_purchases']=int(it.buy.sum()); row['item_purchases_converted']=int(it.pconv.sum()); row['item_conv_share']=it.pconv.sum()/it.buy.sum()
        row['exp_share_converted']=r.exp_conv.sum()/r.exp.sum()
        summ.append(row)
R=pd.DataFrame(rates); R.to_csv('fish_match_rates.csv',index=False)
S=pd.DataFrame(summ); S.to_csv('fish_summary.csv',index=False)
X=pd.DataFrame(mis); X.to_csv('fish_mismatches.csv',index=False)
pd.set_option('display.width',250)
print(R.pivot_table(index=['country','year'],columns='column',values='n_mismatch',aggfunc='sum').to_string())
print(R.groupby(['country','year']).trackA_equals_B.first().to_string())
print(S.round(4).T.to_string())
print(X.to_string())
