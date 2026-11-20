import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
FISH=[808,809,810,8081,8082,8083,8084]
def conv(u): return {1:1.0,2:0.001}.get(u,np.nan)
def load(year):
    if year==2008:
        df,_=rd('TZA_2008_NPS1_v02_M_STATA_English_labels/TZA_2008_NPS1_v02_M_STATA_English_labels/SEC_K1.dta')
        d=pd.DataFrame({'hhid':df.hhid.astype(str),'item':df.skcode,'cons':(df.skq1==1).astype(int),
           'tq':df.skq2_amount,'tu':df.skq2_meas,'pq':df.skq3_amount,'pu':df.skq3_meas,'ex':df.skq4,
           'oq':df.skq5_amount,'ou':df.skq5_meas,'gq':df.skq6_amount,'gu':df.skq6_meas})
        return [d]
    if year==2010:
        df,_=rd('TZA_2010_NPS-R2_v03_M_STATA8/TZA_2010_NPS-R2_v03_M_STATA8/HH_SEC_K1.dta')
        p='hh_k'; idv='y2_hhid'
    elif year==2012:
        df,_=rd('TZA_2012_NPS-R3_v01_M_STATA8_English_labels/TZA_2012_NPS-R3_v01_M_STATA8_English_labels/HH_SEC_J1.dta'); p='hh_j'; idv='y3_hhid'
    elif year==2014:
        df,_=rd('TZA_2014_NPS-R4_v03_M_STATA11/TZA_2014_NPS-R4_v03_M_STATA11/hh_sec_j1.dta'); p='hh_j'; idv='y4_hhid'
    elif year==2020:
        out=[]
        for fn,p in [('hh_sec_ja1.dta','hh_ja'),('hh_sec_j1.dta','hh_j')]:
            df,_=rd('TZA_2020_NPS-R5_v02_M_STATA14/'+fn)
            d=mk(df,p,'y5_hhid'); d['src']=fn; out.append(d)
        return out
    c01=p+('01_2' if year==2010 else '01')
    return [mk(df,p,idv,c01)]
def mk(df,p,idv,c01=None):
    c01=c01 or p+'01'
    return pd.DataFrame({'hhid':df[idv].astype(str),'item':df.itemcode,'cons':(df[c01]==1).astype(int),
        'tq':df[p+'02_2'],'tu':df[p+'02_1'],'pq':df[p+'03_2'],'pu':df[p+'03_1'],'ex':df[p+'04'],
        'oq':df[p+'05_2'],'ou':df[p+'05_1'],'gq':df[p+'06_2'],'gu':df[p+'06_1'],
        'tbq':df[p+'02b_2'] if p+'02b_2' in df else np.nan,'tbu':df[p+'02b_1'] if p+'02b_1' in df else np.nan})
if __name__=='__main__':
    pan=load_panel('TZA','fish','B').set_index('hhid')
    res=[]
    for y in [2008,2010,2012,2014,2020]:
        ds=load(y); it=pd.concat(ds,ignore_index=True)
        allhh=it.hhid.unique()
        it=it[it.item.isin(FISH)]
        r=aggregate(it,conv)
        r=finish(r,allhh)
        r.to_pickle(f'/home/claude/phd/checks/audit/v24/tza_fish_{y}.pkl')
        P=pan[pan.year==y]
        print(y,'raw hh',len(allhh),'panel hh',len(P),'common',len(set(allhh)&set(P.index)), 'panel-only',len(set(P.index)-set(allhh)))
        j=P.join(r,rsuffix='_r',how='left')
        for col,rc in [('consumed','consumed_r'),('consumed','consumed_or_pos'),('exp','exp_r'),('exp_conv','exp_conv_r'),('purch_std','purch'),('unconv','unconv_r'),('uv','uv_r'),('qty_std','qty_allok'),('qty_std','qty_any')]:
            m=cmp(j[col],j[rc])
            res.append(dict(country='TZA',year=y,col=col+('' if rc!='qty_any' else '[any]'),n=len(j),match=m.mean(),nmis=(~m).sum()))
            if (~m).sum()>0 and (~m).sum()<50000:
                print('  MISMATCH',col,rc,(~m).sum()); print(j.loc[~m,[col,rc]].head(5).to_string())
    print(pd.DataFrame(res).to_string())
