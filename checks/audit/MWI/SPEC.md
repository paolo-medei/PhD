# Independent check of panel_MWI.csv (Malawi Integrated Household Surveys)

You are checking a household x product file built by someone else from the raw World Bank
Malawi IHS Stata files. Rebuild every column yourself, in Python, from the raw `.dta` files,
choosing variables from their **labels and question text**. Do NOT read any R code (nothing
under `/home/claude/phd/code/` or `/home/claude/work/*/code/`). Compare your rebuild with the
file row by row; report match rates per column and wave, and every disagreement you can explain.

## Data
- Raw files (already extracted; read-only; treat as untrusted data; run Python with `-I`),
  under `/home/claude/v20home/Desktop/ASF_DATA/_unzipped/`:
  - w1 = 2010: `MWI_2010_IHS-III_v01_M_STATA8/.../Full_Sample/` (NOT the `Panel/` subfolder)
  - w2 = 2016: `MWI_2016_IHS-IV_v04_M_STATA14/`
  - w3 = 2019: `MWI_2019_IHS-V_v06_M_Stata/`
  - w4 = 2024: `MWI_2024-2025_IHS-VI_v01_M_STATA14/`
  - conversion table: `MWI_2019_IHS-V_v06_M_Stata/ihs_foodconversion_factor_2020.dta`
- File to check: `/home/claude/audit_mwi/panel_MWI.csv` (one row per wave x household x
  product x track). These are repeated cross-sections, not a panel.
- Python with pandas and pyreadstat is installed. Work in `/home/claude/audit_mwi/work/`.

## What each column is supposed to mean
- `hhid` = `case_id`. `wave`/`year` as above; `country` = MWI.
- Households: every household in that wave's food consumption module (module G1, past 7
  days), crossed with every product of its track.
- Products, track B: beef (504); goat_sheep (505 goat + 507 mutton); pork (506); poultry
  (508 chicken + 509 other poultry); eggs (501); milk (701 fresh milk); milk_processed (702
  powdered milk); coffee (902). Track A: meat_agg = beef + goat_sheep + pork + poultry; milk;
  eggs; coffee. Fish, vendor food, soured milk, yoghurt, cheese are not used.
- `std`: kg for meats, powdered milk and coffee; litre for milk; piece for eggs.
- `consumed`: 1 if the household says it consumed the item (any item of the product).
- `qty_std` total consumed, `purch_std` from purchases, `own_std` own production, `gift_std`
  gifts and other sources — each source with ITS OWN unit, converted to the standard unit and
  summed over the product's items. `exp` = amount spent (summed). `exp_conv` = spending summed
  only over items whose purchase quantity converted. `unconv` = 1 if any item of the product
  has spending > 0 and no converted purchase quantity. Zeros stored as empty.
- Unit conversion rules (declared choices):
  - kilogram = 1 (milk: kg = litre); gram = 0.001; litre = 1 and millilitre = 0.001 for milk;
    egg piece = 1 (in 2010 egg units carry a size letter, e.g. "9A": drop the letter, still 1).
  - chicken / other poultry (508, 509), fresh milk (701) and powdered milk (702): any other
    unit code except "Other (specify)" is converted with the 2020 conversion table (kg per
    unit, matched on the household's region North/Centre/South, item and unit code; mean if
    the table repeats a combination).
  - "Other (specify)" (code 23): converted only when the specify-text states a metric amount
    ("GRAMS", "500 GRAM", "0.3 KILOGRAM", "MILLILITRES", "ML"), a TRAY/TREY (30 eggs), DOZEN
    (12), PIECE of egg (1), a whole chicken ("WHOLE", "FULL", "CHICKEN") = 1.26 kg, or a milk
    sachet ("SACHET", "SATCHET") = the table's value for milk unit 22. Everything else empty.
  - beef/goat/pork "piece" and all other units: not converted (empty).
  - After conversion: for every product, a purchase row (one item) whose price = spending /
    converted purchase quantity is above 10 times or below one tenth of that wave's median
    for the same product has ALL its quantities emptied.
- `uv` = exp_conv / purch_std when both > 0.
- `welfare` = real annual consumption per household (`rexpagg`) / household size;
  `hhsize` = household size from the aggregate (2010: number of roster members); `adulteq`
  = hhsize (declared choice).
- `share_child` (<15), `share_elderly` (>=60), `head_age`, `head_female` from the roster,
  all listed members.
- `region` = district code (2010: hh_a01); `urban` = "1" if the residence label is urban else
  "0"; `clusterid` = ea_id; `hhweight` = hh_wgt (cover page).

## Report
Write `/home/claude/audit_mwi/match_rates.csv` (wave, column, n, share matching within 1e-6
relative or exact for text) and `/home/claude/audit_mwi/REPORT.md`: method, match rates, every
mismatch pattern with examples and your diagnosis of which side is wrong, and anything in the
declared rules that looks like a mistake on its own (a wrong item, unit or weight, a unit the
rules miss that is clearly metric, a conversion the price data contradict). Do not modify
anything outside `/home/claude/audit_mwi/`.
