"""(d) Uganda fish with item 1234 and gram-stating labels: rebuild vs new panel; MARGINS row; clusterid diff."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from build import *
X='/home/claude/work/v24/data/OUTPUT/run_2026-11-20_20-36/RESULTS_2026-11-20_20-36.xlsx'
new=load_panel('UGA','fish','B'); old=pd.read_csv('/home/claude/work/v24/data/OUTPUT_run4_traced/panel_UGA.csv',dtype={'hhid':str},low_memory=False)
old=old[(old['product']=='fish')&(old.track=='B')]
Bt=pd.read_pickle('/home/claude/work/v24/audit_private/r2_built_UGA.pkl'); Bf=Bt[(Bt['product']=='fish')&(Bt.track=='B')]
rows=[]
for y in YEARS['UGA']:
    d,ul=load_uga(y); allhh=d.hhid.unique()
    f=d[d.item.isin(MAPS['UGA']['fish'])].copy()
    pos=(f[['q_p','q_a','q_o','q_g']].fillna(0)>0).any(axis=1)|(f.ex>0); f['cx']=np.where(pos,1.0,f.cons)
    cons=f.groupby('hhid').cx.max().reindex(allhh).fillna(0); ex=f.ex.where(f.ex>0).groupby(f.hhid).sum(min_count=1).reindex(allhh)
    N=new[new.year==y].set_index('hhid'); O=old[old.year==y].set_index('hhid')
    i1234=f[f.item==1234]
    rows.append(dict(year=y,consume_share_new=N.consumed.mean(),consume_share_rebuilt=cons.reindex(N.index).mean(),consumed_match=cmp(N.consumed,cons.reindex(N.index)).mean(),
                     exp_match=cmp(N.exp,ex.reindex(N.index)).mean(),hh_consuming_1234=int((i1234.cx==1).groupby(i1234.hhid).max().sum()) if len(i1234) else 0,
                     consumed_changed_vs_old=int((N.consumed!=O.consumed.reindex(N.index)).sum()),exp_changed_vs_old=int((~cmp(N.exp,O.exp.reindex(N.index))).sum()),
                     buyers_with_uv_new=(N.uv.notna()&(N.exp>0)).sum()/(N.exp>0).sum()))
print(pd.DataFrame(rows).round(4).to_string())
# gram-stating labels: the two cases from round 1
for y,lab in [(2010,'METALLIC PLATE(80G)- SMALL'),(2011,'NIDO TIN(400G)')]:
    d,ul=load_uga(y); s=d[d.item.isin(MAPS['UGA']['fish'])&(d.x_p.str.upper()==lab)&(d.q_p>0)]
    j=new[new.year==y].set_index('hhid').loc[s.hhid.unique()]
    print(y,lab,'rows',len(s),'raw purchased',s.q_p.tolist(),'-> panel purch_std',j.purch_std.tolist(),' unconv',j.unconv.tolist())
M=pd.read_excel(X,sheet_name='MARGINS_01_three_margins'); print(M[M['product']=='fish'][['country','n','n_buyers','n_unit_values','e_qty','e_qual']].to_string(index=False))
# clusterid diff (not in the spec)
a=pd.read_csv('/home/claude/work/v24/data/OUTPUT_run4_traced/panel_UGA.csv',dtype={'hhid':str,'clusterid':str},low_memory=False)
b=pd.read_csv(OUT+'panel_UGA.csv',dtype={'hhid':str,'clusterid':str},low_memory=False)
m=a.merge(b,on=['hhid','year','product','track'],suffixes=('_o','_n'))
dd=m[m.clusterid_o.astype(str)!=m.clusterid_n.astype(str)]
print('clusterid changed rows',len(dd),'households',dd.hhid.nunique(),'years',dd.year.unique(),'old values',dd.clusterid_o.unique()[:5],'new values',dd.clusterid_n.unique()[:5])
