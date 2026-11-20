"""Compare rebuild vs a panel (old or new). python r2/compare.py CC old|new [noscreen] [nom17] [nonstrict]"""
import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24'); sys.path.insert(0,'/home/claude/phd/checks/audit/v24/r2')
from build import *
COLS=['qty','purch','own','gift','exp_conv','uv','unconv']
def panel(c, which):
    path=('/home/claude/work/v24/data/OUTPUT_run4_traced/' if which=='old' else OUT)+f'panel_{c}.csv'
    p=pd.read_csv(path,dtype={'hhid':str},low_memory=False)
    suf='_std' if 'qty_std' in p else '_kg'
    return p.rename(columns={'qty'+suf:'qty','purch'+suf:'purch','own'+suf:'own','gift'+suf:'gift'})
def run(c, which, screen, dom17, strict=True, extra_by_year=None, verbose=True, keep=False):
    p=panel(c,which); res=[]; allc=[]; mis=[]; built=[]
    for y in YEARS[c]:
        P,counts,d2=build(c,y,screen=screen,do_m17=dom17,strict=strict,extra_tab=(extra_by_year or {}).get(y))
        if keep: built.append(P)
        counts.update(country=c,year=y); allc.append(counts)
        Q=p[p.year==y]
        j=Q.merge(P,on=['hhid','product','track'],how='left',suffixes=('','_r'))
        for col in COLS:
            m=cmp(j[col],j[col+'_r'])
            for (pr,tr),g in j.groupby(['product','track']):
                mm=m[g.index]
                res.append(dict(country=c,year=y,product=pr,track=tr,col=col,n=len(g),nmis=int((~mm).sum())))
            if (~m).sum(): mis.append(j.loc[~m,['hhid','year','product','track',col,col+'_r']].assign(col=col).rename(columns={col:'panel',col+'_r':'rebuild'}))
    R=pd.DataFrame(res)
    M=pd.concat(mis) if mis else pd.DataFrame()
    if verbose:
        t=R.groupby(['year','col']).nmis.sum().unstack(); print(c,which,'screen' if screen else 'noscreen','m17' if dom17 else 'nom17'); print(t.to_string())
        print(pd.DataFrame(allc).to_string())
    return R,M,pd.DataFrame(allc),(pd.concat(built) if keep else None)
if __name__=='__main__':
    c,which=sys.argv[1],sys.argv[2]
    R,M,C,_=run(c,which,'noscreen' not in sys.argv,'nom17' not in sys.argv,'nonstrict' not in sys.argv)
    if len(M):
        M.to_csv(f'/home/claude/work/v24/audit_private/mis_{c}_{which}.csv',index=False)
        print(M.groupby(['year','product','track','col']).size().head(60).to_string())
