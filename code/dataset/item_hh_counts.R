## Households reporting each food item, and its 7-day purchase value, per round (input of food_categories_map.py).
## Run from the build directory that holds item_inventory.csv and out4/role_vars.csv.
suppressPackageStartupMessages({library(haven); library(dplyr)})
ROOT <- "/home/claude/work/single/data/_unzipped"
inv <- read.csv("item_inventory.csv", stringsAsFactors = FALSE)
rv <- read.csv("out4/role_vars.csv", stringsAsFactors = FALSE) %>% filter(exists %in% c(TRUE, "TRUE"))
fl <- inv %>% distinct(country, year, file, itemvar)
out <- list()
for (i in seq_len(nrow(fl))) {
  f <- fl[i, ]; bn <- basename(f$file); yr <- floor(f$year)
  r <- rv %>% filter(country == f$country, year == yr, tolower(file) == tolower(bn))
  v <- function(role) { x <- r$variable[r$role == role]; if (length(x)) x[1] else NA }
  vars <- c(f$itemvar, v("cons_raw"), v("q_tot"), v("exp_pur"))
  d <- read_dta(file.path(ROOT, f$file), col_select = any_of(na.omit(vars)))
  num <- function(n) if (!is.na(n) && n %in% names(d)) suppressWarnings(as.numeric(zap_labels(d[[n]]))) else rep(NA_real_, nrow(d))
  code <- num(vars[1]); cons <- num(vars[2]); q <- num(vars[3]); e <- num(vars[4])
  yes <- (cons %in% 1) | (!is.na(q) & q > 0) | (!is.na(e) & e > 0)
  out[[i]] <- data.frame(code = code, yes = yes, e = ifelse(is.na(e), 0, e)) %>% group_by(code) %>%
    summarise(hh_consuming = sum(yes), purchase_value_sum = sum(e), .groups = "drop") %>%
    mutate(country = f$country, year = f$year, cons_var = vars[2], q_var = vars[3], exp_var = vars[4])
  cat(f$country, f$year, bn, paste(vars, collapse = " "), nrow(d), "\n")
}
write.csv(bind_rows(out), "allfood/item_hh_counts.csv", row.names = FALSE)
