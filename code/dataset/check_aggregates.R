# Independent check: re-reads each official consumption aggregate file and compares welfare, total and food consumption with the delivered dataset.
# usage: Rscript check_aggregates.R <data/_unzipped> <_wide_check_<date>.csv.gz>   (24 Nov 2026: all values equal)
suppressMessages({library(haven); library(dplyr)})
a <- commandArgs(TRUE); root <- a[1]; W <- read.csv(gzfile(a[2]), colClasses = c(hhid = "character"))
fnd <- function(hint, base) { f <- list.files(root, pattern = "\\.dta$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  f <- f[grepl(hint, f) & tolower(tools::file_path_sans_ext(basename(f))) == tolower(base)]; stopifnot(length(f) >= 1); f[1] }
id <- function(x) { x <- zap_labels(x); if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x)) }
n <- function(d, v) as.numeric(zap_labels(d[[v]]))
C <- list(
  list("ETH", 2015, "ETH_2015", "cons_agg_w3", "household_id2", function(d) list(w = n(d, "nom_totcons_aeq"), t = n(d, "total_cons_ann"), f = n(d, "food_cons_ann"))),
  list("ETH", 2018, "ETH_2018", "cons_agg_w4", "household_id", function(d) list(w = n(d, "nom_totcons_aeq"), t = n(d, "total_cons_ann"), f = n(d, "food_cons_ann"))),
  list("ETH", 2021, "ETH_2021", "cons_agg_w5", "household_id", function(d) list(w = n(d, "nom_totcons_aeq"), t = n(d, "total_cons_ann"), f = n(d, "food_cons_ann"))),
  list("TZA", 2008, "TZA_2008", "TZY1.HH.Consumption", "hhid", function(d) list(w = n(d, "expmR") / n(d, "adulteq"), t = n(d, "expm"), f = n(d, "foodIN") + n(d, "foodOUT"))),
  list("TZA", 2010, "TZA_2010", "TZY2.HH.Consumption", "y2_hhid", function(d) list(w = n(d, "expmR") / n(d, "adulteq"), t = n(d, "expm"), f = n(d, "foodIN") + n(d, "foodOUT"))),
  list("TZA", 2012, "TZA_2012", "ConsumptionNPS3", "y3_hhid", function(d) list(w = n(d, "expmR") / n(d, "adulteq"), t = n(d, "expm"), f = n(d, "foodIN") + n(d, "foodOUT"))),
  list("TZA", 2014, "TZA_2014", "consumptionNPS4", "y4_hhid", function(d) list(w = n(d, "expmR") / n(d, "adulteq"), t = n(d, "expm"), f = n(d, "foodIN") + n(d, "foodOUT"))),
  list("TZA", 2020, "TZA_2020", "consumption_real_y5", "y5_hhid", function(d) list(w = n(d, "expmR_pae") * 365 / 28, t = n(d, "expm"), f = n(d, "foodIN") + n(d, "foodOUT"))),
  list("MWI", 2010, "MWI_2010_IHS-III.*Full_Sample", "ihs3fc2M_consumption", "case_id", function(d) list(w = NA, t = n(d, "rexpagg"), f = n(d, "rexp_cat011"), hhtot = n(d, "rexpagg"))),
  list("MWI", 2016, "MWI_2016", "ihs4 consumption aggregate", "case_id", function(d) list(w = n(d, "rexpaggpc"), t = n(d, "rexpagg"), f = n(d, "rexp_cat011"))),
  list("MWI", 2019, "MWI_2019", "ihs5_consumption_aggregate", "case_id", function(d) list(w = n(d, "rexpaggpc"), t = n(d, "rexpagg"), f = n(d, "rexp_cat011"))),
  list("MWI", 2024, "MWI_2024", "ihs6_consumptionaggregates", "case_id", function(d) list(w = n(d, "rexpaggpc"), t = n(d, "rexpagg"), f = n(d, "rexp_cat011"))),
  list("NGA", 2010, "NGA_2010", "cons_agg_wave1_visit2", "hhid", function(d) list(w = n(d, "totcons"), t = NA, f = NA)),
  list("NGA", 2012, "NGA_2012", "cons_agg_wave2_visit2", "hhid", function(d) list(w = n(d, "totcons"), t = NA, f = NA)),
  list("NGA", 2015, "NGA_2015", "cons_agg_wave3_visit2", "hhid", function(d) list(w = n(d, "totcons"), t = NA, f = NA)),
  list("NGA", 2018, "NGA_2018", "totcons_final", "hhid", function(d) list(w = n(d, "totcons_pc"), t = NA, f = NA)),
  list("NGA", 2023, "NGA_2023", "totcons_final", "hhid", function(d) list(w = n(d, "totcons_adj"), t = NA, f = NA)),
  list("UGA", 2010, "UGA_2010", "pov2010_11", "hh", function(d) list(w = n(d, "welfare") * 12, t = NA, f = NA)),
  list("UGA", 2011, "UGA_2011", "UNPS 2011-12 Consumption Aggregate", "HHID", function(d) list(w = n(d, "welfare") * 12, t = NA, f = NA)),
  list("UGA", 2013, "UGA_2013", "pov2013_14", "hhid", function(d) list(w = n(d, "welfare") * 12, t = n(d, "nrrexp30") * 12, f = NA)),
  list("UGA", 2015, "UGA_2015", "pov2015_16", "hh", function(d) list(w = n(d, "welfare") * 12, t = n(d, "nrrexp30") * 12, f = NA)),
  list("UGA", 2018, "UGA_2018", "pov2018_19", "hhid", function(d) list(w = n(d, "welfare") * 12, t = n(d, "nrrexp30") * 12, f = NA)),
  list("UGA", 2019, "UGA_2019", "pov2019_20", "hhid", function(d) list(w = n(d, "welfare") * 12, t = n(d, "nrrexp30") * 12, f = NA)))
same <- function(x, y) { both <- !is.na(x) & !is.na(y); c(compared = sum(both), equal = sum(both & abs(x - y) <= pmax(0.01, 1e-7 * abs(x))),
                                                        only_file = sum(!is.na(x) & is.na(y)), only_data = sum(is.na(x) & !is.na(y))) }
out <- list()
for (r in C) {
  d <- read_dta(fnd(r[[3]], r[[4]])); v <- r[[6]](d)
  e <- tibble(hhid = id(d[[r[[5]]]]), w = if (length(v$w) > 1) v$w else NA_real_, t = if (length(v$t) > 1) v$t else NA_real_, f = if (length(v$f) > 1) v$f else NA_real_,
              hhtot = if (!is.null(v$hhtot)) v$hhtot else NA_real_) %>% distinct(hhid, .keep_all = TRUE)
  x <- W %>% filter(country == r[[1]], year == r[[2]]) %>% select(hhid, welfare_annual, cons_total_hh_annual, food_cons_hh_annual, hhsize) %>% left_join(e, by = "hhid")
  if (r[[1]] == "MWI" && r[[2]] == 2010) x$w <- x$hhtot / x$hhsize
  s <- rbind(welfare = same(x$w, x$welfare_annual), total = same(x$t, x$cons_total_hh_annual), food = same(x$f, x$food_cons_hh_annual))
  out[[length(out) + 1]] <- data.frame(country = r[[1]], year = r[[2]], households = nrow(x), in_file = sum(x$hhid %in% e$hhid), var = rownames(s), s, row.names = NULL)
}
o <- bind_rows(out); print(o, row.names = FALSE)
