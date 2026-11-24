###############################################################################
##  ALL-FOOD LONG FILES: every item of the 7-day food module, every round (24 Nov 2026)
##
##  Same readers and unit converters as build_protein_dataset.R (sourced with LIB_ONLY),
##  applied to ALL items, not only the protein ones. One row per household x item as in
##  the module (no full grid: an item missing for a household is not consumed). The
##  category of each code comes from food_category_map.csv (food_categories_map.py).
##  Non-protein items: standard unit kg, litre for beverages; Malawi official 2020 table
##  used (as for plant protein items); Ethiopia Food_CF read with the 2015 code (crosswalk below).
##  Also writes the household food-away-from-home values of the separate modules:
##  Ethiopia 5D (2015) / 6B4 (2018-2021), Nigeria 10A (5A in 2023), Tanzania section F
##  (individual roster, summed over members). 7-day values, local currency.
##
##  USO  Rscript build_allfood_long.R <_unzipped> <out dir> <item_map.csv> <food_category_map.csv>
###############################################################################
LIB_ONLY <- TRUE
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
args <- commandArgs(TRUE)
source(file.path(here, "build_protein_dataset.R"))          # reads args[1:3]: _unzipped, out dir, item_map.csv
CATF <- args[4]
CAT <- read.csv(CATF, stringsAsFactors = FALSE) %>% filter(category != "header") %>%
  transmute(country, round = as.integer(round), module = ifelse(sample == "", NA, sample), code = as.numeric(code), category)

## Ethiopia 2018-2021 codes -> 2015 codes of the Food_CF tables (non-protein items; protein items have cf_code in item_map)
ETH_CF <- c(`101` = 1, `102` = 2, `103` = 3, `104` = 4, `105` = 5, `106` = 6, `109` = 60, `401` = 14, `402` = 141, `403` = 142,
            `404` = 143, `405` = 144, `408` = 145, `501` = 15, `502` = 151, `506` = 152, `601` = 16, `602` = 17, `603` = 26,
            `604` = 170, `605` = 171, `606` = 172, `607` = 173, `708` = 202, `710` = 22, `712` = 23, `801` = 24, `802` = 203,
            `803` = 204, `804` = 205, `805` = 206, `901` = 195, `902` = 196, `903` = 197, `904` = 198)
ETH_CF15 <- c(1:17, 19:26, 60, 110, 111, 131, 141:145, 151, 152, 170:173, 180:183, 195:198, 201:206)

