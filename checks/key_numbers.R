## The numbers that appear in the slides, pulled from one RESULTS_*.xlsx.
## Usage: Rscript checks/key_numbers.R RESULTS.xlsx [label]
## Prints one row per number; run it on two workbooks to see what a change moved.
suppressPackageStartupMessages({ library(openxlsx); library(dplyr) })
a <- commandArgs(TRUE); f <- a[1]; lab <- if (length(a) > 1) a[2] else basename(f)
sh <- getSheetNames(f); r <- function(s) if (s %in% sh) read.xlsx(f, s) else NULL
out <- list(); add <- function(k, v) out[[length(out) + 1]] <<- data.frame(number = k, value = round(v, 3))
for (c in c("ETH", "TZA", "NGA")) {
  q <- r(paste0(c, "_14_participation_quintile"))
  if (!is.null(q)) { m <- q[q$product == "meat_agg", ]
    add(paste(c, "meat buyers % Q1"), m$Q1); add(paste(c, "meat buyers % Q5"), m$Q5) }
  g <- r(paste0(c, "_22_four_margins"))
  if (!is.null(g)) add(paste(c, "beef participation slope (slide 8)"), g$e_participation[g$product == "beef"])
  d <- r(paste0(c, "_01_decomposition"))
  if (!is.null(d)) { m <- d[d$product == "meat_agg", ]
    add(paste(c, "meat waves with quality p<0.05"), sum(m$p_quality < 0.05, na.rm = TRUE))
    add(paste(c, "meat waves estimated"), nrow(m)) }
  b <- r(paste0(c, "_20_basket_by_quintile"))
  if (!is.null(b)) { b <- b[b$product != "fish" & b$qt %in% c(1, 5), ]
    b <- b %>% group_by(qt) %>% mutate(s = 100 * share_of_asf_spend / sum(share_of_asf_spend, na.rm = TRUE)) %>% ungroup()
    sel <- if (c == "ETH") list(dairy = c("milk", "cheese"), goat_sheep = "goat_sheep") else
           if (c == "NGA") list(beef = "beef", poultry = "poultry") else list(beef = "beef", poultry = "poultry")
    for (k in names(sel)) for (qq in c(1, 5))
      add(sprintf("%s basket %s %% Q%d (no fish)", c, k, qq), sum(b$s[b$qt == qq & b$product %in% sel[[k]]])) }
}
cs <- r("COMPARE_01_summary")
if (!is.null(cs)) for (i in which(cs$product == "meat_agg")) add(paste(cs$country[i], "meat quality share"), cs$quality_share[i])
vc <- r("VC_01_multiplier")
if (!is.null(vc)) for (i in seq_len(nrow(vc))) add(paste(vc$country[i], "variety elasticity"), vc$Variety[i])
res <- do.call(rbind, out); names(res)[2] <- lab
print(res, row.names = FALSE, right = FALSE)
write.csv(res, sub("[.]xlsx$", "_key_numbers.csv", f), row.names = FALSE)
