###############################################################################
##  TWO-STAGE LA/AIDS FOR TANZANIA (NPS 2008, 2010, 2012, 2014, 2020)
##  From the harmonised raw data to conditional and unconditional elasticities
##  Teaching script: run it one section at a time (select the lines in RStudio and press Ctrl+Enter).
##
##  THE IDEA: TWO-STAGE BUDGETING
##  The household is assumed to decide in two steps.
##    Stage 1: it splits its FOOD budget (x_food) among 4 broad groups
##             staples | proteins | fruits and vegetables | other foods
##    Stage 2: it splits its PROTEIN budget (x_prot) among 9 protein categories
##             beef | pork | sheep, goat and other meat | poultry | fish | fluid milk |
##             other dairy | eggs | plant proteins
##  Why two separate steps are allowed: WEAK SEPARABILITY. We assume that the way the household divides
##  its protein budget depends only on (a) the size of the protein budget and (b) the prices of the protein
##  categories. The price of maize or of tomatoes can change the protein budget (stage 1), but it does not
##  change, by itself, the split between beef and fish (stage 2).
##  Weak separability is an ASSUMPTION of the model: this script does NOT test it.
##
##  DATA: TZA_dati_grezzi_LAAIDS_<date>.xlsx
##    sheet "dati": ONE ROW PER HOUSEHOLD x round; for every food item, the quantities, units and spending
##                  are in columns c<item code>_<variable> (e.g. c802_spesa_acq = spending on beef purchases)
##    sheet "voci": item code -> item name ("voce"), food category ("categoria"), old 12-group code ("gruppo")
##
##  METHOD, STEP BY STEP (every step is explained again in its section)
##   - prices: unit values of purchases (spending / quantity), local medians EA -> district -> region -> country
##   - own production and gifts: quantity x local median price of the same item and unit
##   - food budget = purchases + own production + gifts (food consumed at home, last 7 days)
##   - price of a group: weighted geometric mean of the local prices of the items in the group
##   - Stone price index with the MEAN sample shares (Moschini 1995); real expenditure = expenditure / index
##   - LA/AIDS estimated SEPARATELY in each stage, each time with:
##       zero consumption: two-step procedure of Shonkwiler and Yen (1999)
##       endogenous expenditure: control function (the instruments of each stage are explained in section 9)
##       SUR with homogeneity and symmetry imposed; adding-up through the omitted (residual) equation
##   - elasticities at the sample means: stage 1, stage 2 (conditional), unconditional (Edgerton 1997)
##   - standard errors: cluster bootstrap (resample the sampling clusters and redo the whole estimation)
##
##  ITALIAN WORDS USED IN THE NAMES (the dataset is in Italian, and the names are kept as in the dataset)
##    voci = food items          famiglie = households       dati = household data (one row per household)
##    spesa = expenditure        quota = share               prezzo = price          valore = value
##    acq = purchases            auto = own production       regali = gifts          stima = estimation sample
##    ampiezza = household size  rurale = rural (1/0)        capo_donna = female head (1/0)
##    livello = geographic level of a price                  stadio1 / stadio2 = stage 1 / stage 2
##    cella = "price cell": the group (stage 1) or category (stage 2) of an item, used to build prices
##
##  PACKAGES: install.packages(c("readxl", "dplyr", "tidyr", "systemfit", "openxlsx"))
##
##  REFERENCES
##   Deaton, A. & Muellbauer, J. (1980). An Almost Ideal Demand System. American Economic Review 70(3): 312-326.
##   Shonkwiler, J.S. & Yen, S.T. (1999). Two-step estimation of a censored system of equations.
##       American Journal of Agricultural Economics 81(4): 972-982.
##   Moschini, G. (1995). Units of measurement and the Stone index in demand system estimation. AJAE 77(1): 63-68.
##   Rivers, D. & Vuong, Q. (1988). Limited information estimators and exogeneity tests for simultaneous
##       probit models. Journal of Econometrics 39(3): 347-366.
##   Edgerton, D.L. (1997). Weak separability and the estimation of elasticities in multistage demand systems.
##       AJAE 79(1): 62-79.
##   Carpentier, A. & Guyomard, H. (2001). Unconditional elasticities in two-stage demand systems:
##       an approximate solution. AJAE 83(1): 222-229.
##   Ecker, O. & Qaim, M. (2011). Analyzing nutritional impacts of policies: an empirical study for Malawi.
##       World Development 39(3): 412-428.  (LSMS data, AIDS-type system with the Shonkwiler-Yen correction)
###############################################################################


## =============================================================================
## 0. SETTINGS
## =============================================================================
library(readxl)
library(dplyr)
library(tidyr)
library(systemfit)
library(openxlsx)

FILE   <- "C:/Users/Medei/Desktop/PhD_v21/data/OUTPUT/analisi_TZA/TZA_dati_grezzi_LAAIDS_2026-11-24.xlsx"
USCITA <- file.path(dirname(FILE), paste0("risultati_LAAIDS_2stadi_TZA_", Sys.Date()))   # new folder: the input data are never touched
dir.create(USCITA, showWarnings = FALSE)

N_MIN  <- 5     # minimum number of purchases needed to compute a local median price
SOGLIA <- 10    # outlier price: more than 10 times, or less than 1/10 of, the national median of the same item and unit
B      <- 200   # bootstrap replications (section 11); for a quick test use 20
SEME   <- 2026  # random seed: with the same seed the bootstrap always gives the same numbers

