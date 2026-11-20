# Independent audit of the v24 changes (fish, unit-value coverage rule, M15, M16, FAO table)

Audit date: 20 November 2026. Outputs checked: `/home/claude/work/v24/data/OUTPUT/panel_{ETH,TZA,NGA,UGA,MWI}.csv` and `run_2026-11-15_12-16/RESULTS_2026-11-15_12-16.xlsx`. These files have not changed since 15 November.

How the check was done: the auditor did not open any pipeline code. Every quantity was rebuilt in Python from the raw LSMS-ISA `.dta` files and the FAOSTAT zips, choosing variables from their labels; the rules come from the written spec. Where the spec left a choice open, each alternative was tried, and the report says which one the pipeline uses. No pipeline file was modified. Scripts: `rebuild_{tza,uga,mwi,nga,eth}.py` and `fish_all.py` (part 1), `margins_nuv2.py` (part 2), `m15_cost_per_gram.py` (part 3), `m16_final.py` and `m16_rowlevel.py` (part 4), `fao_check.py` and `fao_meat.py` (part 5).

Household identifiers that appeared in the auditor's report are left out of this public file (they are survey microdata); the household-level mismatch list (`fish_mismatches.csv`) stays on the working machine and is not committed.

## Bottom line

| Part | Result |
|---|---|
| 1. Fish product, 5 countries, 21 rounds | Row-level match of 99.9 to 100% on every column. All differences explained except two small inconsistencies in unit handling and a unit-value screen not in the spec (details below). Tracks A and B identical for fish in TZA, UGA, MWI and NGA. |
| 2. Unit values must cover half of buyers | Confirmed. Fish has quantity and quality only for TZA (92.1% coverage) and NGA (94.4%), not UGA (14.9%) or MWI (0.18%). `n`, `n_buyers`, `n_unit_values` and `P` in MARGINS_01 reproduced exactly for all 20 rows. |
| 3. Cost per gram of protein (M15) | TZA 0.0960 and UGA 0.0890 reproduced exactly; NGA 0.0458 matches (0.046). MWI −0.0512 against −0.052. ETH not reproduced (0.1665 against 0.169). |
| 4. Welfare quintiles (M16) | No household-year in two quintiles. `_14_participation_quintile` reproduced in 99 of 100 cells; one cell off by 0.06 points. |
| 5. FAO_01 | All 165 rows reproduced within rounding to 2 decimals. |

## 1. Fish

### Rules that reproduce the panel
- `consumed` = 1 if the "consumed?" answer is yes, or any quantity or spending for a fish item is positive (one Ugandan 2013 household answered "no" but reports 1 kg bought). `exp` = sum of spending; `purch` = sum of purchased quantities whose unit converts (including those with zero or missing spending); `exp_conv` = spending on items whose purchase unit converts; `unconv` = 1 if any item with spending did not convert; `uv` = `exp_conv / purch`; `qty` = sum of converted total quantities (partial when a household reports one fish item in kg and another in heaps).
- TZA: items 808/809/810 (2020 also 8081–8084), units 1 (kg) and 2 (g) only; 2020 `hh_sec_ja1` and `hh_sec_j1` stacked (419 households, no overlap); the "approximately how many kg" follow-up is not used.
- UGA: purchases and spending at home only; `qty` = home + away + own + gifts (equals `h15bq14` in 2010–2015; summed in 2018–19). Units convert for Kilogram, Gram, Nice cup 100/60/50 g. Item 1234 excluded, as in the spec.
- MWI: unit codes 1 (kg) and 18 (g); "other, specify" metric texts parsed (one case, 2024); heaps and pieces not converted.
- NGA: items 100–103 and 105–107 (snails 104 excluded, verified: 32 snail-only consumers in 2010 would otherwise mismatch). 2010: kg, g, litre, ml (1 l = 1 kg); 2012: `food_conv_w2ph` with `g_cl` = 1 grams (÷1000) / 0 centilitres (÷100), fallback kg, g, l, cl; 2015: `food_conv_w3` `conv_national` in kg, same fallback.
- ETH: item 183 (2015) and 704 (2018/2021, mapped to factor item 183); the factor table for fish has only kg, g and litre.

