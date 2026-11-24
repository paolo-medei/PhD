###############################################################################
##  OFFICIAL FOOD AGGREGATES, household level, for the check D3 of the all-food dataset (24 Nov 2026)
##  annual, local currency, nominal where the file has it; food at home and food away from home apart.
##  Ethiopia cons_agg (food_cons_ann; fafh_cons_ann 2018-2021); Tanzania consumption files (foodIN, foodOUT);
##  Malawi consumption aggregate (cat011 food + cat012 beverages + cat021 alcohol at home, cat111 vendors/restaurants);
##  Nigeria cons_agg visit 2 (2010-2015: fd*by + fd*pr, fdrestby away) and totcons_final (2018-2023: food_own/purch 1-19,
##  food_meals20 away). Uganda: no food aggregate in the files.
##  USO  Rscript official_food_aggregates.R <_unzipped> <out.csv>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr) })
args <- commandArgs(TRUE); U <- args[1]
num <- function(x) suppressWarnings(as.numeric(zap_labels(x)))
idstr <- function(x) { x <- zap_labels(x); if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x)) }
f1 <- function(pat, hint) { f <- list.files(U, pattern = pat, recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  f <- f[grepl(hint, f)]; if (!length(f)) stop("missing ", pat, " ", hint); f[1] }
rs <- function(d, v) { v <- intersect(v, names(d)); if (!length(v)) return(rep(NA_real_, nrow(d))); m <- sapply(v, function(z) num(d[[z]])); if (is.null(dim(m))) m <- matrix(m, ncol = 1); rowSums(m, na.rm = TRUE) }
O <- list()
## Ethiopia
for (w in list(c("2015", "cons_agg_w3", "household_id2"), c("2018", "cons_agg_w4", "household_id"), c("2021", "cons_agg_w5", "household_id"))) {
  d <- read_dta(f1(paste0("^", w[2], "\\.dta$"), paste0("ETH_", w[1])))
  O[[paste0("e", w[1])]] <- tibble(country = "ETH", year = as.numeric(w[1]), hhid = idstr(d[[w[3]]]), off_home = num(d$food_cons_ann),
    off_away = if ("fafh_cons_ann" %in% names(d)) num(d$fafh_cons_ann) else NA_real_, off_note = if (w[1] == "2015") "food_cons_ann; no away-from-home variable" else "food_cons_ann; fafh_cons_ann") }
## Tanzania
for (w in list(c("2008", "TZY1.HH.Consumption", "hhid", "TZA_2008"), c("2010", "TZY2.HH.Consumption", "y2_hhid", "TZA_2010"),
               c("2012", "ConsumptionNPS3", "y3_hhid", "TZA_2012"), c("2014", "consumptionNPS4", "y4_hhid", "TZA_2014"),
               c("2020", "consumption_real_y5", "y5_hhid", "TZA_2020"))) {
  d <- read_dta(f1(paste0("^", gsub("\\.", "\\\\.", w[2]), "\\.dta$"), w[4]))
  O[[paste0("t", w[1])]] <- tibble(country = "TZA", year = as.numeric(w[1]), hhid = idstr(d[[w[3]]]), off_home = num(d$foodIN), off_away = num(d$foodOUT),
    off_note = "foodIN; foodOUT (food, beverages, alcohol and tobacco outside the home)") }
## Malawi
for (w in list(c("2010", "ihs3fc2M_consumption", "MWI_2010_IHS-III.*Full_Sample"), c("2016", "ihs4 consumption aggregate", "MWI_2016"),
               c("2019", "ihs5_consumption_aggregate", "MWI_2019"), c("2024", "ihs6_consumptionaggregates", "MWI_2024-2025"))) {
  f <- tryCatch(f1(w[2], w[3]), error = function(e) NA); if (is.na(f)) { cat("MWI", w[1], "aggregate not found\n"); next }
  d <- read_dta(f); nom <- all(c("exp_cat011", "exp_cat111") %in% names(d)); p <- if (nom) "exp_cat" else "rexp_cat"
  O[[paste0("m", w[1])]] <- tibble(country = "MWI", year = as.numeric(w[1]), hhid = idstr(d$case_id), off_home = rs(d, paste0(p, c("011", "012", "021"))),
    off_away = rs(d, paste0(p, "111")), off_note = paste0(p, "011+012+021; ", p, "111", if (nom) " (nominal)" else " (REAL: spatially and temporally deflated)")) }
## Nigeria
for (w in c("2010", "2012", "2015")) {
  d <- read_dta(f1(paste0("cons_agg_wave", c("2010" = 1, "2012" = 2, "2015" = 3)[w], "_visit2\\.dta$"), paste0("NGA_", w)))
  fd <- grep("^fd.*(by|pr)$", names(d), value = TRUE); fd <- setdiff(fd, "fdrestby")
  O[[paste0("n", w)]] <- tibble(country = "NGA", year = as.numeric(w), hhid = idstr(d$hhid), off_home = rs(d, fd), off_away = num(d$fdrestby),
    off_note = "cons_agg visit 2: fd*by + fd*pr; fdrestby") }
for (w in c("2018", "2023")) {
  d <- read_dta(f1("^totcons_final\\.dta$", paste0("NGA_", w)))
  O[[paste0("n", w)]] <- tibble(country = "NGA", year = as.numeric(w), hhid = idstr(d$hhid), off_home = rs(d, c(paste0("food_own", 1:19), paste0("food_purch", 1:19))),
    off_away = num(d$food_meals20), off_note = "totcons_final: food_own1-19 + food_purch1-19; food_meals20") }
X <- bind_rows(O)
write.csv(X, args[2], row.names = FALSE, na = "")
print(X %>% group_by(country, year) %>% summarise(n = n(), home_med = median(off_home, na.rm = TRUE), away_med = median(off_away, na.rm = TRUE), .groups = "drop"), n = 30)