# 0.1 FROM ITEMS TO THE TWO STAGES
# Every item of the dictionary (sheet "voci") has a "categoria". The table below says, for each categoria,
# its stage-1 group (stadio1) and, for proteins only, its stage-2 category (stadio2). NA = not a protein.
# Decisions taken on the item dictionary (all items of the 5 rounds are covered; nothing is left out):
#  - sheep_goat_other_meat: 801 goat meat + 806 "other domestic/wild meat products". There is no separate
#    sheep item in any round. 806 alone is too small for its own category (121 households in 5 rounds,
#    only 4 purchases in 2020: no national price can be computed in 2020), so it is merged with goat.
#  - fish: fresh fish (808, 8081-8084) + dried, salted, canned and packaged fish (809, 810).
#  - fluid_milk: 901 fresh milk only.
#  - other_dairy: 902 cream, cheese, yoghurt + 903 canned milk / milk powder (preserved milk, not fluid milk).
#  - plant_protein: pulses (401, 4011, 4013), green beans (4012, 2020 only: before 2020 they were inside item
#    401, so they stay here for comparability across rounds), groundnuts (501), nuts (503), seeds (504).
#  - staples = cereals + starches (cassava, potatoes, plantains, cooking bananas ...).
#  - fruits_veg = fruits (coconut included) + vegetables.
#  - other = oils and fats, sugar and sweets, spices and salt, beverages.
#  (Already excluded when the dataset was built: food eaten away from home, khat, kola nut,
#   "butter, margarine, ghee" and "wild birds and insects".)
MAPPA <- read.table(header = TRUE, stringsAsFactors = FALSE, text = "
categoria        stadio1      stadio2
cereals          staples      NA
starches         staples      NA
beef             proteins     beef
pork             proteins     pork
goat_sheep       proteins     sheep_goat_other_meat
meat_other       proteins     sheep_goat_other_meat
poultry          proteins     poultry
fish_fresh       proteins     fish
fish_processed   proteins     fish
milk_fresh       proteins     fluid_milk
dairy_processed  proteins     other_dairy
eggs             proteins     eggs
pulses_dry       proteins     plant_protein
pulses_fresh     proteins     plant_protein
groundnuts       proteins     plant_protein
nuts             proteins     plant_protein
seeds            proteins     plant_protein
fruits           fruits_veg   NA
vegetables       fruits_veg   NA
oils_fats        other        NA
sugar_sweets     other        NA
spices_other     other        NA
beverages        other        NA
")

# 0.2 The groups of each stage. THE LAST ONE OF EACH LIST IS THE RESIDUAL: its equation is not estimated,
#     it is obtained from adding-up (section 9.6). It must be the most commonly consumed group/category.
STAGE1 <- c("staples", "proteins", "fruits_veg", "other")
STAGE2 <- c("beef", "pork", "sheep_goat_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs", "plant_protein")
ALTRI1 <- setdiff(STAGE1, "proteins")              # the 3 stage-1 groups that are not proteins
CELLE  <- c(STAGE2, ALTRI1)                         # 12 "price cells": every item belongs to exactly one of them
DEMO   <- c("ln_ampiezza", "rurale", "capo_donna")  # demographic variables in all equations
stopifnot(setequal(MAPPA$stadio1, STAGE1), setequal(na.omit(MAPPA$stadio2), STAGE2),
          all(!is.na(MAPPA$stadio2) == (MAPPA$stadio1 == "proteins")))   # check: stage-2 category only for proteins


## =============================================================================
## 1. LOAD THE DATA
## =============================================================================
dati_grezzi <- read_excel(FILE, sheet = "dati", guess_max = 1e5)   # one row per household x round (original values)
dizionario  <- read_excel(FILE, sheet = "voci")                     # item code -> item name, categoria, gruppo (by round)
cat("Households read:", nrow(dati_grezzi), " columns:", ncol(dati_grezzi), "\n")
stopifnot(!anyDuplicated(dati_grezzi[, c("round", "hhid")]))      # check: no household appears twice in a round

# out: the 419 households of the 2020 sample hh_sec_j1, which answered a different consumption module
dati_grezzi <- dati_grezzi %>% mutate(campione = coalesce(campione, "")) %>% filter(campione != "hh_sec_j1")

# 1.1 Household characteristics: all the columns that are not items (item columns start with "c" + a number)
col_voci <- grep("^c[0-9]+_", names(dati_grezzi), value = TRUE)
famiglie <- dati_grezzi %>% select(-all_of(col_voci))

# 1.2 Items: the price calculations need one row per household x item. pivot_longer turns the columns
#     c<code>_<variable> into rows: one per item, with its 9 variables side by side. Only consumed items are kept.
#     Then each item gets its categoria from the dictionary, and through MAPPA its stage-1 group and
#     stage-2 category. "cella" = stage-2 category for proteins, stage-1 group for the others.
voci <- dati_grezzi %>% select(round, hhid, campione, all_of(col_voci)) %>%
  pivot_longer(cols = all_of(col_voci), names_to = c("codice_voce", ".value"), names_pattern = "^c([0-9]+)_(.*)$") %>%
  mutate(codice_voce = as.numeric(codice_voce)) %>%
  filter(!is.na(q_tot) | !is.na(q_acq) | !is.na(spesa_acq) | !is.na(q_auto) | !is.na(q_regali)) %>%
  left_join(dizionario %>% mutate(campione = coalesce(campione, "")) %>% select(round, campione, codice_voce, voce, categoria),
            by = c("round", "campione", "codice_voce")) %>%
  left_join(MAPPA, by = "categoria") %>%
  mutate(cella = coalesce(stadio2, stadio1))
cat("Consumed items (household x item):", nrow(voci), " without categoria:", sum(is.na(voci$categoria)),
    " without stage:", sum(is.na(voci$stadio1)), "\n")
stopifnot(!anyNA(voci$categoria), !anyNA(voci$stadio1), all(voci$cella %in% CELLE))   # every item is classified

# 1.3 Table of the items in each stage (read it: it is the classification used by the whole script)
tab_voci <- voci %>% group_by(stadio1, stadio2, categoria, codice_voce) %>%
  summarise(voce = first(voce), rounds = paste(sort(unique(round)), collapse = " "), famiglie = n(), .groups = "drop") %>%
  mutate(stadio1 = factor(stadio1, STAGE1), stadio2 = factor(stadio2, STAGE2)) %>% arrange(stadio1, stadio2, codice_voce)
cat("\nItems by stage (famiglie = household x round observations consuming the item):\n")
print(as.data.frame(tab_voci), right = FALSE)

# check for missing values in the variables that are needed
cat("\nMissing values in the household variables:\n")
print(colSums(is.na(famiglie[, c("regione", "id_distretto", "id_ea", "cluster", "ampiezza", "rurale", "capo_donna", "spesa_totale_annua")])))
cat("Consumed items without any quantity:", sum(is.na(voci$q_tot) & is.na(voci$q_acq) & is.na(voci$q_auto) & is.na(voci$q_regali)), "\n")


## =============================================================================
## 2. UNIT VALUES OF PURCHASES: spending / quantity purchased          (unchanged from the one-stage script)
## =============================================================================
# 2.1 Standard units: grams become kg (code 1), millilitres become litres (code 3); pieces (5) and the 2020
#     local units (6-20) stay as they are. A price is always "per unit" of the same item.
voci <- voci %>% mutate(
  q_acq_s    = ifelse(u_acq    %in% c(2, 4), q_acq    / 1000, q_acq),
  u_acq_s    = ifelse(u_acq    == 2, 1, ifelse(u_acq    == 4, 3, u_acq)),
  q_auto_s   = ifelse(u_auto   %in% c(2, 4), q_auto   / 1000, q_auto),
  u_auto_s   = ifelse(u_auto   == 2, 1, ifelse(u_auto   == 4, 3, u_auto)),
  q_regali_s = ifelse(u_regali %in% c(2, 4), q_regali / 1000, q_regali),
  u_regali_s = ifelse(u_regali == 2, 1, ifelse(u_regali == 4, 3, u_regali)),
  q_tot_s    = ifelse(u_tot    %in% c(2, 4), q_tot    / 1000, q_tot),
  u_tot_s    = ifelse(u_tot    == 2, 1, ifelse(u_tot    == 4, 3, u_tot)))

# 2.2 Unit value: uv = spending / quantity purchased (TSH per unit), only when both are positive
voci <- voci %>% mutate(uv = ifelse(q_acq_s > 0 & spesa_acq > 0, spesa_acq / q_acq_s, NA))

# 2.3 Outlier prices: compared with the national median of the same item and unit in the same round
med_naz_uv <- voci %>% filter(!is.na(uv)) %>% group_by(round, codice_voce, u_acq_s) %>%
  summarise(med_uv = median(uv), n_uv = n(), .groups = "drop")
voci <- voci %>% left_join(med_naz_uv, by = c("round", "codice_voce", "u_acq_s")) %>%
  mutate(flag_uv_anomalo = !is.na(uv) & n_uv >= N_MIN & (uv > SOGLIA * med_uv | uv < med_uv / SOGLIA)) %>%
  select(-med_uv, -n_uv)
cat("\nUnit values computed:", sum(!is.na(voci$uv)), " of which outliers (excluded from the medians):", sum(voci$flag_uv_anomalo), "\n")


## =============================================================================
## 3. LOCAL MEDIAN PRICES by item and unit: EA -> district -> region -> country      (unchanged)
## =============================================================================
# the price of an item in a place is the median of the unit values of the purchases made there;
# the smallest level with at least N_MIN purchases is used
voci <- voci %>% left_join(famiglie %>% select(round, hhid, id_ea, id_distretto, regione), by = c("round", "hhid"))
acquisti <- voci %>% filter(!is.na(uv), !is.na(u_acq_s), !flag_uv_anomalo) %>% rename(unita = u_acq_s)

med_ea  <- acquisti %>% filter(!is.na(id_ea)) %>% group_by(round, codice_voce, unita, id_ea) %>%
  summarise(p_ea = median(uv), n_ea = n(), .groups = "drop") %>% filter(n_ea >= N_MIN)
med_dis <- acquisti %>% filter(!is.na(id_distretto)) %>% group_by(round, codice_voce, unita, id_distretto) %>%
  summarise(p_dis = median(uv), n_dis = n(), .groups = "drop") %>% filter(n_dis >= N_MIN)
med_reg <- acquisti %>% filter(!is.na(regione)) %>% group_by(round, codice_voce, unita, regione) %>%
  summarise(p_reg = median(uv), n_reg = n(), .groups = "drop") %>% filter(n_reg >= N_MIN)
med_naz <- acquisti %>% group_by(round, codice_voce, unita) %>%
  summarise(p_naz = median(uv), n_naz = n(), .groups = "drop") %>% filter(n_naz >= N_MIN)

# one function: given a list of (round, item, unit, place) it returns the local price and the level used
prezzo_locale <- function(d) {
  d <- d %>%
    left_join(med_ea,  by = c("round", "codice_voce", "unita", "id_ea")) %>%
    left_join(med_dis, by = c("round", "codice_voce", "unita", "id_distretto")) %>%
    left_join(med_reg, by = c("round", "codice_voce", "unita", "regione")) %>%
    left_join(med_naz, by = c("round", "codice_voce", "unita"))
  data.frame(prezzo  = coalesce(d$p_ea, d$p_dis, d$p_reg, d$p_naz),
             livello = case_when(!is.na(d$p_ea) ~ "EA", !is.na(d$p_dis) ~ "distretto", !is.na(d$p_reg) ~ "regione",
                                 !is.na(d$p_naz) ~ "paese", TRUE ~ "nessun prezzo"))
}


## =============================================================================
## 4. VALUE OF OWN PRODUCTION AND GIFTS: quantity x imputed local price      (unchanged)
## =============================================================================
pa <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_auto_s,   id_ea, id_distretto, regione))
pr <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_regali_s, id_ea, id_distretto, regione))
pq <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_acq_s,    id_ea, id_distretto, regione))
pt <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_tot_s,    id_ea, id_distretto, regione))
voci <- voci %>% mutate(
  liv_prezzo_auto = ifelse(coalesce(q_auto_s, 0) > 0, pa$livello, NA), liv_prezzo_regali = ifelse(coalesce(q_regali_s, 0) > 0, pr$livello, NA),
  # own production and gifts: value = quantity x local price (0 if the source is not used)
  val_auto   = ifelse(coalesce(q_auto_s, 0) > 0, q_auto_s * pa$prezzo, 0),
  val_regali = ifelse(coalesce(q_regali_s, 0) > 0, q_regali_s * pr$prezzo, 0),
  # purchases: the reported spending; if it is missing, or the unit value is an outlier, quantity x local price
  flag_acq_rivalutato = (coalesce(q_acq_s, 0) > 0) & (is.na(spesa_acq) | spesa_acq <= 0 | flag_uv_anomalo),
  val_acq    = case_when(flag_acq_rivalutato ~ q_acq_s * pq$prezzo,
                         spesa_acq > 0       ~ spesa_acq,
                         TRUE                ~ 0),
  # item consumed but no source filled in: the total quantity is valued
  flag_solo_totale = !(coalesce(q_acq_s, 0) > 0) & !(coalesce(q_auto_s, 0) > 0) & !(coalesce(q_regali_s, 0) > 0) & !(coalesce(spesa_acq, 0) > 0),
  val_solo_tot = ifelse(flag_solo_totale & coalesce(q_tot_s, 0) > 0, q_tot_s * pt$prezzo, 0))

