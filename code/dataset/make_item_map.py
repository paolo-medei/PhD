"""Item map for the protein-rich household dataset (v1, 23 Nov 2026).

Every protein-rich food item of every round is mapped, by its ORIGINAL code and the
label that round gives it, to one harmonised item ("slot"), a category and a
subcategory. Rules are written per country; each rule carries a regular expression
that the round's own label must match, so a code whose meaning changes between
rounds (Ethiopia 201-206, Nigeria 44 and 114, Malawi 837) stops the build instead of
being mapped silently. Input: item_inventory.csv (codes and labels read from the
raw food modules). Output: item_map.csv.

Columns of item_map.csv
  country, year, code, label (verbatim), slot, cat, sub, std (standard unit of the
  harmonised quantity), in_total (1 = counted in its category total), cf_code
  (Ethiopia: code in the official conversion table), note
"""
import re, sys, pandas as pd

INV = sys.argv[1] if len(sys.argv) > 1 else 'item_inventory.csv'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'item_map.csv'
inv = pd.read_csv(INV)

# rule: (code, years or None, slot, cat, sub, std, in_total, label regex, note, cf_code)
R = {}
def add(cc, code, years, slot, cat, sub, std, tot, rx, note='', cf=None):
    R.setdefault(cc, []).append(dict(code=code, years=years, slot=slot, cat=cat, sub=sub, std=std,
                                     in_total=tot, rx=rx, note=note, cf_code=cf))

# ------------------------------------------------------------------ ETHIOPIA
E = 'ETH'; old = [2011, 2013, 2015]; new = [2018, 2021]
add(E, 18, [2011, 2013], 'meat_all', 'meat', 'mixed', 'kg', 1, r'^Meat$',
    'single meat item in 2011-2013; whether fish was reported here is not stated', 18)
add(E, 180, [2015], 'goat_mutton', 'meat', 'red', 'kg', 1, r'Goat & mutton', '', 180)
add(E, 701, new, 'goat_mutton', 'meat', 'red', 'kg', 1, r'Goat & mutton', '', 180)
add(E, 181, [2015], 'beef', 'meat', 'red', 'kg', 1, r'Beef', '', 181)
add(E, 702, new, 'beef', 'meat', 'red', 'kg', 1, r'Beef', '', 181)
add(E, 714, [2021], 'camel', 'meat', 'red', 'kg', 1, r'Camel meat', 'no conversion-table entry: metric units only')
add(E, 182, [2015], 'poultry', 'meat', 'white', 'kg', 1, r'Poultry', '', 182)
add(E, 703, new, 'poultry', 'meat', 'white', 'kg', 1, r'Poultry', '', 182)
add(E, 183, [2015], 'fish_unspecified', 'fish', 'unspecified', 'kg', 1, r'Fish', 'form (fresh, dried, canned) not asked', 183)
add(E, 704, new, 'fish_unspecified', 'fish', 'unspecified', 'kg', 1, r'Fish', 'form (fresh, dried, canned) not asked', 183)
add(E, 21, old, 'eggs', 'eggs', 'eggs', 'kg', 1, r'^Eggs$', 'official table converts numbers to kg', 21)
add(E, 709, new, 'eggs', 'eggs', 'eggs', 'kg', 1, r'Eggs', 'official table converts numbers to kg', 21)
add(E, 19, old, 'milk_fresh', 'dairy', 'milk_fresh', 'litre', 1, r'^Milk$', 'all milk; species not stated', 19)
add(E, 705, new, 'milk_fresh', 'dairy', 'milk_fresh', 'litre', 1, r'Milk', 'all milk; species not stated', 19)
add(E, 20, old, 'cheese', 'dairy', 'cheese', 'kg', 1, r'^Cheese$', 'traditional cottage cheese (ayib)', 20)
add(E, 706, new, 'cheese', 'dairy', 'cheese', 'kg', 1, r'Cheese', 'traditional cottage cheese (ayib)', 20)
add(E, 201, [2015], 'butter_ghee', 'dairy', 'butter_ghee', 'kg', 1, r'^Butter/ghee$', 'code 201 means horsebeans from 2018', 201)
add(E, 707, new, 'butter_ghee', 'dairy', 'butter_ghee', 'kg', 1, r'Butter/ghee', '', 201)
add(E, 7, old, 'horsebeans', 'plant', 'pulses', 'kg', 1, r'Horsebeans', '', 7)
add(E, 201, new, 'horsebeans', 'plant', 'pulses', 'kg', 1, r'Horsebeans', 'code 201 means butter/ghee in 2015', 7)
# codes 8 and 9: the 2011 and 2013 food modules label 8 Chick Pea and 9 Field Pea; the
# 2015 module and every conversion table (2011-2021) label 8 Field Pea and 9 Chick Pea
add(E, 8, [2011, 2013], 'eth_pea_code8', 'plant', 'pulses', 'kg', 1, r'^Chick Pea$',
    'LABEL CONFLICT: module says chick pea, conversion table says field pea; identity unresolved', 8)
