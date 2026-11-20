"""Round 2 driver: rebuild all five panels (screen + M17), compare with the new panels, collect screen and M17 counts.
Writes counts/match tables (no household ids) to r2/, household-level mismatches to /home/claude/work/v24/audit_private/."""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from compare import *
LOG={'ETH':[(121,0,109),(108,0,99),(176,0,177),(101,0,84),(60,0,59)],'TZA':[(24,1,22),(5,0,5),(20,1,20),(25,0,25),(53,0,33)],
     'MWI':[(101,0,None),(65,1,None),(69,1,None),(51,1,None)],'NGA':[(100,0,100),(44,0,43),(213,0,206)],
     'UGA':[(0,0,None),(7,0,None),(0,0,None),(0,25,None),(0,0,None),(0,3,None)]}
M17LOG={'ETH':32,'TZA':18,'NGA':6,'UGA':3,'MWI':4}
T=pd.read_pickle('/home/claude/phd/checks/audit/v24/r2/mwi_factors_learned.pkl')
extra={'MWI':T,'UGA':{y:'no_coffee' for y in YEARS['UGA']}}
allR=[]; allC=[]; m17=[]; built={}
for c in ['ETH','TZA','NGA','UGA','MWI']:
    R,M,C,Bt=run(c,'new',True,True,extra_by_year=extra.get(c),verbose=False,keep=True)
    built[c]=Bt
    allR.append(R)
    for i,(e,r,o) in enumerate(LOG[c]):
        C.loc[i,'log_purch_emptied']=e; C.loc[i,'log_eggs_rescaled']=r; C.loc[i,'log_other_emptied']=o
    allC.append(C)
    f=Bt[Bt.m17]
    m17.append(dict(country=c,rebuilt_rows=int(len(f)),log=M17LOG[c],by_track=f.groupby('track').size().to_dict(),by_product=f.groupby('product').size().to_dict()))
    if len(M): M.to_csv(f'/home/claude/work/v24/audit_private/r2_mismatch_{c}.csv',index=False)
    Bt[Bt.m17][['hhid','year','product','track','qty','purch','exp']].to_csv(f'/home/claude/work/v24/audit_private/r2_m17_rows_{c}.csv',index=False)
    pd.to_pickle(Bt,f'/home/claude/work/v24/audit_private/r2_built_{c}.pkl')
R=pd.concat(allR); C=pd.concat(allC); M17=pd.DataFrame(m17)
R.to_csv('/home/claude/phd/checks/audit/v24/r2/match_counts.csv',index=False)
C.drop(columns=['other_nontotal_cells']).to_csv('/home/claude/phd/checks/audit/v24/r2/screen_counts_vs_log.csv',index=False)
M17.to_csv('/home/claude/phd/checks/audit/v24/r2/m17_counts.csv',index=False)
pd.set_option('display.width',250)
print(C.drop(columns=['other_nontotal_cells']).to_string())
print(M17.to_string())
S=R.groupby(['country','year','col']).agg(n=('n','sum'),nmis=('nmis','sum')).reset_index(); S['match']=1-S.nmis/S.n
print(S.pivot_table(index=['country','year'],columns='col',values='nmis').to_string())
print('total rows compared x cols', R.n.sum(), 'mismatches', R.nmis.sum())
