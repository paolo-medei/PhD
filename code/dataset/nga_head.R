# Nigeria GHS-Panel: sex and age of the household head from the post-harvest roster (relationship to head = 1).
# When a household lists more than one head, the one still living in the household is kept.
# args: <data/_unzipped> <output csv>
suppressMessages({library(haven); library(dplyr)})
a <- commandArgs(TRUE); root <- a[1]
W <- list(
  list(y = 2010, f = "NGA_2010_GHSP-W1_v03_M_STATA/Post Harvest Wave 1/Household/sect1_harvestw1.dta", age = "s1q4", still = "s1q19"),
  list(y = 2012, f = "NGA_2012_GHSP-W2_v02_M_STATA/Post Harvest Wave 2/Household/sect1_harvestw2.dta", age = "s1q4", still = "s1q14"),
  list(y = 2015, f = "NGA_2015_GHSP-W3_v02_M_Stata/sect1_harvestw3.dta", age = "s1q4", still = "s1q4a"),
  list(y = 2018, f = "NGA_2018_GHSP-W4_v04_M_Stata/sect1_harvestw4.dta", age = "s1q4", still = "s1q4a"),
  list(y = 2023, f = "NGA_2023_GHSP-W5_v03_M_Stata/sect1_harvestw5.dta", age = "s1q6", still = "s1q4"))
out <- bind_rows(lapply(W, function(w) {
  d <- read_dta(file.path(root, w$f))
  cat(w$y, ": sex", paste(names(attr(d$s1q2, "labels")), attr(d$s1q2, "labels"), collapse = "; "),
      "| rel 1 =", names(attr(d$s1q3, "labels"))[attr(d$s1q3, "labels") == 1],
      "| still", if (w$still %in% names(d)) paste(names(attr(d[[w$still]], "labels")), attr(d[[w$still]], "labels"), collapse = "; ") else "none", "\n")
  st <- if (w$still %in% names(d)) as.numeric(d[[w$still]]) else NA
  x <- tibble(hhid = sprintf("%.0f", as.numeric(d$hhid)), rel = as.numeric(d$s1q3), sex = as.numeric(d$s1q2), age = as.numeric(d[[w$age]]), still = st) %>%
    filter(rel == 1) %>% mutate(gone = !is.na(still) & still == 2) %>% arrange(hhid, gone)
  n_multi <- sum(table(x$hhid) > 1)
  x <- x %>% group_by(hhid) %>% slice(1) %>% ungroup()
  cat("   heads", nrow(x), "households with more than one head", n_multi, "\n")
  transmute(x, country = "NGA", year = w$y, hhid, head_female = ifelse(sex == 2, 1, ifelse(sex == 1, 0, NA)), head_age = age,
            head_source = paste0(basename(w$f), ": s1q2, s1q3 == 1, ", w$age))
}))
write.csv(out, a[2], row.names = FALSE)
print(out %>% group_by(year) %>% summarise(n = n(), female = mean(head_female, na.rm = TRUE), age = median(head_age, na.rm = TRUE), na_sex = sum(is.na(head_female))))
