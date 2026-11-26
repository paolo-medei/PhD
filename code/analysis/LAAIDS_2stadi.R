###############################################################################
##  TWO-STAGE LA/AIDS, ONE COUNTRY AT A TIME: TANZANIA, ETHIOPIA, MALAWI, NIGERIA, UGANDA
##  Choose the country in section 0 (PAESE <- "TZA", "ETH", "MWI", "NGA" or "UGA"): it is the only line to change.
##  From the harmonised raw data to conditional and unconditional elasticities
##  Teaching script: run it one section at a time (select the lines in RStudio and press Ctrl+Enter).
##
##  THE IDEA: TWO-STAGE BUDGETING
##  The household is assumed to decide in two steps.
##    Stage 1: it splits its FOOD budget (x_food) among 4 broad groups
##             staples | proteins | fruits and vegetables | other foods
##    Stage 2: it splits its PROTEIN budget (x_prot) among 9 protein categories
##             beef | sheep and goat | pork and other meat | poultry | fish | fluid milk |
##             other dairy | eggs | plant proteins          (Ethiopia: 8, there is no pork in the questionnaire)
##  Why two separate steps are allowed: WEAK SEPARABILITY. We assume that the way the household divides
##  its protein budget depends only on (a) the size of the protein budget and (b) the prices of the protein
##  categories. The price of maize or of tomatoes can change the protein budget (stage 1), but it does not
##  change, by itself, the split between beef and fish (stage 2).
##  Weak separability is an ASSUMPTION of the model: this script does NOT test it.
##
##  DATA: <country>_dati_grezzi_LAAIDS_<date>.xlsx (same layout for the 5 countries; built by tza_dati_grezzi.R and
##        dati_grezzi_LAAIDS.R; read the sheet LEGGIMI of each file for what the questionnaire asks)
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
##   - elasticities AVERAGED OVER THE HOUSEHOLDS (average marginal effects / mean share): stage 1, stage 2
##     (conditional), unconditional (Edgerton 1997); the old "at the sample means" version is kept as a robustness check
##   - main table (section 14): elasticities with respect to TOTAL expenditure, with and without control function,
##     for the categories and for aggregates (meat, meat and fish, dairy, all animal-source foods), split into
##     current buyers and new buyers
##   - standard errors: cluster bootstrap (resample the sampling clusters and redo the whole estimation)
##
##  WHAT CHANGES BETWEEN COUNTRIES (only in sections 0-4; from section 5 on the code is the same for all)
##   - units: Tanzania grams -> kg and ml -> litres; the other countries keep their original unit codes
##     (a price is always per unit of the same item). Malawi and Nigeria 2018-2023: the unit is code + size (taglia).
##   - Nigeria 2012-2015: the value of purchases is the quantity CONSUMED from purchases (q_da_acq) x the household's
##     own unit value (spending / quantity bought), or x the local price if the units differ.
##   - Nigeria 2018-2023: no 7-day purchases in the questionnaire: prices come from the LAST purchase in 30 days
##     (spesa_ultacq / q_ultacq) and the value of purchases = quantity consumed from purchases x local price.
##   - Uganda: own production and gifts are valued at local prices like everywhere else (the values reported by
##     the households are not used). Malawi and Uganda: ready food bought from vendors (food away) is left out.
##   - Ethiopia: no pork in the questionnaire, so no "pork and other meat" category (camel meat, 4 households in
##     2021, goes to beef).
##   - robustness (section 13): another residual in stage 2, no control function, elasticities at the sample means,
##     split of the expenditure elasticity into "current buyers" and "new buyers"
##
##  ITALIAN WORDS USED IN THE NAMES (the dataset is in Italian, and the names are kept as in the dataset)
##    voci = food items          famiglie = households       dati = household data (one row per household)
##    spesa = expenditure        quota = share               prezzo = price          valore = value
##    acq = purchases            auto = own production       regali = gifts          stima = estimation sample
##    ampiezza = household size  rurale = rural (1/0)        capo_donna = female head (1/0)
##    livello = geographic level of a price                  stadio1 / stadio2 = stage 1 / stage 2
##    cella = "price cell": the group (stage 1) or category (stage 2) of an item, used to build prices
##
##  PACKAGES: install.packages(c("readxl", "dplyr", "tidyr", "openxlsx"))
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
library(openxlsx)

PAESE  <- "TZA"   # <-- the country: "TZA" Tanzania, "ETH" Ethiopia, "MWI" Malawi, "NGA" Nigeria, "UGA" Uganda
EF_REGIONE <- TRUE    # TRUE: region dummies (regional fixed effects) in all equations of both stages (section 8.7b).
                      # Recommended: without them, prices also pick up regional differences in tastes (Uganda: the
                      # own-price elasticity of proteins comes out positive). FALSE = the specification used before.
NOME_PAESE <- c(TZA = "Tanzania", ETH = "Ethiopia", MWI = "Malawi", NGA = "Nigeria", UGA = "Uganda")[PAESE]
CARTELLA <- "C:/Users/Medei/Desktop/PhD_v21/data/OUTPUT"
FILE   <- file.path(CARTELLA, paste0("analisi_", PAESE),
                    c(TZA = "TZA_dati_grezzi_LAAIDS_2026-11-24.xlsx", ETH = "ETH_dati_grezzi_LAAIDS_2026-11-25.xlsx",
                      MWI = "MWI_dati_grezzi_LAAIDS_2026-11-25.xlsx", NGA = "NGA_dati_grezzi_LAAIDS_2026-11-25.xlsx",
                      UGA = "UGA_dati_grezzi_LAAIDS_2026-11-25.xlsx")[PAESE])
USCITA <- file.path(dirname(FILE), paste0("risultati_LAAIDS_2stadi_", PAESE, if (EF_REGIONE) "" else "_senza_EF", "_", Sys.Date()))   # new folder: the input data are never touched
dir.create(USCITA, showWarnings = FALSE)

N_MIN  <- 5     # minimum number of purchases needed to compute a local median price
SOGLIA <- 10    # outlier price: more than 10 times, or less than 1/10 of, the national median of the same item and unit
B      <- 200   # bootstrap replications (section 11); for a quick test use 20
B_ROB  <- 200   # bootstrap replications of the robustness checks (section 13); 0 = point estimates only
SEME   <- 2026  # random seed: with the same seed the bootstrap always gives the same numbers

