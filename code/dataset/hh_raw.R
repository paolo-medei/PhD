###############################################################################
##  VARIABILI DI FAMIGLIA ORIGINALI per il dataset sulle proteine (v2, 23 nov 2026)
##
##  Solo valori come sono nei file .dta delle indagini: nessuna ricodifica,
##  nessuna divisione, nessun valore ricostruito. Per ogni wave si leggono la
##  copertina (cover) e l'aggregato ufficiale di consumo, e ogni variabile
##  originale va in una colonna:
##    - le variabili di disegno e di famiglia (peso, regione, distretto, EA,
##      strato, urbano/rurale, dimensione, adulti equivalenti, mese e anno
##      dell'intervista) in colonne comuni, con il nome originale di ogni wave
##      nel file delle fonti (i codici restano quelli dell'indagine: per esempio
##      urban_rural vale 1 = rurale in Etiopia e 1 = urbano in Malawi);
##    - le variabili dell'aggregato di consumo con il loro nome originale,
##      precedute da agg_ (agg_expmR, agg_totcons, agg_welfare, ...).
##  USO  Rscript hh_raw.R <cartella _unzipped> <out.csv> <fonti.csv>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(purrr) })
args <- commandArgs(TRUE); ROOT <- args[1]; OUTF <- args[2]; SRCF <- args[3]
find_dta <- function(stem, hint) {
  f <- list.files(ROOT, pattern = paste0("^", stem, "\\.dta$"), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  f <- f[grepl(hint, f, ignore.case = TRUE)]; if (length(f)) f[1] else NA_character_ }
idstr <- function(x) { x <- zap_labels(x); if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x)) }

## fonte: file, indizio della cartella, id della famiglia, colonne comuni (ruolo = variabile), variabili dell'aggregato
S <- function(file, hint, id, roles = c(), agg = c()) list(file = file, hint = hint, id = id, roles = roles, agg = agg)
ETH_AGG <- c("total_cons_ann", "food_cons_ann", "nonfood_cons_ann", "nom_totcons_aeq", "cons_quint", "price_index_hce",
             "fafh_cons_ann", "nom_foodcons_aeq", "spat_totcons_aeq")