add(E, 9, [2011, 2013], 'eth_pea_code9', 'plant', 'pulses', 'kg', 1, r'^Field Pea$',
    'LABEL CONFLICT: module says field pea, conversion table says chick pea; identity unresolved', 9)
add(E, 8, [2015], 'field_pea', 'plant', 'pulses', 'kg', 1, r'Field Pea', '', 8)
add(E, 9, [2015], 'chickpea', 'plant', 'pulses', 'kg', 1, r'Chick Pea', '', 9)
add(E, 202, new, 'chickpea', 'plant', 'pulses', 'kg', 1, r'Chick Pea', '', 9)
add(E, 203, new, 'field_pea', 'plant', 'pulses', 'kg', 1, r'Field Pea', '', 8)
add(E, 10, old, 'lentils', 'plant', 'pulses', 'kg', 1, r'Lentils', '', 10)
add(E, 204, new, 'lentils', 'plant', 'pulses', 'kg', 1, r'Lentils', '', 10)
add(E, 11, old, 'haricot_beans', 'plant', 'pulses', 'kg', 1, r'Haricot Beans', '', 11)
add(E, 205, new, 'haricot_beans', 'plant', 'pulses', 'kg', 1, r'Haricot Beans', '', 11)
add(E, 207, new, 'vetch', 'plant', 'pulses', 'kg', 1, r'Vetch', 'no conversion-table entry: metric units only')
add(E, 208, new, 'fenugreek', 'plant', 'pulses', 'kg', 1, r'Fenugreek', 'legume seed used mainly as spice; no conversion-table entry')
add(E, 209, new, 'mung_bean', 'plant', 'pulses', 'kg', 1, r'mung bean', 'no conversion-table entry: metric units only')
add(E, 210, new, 'shiro_processed_pulses', 'plant', 'pulses_processed', 'kg', 1, r'Shiro', 'pulse flour; no conversion-table entry')
add(E, 110, [2015], 'groundnuts', 'plant', 'groundnuts', 'kg', 1, r'Ground nuts', 'not asked in 2011-2013', 110)
add(E, 206, new, 'groundnuts', 'plant', 'groundnuts', 'kg', 1, r'Ground nuts', '', 110)
add(E, 111, [2015], 'pulse_or_nut_other', 'plant', 'pulse_nut_other', 'kg', 1, r'Other pulse or nut', '', 111)
add(E, 211, new, 'pulse_or_nut_other', 'plant', 'pulse_nut_other', 'kg', 1, r'Other pulse or nut', '', 111)
add(E, 12, old, 'niger_seed', 'plant', 'seeds', 'kg', 1, r'Niger Seed', '', 12)
add(E, 301, new, 'niger_seed', 'plant', 'seeds', 'kg', 1, r'Niger Seed', '', 12)
add(E, 13, old, 'linseed', 'plant', 'seeds', 'kg', 1, r'Linseed', '', 13)
add(E, 302, new, 'linseed', 'plant', 'seeds', 'kg', 1, r'Linseed', '', 13)
add(E, 303, new, 'sesame', 'plant', 'seeds', 'kg', 1, r'(?i)sesame|seasame', 'no conversion-table entry: metric units only')
add(E, 304, new, 'sunflower_seed', 'plant', 'seeds', 'kg', 1, r'Sun Flower', 'no conversion-table entry: metric units only')
add(E, 131, [2015], 'seed_other', 'plant', 'seeds', 'kg', 1, r'Other seed', '', 131)
add(E, 305, new, 'seed_other', 'plant', 'seeds', 'kg', 1, r'Other seed', '', 131)

