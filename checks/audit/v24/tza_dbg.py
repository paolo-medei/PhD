import sys; sys.path.insert(0,'/home/claude/phd/checks/audit/v24')
from rebuild_tza import *
pd.set_option('display.width',250)
for y,ids in [(2008,['05060110010215','53020150090068']),(2010,['0505019314003901']),(2020,['3948-001-04','6934-001-01'])]:
    it=pd.concat(load(y),ignore_index=True)
    print(it[it.hhid.isin(ids)&it.item.isin(FISH)].to_string())