### Match rates against the panel (track B, one row per household; rtol 1e-6, NA = NA counts as a match)

| country | year | n_hh | consumed | exp | exp_conv | purch | qty | uv | unconv |
|---|---|---|---|---|---|---|---|---|---|
| ETH | 2015 | 4954 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| ETH | 2018 | 6770 | 98.01% | 100% | 100% | 100% | 100% | 100% | 100% |
| ETH | 2021 | 4959 | 99.60% | 100% | 100% | 100% | 100% | 100% | 100% |
| MWI | 2010 | 12271 | 100% | 100% | 99.98% | 99.98% | 99.98% | 99.98% | 100% |
| MWI | 2016 | 12447 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| MWI | 2019 | 11434 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| MWI | 2024 | 12502 | 100% | 100% | 99.99% | 99.99% | 99.99% | 99.99% | 99.99% |
| NGA | 2010 | 4826 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| NGA | 2012 | 4759 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| NGA | 2015 | 4580 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| TZA | 2008 | 3265 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| TZA | 2010 | 3924 | 99.97% | 100% | 100% | 100% | 100% | 100% | 100% |
| TZA | 2012 | 5010 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| TZA | 2014 | 3352 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| TZA | 2020 | 4709 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| UGA | 2010 | 2657 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| UGA | 2011 | 2830 | 100% | 100% | 99.89% | 99.89% | 99.89% | 99.89% | 99.96% |
| UGA | 2013 | 3119 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| UGA | 2015 | 3285 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| UGA | 2018 | 3172 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| UGA | 2019 | 3059 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |

ETH conventions already applied: `unconv` is NA for non-buyers (0 elsewhere); a reported spending of 0 is kept as 0 (1 household, 2015).

### Mismatches, all explained
- `consumed` NA in the panel, 0 in the rebuild: ETH 2018 (135 households), ETH 2021 (20), TZA 2010 (1). The raw "consumed?" answer is missing for every fish item; the panel keeps NA. Convention, not an error.
- UGA 2011, 3 households: unit "Nido Tin(400g)" converted to 0.4 kg by the pipeline, not in the spec's list. Inconsistent with one UGA 2010 household whose unit "Metallic plate(80g)- Small" also states a weight but is not converted. Pick one rule (4 households).
- MWI 2010 (3 households) and MWI 2024 (1): purchases whose unit converts but which the panel treats as unconverted. Their unit values are 150×, 0.005×, 0.012× and exactly 10.0× the year's median; every other converted fish purchase lies inside (0.1×, 10×). This is a screen at 10× / 0.1× the median, not in the spec. The same screen appears in UGA (2 beef purchases in 2011, at 0.09× and about 200×). Panel unit values are bounded in [0.1, 10]× the median in UGA and MWI, but reach 1,000–5,700× the median in TZA, NGA and ETH (e.g. TZA fish 2020 at 8,000,000 TSh/kg). The screen is applied in two of the five countries; MARGINS trims unit values at the 1st/99th percentile, which limits the damage, but the rule should be made consistent and documented.

### Fish levels (panel = rebuild unless two values shown)

