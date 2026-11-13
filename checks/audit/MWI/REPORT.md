# Malawi: independent check of panel_MWI.csv (13 November 2026)

A separate check rebuilt every column in Python from the raw IHS files (IHS3 2010 Full_Sample, IHS4 2016,
IHS5 2019, IHS6 2024 and the 2020 conversion table), choosing variables from their labels, without reading
the R code. `SPEC.md` is what it was given; `rebuild.py` (round 1), `rebuild2.py` (round 2), `compare.py`,
`classify.py`, `prices.py` are its own work, kept as a record.

## Round 1
- Same 588,480 rows; 22 of 28 columns identical in every row; quantities and unit values differ in
  34-48 rows, roster columns for 394 households. Every difference explained.
- Corrected in the build after round 1: the Dzaleka refugee camp (2024, 386 households, no aggregate)
  is dropped; misspelt metric units ("MILLITER", "GRAMM", "MLS") and decimal commas are read; sachet
  texts with a qualifier, egg "PIECE (MEDIUM)", "CHICKENS", "HALF CHICKEN", "HALF KG" are read; 2010 size
  letters dropped for every unit, not only eggs.
- Problems in the rules found by prices, corrected: the table's "other poultry" piece (a chicken's weight
  for doves: not used); the powdered-milk teaspoon (heavier than the tablespoon: not used); fresh milk "in
  grams" (4.9 times the litre price: not converted); fresh-milk packets priced like sachets (read as
  sachets, by analogy with Paolo's "Nice cup" decision); egg crates priced like trays (30); a mispriced
  purchase now empties only the purchased quantity (each source has its own unit).

## Round 2 (revised rules)
- Same 583,848 rows; 27 of 28 columns identical in every row; the last differs in one household
  ("MILITRE", where the panel was right and the written rule lacked the spelling).
- Its remaining remarks, applied afterwards and checked by price: a trimmed or rescaled purchase now
  carries over to the total, own or gift quantity when that is recorded in the same unit and text (270 of
  279 cases); 2016 tins coded 71-73 are converted by the weight in their label; codes 51 and 60 and
  "small/unspecified packet" texts of fresh milk are read as sachets. 37 purchases gain a quantity; their
  unit values are within the band of the median.

## Open points (choices, documented)
- Welfare is real within each survey only (different price base): every model has year effects and
  quintiles are within year.
- adulteq = household size (the 2024 aggregate has no adult-equivalent scale); strataid not built.
- The chicken piece factor (1.27-1.30 kg) is a live weight; prices suggest 1.0-1.16 kg.
- "HALF CHICKEN" with quantity 0.5 (one row) is read as a quarter.
