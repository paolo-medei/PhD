###############################################################################
##  DESCRIPTIVE ANALYSIS, 5 COUNTRIES: by consumption quintile and by area (rural / urban)
##  Tanzania, Ethiopia, Malawi, Nigeria, Uganda (LSMS-ISA panels, all rounds pooled)
##
##  WHAT IT PRODUCES (one Excel file + charts in PNG, in a new folder):
##    leggimi        definitions, sources, warnings
##    demografia     household size, adult equivalents, female head, age of the head, share of the population
##    consumo        total consumption and food consumption per person per day (2021 PPP dollars), food share,
##                   share of people below 3.00 dollars a day
##    asf            animal-source foods (ASF): spending per person, share of the food budget, % of households that
##                   consumed each category in the last 7 days, share of each category in the food budget
##    mercato        where ASF come from: purchases, own production, gifts (% of the value consumed)
##    qualita        unit values of ASF purchases relative to the local median of the same item and unit (a sign of quality)
##    per_round      the main indicators round by round (with local currency)
##    dati_lunghi    every number of the other sheets in one long table (for pivot tables)
##
##  INPUTS (all already on the PC):
##    1. for every country the results folder of LAAIDS_2stadi.R (the most recent one WITH regional fixed effects):
##         famiglie_quote_prezzi.csv  one row per household x round (shares, budgets, quintile, demographics)
##         voci_valori_flag.csv       one row per household x item (value of purchases, own production, gifts, unit values)
##    2. famiglie_extra_5paesi.csv  official FOOD consumption and interview year (built by famiglie_extra_5paesi.py)
##    3. wb_ppp_cpi.csv             World Bank: consumer price index and 2021 PPP factor (see README_wb_ppp_cpi.txt)
##
##  DEFINITIONS (written again in the sheet "leggimi")
##   - Quintile: of total consumption PER PERSON, national, within each round, so that each quintile holds 20% of
##     the people (built in LAAIDS_2stadi.R, section 8.7c). Q1 = poorest 20%.
##   - Rounds pooled: every round counts the same (the survey weights are rescaled to sum to 1 in each round).
##   - Means per PERSON (weights = survey weight x household size) for consumption per person and for poverty;
##     means per HOUSEHOLD (weights = survey weight) for shares, % of households and demographics.
##   - 2021 PPP dollars per person per day = annual value / household size / 365 x CPI(2021) / CPI(year of the prices)
##     / PPP factor 2021. Year of the prices: interview year when known, otherwise the middle of the fieldwork.
##     Malawi: the official aggregates are already in real terms (prices of the start of the survey); Uganda 2010-2011:
##     official total consumption is at constant 2005/06 prices. The conversion is an approximation (10-15% in rounds
##     that span two calendar years with high inflation: Ethiopia, Nigeria).
##   - Food share = official food consumption / official total consumption (Uganda: our food at home x 52 / total).
##   - ASF and categories: our food budget (food consumed at home in the last 7 days: purchases + own production +
##     gifts valued at local prices), as in the LA/AIDS.
##
##  PACKAGES: install.packages(c("dplyr", "tidyr", "openxlsx", "ggplot2"))
###############################################################################

library(dplyr)
library(tidyr)
library(openxlsx)
library(ggplot2)

## =============================================================================
## 0. SETTINGS
## =============================================================================
CARTELLA <- "C:/Users/Medei/Desktop/PhD_v21/data/OUTPUT"                 # folder with analisi_<country>
EXTRA    <- file.path(CARTELLA, "dataset", "famiglie_extra_5paesi.csv")
PPP_CPI  <- file.path(CARTELLA, "dataset", "wb_ppp_cpi.csv")
USCITA   <- file.path(CARTELLA, paste0("descrittive_5paesi_", Sys.Date()))
dir.create(USCITA, showWarnings = FALSE)
PAESI <- c(TZA = "Tanzania", ETH = "Etiopia", MWI = "Malawi", NGA = "Nigeria", UGA = "Uganda")
SOGLIA_POVERTA <- 3.00                                                     # World Bank line, 2021 PPP dollars a day

# Protein categories of the LA/AIDS and their groups (Ethiopia has no pork_other_meat)
CAT  <- c("beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs", "plant_protein")
NOMI <- c(beef = "Manzo", sheep_goat = "Ovicaprini", pork_other_meat = "Maiale e altra carne", poultry = "Pollame", fish = "Pesce",
          fluid_milk = "Latte fresco", other_dairy = "Altri latticini", eggs = "Uova", plant_protein = "Proteine vegetali",
          carne = "Carne (tutta)", latticini = "Latticini (tutti)", asf = "Tutti gli ASF")
GRUPPI_ASF <- list(carne = c("beef", "sheep_goat", "pork_other_meat", "poultry"), fish = "fish",
                   latticini = c("fluid_milk", "other_dairy"), eggs = "eggs",
                   asf = c("beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs"))