# 4.1 Values without a price at any level: imputed with the median value of the same item and source in the
#     round (among the households that have a value) and flagged (flag_imp_*). Those still without a value
#     (the item has no value at all in the round) count as 0, are counted on screen and flagged in step 5.
imputa <- function(valore, fonte) {
  m <- voci %>% mutate(v = valore) %>% filter(coalesce(v, 0) > 0) %>% group_by(round, codice_voce) %>% summarise(med = median(v), .groups = "drop")
  med <- voci %>% select(round, codice_voce) %>% left_join(m, by = c("round", "codice_voce")) %>% pull(med)
  cat("  ", fonte, ": values imputed", sum(is.na(valore) & !is.na(med)), " - still without value (count as 0)", sum(is.na(valore) & is.na(med)), "\n")
  list(valore = ifelse(is.na(valore), med, valore), flag = is.na(valore) & !is.na(med))
}
cat("\nImputation of the values without a price:\n")
x <- imputa(voci$val_auto,     "own production"); voci$val_auto     <- x$valore; voci$flag_imp_auto     <- x$flag
x <- imputa(voci$val_regali,   "gifts");          voci$val_regali   <- x$valore; voci$flag_imp_regali   <- x$flag
x <- imputa(voci$val_acq,      "purchases");      voci$val_acq      <- x$valore; voci$flag_imp_acq      <- x$flag
x <- imputa(voci$val_solo_tot, "total only");     voci$val_solo_tot <- x$valore; voci$flag_imp_solo_tot <- x$flag
voci <- voci %>% mutate(flag_imputato = flag_imp_auto | flag_imp_regali | flag_imp_acq | flag_imp_solo_tot,
                        val_imputato  = flag_imp_auto * val_auto + flag_imp_regali * val_regali + flag_imp_acq * val_acq + flag_imp_solo_tot * val_solo_tot)

cat("\nGeographic level of the price used for own production (rows):\n"); print(table(voci$liv_prezzo_auto, useNA = "no"))


## =============================================================================
## 5. TOTAL VALUE OF CONSUMPTION = purchases + own production + gifts      (unchanged)
## =============================================================================
voci <- voci %>% mutate(val_tot = coalesce(val_acq, 0) + coalesce(val_auto, 0) + coalesce(val_regali, 0) + coalesce(val_solo_tot, 0),
                        flag_senza_valore = val_tot <= 0)
cat("\nConsumed items with zero value (no quantity that can be valued):", sum(voci$flag_senza_valore), "\n")


## =============================================================================
## 6. AGGREGATION INTO THE 12 PRICE CELLS AND THE 4 STAGE-1 GROUPS (one row per household)      (MODIFIED)
## =============================================================================
# 6.1 Value of each cell: the 9 protein categories + staples, fruits_veg, other (v_<cell>, TSH, 7 days)
celle_hh <- voci %>% group_by(round, hhid, cella) %>%
  summarise(valore = sum(val_tot), imputato = sum(val_imputato, na.rm = TRUE), .groups = "drop")
valori <- celle_hh %>% select(-imputato) %>%
  pivot_wider(names_from = cella, values_from = valore, values_fill = 0, names_prefix = "v_")
stopifnot(all(paste0("v_", CELLE) %in% names(valori)))
imputati <- celle_hh %>% group_by(round, hhid) %>%
  summarise(valore_imputato      = sum(imputato),                          # imputed value, whole food budget
            valore_imputato_prot = sum(imputato[cella %in% STAGE2]),       # imputed value, protein budget only
            .groups = "drop")
dati <- famiglie %>% left_join(valori, by = c("round", "hhid")) %>% left_join(imputati, by = c("round", "hhid"))
for (g in CELLE) dati[[paste0("v_", g)]] <- coalesce(dati[[paste0("v_", g)]], 0)   # cell not consumed = 0
dati$valore_imputato      <- coalesce(dati$valore_imputato, 0)
dati$valore_imputato_prot <- coalesce(dati$valore_imputato_prot, 0)

# 6.2 Value of the stage-1 protein group = sum of the 9 protein categories
dati$v_proteins <- rowSums(dati[, paste0("v_", STAGE2)])


## =============================================================================
## 7. BUDGETS AND SHARES OF THE TWO STAGES      (MODIFIED)
## =============================================================================
# 7.1 STAGE 1. Food budget x_food = staples + proteins + fruits_veg + other (food consumed at home, 7 days, TSH)
#     share of group g:  w1_g = v_g / x_food   (the 4 shares sum to 1)
dati$x_food <- rowSums(dati[, paste0("v_", STAGE1)])
dati$flag_budget_zero <- dati$x_food <= 0
n_budget_zero <- sum(dati$flag_budget_zero)
cat("\nHouseholds with zero food budget (they only eat away from home; excluded from both stages):", n_budget_zero, "\n")
dati <- dati %>% filter(!flag_budget_zero)
for (g in STAGE1) dati[[paste0("w1_", g)]] <- dati[[paste0("v_", g)]] / dati$x_food
stopifnot(all(abs(rowSums(dati[, paste0("w1_", STAGE1)]) - 1) < 1e-9))      # check: the 4 shares sum to 1
dati$quota_imputata <- dati$valore_imputato / dati$x_food
cat("Share of the food budget that is imputed: mean", round(100 * mean(dati$quota_imputata), 2), "%\n")

# 7.2 STAGE 2. Protein budget x_prot = v_proteins
#     CONDITIONAL share of category k:  w2_k = v_k / x_prot   (the 9 shares sum to 1 inside the protein budget)
#     A household with no protein spending (x_prot = 0) has no conditional shares: 0/0 is not defined.
#     Its w2_k are set to NA (not 0!) and the household is left out of stage 2 only (it stays in stage 1,
#     where its protein share w1_proteins = 0 is a real zero, handled by Shonkwiler-Yen).
dati$x_prot <- dati$v_proteins
dati$flag_prot_zero <- dati$x_prot <= 0
n_prot_zero <- sum(dati$flag_prot_zero)
cat("Households with zero protein budget (excluded from stage 2 only):", n_prot_zero, "\n")
for (k in STAGE2) dati[[paste0("w2_", k)]] <- ifelse(dati$flag_prot_zero, NA, dati[[paste0("v_", k)]] / dati$x_prot)
stopifnot(all(abs(rowSums(dati[!dati$flag_prot_zero, paste0("w2_", STAGE2)]) - 1) < 1e-9))   # check: sum to 1
dati$quota_imputata_prot <- ifelse(dati$flag_prot_zero, NA, dati$valore_imputato_prot / dati$x_prot)
cat("Share of the protein budget that is imputed: mean", round(100 * mean(dati$quota_imputata_prot, na.rm = TRUE), 2), "%\n")

# 7.3 Descriptive table of the shares
pr2 <- !dati$flag_prot_zero
tab_quote <- bind_rows(
  data.frame(stage = "stage 1", category = STAGE1,
             mean_share = colMeans(dati[, paste0("w1_", STAGE1)]),                          # share of the food budget
             mean_share_of_food_budget = colMeans(dati[, paste0("w1_", STAGE1)]),
             pct_consuming = 100 * colMeans(dati[, paste0("v_", STAGE1)] > 0), row.names = NULL),
  data.frame(stage = "stage 2 (conditional)", category = STAGE2,
             mean_share = colMeans(dati[pr2, paste0("w2_", STAGE2)]),                       # share of the protein budget
             mean_share_of_food_budget = colMeans(dati[, paste0("v_", STAGE2)] / dati$x_food),
             pct_consuming = 100 * colMeans(dati[pr2, paste0("v_", STAGE2)] > 0), row.names = NULL))
