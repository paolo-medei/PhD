###############################################################################
##  VARIABILI ORIGINALI DEL MODULO ALIMENTARE, una per colonna del dataset
##
##  Per ogni wave scrive quale variabile del file .dta riempie ogni colonna
##  delle voci (consumo si'/no, quantita', unita', spesa, per fonte), con
##  l'etichetta del file, e i totali di controllo calcolati DIRETTAMENTE dal
##  file grezzo sulle voci proteiche (righe non vuote, somma, valori distinti).
##  Il controllo di qualita' confronta questi totali con il dataset finale:
##  se coincidono, ogni valore e' stato copiato senza cambiarlo.
##  Le regole dei nomi sono le stesse di build_protein_dataset.R, riscritte qui.
##  USO  Rscript role_vars.R <cartella _unzipped> <item_map.csv> <out.csv>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(purrr) })
args <- commandArgs(TRUE); ROOT <- args[1]; MAP <- read.csv(args[2]); OUTF <- args[3]
find_dta <- function(stem, hint) {
  f <- list.files(ROOT, pattern = paste0("^", stem, "\\.dta$"), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  f <- f[grepl(hint, f, ignore.case = TRUE)]; if (length(f)) f[1] else NA_character_ }
first <- function(d, ...) { v <- c(...); v <- v[v %in% names(d)]; if (length(v)) v[1] else NA_character_ }

eth <- function(yr, d) {
  if (yr %in% c(2011, 2013, 2015)) { p <- "hh_s5aq"; s <- "_" } else { p <- "s6aq"; s <- "" }
  oth <- function(k) first(d, paste0(p, k, "_b_other"), paste0(p, k, "b_others3"), paste0("s5aq", k, "b_others"), paste0(p, k, "b_os"))
  c(cons_raw = paste0(p, "01"), q_tot = paste0(p, "02", s, "a"), u_tot = paste0(p, "02", s, "b"), uo_tot = oth("02"),
    q_pur = paste0(p, "03", s, "a"), u_pur = paste0(p, "03", s, "b"), uo_pur = oth("03"), exp_pur = paste0(p, "04"),
    q_own = paste0(p, "05", s, "a"), u_own = paste0(p, "05", s, "b"), uo_own = oth("05"),
    q_gift = paste0(p, "06", s, "a"), u_gift = paste0(p, "06", s, "b"), uo_gift = oth("06"))
}
tza <- function(yr, d, pre) {
  if (yr == 2008) return(c(cons_raw = "skq1", q_tot = "skq2_amount", u_tot = "skq2_meas", q_pur = "skq3_amount", u_pur = "skq3_meas", exp_pur = "skq4",
                           q_own = "skq5_amount", u_own = "skq5_meas", q_gift = "skq6_amount", u_gift = "skq6_meas"))
  c(cons_raw = if (yr == 2010) "hh_k01_2" else paste0(pre, "01"), q_tot = paste0(pre, "02_2"), u_tot = paste0(pre, "02_1"),
    q_pur = paste0(pre, "03_2"), u_pur = paste0(pre, "03_1"), exp_pur = paste0(pre, "04"), q_own = paste0(pre, "05_2"), u_own = paste0(pre, "05_1"),
    q_gift = paste0(pre, "06_2"), u_gift = paste0(pre, "06_1"), q_wt = paste0(pre, "02b_2"), u_wt = paste0(pre, "02b_1"))
}
mwi <- function(yr, d) {
  o <- function(b) first(d, paste0(b, "_oth"), paste0(b, "_os")); z <- function(b) first(d, paste0(b, "c"), paste0(b, "c_1"))
  c(cons_raw = "hh_g01", q_tot = "hh_g03a", u_tot = "hh_g03b", uo_tot = o("hh_g03b"), us_tot = z("hh_g03"),
    q_pur = "hh_g04a", u_pur = "hh_g04b", uo_pur = o("hh_g04b"), us_pur = z("hh_g04"), exp_pur = "hh_g05",
    q_own = "hh_g06a", u_own = "hh_g06b", uo_own = o("hh_g06b"), us_own = z("hh_g06"),
    q_gift = "hh_g07a", u_gift = "hh_g07b", uo_gift = o("hh_g07b"), us_gift = z("hh_g07"))
}
nga <- function(yr, d) {
  if (yr == 2018) return(c(cons_raw = "s10bq1", q_tot = "s10bq2a", u_tot = "s10bq2b", us_tot = "s10bq2c", q_frompur = "s10bq5a",
                           q_own = "s10bq6a", q_gift = "s10bq7a", pur30_yn = "s10bq8", q_lastpur = "s10bq9a", u_lastpur = "s10bq9b",
                           us_lastpur = "s10bq9c", val_lastpur = "s10bq10", cvn_tot = "s10bq2_cvn", cvn_lastpur = "s10bq9_cvn", os_item = "item_os_cd"))
  if (yr == 2023) return(c(cons_raw = "s5bq1", q_tot = "s5bq2a", u_tot = "s5bq2b", us_tot = "s5bq2c", q_frompur = "s5bq3",
                           q_own = "s5bq4", q_gift = "s5bq5", pur30_yn = "s5bq6", q_lastpur = "s5bq7a", u_lastpur = "s5bq7b",
                           us_lastpur = "s5bq7c", val_lastpur = "s5bq8", cvn_tot = "s5bq2_cvn", cvn_lastpur = "s5bq7_cvn", os_item = "item_os_cd"))
  own <- if (yr == 2010) "5" else "6"; gift <- if (yr == 2010) "6" else "7"; q <- "s10bq"
  x <- c(cons_raw = "s10bq1", q_tot = "s10bq2a", u_tot = "s10bq2b", uo_tot = first(d, "s10bq2b_os"), q_pur = "s10bq3a", u_pur = "s10bq3b",
         uo_pur = first(d, "s10bq3b_os"), exp_pur = "s10bq4", q_own = paste0(q, own, "a"), u_own = paste0(q, own, "b"), uo_own = first(d, paste0(q, own, "b_os")),
         q_gift = paste0(q, gift, "a"), u_gift = paste0(q, gift, "b"), uo_gift = first(d, paste0(q, gift, "b_os")))
  if (yr != 2010) x <- c(x, q_frompur = "s10bq5a", u_frompur = "s10bq5b")
  x
}
uga <- function(yr, d) {
  if (yr <= 2015) c(cons_raw = "h15bq3a", u_tot = "untcd", q_pur = "h15bq4", exp_pur = "h15bq5", q_away = "h15bq6", val_away = "h15bq7",
                    q_own = "h15bq8", val_own = "h15bq9", q_gift = "h15bq10", val_gift = "h15bq11", q_tot = "h15bq14")
  else c(cons_raw = "CEB03", u_tot = "CEB03C", q_pur = "CEB06", exp_pur = "CEB07", q_away = "CEB08", val_away = "CEB09",
         q_own = "CEB10", val_own = "CEB11", q_gift = "CEB012", val_gift = "CEB013")
}
R <- list(
  list("ETH", 2011, "sect5a_hh_w1", "ETH_2011", "hh_s5aq00", 2011), list("ETH", 2013, "sect5a_hh_w2", "ETH_2013", "hh_s5aq00", 2013),
  list("ETH", 2015, "sect5a_hh_w3", "ETH_2015", "item_cd", 2015), list("ETH", 2018, "sect6a_hh_w4", "ETH_2018", "item_cd", 2018),
  list("ETH", 2021, "sect6a_hh_w5", "ETH_2021", "item_cd", 2021),
  list("TZA", 2008, "SEC_K1", "TZA_2008", "skcode", 2008), list("TZA", 2010, "HH_SEC_K1", "TZA_2010", "itemcode", 2010),
  list("TZA", 2012, "HH_SEC_J1", "TZA_2012", "itemcode", 2012), list("TZA", 2014, "hh_sec_j1", "TZA_2014", "itemcode", 2014),
  list("TZA", 2020, "hh_sec_ja1", "TZA_2020", "itemcode", 2020), list("TZA", 2020, "hh_sec_j1", "TZA_2020", "itemcode", 2020.1),
  list("MWI", 2010, "hh_mod_g1", "MWI_2010_IHS-III.*Full_Sample", "hh_g02", 2010), list("MWI", 2016, "hh_mod_g1", "MWI_2016", "hh_g02", 2016),
  list("MWI", 2019, "hh_mod_g1", "MWI_2019", "hh_g02", 2019), list("MWI", 2024, "hh_mod_g1", "MWI_2024", "hh_g02", 2024),
  list("NGA", 2010, "sect10b_harvestw1", "NGA_2010", "item_cd", 2010), list("NGA", 2012, "sect10b_harvestw2", "NGA_2012", "item_cd", 2012),
  list("NGA", 2015, "sect10b_harvestw3", "NGA_2015", "item_cd", 2015),
  list("NGA", 2018, "sect10b_harvestw4", "NGA_2018", "item_cd", 2018),
  list("NGA", 2023, "sect5b_harvestw5", "NGA_2023", "item_cd", 2023),
  list("UGA", 2010, "GSEC15b", "UGA_2010", "itmcd", 2010), list("UGA", 2011, "GSEC15B", "UGA_2011", "itmcd", 2011),
  list("UGA", 2013, "GSEC15B", "UGA_2013", "itmcd", 2013), list("UGA", 2015, "gsec15b", "UGA_2015", "itmcd", 2015),
  list("UGA", 2018, "GSEC15B", "UGA_2018", "CEB01", 2018), list("UGA", 2019, "gsec15b", "UGA_2019", "CEB01", 2019))

out <- map_dfr(R, function(r) {
  cc <- r[[1]]; yr <- r[[2]]; p <- find_dta(r[[3]], r[[4]]); if (is.na(p)) return(NULL)
  d <- read_dta(p)
  vars <- switch(cc, ETH = eth(yr, d), TZA = tza(yr, d, if (r[[3]] == "hh_sec_j1" && yr == 2020) "hh_j" else
                   c(`2010` = "hh_k", `2012` = "hh_j", `2014` = "hh_j", `2020` = "hh_ja")[[as.character(yr)]]),
                 MWI = mwi(yr, d), NGA = nga(yr, d), UGA = uga(yr, d))
  vars <- vars[!is.na(vars)]
  codes <- MAP$code[MAP$country == cc & MAP$year == r[[6]]]
  prot <- as.numeric(zap_labels(d[[r[[5]]]])) %in% codes
  map_dfr(names(vars), function(k) {
    v <- vars[[k]]; ok <- v %in% names(d)
    x <- if (ok) zap_labels(d[[v]])[prot] else NULL
    isnum <- ok && is.numeric(x)
    xs <- if (ok && !isnum) { y <- trimws(as.character(x)); y[y %in% ""] <- NA; y } else NULL
    tibble(country = cc, year = yr, file = basename(p), role = k, variable = v, exists = ok,
           label = if (ok && !is.null(attr(d[[v]], "label"))) attr(d[[v]], "label") else "",
           stata_type = if (!ok) NA else if (isnum) "numeric" else "string",
           protein_rows = sum(prot), non_missing = if (!ok) NA_integer_ else if (isnum) sum(!is.na(x)) else sum(!is.na(xs)),
           sum = if (isnum) sum(as.numeric(x), na.rm = TRUE) else if (ok) sum(suppressWarnings(as.numeric(xs)), na.rm = TRUE) else NA_real_,
           non_numeric_text = if (ok && !isnum) sum(!is.na(xs) & is.na(suppressWarnings(as.numeric(xs)))) else 0L,
           distinct_values = if (!ok) NA_integer_ else if (isnum) length(unique(x[!is.na(x)])) else length(unique(xs[!is.na(xs)])),
           value_labels = if (!ok || !k %in% c("cons_raw", "pur30_yn", "os_item")) "" else {
             l <- attr(d[[v]], "labels"); l <- l[l %in% unique(x)]; paste(paste0(unname(l), "=", names(l)), collapse = "; ") })
  })
})
write.csv(out, OUTF, row.names = FALSE, na = "")
cat(nrow(out), "role x round rows;", sum(!out$exists), "variables not found\n")
print(out %>% filter(!exists))
