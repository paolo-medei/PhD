import sys,re; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
files={2010:'MWI_2010_IHS-III_v01_M_STATA8/MWI_2010_IHS-III_v01_M_STATA8/Full_Sample/Household/hh_mod_g1.dta',2016:'MWI_2016_IHS-IV_v04_M_STATA14/MWI_2016_IHS-IV_v04_M_STATA14/household/hh_mod_g1.dta',2019:'MWI_2019_IHS-V_v06_M_Stata/HH_MOD_G1.dta',2024:'MWI_2024-2025_IHS-VI_v01_M_STATA14/hh_mod_g1.dta'}
FISH={2010:[502,503,513]}; 
for y in (2016,2019,2024): FISH[y]=[5021,5022,5023,5031,5032,5033,5121,5122,5123]
def parse_other(s):
    if not isinstance(s,str): return np.nan
    t=s.upper().replace(' ','')
    m=re.match(r'^(\d+(?:\.\d+)?)(KG|KGS|KILOGRAM|KILOGRAMS|KILOGRAMME|KILO|KILOS)$',t)
    if m: return float(m.group(1))
    m=re.match(r'^(\d+(?:\.\d+)?)(G|GR|GRAM|GRAMS|GRAMME|GRAMMES|GMS)$',t)
    if m: return float(m.group(1))/1000
    return np.nan
def ufac(code, oth, use_other=True):
    c=str(code).strip() if isinstance(code,str) else ('' if pd.isna(code) else str(int(code)))
    if c=='1': return 1.0
    if c=='18': return 0.001
    if c=='23' and use_other: return parse_other(oth)
    return np.nan
def load(y, use_other=True):
    df,m=pyreadstat.read_dta(B+files[y])
    oth={a:[c for c in df.columns if c.startswith(f'hh_g0{a}b_o')][0] for a in '3467'}
    d=pd.DataFrame({'hhid':df.case_id.astype(str),'item':df.hh_g02,'cons':(df.hh_g01==1).astype(int),'ex':pd.to_numeric(df.hh_g05,errors='coerce')})
    for a,k in zip('3467','tpog'):
        d[k+'q']=pd.to_numeric(df[f'hh_g0{a}a'],errors='coerce')
        d[k+'u']=[ufac(u,o,use_other) for u,o in zip(df[f'hh_g0{a}b'],df[oth[a]])]
        d[k+'code']=df[f'hh_g0{a}b'].astype(str); d[k+'oth']=df[oth[a]]
    return d
if __name__=='__main__':
    pan=load_panel('MWI','fish','B').set_index('hhid')
    res=[]; keep={}
    for y in files:
        for variant in ['base','no_other']:
            d=load(y, use_other=(variant=='base'))
            allhh=d.hhid.unique()
            it=d[d.item.isin(FISH[y])].copy()
            r=aggregate(it, lambda f: f)   # tu etc. already factors
            r=finish(r,allhh)
            if variant=='base': keep[y]=(r,it)
            P=pan[pan.year==y]
            if variant=='base': print(y,'raw hh',len(allhh),'panel',len(P),'common',len(set(allhh)&set(P.index)),'panel-only',list(set(P.index)-set(allhh))[:5])
            j=P.join(r,rsuffix='_r',how='left')
            for col,rc in [('consumed','consumed_r'),('consumed','consumed_or_pos'),('exp','exp_r'),('exp_conv','exp_conv_r'),('purch_std','purch'),('unconv','unconv_r'),('uv','uv_r'),('qty_std','qty_any'),('qty_std','qty_allok')]:
                mm=cmp(j[col],j[rc])
                res.append(dict(country='MWI',year=y,variant=variant,col=col,rc=rc,n=len(j),match=mm.mean(),nmis=(~mm).sum()))
                if variant=='base' and 0<(~mm).sum() and rc not in('qty_allok','consumed_r'):
                    print('  MISMATCH',col,rc,(~mm).sum()); print(j.loc[~mm,[col,rc]].head(4).to_string())
    R=pd.DataFrame(res); print(R.pivot_table(index=['year','col','rc'],columns='variant',values='nmis').to_string())
    pd.to_pickle(keep,'/home/claude/phd/checks/audit/v24/mwi_fish.pkl')