| country | year | consume % | buy % | total spend 7d (LCU) | buyers fully converted | buyers with uv | item purchases converted | spend share converted | median uv |
|---|---|---|---|---|---|---|---|---|---|
| TZA | 2008 | 64.6 | 59.8 | 4,654,965 | 99.8% | 99.9% | 2186/2189 | 99.8% | 2,000 |
| TZA | 2010 | 70.0 | 65.7 | 7,532,300 | 100.0% | 100.0% | 2919/2920 | 100.0% | 2,500 |
| TZA | 2012 | 69.3 | 65.7 | 11,998,475 | 100.0% | 100.0% | 3707/3708 | 100.0% | 3,439 |
| TZA | 2014 | 75.0 | 71.2 | 10,032,350 | 100.0% | 100.0% | 2746/2746 | 100.0% | 4,000 |
| TZA | 2020 | 73.9 | 69.8 | 14,186,908 | 74.9% | 78.1% | 3186/4178 | 75.9% | 5,333 |
| UGA | 2010 | 35.8 | 33.9 | 4,261,200 | 1.2% | 1.9% | 17/1012 | 2.2% | 4,000 |
| UGA | 2011 | 37.7 | 34.9 | 5,958,400 | 1.2% | 1.6% (rebuild 1.3%) | 14/1122 | 1.7% | 6,375 (rebuild 5,000) |
| UGA | 2013 | 39.4 | 36.9 | 6,849,100 | 9.8% | 12.7% | 146/1306 | 7.4% | 10,000 |
| UGA | 2015 | 39.3 | 37.0 | 7,542,250 | 9.6% | 11.4% | 140/1373 | 6.0% | 12,000 |
| UGA | 2018 | 50.6 | 48.3 | 8,707,750 | 26.7% | 41.0% | 635/2062 | 16.8% | 16,667 |
| UGA | 2019 | 54.4 | 51.8 | 9,593,800 | 29.1% | 44.6% | 712/2117 | 21.1% | 16,667 |
| MWI | 2010 | 76.6 | 73.6 | 2,075,865 | 0.2% | 0.4% | 41/11416 | 0.9% | 300 (rebuild 283) |
| MWI | 2016 | 73.3 | 69.8 | 7,327,990 | 0.1% | 0.3% | 25/11744 | 0.5% | 900 |
| MWI | 2019 | 73.1 | 69.0 | 8,208,950 | 0.3% | 0.6% | 53/10732 | 1.1% | 900 |
| MWI | 2024 | 76.2 | 71.4 | 29,452,476 | 0.1% | 0.3% | 28/13832 | 0.5% | 1,000 |
| NGA | 2010 | 71.7 | 69.6 | 2,253,697 | 94.6% | 95.9% | 4382/4595 | 96.6% | 500 |
| NGA | 2012 | 68.6 | 63.8 | 2,021,342 | 98.8% | 99.7% | 3772/3809 | 99.1% | 600 |
| NGA | 2015 | 70.8 | 66.0 | 2,330,367 | 95.6% | 99.5% | 3793/3926 | 97.0% | 649 |
| ETH | 2015 | 2.0 | 1.1 | 3,087 | 58.2% | 58.2% | 32/55 | 73.8% | 20 |
| ETH | 2018 | 2.5 | 1.7 | 10,506 | 11.6% | 11.6% | 13/112 | 13.6% | 80 |
| ETH | 2021 | 3.9 | 2.7 | 24,425 | 13.5% | 13.5% | 18/133 | 12.0% | 82 |

Shares unweighted over panel households; weighted shares in `fish_summary.csv` also match.

### Observations for the author (not mismatches)
1. UGA item 1234 "Dried Nkejje" (a small lake fish) is excluded in 2018/19, as the spec says. Including it would add 24 (2018) and 17 (2019) consuming households and change spending for 54 and 44 buyers; usually measured in bundles, so unit values would not change.
2. Partial households: in TZA 2020, 196 households have a `qty` covering only their kg/g items; `exp_conv` is likewise partial for mixed households (107 in TZA 2020, 218 and 245 in UGA 2018/19). `uv` stays consistent, but `qty` as total fish quantity is understated for them, and the FAO "coverage" counts them as covered.
3. Purchased quantity with zero or missing spending goes into `purch` but not `exp_conv` (3 TZA households); in one TZA 2020 household it lowers the unit value from 5,000 to 4,537.
4. Volume units converted at 1 kg per litre for fish in NGA 2010 and ETH; the NGA 2012 official factors for dried fish are in centilitres (a mudu of dried fish = 600 cl → 6 kg). About 15 rows.

## 2. Unit values must cover half of buyers (MARGINS_01_three_margins)

All 20 rows reproduced exactly in `n`, `n_buyers`, `n_unit_values` and `P`. Sample: households with welfare > 0 and adult equivalents, weight, region and head age present (NGA: welfare only; UGA: welfare, adult equivalents and head age, 61 rows without weight kept). Buyer: spending > 0 or purchased quantity > 0. `n_unit_values`: buyers with `uv` > 0 and `unconv` = 0, after trimming `uv` at the year's 1st/99th percentiles. The rule is applied on the pooled country sample.