TZA_AGG <- c("expm", "expmR", "foodbev", "foodbevR", "foodIN", "foodINR", "foodOUT", "foodOUTR", "expmR_pae", "foodINR_pae", "foodOUTR_pae")
MWI_AGG <- c("expagg", "rexpagg", "expaggpc", "rexpaggpc", "exp_cat011", "rexp_cat011", "price_index", "price_indexL")
NGA_AGG <- "^(totcons|totcons_pc|totcons_adj|fd.*|food_.*|reg_def_mean)$"
UGA_AGG <- c("welfare", "cpexp30", "nrrexp30", "fcpexp30", "fnrfxp30", "quints", "poor10", "poor_13", "poor_2015_2016", "poor_2019", "poor_2020")
R <- list(
  list("ETH", 2011, S("sect_cover_hh_w1", "ETH_2011", "household_id", c(region = "saq01", district = "saq02", subdistrict = "saq03", ea = "ea_id", urban_rural = "rural")),
                    S("cons_agg_w1", "ETH_2011", "household_id", c(weight = "pw", hhsize = "hh_size", adulteq = "adulteq"), ETH_AGG)),
  list("ETH", 2013, S("sect_cover_hh_w2", "ETH_2013", "household_id2", c(region = "saq01", district = "saq02", subdistrict = "saq03", ea = "ea_id2", urban_rural = "rural")),
                    S("cons_agg_w2", "ETH_2013", "household_id2", c(weight = "pw2", hhsize = "hh_size", adulteq = "adulteq"), ETH_AGG)),
  list("ETH", 2015, S("sect_cover_hh_w3", "ETH_2015", "household_id2", c(region = "saq01", district = "saq02", subdistrict = "saq03", ea = "ea_id2", urban_rural = "rural")),
                    S("cons_agg_w3", "ETH_2015", "household_id2", c(weight = "pw_w3", hhsize = "hh_size", adulteq = "adulteq"), ETH_AGG)),
  list("ETH", 2018, S("sect_cover_hh_w4", "ETH_2018", "household_id", c(region = "saq01", district = "saq02", subdistrict = "saq03", ea = "ea_id", urban_rural = "saq14")),
                    S("cons_agg_w4", "ETH_2018", "household_id", c(weight = "pw_w4", hhsize = "hh_size", adulteq = "adulteq"), ETH_AGG)),
  list("ETH", 2021, S("sect_cover_hh_w5", "ETH_2021", "household_id", c(region = "saq01", district = "saq02", subdistrict = "saq03", ea = "ea_id", urban_rural = "saq14")),
                    S("cons_agg_w5", "ETH_2021", "household_id", c(weight = "pw_w5", hhsize = "hh_size", adulteq = "adulteq"), ETH_AGG)),
  list("TZA", 2008, S("SEC_A_T", "TZA_2008", "hhid", c(district = "district", ea = "clusterid", strata = "strataid")),
                    S("TZY1.HH.Consumption", "TZA_2008", "hhid", c(weight = "hhweight", region = "region", urban_rural = "urban", hhsize = "hhsize", adulteq = "adulteq",
                                                                   int_month = "intmonth", int_year = "intyear"), TZA_AGG)),
  list("TZA", 2010, S("HH_SEC_A", "TZA_2010", "y2_hhid", c(district = "district", ea = "clusterid")),
                    S("TZY2.HH.Consumption", "TZA_2010", "y2_hhid", c(weight = "hhweight", region = "region", strata = "strata", urban_rural = "urban", hhsize = "hhsize",
                                                                      adulteq = "adulteq", int_month = "intmonth", int_year = "intyear"), TZA_AGG)),
  list("TZA", 2012, S("HH_SEC_A", "TZA_2012", "y3_hhid", c(weight = "y3_weight", ea = "clusterid", strata = "strataid")),
                    S("ConsumptionNPS3", "TZA_2012", "y3_hhid", c(region = "region", urban_rural = "urban", hhsize = "hhsize", adulteq = "adulteq"), TZA_AGG)),
  list("TZA", 2014, S("hh_sec_a", "TZA_2014", "y4_hhid", c(ea = "clusterid", strata = "strataid")),
                    S("consumptionNPS4", "TZA_2014", "y4_hhid", c(weight = "hhweight", region = "region", district = "district", urban_rural = "urban", hhsize = "hhsize",
                                                                  adulteq = "adulteq", int_month = "intmonth", int_year = "intyear"), TZA_AGG)),
  list("TZA", 2020, S("hh_sec_a", "TZA_2020", "y5_hhid", c(ea = "clusterid", strata = "strataid")),
                    S("consumption_real_y5", "TZA_2020", "y5_hhid", c(weight = "hhweight", region = "region", district = "district", urban_rural = "urban", hhsize = "hhsize",
                                                                      adulteq = "adulteq", int_month = "intmonth", int_year = "intyear"), TZA_AGG)),
  list("MWI", 2010, S("hh_mod_a_filt", "MWI_2010_IHS-III.*Full_Sample", "case_id", c(weight = "hh_wgt", district = "hh_a01", ea = "ea_id", urban_rural = "reside")),
                    S("ihs3fc2M_consumption", "MWI_2010_IHS-III.*Full_Sample", "case_id", c(), MWI_AGG)),
  list("MWI", 2016, S("hh_mod_a_filt", "MWI_2016", "case_id", c(weight = "hh_wgt", region = "region", district = "district", ea = "ea_id", urban_rural = "reside")),
                    S("ihs4 consumption aggregate", "MWI_2016", "case_id", c(hhsize = "hhsize", adulteq = "adulteq", int_month = "smonth", int_year = "syear"), MWI_AGG)),
  list("MWI", 2019, S("hh_mod_a_filt", "MWI_2019", "case_id", c(weight = "hh_wgt", region = "region", district = "district", ea = "ea_id", urban_rural = "reside")),
                    S("ihs5_consumption_aggregate", "MWI_2019", "case_id", c(hhsize = "hhsize", adulteq = "adulteq", int_month = "smonth", int_year = "syear"), MWI_AGG)),
  list("MWI", 2024, S("hh_mod_a_filt", "MWI_2024", "case_id", c(weight = "hh_wgt", region = "region", district = "district", ea = "ea_id", urban_rural = "reside",
                                                              strata = "strata", hhsize = "hhsize", refugee_camp_sample = "camp")),
                    S("ihs6_consumptionaggregates", "MWI_2024", "case_id", c(int_month = "smonth", int_year = "syear"), MWI_AGG)),
  list("NGA", 2010, S("cons_agg_wave1_visit2", "NGA_2010", "hhid", c(weight = "hhweight", region = "zone", district = "state", subdistrict = "lga", ea = "ea",
                                                                     urban_rural = "rururb", hhsize = "hhsize"), NGA_AGG)),
  list("NGA", 2012, S("cons_agg_wave2_visit2", "NGA_2012", "hhid", c(weight = "hhweight", region = "zone", district = "state", subdistrict = "lga", ea = "ea",
                                                                     urban_rural = "rururb", hhsize = "hhsize"), NGA_AGG)),
  list("NGA", 2015, S("cons_agg_wave3_visit2", "NGA_2015", "hhid", c(weight = "hhweight", region = "zone", district = "state", subdistrict = "lga", ea = "ea",
                                                                     urban_rural = "rururb", hhsize = "hhsize"), NGA_AGG)),
  list("NGA", 2018, S("secta_harvestw4", "NGA_2018", "hhid", c(weight = "wt_wave4", region = "zone", district = "state", subdistrict = "lga", ea = "ea",
                                                               strata = "strata", urban_rural = "sector")),
                    S("totcons_final", "NGA_2018", "hhid", c(hhsize = "hhsize"), NGA_AGG)),
  list("NGA", 2023, S("secta_harvestw5", "NGA_2023", "hhid", c(weight = "wt_cross_wave5", region = "zone", district = "state", subdistrict = "lga", ea = "ea",
                                                               strata = "strata", urban_rural = "sector")),
                    S("totcons_final", "NGA_2023", "hhid", c(hhsize = "hhsize"), NGA_AGG)),
  list("UGA", 2010, S("GSEC1", "UGA_2010", "HHID", c(weight = "wgt10", region = "region", district = "h1aq1", ea = "comm", strata = "stratum", urban_rural = "urban",
                                                     int_month = "month", int_year = "year")),
                    S("pov2010_11", "UGA_2010", "hh", c(hhsize = "hsize", adulteq = "equiv"), UGA_AGG)),
  list("UGA", 2011, S("GSEC1", "UGA_2011", "HHID", c(weight = "mult", region = "region", district = "h1aq1", ea = "comm", urban_rural = "urban", int_month = "month", int_year = "year")),
                    S("UNPS 2011-12 Consumption Aggregate", "UGA_2011", "HHID", c(adulteq = "equiv"), UGA_AGG)),
  list("UGA", 2013, S("GSEC1", "UGA_2013", "hhid", c(weight = "wgt_X", region = "region", district = "h1aq1a", ea = "ea", urban_rural = "urban", int_month = "month", int_year = "year")),
                    S("pov2013_14", "UGA_2013", "hhid", c(hhsize = "hsize", adulteq = "equiv"), UGA_AGG)),
  list("UGA", 2015, S("gsec1", "UGA_2015", "hh", c(weight = "h_xwgt_W5", region = "region", district = "district", ea = "ea", urban_rural = "urban", int_month = "month", int_year = "year")),
                    S("pov2015_16", "UGA_2015", "hh", c(hhsize = "hsize", adulteq = "equiv"), UGA_AGG)),
  list("UGA", 2018, S("GSEC1", "UGA_2018", "hhid", c(weight = "wgt", region = "region", district = "district_code", subdistrict = "subcounty_code", ea = "parish_code",
                                                     urban_rural = "urban", int_month = "month", int_year = "year")),
                    S("pov2018_19", "UGA_2018", "hhid", c(hhsize = "hsize", adulteq = "equiv"), UGA_AGG)),
  list("UGA", 2019, S("gsec1", "UGA_2019", "hhid", c(weight = "wgt", region = "region", district = "dc_2018", subdistrict = "sc_2018", ea = "pc_2018",
                                                     urban_rural = "urban", int_month = "month", int_year = "year")),
                    S("pov2019_20", "UGA_2019", "hhid", c(hhsize = "hsize", adulteq = "equiv"), UGA_AGG)))
