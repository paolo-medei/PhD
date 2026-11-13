# Uganda: independent check of panel_UGA.csv (13 November 2026)

A separate check rebuilt every column of the panel in Python from the raw UNPS files, choosing variables
from their labels and without reading the R code (`SPEC.md` is what it was given; `rebuild.py`,
`compare.py`, `pids_rebuild.py` and the `linkcheck*`/`defchecks*` scripts are its own work, kept as a
record; data paths inside them are those of the machine it ran on).

## Round 1 (spec as in SPEC.md, general outlier rule)
- 100% match on every food, spending, unit-value, welfare, weight, region and urban column, every wave;
  panel links 18,254 of 18,264.
- Found on the panel side, all corrected in v23:
  - roster variables blanked for the 158 households missing from the consumption aggregate;
  - a 2013 household with two heads averaged (head_female 0.5): now the first listed head;
  - three 2019 households pasted into a fake cluster "NA_NA_NA": now NA;
  - 2018-19 cluster ids without the county code (subcounties are numbered within county): added;
  - 2011 household size counting usual AND regular members, where the aggregates count usual
    members only (+9%): now usual members;
  - Kampala coded 0 in 2010 only: now Central, as in the other waves;
  - fermented milk and yoghurt rows with false zeros in 2010-2015, when they were not asked: removed;
  - "not consumed" next to a recorded purchase (six 2013 rows): consumed = 1;
  - egg trays recorded as single eggs (2015) emptied rather than rescaled: now x 30 (and two 2019
    "trays" priced as single eggs / 30), as Paolo decided; "Nice cup" of milk = 0.5 l, as Paolo decided.

## Round 2 (revised spec, the corrected panel)
- All 205,573 rows match on every column except `hhsize` for 147 households absent from the
  consumption aggregate (none has welfare): the check gave them NA, the panel the roster count of
  usual members - both readings of the spec; and 2 households of 2015 with hhsize 0 (one regular,
  no usual member), now NA in the panel.

## Open points (shared by both sides; documented, not errors of construction)
- Panel links follow the ids each wave gives of its predecessor. About 185 of 1,784 links in 2013 and
  86 of 2,872 in 2015 point to a household whose head was not in the earlier one (often a sibling
  household after a split); 5 pairs of 2018 households claiming the same 2015 household are both
  treated as new (the roster identifies the continuing one in 4); 43 households of 2019 point to 2018
  households missing from the 2018 cover page. Effect: some noise in the household fixed effects.
- Welfare is in 2005/06 prices up to 2013 and 2009/10 prices from 2015: every model has year
  effects and quintiles are within year, so nothing is affected.
- Cluster: enumeration area 2010-15, parish 2018-19. 2010 and 2011 weights are panel weights.
- Poultry has quantities only for a few 2018-19 broilers; coffee never has quantities.