# ------------------------------------------------------------------ TANZANIA
T = 'TZA'; allT = [2008, 2010, 2012, 2014, 2020, 2020.1]; ja = [2020]
add(T, 801, allT, 'goat', 'meat', 'red', 'kg', 1, r'(?i)goat meat')
add(T, 802, allT, 'beef', 'meat', 'red', 'kg', 1, r'(?i)beef.*minced sausage', 'includes minced meat and sausages')
add(T, 803, allT, 'pork', 'meat', 'red', 'kg', 1, r'(?i)pork.*(sausages|sauages)', 'includes sausages and bacon')
add(T, 804, [2008, 2010, 2012, 2014, 2020.1], 'poultry', 'meat', 'white', 'kg', 1, r'(?i)chicken and other poultry')
add(T, 8041, ja, 'chicken', 'meat', 'white', 'kg', 1, r'(?i)^chicken$', '2020 main sample splits poultry')
add(T, 8042, ja, 'poultry_other', 'meat', 'white', 'kg', 1, r'(?i)other poultry')
add(T, 805, allT, 'wild_birds_insects', 'meat', 'minor', 'kg', 1, r'(?i)wild birds and insects')
add(T, 806, allT, 'meat_other_domestic_wild', 'meat', 'minor', 'kg', 1, r'(?i)other domestic/wild meat')
add(T, 807, allT, 'eggs', 'eggs', 'eggs', 'piece', 1, r'(?i)^eggs$', 'grams converted at 55 g per egg (2020 survey calibration)')
add(T, 808, [2008, 2010, 2012, 2014, 2020.1], 'fish_fresh_seafood', 'fish', 'fresh', 'kg', 1, r'(?i)fresh fish and seafood', 'includes dagaa')
add(T, 8081, ja, 'dagaa_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)dagaa \(fresh\)')
add(T, 8082, ja, 'kolekole_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)kolekole')
add(T, 8083, ja, 'tilapia_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)tilapia')
add(T, 8084, ja, 'fish_other_fresh_seafood', 'fish', 'fresh', 'kg', 1, r'(?i)other fresh fish')
add(T, 809, allT, 'fish_dried_salted_canned', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)dried/salted/canned',
    'label includes canned fish, which overlaps item 810')
add(T, 810, allT, 'fish_packaged_canned', 'fish', 'canned_packaged', 'kg', 1, r'(?i)package(d)? ?(/canned)? fish')
add(T, 901, allT, 'milk_fresh', 'dairy', 'milk_fresh', 'litre', 1, r'(?i)fresh milk')
add(T, 902, allT, 'milk_products_cream_cheese_yoghurt', 'dairy', 'milk_products', 'litre', 1, r'(?i)milk products')
add(T, 903, allT, 'milk_canned_powder', 'dairy', 'milk_powder_tinned', 'kg', 1, r'(?i)canned milk/milk powder', 'litres counted as kg')
add(T, 1002, allT, 'butter_margarine_ghee', 'dairy', 'fats_mixed', 'kg', 0, r'(?i)butter, margarine, ghee',
    'mixes dairy butter and ghee with margarine: kept, not counted in dairy')
add(T, 401, [2008, 2010, 2012, 2014, 2020.1], 'pulses_all', 'plant', 'pulses', 'kg', 1, r'(?i)peas, beans, lentils')
add(T, 4011, ja, 'peas', 'plant', 'pulses', 'kg', 1, r'(?i)^peas$', 'fresh or dry not stated')
add(T, 4012, ja, 'green_beans', 'plant', 'pulses_fresh', 'kg', 1, r'(?i)green beans', 'fresh beans or pods: not stated')
add(T, 4013, ja, 'beans_lentils_pulses_other', 'plant', 'pulses', 'kg', 1, r'(?i)other beans, lentils')
add(T, 501, allT, 'groundnuts', 'plant', 'groundnuts', 'kg', 1, r'(?i)groundnuts in shell/shelled')
add(T, 502, allT, 'coconut', 'plant', 'nuts_low_protein', 'piece', 0, r'(?i)coconuts', 'low in protein: kept, not counted in plant-protein total')
add(T, 503, allT, 'cashew_almonds_nuts', 'plant', 'nuts', 'kg', 1, r'(?i)cashew, almonds')
add(T, 504, allT, 'seeds_and_nut_products', 'plant', 'seeds', 'kg', 1, r'(?i)seeds and products from nuts')

