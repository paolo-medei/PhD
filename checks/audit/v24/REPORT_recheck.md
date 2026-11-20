# v24 audit, round 2: re-check of the 20 Nov run (price screen, M17, Uganda fish, M15)

Outputs checked:
- panels: `/home/claude/work/v24/data/OUTPUT/panel_*.csv` (20 Nov, 20:36);
- workbook: `run_2026-11-20_20-36/RESULTS_2026-11-20_20-36.xlsx`;
- log: `run6.log`;
- previous panels: `OUTPUT_run4_traced/`.

Method: the same as round 1. Everything was rebuilt in Python from the raw `.dta` files, without opening the
pipeline code and without modifying any pipeline file. The scripts are in `r2/`. Household-level lists are kept
outside this repository.

(Saved from the auditor's hand-back by the main session; the auditor cannot write files. Notes added by the
main session are marked *[note]*.)

## Bottom line

| Item | Result |
|---|---|
| (a) Price-screen counts vs `run6.log` | ETH, TZA, NGA, UGA: **exact in every wave** for purchases emptied, egg rows rescaled and other-source quantities emptied. MWI: exact in 2010 and 2019 and for egg rescales; **2 short in 2016 (63 vs 65) and 2024 (49 vs 51)**. |
| (b) Row-level match: qty, purch, own, gift, exp_conv, uv, unconv; 5 countries, tracks A and B | 1,682,122 rows × 7 columns. **14 cells differ, all in MWI** (2 household rows, each in A and B). ETH, TZA, NGA and UGA: 100%. |
| (c) M17 rows | **ETH 32, TZA 18, NGA 6, UGA 3, MWI 4: all exact.** |
| (d) Uganda fish (item 1234 and gram labels) | 100% match on every column, plus consumed and spending. |
| (e) Cost per gram | TZA 0.0895, NGA 0.0346, UGA 0.0891 and MWI −0.0512 match the workbook (0.089, 0.035, 0.089, −0.051). **ETH 0.2229 against 0.221: not reproduced.** |
| (f) NGA 2015 milk powder, medium sachet = 0.4 kg | **In the auditor's reading the table is wrong** (section 6). |

## 1. How the rebuild was done

**Item rows.** For every product item and every wave: the consumed answer, spending, and the quantity and unit of
each source (total, purchase, own production, gift) from the raw module.

**Products.** Mapped from item labels and checked against panel spending and consumption (100% match). Points
that needed care:
- TZA processed milk = item 902.
- NGA processed milk = 111, 113 and 115, plus 114 in 2010.
- UGA beef = 117 (offal and roasted items carry no data); UGA processed milk = 1252 and 1254.
- MWI poultry = 508 and 509; MWI processed milk = 702.
- UGA fish includes item 1234.
- Track A rows equal the corresponding track B product, and meat_agg is the sum of the meat items. ETH 2011/13 use
  their own aggregate items (18–24).

**Unit conversion** (outside the change spec).
- TZA, NGA and ETH: labels and official tables. ETH uses the national conversion factor; NGA uses `food_conv_w2ph`
  and `food_conv_w3` with metric fallbacks.
- TZA conventions from the earlier audit: 55 g per egg, and milk in kg taken as litres.
- Before any screen, these reproduce the **previous** panels at 100% on all seven columns.
- UGA: label rules, same 100% result. Coffee is never converted (section 5).
- MWI: the factors depend on region-specific IHS tables and "other, specify" text, so they were inferred from the
  previous panel. This makes MWI a weaker test of conversion, although the screen and M17 are rebuilt
  independently.

**Price screen (spec 1).**
- Item price = spending / converted purchased quantity, where both are > 0.
- Median by product over the wave's item rows.
- Eggs in pieces (TZA, UGA, MWI) are rescaled by ×30 or ÷30 when that puts the price inside (median/3, 3×median).
- A purchase is then emptied if its price is still > 10× or < 0.1× the median.
- Total, own and gift quantities follow the purchase only when recorded in the same unit code (MWI: code plus
  text). In UGA, one unit for all sources, all four go.
- The comparisons are **strict**: using ≥/≤ creates mismatches in TZA.

**M17 (spec 2).** By year × product × track: a row whose total quantity exceeds 100× the median of positive
totals, or whose purchased quantity exceeds 100× the median of positive purchases, loses all quantities;
exp_conv = NA, unconv = 1 where spending > 0, uv recomputed.

## 2. (a) Price-screen counts

Rebuild / `run6.log`. "Other quantities" counts the total, own and gift quantities in the purchase's unit
separately, as the log does (ETH 2015: 177 such quantities from 176 purchases).