# Year of the prices when the interview year is missing (middle of the fieldwork); .5 = between two years
ANNO_DEFAULT <- read.table(header = TRUE, text = "
paese round anno
TZA 2008 2009
TZA 2010 2011
TZA 2012 2013
TZA 2014 2015
TZA 2020 2021
ETH 2015 2015.5
ETH 2018 2018.5
ETH 2021 2021.5
MWI 2010 2010.5
MWI 2016 2016.5
MWI 2019 2019.5
MWI 2024 2024.5
NGA 2010 2011
NGA 2012 2013
NGA 2015 2016
NGA 2018 2019
NGA 2023 2023.5
UGA 2010 2010.5
UGA 2011 2011.5
UGA 2013 2013.5
UGA 2015 2015.5
UGA 2018 2018.5
UGA 2019 2019.5
")
# Official total (and official food) with prices of a different year than the interview:
#   Malawi: real aggregates, prices of the start of each survey; Uganda 2010-2011: constant 2005/06 prices;
#   Nigeria 2023: totcons_adj, 2023 prices.
ANNO_TOTALE <- read.table(header = TRUE, text = "
paese round anno
MWI 2010 2010
MWI 2016 2016
MWI 2019 2019
MWI 2024 2024
UGA 2010 2005.5
UGA 2011 2005.5
NGA 2023 2023
")


## =============================================================================
## 1. READ THE DATA OF THE 5 COUNTRIES
## =============================================================================
ultima_cartella <- function(p) {                 # the most recent results folder WITH fixed effects
  d <- list.files(file.path(CARTELLA, paste0("analisi_", p)), pattern = paste0("^risultati_LAAIDS_2stadi_", p, "_20[0-9-]{8}$"), full.names = TRUE)
  d <- d[file.exists(file.path(d, "famiglie_quote_prezzi.csv"))]
  if (!length(d)) stop("no results folder for ", p)
  tail(sort(d), 1)
}
extra <- read.csv(EXTRA, colClasses = c(hhid = "character"))
wb    <- read.csv(PPP_CPI)
cpi <- function(paese, anno) {                   # CPI of a (fractional) year: geometric interpolation
  a0 <- floor(anno); a1 <- ceiling(anno); f <- anno - a0
  c0 <- wb$cpi_2010_100[match(paste(paese, a0), paste(wb$country, wb$year))]
  c1 <- wb$cpi_2010_100[match(paste(paese, a1), paste(wb$country, wb$year))]
  exp((1 - f) * log(c0) + f * log(c1))
}
ppp <- function(paese) wb$ppp2021_hfce_lcu_per_intl_dollar[match(paese, wb$country)]

FAM <- list(); VOCI <- list()
for (p in names(PAESI)) {
  cart <- ultima_cartella(p); cat(p, "<-", cart, "\n")
  f <- read.csv(file.path(cart, "famiglie_quote_prezzi.csv"), colClasses = c(hhid = "character"))
  for (k in setdiff(CAT, sub("^v_", "", grep("^v_", names(f), value = TRUE)))) f[[paste0("v_", k)]] <- 0   # Ethiopia: no pork
  f <- f %>% mutate(paese = p) %>%
    left_join(extra %>% filter(country == p) %>% select(round, hhid, int_year, cibo_ufficiale_annuo), by = c("round", "hhid")) %>%
    left_join(ANNO_DEFAULT %>% filter(paese == p) %>% select(round, anno_def = anno), by = "round") %>%
    left_join(ANNO_TOTALE %>% filter(paese == p) %>% select(round, anno_tot = anno), by = "round") %>%
    mutate(anno_cibo = ifelse(is.na(int_year), anno_def, int_year),          # year of the prices of OUR food values
           anno_tot  = ifelse(is.na(anno_tot), anno_cibo, anno_tot),         # year of the prices of the official aggregates
           k_cibo = cpi(p, 2021) / cpi(p, anno_cibo) / ppp(p),               # local currency of that year -> 2021 PPP dollars
           k_tot  = cpi(p, 2021) / cpi(p, anno_tot) / ppp(p),
           id_distretto = as.character(id_distretto), regione = as.character(regione))
  # only the columns used here (the countries have different extra columns and types)
  FAM[[p]] <- f[, c("paese", "round", "hhid", "peso", "rurale", "ampiezza", "adulti_eq", "capo_donna", "eta_capo", "quintile",
                    "id_distretto", "regione", "spesa_totale_annua", "x_food", "v_proteins", paste0("v_", CAT),
                    "int_year", "cibo_ufficiale_annuo", "anno_cibo", "anno_tot", "k_cibo", "k_tot")]
  v <- read.csv(file.path(cart, "voci_valori_flag.csv"), colClasses = c(hhid = "character", pr_u = "character"))
  VOCI[[p]] <- v %>% filter(stadio2 %in% CAT) %>% mutate(paese = p, codice_voce = as.character(codice_voce)) %>%
    select(paese, round, hhid, codice_voce, stadio2, uv, pr_u, flag_uv_anomalo, val_acq, val_auto, val_regali, val_solo_tot)
}
fam <- bind_rows(FAM)


## =============================================================================
## 2. HOUSEHOLD VARIABLES
## =============================================================================
fam <- fam %>%
  group_by(paese, round) %>%
  mutate(w_fam = ifelse(is.na(peso), 0, peso) / sum(peso, na.rm = TRUE),                     # households: each round sums to 1
         w_per = ifelse(is.na(peso) | is.na(ampiezza), 0, peso * ampiezza) / sum(peso * ampiezza, na.rm = TRUE)) %>%   # people
  ungroup() %>%
  mutate(area = ifelse(rurale == 1, "Rurali", "Urbane"),
         q    = paste0("Q", quintile),
         v_carne     = v_beef + v_sheep_goat + v_pork_other_meat + v_poultry,
         v_latticini = v_fluid_milk + v_other_dairy,
         v_asf       = v_carne + v_fish + v_latticini + v_eggs,
         # 2021 PPP dollars per person per day
         tot_ppp     = spesa_totale_annua / ampiezza / 365 * k_tot,
         cibo_uff_ppp = cibo_ufficiale_annuo / ampiezza / 365 * k_tot,
         cibo_casa_ppp = x_food / 7 / ampiezza * k_cibo,                      # our food at home (7-day value / 7 = per day)
         asf_ppp     = v_asf / 7 / ampiezza * k_cibo,
         # food share of total consumption: official where available, otherwise ours (Uganda)
         quota_cibo  = ifelse(!is.na(cibo_uff_ppp), cibo_uff_ppp / tot_ppp, cibo_casa_ppp / tot_ppp),
         povero      = as.numeric(tot_ppp < SOGLIA_POVERTA),
         quota_asf   = v_asf / x_food, quota_prot = v_proteins / x_food)
for (k in c(CAT, "carne", "latticini", "asf")) {
  fam[[paste0("cons_", k)]]  <- as.numeric(fam[[paste0("v_", k)]] > 0)       # consumed in the last 7 days (1/0)
  fam[[paste0("quota_", k)]] <- fam[[paste0("v_", k)]] / fam$x_food          # share of the food budget
}
# 2.1 IMPLAUSIBLE FOOD BUDGETS: households whose food at home in 7 days, x 52, is more than 3 times their total annual
#     consumption. These are measurement errors in our food values (a quantity or a unit far off: e.g. Uganda 2019, a
#     7-day food budget of 100 million UGX). They are left out of ALL the descriptive tables (counted in "controlli").
fam$anomala <- with(fam, !is.na(cibo_casa_ppp) & !is.na(tot_ppp) & cibo_casa_ppp > 3 * tot_ppp)
controlli <- fam %>% group_by(Paese = PAESI[paese]) %>% summarise(
  `Famiglie (tutti i round)` = n(), `Escluse: cibo a casa x 52 > 3 volte il consumo totale` = sum(anomala),
  `Escluse (%)` = round(100 * mean(anomala), 2),
  `Con cibo ufficiale (%)` = round(100 * mean(!is.na(cibo_ufficiale_annuo)), 1), `Con anno dell'intervista (%)` = round(100 * mean(!is.na(int_year)), 1),
  `Fattore PPP 2021` = round(first(ppp(paese)), 2), `CPI 2021 (2010 = 100)` = round(first(cpi(paese, 2021)), 1), .groups = "drop")
print(controlli)
fam <- fam %>% filter(!anomala)
fam <- fam %>% group_by(paese, round) %>%                                  # weights again, without the excluded households
  mutate(w_fam = w_fam / sum(w_fam), w_per = w_per / sum(w_per)) %>% ungroup()
cat("\nFood share above 1 after the exclusion:", round(100 * mean(fam$quota_cibo > 1, na.rm = TRUE), 2), "% of households\n")


## =============================================================================
## 3. INDICATORS BY COUNTRY x QUINTILE x AREA
## =============================================================================
wmean <- function(x, w) { ok <- !is.na(x) & !is.na(w) & w > 0; if (!any(ok)) NA else sum(x[ok] * w[ok]) / sum(w[ok]) }
wmed  <- function(x, w) { ok <- !is.na(x) & !is.na(w) & w > 0; if (!any(ok)) return(NA)
  o <- order(x[ok]); cw <- cumsum(w[ok][o]) / sum(w[ok]); x[ok][o][which(cw >= 0.5)[1]] }

# INDICATORS: code, sheet, label, unit, function of the households of the cell (d) and of the whole country (tutti)
IND <- list(
  list("n_famiglie",  "demografia", "Famiglie nel campione (tutti i round)",      "numero", function(d, t) nrow(d)),
  list("quota_pop",   "demografia", "Quota della popolazione del paese",          "%",      function(d, t) 100 * sum(d$w_per) / sum(t$w_per)),
  list("ampiezza",    "demografia", "Ampiezza della famiglia",                    "persone", function(d, t) wmean(d$ampiezza, d$w_fam)),
  list("adulti_eq",   "demografia", "Adulti equivalenti",                         "numero", function(d, t) wmean(d$adulti_eq, d$w_fam)),
  list("capo_donna",  "demografia", "Capofamiglia donna",                         "% famiglie", function(d, t) 100 * wmean(d$capo_donna, d$w_fam)),
  list("eta_capo",    "demografia", "Eta' del capofamiglia",                      "anni",   function(d, t) wmean(d$eta_capo, d$w_fam)),
  list("rurale",      "demografia", "Famiglie rurali",                            "% famiglie", function(d, t) 100 * wmean(d$rurale, d$w_fam)),
  list("tot_media",   "consumo", "Consumo totale per persona (media)",            "$ PPP 2021 al giorno", function(d, t) wmean(d$tot_ppp, d$w_per)),
  list("tot_mediana", "consumo", "Consumo totale per persona (mediana)",          "$ PPP 2021 al giorno", function(d, t) wmed(d$tot_ppp, d$w_per)),
  list("cibo_uff",    "consumo", "Consumo di cibo per persona (aggregato ufficiale)", "$ PPP 2021 al giorno", function(d, t) wmean(d$cibo_uff_ppp, d$w_per)),
  list("cibo_casa",   "consumo", "Cibo consumato a casa per persona (7 giorni, nostra misura)", "$ PPP 2021 al giorno", function(d, t) wmean(d$cibo_casa_ppp, d$w_per)),
  list("quota_cibo",  "consumo", "Quota del cibo sul consumo totale",             "% (media delle famiglie)", function(d, t) 100 * wmean(d$quota_cibo, d$w_fam)),
  list("poveri",      "consumo", "Persone sotto 3,00 $ PPP al giorno (indicativo)", "% persone", function(d, t) 100 * wmean(d$povero, d$w_per)),
  list("asf_ppp",     "asf", "Spesa in ASF per persona",                          "$ PPP 2021 al giorno", function(d, t) wmean(d$asf_ppp, d$w_per)),
  list("quota_asf",   "asf", "Quota degli ASF nel budget alimentare",             "% (media delle famiglie)", function(d, t) 100 * wmean(d$quota_asf, d$w_fam)),
  list("quota_prot",  "asf", "Quota delle proteine (ASF + vegetali) nel budget alimentare", "% (media delle famiglie)", function(d, t) 100 * wmean(d$quota_prot, d$w_fam)))
for (k in c("carne", "asf", CAT, "latticini"))
  IND[[length(IND) + 1]] <- list(paste0("cons_", k), "asf", paste0(NOMI[k], ": famiglie che ne hanno consumato negli ultimi 7 giorni"), "% famiglie",
                                 local({ kk <- k; function(d, t) 100 * wmean(d[[paste0("cons_", kk)]], d$w_fam) }))
for (k in c(CAT, "carne", "latticini"))
  IND[[length(IND) + 1]] <- list(paste0("quota_", k), "asf", paste0(NOMI[k], ": quota nel budget alimentare"), "% (media delle famiglie)",
                                 local({ kk <- k; function(d, t) 100 * wmean(d[[paste0("quota_", kk)]], d$w_fam) }))

CELLE <- expand.grid(q = c(paste0("Q", 1:5), "Tutti"), area = c("Tutte", "Rurali", "Urbane"), stringsAsFactors = FALSE)
risultati <- list()
for (p in names(PAESI)) {
  t <- fam %>% filter(paese == p)
  for (i in seq_len(nrow(CELLE))) {
    d <- t
    if (CELLE$q[i] != "Tutti")    d <- d %>% filter(q == CELLE$q[i])
    if (CELLE$area[i] != "Tutte") d <- d %>% filter(area == CELLE$area[i])
    for (ind in IND) risultati[[length(risultati) + 1]] <- data.frame(paese = PAESI[p], quintile = CELLE$q[i], area = CELLE$area[i],
      foglio = ind[[2]], codice = ind[[1]], indicatore = ind[[3]], unita = ind[[4]], valore = if (nrow(d)) ind[[5]](d, t) else NA,
      n_famiglie = nrow(d), row.names = NULL)
  }
}
lunghi <- bind_rows(risultati)


## =============================================================================
## 4. WHERE ASF COME FROM: PURCHASES, OWN PRODUCTION, GIFTS (item values, sheet "mercato")
## =============================================================================
# val_acq = purchases (Nigeria 2012-2015: consumption from purchases), val_auto = own production, val_regali = gifts,
# val_solo_tot = items with only a total (source unknown). Shares of the VALUE consumed, weighted by households.
voci <- bind_rows(VOCI) %>% left_join(fam %>% select(paese, round, hhid, q, area, w_fam), by = c("paese", "round", "hhid")) %>%
  filter(!is.na(w_fam)) %>% mutate(across(c(val_acq, val_auto, val_regali, val_solo_tot), ~ ifelse(is.na(.x), 0, .x)))
fonte <- function(v) { tot <- sum(v$w_fam * (v$val_acq + v$val_auto + v$val_regali + v$val_solo_tot))
  c(acquisti = 100 * sum(v$w_fam * v$val_acq) / tot, autoproduzione = 100 * sum(v$w_fam * v$val_auto) / tot,
    regali = 100 * sum(v$w_fam * v$val_regali) / tot, non_attribuito = 100 * sum(v$w_fam * v$val_solo_tot) / tot) }
merc <- list()
for (p in names(PAESI)) for (i in seq_len(nrow(CELLE))) {
  v <- voci %>% filter(paese == p)
  if (CELLE$q[i] != "Tutti")    v <- v %>% filter(q == CELLE$q[i])
  if (CELLE$area[i] != "Tutte") v <- v %>% filter(area == CELLE$area[i])
  for (g in c("asf", "carne", "fish", "latticini", "eggs")) {
    vg <- v %>% filter(stadio2 %in% GRUPPI_ASF[[g]])
    if (!nrow(vg)) next
    s <- fonte(vg)
    for (k in names(s)) merc[[length(merc) + 1]] <- data.frame(paese = PAESI[p], quintile = CELLE$q[i], area = CELLE$area[i], foglio = "mercato",
      codice = paste0(k, "_", g), indicatore = paste0(NOMI[ifelse(g == "fish", "fish", ifelse(g == "eggs", "eggs", g))], ": quota del valore da ", gsub("_", " ", k)),
      unita = "% del valore consumato", valore = s[[k]], n_famiglie = n_distinct(paste(vg$round, vg$hhid)), row.names = NULL)
  }
}
lunghi <- bind_rows(lunghi, bind_rows(merc))


## =============================================================================
## 5. QUALITY: UNIT VALUES RELATIVE TO THE LOCAL MEDIAN (sheet "qualita")
## =============================================================================
# For every ASF purchase with a unit value (not an outlier): ln(uv / median uv of the same item, unit and round in the
# same district; the region or the country if the district has fewer than 5 purchases). The mean of this log ratio by
# group, as a percentage (exp(mean) - 1): +10% = the group pays 10% more than its neighbours for the same item in the
# same unit, a sign of better quality (better cuts, processed products). Deaton (1988) reads unit values the same way.
loc <- fam %>% select(paese, round, hhid, id_distretto, regione)
uv <- bind_rows(VOCI) %>% filter(!is.na(uv), !flag_uv_anomalo, !is.na(pr_u), stadio2 != "plant_protein") %>%
  left_join(loc, by = c("paese", "round", "hhid")) %>%
  left_join(fam %>% select(paese, round, hhid, q, area, w_fam), by = c("paese", "round", "hhid")) %>% filter(!is.na(w_fam))
mediana_a <- function(uv, livello) uv %>% group_by(across(all_of(c("paese", "round", "codice_voce", "pr_u", livello)))) %>%
  summarise(m = median(uv), n = n(), .groups = "drop") %>% filter(n >= 5) %>% select(-n)
uv <- uv %>%
  left_join(mediana_a(uv, "id_distretto") %>% rename(m_dis = m), by = c("paese", "round", "codice_voce", "pr_u", "id_distretto")) %>%
  left_join(mediana_a(uv, "regione") %>% rename(m_reg = m), by = c("paese", "round", "codice_voce", "pr_u", "regione")) %>%
  left_join(mediana_a(uv, character(0)) %>% rename(m_naz = m), by = c("paese", "round", "codice_voce", "pr_u")) %>%
  mutate(m_loc = coalesce(m_dis, m_reg, m_naz), rel_loc = log(uv / m_loc), rel_naz = log(uv / m_naz)) %>% filter(!is.na(rel_loc))
qual <- list()
for (p in names(PAESI)) for (i in seq_len(nrow(CELLE))) {
  u <- uv %>% filter(paese == p)
  if (CELLE$q[i] != "Tutti")    u <- u %>% filter(q == CELLE$q[i])
  if (CELLE$area[i] != "Tutte") u <- u %>% filter(area == CELLE$area[i])
  for (g in c("asf", "carne", "fish", "latticini", "eggs")) {
    ug <- u %>% filter(stadio2 %in% GRUPPI_ASF[[g]])
    if (nrow(ug) < 20) next                                       # too few purchases
    for (tipo in c("loc", "naz")) qual[[length(qual) + 1]] <- data.frame(paese = PAESI[p], quintile = CELLE$q[i], area = CELLE$area[i], foglio = "qualita",
      codice = paste0("uv_", tipo, "_", g), indicatore = paste0(NOMI[g], ": valore unitario rispetto alla mediana ", ifelse(tipo == "loc", "LOCALE (distretto)", "NAZIONALE")),
      unita = "% sopra (+) o sotto (-) la mediana", valore = 100 * (exp(wmean(ug[[paste0("rel_", tipo)]], ug$w_fam)) - 1), n_famiglie = nrow(ug), row.names = NULL)
  }
}
lunghi <- bind_rows(lunghi, bind_rows(qual))
lunghi$n_nota <- ifelse(lunghi$foglio == "qualita", "n_famiglie = numero di acquisti", "")


## =============================================================================
## 6. ROUND BY ROUND (all households of the country; local currency too)
## =============================================================================
per_round <- fam %>% group_by(Paese = PAESI[paese], Round = round) %>% summarise(
  Famiglie = n(), `Anno dei prezzi (cibo)` = round(wmean(anno_cibo, w_fam), 1),
  `Consumo totale per persona, valuta locale all'anno (media)` = wmean(spesa_totale_annua / ampiezza, w_per),
  `Consumo totale per persona, $ PPP al giorno (media)` = wmean(tot_ppp, w_per),
  `Quota del cibo sul totale (%)` = 100 * wmean(quota_cibo, w_fam),
  `Persone sotto 3,00 $ al giorno (%)` = 100 * wmean(povero, w_per),
  `Spesa ASF per persona, $ PPP al giorno` = wmean(asf_ppp, w_per),
  `Quota ASF nel budget alimentare (%)` = 100 * wmean(quota_asf, w_fam),
  `Famiglie che hanno consumato carne in 7 giorni (%)` = 100 * wmean(cons_carne, w_fam),
  `Famiglie rurali (%)` = 100 * wmean(rurale, w_fam), .groups = "drop")


## =============================================================================
## 7. EXCEL: one sheet per topic; in each sheet one block per indicator
##    rows = quintile (Q1 poorest ... Q5 richest, Tutti), columns = country x area (Tutte, Rurali, Urbane)
## =============================================================================
wb_out <- createWorkbook()
st_tit <- createStyle(fontName = "Arial", fontSize = 12, textDecoration = "bold")
st_sub <- createStyle(fontName = "Arial", fontSize = 9, fontColour = "#555555", textDecoration = "italic")
st_hdr <- createStyle(fontName = "Arial", fontSize = 10, textDecoration = "bold", fontColour = "#FFFFFF", fgFill = "#1F4E78",
                      halign = "center", border = "TopBottomLeftRight", borderColour = "#BFBFBF", wrapText = TRUE)
st_hdr2 <- createStyle(fontName = "Arial", fontSize = 9, textDecoration = "bold", fgFill = "#DDEBF7", halign = "center",
                       border = "TopBottomLeftRight", borderColour = "#BFBFBF")
st_body <- createStyle(fontName = "Arial", fontSize = 10, border = "TopBottomLeftRight", borderColour = "#BFBFBF", numFmt = "0.0")
st_int  <- createStyle(fontName = "Arial", fontSize = 10, border = "TopBottomLeftRight", borderColour = "#BFBFBF", numFmt = "#,##0")
st_lab  <- createStyle(fontName = "Arial", fontSize = 10, border = "TopBottomLeftRight", borderColour = "#BFBFBF")
st_tutti <- createStyle(textDecoration = "bold", fgFill = "#F2F2F2")
ETIC_Q <- c(Q1 = "Q1 (20% piu' povero)", Q2 = "Q2", Q3 = "Q3", Q4 = "Q4", Q5 = "Q5 (20% piu' ricco)", Tutti = "Tutti")

TITOLI <- c(demografia = "Chi sono le famiglie", consumo = "Consumo totale, cibo e quota del cibo",
            asf = "Alimenti di origine animale (ASF): spesa, quote e famiglie che consumano",
            mercato = "Da dove vengono gli ASF: acquisti, autoproduzione, regali", qualita = "Qualita': valori unitari degli acquisti di ASF")
for (fg in names(TITOLI)) {
  addWorksheet(wb_out, fg, gridLines = FALSE)
  writeData(wb_out, fg, TITOLI[fg], startRow = 1); addStyle(wb_out, fg, st_tit, rows = 1, cols = 1)
  writeData(wb_out, fg, "Tutti i round insieme (ogni round pesa uguale). Quintili nazionali di consumo totale per persona. Vedi il foglio leggimi.", startRow = 2)
  addStyle(wb_out, fg, st_sub, rows = 2, cols = 1)
  r <- 4
  for (cod in unique(lunghi$codice[lunghi$foglio == fg])) {
    x <- lunghi %>% filter(codice == cod)
    writeData(wb_out, fg, paste0(x$indicatore[1], "  [", x$unita[1], "]"), startRow = r)
    addStyle(wb_out, fg, createStyle(fontName = "Arial", fontSize = 10, textDecoration = "bold"), rows = r, cols = 1)
    # header: countries (merged over 3 columns), then areas
    writeData(wb_out, fg, "Quintile", startRow = r + 1, startCol = 1); mergeCells(wb_out, fg, cols = 1, rows = (r + 1):(r + 2))
    for (j in seq_along(PAESI)) {
      c0 <- 2 + (j - 1) * 3
      writeData(wb_out, fg, PAESI[j], startRow = r + 1, startCol = c0); mergeCells(wb_out, fg, cols = c0:(c0 + 2), rows = r + 1)
      writeData(wb_out, fg, t(c("Tutte", "Rurali", "Urbane")), startRow = r + 2, startCol = c0, colNames = FALSE)
    }
    addStyle(wb_out, fg, st_hdr, rows = r + 1, cols = 1:16, gridExpand = TRUE)
    addStyle(wb_out, fg, st_hdr2, rows = r + 2, cols = 2:16, gridExpand = TRUE)
    tab <- x %>% mutate(col = paste(paese, area)) %>% select(quintile, col, valore) %>%
      pivot_wider(names_from = col, values_from = valore)
    ordine <- unlist(lapply(PAESI, function(p) paste(p, c("Tutte", "Rurali", "Urbane"))))
    for (o in setdiff(ordine, names(tab))) tab[[o]] <- NA
    tab <- tab[match(names(ETIC_Q), tab$quintile), c("quintile", ordine)]
    tab$quintile <- ETIC_Q[tab$quintile]
    writeData(wb_out, fg, tab, startRow = r + 3, colNames = FALSE)
    addStyle(wb_out, fg, st_lab, rows = (r + 3):(r + 8), cols = 1, gridExpand = TRUE)
    addStyle(wb_out, fg, if (x$unita[1] == "numero" && grepl("^n_", cod)) st_int else st_body, rows = (r + 3):(r + 8), cols = 2:16, gridExpand = TRUE)
    addStyle(wb_out, fg, st_tutti, rows = r + 8, cols = 1:16, gridExpand = TRUE, stack = TRUE)
    r <- r + 11
  }
  setColWidths(wb_out, fg, cols = 1, widths = 22); setColWidths(wb_out, fg, cols = 2:16, widths = 9.5)
  freezePane(wb_out, fg, firstActiveCol = 2)
}
addWorksheet(wb_out, "controlli"); writeData(wb_out, "controlli", controlli, headerStyle = st_hdr); setColWidths(wb_out, "controlli", 1:ncol(controlli), 18)
addWorksheet(wb_out, "per_round"); writeData(wb_out, "per_round", per_round, headerStyle = st_hdr)
addStyle(wb_out, "per_round", st_body, rows = 2:(nrow(per_round) + 1), cols = 3:ncol(per_round), gridExpand = TRUE)
setColWidths(wb_out, "per_round", cols = 1:ncol(per_round), widths = c(10, 7, 9, 12, rep(14, ncol(per_round) - 4)))
addWorksheet(wb_out, "dati_lunghi"); writeData(wb_out, "dati_lunghi", lunghi, headerStyle = st_hdr)
LEGGIMI <- c(
  "Analisi descrittiva per paese, quintile e area. Script: descrittive_5paesi.R (github.com/paolo-medei/PhD, code/analysis).",
  "Dati: LSMS-ISA. Tanzania NPS 2008-2020 (5 round), Etiopia ESS 2015-2021 (3), Malawi IHS/IHPS 2010-2024 (4), Nigeria GHS-Panel 2010-2023 (5), Uganda UNPS 2010-2019 (6).",
  "Famiglie: quelle dello script LAAIDS_2stadi.R (budget alimentare positivo). Tutti i round insieme: i pesi campionari sono riscalati a somma 1 in ogni round.",
  "Quintili: nazionali, di consumo totale PER PERSONA (aggregato ufficiale / ampiezza), dentro ogni round, pesati per persona: ogni quintile = 20% delle persone. Q1 = il piu' povero.",
  "Aree: rurale / urbana come nell'indagine. Le celle urbane dei quintili poveri hanno poche famiglie: guardare n_famiglie nel foglio dati_lunghi.",
  "Medie per PERSONA (peso x ampiezza): consumo per persona e poverta'. Medie per FAMIGLIA (peso): quote, % di famiglie, demografia.",
  "Dollari PPP 2021 al giorno = valore annuo / ampiezza / 365 x CPI(2021) / CPI(anno dei prezzi) / fattore PPP 2021 (Banca Mondiale, consumo delle famiglie).",
  "  Anno dei prezzi: anno dell'intervista se noto, altrimenti meta' del lavoro sul campo. Malawi: aggregati ufficiali reali (prezzi dell'inizio dell'indagine).",
  "  Uganda 2010-2011: consumo totale ufficiale a prezzi costanti 2005/06. Nigeria 2023: prezzi 2023. Approssimazione: 10-15% nei round a cavallo di due anni con inflazione alta.",
  "Quota del cibo: cibo ufficiale / consumo totale ufficiale. Tanzania foodIN+foodOUT (con bevande e pasti fuori), Etiopia food_cons_ann (cibo a casa), Malawi rexp_cat011 (solo cibo),",
  "  Nigeria cibo a casa + fuori; Uganda nessun aggregato ufficiale: nostro cibo a casa x 52 / totale. Le definizioni non sono identiche fra paesi.",
  "Poverta': consumo totale per persona < 3,00 $ PPP 2021 al giorno. INDICATIVO: non e' la misura ufficiale (gli aggregati ufficiali di poverta' usano deflatori spaziali propri).",
  "ASF e categorie: nostro budget alimentare (cibo consumato a casa negli ultimi 7 giorni: acquisti + autoproduzione + regali ai prezzi locali), come nel LA/AIDS.",
  "  'Consumato negli ultimi 7 giorni': con il ricordo di 7 giorni uno zero puo' voler dire 'non comprato quella settimana', non 'mai consumato'.",
  "Mercato: quota del VALORE consumato che viene da acquisti, autoproduzione, regali; 'non attribuito' = voci con solo il totale. Nigeria 2012-2015: acquisti = consumo da acquisti.",
  "Qualita': valore unitario di ogni acquisto / mediana dello stesso prodotto e unita' nello stesso distretto (o regione, o paese se meno di 5 acquisti), media del logaritmo, in %.",
  "  +10% = paga il 10% in piu' dei vicini per lo stesso prodotto: segno di qualita' migliore (tagli, prodotti trasformati). La versione NAZIONALE include anche le differenze di prezzo fra luoghi.",
  "Escluse: famiglie con cibo a casa (7 giorni x 52) piu' di 3 volte il consumo totale annuo: errori di misura nei nostri valori (0,1-1% per paese, foglio controlli).",
  "Grafici: cartella 'grafici' accanto a questo file.")
addWorksheet(wb_out, "leggimi"); writeData(wb_out, "leggimi", data.frame(Note = LEGGIMI), headerStyle = st_hdr); setColWidths(wb_out, "leggimi", 1, 180)
worksheetOrder(wb_out) <- match(c("leggimi", names(TITOLI), "per_round", "controlli", "dati_lunghi"), names(wb_out))
FILE_X <- file.path(USCITA, paste0("Descrittive_5paesi_", Sys.Date(), ".xlsx"))
saveWorkbook(wb_out, FILE_X, overwrite = TRUE)
write.csv(lunghi, file.path(USCITA, "descrittive_lunghi.csv"), row.names = FALSE)
cat("\nSaved:", FILE_X, "\n")


## =============================================================================
## 8. CHARTS (PNG): one line per country, quintiles on the x axis, rural and urban side by side
## =============================================================================
dir.create(file.path(USCITA, "grafici"), showWarnings = FALSE)
COLORI <- c(Tanzania = "#1F77B4", Etiopia = "#D62728", Malawi = "#2CA02C", Nigeria = "#FF7F0E", Uganda = "#9467BD")
grafico <- function(cod, titolo, asse, file, aree = c("Rurali", "Urbane")) {
  x <- lunghi %>% filter(codice == cod, quintile != "Tutti", area %in% aree) %>% mutate(quintile = factor(quintile, levels = paste0("Q", 1:5)))
  g <- ggplot(x, aes(quintile, valore, colour = paese, group = paese)) + geom_line(linewidth = 0.9) + geom_point(size = 2) +
    facet_wrap(~ area) + scale_colour_manual(values = COLORI, name = NULL) +
    labs(title = titolo, x = "Quintile di consumo per persona (Q1 = 20% piu' povero)", y = asse,
         caption = "Dati LSMS-ISA, tutti i round. Elaborazione: descrittive_5paesi.R") +
    theme_minimal(base_size = 11) + theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
  ggsave(file.path(USCITA, "grafici", file), g, width = 9, height = 5, dpi = 200, bg = "white")
}
grafico("quota_cibo", "Quota del cibo sul consumo totale", "% del consumo totale", "01_quota_cibo.png")
grafico("tot_mediana", "Consumo totale per persona (mediana)", "$ PPP 2021 al giorno", "02_consumo_totale.png")
grafico("cons_carne", "Famiglie che hanno consumato carne negli ultimi 7 giorni", "% famiglie", "03_consumo_carne.png")
grafico("asf_ppp", "Spesa in alimenti di origine animale per persona", "$ PPP 2021 al giorno", "04_spesa_asf.png")
grafico("quota_asf", "Quota degli ASF nel budget alimentare", "% del budget alimentare", "05_quota_asf.png")
grafico("acquisti_asf", "Quota degli ASF che viene dal mercato (acquisti)", "% del valore consumato", "06_mercato_asf.png")
grafico("uv_loc_carne", "Carne: valore unitario rispetto ai vicini (qualita')", "% sopra la mediana del distretto", "07_qualita_carne.png")
cat("Charts saved in:", file.path(USCITA, "grafici"), "\n")
