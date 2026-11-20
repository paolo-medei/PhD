import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from common import *
import m16_quintiles as Q  # runs main table; reuse quint
X=Q.X
for c in ['UGA','ETH']:
    p=load_panel(c)
    if c=='ETH': p['welfare']=p['nom_totcons_aeq']
    wc='hhweight' if 'hhweight' in p else 'weight'
    h=p.groupby(['hhid','year']).agg(welfare=('welfare','first')).reset_index(); h=h[h.welfare.notna()]
    h['Q']=Q.quint(h)
    # ties in welfare within year
    t=h.groupby('year').welfare.apply(lambda s: s.duplicated(keep=False).sum())
    print(c,'tied welfare values within year:',t.to_dict())
    # row-level (long file) assignment for comparison
    pl=p[p.welfare.notna()].copy()
    pl['Qrow']=pl.groupby('year')['welfare'].transform(lambda s: (np.floor(5*(s.rank(method='first')-1)/len(s))+1).astype(int))
    nq=pl.groupby(['hhid','year']).Qrow.nunique()
    print(c,'row-level assignment would put',int((nq>1).sum()),'household-years in two quintiles')
    f=p[(p['product']=='meat_agg')&(p.track=='A')].merge(h[['hhid','year','Q']],on=['hhid','year'])
    pc='purch_std' if 'purch_std' in f else 'purch_kg'
    ind=((f.exp>0)|(f[pc]>0)).astype(float); ww=f[wc].fillna(0)
    print(c,'meat_agg hh-level',(100*(ind*ww).groupby(f.Q).sum()/ww.groupby(f.Q).sum()).round(3).tolist())
    print(c,'workbook',pd.read_excel(X,sheet_name=f'{c}_14_participation_quintile').set_index('product').loc['meat_agg'].tolist())
