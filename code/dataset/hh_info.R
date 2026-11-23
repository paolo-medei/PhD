###############################################################################
##  CARATTERISTICHE DELLE FAMIGLIE per il dataset sulle proteine (v1, 23 nov 2026)
##
##  Prende dai pannelli della pipeline (OUTPUT/panel_XXX.csv) una riga per
##  famiglia e wave con le variabili usate finora nello Step I (pesi, dimensione,
##  adulti equivalenti, benessere, regione, cluster, urbano, composizione), e
##  aggiunge: la spesa alimentare annua degli aggregati ufficiali (food_spend()
##  della PARTE 14b), l'identificativo che collega la famiglia fra le wave
##  (panel_ids() della PARTE 9), il campo profughi del Malawi 2024. Le funzioni
##  si leggono dallo script principale, cosi' sono le stesse usate nelle stime.
##  USO  Rscript hh_info.R <ASF_completo.R> <cartella dei dati> <OUTPUT> <out.csv>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(tidyr); library(stringr); library(purrr) })
args <- commandArgs(TRUE)
SCRIPT <- args[1]; DATA_ROOT <- ARCH_ROOT <- args[2]; OUT_DIR <- args[3]; OUTF <- args[4]
if (dir.exists(file.path(DATA_ROOT, "_unzipped"))) ARCH_ROOT <- file.path(DATA_ROOT, "_unzipped")

## funzioni e tabelle dello script principale, cercate anche dentro i blocchi if
want <- c("num", "find_dta", "grab", "panel_ids", "ROB_FOOD", "rob_id", "food_spend", "idstr")
walk_ex <- function(e) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) && as.character(e[[2]]) %in% want &&
      !exists(as.character(e[[2]]), envir = globalenv(), inherits = FALSE)) { eval(e, globalenv()); return(invisible()) }
  if (is.call(e) && (identical(e[[1]], as.name("if")) || identical(e[[1]], as.name("{"))))
    for (k in as.list(e)[-1]) if (!is.null(k)) walk_ex(k)
}
for (e in parse(SCRIPT, keep.source = FALSE)) walk_ex(e)
miss <- want[!sapply(want, exists)]; if (length(miss)) stop("not found in the script: ", paste(miss, collapse = ", "))

one <- function(cc) {
  d <- read.csv(file.path(OUT_DIR, sprintf("panel_%s.csv", cc)), colClasses = c(hhid = "character"), stringsAsFactors = FALSE)
  pick <- function(...) { for (n in c(...)) if (n %in% names(d)) return(d[[n]]); rep(NA, nrow(d)) }
  h <- tibble(country = cc, year = as.numeric(d$year), wave = d$wave, hhid = d$hhid,
              weight = as.numeric(pick("hhweight", "weight")), hhsize = as.numeric(pick("hhsize", "hh_size")),
              adulteq = as.numeric(pick("adulteq")), welfare = as.numeric(pick("welfare", "nom_totcons_aeq")),
              total_cons_ann_eth = as.numeric(pick("total_cons_ann")),
              region = as.character(pick("region")), zone = as.character(pick("zone")), woreda = as.character(pick("woreda")),
              state = as.character(pick("state")), lga = as.character(pick("lga")),
              cluster = as.character(pick("clusterid", "ea_id")), strata = as.character(pick("strataid")),
              urban_code = as.character(pick("urban", "urban_code", "sector")),
              n_members = as.numeric(pick("n_members")), share_child = as.numeric(pick("share_child")),
              share_elderly = as.numeric(pick("share_elderly")), share_female = as.numeric(pick("share_female")),
              head_age = as.numeric(pick("head_age")), head_female = as.numeric(pick("head_female"))) %>%
    distinct(year, hhid, .keep_all = TRUE)
  ## rurale dal codice grezzo, come nella PARTE 12: 1 = rurale in Etiopia e Tanzania,
  ## 2 = rurale in Nigeria (settore), 0 = rurale in Malawi e Uganda
  ur <- trimws(h$urban_code)
  h$rural <- ifelse(is.na(ur) | ur == "", NA_integer_, as.integer(
    if (cc %in% c("ETH", "TZA")) ur %in% c("1", "1.0") else if (cc == "NGA") ur %in% c("2", "2.0") else ur %in% c("0", "0.0")))
  ## spesa alimentare annua dell'aggregato ufficiale
  fs <- try(food_spend(cc), silent = TRUE)
  if (!inherits(fs, "try-error") && nrow(fs)) h <- h %>% left_join(fs %>% rename(food_cons_annual_official = food) %>%
                                                                       mutate(year = as.numeric(year)), by = c("year", "hhid"))
  else h$food_cons_annual_official <- NA_real_
  ## collegamento fra le wave
  pid <- try(panel_ids(cc), silent = TRUE)
  if (!inherits(pid, "try-error") && !is.null(pid) && nrow(pid))
    h <- h %>% left_join(pid %>% distinct(wave, hhid, .keep_all = TRUE) %>% select(wave, hhid, panel_id = pid), by = c("wave", "hhid"))
  else h$panel_id <- NA_character_
  h
}
H <- map_dfr(c("ETH", "TZA", "MWI", "NGA", "UGA"), one)

## Malawi 2024: il campo profughi di Dzaleka (camp = 1) e' nel modulo alimentare
## ma non nel pannello (non ha aggregato di consumo); qui entra con il segnale
cv <- haven::read_dta(find_dta("hh_mod_a_filt", "MWI_2024"))
camp <- if ("camp" %in% names(cv)) tibble(hhid = trimws(as.character(cv$case_id)), camp = num(cv$camp)) else NULL
if (!is.null(camp)) {
  cvx <- cv %>% transmute(hhid = trimws(as.character(case_id)), c_region = as.character(num(if ("district" %in% names(cv)) district else hh_a01)),
                          c_urban = ifelse(tolower(trimws(as.character(haven::as_factor(reside)))) == "urban", "1", "0"),
                          c_cluster = trimws(as.character(ea_id)), c_weight = num(hh_wgt)) %>% distinct(hhid, .keep_all = TRUE)
  extra <- camp %>% filter(camp %in% 1, !hhid %in% H$hhid[H$country == "MWI" & H$year == 2024]) %>% left_join(cvx, by = "hhid") %>%
    transmute(country = "MWI", year = 2024, wave = "w4", hhid, weight = c_weight, region = c_region, cluster = c_cluster,
              urban_code = c_urban, rural = as.integer(c_urban == "0"))
  H <- bind_rows(H, extra)
  H$refugee_camp <- ifelse(H$country == "MWI" & H$year == 2024, as.integer(H$hhid %in% camp$hhid[camp$camp %in% 1]), NA_integer_)
}
## quinti di benessere per famiglia, dentro paese e wave, non pesati (come M16)
H <- H %>% group_by(country, year) %>% mutate(welfare_quintile = ifelse(is.na(welfare), NA, ntile(welfare, 5))) %>% ungroup()
write.csv(H, OUTF, row.names = FALSE, na = "")
cat(nrow(H), "households;", sum(duplicated(H[, c("country", "year", "hhid")])), "duplicated country-year-hhid\n")
print(H %>% group_by(country, year) %>% summarise(n = n(), weight = mean(!is.na(weight)), welfare = mean(!is.na(welfare)),
                                                 food_off = mean(!is.na(food_cons_annual_official)), panel = mean(!is.na(panel_id)),
                                                 rural = mean(!is.na(rural)), .groups = "drop") %>% as.data.frame())
