import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
files={2010:'NGA_2010_GHSP-W1_v03_M_STATA/Post Harvest Wave 1/Household/sect10b_harvestw1.dta',2012:'NGA_2012_GHSP-W2_v02_M_STATA/Post Harvest Wave 2/Household/sect10b_harvestw2.dta',2015:'NGA_2015_GHSP-W3_v02_M_Stata/sect10b_harvestw3.dta'}
FISH=[100,101,102,103,105,106,107]
def conv_table(y, cl_mode='cl_to_l'):
    if y==2012:
        c,_=pyreadstat.read_dta(B+'NGA_2012_GHSP-W2_v02_M_STATA/food_conv_w2ph.dta')
        # g_cl 1=grams, 0=centilitres
        if cl_mode=='cl_to_l': f=np.where(c.g_cl==1,c.conv/1000,c.conv/100)
        else: f=c.conv/1000
        return {(int(i),int(u)):v for i,u,v in zip(c.item_cd,c.nsu_cd,f)}
    if y==2015:
        c,_=pyreadstat.read_dta(B+'NGA_2015_GHSP-W3_v02_M_Stata/food_conv_w3.dta')
        return {(int(i),int(u)):v for i,u,v in zip(c.item_cd,c.unit_cd,c.conv_national) if pd.notna(v)}
    return {}
FALLBACK={2010:{1:1.0,2:0.001,3:1.0,4:0.001},2012:{1:1.0,2:0.001,3:1.0,4:0.01},2015:{1:1.0,2:0.001,3:1.0,4:0.01}}
def load(y, variant='base'):
    df,m=pyreadstat.read_dta(B+files[y])
    tab=conv_table(y, 'g_only' if variant=='g_only' else 'cl_to_l')
    fb=dict(FALLBACK[y])
    if variant=='kg_g_only': fb={1:1.0,2:0.001}
    if variant=='no_table': tab={}
    def f(i,u):
        if pd.isna(u): return np.nan
        i,u=int(i),int(u)
        if (i,u) in tab: return tab[(i,u)]
        return fb.get(u,np.nan)
    if y==2010: q={'t':'2','p':'3','o':'5','g':'6'}
    else: q={'t':'2','p':'3','o':'6','g':'7'}
    d=pd.DataFrame({'hhid':df.hhid.astype('Int64').astype(str),'item':df.item_cd,'cons':(df.s10bq1==1).astype(int),'ex':df.s10bq4})
    for k,n in q.items():
        d[k+'q']=df[f's10bq{n}a']; d[k+'u']=[f(i,u) for i,u in zip(df.item_cd,df[f's10bq{n}b'])]; d[k+'code']=df[f's10bq{n}b']
    return d
if __name__=='__main__':
    pan=load_panel('NGA','fish','B').set_index('hhid')
    res=[]; keep={}
    for y in files:
        for variant in ['base','g_only','kg_g_only','no_table']:
            if y==2010 and variant in('g_only','no_table'): continue
            d=load(y,variant); allhh=d.hhid.unique()
            it=d[d.item.isin(FISH)].copy()
            r=aggregate(it,lambda x:x); r=finish(r,allhh)
            if variant=='base': keep[y]=(r,it)
            P=pan[pan.year==y]
            if variant=='base': print(y,'raw hh',len(allhh),'panel',len(P),'common',len(set(allhh)&set(P.index)))
            j=P.join(r,rsuffix='_r',how='left')
            for col,rc in [('consumed','consumed_r'),('consumed','consumed_or_pos'),('exp','exp_r'),('exp_conv','exp_conv_r'),('purch_kg','purch'),('unconv','unconv_r'),('uv','uv_r'),('qty_kg','qty_any'),('qty_kg','qty_allok')]:
                mm=cmp(j[col],j[rc])
                res.append(dict(country='NGA',year=y,variant=variant,col=col,rc=rc,n=len(j),match=mm.mean(),nmis=(~mm).sum()))
                if variant=='base' and 0<(~mm).sum() and rc not in('qty_allok','consumed_r'):
                    print('  MISMATCH',col,rc,(~mm).sum()); print(j.loc[~mm,[col,rc]].head(4).to_string())
    R=pd.DataFrame(res); print(R.pivot_table(index=['year','col','rc'],columns='variant',values='nmis').to_string())
    pd.to_pickle(keep,'/home/claude/phd/checks/audit/v24/nga_fish.pkl')