# ------------------------------------------------------------------ MALAWI
M = 'MWI'; allM = [2010, 2016, 2019, 2024]; s16 = [2016, 2019, 2024]
add(M, 504, allM, 'beef', 'meat', 'red', 'kg', 1, r'^Beef$', 'pieces not converted (official factor 0.036-0.25 kg)')
add(M, 505, allM, 'goat', 'meat', 'red', 'kg', 1, r'^Goat$', 'pieces not converted')
add(M, 507, allM, 'mutton', 'meat', 'red', 'kg', 1, r'^Mutton$', 'pieces not converted')
add(M, 506, allM, 'pork', 'meat', 'red', 'kg', 1, r'^Pork$', 'pieces not converted')
add(M, 508, [2010], 'chicken', 'meat', 'white', 'kg', 1, r'^Chicken$', '2010: whole and pieces together')
add(M, 508, s16, 'chicken_whole', 'meat', 'white', 'kg', 1, r'^Chicken( - Whole)?$', '2016 label is "Chicken", with pieces separate in 522')
add(M, 522, s16, 'chicken_pieces', 'meat', 'white', 'kg', 1, r'Chicken ?(/|-) ?Pieces', '')
add(M, 509, allM, 'poultry_other', 'meat', 'white', 'kg', 1, r'Other poultry', 'pieces not converted')
add(M, 510, allM, 'small_animals', 'meat', 'minor', 'kg', 1, r'Small animal', 'rabbit, mice')
add(M, 511, allM, 'insects', 'meat', 'minor', 'kg', 1, r'Termites', '')
add(M, 516, [2024], 'offal', 'meat', 'minor', 'kg', 1, r'Offal', '')
add(M, 517, [2024], 'sausage_minced_meatballs', 'meat', 'processed', 'kg', 1, r'Sausage', '')
add(M, 512, allM, 'meat_or_fish_tinned', 'asf_mixed', 'meat_or_fish_tinned', 'kg', 1, r'Tinned meat or fish',
    'meat and fish together: counted in the animal-source total only')
add(M, 515, allM, 'meat_fish_other_specify', 'asf_mixed', 'other_specify', 'kg', 1, r'Other \(specify\)',
    '"other" of the meat, fish and animal products group: counted in the animal-source total only')
add(M, 501, allM, 'eggs', 'eggs', 'eggs', 'piece', 1, r'^Eggs$', '')
add(M, 502, [2010], 'fish_dried', 'fish', 'dried_smoked_salted', 'kg', 1, r'^Dried fish$', 'heaps and pieces not converted')
add(M, 503, [2010], 'fish_fresh', 'fish', 'fresh', 'kg', 1, r'^Fresh fish$', 'heaps and pieces not converted')
add(M, 513, [2010], 'fish_smoked', 'fish', 'dried_smoked_salted', 'kg', 1, r'^Smoked fish$', 'heaps and pieces not converted')
for c, nm, sz in [(5021, 'sundried', 'Large'), (5022, 'sundried', 'Medium'), (5023, 'sundried', 'Small'),
                  (5031, 'fresh', 'Large'), (5032, 'fresh', 'Medium'), (5033, 'fresh', 'Small'),
                  (5121, 'smoked', 'Large'), (5122, 'smoked', 'Medium'), (5123, 'smoked', 'Small')]:
    sub = 'fresh' if nm == 'fresh' else 'dried_smoked_salted'
    rx = {'sundried': r'Sun Dried fish', 'fresh': r'Fresh fish', 'smoked': r'Smoked fish'}[nm] + r' \(' + sz
    add(M, c, s16, f'fish_{nm}_{sz.lower()}', 'fish', sub, 'kg', 1, rx, 'size of the variety; heaps and pieces not converted')