| country | wave | purchases emptied | egg rows rescaled | other quantities emptied |
|---|---|---|---|---|
| ETH | 2011 | 121 / 121 | 0 / 0 | 109 / 109 |
| ETH | 2013 | 108 / 108 | 0 / 0 | 99 / 99 |
| ETH | 2015 | 176 / 176 | 0 / 0 | 177 / 177 |
| ETH | 2018 | 101 / 101 | 0 / 0 | 84 / 84 |
| ETH | 2021 | 60 / 60 | 0 / 0 | 59 / 59 |
| TZA | 2008 | 24 / 24 | 1 / 1 | 22 / 22 |
| TZA | 2010 | 5 / 5 | 0 / 0 | 5 / 5 |
| TZA | 2012 | 20 / 20 | 1 / 1 | 20 / 20 |
| TZA | 2014 | 25 / 25 | 0 / 0 | 25 / 25 |
| TZA | 2020 | 53 / 53 | 0 / 0 | 33 / 33 |
| NGA | 2010 | 100 / 100 | 0 / 0 | 100 / 100 |
| NGA | 2012 | 44 / 44 | 0 / 0 | 43 / 43 |
| NGA | 2015 | 213 / 213 | 0 / 0 | 206 / 206 |
| UGA | 2010 | 0 / 0 | 0 / 0 | 0 / not printed |
| UGA | 2011 | 7 / 7 | 0 / 0 | 7 / not printed |
| UGA | 2013 | 0 / 0 | 0 / 0 | 0 / not printed |
| UGA | 2015 | 0 / 0 | 25 / 25 | 0 / not printed |
| UGA | 2018 | 0 / 0 | 0 / 0 | 0 / not printed |
| UGA | 2019 | 0 / 0 | 3 / 3 | 0 / not printed |
| MWI | 2010 | 101 / 101 | 0 / 0 | 101 / not printed |
| MWI | 2016 | **63 / 65** | 1 / 1 | 61 / not printed |
| MWI | 2019 | 69 / 69 | 1 / 1 | 63 / not printed |
| MWI | 2024 | **49 / 51** | 1 / 1 | 48 / not printed |

**Egg rescales.**
- UGA 2015: 25 rows recorded as "Piece-Medium" priced at about 30× the median, multiplied by 30 (trays).
- UGA 2019: one "Number of Units" row multiplied by 30 and two "Tray of 30 eggs" rows divided by 30.
- TZA 2008 and 2012: one egg row recorded in kg divided by 30 in each year.
- MWI 2016, 2019 and 2024: one row multiplied by 30 in each year.

**Emptied purchases by product, all waves.** ETH mostly coffee (377 of 568); NGA mostly processed milk (179) and
fish (96); MWI processed milk (107) and poultry (54); TZA fish (52). Breakdown in `r2/screen_emptied_by_product.csv`.

**MWI gaps (2016 and 2024, 2 each).** Purchases that the pipeline converts and then empties, but whose unit/text
combination the inferred table does not contain: such combinations appeared only in rows the old screen had
already emptied. The rebuild leaves them unconverted, so the output is the same either way. MWI 2016 matches the
panel at 100% despite the count gap.

## 3. (b) Row-level match of the new panels

| country | rows (A + B) | cells compared | mismatching cells |
|---|---|---|---|
| ETH | 263,034 | 1,841,238 | 0 |
| TZA | 283,640 | 1,985,480 | 0 |
| NGA | 212,475 | 1,487,325 | 0 |
| UGA | 241,817 | 1,692,719 | 0 |
| MWI | 681,156 | 4,768,092 | 14 |

The 14 MWI cells come from 2 household rows, each in tracks A and B:
- **MWI 2010 poultry.** Own production recorded in "other, specify" as "FULL CHICKEN + KHUNDA". The pipeline counts
  it as a whole chicken (1.26 kg); the inferred table does not contain that text. A conversion detail, not part
  of this round's spec.
- **MWI 2024 fish.** One purchase priced at exactly 10.0× the rebuild's fish median. The panel empties it, the
  strict "> 10×" keeps it; this follows if the pipeline's median is slightly lower because of the 2 extra
  converted rows of section 2. The old Malawi screen emptied it too.

**Changes from the previous panels, as a cross-check.**
- ETH, TZA and NGA: only quantity columns changed, from the screen and M17.
- MWI: only 4 rows changed (M17); Malawi already had a price screen.
- UGA: fish item 1234 (consumed and spending), the gram labels, and M17.
- The "clusterid" difference in 56 UGA 2019 rows is a data-type artifact; the value is missing in both versions.

## 4. (c) M17 counts

| country | rebuilt | log | by track | by product |
|---|---|---|---|---|
| ETH | 32 | 32 | A 24, B 8 | coffee 28, cheese 2, meat_agg 1, milk 1 |
| TZA | 18 | 18 | A 9, B 9 | fish 6, meat_agg 4, milk 4, goat_sheep 2, poultry 2 |
| NGA | 6 | 6 | A 3, B 3 | eggs 4, fish 2 |
| UGA | 3 | 3 | A 1, B 2 | meat_agg 1, milk_processed 1, pork 1 |
| MWI | 4 | 4 | A 2, B 2 | meat_agg 1, milk 2, poultry 1 |

