import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
files={2010:('UGA_2010_UNPS_v03_M_STATA12/GSEC15b.dta','hh'),2011:('UGA_2011_UNPS_v02_M_Stata/GSEC15B.dta','HHID'),2013:('UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC15B.dta','hhid'),
2015:('UGA_2015_UNPS_v02_M_STATA14/household/gsec15b.dta','hh'),2018:('UGA_2018_UNPS_v02_M_STATA14/HH/GSEC15B.dta','hhid'),2019:('UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec15b.dta','hhid')}
FISH_OLD=[122,123]; FISH_NEW=[1221,1222,1231,1232,1235,1236,1237]
import re
def make_conv(ul, extra=False):
    d={}
    for k,v in ul.items():
        s=v.strip()
        if s.startswith('Kilogram'): d[k]=1.0
        elif s=='Gram': d[k]=0.001
        elif re.match(r'Nice cup\((\d+)g\)',s): d[k]=int(re.match(r'Nice cup\((\d+)g\)',s).group(1))/1000
        elif extra and re.search(r'\((\d+)g\)',s): d[k]=int(re.search(r'\((\d+)g\)',s).group(1))/1000
    return d
def load(y, extra=False):
    f,idv=files[y]
    df,m=pyreadstat.read_dta(B+f)
    if y<=2015:
        ul=m.value_labels[m.variable_to_label['untcd']]
        hid=df[idv].map(lambda x: str(int(x)) if isinstance(x,float) else str(x))
        d=pd.DataFrame({'hhid':hid,'item':df.itmcd,'cons':(df.h15bq3a==1).astype(int),'unit':df.untcd,
          'pq':df.h15bq4,'ex':df.h15bq5,'aq':df.h15bq6,'ax':df.h15bq7,'oq':df.h15bq8,'gq':df.h15bq10,'tq_tot':df.h15bq14})
    else:
        ul=m.value_labels[m.variable_to_label['CEB03C']]
        d=pd.DataFrame({'hhid':df[idv].astype(str),'item':df.CEB01,'cons':(df.CEB03==1).astype(int),'unit':df.CEB03C,
          'pq':df.CEB06,'ex':df.CEB07,'aq':df.CEB08,'ax':df.CEB09,'oq':df.CEB10,'gq':df.CEB012,'tq_tot':np.nan})
    d['tq_sum']=d[['pq','oq','gq']].sum(axis=1,min_count=1)
    d['tq_sum_away']=d[['pq','aq','oq','gq']].sum(axis=1,min_count=1)
    for a in 'tpog': d[a+'u']=d['unit']
    return d, make_conv(ul, extra), ul
if __name__=='__main__':
    pan=load_panel('UGA','fish','B').set_index('hhid')
    res=[]; keep={}
    for y in files:
        for variant in ['base','with1234','extra_g']:
            d,cv,ul=load(y, extra=(variant=='extra_g'))
            allhh=d.hhid.unique()
            items=FISH_OLD if y<=2015 else FISH_NEW+([1234] if variant=='with1234' else [])
            if y<=2015 and variant=='with1234': continue
            it=d[d.item.isin(items)].copy()
            out={}
            for tv in ['tq_tot','tq_sum','tq_sum_away']:
                it['tq']=it[tv]
                r=aggregate(it,lambda u: cv.get(u,np.nan))
                out[tv]=r['qty_any']
            r['qty_sum']=out['tq_sum']; r['qty_tot']=out['tq_tot']; r['qty_away']=out['tq_sum_away']
            r=finish(r,allhh)
            if variant=='base': keep[y]=(r,it)
            P=pan[pan.year==y]
            if variant=='base': print(y,'raw hh',len(allhh),'panel',len(P),'common',len(set(allhh)&set(P.index)))
            j=P.join(r,rsuffix='_r',how='left')
            for col,rc in [('consumed','consumed_r'),('consumed','consumed_or_pos'),('exp','exp_r'),('exp_conv','exp_conv_r'),('purch_std','purch'),('unconv','unconv_r'),('uv','uv_r'),('qty_std','qty_tot'),('qty_std','qty_sum'),('qty_std','qty_away')]:
                m=cmp(j[col],j[rc])
                res.append(dict(country='UGA',year=y,variant=variant,col=col,rc=rc,n=len(j),match=m.mean(),nmis=(~m).sum()))
                if variant=='base' and 0<(~m).sum() and rc not in('qty_tot','qty_away'):
                    print('  MISMATCH',col,rc,(~m).sum()); print(j.loc[~m,[col,rc]].head(4).to_string())
    R=pd.DataFrame(res); print(R.pivot_table(index=['year','col','rc'],columns='variant',values='nmis').to_string())
    pd.to_pickle(keep,'/home/claude/phd/checks/audit/v24/uga_fish.pkl')