add(M, 514, allM, 'fish_soup_sauce', 'fish', 'fish_product', 'kg', 1, r'Fish Soup', '')
add(M, 701, allM, 'milk_fresh', 'dairy', 'milk_fresh', 'litre', 1, r'Fresh milk', '')
add(M, 702, allM, 'milk_powder', 'dairy', 'milk_powder_tinned', 'kg', 1, r'Powdered milk', '')
add(M, 704, allM, 'butter', 'dairy', 'butter_ghee', 'kg', 1, r'^Butter$', '')
add(M, 705, allM, 'milk_soured_fermented', 'dairy', 'yoghurt_fermented', 'litre', 1, r'Chambiko', 'chambiko (soured milk)')
add(M, 706, allM, 'yoghurt', 'dairy', 'yoghurt_fermented', 'litre', 1, r'Yoghurt', '')
add(M, 707, allM, 'cheese', 'dairy', 'cheese', 'kg', 1, r'Cheese', '')
add(M, 708, allM, 'infant_formula', 'dairy', 'infant_formula', 'kg', 0, r'Infant feeding formula', 'kept, not counted in dairy')
add(M, 709, allM, 'dairy_other_specify', 'dairy', 'milk_products', 'kg', 1, r'Other \(specify\)', '"other" of the milk group')
add(M, 301, allM, 'beans_white', 'plant', 'pulses', 'kg', 1, r'Bean, white', '')
add(M, 302, allM, 'beans_brown', 'plant', 'pulses', 'kg', 1, r'Bean, brown', '')
add(M, 323, [2024], 'beans_mixed', 'plant', 'pulses', 'kg', 1, r'Bean, mixed', '')
add(M, 303, allM, 'pigeonpea', 'plant', 'pulses', 'kg', 1, r'(?i)pigeon ?pea', '')
add(M, 307, allM, 'ground_bean_nzama', 'plant', 'pulses', 'kg', 1, r'Ground bean', 'Bambara groundnut')
add(M, 308, allM, 'cowpea', 'plant', 'pulses', 'kg', 1, r'Cowpea', '')
add(M, 306, allM, 'soybean_flour', 'plant', 'soy', 'kg', 1, r'Soyabean flour', '')
add(M, 315, [2024], 'soya_pieces', 'plant', 'soy', 'kg', 1, r'Soya Pieces', '')
add(M, 304, [2010], 'groundnuts', 'plant', 'groundnuts', 'kg', 1, r'^Groundnut$', '2010: one item for all groundnuts')
add(M, 311, s16, 'groundnuts_shelled', 'plant', 'groundnuts', 'kg', 1, r'(?i)groundnut \(shelled\)', '')
add(M, 312, s16, 'groundnuts_dried_unshelled', 'plant', 'groundnuts', 'kg', 1, r'(?i)groundnut (dried )?\(unshelled\)', '')
add(M, 313, s16, 'groundnuts_fresh_unshelled', 'plant', 'groundnuts', 'kg', 1, r'(?i)groundnut fresh', '')
add(M, 305, allM, 'groundnut_flour', 'plant', 'groundnuts', 'kg', 1, r'Groundnut flour', '')
add(M, 309, allM, 'macadamia', 'plant', 'nuts', 'kg', 1, r'Macademia', '')
add(M, 310, allM, 'pulses_nuts_other_specify', 'plant', 'pulse_nut_other', 'kg', 1, r'Other \(specify\)', '"other" of the nuts and pulses group')
add(M, 837, [2019, 2024], 'mucuna_kalongonda', 'plant', 'pulses', 'kg', 1, r'KALONGONDA', 'code 837 is "other (specify)" in 2016: not mapped there')
add(M, 823, allM, 'eggs_boiled_vendor', 'eggs', 'prepared_vendor', 'piece', 0, r'Eggs - boiled', 'cooked food from vendors: own subtotal')
add(M, 824, allM, 'chicken_vendor', 'meat', 'prepared_vendor', 'kg', 0, r'Chicken \(vendor\)', 'cooked food from vendors: own subtotal')
add(M, 825, allM, 'meat_vendor', 'meat', 'prepared_vendor', 'kg', 0, r'Meat \(vendor\)', 'cooked food from vendors: own subtotal')
add(M, 826, allM, 'fish_vendor', 'fish', 'prepared_vendor', 'kg', 0, r'Fish \(vendor\)', 'cooked food from vendors: own subtotal')
add(M, 833, s16, 'groundnuts_boiled_vendor', 'plant', 'prepared_vendor', 'kg', 0, r'Boiled groundnuts', 'cooked food from vendors: own subtotal')
add(M, 834, s16, 'groundnuts_roasted_vendor', 'plant', 'prepared_vendor', 'kg', 0, r'R(oa|o)sted groundnuts', 'cooked food from vendors: own subtotal')

