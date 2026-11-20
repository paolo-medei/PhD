"""Item -> product maps (track B products; track A built from them). Read from item value labels; validated on spending."""
TZA_FISH = [808, 809, 810, 8081, 8082, 8083, 8084]
MAPS = {
 'TZA': {'beef': [802], 'goat_sheep': [801], 'pork': [803], 'poultry': [804, 8041, 8042], 'eggs': [807], 'milk': [901],
         'milk_processed': [902], 'coffee': [1102], 'fish': TZA_FISH},
 'UGA': {'beef': [117, 1172, 1173], 'pork': [118, 1181, 1182], 'goat_sheep': [119, 1191, 1192, 1193],
         'poultry': [121, 1211, 1212, 1213, 1214, 1215], 'eggs': [124, 1241, 1242, 1243], 'milk': [125],
         'milk_processed': [1252, 1254], 'coffee': [148, 1481, 1482],
         'fish': [122, 123, 1221, 1222, 1231, 1232, 1234, 1235, 1236, 1237]},
 'MWI': {'beef': [504], 'goat_sheep': [505, 507], 'pork': [506], 'poultry': [508, 509], 'eggs': [501], 'milk': [701],
         'milk_processed': [702], 'coffee': [902],
         'fish': [502, 503, 513, 5021, 5022, 5023, 5031, 5032, 5033, 5121, 5122, 5123]},
 'NGA': {'beef': [90], 'goat_sheep': [91, 93], 'pork': [92], 'poultry': [80, 82], 'eggs': [83, 84], 'milk': [110],
         'milk_processed': [111, 113, 115, 114], 'coffee': [120], 'fish': [100, 101, 102, 103, 105, 106, 107]},
 'ETH': {'beef': [181, 702], 'goat_sheep': [180, 701], 'poultry': [182, 703], 'fish': [183, 704], 'milk': [19, 705],
         'cheese': [20, 706], 'eggs': [21, 709], 'coffee': [24, 801], 'meat_agg_old': [18]},
}
# ETH conversion-factor item for each survey item (waves 4-5 use the wave-3 numbering)
ETH_CFMAP = {701: 180, 702: 181, 703: 182, 704: 183, 705: 19, 706: 20, 709: 21, 801: 24}
MEATS = ['beef', 'goat_sheep', 'pork', 'poultry']
# track A products per country (meat_agg = sum of the meats)
TRACK_A = {'TZA': ['coffee', 'eggs', 'fish', 'meat_agg', 'milk'], 'UGA': ['coffee', 'eggs', 'fish', 'meat_agg', 'milk'],
           'MWI': ['coffee', 'eggs', 'fish', 'meat_agg', 'milk'], 'NGA': ['coffee', 'eggs', 'fish', 'meat_agg', 'milk', 'milk_processed'],
           'ETH': ['cheese', 'coffee', 'eggs', 'meat_agg', 'milk']}