## 5. (d) Uganda fish

- **Item 1234 (dried nkejje) is now fish.** Panel and rebuild agree at 100% on consumed, spending and every
  quantity column. Against the previous panel, consumed changes for 24 households in 2018 and 17 in 2019, and
  spending for 54 and 44, as predicted in round 1. Households consuming fish: 51.3% in 2018, 55.0% in 2019. 1234
  is recorded in bundles, so it never converts.
- **Gram labels.** The 2010 "Metallic plate(80g)" purchase of 3 plates converts to 0.24 kg; the three 2011
  "Nido Tin(400g)" purchases convert to 0.4 kg each.
- **MARGINS_01.** UGA fish: 7,367 buyers and 1,083 unit values (14.7%), so still no quantity or quality estimate.
  All 20 rows of MARGINS_01 still reproduce exactly (n, n_buyers, n_unit_values, P). Fish coverage: TZA 91.8%,
  NGA 93.8%, MWI 0.18%.
- **Spec 3 vs the panel: coffee.** UGA coffee is never converted, whatever the unit ("Packet (100 g)",
  "Sacket (15g)", even Kilogram). Not new in this run. *[note] Coffee is analysed only for Ethiopia; elsewhere it
  has no standard unit in the item list on purpose and enters only through spending. Documented as the exception
  to the gram-label rule.*
- **Observation, old rule.** UGA milk in "Nice cup (50/60/100 g)" is counted as 0.5 litre. *[note] Decided by
  Paolo on 13 Nov from prices: the Nice cup of milk costs what the 0.5-litre packet costs; the grams on the label
  describe dry goods (FINDINGS, section E).*

## 6. (f) NGA 2015 milk powder (item 111) in PACKET/SACHET units

| unit | table kg/unit | purchases | median spend per unit (naira) | price/kg at the table factor | × product median (1,709 naira/kg) |
|---|---|---|---|---|---|
| 120 small | 0.012 | 384 | 40 | 3,333 | 1.95 |
| 121 medium | **0.400** | 69 | 40 | 100 | **0.06** |
| 122 large | **0.900** | 11 | 40 | 44 | **0.03** |

Households pay the same median 40 naira per unit whatever size code they report. At the product median price,
40 naira buys about 23 g, close to the small sachet's 12 g and nowhere near 400 g. The same table steps up
gradually for other items: chocolate drinks 12/200/500 g, tea 10/50/250 g.

Reading: the 0.400 and 0.900 kg entries for item 111 do not describe what these households bought; either the
table is wrong or the size codes are unreliable. The screen empties 58 of the 69 medium-sachet purchases and 10 of
the 11 large ones (part of the 213 in NGA 2015), which is the safe outcome. Flag the table rows rather than impute
another weight.

## 7. (e) Cost per gram of protein from the new panels

Spec 4 rule: Σ exp_conv / Σ (protein × purchased quantity), over track B rows with exp_conv > 0, purchased
quantity > 0 and a protein factor. Regression: WLS on log welfare and log adult equivalents with region × year
effects, survey weights, households with a positive cost.

| country | rebuilt (SE) | n households | workbook |
|---|---|---|---|
| ETH | 0.2229 (0.031), eggs in kg at 126 g/kg; 0.0732 with eggs as pieces | 6,148 | **0.221** |
| TZA | 0.0895 (0.007) | 9,803 | 0.089 |
| NGA | 0.0346 (0.009) | 9,108 | 0.035 |
| UGA | 0.0891 (0.006) | 9,687 | 0.089 |
| MWI | −0.0512 (0.007) | 21,421 | −0.051 (round 1's −0.052 is now resolved) |

ETH stays about 0.002 off, as in round 1 (0.1665 against 0.169). Tried without reproducing 0.221: zone instead of
region fixed effects, no weights, household size instead of adult equivalents, total consumption as welfare,
dropping cheese or other products, other cheese factors, adding track A or the 2011/13 waves. *[note] The gap is
1% of the estimate and a fraction of its standard error (0.031); open, not blocking.*

## 8. Unexplained or open

1. **MWI:** screen counts 2 short in 2016 and 2024, and 2 household rows differ; both traced to MWI unit
   conversion inferred from the previous panel, not to the screen rule.
2. **ETH cost per gram:** 0.2229 against 0.221.
3. **UGA coffee:** the gram-label rule is not applied (see the note in section 5).
4. **NGA milk-powder table entries:** a data issue in the survey's own table, caught by the screen.

Privacy: household-level lists from both rounds are outside this repository. *[note] The household identifiers
the auditor found in older audit files (`checks/audit/TZA/match_rates.csv`, `checks/audit/UGA/dup2018.py`) were
removed from the current tree on 20 Nov; they remain in the git history until the repository is made private.*

*[note] Not covered by this round: rule M18 (spending above 100× the median, decided by Paolo on 20 Nov after this
check). It touches 10 rows (ETH 9, MWI 1), whose spending values are listed in FINDINGS, section G.*