# ------------------------------------------------------------------ NIGERIA
N = 'NGA'; allN = [2010, 2012, 2015]; n12 = [2012, 2015]
add(N, 90, allN, 'beef', 'meat', 'red', 'kg', 1, r'(?i)meat: beef')
add(N, 91, allN, 'mutton', 'meat', 'red', 'kg', 1, r'(?i)meat: mutton')
add(N, 93, allN, 'goat', 'meat', 'red', 'kg', 1, r'(?i)meat: goat')
add(N, 92, allN, 'pork', 'meat', 'red', 'kg', 1, r'(?i)meat: pork')
add(N, 94, allN, 'game_bush_meat', 'meat', 'minor', 'kg', 1, r'(?i)wild game')
add(N, 96, allN, 'meat_other_excl_poultry', 'meat', 'minor', 'kg', 1, r'(?i)other meat \(excl\. poultry\)')
add(N, 95, allN, 'corned_beef_canned', 'meat', 'processed', 'kg', 1, r'(?i)canned beef/corned beef')
add(N, 80, allN, 'chicken', 'meat', 'white', 'kg', 1, r'(?i)poultry products: chicke?n?')
add(N, 81, allN, 'duck', 'meat', 'white', 'kg', 1, r'(?i)poultry products: duck')
add(N, 82, allN, 'poultry_other', 'meat', 'white', 'kg', 1, r'(?i)poultry products: other dome')
add(N, 104, allN, 'snails', 'meat', 'minor', 'kg', 1, r'(?i)snails', 'listed under fish and seafood in the questionnaire; land snails counted as minor meat')
add(N, 83, allN, 'eggs_farm', 'eggs', 'eggs', 'kg', 1, r'(?i)poultry products: agricu', '"agricultural" (farm) eggs')
add(N, 84, allN, 'eggs_local', 'eggs', 'eggs', 'kg', 1, r'(?i)poultry products: local')
add(N, 85, allN, 'eggs_other', 'eggs', 'eggs', 'kg', 1, r'(?i)poultry products: other e')
add(N, 100, allN, 'fish_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)fish-fresh')
add(N, 101, allN, 'fish_frozen', 'fish', 'fresh', 'kg', 1, r'(?i)fish-frozen', 'frozen fish counted with fresh')
add(N, 102, allN, 'fish_smoked', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)fish-smoked')
add(N, 103, allN, 'fish_dried', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)fish-dried')
add(N, 105, allN, 'seafood_crustaceans', 'fish', 'fresh', 'kg', 1, r'(?i)seafood \(lobster')
add(N, 106, allN, 'fish_canned', 'fish', 'canned_packaged', 'kg', 1, r'(?i)canned fish')
add(N, 107, allN, 'fish_other', 'fish', 'unspecified', 'kg', 1, r'(?i)other fish or seafood')
add(N, 110, allN, 'milk_fresh', 'dairy', 'milk_fresh', 'litre', 1, r'(?i)fresh milk')
add(N, 111, allN, 'milk_powder', 'dairy', 'milk_powder_tinned', 'kg', 1, r'(?i): milk powder')
add(N, 113, allN, 'milk_tinned', 'dairy', 'milk_powder_tinned', 'kg', 1, r'(?i)milk tinned')
add(N, 112, allN, 'infant_formula', 'dairy', 'infant_formula', 'kg', 0, r'(?i)baby milk', 'kept, not counted in dairy')
add(N, 114, [2010], 'dairy_other', 'dairy', 'milk_products', 'kg', 1, r'(?i)other milk produ', '2010 code 114 = other milk products; from 2012 = cheese')
add(N, 114, n12, 'cheese_wara', 'dairy', 'cheese', 'kg', 1, r'(?i)cheese \(wara\)', '')
add(N, 115, n12, 'dairy_other', 'dairy', 'milk_products', 'kg', 1, r'(?i)other milk products', '')
add(N, 51, allN, 'butter_margarine', 'dairy', 'fats_mixed', 'kg', 0, r'(?i)butter/margarine', 'mixes butter with margarine: kept, not counted in dairy')
add(N, 40, allN, 'soybeans', 'plant', 'soy', 'kg', 1, r'(?i)soya beans')
add(N, 41, allN, 'beans_brown', 'plant', 'pulses', 'kg', 1, r'(?i)brown beans')
add(N, 42, allN, 'beans_white', 'plant', 'pulses', 'kg', 1, r'(?i)white beans')
add(N, 43, [2010], 'groundnuts', 'plant', 'groundnuts', 'kg', 1, r'(?i)seeds:groundnuts$', '2010: one item for all groundnuts')
add(N, 43, n12, 'groundnuts_unshelled', 'plant', 'groundnuts', 'kg', 1, r'(?i)groundnuts \(unshe')
add(N, 44, [2010], 'nuts_seeds_other', 'plant', 'pulse_nut_other', 'kg', 1, r'(?i)other nuts/seeds', '2010 code 44 = other nuts/seeds; from 2012 = shelled groundnuts')
add(N, 44, n12, 'groundnuts_shelled', 'plant', 'groundnuts', 'kg', 1, r'(?i)groundnuts \(s')
add(N, 45, n12, 'nuts_seeds_other', 'plant', 'pulse_nut_other', 'kg', 1, r'(?i)other nuts/se')
add(N, 46, [2015], 'coconut', 'plant', 'nuts_low_protein', 'kg', 0, r'(?i)coconut', 'low in protein: kept, not counted')
add(N, 47, [2015], 'kola_nut', 'plant', 'nuts_low_protein', 'kg', 0, r'(?i)kola', 'stimulant, low in protein: kept, not counted')
add(N, 48, [2015], 'cashew', 'plant', 'nuts', 'kg', 1, r'(?i)cashew')
add(N, 145, n12, 'melon_seed_shelled', 'plant', 'seeds', 'kg', 1, r'(?i)melon \(shelled\)', 'egusi')
add(N, 146, n12, 'melon_seed_unshelled', 'plant', 'seeds', 'kg', 1, r'(?i)melon \(unshelled\)', 'egusi')
add(N, 147, [2015], 'melon_seed_ground', 'plant', 'seeds', 'kg', 1, r'(?i)melon \(ground\)', 'egusi')
add(N, 142, n12, 'ogbono_unground', 'plant', 'seeds', 'kg', 1, r'(?i)ogbonno (un)?grinded|unground ogbonno', 'bush-mango kernel, soup thickener')
add(N, 143, n12, 'ogbono_ground', 'plant', 'seeds', 'kg', 1, r'(?i)ogbonno grinded|ground ogbonno', 'bush-mango kernel, soup thickener')