cat("\nMean shares and % of households consuming (stage 2: among households with protein spending):\n")
print(tab_quote %>% mutate(across(where(is.numeric), ~ round(.x, 3))))


## =============================================================================
## 8. PRICES OF THE GROUPS, STONE INDICES, REAL EXPENDITURE      (MODIFIED)
## =============================================================================
# 8.1 Reference unit of each item: the one with the most purchases in the round (the item price is in that unit)
rif <- acquisti %>% count(round, codice_voce, cella, unita) %>% group_by(round, codice_voce) %>% slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>% select(round, codice_voce, cella, unita)

# 8.2 Weight of each item in its cell: share of the item in the value of the cell, in the round (same for all households)
pesi <- voci %>% group_by(round, cella, codice_voce) %>% summarise(v = sum(val_tot), .groups = "drop") %>%
  group_by(round, cella) %>% mutate(peso = v / sum(v)) %>% ungroup() %>% select(round, codice_voce, peso)

# 8.3 Local price of every item for EVERY household, also for those who do not buy it (same medians EA -> country)
griglia <- dati %>% select(round, hhid, id_ea, id_distretto, regione) %>%
  inner_join(rif, by = "round", relationship = "many-to-many") %>% left_join(pesi, by = c("round", "codice_voce"))
pp <- prezzo_locale(griglia %>% select(round, codice_voce, unita, id_ea, id_distretto, regione))
griglia$prezzo <- pp$prezzo; griglia$livello <- pp$livello
cat("\nItem prices for each household, by geographic level (%):\n"); print(round(100 * prop.table(table(griglia$livello)), 1))

# 8.4 Price of each cell: weighted geometric mean of the item prices, ln P_c = sum_i peso_i ln p_i / sum_i peso_i
#     (items without a price in the round are left out of the index and the weights of the others are rescaled)
pg <- griglia %>% filter(!is.na(prezzo), peso > 0) %>% group_by(round, hhid, cella) %>%
  summarise(lnP = sum(peso * log(prezzo)) / sum(peso), .groups = "drop") %>%
  pivot_wider(names_from = cella, values_from = lnP, names_prefix = "lnP_")
dati <- dati %>% left_join(pg, by = c("round", "hhid"))
cat("Households without a price for at least one cell:", sum(!complete.cases(dati[, paste0("lnP_", CELLE)])), "\n")

# 8.5 STAGE-2 STONE INDEX = PRICE OF THE PROTEIN GROUP
#     ln P_prot = sum_k wbar2_k ln P_k, with wbar2 = MEAN conditional shares (households with protein spending).
#     The same index plays two roles, which keeps the two stages consistent:
#       - in stage 2 it deflates the protein budget: real protein expenditure = x_prot / P_prot
#       - in stage 1 it is the price of the group "proteins"
#     (with each household's own shares, the share would appear on both sides of the equation: Buse 1994, Moschini 1995)
wbar2 <- colMeans(dati[!dati$flag_prot_zero, paste0("w2_", STAGE2)]); names(wbar2) <- STAGE2
dati$lnP_proteins <- as.vector(as.matrix(dati[, paste0("lnP_", STAGE2)]) %*% wbar2)

# 8.6 STAGE-1 STONE INDEX of food: ln P_food = sum_g wbar1_g ln P_g over the 4 groups (proteins: the index of 8.5)
wbar1 <- colMeans(dati[, paste0("w1_", STAGE1)]); names(wbar1) <- STAGE1
dati$lnP_food <- as.vector(as.matrix(dati[, paste0("lnP_", STAGE1)]) %*% wbar1)

# 8.7 Real expenditures and relative prices
#     Homogeneity (doubling all prices and the budget changes nothing) is imposed by dividing every price by
#     the price of the residual group of the same stage: ln(p_g / p_other) in stage 1, ln(p_k / p_plant_protein) in stage 2.
dati <- dati %>% mutate(ln_ampiezza    = log(ampiezza),
                        ln_spesa_tot   = log(spesa_totale_annua),                       # instrument (section 9)
                        ln_x_food      = log(x_food),
                        ln_x_food_real = ln_x_food - lnP_food,                          # stage 1: ln(x_food / P_food)
                        ln_x_prot      = ifelse(flag_prot_zero, NA, log(x_prot)),
                        ln_x_prot_real = ln_x_prot - lnP_proteins)                      # stage 2: ln(x_prot / P_prot)
RES1 <- tail(STAGE1, 1); RES2 <- tail(STAGE2, 1)                                        # "other" and "plant_protein"
for (g in head(STAGE1, -1)) dati[[paste0("lnp1_", g)]] <- dati[[paste0("lnP_", g)]] - dati[[paste0("lnP_", RES1)]]
for (k in head(STAGE2, -1)) dati[[paste0("lnp2_", k)]] <- dati[[paste0("lnP_", k)]] - dati[[paste0("lnP_", RES2)]]

# 8.8 Clean-up: the large intermediate objects are no longer needed (the bootstrap needs memory)
rm(dati_grezzi, griglia, pp, pg, pa, pr, pq, pt); invisible(gc())


## =============================================================================
## 9. ESTIMATION OF THE TWO LA/AIDS SYSTEMS (Shonkwiler-Yen, control function, SUR)      (MODIFIED)
## =============================================================================
# The SAME function estimates stage 1 and stage 2. What changes between the stages is written in a "spec"
# (a list): which shares, which groups, which prices, which expenditure, which instruments.
#
# THE SHARE EQUATION OF ONE GROUP g (LA/AIDS, Deaton and Muellbauer 1980):
#     w_g = a_g + sum_j gamma_gj ln(p_j / p_residual) + beta_g ln(x / P) + demographics + round dummies
#   gamma = price effects, beta = expenditure effect (beta > 0: luxury, beta < 0: necessity)
#
# WHY A CONTROL FUNCTION (the expenditure is endogenous)
#   The expenditure x is on the right-hand side, but it is not "given from outside": the same reported quantities
#   that build the shares also build x (a measurement error enters both), and a household that likes meat may also
#   spend more on food. Ordinary regression would then be biased. The control function corrects it in two steps:
#    (1) regress the endogenous expenditure on one or more INSTRUMENTS (variables that move the expenditure but have
#        no direct effect on the shares) and on all the other regressors of the share equations; keep the residual
#        v_hat = the part of the expenditure the instruments cannot explain (the "suspicious" part);
#    (2) add v_hat as an extra regressor in the probits and in the share equations. With v_hat held fixed, the
#        effect of expenditure is measured only from its "clean" variation. If the coefficient of v_hat is close
#        to zero, the expenditure was not really endogenous.
#
#   STAGE 1. Endogenous: ln(x_food / P_food). Instrument: ln(total household expenditure) = ln_spesa_tot.
#     Relevance: households that spend more in total also spend more on food (checked below with an F statistic).
#     Exclusion (the identifying assumption): total expenditure affects how food is split among the 4 groups ONLY
#       through the food budget. This is weak separability of food from non-food: the upper level of the same
#       two-stage budgeting logic.
#     Caveat: total expenditure contains food expenditure, so part of the measurement error of the food module is
#       also in the instrument: the bias is reduced, not removed. Income would be a cleaner instrument, but income
#       in the NPS is poorly measured.
#
#   STAGE 2. Endogenous: ln(x_prot / P_prot).
#     The food budget is NOT a valid instrument here: food budget and protein budget are chosen together in stage 1.
#     Instruments: ln(total expenditure) + ln prices of staples, fruits-vegetables and other foods
#       (ln_spesa_tot, lnP_staples, lnP_fruits_veg, lnP_other).
#     Relevance: these prices change the protein budget through stage 1 (if maize is expensive, less money is left
#       for proteins). Checked below with a joint F statistic of the 4 instruments.
#     Exclusion: under weak separability these prices do NOT enter the stage-2 equations: they can change the
#       beef-versus-fish split only by changing x_prot. So the identifying assumption is exactly the maintained
#       assumption of the model. If weak separability were false, these instruments would not be valid.
#     Caveat: the same as stage 1 for total expenditure.
#
#   CHANGES with respect to the one-stage script (the control function is not simply copied):
#     - the dependent variable of step (1) is now the REAL expenditure ln(x/P), which is exactly the variable
#       that enters the share equations (before it was the nominal ln x);
#     - v_hat now enters the probits too, not only the share equations, because the expenditure is also a
#       regressor of the probit (control function for probit: Rivers and Vuong 1988).
#
# The instrument strength is measured with a Wald F statistic that is robust to clustering (households of
# the same cluster are not independent). Rule of thumb: an F well above 10 means strong instruments.

# 9.1 Survey-round dummies (base = 2008): they absorb inflation and everything common to a round
ANNI  <- sort(unique(dati$round))
ROUND <- paste0("r", ANNI[-1])
for (r in ROUND) dati[[r]] <- as.numeric(dati$round == as.numeric(sub("r", "", r)))

