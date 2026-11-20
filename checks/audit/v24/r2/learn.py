"""Reveal the unit factors used in the panel for UGA/MWI: implied factor = panel purch / raw purchased quantity,
for households with exactly one purchased item row in the product. Output per (product, unit code, text)."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24'); sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from build import *
c=sys.argv[1]
pan=load_panel(c,track='B'); pc='purch_std'
rows=[]
for y in YEARS[c]:
    r=LOADERS[c](y); d=r[0] if isinstance(r,tuple) else r
    mp=dict(MAPS[c]); i2p={i:p for p,its in mp.items() for i in its}
    d=d[d.item.isin(i2p)].copy(); d['product']=d.item.map(i2p)
    d['q_p']=pd.to_numeric(d.q_p,errors='coerce')
    s=d[d.q_p>0]
    n=s.groupby(['hhid','product']).size().rename('nit')
    s=s.join(n,on=['hhid','product'])
    s=s[s.nit==1]
    P=pan[pan.year==y][['hhid','product',pc]]
    s=s.merge(P,on=['hhid','product'],how='left')
    s['f']=s[pc]/s.q_p
    s['year']=y
    rows.append(s[['year','product','item','u_p','x_p','q_p','ex','f']])
S=pd.concat(rows)
S['x_p']=S.x_p.astype(str).str.strip().str.upper()
S['fr']=S.f.round(6)
g=S.groupby(['product','u_p','x_p'] if c=='MWI' else ['product','x_p'])
T=pd.DataFrame({'n':g.size(),'n_conv':g.f.count(),'mode_f':g.fr.agg(lambda s: s.mode().iloc[0] if s.notna().any() else np.nan),
                'n_mode':g.fr.agg(lambda s: (s==s.mode().iloc[0]).sum() if s.notna().any() else 0),'years':g.year.agg(lambda s: ','.join(map(str,sorted(s.unique()))))}).reset_index()
T=T[T.n_conv>0]
pd.set_option('display.width',250); pd.set_option('display.max_rows',500)
print(T.to_string())
T.to_csv(f'/home/claude/phd/checks/audit/v24/r2/learned_units_{c}.csv',index=False)