# ------------------------------------------------------------------ UGANDA
U = 'UGA'; o = [2010, 2011, 2013, 2015]; nU = [2018, 2019]; allU = o + nU
add(U, 117, allU, 'beef', 'meat', 'red', 'kg', 1, r'(?i)beef')
add(U, 118, o, 'pork', 'meat', 'red', 'kg', 1, r'(?i)pork', 'code 118 has no consumption in 2018-19 (replaced by 1181)')
add(U, 1181, nU, 'pork', 'meat', 'red', 'kg', 1, r'(?i)^pork$')
add(U, 119, allU, 'goat', 'meat', 'red', 'kg', 1, r'(?i)goat meat')
add(U, 120, allU, 'meat_other', 'meat', 'minor', 'kg', 1, r'(?i)other meat', 'e.g. duck, rabbit')
add(U, 1174, nU, 'sausages', 'meat', 'processed', 'kg', 1, r'(?i)sausages')
add(U, 121, o, 'chicken', 'meat', 'white', 'kg', 1, r'(?i)chicken', 'whole birds and pieces at 1.3 kg per bird (FAO)')
for c, nm in [(1211, 'off-layer'), (1212, 'broiler'), (1213, 'kroiler'), (1214, 'local')]:
    add(U, c, nU, 'chicken_' + nm.replace('-', '_'), 'meat', 'white', 'kg', 1, r'(?i)' + nm.replace('-', '.?'),
        'whole birds and pieces at 1.3 kg per bird (FAO)')
add(U, 122, o, 'fish_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)fresh fish', 'whole fish, heaps: mostly not converted')
add(U, 123, o, 'fish_dried_smoked', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)dry/smocked', 'whole fish, heaps: mostly not converted')
add(U, 1221, nU, 'tilapia_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)fresh tilapia')
add(U, 1222, nU, 'nile_perch_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)fresh nile perch')
add(U, 1235, nU, 'fish_other_fresh', 'fish', 'fresh', 'kg', 1, r'(?i)other fresh fish')
add(U, 1231, nU, 'tilapia_dried_smoked', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)dry/ ?smoked tilapia')
add(U, 1232, nU, 'nile_perch_dried_smoked', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)dry/smoked nile perch')
add(U, 1234, nU, 'nkejje_dried', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)dried nkejje')
add(U, 1236, nU, 'fish_other_dried_smoked', 'fish', 'dried_smoked_salted', 'kg', 1, r'(?i)other dry/smoked fish')
add(U, 1237, nU, 'silverfish_mukene', 'fish', 'unspecified', 'kg', 1, r'(?i)silver fish', 'form not stated (usually sun-dried)')
add(U, 124, allU, 'eggs', 'eggs', 'eggs', 'piece', 1, r'(?i)eggs')
add(U, 125, allU, 'milk_fresh', 'dairy', 'milk_fresh', 'litre', 1, r'(?i)fresh milk')
add(U, 1251, nU, 'milk_powder', 'dairy', 'milk_powder_tinned', 'kg', 1, r'(?i)milk powdered')
add(U, 1252, nU, 'milk_soured_fermented', 'dairy', 'yoghurt_fermented', 'litre', 1, r'(?i)fermented milk', 'bongo')
add(U, 1254, nU, 'yoghurt', 'dairy', 'yoghurt_fermented', 'litre', 1, r'(?i)yoghurt')
add(U, 1253, nU, 'ice_cream', 'dairy', 'ice_cream', 'kg', 1, r'(?i)ice-?cream')
add(U, 1281, nU, 'cheese', 'dairy', 'cheese', 'kg', 1, r'(?i)cheese')
add(U, 128, allU, 'ghee', 'dairy', 'butter_ghee', 'kg', 1, r'(?i)ghee')
add(U, 129, o, 'margarine_butter', 'dairy', 'fats_mixed', 'kg', 0, r'(?i)margarine, butter', 'mixes butter with margarine: kept, not counted in dairy')
add(U, 126, allU, 'infant_formula', 'dairy', 'infant_formula', 'kg', 0, r'(?i)infant formula', 'kept, not counted in dairy')
add(U, 140, allU, 'beans_fresh', 'plant', 'pulses_fresh', 'kg', 1, r'(?i)bean.*fresh')
add(U, 141, allU, 'beans_dry', 'plant', 'pulses', 'kg', 1, r'(?i)beans \(dry\)')
add(U, 145, allU, 'peas_fresh', 'plant', 'pulses_fresh', 'kg', 1, r'(?i)peas.*fresh')
add(U, 162, allU, 'peas_dry', 'plant', 'pulses', 'kg', 1, r'(?i)peas.*dry')
add(U, 1761, nU, 'soybeans_fresh', 'plant', 'soy', 'kg', 1, r'(?i)soya beans \(fresh\)')
add(U, 1762, nU, 'soybeans_dry', 'plant', 'soy', 'kg', 1, r'(?i)soya beans \(dry\)')
add(U, 142, allU, 'groundnuts_in_shell', 'plant', 'groundnuts', 'kg', 1, r'(?i)ground nuts \(in shell\)')
add(U, 143, allU, 'groundnuts_shelled', 'plant', 'groundnuts', 'kg', 1, r'(?i)ground nut seeds \(unshelled\)|ground nuts \(shelled\)',
    'LABEL CHANGE: 2010-15 "ground nut seeds (unshelled)", 2018-19 "ground nuts (shelled)"')
