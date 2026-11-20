"""(f) NGA 2015 milk powder (item 111) in PACKET/SACHET units: conversion table vs the prices actually paid."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from build import *
c3,m3=pyreadstat.read_dta(B+'NGA_2015_GHSP-W3_v02_M_Stata/food_conv_w3.dta')
pd.set_option('display.width',250)
t=c3[c3.unit_cd.isin([120,121,122])&c3.item_cd.isin([110,111,112,113,115,121,122,130])][['item_name','item_cd','unit_name','unit_cd','conv_national','conv_NC_1','conv_SW_6']]
print(t.to_string(index=False))
print('notes for 111:', c3[c3.item_cd==111].note.unique()[:3])
d=load_nga(2015)
s=d[(d.item==111)&(d.ex>0)&(d.q_p>0)].copy()
T={(int(a),int(b)):v for a,b,v in zip(c3.item_cd,c3.unit_cd,c3.conv_national) if pd.notna(v)}
s['f']=[NGA_FB[2015].get(int(u),T.get((111,int(u)),np.nan)) if pd.notna(u) else np.nan for u in s.u_p]
s['kg']=s.q_p*s.f; s['price']=s.ex/s.kg
# product median as in the screen: milk_processed items 111,113,115 (2015)
mp=d[d.item.isin([111,113,115])&(d.ex>0)&(d.q_p>0)].copy()
mp['f']=[NGA_FB[2015].get(int(u),T.get((int(i),int(u)),np.nan)) if pd.notna(u) else np.nan for i,u in zip(mp.item,mp.u_p)]
mp['price']=mp.ex/(mp.q_p*mp.f); med=mp.price.median()
print('milk_processed 2015 median price per kg (all item rows):',round(med,1))
g=s.groupby('u_p').agg(n=('ex','size'),median_spend_per_unit=('ex',lambda x: (x/s.loc[x.index,'q_p']).median()),factor=('f','first'),median_price_per_kg=('price','median'))
g['ratio_to_median']=g.median_price_per_kg/med
g['implied_kg_per_unit_at_median_price']=g.median_spend_per_unit/med
print(g.round(4).to_string())
print('share of unit-121 purchases screened (<0.1x):', ((s[s.u_p==121].price<0.1*med)).mean().round(3), ' n=',(s.u_p==121).sum())