any_q <- function(z) rowSums(cbind(z$q_tot, z$q_pur, z$q_own, z$q_gift, z$exp_pur, z$q_away, z$q_frompur, z$val_away, z$val_own, z$val_gift) > 0, na.rm = TRUE) > 0
LOG <- list()
for (cc in names(ROUNDS)) {
  LONG <- list()
  for (yr in ROUNDS[[cc]]) {
    if (cc == "ETH" && yr %in% c("2011", "2013")) next      # left out (23 Nov)
    t0 <- Sys.time()
    d <- READ[[cc]](yr)
    keep_attr <- Filter(Negate(is.null), attributes(d)[c("conv", "cf", "cv", "lab")])
    d$year <- as.numeric(yr)
    if (!"module" %in% names(d)) d$module <- NA_character_
    if (cc == "TZA" && yr != "2020") d$module <- NA_character_
    pm <- MAP %>% filter(country == cc, floor(year) == as.numeric(yr)) %>% distinct(code, .keep_all = TRUE) %>% select(code, std, cat, sub, cf_code)
    cm <- CAT %>% filter(country == cc, round == as.integer(yr)) %>% select(module, code, category)
    d <- if (cc == "TZA" && yr == "2020") d %>% left_join(cm, by = c("module", "code")) else d %>% left_join(cm %>% distinct(code, category), by = "code")
    mp <- tibble(code = sort(unique(d$code))) %>% left_join(pm, by = "code") %>%
      left_join(d %>% distinct(code, category) %>% group_by(code) %>% summarise(category = first(category)), by = "code") %>%
      mutate(std = coalesce(std, ifelse(category %in% "beverages", "litre", "kg")), cat = coalesce(cat, "plant"), sub = coalesce(sub, ""),
             cf_code = if (cc == "ETH") coalesce(cf_code, if (yr == "2015") ifelse(code %in% ETH_CF15, code, NA) else unname(ETH_CF[as.character(code)])) else cf_code) %>%
      select(-category)
    mod <- d$module; cat_ <- d$category
    d <- d %>% select(-module, -category)
    for (a in names(keep_attr)) attr(d, a) <- keep_attr[[a]]
    d <- CONV[[cc]](d, mp)
    stopifnot(nrow(d) == length(mod))
    d$module <- mod; d$category <- cat_
    if (!"s_away" %in% names(d)) d$s_away <- NA_real_
    if (!"s_frompur" %in% names(d)) d$s_frompur <- NA_real_
    oc <- paste(cc, yr, sep = "_") %in% ONLY_CONSUMED
    d <- d %>% mutate(
      cons = case_when(cons_raw == 1 | any_q(d) ~ 1, cons_raw == 2 ~ 0, oc ~ 1, TRUE ~ NA_real_),
      across(c(s_tot, s_pur, s_own, s_gift), ~ ifelse(cons %in% 0, 0, .x)))
    ## same purchase rules as the protein dataset
    if (cc == "UGA") d <- d %>% mutate(
      s_pur  = ifelse(cons %in% 1 & is.na(q_pur)  & is.na(exp_pur),  0, s_pur),
      s_own  = ifelse(cons %in% 1 & is.na(q_own)  & is.na(val_own),  0, s_own),
      s_gift = ifelse(cons %in% 1 & is.na(q_gift) & is.na(val_gift), 0, s_gift))
    d <- d %>% mutate(exp = case_when(
      cons %in% 0 ~ 0, exp_pur > 0 ~ exp_pur,
      cons %in% 1 & exp_pur %in% 0 & (is.na(q_pur) | q_pur %in% 0) ~ 0,
      cons %in% 1 & q_pur %in% 0 & is.na(exp_pur) ~ 0,
      cons %in% 1 & cc == "UGA" & is.na(q_pur) & is.na(exp_pur) ~ 0,
      TRUE ~ NA_real_))
    dup <- d %>% count(hhid, module, code) %>% filter(n > 1)
    LOG[[paste(cc, yr)]] <- tibble(country = cc, year = as.numeric(yr), rows = nrow(d), households = n_distinct(d$hhid),
      codes = n_distinct(d$code), consumed_rows = sum(d$cons %in% 1), cons_missing = sum(is.na(d$cons)),
      no_category = sum(is.na(d$category)), duplicated_hh_item = nrow(dup), only_consumed_listed = oc)
    cat(sprintf("%s %s: %6d rows, %5d hh, %3d codes, %6d consumed, %d without category, %d duplicated (%ss)\n", cc, yr, nrow(d),
                n_distinct(d$hhid), n_distinct(d$code), sum(d$cons %in% 1), sum(is.na(d$category)), nrow(dup),
                round(as.numeric(difftime(Sys.time(), t0, units = "secs")))))
    LONG[[yr]] <- d %>% filter(!(cons %in% 0)) %>% select(any_of(c("hhid", "year", "module", "code", "category", "cons", "cons_raw",
      "q_tot", "u_tot", "us_tot", "uo_tot", "q_pur", "u_pur", "us_pur", "uo_pur", "exp_pur", "exp", "q_own", "u_own", "us_own", "uo_own",
      "q_gift", "u_gift", "us_gift", "uo_gift", "q_away", "val_away", "val_own", "val_gift", "q_frompur", "u_frompur", "q_wt", "u_wt",
      "pur30_yn", "q_lastpur", "u_lastpur", "us_lastpur", "val_lastpur", "cvn_tot", "cvn_lastpur",
      "s_tot", "s_pur", "s_own", "s_gift", "s_away", "s_frompur", "conv_method")))
  }
  write.csv(bind_rows(LONG), gzfile(file.path(OUTD, paste0("allfood_long_", cc, ".csv.gz"))), row.names = FALSE, na = "")
  rm(LONG); gc()
}
write.csv(bind_rows(LOG), file.path(OUTD, "allfood_build_log.csv"), row.names = FALSE)