add(U, 144, allU, 'groundnuts_pounded', 'plant', 'groundnuts', 'kg', 1, r'(?i)pounded')
add(U, 163, allU, 'groundnut_paste', 'plant', 'groundnuts', 'kg', 1, r'(?i)paste')
add(U, 146, o, 'simsim', 'plant', 'seeds', 'kg', 1, r'(?i)simsim', 'sesame; replaced by 1461 in 2018-19')
add(U, 1461, nU, 'simsim', 'plant', 'seeds', 'kg', 1, r'(?i)^simsim$', 'sesame')
add(U, 1462, nU, 'simsim_paste', 'plant', 'seeds', 'kg', 1, r'(?i)simsim paste', 'sesame paste')

# ------------------------------------------------------------------ build and verify
rows, problems = [], []
for cc, rules in R.items():
    x = inv[inv.country == cc]
    for r in rules:
        yrs = r['years']
        for y in yrs:
            hit = x[(x.year == y) & (x.code == r['code'])]
            if hit.empty:
                problems.append(f'{cc} {y} code {r["code"]} ({r["slot"]}): not in the food module'); continue
            lab = str(hit.label.iloc[0]).strip()
            if not re.search(r['rx'], lab):
                problems.append(f'{cc} {y} code {r["code"]} ({r["slot"]}): label "{lab}" does not match /{r["rx"]}/'); continue
            rows.append(dict(country=cc, year=y, code=r['code'], label=lab, slot=r['slot'], cat=r['cat'], sub=r['sub'],
                             std=r['std'], in_total=r['in_total'], cf_code=r['cf_code'], note=r['note'],
                             rows_in_module=int(hit.rows.sum())))
m = pd.DataFrame(rows)
# one slot per original code within a round, and one original code per slot within a round
d1 = m.groupby(['country', 'year', 'code']).slot.nunique(); d2 = m.groupby(['country', 'year', 'slot']).code.nunique()
for k, v in d1[d1 > 1].items(): problems.append(f'{k}: code mapped to {v} slots')
for k, v in d2[d2 > 1].items(): problems.append(f'{k}: slot receives {v} codes')
# same slot must keep the same unit and category everywhere
for col in ['cat', 'sub', 'in_total']:
    g = m.groupby('slot')[col].nunique()
    for k in g[g > 1].index: problems.append(f'slot {k}: more than one {col}')
g = m.groupby(['country', 'slot'])['std'].nunique()          # the unit may differ between countries
for k in g[g > 1].index: problems.append(f'{k}: more than one unit')
m.to_csv(OUT, index=False)
print(f'{len(m)} item-round rows, {m.slot.nunique()} slots, {len(problems)} problems')
for p in problems: print('  PROBLEM', p)