# 0.1 FROM ITEMS TO THE TWO STAGES
# Every item of the dictionary (sheet "voci") has a "categoria" (the same 26 categories in the 5 countries).
# The table below says, for each categoria, its stage-1 group (stadio1) and, for proteins only, its stage-2
# category (stadio2). NA = not a protein. Decisions (Paolo, 24-25 November 2026):
#  - sheep_goat: goat and sheep (mutton) only.
#  - pork_other_meat: pork + other meat (domestic and wild, game, offal, small animals) + processed meat
#    (sausages, corned beef). Other meat alone is too small for its own category (Tanzania: 121 households in 5
#    rounds, no national price in 2020); together with pork it has prices in every round.
#  - fish: fresh fish + dried, salted, smoked, canned and packaged fish.
#  - fluid_milk: fresh milk only. other_dairy: everything else (powder and tinned milk, yoghurt, cheese, cream,
#    butter and ghee from milk, fermented milk, infant formula).
#  - plant_protein: dry and fresh pulses, groundnuts, soy, nuts, seeds (Tanzania: green beans 4012, 2020 only,
#    were inside item 401 before 2020, so they stay here).
#  - staples = cereals + starches; fruits_veg = fruits (coconut included) + vegetables;
#    other = oils and fats, sugar and sweets, spices and salt, beverages, other foods.
#  (Already out of the files: khat, kola nut, tobacco, butter-margarine mixes, insects, snails, "other (specify)".
#   Food bought ready from vendors in Malawi and Uganda - categoria food_away - is removed in section 1.)
MAPPA <- read.table(header = TRUE, stringsAsFactors = FALSE, text = "
categoria          stadio1      stadio2
cereals            staples      NA
starches           staples      NA
beef               proteins     beef
goat_sheep         proteins     sheep_goat
pork               proteins     pork_other_meat
meat_other         proteins     pork_other_meat
processed_red_meat proteins     pork_other_meat
poultry            proteins     poultry
fish_fresh         proteins     fish
fish_processed     proteins     fish
milk_fresh         proteins     fluid_milk
dairy_processed    proteins     other_dairy
eggs               proteins     eggs
pulses_dry         proteins     plant_protein
pulses_fresh       proteins     plant_protein
groundnuts         proteins     plant_protein
soy                proteins     plant_protein
nuts               proteins     plant_protein
seeds              proteins     plant_protein
fruits             fruits_veg   NA
vegetables         fruits_veg   NA
oils_fats          other        NA
sugar_sweets       other        NA
spices_other       other        NA
beverages          other        NA
other_food         other        NA
")
# Ethiopia: no pork in the questionnaire and "other meat" is only camel meat (4 households in 2021): it goes to beef
if (PAESE == "ETH") {
  MAPPA$stadio2[MAPPA$categoria == "meat_other"] <- "beef"
  MAPPA <- MAPPA[!MAPPA$categoria %in% c("pork", "processed_red_meat"), ]   # not in the Ethiopian questionnaire
}

# 0.2 The groups of each stage. THE LAST ONE OF EACH LIST IS THE RESIDUAL: its equation is not estimated,
#     it is obtained from adding-up (section 9.6). It must be the most commonly consumed group/category.
STAGE1 <- c("staples", "proteins", "fruits_veg", "other")
STAGE2 <- c("beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs", "plant_protein")
if (PAESE == "ETH") STAGE2 <- setdiff(STAGE2, "pork_other_meat")            # 8 categories in Ethiopia
ALTRI1 <- setdiff(STAGE1, "proteins")              # the 3 stage-1 groups that are not proteins
CELLE  <- c(STAGE2, ALTRI1)                         # 12 "price cells" (11 in Ethiopia): every item belongs to exactly one
DEMO   <- c("ln_ampiezza", "rurale", "capo_donna")  # demographic variables in all equations
# 0.3 AGGREGATES of protein categories, reported in the main table (section 14) to compare with studies that use
#     broad groups ("meat", "dairy"). Not estimated: computed from the category elasticities (section 10.2b).
AGGREGATI <- list(meat                = c("beef", "sheep_goat", "pork_other_meat", "poultry"),
                  meat_and_fish       = c("beef", "sheep_goat", "pork_other_meat", "poultry", "fish"),
                  dairy               = c("fluid_milk", "other_dairy"),
                  animal_source_foods = c("beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs"))
AGGREGATI <- lapply(AGGREGATI, intersect, STAGE2)  # Ethiopia: no pork_other_meat
stopifnot(PAESE %in% c("TZA", "ETH", "MWI", "NGA", "UGA"), setequal(MAPPA$stadio1, STAGE1), setequal(na.omit(MAPPA$stadio2), STAGE2),
          all(!is.na(MAPPA$stadio2) == (MAPPA$stadio1 == "proteins")))   # check: stage-2 category only for proteins


## =============================================================================
## 1. LOAD THE DATA
## =============================================================================
dati_grezzi <- read_excel(FILE, sheet = "dati", guess_max = 1e5)   # one row per household x round (original values)
dizionario  <- read_excel(FILE, sheet = "voci")                     # item code -> item name, categoria, gruppo (by round)
cat("Households read:", nrow(dati_grezzi), " columns:", ncol(dati_grezzi), "\n")
stopifnot(!anyDuplicated(dati_grezzi[, c("round", "hhid")]))      # check: no household appears twice in a round

# out: the 419 households of the 2020 sample hh_sec_j1, which answered a different consumption module (Tanzania only)
dati_grezzi <- dati_grezzi %>% mutate(campione = coalesce(as.character(campione), "")) %>% filter(campione != "hh_sec_j1")

# unit codes as text in every country (Malawi has codes like "10B"); Uganda: the values of own production and gifts
# reported by the households are renamed and NOT used (decision: valued at local prices, as in the other countries)
for (v in grep("^c[0-9]+_(u_|taglia_|acq_30gg)", names(dati_grezzi), value = TRUE)) dati_grezzi[[v]] <- as.character(dati_grezzi[[v]])
names(dati_grezzi) <- sub("_val_(auto|regali)$", "_val_\\1_dichiarato", names(dati_grezzi))

# 1.1 Household characteristics: all the columns that are not items (item columns start with "c" + a number)
col_voci <- grep("^c[0-9]+_", names(dati_grezzi), value = TRUE)
famiglie <- dati_grezzi %>% select(-all_of(col_voci))

# 1.2 Items: the price calculations need one row per household x item. The columns c<code>_<variable> of each
#     item become rows: one per household that consumed the item, with its variables side by side. (Item by item,
#     not with one pivot_longer of the whole sheet: the Malawi file is too big for that.)
#     Then each item gets its categoria from the dictionary, and through MAPPA its stage-1 group and
#     stage-2 category. "cella" = stage-2 category for proteins, stage-1 group for the others.
CODICI <- unique(sub("^c([0-9]+)_.*$", "\\1", col_voci))
voci <- bind_rows(lapply(CODICI, function(k) {
  cc <- grep(paste0("^c", k, "_"), col_voci, value = TRUE)
  x <- dati_grezzi[, c("round", "hhid", "campione", cc)]
  names(x) <- sub(paste0("^c", k, "_"), "", names(x))
  x <- x[rowSums(!is.na(x[, intersect(c("q_tot", "q_acq", "spesa_acq", "q_auto", "q_regali", "q_da_acq", "q_ultacq"), names(x)), drop = FALSE])) > 0, ]
  x$codice_voce <- as.numeric(k)
  x })) %>%
  relocate(codice_voce, .after = campione) %>%
  left_join(dizionario %>% mutate(campione = coalesce(as.character(campione), "")) %>% select(round, campione, codice_voce, voce, categoria),
            by = c("round", "campione", "codice_voce"))
# variables that only some countries have: created empty where they do not exist, so the code is the same for all
for (v in c("taglia_tot", "taglia_acq", "taglia_auto", "taglia_regali", "q_da_acq", "u_da_acq", "q_ultacq", "u_ultacq", "taglia_ultacq", "spesa_ultacq"))
  if (!v %in% names(voci)) voci[[v]] <- if (grepl("^(u_|taglia_)", v)) NA_character_ else NA_real_
# ready food bought from vendors or restaurants (Malawi, Uganda): not food consumed at home -> out
cat("Food away from home recorded in the food module (removed):", sum(voci$categoria %in% "food_away"), "rows\n")
voci <- voci %>% filter(!categoria %in% "food_away") %>%
  left_join(MAPPA, by = "categoria") %>%
  mutate(cella = coalesce(stadio2, stadio1))
cat("Consumed items (household x item):", nrow(voci), " without categoria:", sum(is.na(voci$categoria)),
    " without stage:", sum(is.na(voci$stadio1)), "\n")
stopifnot(!anyNA(voci$categoria), !anyNA(voci$stadio1), all(voci$cella %in% CELLE))   # every item is classified
# every group and category must be consumed in every round (otherwise it has no price in that round)
presenti <- voci %>% distinct(round, cella) %>% count(cella)
mancanti <- setdiff(CELLE, presenti$cella[presenti$n == n_distinct(voci$round)])
if (length(mancanti) > 0) stop("Not consumed in every round: ", paste(mancanti, collapse = ", "))

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
# 2.1 Units. The key of a unit is its original code (text). Tanzania: grams become kg (code 1) and millilitres
#     litres (code 3), as in the one-stage script. Malawi and Nigeria 2018-2023: code + size ("10B|2"), because the
#     same code in different sizes is a different unit. A price is always "per unit" of the same item.
#     Nigeria 2018-2023: own production, gifts and consumption from purchases are asked in the unit of the total.
chiave <- function(u, taglia) ifelse(is.na(u), NA, ifelse(is.na(taglia), u, paste0(u, "|", taglia)))
if (PAESE == "TZA") {
  voci <- voci %>% mutate(
    q_acq_s    = ifelse(u_acq    %in% c("2", "4"), q_acq    / 1000, q_acq),
    u_acq_s    = ifelse(u_acq    == "2", "1", ifelse(u_acq    == "4", "3", u_acq)),
    q_auto_s   = ifelse(u_auto   %in% c("2", "4"), q_auto   / 1000, q_auto),
    u_auto_s   = ifelse(u_auto   == "2", "1", ifelse(u_auto   == "4", "3", u_auto)),
    q_regali_s = ifelse(u_regali %in% c("2", "4"), q_regali / 1000, q_regali),
    u_regali_s = ifelse(u_regali == "2", "1", ifelse(u_regali == "4", "3", u_regali)),
    q_tot_s    = ifelse(u_tot    %in% c("2", "4"), q_tot    / 1000, q_tot),
    u_tot_s    = ifelse(u_tot    == "2", "1", ifelse(u_tot    == "4", "3", u_tot)))
} else {
  voci <- voci %>% mutate(
    q_acq_s = q_acq, u_acq_s = chiave(u_acq, taglia_acq), q_auto_s = q_auto, u_auto_s = chiave(u_auto, taglia_auto),
    q_regali_s = q_regali, u_regali_s = chiave(u_regali, taglia_regali), q_tot_s = q_tot, u_tot_s = chiave(u_tot, taglia_tot))
}
voci <- voci %>% mutate(q_da_acq_s = q_da_acq, u_da_acq_s = u_da_acq)
voci$ultimo <- PAESE == "NGA" & voci$round %in% c(2018, 2023)       # Nigeria 2018-2023: last purchase in 30 days
ULTIMO <- voci$ultimo
voci <- voci %>% mutate(u_auto_s   = ifelse(ULTIMO, u_tot_s, u_auto_s), u_regali_s = ifelse(ULTIMO, u_tot_s, u_regali_s),
                        u_da_acq_s = ifelse(ULTIMO, u_tot_s, u_da_acq_s))

# 2.2 Unit value of a purchase: uv = spending / quantity purchased (local currency per unit), only when both are positive.
#     The purchase that gives the price: the 7-day purchase; Nigeria 2018-2023 the last purchase in 30 days.
voci <- voci %>% mutate(pr_q = ifelse(ULTIMO, q_ultacq, q_acq_s), pr_v = ifelse(ULTIMO, spesa_ultacq, spesa_acq),
                        pr_u = ifelse(ULTIMO, chiave(u_ultacq, taglia_ultacq), u_acq_s),
                        uv = ifelse(pr_q > 0 & pr_v > 0, pr_v / pr_q, NA))

# 2.3 Outlier prices: compared with the national median of the same item and unit in the same round
med_naz_uv <- voci %>% filter(!is.na(uv)) %>% group_by(round, codice_voce, pr_u) %>%
  summarise(med_uv = median(uv), n_uv = n(), .groups = "drop")
voci <- voci %>% left_join(med_naz_uv, by = c("round", "codice_voce", "pr_u")) %>%
  mutate(flag_uv_anomalo = !is.na(uv) & n_uv >= N_MIN & (uv > SOGLIA * med_uv | uv < med_uv / SOGLIA)) %>%
  select(-med_uv, -n_uv)
cat("\nUnit values computed:", sum(!is.na(voci$uv)), " of which outliers (excluded from the medians):", sum(voci$flag_uv_anomalo), "\n")


## =============================================================================
## 3. LOCAL MEDIAN PRICES by item and unit: EA -> district -> region -> country      (unchanged)
## =============================================================================
# the price of an item in a place is the median of the unit values of the purchases made there;
# the smallest level with at least N_MIN purchases is used
voci <- voci %>% left_join(famiglie %>% select(round, hhid, id_ea, id_distretto, regione), by = c("round", "hhid"))
acquisti <- voci %>% filter(!is.na(uv), !is.na(pr_u), !flag_uv_anomalo) %>% mutate(unita = pr_u)

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
pd <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_da_acq_s, id_ea, id_distretto, regione))   # Nigeria
# How purchases are valued:
#   acquisti_7gg        (all countries and rounds, except below): the spending reported for the 7-day purchases
#   consumo_da_acquisti (Nigeria 2012, 2015): quantity CONSUMED from purchases x the household's own unit value
#                       (spending / quantity bought, same unit), else x the local price
#   ultimo_acquisto     (Nigeria 2018, 2023): quantity consumed from purchases x local price (from last purchases)
voci$regime <- ifelse(voci$ultimo, "ultimo_acquisto", ifelse(PAESE == "NGA" & voci$round %in% c(2012, 2015), "consumo_da_acquisti", "acquisti_7gg"))
voci <- voci %>% mutate(
  da_acq     = coalesce(q_da_acq_s, 0) > 0,
  uv_propria = ifelse(regime == "consumo_da_acquisti" & !is.na(uv) & !flag_uv_anomalo & u_da_acq_s == u_acq_s, uv, NA),

  liv_prezzo_auto = ifelse(coalesce(q_auto_s, 0) > 0, pa$livello, NA), liv_prezzo_regali = ifelse(coalesce(q_regali_s, 0) > 0, pr$livello, NA),
  # own production and gifts: value = quantity x local price (0 if the source is not used)
  val_auto   = ifelse(coalesce(q_auto_s, 0) > 0, q_auto_s * pa$prezzo, 0),
  val_regali = ifelse(coalesce(q_regali_s, 0) > 0, q_regali_s * pr$prezzo, 0),
  # purchases: the reported spending; if it is missing, or the unit value is an outlier, quantity x local price
  #            (Nigeria: see above; flag_acq_rivalutato = valued at the local price)
  flag_acq_rivalutato = (regime == "acquisti_7gg" & coalesce(q_acq_s, 0) > 0 & (is.na(spesa_acq) | spesa_acq <= 0 | flag_uv_anomalo)) |
                        (regime != "acquisti_7gg" & da_acq & is.na(uv_propria)),
  val_acq    = case_when(regime == "acquisti_7gg" & flag_acq_rivalutato            ~ q_acq_s * pq$prezzo,
                         regime == "acquisti_7gg" & coalesce(spesa_acq, 0) > 0     ~ spesa_acq,
                         regime == "acquisti_7gg"                                  ~ 0,
                         regime == "consumo_da_acquisti" & is.na(q_da_acq_s) & coalesce(spesa_acq, 0) > 0 ~ spesa_acq,  # no quantity: the spending
                         !da_acq                                                   ~ 0,
                         !is.na(uv_propria)                                        ~ q_da_acq_s * uv_propria,
                         TRUE                                                      ~ q_da_acq_s * pd$prezzo),
  # item consumed but no source filled in: the total quantity is valued
  flag_solo_totale = !(coalesce(q_acq_s, 0) > 0) & !(coalesce(q_auto_s, 0) > 0) & !(coalesce(q_regali_s, 0) > 0) & !(coalesce(spesa_acq, 0) > 0) & !da_acq,
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
# 6.1 Value of each cell: the 9 protein categories + staples, fruits_veg, other (v_<cell>, local currency, 7 days)
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
# 7.1 STAGE 1. Food budget x_food = staples + proteins + fruits_veg + other (food consumed at home, 7 days, local currency)
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

# 8.7b Regional fixed effects (only if EF_REGIONE is TRUE): one dummy per region (the largest region is the base).
#      They take away the differences between regions that are not due to prices or income (tastes, climate,
#      religion, ...); prices are then measured only from the differences WITHIN a region (districts, EAs, rounds).
if (EF_REGIONE) {
  reg <- as.character(dati$regione); livelli <- names(sort(table(reg), decreasing = TRUE))
  for (l in livelli[-1]) dati[[paste0("reg_", make.names(l))]] <- as.numeric(reg == l)
  DEMO <- c(DEMO, paste0("reg_", make.names(livelli[-1])))
  cat("Regional fixed effects:", length(livelli) - 1, "dummies\n")
}

# 8.7c CONSUMPTION QUINTILES (used for the results by quintile, sections 10.4b and 14, and for the descriptive tables)
#      Quintile of total consumption PER PERSON (official aggregate / household size), within each round, with
#      weights = survey weight x household size, so that every quintile holds 20% of the PEOPLE of the country.
#      Quintile 1 = the poorest 20%. Households without a weight still get the quintile of their consumption.
quintile_pesato <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  o  <- order(x[ok]); cw <- cumsum(w[ok][o]) / sum(w[ok])
  tagli <- sapply(c(0.2, 0.4, 0.6, 0.8), function(p) x[ok][o][which(cw >= p)[1]])    # the 4 cut-off points
  findInterval(x, tagli, left.open = TRUE) + 1                                        # 1 ... 5 (NA stays NA)
}
dati <- dati %>% group_by(round) %>% mutate(quintile = quintile_pesato(spesa_totale_annua / ampiezza, peso * ampiezza)) %>%
  ungroup() %>% as.data.frame()