ROLES <- c("weight", "region", "district", "subdistrict", "ea", "strata", "urban_rural", "hhsize", "adulteq", "int_month", "int_year", "refugee_camp_sample")

vlab <- function(x) { l <- attr(x, "labels"); if (is.null(l) || !length(l)) "" else paste(paste0(unname(l), "=", names(l)), collapse = "; ") }
## valori come testo esatto per poter unire le wave (un codice puo' essere numero in una wave e testo in
## un'altra); il tipo originale di ogni variabile e' nel file delle fonti (stata_type)
vtxt <- function(x) { x <- zap_labels(x)
  if (is.numeric(x)) { y <- formatC(x, digits = 15, format = "fg"); y[is.na(x)] <- NA_character_; trimws(y) } else {
    y <- as.character(x); y[!is.na(y)] <- trimws(y[!is.na(y)]); y[y %in% ""] <- NA_character_; y } }
OUT <- list(); SRC <- list()
for (r in R) {
  cc <- r[[1]]; yr <- r[[2]]; srcs <- r[-(1:2)]
  if (any(is.na(sapply(srcs, function(s) find_dta(s$file, s$hint))))) { cat("skip", cc, yr, "(files missing)\n"); next }
  H <- NULL
  for (s in srcs) {
    p <- find_dta(s$file, s$hint); d <- read_dta(p)
    if (!s$id %in% names(d)) stop(cc, yr, ": no ", s$id, " in ", basename(p))
    keepr <- s$roles[s$roles %in% names(d)]
    if (length(miss <- setdiff(s$roles, names(d)))) cat("  ", cc, yr, basename(p), "lacks", paste(miss, collapse = ", "), "\n")
    aggv <- if (length(s$agg) == 1 && grepl("^\\^", s$agg)) grep(s$agg, names(d), value = TRUE) else intersect(s$agg, names(d))
    x <- tibble(hhid = idstr(d[[s$id]]))
    for (k in names(keepr)) x[[k]] <- vtxt(d[[keepr[[k]]]])
    for (v in aggv) x[[paste0("agg_", v)]] <- vtxt(d[[v]])
    ndup <- sum(duplicated(x$hhid))
    if (ndup) { cat("  ", cc, yr, basename(p), ndup, "duplicated household rows: first kept\n"); x <- x[!duplicated(x$hhid), ] }
    SRC[[length(SRC) + 1]] <- tibble(country = cc, year = yr, file = basename(p), id_variable = s$id,
      column = c(names(keepr), paste0("agg_", aggv, recycle0 = TRUE)), variable = c(unname(keepr), aggv),
      label = sapply(c(unname(keepr), aggv), function(v) { l <- attr(d[[v]], "label"); if (is.null(l)) "" else l }),
      value_labels = sapply(c(unname(keepr), aggv), function(v) vlab(d[[v]])),
      stata_type = sapply(c(unname(keepr), aggv), function(v) if (is.numeric(zap_labels(d[[v]]))) "numeric" else "string"),
      duplicated_rows_in_file = ndup)
    H <- if (is.null(H)) x else full_join(H, x %>% select(-any_of(setdiff(intersect(names(H), names(x)), "hhid"))), by = "hhid")
  }
  OUT[[paste(cc, yr)]] <- H %>% mutate(country = cc, year = yr, .before = 1)
  cat(cc, yr, nrow(H), "households,", ncol(H) - 1, "variables\n")
}
## i codici restano testo dove nel file sono testo; i numeri restano numeri
ALL <- bind_rows(OUT)
ALL <- ALL %>% select(country, year, hhid, any_of(ROLES), sort(grep("^agg_", names(ALL), value = TRUE)))
write.csv(ALL, OUTF, row.names = FALSE, na = "")
write.csv(bind_rows(SRC), SRCF, row.names = FALSE, na = "")
cat(nrow(ALL), "households,", ncol(ALL), "columns\n")