###############################################################################
## FOOD AWAY FROM HOME, separate modules: household x round, 7-day value
###############################################################################
fa <- list()
ag <- function(id, v, cc, yr, src) tibble(hhid = id, v = v) %>% group_by(hhid) %>%
  summarise(fafh_module = if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE), fafh_items = sum(v > 0, na.rm = TRUE), .groups = "drop") %>%
  mutate(country = cc, year = yr, fafh_source = src)
## Ethiopia
e3 <- rd("sect5d_hh_w3", "ETH_2015"); fa$e3 <- ag(idstr(e3$household_id2), ifelse(num(e3$hh_s5cq06) %in% 2, 0, num(e3$hh_s5cq07)), "ETH", 2015, "sect5d_hh_w3: hh_s5cq07")
for (w in c("2018" = "4", "2021" = "5")) { yr <- names(which(c("2018" = "4", "2021" = "5") == w))
  e <- rd(paste0("sect6b4_hh_w", w), paste0("ETH_", yr))
  fa[[yr]] <- ag(idstr(e$household_id), ifelse(num(e$s6bq06) %in% 2, 0, num(e$s6bq07)), "ETH", as.numeric(yr), paste0("sect6b4_hh_w", w, ": s6bq07")) }
## Nigeria (post-harvest visit, as the food module)
for (w in list(c("2010", "sect10a_harvestw1", "s10aq1", "s10aq2"), c("2012", "sect10a_harvestw2", "s10aq1", "s10aq2"),
               c("2015", "sect10a_harvestw3", "s10aq1", "s10aq2"), c("2018", "sect10a_harvestw4", "s10aq1", "s10aq2"),
               c("2023", "sect5a_harvestw5", "s5aq1", "s5aq2"))) {
  n <- rd(w[2], paste0("NGA_", w[1]))
  fa[[paste0("n", w[1])]] <- ag(idstr(n$hhid), ifelse(num(n[[w[3]]]) %in% 2, 0, num(n[[w[4]]])), "NGA", as.numeric(w[1]), paste0(w[2], ": ", w[4])) }
## Tanzania: section F, one row per member; values of the 7 groups (meals, barbecued meat/snacks, local brews,
## beer/wine/spirits, sodas, sweets/ice-cream, tea/coffee/snacks) summed over members
for (w in list(c("2008", "SEC_B_C_D_E1_F_G1_U", "hhid", "sfq"), c("2010", "HH_SEC_F", "y2_hhid", "hh_f"), c("2012", "HH_SEC_F", "y3_hhid", "hh_f"),
               c("2014", "hh_sec_f", "y4_hhid", "hh_f"), c("2020", "hh_sec_f", "y5_hhid", "hh_f"))) {
  t <- rd(w[2], paste0("TZA_", w[1]))
  vv <- if (w[1] == "2008") paste0("sfq", c(3, 5, 7, 9, 11, 13, 15)) else sprintf("hh_f%02d", c(3, 5, 7, 9, 11, 13, 15))
  m <- sapply(vv, function(v) num(t[[v]])); s <- rowSums(m, na.rm = TRUE); s[rowSums(!is.na(m)) == 0] <- NA
  any1 <- num(t[[if (w[1] == "2008") "sfq1" else "hh_f01"]])
  s[any1 %in% 2] <- 0
  fa[[paste0("t", w[1])]] <- ag(idstr(t[[w[3]]]), s, "TZA", as.numeric(w[1]), paste0(w[2], ": ", paste(vv, collapse = "+"), " (summed over members)")) }
FA <- bind_rows(fa)
write.csv(FA, file.path(OUTD, "fafh_modules_hh.csv"), row.names = FALSE, na = "")
print(FA %>% group_by(country, year) %>% summarise(hh = n(), with_value = sum(fafh_module > 0, na.rm = TRUE), na = sum(is.na(fafh_module)),
                                                   median_pos = median(fafh_module[fafh_module > 0], na.rm = TRUE)), n = 30)
cat("done\n")