# 9.2 The two specs. prepara_spec adds the derived pieces: estimated groups (all but the residual), relative
#     prices, regressors, equation names, symmetry restrictions.
prepara_spec <- function(S) {
  S$GS   <- head(S$gruppi, -1)                                  # estimated groups (the residual is the last one)
  S$res  <- tail(S$gruppi, 1)                                   # residual group: equation omitted
  S$PREL <- paste0(S$p, S$GS)                                   # relative prices ln(p_j / p_residual)
  S$X    <- c(S$PREL, S$x_reale, DEMO, ROUND, "v_hat")          # regressors of the probits and of the shares
  S$EQ   <- setNames(gsub("_", "", S$GS), S$GS)                 # equation names without "_" (systemfit does not accept it)
  # Symmetry: gamma_ij = gamma_ji for i, j among the estimated groups (homogeneity is already imposed by the
  # relative prices). In systemfit a coefficient is called "<equation>_<regressor>", e.g. "beef_beef_lnp2_pork";
  # "fruits_veg" is called "fruitsveg" in the system, "sheep_goat_other_meat" is "sheepgoatothermeat", etc.
  simm <- c()
  n <- length(S$GS)
  for (i in 1:(n - 1)) for (j in (i + 1):n) {
    gi <- S$GS[i]; gj <- S$GS[j]; ei <- S$EQ[gi]; ej <- S$EQ[gj]
    simm <- c(simm, paste0(ei, "_", ei, "_", S$p, gj, " - ", ej, "_", ej, "_", S$p, gi, " = 0"))
  }
  S$simm <- simm
  S
}
SPEC1 <- prepara_spec(list(nome = "stage 1", gruppi = STAGE1, w = "w1_", p = "lnp1_", x_reale = "ln_x_food_real",
                           strumenti = c("ln_spesa_tot"), wbar = wbar1))
SPEC2 <- prepara_spec(list(nome = "stage 2", gruppi = STAGE2, w = "w2_", p = "lnp2_", x_reale = "ln_x_prot_real",
                           strumenti = c("ln_spesa_tot", "lnP_staples", "lnP_fruits_veg", "lnP_other"), wbar = wbar2))
cat("\nSymmetry restrictions: stage 1", length(SPEC1$simm), " stage 2", length(SPEC2$simm), "\n")

# 9.3 Estimation samples: households with all prices, demographics, instruments and cluster.
#     Stage 2 only uses households with protein spending (x_prot > 0).
vars1  <- c(SPEC1$PREL, SPEC1$x_reale, DEMO, SPEC1$strumenti, "cluster")
vars2  <- c(SPEC2$PREL, SPEC2$x_reale, DEMO, SPEC2$strumenti, "cluster")
stima1 <- dati[complete.cases(dati[, vars1]), ]
stima2 <- dati[!dati$flag_prot_zero & complete.cases(dati[, vars2]), ]
cat("Households in the estimation: stage 1", nrow(stima1), "of", nrow(dati), " - stage 2", nrow(stima2), "of", sum(!dati$flag_prot_zero), "\n")

# 9.4 Strength of the instruments: coefficients, cluster-robust t and joint F of the excluded instruments.
#     Cluster-robust variance: (X'X)^-1 [sum over clusters of (X_c'u_c)(X_c'u_c)'] (X'X)^-1, with the usual
#     small-sample correction.
forza_strumenti <- function(m, strumenti, cl) {
  X <- model.matrix(m); u <- residuals(m)
  XtX_inv <- solve(crossprod(X))
  somme <- rowsum(X * u, cl)                                   # X_c'u_c for every cluster
  nc <- nrow(somme); n <- nrow(X); k <- ncol(X)
  V <- XtX_inv %*% crossprod(somme) %*% XtX_inv * (nc / (nc - 1)) * ((n - 1) / (n - k))
  b <- coef(m)[strumenti]; Vs <- V[strumenti, strumenti, drop = FALSE]
  F <- as.numeric(t(b) %*% solve(Vs, b)) / length(strumenti)
  data.frame(instrument = strumenti, coefficient = b, se_cluster = sqrt(diag(Vs)), t_cluster = b / sqrt(diag(Vs)),
             joint_F_cluster = F, row.names = NULL)
}

