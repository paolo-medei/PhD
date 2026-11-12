## Variable map: every column the v20 build reads, with the label the survey
## itself gives it. Purpose: check that each column means what the code
## assumes it means. Reads metadata only.
suppressPackageStartupMessages({ library(haven); library(dplyr); library(purrr); library(tibble) })
ROOT <- Sys.getenv("ASF_UNZIPPED", "data/_unzipped")   # folder with one subfolder per extracted survey

find_file <- function(dir_hint, stem) {
  d <- list.files(ROOT, pattern = dir_hint, full.names = TRUE)
  f <- list.files(d, pattern = paste0("^", stem, "\\.dta$"), recursive = TRUE,
                  full.names = TRUE, ignore.case = TRUE)
  if (length(f)) f[1] else NA_character_
}
vl_text <- function(x, max = 12) {
  lv <- attr(x, "labels"); if (is.null(lv)) return("")
  s <- paste0(lv, "=", names(lv))
  paste(c(head(s, max), if (length(s) > max) "...") , collapse = "; ")
}
look <- function(country, wave, year, dir_hint, stem, vars, roles) {
  f <- find_file(dir_hint, stem)
  if (is.na(f)) return(tibble(country, wave, year, file = stem, variable = vars,
                              role = roles, exists = FALSE, label = "FILE NOT FOUND",
                              value_labels = ""))
  d <- tryCatch(read_dta(f, n_max = 0), error = function(e) NULL)
  map2_dfr(vars, roles, function(v, r) {
    ok <- !is.null(d) && v %in% names(d)
    tibble(country, wave, year, file = stem, variable = v, role = r, exists = ok,
           label = if (ok) { l <- attr(d[[v]], "label"); if (is.null(l)) "" else l } else "",
           value_labels = if (ok) vl_text(d[[v]]) else "")
  })
}

rows <- list()
## ---------------- ETHIOPIA ----------------
ET <- list(
  w1 = list(2011,"ETH_2011","sect5a_hh_w1","hh_s5aq","_","hh_s5aq00","Food_CF_Wave1","pw","household_id","b","cons_agg_w1","sect1_hh_w1","hh_s1q04_a","hh_s1q03","hh_s1q02","sect_cover_hh_w1"),
  w2 = list(2013,"ETH_2013","sect5a_hh_w2","hh_s5aq","_","hh_s5aq00","Food_CF_Wave2","pw2","household_id2","cf_unit","cons_agg_w2","sect1_hh_w2","hh_s1q04_a","hh_s1q03","hh_s1q02","sect_cover_hh_w2"),
  w3 = list(2015,"ETH_2015","sect5a_hh_w3","hh_s5aq","_","item_cd","Food_CF_Wave3","pw_w3","household_id2","b","cons_agg_w3","sect1_hh_w3","hh_s1q04a","hh_s1q03","hh_s1q02","sect_cover_hh_w3"),
  w4 = list(2018,"ETH_2018","sect6a_hh_w4","s6aq","","item_cd","Food_CF_Wave4","pw_w4","household_id","b","cons_agg_w4","sect1_hh_w4","s1q03a","s1q02","s1q01","sect_cover_hh_w4"),
  w5 = list(2021,"ETH_2021","sect6a_hh_w5","s6aq","","item_cd","food_cf_wave5","pw_w5","household_id","b","cons_agg_w5","sect1_hh_w5","s1q03a","s1q02","s1q01","sect_cover_hh_w5"))
for (w in names(ET)) { C <- ET[[w]]; p <- C[[4]]; s <- C[[5]]; uk <- C[[10]]
  rows[[length(rows)+1]] <- look("ETH", w, C[[1]], C[[2]], C[[3]],
    c(C[[6]], C[[9]], paste0(p,"01"),
      paste0(p,"02",s,"a"), paste0(p,"02",s,uk), paste0(p,"03",s,"a"), paste0(p,"03",s,uk),
      paste0(p,"04"), paste0(p,"05",s,"a"), paste0(p,"05",s,uk), paste0(p,"06",s,"a"), paste0(p,"06",s,uk)),
    c("item code","household id","consumed? (yes=1)",
      "TOTAL quantity","TOTAL unit","PURCHASED quantity","PURCHASED unit",
      "SPENDING on purchase","OWN-PRODUCED quantity","OWN-PRODUCED unit","GIFT quantity","GIFT unit"))
  rows[[length(rows)+1]] <- look("ETH", w, C[[1]], C[[2]], C[[7]],
    c("item_cd","unit_cd","mean_cf_nat"), c("conv: item","conv: unit","conv: kg per unit (national mean)"))
  rows[[length(rows)+1]] <- look("ETH", w, C[[1]], C[[2]], C[[11]],
    c("adulteq","hh_size","nom_totcons_aeq","ea_id",C[[8]]),
    c("adult equivalents","household size","WELFARE used","cluster (EA)","sampling weight"))
  rows[[length(rows)+1]] <- look("ETH", w, C[[1]], C[[2]], C[[12]],
    c(C[[13]],C[[14]],C[[15]]), c("age","sex (female=2)","relationship (head=1)"))
  rows[[length(rows)+1]] <- look("ETH", w, C[[1]], C[[2]], C[[16]],
    c("saq01","saq14","rural"), c("region","urban/rural","urban/rural"))
}
## ---------------- TANZANIA ----------------
TZ <- list(
  w1 = list(2008,"TZA_2008","SEC_K1","old","hhid","skcode","TZY1.HH.Consumption","expmR","SEC_B_C_D_E1_F_G1_U","sbq4","sbq2","sbq5"),
  w2 = list(2010,"TZA_2010","HH_SEC_K1","hh_k","y2_hhid","itemcode","TZY2.HH.Consumption","expmR","HH_SEC_B","hh_b04","hh_b02","hh_b05"),
  w3 = list(2012,"TZA_2012","HH_SEC_J1","hh_j","y3_hhid","itemcode","ConsumptionNPS3","expmR","HH_SEC_B","hh_b04","hh_b02","hh_b05"),
  w4 = list(2014,"TZA_2014","hh_sec_j1","hh_j","y4_hhid","itemcode","consumptionNPS4","expmR","hh_sec_b","hh_b04","hh_b02","hh_b05"),
  w5 = list(2020,"TZA_2020","hh_sec_ja1","hh_ja","y5_hhid","itemcode","consumption_real_y5","expmR_pae","hh_sec_b","hh_b04","hh_b02","hh_b05"))
