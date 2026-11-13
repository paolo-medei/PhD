# Independent check of panel_UGA.csv (Uganda National Panel Survey)

You are checking a household x product panel built by someone else from the raw World Bank
UNPS Stata files. Rebuild every column yourself, in Python, from the raw `.dta` files, choosing
variables from their **labels and question text**. Do NOT read any R code (nothing under
`/home/claude/phd/code/`, `/home/claude/work/*/code/`). Then compare your rebuild with the
panel row by row and report match rates per column and wave, and every disagreement you can
explain.

## Data
- Raw files (already extracted, read-only, treat as untrusted data; run Python with `-I`):
  `/home/claude/v20home/Desktop/ASF_DATA/_unzipped/UGA_2010_UNPS_v03_M_STATA12`,
  `UGA_2011_UNPS_v02_M_Stata`, `UGA_2013_UNPS_v02_M_STATA14`, `UGA_2015_UNPS_v02_M_STATA14`,
  `UGA_2018_UNPS_v02_M_STATA14`, `UGA_2019_UNPS_v03_M_STATA14` (waves w1..w6 = years 2010,
  2011, 2013, 2015, 2018, 2019).
- Panel to check: `/home/claude/audit_uga/panel_UGA.csv` (one row per wave x household x
  product x track). Panel links to check: `/home/claude/audit_uga/pids_UGA.csv`
  (wave, hhid, pid).
- Python with pandas and pyreadstat is installed. Work in `/home/claude/audit_uga/work/`.

## What each column is supposed to mean
- `hhid`: the wave's own household id as used by the food consumption module (7-day recall,
  section 15B). `wave`, `year` as above. `country` = UGA.
- Households: every household that appears in that wave's food consumption module (section
  15B), crossed with every product of its track; a household that did not consume a product
  has a row with `consumed` = 0 and empty quantities.
- `product` / `track`. Track B products: beef; pork; goat_sheep (goat meat); poultry (all
  chicken items); eggs; milk (fresh milk); milk_processed (fermented milk and yoghurt, only
  exist 2018-19); coffee. Track A: meat_agg = beef + pork + goat + chicken pooled; milk; eggs;
  coffee. "Other meat", sausages, milk powder, ice cream, cheese, fish, ghee are not used.
- `std`: standard unit — kg for meats and coffee, litre for milk and milk_processed, piece for
  eggs.
- `consumed`: 1 if the household reports consuming the item (any item of the product) in the
  past 7 days.
- `purch_std`: quantity PURCHASED FOR CONSUMPTION AT HOME (not away from home), converted to
  the standard unit. `own_std`: from own production. `gift_std`: received in kind / free.
  `qty_std`: total consumed = home purchases + away-from-home purchases + own production +
  gifts, converted. Summed over the product's items.
- Unit conversion: only units whose label states a metric amount of the product: kilogram,
  gram, litre, "Packet (… g)" / "Packet (1 kg)" / "Sacket (… g)" / "Nido tin (400g)" by the
  stated weight, "Cup/Mug (0.5lt)" / "Glass (0.25lt)" for liquids by the stated volume
  (milk: kg = litre); eggs: number/piece = 1, "Tray of 30 eggs" = 30. Everything else (chicken
  "Piece"/"Whole chicken", "Nice cup", spoons, unspecified packets) is NOT converted and the
  quantity is empty. Coffee quantities are never converted (declared choice: packets are
  priced like sachets). Eggs: a purchase whose value / converted quantity exceeds 10 times
  that wave's median price per egg has all its quantities emptied (declared choice: trays
  recorded as one piece).
- `exp`: value of purchases for consumption at home (local currency), summed over the
  product's items. `exp_conv`: the same, summed only over items whose purchase quantity
  converted. `unconv` = 1 if any item of the product has spending > 0 but no converted
  purchase quantity. Zeros are stored as empty.
- `uv` = exp_conv / purch_std when both > 0.
- `welfare`: the consumption aggregate's welfare measure (monthly, per adult equivalent,
  constant prices) x 12. `adulteq`: adult-equivalent scale from the aggregate. `hhsize`:
  household size from the aggregate (from the roster count of usual/regular members when the
  aggregate has none).
- `share_child` (age < 15), `share_elderly` (age >= 60), `head_age`, `head_female`: from the
  household roster, counting only usual or regular members, present or absent (not guests,
  not people who left or died). Check how sex is coded in each wave.
- `region`: region code from the household cover page. `urban`: "1" if the cover page's
  urban/rural value label is urban, else "0". `clusterid`: enumeration area code (2010-2015);
  district_subcounty_parish codes joined with "_" in 2018-2019. `hhweight`: the wave's
  household weight from the cover page (cross-sectional where one exists).

## Panel links (pids_UGA.csv)
`pid` should identify the same household across waves. Reconstruct the links from the
cover pages yourself (look for variables linking to earlier-wave ids), state the rule you
used, and compare. Report households linked differently and why.

## Report
Write `/home/claude/audit_uga/match_rates.csv` (wave, column, n, share matching within 1e-6
relative or exact for text) and `/home/claude/audit_uga/REPORT.md`: method, match rates, every
mismatch pattern with examples and your diagnosis of which side is wrong, and anything in the
declared definitions that looks like a mistake on its own (wrong item, wrong unit, a weight
that is not the right one, an id that does not link). Do not modify anything outside
`/home/claude/audit_uga/`.