cat("Households by quintile (all rounds):\n"); print(table(dati$quintile, useNA = "ifany"))

# 8.8 Clean-up: the large intermediate objects are no longer needed (the bootstrap needs memory)
rm(dati_grezzi, griglia, pp, pg, pa, pr, pq, pt, pd); invisible(gc())


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
#     cf = TRUE (default): with the control function. cf = FALSE is used only in the robustness check of section 13.
prepara_spec <- function(S) {
  if (is.null(S$cf)) S$cf <- TRUE
  S$GS   <- head(S$gruppi, -1)                                  # estimated groups (the residual is the last one)
  S$res  <- tail(S$gruppi, 1)                                   # residual group: equation omitted
  S$PREL <- paste0(S$p, S$GS)                                   # relative prices ln(p_j / p_residual)
  S$X    <- c(S$PREL, S$x_reale, DEMO, ROUND, if (S$cf) "v_hat")   # regressors of the probits and of the shares
  S$EQ   <- setNames(gsub("_", "", S$GS), S$GS)                 # equation names without "_" (as in systemfit, see 9.4b)
  # Symmetry: gamma_ij = gamma_ji for i, j among the estimated groups (homogeneity is already imposed by the
  # relative prices). A coefficient is called "<equation>_<regressor>", e.g. "beef_beef_lnp2_pork";
  # "fruits_veg" is called "fruitsveg" in the system, "pork_other_meat" is "porkothermeat", etc.
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

# 9.4b SUR with linear restrictions, written out. It is the same estimator as systemfit(method = "SUR") used in the
#      one-stage script: (1) OLS of all equations with the restrictions, (2) covariance Sigma of the residuals of the
#      equations, (3) GLS with Sigma and the restrictions. Written here because systemfit builds very large matrices
#      and runs out of memory with the Malawi sample (47,000 households x 8 equations); it is also much faster.
#      Restricted GLS: minimise (y - Xb)' (Sigma^-1 x I) (y - Xb) subject to R b = 0 (the symmetry restrictions).
#      The solution solves the linear system [A R'; R 0] [b; lambda] = [c; 0], with A = X'(Sigma^-1 x I)X and
#      c = X'(Sigma^-1 x I)y; the blocks of A are Sigma^ij X_i'X_j, so only small k x k matrices are needed.
#      The standard errors (top-left block of the inverse of the system matrix) ignore that Phi, phi and v_hat are
#      estimated: they are reported only for reference; inference uses the bootstrap (section 11).
sur_vincolato <- function(d, eqs, simm, varianza = FALSE) {
  M <- length(eqs); n <- nrow(d)
  X <- lapply(eqs, function(q) as.matrix(d[, q$x])); Y <- sapply(eqs, function(q) d[[q$y]])
  # every column divided by its size (root of the sum of squares): same estimates, but the system stays well
  # conditioned even when some columns are very small (Phi close to 0); coefficients are rescaled at the end
  sc <- unlist(lapply(X, function(x) sqrt(colSums(x^2))))
  X <- lapply(X, function(x) sweep(x, 2, sqrt(colSums(x^2)), "/"))
  k <- sapply(X, ncol); fine <- cumsum(k); inizio <- fine - k + 1; K <- sum(k)
  nomi <- unlist(lapply(names(eqs), function(e) paste0(e, "_", eqs[[e]]$x)))
  XX <- XY <- vector("list", M * M); dim(XX) <- dim(XY) <- c(M, M)
  for (i in 1:M) for (j in 1:M) { XX[[i, j]] <- crossprod(X[[i]], X[[j]]); XY[[i, j]] <- crossprod(X[[i]], Y[, j]) }
  # restrictions: each string "a - b = 0" becomes a row of R with +1 for coefficient a and -1 for coefficient b
  R <- matrix(0, length(simm), K, dimnames = list(NULL, nomi))
  for (r in seq_along(simm)) { ab <- strsplit(sub(" = 0$", "", simm[r]), " - ")[[1]]; R[r, ab[1]] <- 1; R[r, ab[2]] <- -1 }
  R <- sweep(R, 2, sc, "/")                                         # restrictions on the rescaled coefficients
  gls <- function(Sinv) {
    A <- matrix(0, K, K); cc <- numeric(K)
    for (i in 1:M) for (j in 1:M) {
      A[inizio[i]:fine[i], inizio[j]:fine[j]] <- Sinv[i, j] * XX[[i, j]]
      cc[inizio[i]:fine[i]] <- cc[inizio[i]:fine[i]] + Sinv[i, j] * XY[[i, j]]
    }
    sistema <- rbind(cbind(A, t(R)), cbind(R, matrix(0, nrow(R), nrow(R))))
    list(b = solve(sistema, c(cc, rep(0, nrow(R))))[1:K], sistema = sistema)
  }
  residui <- function(b) sapply(1:M, function(i) Y[, i] - X[[i]] %*% b[inizio[i]:fine[i]])
  passo1 <- gls(diag(M))                                            # (1) OLS with the restrictions
  E <- residui(passo1$b)
  Sigma <- crossprod(E) / sqrt(outer(n - k, n - k))                 # (2) residual covariance (degrees of freedom as systemfit)
  passo2 <- gls(solve(Sigma))                                       # (3) GLS with the restrictions
  E <- residui(passo2$b)
  b <- setNames(passo2$b / sc, nomi)                                # back to the original units
  r2 <- setNames(1 - colSums(E^2) / colSums(sweep(Y, 2, colMeans(Y))^2), names(eqs))
  es <- if (varianza) setNames(sqrt(diag(solve(passo2$sistema))[1:K]) / sc, nomi) else NULL
  list(b = b, r2 = r2, es = es)
}

# 9.5 The estimation, written ONCE as a function, because the bootstrap (section 11) repeats it many times.
#     In: a sample d and a spec S. Out: the parameters and the sample columns needed for the elasticities.
#     (glm objects are large: only their coefficients are kept, so the bootstrap does not run out of memory.)
stima_laaids <- function(d, S, stampa = FALSE) {

  # (a) Control function, step (1): endogenous real expenditure on the instruments and on all the exogenous regressors
  esogene <- c(S$PREL, DEMO, ROUND)
  cf <- lm(as.formula(paste(S$x_reale, "~", paste(c(S$strumenti, esogene), collapse = " + "))), data = d)
  d$v_hat <- residuals(cf)                     # (with cf = FALSE it is computed but not used)
  b_cf <- coef(cf)[S$strumenti]                # kept: in stage 1 the coefficient of ln_spesa_tot is used in section 13.2
  strumenti <- NULL
  if (stampa && S$cf) {
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
  #     With regional fixed effects: a region where NOBODY (or EVERYBODY) consumes g predicts consumption perfectly
  #     and its probit coefficient would go to infinity; that region dummy is left out of the probit of g only
  #     (it stays in the share equation of g). E.g. pork in Zanzibar.
  probit <- list()
  for (g in S$GS) {
    d[[paste0("d_", g)]] <- as.numeric(d[[paste0(S$w, g)]] > 0)
    sep <- Filter(function(v) { y <- d[[paste0("d_", g)]][d[[v]] == 1]; length(y) == 0 || all(y == 0) || all(y == 1) },
                  grep("^reg_", S$X, value = TRUE))
    if (stampa && length(sep) > 0) cat("  ", g, ": region dummies left out of the probit (perfect prediction):", paste(sep, collapse = ", "), "\n")
    m <- glm(as.formula(paste0("d_", g, " ~ ", paste(setdiff(S$X, sep), collapse = " + "))), family = binomial(link = "probit"), data = d)
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
  #     A column that is zero in the sample (e.g. a region dummy when the region is not in a bootstrap sample)
  #     cannot be estimated: it is left out of that equation and its coefficient counts as 0.
  eqs <- list()
  for (g in S$GS) {
    e <- S$EQ[g]
    for (v in S$X) d[[paste0(e, "_", v)]] <- d[[paste0("Phi_", g)]] * d[[v]]
    xs <- S$X[sapply(S$X, function(v) max(abs(d[[paste0(e, "_", v)]])) > 1e-8)]
    if (stampa && length(xs) < length(S$X)) cat("  ", g, ": left out (nobody consumes it there):", paste(setdiff(S$X, xs), collapse = ", "), "\n")
    nomi <- c(paste0(e, "_cost"), paste0(e, "_", xs), paste0(e, "_phi"))
    d[[nomi[1]]] <- d[[paste0("Phi_", g)]]                                     # constant a_g
    d[[nomi[length(nomi)]]] <- d[[paste0("phi_", g)]]                          # term delta_g * phi_g
    eqs[[e]] <- list(y = paste0(S$w, g), x = nomi)                            # share and regressors (no intercept)
  }

  # (d) SUR (seemingly unrelated regressions) on all the estimated equations together, with symmetry imposed (9.4b)
  sur <- sur_vincolato(d, eqs, S$simm, varianza = stampa)
  b   <- sur$b
  es_systemfit <- sur$es
  if (stampa) { cat(" ", S$nome, "- SUR estimated. R2 by equation:\n"); print(round(sur$r2, 3)) }
  rm(sur)

  # (e) Parameters of the AIDS part (inside the brackets): matrix gamma, alfa, beta, delta.
  #     ADDING-UP AND THE OMITTED EQUATION. The observed shares sum to 1, but with Shonkwiler-Yen the expected
  #     shares of the estimated equations do not sum to 1 automatically. So the residual equation is NOT estimated:
  #     its expected share is DEFINED as 1 minus the sum of the others. Adding-up then holds exactly, for the shares
  #     and for the elasticities (section 10). Its AIDS parameters below are recovered from the adding-up conditions
  #     (sum of alfa = 1, sum of beta = 0, every column of gamma sums to 0) and are only reported.
  #     The price: the zeros of the residual group are not modelled. This is why the residual must be the most
  #     commonly consumed group: "other" in stage 1 (almost everybody), "plant_protein" in stage 2 (82-95% of the households, depending on the country).
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
  tieni <- c("round", "quintile", paste0(S$w, S$gruppi), paste0("t_", S$GS), S$PREL, S$x_reale, DEMO, ROUND, "v_hat")
  list(d = d[, tieni], S = S, probit = probit, b = b, alfa = alfa, beta = beta, delta = delta, gam = gam,
       strumenti = strumenti, es_systemfit = es_systemfit, b_cf = b_cf)
}

fit1 <- stima_laaids(stima1, SPEC1, stampa = TRUE)       # stage 1 on the real sample
fit2 <- stima_laaids(stima2, SPEC2, stampa = TRUE)       # stage 2 on the real sample


## =============================================================================
## 10. ELASTICITIES (averaged over the households)      (MODIFIED: one function for both stages + unconditional)
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
# v_hat is held at its observed value: the elasticities measure the effect of expenditure net of its endogenous part.
# In stage 1 "x" is the food budget and the prices are group prices; in stage 2 "x" is the PROTEIN budget and the
# prices are category prices: the stage-2 elasticities are CONDITIONAL on the protein budget.
#
# WHERE THE ELASTICITIES ARE EVALUATED (metodo)
#   "media" (DEFAULT, used for all the main results): the derivative dE(w_g)/ds is computed for EVERY household
#     (its own probit index t, its own Phi, phi and AIDS part f) and then averaged over the households of the sample;
#     the average derivative is divided by the mean share:  E_g = 1 + mean_i(dE(w_g)/d ln x)_i / mean share.
#     ("average marginal effects"). It is the response of the average household share, the quantity a policy
#     maker needs.
#   "punto_medio": the derivative of ONE fictitious household that has all the mean values (mean t, mean prices,
#     mean budget). This is what the script did before 26 November 2026; kept as a robustness check (section 13).
#     Why it was changed: the Shonkwiler-Yen model is NON-LINEAR (Phi and phi are curves), so the household "at
#     the means" does not respond like the average household. The difference is large for categories that few
#     households buy: e.g. at the means, beef in Tanzania 2.62 against 2.23 averaged; fish in Ethiopia 1.42 against
#     0.56. Averaged, the results are very close to those of the same model without the zero correction, in all
#     5 countries (check of 26 November 2026), which is what one expects for an average response.
#   Both versions use the same formulas: only Phi_g and phi_g (f_g - delta_g t_g) change, because the derivative is
#   linear in these two terms: averaging the derivative = using the averages of these two terms.
#
# The function uses the parameters of one estimation (fit) and the households of a sample d (all, or one round).
# It also returns the split of the expenditure elasticity used in sections 13.1 and 14:
#   intensiva      = 1 + Phi_g beta_g / w_g                   households that already consume g spend more on it
#   partecipazione = phi_g (f_g - delta_g t_g) c_g / w_g      more households start consuming g
#   (intensiva + partecipazione = expenditure elasticity; NA for the residual group, whose zeros are not modelled)
elasticita <- function(fit, d, metodo = "media") {
  stopifnot(metodo %in% c("media", "punto_medio"))
  S  <- fit$S; GR <- S$gruppi; G <- length(GR)
  w  <- colMeans(d[, paste0(S$w, GR)]); names(w) <- GR                       # mean shares
  dX <- setNames(rep(0, G), GR); dP <- matrix(0, G, G, dimnames = list(GR, GR))
  dX_int <- dX_par <- setNames(rep(NA_real_, G), GR)
  ALTRE <- setdiff(S$X, c(S$PREL, S$x_reale))                                # demographics, rounds (and v_hat)
  for (g in S$GS) {
    cp <- fit$probit[[g]]
    bb <- fit$b[paste0(S$EQ[g], "_", S$EQ[g], "_", ALTRE)]; bb[is.na(bb)] <- 0   # left-out region dummies count as 0
    if (metodo == "media") {
      t <- d[[paste0("t_", g)]]                                              # probit index of EVERY household
      f <- fit$alfa[g] + as.vector(as.matrix(d[, S$PREL]) %*% fit$gam[g, S$GS]) + fit$beta[g] * d[[S$x_reale]] +
           as.vector(as.matrix(d[, ALTRE]) %*% bb)                           # AIDS part of every household
    } else {
      t <- mean(d[[paste0("t_", g)]])                                        # probit index at the means
      f <- fit$alfa[g] + sum(fit$gam[g, S$GS] * colMeans(d[, S$PREL])) + fit$beta[g] * mean(d[[S$x_reale]]) +
           sum(bb * colMeans(d[, ALTRE]))                                    # AIDS part at the means
    }
    Phi <- mean(pnorm(t))                                                    # average probability of consuming
    k   <- mean(dnorm(t) * (f - fit$delta[g] * t))                           # average of phi (f - delta t)
    c_x <- cp[S$x_reale]; c_p <- c(cp[S$PREL], -sum(cp[S$PREL])); names(c_p) <- GR
    dX[g]   <- Phi * fit$beta[g] + k * c_x
    dP[g, ] <- Phi * (fit$gam[g, ] - fit$beta[g] * S$wbar) + k * (c_p - c_x * S$wbar)
    dX_int[g] <- Phi * fit$beta[g]; dX_par[g] <- k * c_x                     # the two parts of dX[g]
  }
  dX[S$res] <- -sum(dX[S$GS]); dP[S$res, ] <- -colSums(dP[S$GS, , drop = FALSE])
  e_spesa <- 1 + dX / w
  marsh   <- -diag(G) + dP / w                       # row g divided by w_g
  hicks   <- marsh + outer(e_spesa, w)
  dimnames(marsh) <- dimnames(hicks) <- list(GR, GR)
  list(w = w, spesa = e_spesa, marshall = marsh, hicks = hicks, intensiva = 1 + dX_int / w, partecipazione = dX_par / w)
}

# Puts a stage-2 result in the order of STAGE2. Needed only when the residual category is changed (section 13.3),
# because then the categories come out of the estimation in a different order.
ordina2 <- function(E) {
  o <- STAGE2
  E$w <- E$w[o]; E$spesa <- E$spesa[o]; E$marshall <- E$marshall[o, o]; E$hicks <- E$hicks[o, o]
  E$intensiva <- E$intensiva[o]; E$partecipazione <- E$partecipazione[o]
  E
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
# Stage-1 terms (E_P, e_PP, e_Ps, w_P) come from the stage-1 sample, stage-2 terms from the stage-2 sample (both
# averaged over households, 10.1; combining averaged elasticities with these formulas is itself an approximation).
elasticita_incondizionate <- function(E1, E2) {
  E2  <- ordina2(E2)                                                      # categories in the order of STAGE2 (as wbar2)
  wP  <- E1$w["proteins"]; EP <- E1$spesa["proteins"]
  ePP <- E1$marshall["proteins", "proteins"]; ePs <- E1$marshall["proteins", ALTRI1]
  spesa <- E2$spesa * EP                                                  # (1)
  marsh <- cbind(E2$marshall + outer(E2$spesa, wbar2) * (1 + ePP),        # (2) columns = protein prices
                 outer(E2$spesa, ePs))                                    # (3) columns = staples, fruits_veg, other prices
  w_col <- c(E2$w * wP, E1$w[ALTRI1])                                     # shares in the food budget of the price columns
  hicks <- marsh + outer(spesa, w_col)                                    # (4)
  dimnames(marsh) <- dimnames(hicks) <- list(STAGE2, c(STAGE2, ALTRI1))
  # current buyers (intensive margin) in unconditional terms: nobody changes buying status in EITHER stage, so the
  # two intensive parts multiply, as the elasticities do in (1). NA for the residual category (zeros not modelled).
  attuali <- E2$intensiva * unname(E1$intensiva["proteins"])
  list(w = E2$w * wP, w_col = w_col, spesa = spesa, marshall = marsh, hicks = hicks, intensiva = attuali)
}

# 10.2b AGGREGATES (meat, meat and fish, dairy, all animal-source foods; defined in section 0.3)
# Many studies estimate broad groups. The elasticities of a group A are obtained from those of its categories,
# with weights s_k = share of category k in the group (mean shares of the food budget):
#   expenditure:           E_A  = sum over k in A of s_k E_k
#   own price (Marshall):  e_AA = sum over k in A of s_k (sum over j in A of e_kj)
#       = response of the group quantity when ALL prices of the group rise by 1% together
#   own price (Hicks):     the same with the compensated elasticities (= e_AA + E_A w_A, Slutsky)
#   current buyers:        sum over k in A of s_k x (current-buyer part of E_k)
aggrega <- function(EU) {
  t(sapply(AGGREGATI, function(A) {
    A <- A[EU$w[A] > 0]                     # a category nobody buys in a group of households (10.4b) has no elasticity
    s <- EU$w[A] / sum(EU$w[A])
    c(share = sum(EU$w[A]), spesa = sum(s * EU$spesa[A]), marshall = sum(s * rowSums(EU$marshall[A, A, drop = FALSE])),
      hicks = sum(s * rowSums(EU$hicks[A, A, drop = FALSE])), intensiva = sum(s * EU$intensiva[A]))
  }))
}

# 10.3 Point estimates: whole sample
E1 <- elasticita(fit1, fit1$d)                 # stage 1
E2 <- elasticita(fit2, fit2$d)                 # stage 2, conditional on the protein budget
EU <- elasticita_incondizionate(E1, E2)        # unconditional (with respect to the food budget and all food prices)
EA <- aggrega(EU)                              # aggregates of protein categories (unconditional)
E_tutti <- list(s1 = E1, s2 = E2, unc = EU)
# the same at the sample means (old method, robustness check in section 13)
E_pm <- list(s1 = elasticita(fit1, fit1$d, "punto_medio"), s2 = elasticita(fit2, fit2$d, "punto_medio"))
E_pm$unc <- elasticita_incondizionate(E_pm$s1, E_pm$s2)

cat("\nAll elasticities: averaged over the households (section 10.1).\n")
cat("STAGE 1 - elasticities with respect to the food budget:\n");     print(round(E1$spesa, 2))
cat("STAGE 1 - own-price elasticities, Marshall:\n");                 print(round(diag(E1$marshall), 2))
cat("STAGE 2 - CONDITIONAL elasticities with respect to the protein budget:\n"); print(round(E2$spesa, 2))
cat("STAGE 2 - CONDITIONAL own-price elasticities, Marshall:\n");     print(round(diag(E2$marshall), 2))
cat("UNCONDITIONAL elasticities with respect to the food budget:\n"); print(round(EU$spesa, 2))
cat("UNCONDITIONAL own-price elasticities, Marshall:\n");             print(round(diag(EU$marshall), 2))
cat("AGGREGATES (unconditional, food budget):\n");                    print(round(EA, 2))
cat("For comparison, UNCONDITIONAL expenditure elasticities at the sample means (old method):\n"); print(round(E_pm$unc$spesa, 2))

# 10.4 Checks (they must be satisfied exactly, up to rounding)
cat("\nChecks:\n")
cat("  adding-up stage 1: sum w_g E_g =", round(sum(E1$w * E1$spesa), 4), "(must be 1)\n")
cat("  adding-up stage 2: sum w_k|P E_k|P =", round(sum(E2$w * E2$spesa), 4), "(must be 1)\n")
cat("  adding-up unconditional: sum_k w_k E_k + sum_s w_s E_s =",
    round(sum(EU$w * EU$spesa) + sum(E1$w[ALTRI1] * E1$spesa[ALTRI1]), 4), "(must be 1)\n")
cat("  homogeneity (max |row sum of Marshall + expenditure elasticity|): stage 1", signif(max(abs(rowSums(E1$marshall) + E1$spesa)), 3),
    " stage 2", signif(max(abs(rowSums(E2$marshall) + E2$spesa)), 3), " unconditional", signif(max(abs(rowSums(EU$marshall) + EU$spesa)), 3), "\n")

# 10.4b RESULTS BY QUINTILE AND AREA (same model, averages within each group of households)
# The parameters are those of the whole sample: what changes between groups are the households over which the
# derivatives are averaged (their shares, their probability of buying, their prices). So a group of poor households
# with low shares and low probabilities gets higher elasticities, as the descriptive data show. The quintiles
# (8.7c) are national; area = rural / urban. Averages are over the sample households (unweighted, like the model).
# Cells: Q1 ... Q5, rural, urban, and the 10 cells quintile x area (some urban cells of the poorest quintiles are
# small: look at n_households in the results).
GRUPPI    <- c(paste0("Q", 1:5), "rural", "urban", paste0("Q", rep(1:5, each = 2), "_", c("rural", "urban")))
RIGHE_TAB <- c(STAGE1, STAGE2, names(AGGREGATI))        # rows of the tables: stage-1 groups, categories, aggregates
MISURE    <- c("spesa", "intensiva", "marshall", "hicks")
filtro <- function(d, g) {                               # TRUE for the households of group g
  q <- suppressWarnings(as.integer(sub("^Q([1-5]).*$", "\\1", g)))
  a <- if (grepl("rural", g)) 1 else if (grepl("urban", g)) 0 else NA
  (is.na(q) | d$quintile %in% q) & (is.na(a) | d$rurale == a)
}
# one group -> matrix RIGHE_TAB x MISURE (food-budget elasticities; x theta later for total expenditure)
per_gruppo <- function(f1, f2, g) {
  e1 <- elasticita(f1, f1$d[filtro(f1$d, g), ]); e2 <- elasticita(f2, f2$d[filtro(f2$d, g), ])
  eu <- elasticita_incondizionate(e1, e2); ea <- aggrega(eu)
  m <- cbind(spesa     = c(e1$spesa, eu$spesa, ea[, "spesa"]),
             intensiva = c(e1$intensiva, eu$intensiva, ea[, "intensiva"]),
             marshall  = c(diag(e1$marshall), diag(eu$marshall), ea[, "marshall"]),
             hicks     = c(diag(e1$hicks), diag(eu$hicks), ea[, "hicks"]))
  m[!is.finite(m)] <- NA                                 # a category nobody in the group buys has no elasticity
  rownames(m) <- RIGHE_TAB; m
}
E_gruppi <- sapply(GRUPPI, function(g) per_gruppo(fit1, fit2, g), simplify = "array")   # RIGHE_TAB x MISURE x GRUPPI
N_gruppi <- sapply(GRUPPI, function(g) sum(filtro(fit2$d, g)))                          # households (stage 2) per group
quota_gr <- sapply(GRUPPI, function(g) { e1 <- elasticita(fit1, fit1$d[filtro(fit1$d, g), ]); e2 <- elasticita(fit2, fit2$d[filtro(fit2$d, g), ])
  wP <- unname(e1$w["proteins"]); c(e1$w, e2$w * wP, sapply(AGGREGATI, function(A) sum(e2$w[A]) * wP)) })   # mean shares of the food budget
rownames(quota_gr) <- RIGHE_TAB
cat("\nUnconditional expenditure elasticities (food budget) by quintile:\n")
print(round(E_gruppi[STAGE2, "spesa", paste0("Q", 1:5)], 2))

# 10.5 Same estimates, round by round (averaged over the households of each round)
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
# of the SUR ignore this and are too small. Moreover, the elasticities are non-linear functions of the parameters.
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
# also kept for sections 13 and 14: the elasticity of the food budget to total expenditure (theta), the two parts of
# the expenditure elasticity (current buyers / new buyers), the aggregates, and the old "at the means" elasticities
boot_theta <- rep(NA_real_, B)
boot_dec   <- lapply(list(s1 = STAGE1, s2 = STAGE2, unc = STAGE2), function(g) array(NA, c(B, length(g), 2),
                                                     dimnames = list(NULL, g, c("intensiva", "partecipazione"))))
boot_agg   <- array(NA, c(B, length(AGGREGATI), ncol(EA)), dimnames = list(NULL, names(AGGREGATI), colnames(EA)))
boot_pm    <- lapply(SISTEMI, function(s) array(NA, c(B, length(s$righe), 2), dimnames = list(NULL, s$righe, c("spesa", "marshall"))))
boot_gr    <- array(NA, c(B, length(RIGHE_TAB), length(MISURE), length(GRUPPI)), dimnames = list(NULL, RIGHE_TAB, MISURE, GRUPPI))   # by quintile and area
set.seed(SEME)
righe1  <- split(seq_len(nrow(stima1)), stima1$cluster)     # rows of each cluster, stage 1
righe2  <- split(seq_len(nrow(stima2)), stima2$cluster)     # rows of each cluster, stage 2
CLUSTER <- names(righe1)
K <- length(CLUSTER)
cat("\nBootstrap:", B, "replications,", K, "clusters. Each replication redoes control function, probits and SUR of both stages.\n")
t0 <- Sys.time()
for (r in seq_len(B)) {
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
  boot_theta[r] <- f1$b_cf["ln_spesa_tot"]
  for (s in c("s1", "s2")) boot_dec[[s]][r, , ] <- cbind(e_b[[s]]$intensiva, e_b[[s]]$partecipazione)
  boot_dec$unc[r, , ] <- cbind(e_b$unc$intensiva, e_b$unc$spesa - e_b$unc$intensiva)
  boot_agg[r, , ] <- aggrega(e_b$unc)
  e_pm <- list(s1 = elasticita(f1, f1$d, "punto_medio"), s2 = elasticita(f2, f2$d, "punto_medio"))
  e_pm$unc <- elasticita_incondizionate(e_pm$s1, e_pm$s2)
  for (s in names(SISTEMI)) boot_pm[[s]][r, , ] <- cbind(e_pm[[s]]$spesa, diag(e_pm[[s]]$marshall))
  boot_gr[r, , , ] <- sapply(GRUPPI, function(g) per_gruppo(f1, f2, g), simplify = "array")
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
coeff <- function(fit) data.frame(coefficient = names(fit$b), estimate = fit$b, se_sur = fit$es_systemfit, row.names = NULL)
parametri <- function(fit) data.frame(group = fit$S$gruppi, alfa = fit$alfa, beta = fit$beta, delta = fit$delta, fit$gam, row.names = NULL, check.names = FALSE)
pb <- function(fit) bind_rows(lapply(fit$S$GS, function(g) data.frame(group = g, variable = names(fit$probit[[g]]), coefficient = fit$probit[[g]], row.names = NULL)))
test_v_hat <- function(fit) { n <- paste0(fit$S$EQ, "_", fit$S$EQ, "_v_hat")
  data.frame(stage = fit$S$nome, equation = fit$S$GS, coefficient_v_hat = fit$b[n], se_sur = fit$es_systemfit[n],
             t = fit$b[n] / fit$es_systemfit[n], row.names = NULL) }
nota <- data.frame(notes = c(
  paste0("Two-stage LA/AIDS, ", NOME_PAESE, " (", paste(ANNI, collapse = ", "), "). Weak separability is assumed, not tested. Regional fixed effects: ",
         if (EF_REGIONE) "yes (region dummies in all equations)." else "no."),
  c(TZA = "Tanzania: grams and millilitres converted to kg and litres; 2020 sample hh_sec_j1 excluded.",
    ETH = "Ethiopia: no pork in the questionnaire (8 protein categories); camel meat (4 households, 2021) in beef. Original unit codes.",
    MWI = "Malawi: unit = code + size; food bought from vendors left out. Original unit codes.",
    NGA = "Nigeria: 2012-2015 purchases = consumption from purchases x own unit value; 2018-2023 prices from the last purchase in 30 days. Unit = code + size in 2018-2023.",
    UGA = "Uganda: own production and gifts valued at local prices (reported values not used); food away from home left out.")[PAESE],
  "Stage 1 (s1_ sheets): shares of the food budget of staples, proteins, fruits_veg, other. Expenditure elasticity = with respect to the FOOD budget.",
  "Stage 2 (s2_ sheets): CONDITIONAL shares of the protein budget of 9 categories. Elasticities are CONDITIONAL: the protein budget is held fixed; expenditure elasticity = with respect to the PROTEIN budget.",
  "Unconditional (unc_ sheets): protein categories with respect to the FOOD budget and all food prices, both stages re-optimised (Edgerton 1997):",
  "   E_k = E_k|P * E_P ;  e_kj = e_kj|P + E_k|P * wbar_j|P * (1 + e_PP) ;  e_ks = E_k|P * e_Ps ;  Hicks: e*_kj = e_kj + E_k * w_j (w_j = share in the food budget).",
  "   unc_ price columns: the 9 protein categories, then staples, fruits_veg, other (prices of the other stage-1 groups).",
  "Residual equations (not estimated, obtained by adding-up): 'other' in stage 1, 'plant_protein' in stage 2. Their zeros are not modelled (see checks).",
  "MAIN RESULTS: sheets main_expenditure and main_own_price (section 14): elasticities with respect to TOTAL expenditure, with and without control function, categories and aggregates, current vs new buyers.",
  "Elasticities AVERAGED OVER THE HOUSEHOLDS of the estimation sample (average derivative / mean share, section 10.1). The old values at the sample means are in rob_comparison (columns at_means_*).",
  "se and 95% intervals: cluster bootstrap (section 11), B replications, same clusters for both stages.",
  "Marshall = uncompensated; Hicks = compensated (Slutsky). Matrices: rows = category that reacts, columns = price that changes; *_se sheets: their standard errors.",
  "Control function: stage 1 instrument ln(total expenditure); stage 2 instruments ln(total expenditure), ln P staples, ln P fruits_veg, ln P other. Sheet first_stage.",
  "SUR coefficients and v_hat tests: standard errors of the SUR, NOT corrected for the estimated regressors (Phi, phi, v_hat): use the bootstrap for inference."))
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
saveWorkbook(wb, file.path(USCITA, paste0("risultati_LAAIDS_2stadi_", PAESE, ".xlsx")), overwrite = TRUE)
write.csv(dati,  file.path(USCITA, "famiglie_quote_prezzi.csv"), row.names = FALSE)           # estimation dataset, with the flags
write.csv(voci %>% select(round, hhid, codice_voce, voce, categoria, stadio1, stadio2, cella, uv, pr_u, flag_uv_anomalo, liv_prezzo_auto, liv_prezzo_regali,
                          val_acq, val_auto, val_regali, val_solo_tot, val_tot, flag_acq_rivalutato, flag_imputato, flag_senza_valore),
          file.path(USCITA, "voci_valori_flag.csv"), row.names = FALSE)
saveRDS(list(spesa = boot_spesa, marshall = boot_marsh, hicks = boot_hicks, per_round = boot_round, aggregati = boot_agg,
             punto_medio = boot_pm, per_gruppo = boot_gr, theta = boot_theta), file.path(USCITA, "repliche_bootstrap.rds"))
cat("\nResults saved in:", USCITA, "\n")


## =============================================================================
## 13. ROBUSTNESS CHECKS      (ADDED)
## =============================================================================
# Checks on the weak points of the main results:
#   (a) the residual category of stage 2 (plant_protein) has no zero correction and gets its elasticity only
#       from adding-up -> 13.3 re-estimates stage 2 with ANOTHER residual: the second most consumed category
#       (fish in Tanzania, Malawi, Nigeria, Uganda; fluid milk in Ethiopia);
#   (b) the expenditure elasticities of meat, dairy and eggs are high -> 13.1 shows how much of each elasticity
#       comes from households that START buying, 13.4 shows what happens WITHOUT the control function, and the
#       comparison table (13.6) also shows the old elasticities AT THE SAMPLE MEANS (section 10.1).
# The elasticities with respect to TOTAL expenditure (theta, 13.2) are in the main table of section 14.
# Run this section after sections 0-12 (it uses their objects). It adds 3 sheets "rob_..." to the results file.

# 13.1 CURRENT BUYERS AND NEW BUYERS (main model, no new estimation)
# With Shonkwiler-Yen the expenditure elasticity has two parts (computed in the function elasticita, section 10.1):
#   intensiva      = 1 + Phi beta / w : households that already consume the category spend more on it
#   partecipazione = the rest          : as the budget grows, more households start consuming the category
# Example: if beef has 1.78 = 1.02 + 0.76, then about 0.76 / 1.78 = 43% of the response comes from new buyers.
# The two parts always sum to the elasticity. With 7-day recall, "new buyers" also includes households that buy
# MORE OFTEN (a household that buys beef every two weeks is a zero in half of the weeks).
# Not available for the residual groups ("other", "plant_protein"): their zeros are not modelled.
tab_scomposizione <- bind_rows(lapply(c("s1", "s2"), function(s) {
  E <- E_tutti[[s]]; bd <- boot_dec[[s]]
  data.frame(system = c(s1 = "stage 1", s2 = "stage 2 (conditional)")[s], category = names(E$spesa),
             mean_share = E$w, expenditure_elasticity = E$spesa, se = apply(boot_spesa[[s]], 2, es),
             current_buyers = E$intensiva, current_buyers_se = apply(bd[, , "intensiva", drop = FALSE], 2, es),
             new_buyers = E$partecipazione, new_buyers_se = apply(bd[, , "partecipazione", drop = FALSE], 2, es),
             pct_from_new_buyers = 100 * E$partecipazione / E$spesa, row.names = NULL)
}))
cat("\n13.1 Expenditure elasticity = current buyers + new buyers:\n")
print(tab_scomposizione %>% select(system, category, expenditure_elasticity, current_buyers, new_buyers, pct_from_new_buyers) %>%
        mutate(across(where(is.numeric), ~ round(.x, 2))))

# 13.2 ELASTICITIES WITH RESPECT TO TOTAL EXPENDITURE (main model, no new estimation)
# All elasticities of the model are with respect to the FOOD budget (food consumed at home). To compare them with
# income elasticities we add a third, upper step: total expenditure -> food budget.
#   E_k,total = E_k,food x theta
# theta = elasticity of the real food budget to total expenditure = the coefficient of ln_spesa_tot in the first
# step of the stage-1 control function (section 9.5 (a)): a log-linear Engel curve of food, holding prices,
# demographics and round fixed. It is an approximation (food versus non-food is not a full demand system here).
# Bootstrap: every replication uses its own theta and its own elasticities, so the standard errors include both.
# Most studies report elasticities with respect to total expenditure (or income): compare our numbers with theirs
# ONLY after this conversion. The table is built in section 14 (main_expenditure).
theta <- fit1$b_cf["ln_spesa_tot"]
cat("\n13.2 theta (elasticity of the food budget to total expenditure) =", round(theta, 3), " se", round(es(boot_theta), 3), "\n")

# 13.3 VARIANT A: ANOTHER RESIDUAL OF STAGE 2 (the second most consumed category, RES_ALT)
# Same model, same data; only the omitted equation changes. Plant proteins now get their own probit (zero
# correction) and their own equation. Prices are now relative to the price of RES_ALT (columns lnf2_<category>);
# the protein price index and the real protein expenditure do not change.
# How to read it: if an elasticity is similar in the two versions, it does not depend on the choice of the residual.
consumo2 <- colMeans(stima2[, paste0("v_", STAGE2)] > 0); names(consumo2) <- STAGE2
RES_ALT  <- names(which.max(consumo2[setdiff(STAGE2, RES2)]))
cat("\n13.3 Alternative residual:", RES_ALT, "(consumed by", round(100 * consumo2[RES_ALT], 1), "% of the households with protein spending)\n")
STAGE2_A <- c(setdiff(STAGE2, c(RES_ALT, RES2)), RES2, RES_ALT)          # same categories, RES_ALT last
for (k in head(STAGE2_A, -1)) stima2[[paste0("lnf2_", k)]] <- stima2[[paste0("lnP_", k)]] - stima2[[paste0("lnP_", RES_ALT)]]
SPEC2_A <- prepara_spec(list(nome = paste0("stage 2, ", RES_ALT, " residual"), gruppi = STAGE2_A, w = "w2_", p = "lnf2_", x_reale = "ln_x_prot_real",
                             strumenti = SPEC2$strumenti, wbar = wbar2[STAGE2_A]))   # Stone weights in the same order as the groups
fit2_A <- stima_laaids(stima2, SPEC2_A, stampa = TRUE)
E2_A   <- ordina2(elasticita(fit2_A, fit2_A$d))                           # back to the usual order of the categories
EU_A   <- elasticita_incondizionate(E1, E2_A)                             # stage 1 is unchanged

# 13.4 VARIANT B: NO CONTROL FUNCTION (expenditure treated as exogenous, in both stages)
# v_hat is removed from the probits and from the share equations. Everything else is the same.
# How to read it: the difference from the main model shows how much the correction for endogenous expenditure matters.
# With measurement error in reported food spending, elasticities of luxuries are expected to be LOWER without it.
SPEC1_B <- prepara_spec(list(nome = "stage 1, no control function", gruppi = STAGE1, w = "w1_", p = "lnp1_", x_reale = "ln_x_food_real",
                             strumenti = SPEC1$strumenti, wbar = wbar1, cf = FALSE))
SPEC2_B <- prepara_spec(list(nome = "stage 2, no control function", gruppi = STAGE2, w = "w2_", p = "lnp2_", x_reale = "ln_x_prot_real",
                             strumenti = SPEC2$strumenti, wbar = wbar2, cf = FALSE))
fit1_B <- stima_laaids(stima1, SPEC1_B, stampa = TRUE)
fit2_B <- stima_laaids(stima2, SPEC2_B, stampa = TRUE)
E1_B <- elasticita(fit1_B, fit1_B$d); E2_B <- elasticita(fit2_B, fit2_B$d); EU_B <- elasticita_incondizionate(E1_B, E2_B)
EA_B <- aggrega(EU_B)                                                     # aggregates without control function
E_gruppi_B <- sapply(GRUPPI, function(g) per_gruppo(fit1_B, fit2_B, g), simplify = "array")   # by quintile and area (point estimates)

# 13.5 BOOTSTRAP OF THE TWO VARIANTS
# Same seed as section 11, so every replication uses the SAME clusters as the main bootstrap: the differences between
# the versions are not due to different random draws. Variant A also needs stage 1 of the main model (re-estimated here).
PUNTI <- list(A_s2 = E2_A, A_unc = EU_A, B_s1 = E1_B, B_s2 = E2_B, B_unc = EU_B)
RIGHE_V <- list(A_s2 = STAGE2, A_unc = STAGE2, B_s1 = STAGE1, B_s2 = STAGE2, B_unc = STAGE2)
boot_var <- lapply(RIGHE_V, function(g) array(NA, c(max(B_ROB, 1), length(g), 2), dimnames = list(NULL, g, c("spesa", "marshall"))))
boot_agg_B   <- array(NA, c(max(B_ROB, 1), length(AGGREGATI), ncol(EA)), dimnames = list(NULL, names(AGGREGATI), colnames(EA)))
boot_theta_B <- rep(NA_real_, max(B_ROB, 1))                               # theta of each replication (for section 14)
set.seed(SEME)
cat("\nRobustness bootstrap:", B_ROB, "replications (same clusters as section 11).\n")
t0 <- Sys.time()
for (r in seq_len(B_ROB)) {
  estratti <- sample(CLUSTER, K, replace = TRUE)
  d1 <- stima1[unlist(righe1[estratti], use.names = FALSE), ]
  d2 <- stima2[unlist(righe2[estratti], use.names = FALSE), ]
  stima_ok <- function(d, S) tryCatch(suppressWarnings(stima_laaids(d, S)), error = function(e) NULL)
  f1 <- stima_ok(d1, SPEC1); fA2 <- stima_ok(d2, SPEC2_A); fB1 <- stima_ok(d1, SPEC1_B); fB2 <- stima_ok(d2, SPEC2_B)
  rm(d1, d2)
  if (is.null(f1) || is.null(fA2) || is.null(fB1) || is.null(fB2)) next
  e1 <- elasticita(f1, f1$d); eA2 <- ordina2(elasticita(fA2, fA2$d)); eB1 <- elasticita(fB1, fB1$d); eB2 <- elasticita(fB2, fB2$d)
  e_v <- list(A_s2 = eA2, A_unc = elasticita_incondizionate(e1, eA2), B_s1 = eB1, B_s2 = eB2, B_unc = elasticita_incondizionate(eB1, eB2))
  for (v in names(e_v)) boot_var[[v]][r, , ] <- cbind(e_v[[v]]$spesa, diag(e_v[[v]]$marshall))
  boot_agg_B[r, , ] <- aggrega(e_v$B_unc); boot_theta_B[r] <- fB1$b_cf["ln_spesa_tot"]
  rm(f1, fA2, fB1, fB2); invisible(gc())
  if (r %% 10 == 0) cat("  replication", r, "of", B_ROB, "-", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "minutes\n")
}
cat("Successful replications:", sum(!is.na(boot_var$A_s2[, 1, 1])), "of", B_ROB, "\n")

# 13.6 COMPARISON TABLE: main model, variant A (alternative residual RES_ALT), variant B (no control function),
#      and the main model with the elasticities AT THE SAMPLE MEANS (old method, section 10.1; its bootstrap is in
#      section 11, so it uses B replications and the same clusters).
# For every system: expenditure elasticity and own-price (Marshall) elasticity, with bootstrap standard errors.
PUNTI$PM_s1 <- E_pm$s1; PUNTI$PM_s2 <- E_pm$s2; PUNTI$PM_unc <- E_pm$unc
boot_var$PM_s1 <- boot_pm$s1; boot_var$PM_s2 <- boot_pm$s2; boot_var$PM_unc <- boot_pm$unc
COL4 <- c("_expenditure", "_expenditure_se", "_own_marshall", "_own_marshall_se")
col_base <- function(s) setNames(data.frame(TAB[[s]]$spesa$expenditure_elasticity, TAB[[s]]$spesa$se,
                                            TAB[[s]]$propria$marshall, TAB[[s]]$propria$marshall_se), paste0("main", COL4))
col_var  <- function(v, nome) { E <- PUNTI[[v]]; b <- boot_var[[v]]
  setNames(data.frame(E$spesa, apply(b[, , "spesa", drop = FALSE], 2, es), diag(E$marshall), apply(b[, , "marshall", drop = FALSE], 2, es)),
           paste0(nome, COL4)) }
col_na   <- function(n, nome) setNames(data.frame(matrix(NA_real_, n, 4)), paste0(nome, COL4))
tab_rob <- bind_rows(
  data.frame(system = "stage 1", category = STAGE1, col_base("s1"), col_na(length(STAGE1), "alt_residual"), col_var("B_s1", "no_CF"),
             col_var("PM_s1", "at_means"), row.names = NULL),
  data.frame(system = "stage 2 (conditional)", category = STAGE2, col_base("s2"), col_var("A_s2", "alt_residual"), col_var("B_s2", "no_CF"),
             col_var("PM_s2", "at_means"), row.names = NULL),
  data.frame(system = "unconditional", category = STAGE2, col_base("unc"), col_var("A_unc", "alt_residual"), col_var("B_unc", "no_CF"),
             col_var("PM_unc", "at_means"), row.names = NULL))
tab_rob$note <- case_when(tab_rob$category == RES1 ~ "residual in all versions (stage 1 is the same in main and alt_residual)",
                          tab_rob$category == RES2 ~ "residual in main and no_CF: elasticity from adding-up",
                          tab_rob$category == RES_ALT ~ paste0("residual in alt_residual (", RES_ALT, "): elasticity from adding-up"),
                          tab_rob$system == "stage 1" ~ "stage 1 is the same in main and alt_residual",
                          TRUE ~ "")
cat("\n13.6 Expenditure elasticities: main model, alternative residual (", RES_ALT, "), no control function, at the means:\n")
print(tab_rob %>% select(system, category, main_expenditure, alt_residual_expenditure, no_CF_expenditure, at_means_expenditure) %>%
        mutate(across(where(is.numeric), ~ round(.x, 2))))

# 13.7 SAVE: 3 sheets added to the results file of section 12, and the bootstrap replications
nota13 <- data.frame(notes = c(
  "Robustness checks (section 13 of the script). Bootstrap with the same clusters as the main results.",
  paste0("rob_comparison: main model vs alt_residual (", RES_ALT, " is the omitted equation of stage 2 instead of plant_protein) vs no_CF (no control function)"),
  "   vs at_means (main model, elasticities of ONE household with all the mean values: the method used before 26 November 2026).",
  "   A category that is the residual gets its elasticity from adding-up, without zero correction: compare it with the version where it is estimated.",
  "rob_decomposition: expenditure elasticity = current_buyers (households already consuming spend more) + new_buyers (more households start consuming).",
  "All elasticities here are with respect to the FOOD budget (stage 1, unconditional) or the PROTEIN budget (stage 2). For TOTAL expenditure: main_expenditure."))
file_ris <- file.path(USCITA, paste0("risultati_LAAIDS_2stadi_", PAESE, ".xlsx"))
wb <- loadWorkbook(file_ris)
fogli13 <- list(rob_notes = nota13, rob_comparison = tab_rob, rob_decomposition = tab_scomposizione)
for (s in names(fogli13)) { if (s %in% names(wb)) removeWorksheet(wb, s); addWorksheet(wb, s); writeData(wb, s, fogli13[[s]]) }
saveWorkbook(wb, file_ris, overwrite = TRUE)
saveRDS(list(varianti = boot_var, theta = boot_theta, scomposizione = boot_dec, aggregati_no_CF = boot_agg_B, theta_no_CF = boot_theta_B),
        file.path(USCITA, "repliche_bootstrap_robustezza.rds"))
cat("\nRobustness results added to:", file_ris, "\n")


## =============================================================================
## 14. MAIN TABLE FOR THE PAPER      (ADDED 26 November 2026)
## =============================================================================
# Why: our numbers must be comparable with the literature, which mostly reports elasticities with respect to TOTAL
# expenditure (or income), often for broad groups (meat, dairy), and usually without a control function.
# This section puts in two sheets, at the front of the results file:
#   main_expenditure: for every stage-1 group, protein category and aggregate (meat, meat_and_fish, dairy,
#     animal_source_foods):
#       elasticity with respect to TOTAL expenditure (= food-budget elasticity x theta, 13.2), with control function
#       the same WITHOUT control function (variant B of 13.4): the two together give the range to report
#       the elasticity with respect to the FOOD budget (the number the model estimates directly)
#       current buyers / new buyers: how much of the total-expenditure elasticity comes from households that already
#       buy (both stages, 10.2) and how much from households that start buying
#   main_own_price: own-price elasticities (Marshall and Hicks; for protein categories and aggregates unconditional),
#       with and without control function.
# Standard errors: bootstrap (sections 11 and 13.5). Every replication uses its own theta.
# Run this section after sections 0-13 (it uses the no-control-function variant of section 13.4).

# 14.1 Elasticities with respect to the food budget of all rows, with their bootstrap replications
#      rows: 4 stage-1 groups, the protein categories (unconditional), the aggregates
# fetta(a, k): the replications x categories matrix of the 3-D array a for the quantity k (always a matrix, also
# when there is only 1 replication, e.g. B_ROB = 0)
fetta <- function(a, k) matrix(a[, , k], nrow = dim(a)[1], dimnames = dimnames(a)[1:2])
righe14 <- c(STAGE1, STAGE2, names(AGGREGATI))
livello <- c(rep("stage 1 group", length(STAGE1)), rep("protein category", length(STAGE2)), rep("aggregate of protein categories", length(AGGREGATI)))
quota   <- c(E1$w, EU$w, EA[, "share"])                                    # mean shares of the FOOD budget
cibo    <- c(E1$spesa, EU$spesa, EA[, "spesa"])                            # with control function
cibo_B  <- c(E1_B$spesa, EU_B$spesa, EA_B[, "spesa"])                      # without control function
b_cibo  <- cbind(boot_spesa$s1, boot_spesa$unc, fetta(boot_agg, "spesa"))
b_cibo_B <- cbind(fetta(boot_var$B_s1, "spesa"), fetta(boot_var$B_unc, "spesa"), fetta(boot_agg_B, "spesa"))
# current buyers (intensive part), with respect to the food budget. NA for the residual groups.
att     <- c(E1$intensiva, EU$intensiva, EA[, "intensiva"])
b_att   <- cbind(fetta(boot_dec$s1, "intensiva"), fetta(boot_dec$unc, "intensiva"), fetta(boot_agg, "intensiva"))

# 14.2 Conversion to TOTAL expenditure: x theta (every replication with its own theta)
theta_B <- fit1_B$b_cf["ln_spesa_tot"]                                     # the same first step: equal to theta
tot     <- cibo * theta;    b_tot   <- b_cibo * boot_theta
tot_B   <- cibo_B * theta_B; b_tot_B <- b_cibo_B * boot_theta_B
att_tot <- att * theta;     b_att_tot <- b_att * boot_theta
tab_main <- data.frame(level = livello, category = righe14, mean_share_food_budget = quota,
                       total_expenditure = tot, se = apply(b_tot, 2, es), ci95_low = apply(b_tot, 2, q025), ci95_high = apply(b_tot, 2, q975),
                       total_expenditure_no_CF = tot_B, se_no_CF = apply(b_tot_B, 2, es),
                       food_budget = cibo, se_food_budget = apply(b_cibo, 2, es),
                       food_budget_no_CF = cibo_B, se_food_budget_no_CF = apply(b_cibo_B, 2, es),
                       current_buyers = att_tot, current_buyers_se = apply(b_att_tot, 2, es),
                       new_buyers = tot - att_tot, pct_from_new_buyers = 100 * (tot - att_tot) / tot,
                       theta = theta, se_theta = es(boot_theta), row.names = NULL)
tab_main$note <- case_when(tab_main$category %in% c(RES1, RES2) ~ "residual group: elasticity from adding-up, no current/new split",
                           tab_main$level == "stage 1 group" ~ "stage 1: with respect to the food budget x theta",
                           TRUE ~ "unconditional (both stages re-optimised) x theta")

# 14.3 Own-price elasticities (Marshall and Hicks), with and without control function
marsh   <- c(diag(E1$marshall), diag(EU$marshall), EA[, "marshall"])
hicks   <- c(diag(E1$hicks), diag(EU$hicks), EA[, "hicks"])
b_marsh <- cbind(t(apply(boot_marsh$s1, 1, diag)), t(apply(boot_marsh$unc, 1, diag)), fetta(boot_agg, "marshall"))
b_hicks <- cbind(t(apply(boot_hicks$s1, 1, diag)), t(apply(boot_hicks$unc, 1, diag)), fetta(boot_agg, "hicks"))
marsh_B <- c(diag(E1_B$marshall), diag(EU_B$marshall), EA_B[, "marshall"])
b_marsh_B <- cbind(fetta(boot_var$B_s1, "marshall"), fetta(boot_var$B_unc, "marshall"), fetta(boot_agg_B, "marshall"))
tab_prezzi <- data.frame(level = livello, category = righe14, mean_share_food_budget = quota,
                         marshall = marsh, marshall_se = apply(b_marsh, 2, es),
                         marshall_ci95_low = apply(b_marsh, 2, q025), marshall_ci95_high = apply(b_marsh, 2, q975),
                         hicks = hicks, hicks_se = apply(b_hicks, 2, es),
                         marshall_no_CF = marsh_B, marshall_no_CF_se = apply(b_marsh_B, 2, es), row.names = NULL)
tab_prezzi$note <- case_when(tab_prezzi$level == "stage 1 group" ~ "stage 1 (food groups)",
                             tab_prezzi$level == "protein category" ~ "unconditional (both stages re-optimised)",
                             TRUE ~ "aggregate: all prices of the group rise by 1% together")
cat("\n14. MAIN TABLE - elasticities with respect to TOTAL expenditure (theta =", round(theta, 3), "):\n")
print(tab_main %>% select(category, total_expenditure, se, total_expenditure_no_CF, food_budget, current_buyers, pct_from_new_buyers) %>%
        mutate(across(where(is.numeric), ~ round(.x, 2))))
cat("Own-price elasticities (Marshall):\n")
print(tab_prezzi %>% select(category, marshall, marshall_se, marshall_no_CF) %>% mutate(across(where(is.numeric), ~ round(.x, 2))))

# 14.3b RESULTS BY QUINTILE AND AREA (section 10.4b): one row per group x category, and a compact view
#       total_expenditure = food-budget elasticity x theta (theta is the same for all groups: an approximation)
info_gr <- data.frame(group = GRUPPI, quintile = ifelse(grepl("^Q", GRUPPI), sub("^Q([1-5]).*$", "\\1", GRUPPI), "all"),
                      area = ifelse(grepl("rural", GRUPPI), "rural", ifelse(grepl("urban", GRUPPI), "urban", "all")),
                      n_households = N_gruppi[GRUPPI], row.names = NULL)
tab_gruppi <- bind_rows(lapply(GRUPPI, function(g) {
  bs <- boot_gr[, , "spesa", g, drop = FALSE] * boot_theta                 # total-expenditure elasticities, each replication
  bi <- boot_gr[, , "intensiva", g, drop = FALSE] * boot_theta
  bm <- boot_gr[, , "marshall", g, drop = FALSE]
  tot <- E_gruppi[, "spesa", g] * theta; att <- E_gruppi[, "intensiva", g] * theta
  data.frame(info_gr[info_gr$group == g, ], level = livello, category = RIGHE_TAB, mean_share_food_budget = quota_gr[, g],
             total_expenditure = tot, se = apply(bs, 2, es), ci95_low = apply(bs, 2, q025), ci95_high = apply(bs, 2, q975),
             total_expenditure_no_CF = E_gruppi_B[, "spesa", g] * theta_B, food_budget = E_gruppi[, "spesa", g],
             current_buyers = att, current_buyers_se = apply(bi, 2, es), pct_from_new_buyers = 100 * (tot - att) / tot,
             own_marshall = E_gruppi[, "marshall", g], own_marshall_se = apply(bm, 2, es), own_hicks = E_gruppi[, "hicks", g],
             row.names = NULL)
}))
tab_gruppi$note <- ifelse(tab_gruppi$n_households < 200, "fewer than 200 households in the group: imprecise", "")
vista_q <- data.frame(level = livello, category = RIGHE_TAB, round(E_gruppi[, "spesa", c(paste0("Q", 1:5), "rural", "urban")] * theta, 3),
                      check.names = FALSE, row.names = NULL)
cat("\n14.3b Elasticities with respect to TOTAL expenditure by quintile and area:\n"); print(vista_q, row.names = FALSE)

# 14.4 SAVE: the sheets go right after "notes", at the front of the results file
nota14 <- c(
  "main_expenditure: total_expenditure = elasticity with respect to TOTAL household expenditure = food-budget elasticity x theta",
  "   (theta = elasticity of the real food budget to total expenditure, first step of the stage-1 control function). _no_CF = without control function.",
  "   current_buyers = part of the elasticity from households that already buy (in both stages); new_buyers = the rest (households that start buying",
  "   or buy more often within the 7 days). Aggregates: weighted means of the categories (weights = shares in the food budget).",
  "main_own_price: own-price elasticities; protein categories and aggregates unconditional; aggregate = all prices of the group change together.",
  "main_by_quintile: elasticities with respect to TOTAL expenditure by national quintile of consumption per person (Q1 = poorest 20% of people) and area.",
  "main_by_group: the same by quintile, area and quintile x area, with bootstrap se, no-CF values, current/new buyers and own-price elasticities.",
  "   Same model for all groups: the averages are taken over the households of each group (section 10.4b). Groups under 200 households: imprecise.")
wb <- loadWorkbook(file_ris)
for (s in c("main_expenditure", "main_own_price", "main_by_quintile", "main_by_group")) if (s %in% names(wb)) removeWorksheet(wb, s)
addWorksheet(wb, "main_expenditure"); writeData(wb, "main_expenditure", tab_main)
addWorksheet(wb, "main_own_price");   writeData(wb, "main_own_price", tab_prezzi)
addWorksheet(wb, "main_by_quintile"); writeData(wb, "main_by_quintile", vista_q)
addWorksheet(wb, "main_by_group");    writeData(wb, "main_by_group", tab_gruppi)
writeData(wb, "notes", data.frame(notes = nota14), startRow = nrow(nota) + 3, colNames = FALSE)
nomi_fogli <- names(wb)
PRIMI <- c("notes", "main_expenditure", "main_own_price", "main_by_quintile", "main_by_group")
worksheetOrder(wb) <- match(c(PRIMI, setdiff(nomi_fogli, PRIMI)), nomi_fogli)
saveWorkbook(wb, file_ris, overwrite = TRUE)
cat("\nMain table added to:", file_ris, "\n")
