"""Part 5: rebuild FAO_01_levels_lsms_vs_fbs from the panels (track B) and the FAOSTAT food balance sheets."""
import sys, zipfile; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx'
FZ='/mnt/user-data/outputs/PhD_materiale_partenza/02_FAOSTAT/'
def fbs(zipname, csvname):
    with zipfile.ZipFile(FZ+zipname) as z:
        with z.open(csvname) as f: return pd.read_csv(f, encoding='latin1')
new=fbs('FoodBalanceSheets_E_Africa.zip','FoodBalanceSheets_E_Africa_NOFLAG.csv')
hist=fbs('FoodBalanceSheetsHistoric_E_Africa.zip','FoodBalanceSheetsHistoric_E_Africa_NOFLAG.csv')
AREA={'TZA':'United Republic of Tanzania','UGA':'Uganda','MWI':'Malawi','NGA':'Nigeria','ETH':'Ethiopia'}
ITEM={'beef':2731,'goat_sheep':2732,'pork':2733,'poultry':2734,'eggs':2949,'milk':2848,'fish':2960}
def fao_val(c, item, yr):
    yrs=[2023] if yr>=2023 else [yr, yr+1]
    vals=[]
    for y in yrs:
        src=hist if y<2010 else new
        r=src[(src.Area==AREA[c])&(src['Item Code']==item)&(src['Element Code']==645)]
        col=f'Y{y}'
        vals.append(float(r[col].iloc[0]) if len(r) and col in r and pd.notna(r[col].iloc[0]) else np.nan)
    return np.nanmean(vals) if np.isfinite(vals).any() else np.nan, yrs
WB=pd.read_excel(X,sheet_name='FAO_01_levels_lsms_vs_fbs')
rows=[]
for c in ['TZA','UGA','MWI','NGA','ETH']:
    p=load_panel(c,track='B')
    qc='qty_std' if 'qty_std' in p else 'qty_kg'; wc='hhweight' if 'hhweight' in p else 'weight'; hs='hhsize' if 'hhsize' in p else 'hh_size'
    if 'std' not in p: p['std']='kg'
    p['q']=p[qc]*np.where(p['std']=='piece',0.055,1.0)
    hh_meat={}
    for prod in ['beef','goat_sheep','pork','poultry','eggs','milk','fish']:
        for y,g in p[p['product']==prod].groupby('year'):
            g=g[g[wc].notna()&g[hs].notna()]
            w=g[wc]; q=g.q.where(g.q>0)
            cons=g.consumed==1
            med=q[cons].median()
            big=(q>100*med)
            den=(w*g[hs]).sum()
            kg_raw=52*(w*q.fillna(0)).sum()/den
            kg_trim=52*(w*q.where(~big).fillna(0)).sum()/den
            cov_w=(w*(cons&q.notna())).sum()/(w*cons).sum()
            cov_u=(cons&q.notna()).sum()/cons.sum()
            fk,yrs=fao_val(c,ITEM[prod],y)
            rows.append(dict(country=c,year=y,product=prod,kg_raw=kg_raw,kg_trim100=kg_trim,n_trimmed=int(big.sum()),pct_consuming=100*(w*cons).sum()/w.sum(),
                             cov_w=cov_w,cov_u=cov_u,fao_kg=fk,fao_years='+'.join(map(str,yrs))))
R=pd.DataFrame(rows)
J=R.merge(WB,on=['country','year','product'],how='outer',suffixes=('','_wb'),indicator=True)
pd.set_option('display.width',300)
for col in ['kg_raw','kg_trim100','pct_consuming','fao_kg']:
    J['d_'+col]=(J[col].round(2)-J[col+'_wb']).abs()
J['d_n_trimmed']=(J.n_trimmed-J.n_trimmed_wb).abs()
J['d_cov_w']=(J.cov_w.round(2)-J.coverage).abs(); J['d_cov_u']=(J.cov_u.round(2)-J.coverage).abs()
print(J._merge.value_counts())
print(J[[c for c in J.columns if c.startswith('d_')]].describe().T[['count','mean','max']])
bad=J[(J[[c for c in J.columns if c.startswith('d_') and c not in('d_cov_w','d_cov_u')]]>0.011).any(axis=1)]
print(bad[['country','year','product','kg_raw','kg_raw_wb','kg_trim100','kg_trim100_wb','n_trimmed','n_trimmed_wb','pct_consuming','pct_consuming_wb','fao_kg','fao_kg_wb','fao_years']].round(3).to_string())
J.to_pickle('fao_join.pkl')
