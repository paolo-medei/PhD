import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
from eth_peek import files
def load(y, variant='base'):
    f,p,cf=files[y]
    df,m=pyreadstat.read_dta(B+f,encoding='latin1')
    c,_=pyreadstat.read_dta(B+cf,encoding='latin1')
    c=c[c.item_cd_cf==183]
    tab={int(u):v for u,v in zip(c.unit_cd,c.mean_cf_nat)}
    if variant=='kg_g': tab={1:1.0,2:0.001}
    if variant=='plus_ml': tab=dict(tab); tab[5]=0.001
    if y==2015:
        q={'c':'hh_s5aq01','t':('hh_s5aq02_a','hh_s5aq02_b'),'p':('hh_s5aq03_a','hh_s5aq03_b'),'ex':'hh_s5aq04','o':('hh_s5aq05_a','hh_s5aq05_b'),'g':('hh_s5aq06_a','hh_s5aq06_b')}
        item=183
    else:
        q={'c':'s6aq01','t':('s6aq02a','s6aq02b'),'p':('s6aq03a','s6aq03b'),'ex':'s6aq04','o':('s6aq05a','s6aq05b'),'g':('s6aq06a','s6aq06b')}
        item=704
    hid='household_id2' if y==2015 else 'household_id'
    d=pd.DataFrame({'hhid':df[hid].astype(str),'hhid1':df.household_id.astype(str),'item':df.item_cd,'cons':(df[q['c']]==1).astype(int),'ex':df[q['ex']]})
    for k in 'tpog':
        d[k+'q']=df[q[k][0]]; d[k+'u']=df[q[k][1]].map(lambda u: tab.get(int(u),np.nan) if pd.notna(u) else np.nan); d[k+'code']=df[q[k][1]]
    return d[d.item==item], d.hhid.unique()
if __name__=='__main__':
    pan=load_panel('ETH','fish','B').set_index('hhid')
    res=[]; keep={}
    for y in files:
        for variant in ['base','kg_g','plus_ml']:
            it,allhh=load(y,variant)
            r=aggregate(it,lambda x:x); r=finish(r,allhh)
            if variant=='base': keep[y]=(r,it)
            P=pan[pan.year==y]
            if variant=='base': print(y,'raw hh',len(allhh),'panel',len(P),'common',len(set(allhh)&set(P.index)), list(P.index[:2]), list(allhh[:2]))
            j=P.join(r,rsuffix='_r',how='left')
            for col,rc in [('consumed','consumed_r'),('consumed','consumed_or_pos'),('exp','exp_r'),('exp_conv','exp_conv_r'),('purch_kg','purch'),('unconv','unconv_r'),('uv','uv_r'),('qty_kg','qty_any'),('qty_kg','qty_allok')]:
                mm=cmp(j[col],j[rc])
                res.append(dict(country='ETH',year=y,variant=variant,col=col,rc=rc,n=len(j),match=mm.mean(),nmis=(~mm).sum()))
                if variant=='base' and 0<(~mm).sum() and rc not in('qty_allok',):
                    print('  MISMATCH',col,rc,(~mm).sum()); print(j.loc[~mm,[col,rc]].head(4).to_string())
    R=pd.DataFrame(res); print(R.pivot_table(index=['year','col','rc'],columns='variant',values='nmis').to_string())
    pd.to_pickle(keep,'/home/claude/phd/checks/audit/v24/eth_fish.pkl')