| fish | n_buyers | n_unit_values | coverage | qty/quality reported |
|---|---|---|---|---|
| TZA | 13,349 | 12,297 | 92.1% | yes |
| NGA | 9,429 | 8,898 | 94.4% | yes |
| UGA | 7,324 | 1,093 | 14.9% | no |
| MWI | 34,527 | 62 | 0.18% | no |

ETH has no fish row (fish only in track B); pooled coverage would be 21%.

## 3. Cost per gram of protein (M15)

Per household-year: Σ `exp_conv` / Σ (`purch` × protein per unit), track B, products beef, goat_sheep, pork, poultry, eggs, milk, milk_processed, cheese; fish excluded. WLS of log(cost per gram) on log(welfare), log(adult equivalents) and region × year dummies, survey weights, robust SE.

| country | rebuilt elasticity (SE) | n households | workbook |
|---|---|---|---|
| TZA | 0.0960 (0.0093) | 9,824 | 0.096 |
| UGA | 0.0890 (0.0058) | 9,688 | 0.089 |
| NGA | 0.0458 (0.0108) | 9,161 | 0.046 |
| MWI | −0.0512 (0.0068) | 21,421 | −0.052 |
| ETH | 0.1665 (0.0311) eggs in kg; 0.0285 if eggs were pieces | 6,209 | 0.169 |

MWI is off at the third decimal (cause not identified). ETH not reproduced: the ETH panel has no `std` column, and no variant tried (eggs as kg or pieces, cheese excluded, zone effects, other welfare definitions) reached 0.169.

## 4. Welfare quintiles (M16)

One quintile per household-year, unweighted equal-count fifths within year among households with welfare, joined to all the household's rows. No household-year falls in two quintiles (the old row-level assignment would split 16, 8, 16, 12 and 16 household-years in TZA, UGA, MWI, NGA, ETH). Household-level assignment reproduces 99 of 100 cells of `_14` (row-level: 93; quantile breakpoints: 94). meat_agg exact in TZA, MWI, NGA, ETH; UGA meat_agg Q3 41.538 against 41.6 (about one household at a boundary; not tie handling).

## 5. FAO comparison (FAO_01_levels_lsms_vs_fbs)

kg per person per year = 52 · Σ(w · q) / Σ(w · hhsize), track B, non-converted q = 0, eggs × 0.055; `kg_trim100` sets q to 0 above 100 × the median among consumers; `coverage` = weighted share of consumers with a converted quantity; FAO element 645 averaged over label year and next (2023 alone for MWI 2024; historic file before 2010); meat over the listed meats with coverage = minimum (poultry left out in UGA and ETH, coverage ≤ 0.31); ratio reported only when coverage ≥ 0.5 (threshold not in the spec). All 165 rows match at 2 decimals (14 `fao_kg` values differ by 0.005, rounding of a trailing 5).

Without trimming, TZA fish 2020 would be 10.27 instead of 4.54 kg (3 households) and UGA meat 2019 35.98 instead of 7.44 (1 household).

## Discrepancies not fully explained
1. A unit-value screen at 10× / 0.1× the median applied in MWI and UGA but not in TZA, NGA, ETH; not in the spec.
2. UGA weight-labelled units handled inconsistently ("Nido Tin(400g)" converted, "Metallic plate(80g)" not).
3. M15 MWI −0.0512 vs −0.052 and ETH 0.1665 vs 0.169.
4. M16 UGA meat_agg Q3 41.5 vs 41.6.

## Note added after the audit (20 November 2026)
The ETH gap in part 3 is explained. The pipeline pairs spending and protein product by product but does not require both on the same product: protein from a purchased quantity with missing or zero spending enters the denominator. Rebuilding the pipeline's rule from the panel gives ETH 0.1687 (workbook 0.169); the auditor's rule (both spending and quantity required) gives 0.1665. The auditor's rule is the right one; the same convention explains the third-decimal gap in MWI and the 3 TZA households of observation 3 in part 1.
