import pyreadstat, pandas as pd, numpy as np, sys
R='/home/claude/work/final/data/_unzipped/'
it=pd.read_pickle('items_raw.pkl'); H=pd.read_pickle('hh_food.pkl')
VAR=dict(clus3=False, w1_114=False, w2_rawconv=False, w1_kgonly=False, w1_nominal=False, w3_zone=False, w2_cl_as_g=False, w2_eggs_nounit=False)
for a in sys.argv[1:]:
    k,v=a.split('='); VAR[k]=(v=='1')
STD={'w1':{1:1,2:.001,3:1,4:.001},'w2':{1:1,2:.001,3:1,4:.01},'w3':{1:1,2:.001,3:1,4:.01}}
NOM1={11:20,12:50,13:100,14:120,21:15,22:30,23:50,24:75,31:10,32:25,33:40,34:75,41:5,42:8,43:15,51:3,52:5,53:8,63:40,71:60,72:85,73:110,74:150,81:1500,82:2000,83:2500,91:10,92:20,93:25,94:50,95:200}
c2,_=pyreadstat.read_dta(R+'NGA_2012_GHSP-W2_v02_M_STATA/food_conv_w2ph.dta')
c2['f']=np.where(c2.g_cl==1, c2.conv/1000, c2.conv/(1000 if VAR['w2_cl_as_g'] else 100))
if VAR['w2_rawconv']: c2['f']=c2.conv
C2={(int(a),int(b)):f for a,b,f in zip(c2.item_cd,c2.nsu_cd,c2.f)}
c3,_=pyreadstat.read_dta(R+'NGA_2015_GHSP-W3_v02_M_Stata/food_conv_w3.dta')
zc={1:'conv_NC_1',2:'conv_NE_2',3:'conv_NW_3',4:'conv_SE_4',5:'conv_SS_5',6:'conv_SW_6'}
C3={(int(a),int(b)):f for a,b,f in zip(c3.item_cd,c3.unit_cd,c3.conv_national)}
C3z={(int(a),int(b),z):f for z,col in zc.items() for a,b,f in zip(c3.item_cd,c3.unit_cd,c3[col])}
def fac(w,item,unit,zone):
    if pd.isna(unit): return np.nan
    u=int(unit)
    if u in STD[w]: return STD[w][u]
    if w=='w1':
        if VAR['w1_kgonly'] and u>=91: return np.nan
        return NOM1.get(u,np.nan) if VAR['w1_nominal'] else np.nan
    if w=='w2': return C2.get((item,u),np.nan)
    if w=='w3':
        if VAR['w3_zone']: return C3z.get((item,u,int(zone)),np.nan)
        return C3.get((item,u),np.nan)
for q,u,o in [('qt','ut','tot'),('qp','up','pur'),('qo','uo','own'),('qg','ug','gift')]:
    f=np.array([fac(w,i,un,z) for w,i,un,z in zip(it.wave,it['item'],it[u],it.zone)])
    if VAR['w2_eggs_nounit']:
        m=(it.wave=='w2')&it['item'].isin([83,84])&it[u].isna()
        f=np.where(m,0.05,f)
    val=it[q].where(it[q]>0)
    it[o+'_kg']=val*f
    it[o+'_raw']=val
it['consumed']=(it.cons==1).astype(int)
it['exp']=it.ex.where(it.ex>0)
it.loc[it.consumed==0,['tot_kg','pur_kg','own_kg','gift_kg','exp']]=np.nan
it['exp_conv_i']=it.exp.where(it.pur_kg.notna())
it['unconv_i']=(it.exp.notna()&it.pur_kg.isna()).astype(int)
it.to_pickle('items_conv.pkl')
PROD={'beef':[90],'goat_sheep':[91,93],'pork':[92],'poultry':[80,82],'fish':[100,101,102,103],'milk':[110],
      'milk_processed':[111,113,115],'eggs':[83,84],'coffee':[120],'meat_agg':[90,91,92,93,80,82]}
TRK={'beef':['B'],'goat_sheep':['B'],'pork':['B'],'poultry':['B'],'fish':['B'],'milk':['A','B'],'milk_processed':['A','B'],'eggs':['A','B'],'coffee':['A','B'],'meat_agg':['A']}
rows=[]
base=H[['wave','hhid']]
for prod,items in PROD.items():
    s=it[it['item'].isin(items)]
    if prod=='milk_processed' and VAR['w1_114']:
        s=it[it['item'].isin(items)|((it.wave=='w1')&(it['item']==114))]
    g=s.groupby(['wave','hhid'])
    agg=pd.DataFrame({'consumed':g.consumed.max(),
        'qty_kg':g.tot_kg.sum(min_count=1),'purch_kg':g.pur_kg.sum(min_count=1),'own_kg':g.own_kg.sum(min_count=1),
        'gift_kg':g.gift_kg.sum(min_count=1),'exp':g.exp.sum(min_count=1),'exp_conv':g.exp_conv_i.sum(min_count=1),
        'unconv':g.unconv_i.max()}).reset_index()
    x=base.merge(agg,on=['wave','hhid'],how='left')
    x['consumed']=x.consumed.fillna(0).astype(int); x['unconv']=x.unconv.fillna(0).astype(int)
    x['uv']=x.exp_conv/x.purch_kg
    x['product']=prod
    for t in TRK[prod]: rows.append(x.assign(track=t))
P=pd.concat(rows,ignore_index=True)
# household-level
W={'w1':('NGA_2010_GHSP-W1_v03_M_STATA/cons_agg_wave1_visit2.dta',2010),'w2':('NGA_2012_GHSP-W2_v02_M_STATA/cons_agg_wave2_visit2.dta',2012),'w3':('NGA_2015_GHSP-W3_v02_M_Stata/cons_agg_wave3_visit2.dta',2015)}
hl=[]
for w,(f,y) in W.items():
    c,_=pyreadstat.read_dta(R+f)
    c=c[['hhid','hhsize','hhweight','totcons']].rename(columns={'totcons':'welfare'})
    c['hhid']=c.hhid.astype('int64').astype(str); c['wave']=w; c['year']=y
    hl.append(c)
HL=pd.concat(hl)
HH=H.merge(HL,on=['wave','hhid'],how='left')
HH['year']=HH.wave.map({'w1':2010,'w2':2012,'w3':2015})
HH['adulteq']=HH.hhsize
HH['region']=HH.zone
HH['clusterid']=HH.state.astype(int).astype(str)+'_'+HH.ea.astype(int).astype(str)
if VAR['clus3']: HH['clusterid']=HH.state.astype(int).astype(str)+'_'+HH.lga.astype(int).astype(str)+'_'+HH.ea.astype(int).astype(str)
HH['urban']=HH.sector
HH['country']='NGA'
P=P.merge(HH,on=['wave','hhid'],how='left')
P['recall']='spend_7d'; P['std']='kg'
P.to_pickle(sys.argv[0].replace('.py','')+'_out.pkl' if len(sys.argv)==1 else 'rebuild_'+'_'.join(a for a in sys.argv[1:]).replace('=','')+'.pkl')
print(P.shape)
