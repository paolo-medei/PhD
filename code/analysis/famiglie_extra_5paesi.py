"""Household-level extras for the descriptive analysis (descrittive_5paesi.R): official FOOD consumption and interview year.

USO  python3 famiglie_extra_5paesi.py <_allfood_wide_<data>.csv.gz> <official_food.csv> <uscita.csv>
  _allfood_wide: built by build_allfood_dataset.py (food_cons_hh_annual = official food aggregate, int_year)
  official_food.csv: built by official_food_aggregates.R (Nigeria: food per PERSON in the cons_agg files)
Output, one row per household x round:
  country, round, hhid, int_year, cibo_ufficiale_annuo, cibo_ufficiale_fonte
  Tanzania foodIN + foodOUT (nominal); Ethiopia food_cons_ann (nominal, food at home); Malawi rexp_cat011 (REAL, like
  the total rexpagg); Nigeria (food at home + away) per person x household size; Uganda: no official food aggregate.
The file contains household identifiers: keep it on the PC, never on GitHub.
"""
import sys
import numpy as np
import pandas as pd

WIDE, OFF, OUT = sys.argv[1:4]
W = pd.read_csv(WIDE, usecols=["country", "year", "hhid", "hhsize", "int_year", "food_cons_hh_annual"], dtype={"hhid": str})
O = pd.read_csv(OFF, dtype={"hhid": str})
W = W.merge(O[O.country == "NGA"][["country", "year", "hhid", "off_home", "off_away"]], on=["country", "year", "hhid"], how="left")
nga = W.country == "NGA"
W.loc[nga, "food_cons_hh_annual"] = (W.loc[nga, "off_home"] + W.loc[nga, "off_away"].fillna(0)) * W.loc[nga, "hhsize"]
FONTE = {"TZA": "foodIN + foodOUT (nominale)", "ETH": "food_cons_ann (nominale, cibo a casa)", "MWI": "rexp_cat011 (reale, come rexpagg)",
         "NGA": "(cibo a casa + fuori) per persona x ampiezza (nominale)", "UGA": "non disponibile"}
W["cibo_ufficiale_fonte"] = W.country.map(FONTE)
W = W.rename(columns={"year": "round", "food_cons_hh_annual": "cibo_ufficiale_annuo"})
W[["country", "round", "hhid", "int_year", "cibo_ufficiale_annuo", "cibo_ufficiale_fonte"]].to_csv(OUT, index=False)
print(W.groupby(["country", "round"]).agg(n=("hhid", "size"), cibo=("cibo_ufficiale_annuo", lambda x: x.notna().mean()),
                                          int_year=("int_year", lambda x: x.notna().mean())).round(2).to_string())