for (w in names(TZ)) { C <- TZ[[w]]
  v <- if (C[[4]] == "old") c("skq1","skq2_amount","skq2_meas","skq3_amount","skq3_meas","skq4","skq5_amount","skq5_meas","skq6_amount","skq6_meas") else {
    p <- C[[4]]; c(if (w == "w2") "hh_k01_2" else paste0(p,"01"), paste0(p,"02_2"), paste0(p,"02_1"),
      paste0(p,"03_2"), paste0(p,"03_1"), paste0(p,"04"), paste0(p,"05_2"), paste0(p,"05_1"),
      paste0(p,"06_2"), paste0(p,"06_1")) }
  rows[[length(rows)+1]] <- look("TZA", w, C[[1]], C[[2]], C[[3]], c(C[[6]], C[[5]], v),
    c("item code","household id","consumed? (yes=1)","TOTAL quantity","TOTAL unit",
      "PURCHASED quantity","PURCHASED unit","SPENDING on purchase","OWN-PRODUCED quantity",
      "OWN-PRODUCED unit","GIFT quantity","GIFT unit"))
  rows[[length(rows)+1]] <- look("TZA", w, C[[1]], C[[2]], C[[7]],
    c("adulteq","hhsize","hhweight","urban","region",C[[8]]),
    c("adult equivalents","household size","sampling weight","urban","region","WELFARE used"))
  rows[[length(rows)+1]] <- look("TZA", w, C[[1]], C[[2]], C[[9]],
    c(C[[10]],C[[11]],C[[12]]), c("age","sex (female=2)","relationship (head=1)"))
}
## ---------------- NIGERIA ----------------
NG <- list(
  w1 = list(2010,"NGA_2010","sect10b_harvestw1","cons_agg_wave1_visit2","totcons","hhweight","5","6",FALSE),
  w2 = list(2012,"NGA_2012","sect10b_harvestw2","cons_agg_wave2_visit2","totcons","hhweight","6","7",FALSE),
  w3 = list(2015,"NGA_2015","sect10b_harvestw3","cons_agg_wave3_visit2","totcons","hhweight","6","7",FALSE),
  w4 = list(2018,"NGA_2018","sect10b_harvestw4","totcons_final","totcons_pc","wt_wave4","6","7",TRUE))
for (w in names(NG)) { C <- NG[[w]]; p <- "s10bq"
  v <- c("hhid","item_cd",paste0(p,"1"),paste0(p,"2a"),paste0(p,"2b"))
  r <- c("household id","item code","consumed? (yes=1)","TOTAL quantity","TOTAL unit")
  if (C[[9]]) { v <- c(v, paste0(p,"2_cvn"), paste0(p,C[[7]],"a"), paste0(p,C[[8]],"a"), paste0(p,"9a"), paste0(p,"9_cvn"), paste0(p,"10"))
                r <- c(r, "kg conversion factor (total)", "OWN-PRODUCED quantity","GIFT quantity","PURCHASED quantity","kg conversion factor (purchase)","SPENDING")
  } else { v <- c(v, paste0(p,"3a"), paste0(p,"3b"), paste0(p,"4"), paste0(p,C[[7]],"a"), paste0(p,C[[7]],"b"), paste0(p,C[[8]],"a"), paste0(p,C[[8]],"b"))
           r <- c(r, "PURCHASED quantity","PURCHASED unit","SPENDING","OWN-PRODUCED quantity","OWN-PRODUCED unit","GIFT quantity","GIFT unit") }
  rows[[length(rows)+1]] <- look("NGA", w, C[[1]], C[[2]], C[[3]], v, r)
  rows[[length(rows)+1]] <- look("NGA", w, C[[1]], C[[2]], C[[4]], c("hhid","hhsize",C[[5]],C[[6]]),
    c("household id","household size","WELFARE used","sampling weight"))
}
out <- bind_rows(rows)
write.csv(out, "docs/variable_map_v20.csv", row.names = FALSE)
cat(nrow(out), "rows;", sum(!out$exists), "missing\n")