# 9.5 The estimation, written ONCE as a function, because the bootstrap (section 11) repeats it many times.
#     In: a sample d and a spec S. Out: the parameters and the sample columns needed for the elasticities.
#     (glm and systemfit objects are large: only their coefficients are kept, so the bootstrap does not run out of memory.)
stima_laaids <- function(d, S, stampa = FALSE) {

  # (a) Control function, step (1): endogenous real expenditure on the instruments and on all the exogenous regressors
  esogene <- c(S$PREL, DEMO, ROUND)
  cf <- lm(as.formula(paste(S$x_reale, "~", paste(c(S$strumenti, esogene), collapse = " + "))), data = d)
  d$v_hat <- residuals(cf)
  strumenti <- NULL
  if (stampa) {
    strumenti <- data.frame(stage = S$nome, forza_strumenti(cf, S$strumenti, d$cluster))
    cat("\n", S$nome, "- control function, first step (dependent:", S$x_reale, ")\n")
    print(strumenti %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
  }
  rm(cf)

  # (b) Shonkwiler-Yen, step 1. Many households consume none of a group in the 7 days: its share is 0, and a
  #     linear regression would treat these zeros like normal values (biased coefficients). So first, for each
  #     group, a probit on "does the household consume it?" (w > 0), with the same regressors as the shares.
  #     It gives Phi = probability of consuming, phi = normal density at the same point.
  #     The warning "glm.fit: fitted probabilities numerically 0 or 1 occurred" is expected for groups that almost
  #     every household consumes (staples, 99.5%): for a few households the probability is ~1. It is harmless.
  probit <- list()
  for (g in S$GS) {
    d[[paste0("d_", g)]] <- as.numeric(d[[paste0(S$w, g)]] > 0)
    m <- glm(as.formula(paste0("d_", g, " ~ ", paste(S$X, collapse = " + "))), family = binomial(link = "probit"), data = d)
    probit[[g]] <- coef(m)
    t_g <- predict(m, type = "link")                                 # linear index z'c
    rm(m)
    d[[paste0("t_", g)]]   <- t_g
    d[[paste0("Phi_", g)]] <- pnorm(t_g)
    d[[paste0("phi_", g)]] <- dnorm(t_g)
    if (stampa) cat(sprintf("  probit %-22s households consuming %5.1f%%\n", g, 100 * mean(d[[paste0("d_", g)]])))
  }
  if (stampa) cat(sprintf("  residual %-20s households consuming %5.1f%%  (its zeros are not modelled: see (e))\n",
                          S$res, 100 * mean(d[[paste0(S$w, S$res)]] > 0)))

  # (c) Shonkwiler-Yen, step 2. For each estimated group g:
  #     w_g = Phi_g * [ a_g + sum_j gamma_gj ln(p_j/p_res) + beta_g ln(x/P) + demographics + rounds + rho_g v_hat ] + delta_g phi_g
  #     The expected share is "probability of consuming x share if consuming" plus a correction delta_g phi_g.
  #     The equation is linear in the parameters: every regressor in the brackets is multiplied by Phi_g.
  eqs <- list()
  for (g in S$GS) {
    e <- S$EQ[g]
    nomi <- c(paste0(e, "_cost"), paste0(e, "_", S$X), paste0(e, "_phi"))
    d[[nomi[1]]] <- d[[paste0("Phi_", g)]]                                     # constant a_g
    for (v in S$X) d[[paste0(e, "_", v)]] <- d[[paste0("Phi_", g)]] * d[[v]]
    d[[nomi[length(nomi)]]] <- d[[paste0("phi_", g)]]                          # term delta_g * phi_g
    eqs[[e]] <- as.formula(paste0(S$w, g, " ~ 0 + ", paste(nomi, collapse = " + ")))
  }

  # (d) SUR (seemingly unrelated regressions) on all the estimated equations together, with symmetry imposed
  sur <- systemfit(eqs, method = "SUR", data = d, restrict.matrix = S$simm)
  b   <- coef(sur)
  es_systemfit <- NULL
  if (stampa) { cat(" ", S$nome, "- SUR estimated. R2 by equation:\n"); print(round(sapply(summary(sur)$eq, function(e) e$r.squared), 3))
                es_systemfit <- sqrt(diag(vcov(sur))) }
  rm(sur)

  # (e) Parameters of the AIDS part (inside the brackets): matrix gamma, alfa, beta, delta.
  #     ADDING-UP AND THE OMITTED EQUATION. The observed shares sum to 1, but with Shonkwiler-Yen the expected
  #     shares of the estimated equations do not sum to 1 automatically. So the residual equation is NOT estimated:
  #     its expected share is DEFINED as 1 minus the sum of the others. Adding-up then holds exactly, for the shares
  #     and for the elasticities (section 10). Its AIDS parameters below are recovered from the adding-up conditions
  #     (sum of alfa = 1, sum of beta = 0, every column of gamma sums to 0) and are only reported.
  #     The price: the zeros of the residual group are not modelled. This is why the residual must be the most
  #     commonly consumed group: "other" in stage 1 (almost everybody), "plant_protein" in stage 2 (about 82%).
  #     Homogeneity holds exactly also for the expected shares (the probits use relative prices and real
  #     expenditure); symmetry holds for the AIDS parameters gamma, not exactly for the expected shares
  #     (a known property of the Shonkwiler-Yen system).
  G <- length(S$gruppi)
  gam <- matrix(0, G, G, dimnames = list(S$gruppi, S$gruppi))
  alfa <- beta <- delta <- setNames(rep(0, G), S$gruppi)
  for (g in S$GS) {
    e <- S$EQ[g]
    alfa[g]  <- b[paste0(e, "_", e, "_cost")]
    beta[g]  <- b[paste0(e, "_", e, "_", S$x_reale)]
    delta[g] <- b[paste0(e, "_", e, "_phi")]
    for (j in S$GS) gam[g, j] <- b[paste0(e, "_", e, "_", S$p, j)]
    gam[g, S$res] <- -sum(gam[g, S$GS])                      # homogeneity: every row of gamma sums to zero
  }
  alfa[S$res] <- 1 - sum(alfa[S$GS]); beta[S$res] <- -sum(beta[S$GS]); gam[S$res, ] <- -colSums(gam[S$GS, , drop = FALSE])
  if (stampa) cat("  checks: symmetry max|gamma - t(gamma)| =", signif(max(abs(gam - t(gam))), 3),
                  "  homogeneity max|row sum of gamma| =", signif(max(abs(rowSums(gam))), 3), "\n")
  tieni <- c("round", paste0(S$w, S$gruppi), paste0("t_", S$GS), S$PREL, S$x_reale, DEMO, ROUND, "v_hat")
  list(d = d[, tieni], S = S, probit = probit, b = b, alfa = alfa, beta = beta, delta = delta, gam = gam,
       strumenti = strumenti, es_systemfit = es_systemfit)
}

fit1 <- stima_laaids(stima1, SPEC1, stampa = TRUE)       # stage 1 on the real sample
fit2 <- stima_laaids(stima2, SPEC2, stampa = TRUE)       # stage 2 on the real sample


## =============================================================================
## 10. ELASTICITIES (at the sample means)      (MODIFIED: one function for both stages + unconditional)
## =============================================================================
# 10.1 Elasticities of one system (stage 1, or stage 2 conditional). Same formulas as the one-stage script.
# With Shonkwiler-Yen the expected share is E(w_g) = Phi(t_g) * f_g + delta_g * phi(t_g), with f_g = AIDS part.
# Derivative with respect to a variable s (ln x or ln p_j):
#     dE(w_g)/ds = Phi_g * df_g/ds  +  phi_g * (f_g - delta_g * t_g) * dt_g/ds
# because dPhi/dt = phi and dphi/dt = -t * phi. With the Stone index at mean shares: d ln P/d ln p_j = wbar_j.
#   df_g/d ln x   = beta_g                         dt_g/d ln x   = c_g (probit coefficient of real expenditure)
#   df_g/d ln p_j = gamma_gj - beta_g wbar_j       dt_g/d ln p_j = c_gj - c_g wbar_j  (c_g,res = -sum of the c_gj)
# Elasticities:  expenditure  E_g   = 1 + (dE(w_g)/d ln x) / w_g
#                Marshall     e_gj  = -1(g=j) + (dE(w_g)/d ln p_j) / w_g      (uncompensated)
#                Hicks        e*_gj = e_gj + E_g * w_j                         (compensated, Slutsky equation)
# The residual group has derivatives = -(sum of the derivatives of the others) (adding-up).
# v_hat is held at its mean: the elasticities measure the effect of expenditure net of its endogenous part.
# In stage 1 "x" is the food budget and the prices are group prices; in stage 2 "x" is the PROTEIN budget and the
# prices are category prices: the stage-2 elasticities are CONDITIONAL on the protein budget.
# The function uses the parameters of one estimation (fit) and the mean values of a sample d (all, or one round).
elasticita <- function(fit, d) {
  S  <- fit$S; GR <- S$gruppi; G <- length(GR)
  w  <- colMeans(d[, paste0(S$w, GR)]); names(w) <- GR                       # mean shares
  dX <- setNames(rep(0, G), GR); dP <- matrix(0, G, G, dimnames = list(GR, GR))
  ALTRE <- c(DEMO, ROUND, "v_hat")
  for (g in S$GS) {
    cp <- fit$probit[[g]]
    t  <- mean(d[[paste0("t_", g)]])                                         # probit index at the means
    f  <- fit$alfa[g] + sum(fit$gam[g, S$GS] * colMeans(d[, S$PREL])) + fit$beta[g] * mean(d[[S$x_reale]]) +
          sum(fit$b[paste0(S$EQ[g], "_", S$EQ[g], "_", ALTRE)] * colMeans(d[, ALTRE]))   # AIDS part at the means
    k  <- dnorm(t) * (f - fit$delta[g] * t)
    c_x <- cp[S$x_reale]; c_p <- c(cp[S$PREL], -sum(cp[S$PREL])); names(c_p) <- GR
    dX[g]   <- pnorm(t) * fit$beta[g] + k * c_x
    dP[g, ] <- pnorm(t) * (fit$gam[g, ] - fit$beta[g] * S$wbar) + k * (c_p - c_x * S$wbar)
  }
  dX[S$res] <- -sum(dX[S$GS]); dP[S$res, ] <- -colSums(dP[S$GS, , drop = FALSE])
  e_spesa <- 1 + dX / w
  marsh   <- -diag(G) + dP / w                       # row g divided by w_g
  hicks   <- marsh + outer(e_spesa, w)
  dimnames(marsh) <- dimnames(hicks) <- list(GR, GR)
  list(w = w, spesa = e_spesa, marshall = marsh, hicks = hicks)
}

# 10.2 UNCONDITIONAL elasticities of the protein categories (two-stage budgeting, Edgerton 1997)
# The stage-2 elasticities hold the protein budget FIXED. Example: if beef becomes 10% more expensive, the
# conditional elasticity says how beef changes if the household keeps spending exactly the same amount on proteins.
# But a dearer beef also raises the protein price index P_prot, and so changes the protein budget chosen in stage 1.
# The unconditional elasticities add this second channel: they answer "how does beef respond to the food budget,
# or to any food price, when the household re-optimises BOTH stages?"
# Notation: E = expenditure elasticity, e = Marshallian price elasticity, w = share; k, j = protein categories;
#           s = a non-protein stage-1 group (staples, fruits_veg, other); P = the protein group; "|P" = conditional.
#   (1) food budget:              E_k  = E_k|P * E_P
#         food budget +1%  ->  protein budget +E_P %  ->  category k +E_k|P * E_P %
#   (2) price of a protein j:     e_kj = e_kj|P + E_k|P * wbar_j|P * (1 + e_PP)
#         direct effect inside proteins + effect through the protein budget: p_j +1% raises P_prot by wbar_j|P %
#         (its Stone weight); protein spending x_prot = P_prot * Q_prot then changes by (1 + e_PP) times that;
#         and category k reacts to x_prot with E_k|P.  (Edgerton writes w_j|P: our P_prot is a Stone index with
#         fixed weights wbar_j|P, so wbar_j|P is its exact derivative; at the sample mean the two practically coincide.)
#   (3) price of another group s: e_ks = E_k|P * e_Ps
#         by weak separability p_s acts on category k only by changing the protein budget.
#   (4) Hicksian (compensated), from Slutsky: e*_kj = e_kj + E_k * w_j, with w_j the share of j in the FOOD budget
#         (w_j|P * w_P for a protein category, w_s for a stage-1 group).
# These formulas are exact under weak separability with an exact group price index; with the Stone index they are an
# approximation (Edgerton 1997; Carpentier and Guyomard 2001 propose a refined approximation).
# Stage-1 terms (E_P, e_PP, e_Ps, w_P) are taken at the stage-1 means, stage-2 terms at the stage-2 means.
elasticita_incondizionate <- function(E1, E2) {
  wP  <- E1$w["proteins"]; EP <- E1$spesa["proteins"]
  ePP <- E1$marshall["proteins", "proteins"]; ePs <- E1$marshall["proteins", ALTRI1]
  spesa <- E2$spesa * EP                                                  # (1)
  marsh <- cbind(E2$marshall + outer(E2$spesa, wbar2) * (1 + ePP),        # (2) columns = protein prices
                 outer(E2$spesa, ePs))                                    # (3) columns = staples, fruits_veg, other prices
  w_col <- c(E2$w * wP, E1$w[ALTRI1])                                     # shares in the food budget of the price columns
  hicks <- marsh + outer(spesa, w_col)                                    # (4)
  dimnames(marsh) <- dimnames(hicks) <- list(STAGE2, c(STAGE2, ALTRI1))
  list(w = E2$w * wP, w_col = w_col, spesa = spesa, marshall = marsh, hicks = hicks)
}

# 10.3 Point estimates: whole sample
E1 <- elasticita(fit1, fit1$d)                 # stage 1
E2 <- elasticita(fit2, fit2$d)                 # stage 2, conditional on the protein budget
EU <- elasticita_incondizionate(E1, E2)        # unconditional (with respect to the food budget and all food prices)
E_tutti <- list(s1 = E1, s2 = E2, unc = EU)

cat("\nSTAGE 1 - elasticities with respect to the food budget:\n");   print(round(E1$spesa, 2))
cat("STAGE 1 - own-price elasticities, Marshall:\n");                 print(round(diag(E1$marshall), 2))
cat("STAGE 2 - CONDITIONAL elasticities with respect to the protein budget:\n"); print(round(E2$spesa, 2))
cat("STAGE 2 - CONDITIONAL own-price elasticities, Marshall:\n");     print(round(diag(E2$marshall), 2))
cat("UNCONDITIONAL elasticities with respect to the food budget:\n"); print(round(EU$spesa, 2))
cat("UNCONDITIONAL own-price elasticities, Marshall:\n");             print(round(diag(EU$marshall), 2))

# 10.4 Checks (they must be satisfied exactly, up to rounding)
cat("\nChecks:\n")
cat("  adding-up stage 1: sum w_g E_g =", round(sum(E1$w * E1$spesa), 4), "(must be 1)\n")
cat("  adding-up stage 2: sum w_k|P E_k|P =", round(sum(E2$w * E2$spesa), 4), "(must be 1)\n")
cat("  adding-up unconditional: sum_k w_k E_k + sum_s w_s E_s =",
    round(sum(EU$w * EU$spesa) + sum(E1$w[ALTRI1] * E1$spesa[ALTRI1]), 4), "(must be 1)\n")
cat("  homogeneity (max |row sum of Marshall + expenditure elasticity|): stage 1", signif(max(abs(rowSums(E1$marshall) + E1$spesa)), 3),
    " stage 2", signif(max(abs(rowSums(E2$marshall) + E2$spesa)), 3), " unconditional", signif(max(abs(rowSums(EU$marshall) + EU$spesa)), 3), "\n")

# 10.5 Same estimates, at the mean values of each round
E_round <- list(s1 = list(), s2 = list(), unc = list())
for (k in seq_along(ANNI)) {
  E_round$s1[[k]]  <- elasticita(fit1, fit1$d[fit1$d$round == ANNI[k], ])
  E_round$s2[[k]]  <- elasticita(fit2, fit2$d[fit2$d$round == ANNI[k], ])
  E_round$unc[[k]] <- elasticita_incondizionate(E_round$s1[[k]], E_round$s2[[k]])
}


## =============================================================================
## 11. STANDARD ERRORS OF THE ELASTICITIES: CLUSTER BOOTSTRAP      (MODIFIED: both stages in every replication)
## =============================================================================
# Why: Phi, phi and v_hat are ESTIMATED (probits, first step) and then used as data in the SUR; the standard errors
# of systemfit ignore this and are too small. Moreover, the elasticities are non-linear functions of the parameters.
# The bootstrap solves both problems: draw a new sample, redo the WHOLE estimation (9.5) of BOTH stages and recompute
# all the elasticities; the standard deviation of the B replications is the standard error.
# CLUSTERS (sampling units) are drawn, not households: households of the same cluster are similar (same prices,
# same village) and a panel household appears in several rounds, always in the same cluster.
# The SAME clusters are used for stage 1 and stage 2 in a replication: the unconditional elasticities combine the
# two stages, so they get correct standard errors too.
# The group prices and the Stone indices (section 8) are kept as in the sample: they are treated as data.
SISTEMI <- list(s1  = list(righe = STAGE1, colonne = STAGE1),                  # rows = who reacts, columns = which price
                s2  = list(righe = STAGE2, colonne = STAGE2),
                unc = list(righe = STAGE2, colonne = c(STAGE2, ALTRI1)))
boot_spesa <- lapply(SISTEMI, function(s) matrix(NA, B, length(s$righe), dimnames = list(NULL, s$righe)))
boot_marsh <- lapply(SISTEMI, function(s) array(NA, c(B, length(s$righe), length(s$colonne)), dimnames = list(NULL, s$righe, s$colonne)))
boot_hicks <- boot_marsh
boot_round <- lapply(SISTEMI, function(s) array(NA, c(B, length(ANNI), length(s$righe), 3),
                                                dimnames = list(NULL, ANNI, s$righe, c("spesa", "marshall", "hicks"))))
set.seed(SEME)
righe1  <- split(seq_len(nrow(stima1)), stima1$cluster)     # rows of each cluster, stage 1
righe2  <- split(seq_len(nrow(stima2)), stima2$cluster)     # rows of each cluster, stage 2
CLUSTER <- names(righe1)
K <- length(CLUSTER)
cat("\nBootstrap:", B, "replications,", K, "clusters. Each replication redoes control function, probits and SUR of both stages.\n")
t0 <- Sys.time()
for (r in 1:B) {
  estratti <- sample(CLUSTER, K, replace = TRUE)                       # K clusters drawn with replacement
  d1 <- stima1[unlist(righe1[estratti], use.names = FALSE), ]          # their households (a cluster drawn twice enters twice)
  d2 <- stima2[unlist(righe2[estratti], use.names = FALSE), ]          # same clusters for stage 2
  f1 <- tryCatch(suppressWarnings(stima_laaids(d1, SPEC1)), error = function(e) NULL)
  f2 <- tryCatch(suppressWarnings(stima_laaids(d2, SPEC2)), error = function(e) NULL)
  rm(d1, d2)
  if (is.null(f1) || is.null(f2)) next                                 # failed replication: skipped (counted below)
  e_b <- list(s1 = elasticita(f1, f1$d), s2 = elasticita(f2, f2$d))
  e_b$unc <- elasticita_incondizionate(e_b$s1, e_b$s2)
  for (s in names(SISTEMI)) {
    boot_spesa[[s]][r, ] <- e_b[[s]]$spesa; boot_marsh[[s]][r, , ] <- e_b[[s]]$marshall; boot_hicks[[s]][r, , ] <- e_b[[s]]$hicks
  }
  for (k in seq_along(ANNI)) {
    e_r <- list(s1 = elasticita(f1, f1$d[f1$d$round == ANNI[k], ]), s2 = elasticita(f2, f2$d[f2$d$round == ANNI[k], ]))
    e_r$unc <- elasticita_incondizionate(e_r$s1, e_r$s2)
    for (s in names(SISTEMI)) boot_round[[s]][r, k, , ] <- cbind(e_r[[s]]$spesa, diag(e_r[[s]]$marshall), diag(e_r[[s]]$hicks))
  }
  rm(f1, f2); invisible(gc())                                          # free the memory of the replication
  if (r %% 10 == 0) cat("  replication", r, "of", B, "-", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "minutes\n")
}
ok <- !is.na(boot_spesa$s1[, 1]) & !is.na(boot_spesa$s2[, 1])
cat("Successful replications:", sum(ok), "of", B, "\n")

# standard error = standard deviation of the replications; 95% interval = percentiles 2.5 and 97.5 of the replications
es   <- function(x) sd(x, na.rm = TRUE)
q025 <- function(x) quantile(x, 0.025, na.rm = TRUE)
q975 <- function(x) quantile(x, 0.975, na.rm = TRUE)
riassumi <- function(s) {
  E <- E_tutti[[s]]; bs <- boot_spesa[[s]]; bm <- boot_marsh[[s]]; bh <- boot_hicks[[s]]; righe <- SISTEMI[[s]]$righe
  list(
    spesa = data.frame(category = righe, mean_share = E$w, expenditure_elasticity = E$spesa, se = apply(bs, 2, es),
                       ci95_low = apply(bs, 2, q025), ci95_high = apply(bs, 2, q975), row.names = NULL),
    propria = data.frame(category = righe,
                         marshall = diag(E$marshall), marshall_se = diag(apply(bm, c(2, 3), es)),
                         marshall_ci95_low = diag(apply(bm, c(2, 3), q025)), marshall_ci95_high = diag(apply(bm, c(2, 3), q975)),
                         hicks = diag(E$hicks), hicks_se = diag(apply(bh, c(2, 3), es)),
                         hicks_ci95_low = diag(apply(bh, c(2, 3), q025)), hicks_ci95_high = diag(apply(bh, c(2, 3), q975)), row.names = NULL),
    marshall    = data.frame(category = righe, E$marshall, check.names = FALSE),
    marshall_se = data.frame(category = righe, apply(bm, c(2, 3), es), check.names = FALSE),
    hicks       = data.frame(category = righe, E$hicks, check.names = FALSE),
    hicks_se    = data.frame(category = righe, apply(bh, c(2, 3), es), check.names = FALSE))
}
TAB <- lapply(setNames(names(SISTEMI), names(SISTEMI)), riassumi)
tab_round <- bind_rows(lapply(names(SISTEMI), function(s) bind_rows(lapply(seq_along(ANNI), function(k) {
  Er <- E_round[[s]][[k]]; br <- boot_round[[s]]
  data.frame(system = s, round = ANNI[k], category = SISTEMI[[s]]$righe, mean_share = Er$w,
             expenditure_elasticity = Er$spesa, expenditure_elasticity_se = apply(br[, k, , "spesa"], 2, es),
             own_marshall = diag(Er$marshall), own_marshall_se = apply(br[, k, , "marshall"], 2, es),
             own_hicks = diag(Er$hicks), own_hicks_se = apply(br[, k, , "hicks"], 2, es), row.names = NULL)
}))))
for (s in names(SISTEMI)) {
  cat("\n", c(s1 = "STAGE 1", s2 = "STAGE 2 (CONDITIONAL)", unc = "UNCONDITIONAL")[s], "- expenditure and own-price elasticities, bootstrap s.e.:\n")
  print(TAB[[s]]$spesa %>% select(category, mean_share, expenditure_elasticity, se) %>%
          left_join(TAB[[s]]$propria %>% select(category, marshall, marshall_se, hicks, hicks_se), by = "category") %>%
          mutate(across(-category, ~ round(.x, 3))))
}


## =============================================================================
## 12. SAVE THE RESULTS (separate folder)      (MODIFIED: separate sheets for stage 1, stage 2, unconditional)
## =============================================================================
controlli <- data.frame(check = c(
  "item rows used (household x item)", "households read", "unit values", "outlier unit values (excluded from the medians)",
  "purchases revalued (spending missing or outlier unit value)", "items with an imputed value",
  "mean share of the food budget imputed (%)", "mean share of the protein budget imputed (%)",
  "households with zero food budget (excluded)", "households with zero protein budget (excluded from stage 2)",
  "households in the stage-1 estimation", "households in the stage-2 estimation",
  "stage 1: households NOT consuming the residual group 'other' (%) - zeros not modelled",
  "stage 2: households NOT consuming the residual 'plant_protein' (%) - zeros not modelled",
  "stage 1: joint F of the instrument (cluster-robust)", "stage 2: joint F of the 4 instruments (cluster-robust)",
  "symmetry restrictions stage 1", "symmetry restrictions stage 2", "successful bootstrap replications", "bootstrap clusters"),
  value = c(nrow(voci), nrow(famiglie), sum(!is.na(voci$uv)), sum(voci$flag_uv_anomalo), sum(voci$flag_acq_rivalutato, na.rm = TRUE),
            sum(voci$flag_imputato), round(100 * mean(dati$quota_imputata), 2), round(100 * mean(dati$quota_imputata_prot, na.rm = TRUE), 2),
            n_budget_zero, n_prot_zero, nrow(stima1), nrow(stima2),
            round(100 * mean(stima1[[paste0("w1_", RES1)]] == 0), 2), round(100 * mean(stima2[[paste0("w2_", RES2)]] == 0), 2),
            round(fit1$strumenti$joint_F_cluster[1], 1), round(fit2$strumenti$joint_F_cluster[1], 1),
            length(SPEC1$simm), length(SPEC2$simm), sum(ok), K))
coeff <- function(fit) data.frame(coefficient = names(fit$b), estimate = fit$b, se_systemfit = fit$es_systemfit, row.names = NULL)
parametri <- function(fit) data.frame(group = fit$S$gruppi, alfa = fit$alfa, beta = fit$beta, delta = fit$delta, fit$gam, row.names = NULL, check.names = FALSE)
pb <- function(fit) bind_rows(lapply(fit$S$GS, function(g) data.frame(group = g, variable = names(fit$probit[[g]]), coefficient = fit$probit[[g]], row.names = NULL)))
test_v_hat <- function(fit) { n <- paste0(fit$S$EQ, "_", fit$S$EQ, "_v_hat")
  data.frame(stage = fit$S$nome, equation = fit$S$GS, coefficient_v_hat = fit$b[n], se_systemfit = fit$es_systemfit[n],
             t = fit$b[n] / fit$es_systemfit[n], row.names = NULL) }
nota <- data.frame(notes = c(
  "Two-stage LA/AIDS, Tanzania NPS 2008-2020. Weak separability is assumed, not tested.",
  "Stage 1 (s1_ sheets): shares of the food budget of staples, proteins, fruits_veg, other. Expenditure elasticity = with respect to the FOOD budget.",
  "Stage 2 (s2_ sheets): CONDITIONAL shares of the protein budget of 9 categories. Elasticities are CONDITIONAL: the protein budget is held fixed; expenditure elasticity = with respect to the PROTEIN budget.",
  "Unconditional (unc_ sheets): protein categories with respect to the FOOD budget and all food prices, both stages re-optimised (Edgerton 1997):",
  "   E_k = E_k|P * E_P ;  e_kj = e_kj|P + E_k|P * wbar_j|P * (1 + e_PP) ;  e_ks = E_k|P * e_Ps ;  Hicks: e*_kj = e_kj + E_k * w_j (w_j = share in the food budget).",
  "   unc_ price columns: the 9 protein categories, then staples, fruits_veg, other (prices of the other stage-1 groups).",
  "Residual equations (not estimated, obtained by adding-up): 'other' in stage 1, 'plant_protein' in stage 2. Their zeros are not modelled (see checks).",
  "Elasticities at the sample means of the estimation sample. se and 95% intervals: cluster bootstrap (section 11), B replications, same clusters for both stages.",
  "Marshall = uncompensated; Hicks = compensated (Slutsky). Matrices: rows = category that reacts, columns = price that changes; *_se sheets: their standard errors.",
  "Control function: stage 1 instrument ln(total expenditure); stage 2 instruments ln(total expenditure), ln P staples, ln P fruits_veg, ln P other. Sheet first_stage.",
  "SUR coefficients and v_hat tests: systemfit standard errors, NOT corrected for the estimated regressors (Phi, phi, v_hat): use the bootstrap for inference."))
wb <- createWorkbook()
fogli <- list(notes = nota, checks = controlli, item_mapping = as.data.frame(tab_voci), shares = tab_quote,
              first_stage = bind_rows(fit1$strumenti, fit2$strumenti), v_hat_test = bind_rows(test_v_hat(fit1), test_v_hat(fit2)))
for (s in names(SISTEMI)) {
  fogli[[paste0(s, "_expenditure")]] <- TAB[[s]]$spesa;    fogli[[paste0(s, "_own_price")]]   <- TAB[[s]]$propria
  fogli[[paste0(s, "_marshall")]]    <- TAB[[s]]$marshall; fogli[[paste0(s, "_marshall_se")]] <- TAB[[s]]$marshall_se
  fogli[[paste0(s, "_hicks")]]       <- TAB[[s]]$hicks;    fogli[[paste0(s, "_hicks_se")]]    <- TAB[[s]]$hicks_se
}
fogli$by_round <- tab_round
fogli$s1_AIDS_parameters <- parametri(fit1); fogli$s2_AIDS_parameters <- parametri(fit2)
fogli$s1_SUR_coefficients <- coeff(fit1);    fogli$s2_SUR_coefficients <- coeff(fit2)
fogli$s1_probit <- pb(fit1);                 fogli$s2_probit <- pb(fit2)
for (s in names(fogli)) { addWorksheet(wb, s); writeData(wb, s, fogli[[s]]) }
saveWorkbook(wb, file.path(USCITA, "risultati_LAAIDS_2stadi_TZA.xlsx"), overwrite = TRUE)
write.csv(dati,  file.path(USCITA, "famiglie_quote_prezzi.csv"), row.names = FALSE)           # estimation dataset, with the flags
write.csv(voci %>% select(round, hhid, codice_voce, voce, categoria, stadio1, stadio2, cella, uv, flag_uv_anomalo, liv_prezzo_auto, liv_prezzo_regali,
                          val_acq, val_auto, val_regali, val_solo_tot, val_tot, flag_acq_rivalutato, flag_imputato, flag_senza_valore),
          file.path(USCITA, "voci_valori_flag.csv"), row.names = FALSE)
saveRDS(list(spesa = boot_spesa, marshall = boot_marsh, hicks = boot_hicks, per_round = boot_round), file.path(USCITA, "repliche_bootstrap.rds"))
cat("\nResults saved in:", USCITA, "\n")
