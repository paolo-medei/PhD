# USO  Rscript nga_quota_bambini.R <_unzipped> <nga_roster.csv>
# Nigeria: share of household members under 15, from the post-harvest roster (the visit of the consumption module)
suppressMessages({ library(haven); library(dplyr) })
R <- commandArgs(TRUE)[1]; OUT <- commandArgs(TRUE)[2]
F <- list(`2010` = c("NGA_2010_GHSP-W1_v03_M_STATA/Post Harvest Wave 1/Household/sect1_harvestw1.dta", "s1q4", "s1q19"),
          `2012` = c("NGA_2012_GHSP-W2_v02_M_STATA/Post Harvest Wave 2/Household/sect1_harvestw2.dta", "s1q4", "s1q14"),
          `2015` = c("NGA_2015_GHSP-W3_v02_M_Stata/sect1_harvestw3.dta", "s1q4", "s1q4a"),
          `2018` = c("NGA_2018_GHSP-W4_v04_M_Stata/sect1_harvestw4.dta", "s1q4", "s1q4a"),
          `2023` = c("NGA_2023_GHSP-W5_v03_M_Stata/sect1_harvestw5.dta", "s1q6", "s1q4"))
out <- NULL
for (y in names(F)) {
  d <- read_dta(file.path(R, F[[y]][1]))
  lab <- sapply(d, function(x) { l <- attr(x, "label"); if (is.null(l)) "" else l })
  st <- F[[y]][3]
  if (st == "?") { k <- grep("STILL|LIVE IN THIS H", lab, ignore.case = TRUE); cat(y, "candidates:", paste(names(d)[k], lab[k], sep = "=", collapse = " | "), "\n"); st <- names(d)[k][1] }
  age <- as.numeric(zap_labels(d[[F[[y]][2]]])); still <- as.numeric(zap_labels(d[[st]]))
  m <- data.frame(hhid = sprintf("%.0f", as.numeric(zap_labels(d$hhid))), age = age, still = still) %>% filter(is.na(still) | still != 2)
  h <- m %>% group_by(hhid) %>% summarise(n_roster = n(), n_age = sum(!is.na(age)), n_child = sum(age < 15, na.rm = TRUE), .groups = "drop") %>%
    mutate(round = as.integer(y), share_child = ifelse(n_age > 0, n_child / n_age, NA))
  cat(y, ": still var", st, "| households", nrow(h), "| members", nrow(m), "| age missing", sum(is.na(m$age)), "\n")
  out <- bind_rows(out, h)
}
write.csv(out, OUT, row.names = FALSE)
