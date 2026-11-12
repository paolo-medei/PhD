## Secondary columns read by v20: livestock, panel links, market prices,
## conversion tables. Same idea as varmap.R: what the code assumes vs what the
## survey says.
suppressPackageStartupMessages({ library(haven); library(dplyr); library(purrr); library(tibble) })
ROOT <- Sys.getenv("ASF_UNZIPPED", "data/_unzipped")   # folder with one subfolder per extracted survey
ff <- function(hint, stem) { d <- list.files(ROOT, pattern = hint, full.names = TRUE)
  f <- list.files(d, pattern = paste0("^", stem, "[.]dta$"), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (length(f)) f[1] else NA_character_ }
vl <- function(x, max = 14) { lv <- attr(x, "labels"); if (is.null(lv)) return("")
  s <- paste0(lv, "=", names(lv)); paste(c(head(s, max), if (length(s) > max) "..."), collapse = "; ") }
look <- function(country, wave, hint, stem, vars, roles) {
  f <- ff(hint, stem)
  if (is.na(f)) return(tibble(country, wave, file = stem, variable = vars, role = roles, exists = FALSE, label = "FILE NOT FOUND", value_labels = ""))
  d <- read_dta(f, n_max = 0)
  map2_dfr(vars, roles, function(v, r) { ok <- v %in% names(d)
    tibble(country, wave, file = stem, variable = v, role = r, exists = ok,
           label = if (ok) { l <- attr(d[[v]], "label"); if (is.null(l)) "" else l } else "",
           value_labels = if (ok) vl(d[[v]]) else "") })
}
R <- list()
## livestock (Heckman exclusion restriction)
R[[1]] <- look("ETH","w1","ETH_2011","sect8a_ls_w1", c("household_id","ls_s8aq00","ls_s8aq02a"), c("hh id","animal code (1-6 cattle, 7-9 small rum., 10-12 poultry)","count (one of the age-class totals summed)"))
R[[2]] <- look("ETH","w2","ETH_2013","sect8a_ls_w2", c("household_id2","ls_s8aq00","ls_s8aq02a"), c("hh id","animal code","count"))
for (w in c("w3","w4","w5")) { yr <- c(w3="2015",w4="2018",w5="2021")[[w]]
  R[[length(R)+1]] <- look("ETH", w, paste0("ETH_",yr), paste0("sect8_1_ls_",w), c(if (w=="w3") "household_id2" else "household_id","ls_code","ls_s8_1q01"), c("hh id","animal code","number kept")) }
for (w in c("2008","2010","2012","2014","2020")) R[[length(R)+1]] <- look("TZA", w, paste0("TZA_",w), "LF_SEC_02",
  c(c("2008"="hhid","2010"="y2_hhid","2012"="y3_hhid","2014"="y4_hhid","2020"="y5_hhid")[[w]],"lvstckid","lf02_02"), c("hh id","animal code (1-6 cattle, 7-9 small rum., 10-12 poultry)","number owned"))
## panel links (household fixed effects)
R[[length(R)+1]] <- look("ETH","w2","ETH_2013","cons_agg_w2", c("household_id","household_id2"), c("panel link = WAVE-1 id","own wave id"))
R[[length(R)+1]] <- look("ETH","w3","ETH_2015","cons_agg_w3", c("household_id","household_id2"), c("panel link = WAVE-1 id","own wave id"))
R[[length(R)+1]] <- look("TZA","2010","TZA_2010","TZY2.HH.Consumption", c("y2_hhid","hhid_2008"), c("own wave id","link to 2008"))
R[[length(R)+1]] <- look("TZA","2012","TZA_2012","HH_SEC_B", c("y3_hhid","y2_hhid"), c("own wave id","link to 2010"))
R[[length(R)+1]] <- look("TZA","2020","TZA_2020","hh_sec_b", c("y5_hhid","y4_hhid"), c("own wave id","link to 2014"))
## Ethiopian community market prices (used as exogenous price)
R[[length(R)+1]] <- look("ETH","w1","ETH_2011","sect10b1_com_w1", c("cs10b1q07_b","cs10b1q07_d","cs10b1q07_f1","ea_id"), c("price item","price unit","price value","EA"))
for (w in c("w2","w3")) R[[length(R)+1]] <- look("ETH", w, c(w2="ETH_2013",w3="ETH_2015")[[w]], paste0("sect10a2_com_",w), c("cs10a2q02","cs10a2q03_a","cs10a2q05","ea_id"), c("price item","price unit","price value","EA"))
for (w in c("w4","w5")) R[[length(R)+1]] <- look("ETH", w, c(w4="ETH_2018",w5="ETH_2021")[[w]], paste0("sect10b_com_",w), c("cs10bq02","cs10bq03","cs10bq05","ea_id"), c("price item","price unit","price value","EA"))
out <- bind_rows(R)
write.csv(out, "docs/variable_map_v20_secondary.csv", row.names = FALSE)
out$label <- substr(out$label, 1, 70); out$value_labels <- substr(out$value_labels, 1, 95)
options(width = 260); print(as.data.frame(out[, c("country","wave","file","variable","role","exists","label","value_labels")]), right = FALSE, row.names = FALSE)
