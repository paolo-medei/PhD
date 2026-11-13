###############################################################################
## PART 4 — CROSS-COUNTRY COMPARISON
###############################################################################
RES_DIR <- RUN_DIR
read_set <- function(suffix) {
  fs <- list.files(TMPCSV, pattern=paste0("_", suffix, "\\.csv$"), full.names=TRUE)
  if (!length(fs)) return(tibble())
  map_dfr(fs, function(f) {
    d <- read.csv(f, stringsAsFactors=FALSE)
    d$country <- str_match(basename(f), "^([A-Z]{3})_")[,2]
    d
  })
}
dec <- read_set("01_decomposition")
pri <- read_set("02_price_elasticities")
if (!nrow(dec)) stop("nothing to compare")

## GDP per capita, current USD, World Bank — used ONLY to order the countries
## on the income axis. Update as more countries are added.
## v21 (M8): GDP per capita, PPP, constant 2021 international $ (WDI
## NY.GDP.PCAP.PP.KD, file docs/external/wdi_gdp_pc_ppp.csv), MEAN OVER EACH
## COUNTRY'S SURVEY YEARS. v20 had recent single-year values in current USD
## (1,020 / 1,220 / 1,600), which put Nigeria barely above Ethiopia.
##   ETH 2011-2021: 1,493 -> 2,588   TZA 2008-2020: 2,493 -> 3,450
##   NGA 2010-2015: 7,963 -> 8,892
## v22: UGA 2010-2019 (survey years 2010, 2011, 2013, 2015, 2018, 2019):
##   2,245 -> 2,689, mean 2,479. Same WDI series, read through Our World in
##   Data's copy (its Tanzania values equal the WDI extract to the dollar).
##   MWI 2010-2024 (survey years 2010, 2016, 2019, 2024): 1,504 -> 1,634, mean 1,605.
INCOME <- tribble(~country, ~gdp_pc,
                  "MWI",  1605,
                  "ETH",  2009,
                  "UGA",  2479,
                  "TZA",  2890,
                  "NGA",  8374)

CORE  <- c("meat_agg","milk","eggs","coffee")
LABEL <- c(meat_agg="Meat", milk="Fresh milk",
           milk_processed="Milk (powder/tinned)", eggs="Eggs",
           coffee="Coffee", cheese="Cheese")
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), plot.subtitle=element_text(colour="grey35"),
        panel.grid.minor=element_blank(), strip.text=element_text(face="bold"))

###############################################################################
## 1. the headline comparison table
###############################################################################
summ <- dec %>% filter(product %in% CORE, !is.na(e_quantity)) %>%
  group_by(country, product) %>%
  summarise(waves         = n(),
            participation = round(mean(participation, na.rm=TRUE), 1),
            quantity      = round(mean(e_quantity,    na.rm=TRUE), 3),
            quality       = round(mean(e_quality,     na.rm=TRUE), 3),
            expenditure   = round(mean(e_expenditure, na.rm=TRUE), 3),
            quality_share = round(mean(quality_share, na.rm=TRUE), 3),
            .groups="drop") %>%
  left_join(INCOME, by="country") %>% arrange(product, gdp_pc)

write.csv(summ, file.path(TMPCSV, "COMPARE_01_summary.csv"), row.names=FALSE)
cat("\n=========== CROSS-COUNTRY SUMMARY ===========\n")
print(as.data.frame(summ))

###############################################################################
## 2. does the quality share rise with income?
###############################################################################
cat("\n=========== QUALITY SHARE vs INCOME ===========\n")
qs <- summ %>% filter(!is.na(gdp_pc))
if (n_distinct(qs$country) >= 3) {
  fit <- lm(quality_share ~ log(gdp_pc) + factor(product), data=qs)
  print(summary(fit)$coefficients)
  cat("\nNB: with fewer than ~5 countries this slope is descriptive, not a test.\n")
} else {
  cat("Only", n_distinct(qs$country), "countries so far — no gradient can be fitted.\n")
  print(as.data.frame(qs %>% select(country, gdp_pc, product, quality_share) %>%
                        pivot_wider(names_from=product, values_from=quality_share)))
}

###############################################################################
## 3. saturation: has any country reached the plateau?
###############################################################################
cat("\n=========== SATURATION ===========\n")
sat <- dec %>% group_by(country) %>%
  summarise(cells = n(), plateaus = sum(plateau, na.rm=TRUE),
            share = round(mean(plateau, na.rm=TRUE), 3), .groups="drop")
print(as.data.frame(sat))

###############################################################################
## 4. price elasticities: keep the WRONG-SIGNED ones visible
###############################################################################
if (nrow(pri)) {
  cat("\n=========== PRICE ELASTICITIES ===========\n")
  ps <- pri %>% mutate(sig = p < .05,
                       wrong_sign = e_price > 0 & p < .05) %>%
    group_by(country, product) %>%
    summarise(n_est = n(), median_e = round(median(e_price, na.rm=TRUE), 3),
              n_sig = sum(sig, na.rm=TRUE),
              n_wrong_sign = sum(wrong_sign, na.rm=TRUE), .groups="drop")
  print(as.data.frame(ps))
  write.csv(ps, file.path(TMPCSV, "COMPARE_02_price.csv"), row.names=FALSE)
  if (sum(ps$n_wrong_sign) > 0)
    cat("\n!! Positive, significant own-price elasticities remain. The leave-one-out\n",
        "   cluster price is not a clean instrument: in clusters where everyone buys\n",
        "   the expensive cut, price and quantity rise together. Report this.\n")
}

###############################################################################
## 5. figures
###############################################################################
FIG <- FIGDIAG
s <- summ %>% mutate(lab = LABEL[product],
                     ctry = paste0(country, "\n$", gdp_pc))

p1 <- s %>% select(ctry, lab, Quantity=quantity, Quality=quality) %>%
  pivot_longer(c(Quantity,Quality), names_to="component", values_to="e") %>%
  ggplot(aes(ctry, e, fill=component)) + geom_col() + facet_wrap(~lab, nrow=1) +
  scale_fill_manual(values=c(Quantity="#4E79A7", Quality="#59A14F")) +
  labs(title="Quantity dominates in both countries",
       subtitle="Expenditure elasticity split into its two margins, averaged over waves",
       x=NULL, y="Elasticity", fill=NULL) + TH
ggsave(file.path(FIGDIAG, paste0("zz_", "COMPARE_01_decomposition.png")), p1, width=10, height=3.6, dpi=200)

p2 <- ggplot(s, aes(reorder(ctry, gdp_pc), quality_share, fill=lab)) +
  geom_col(position=position_dodge(.8), width=.75) +
  geom_hline(yintercept=.5, linetype="dashed", colour="grey50") +
  labs(title="Share of the income response that is quality",
       subtitle="Countries ordered by GDP per capita. Above the dashed line, upgrading dominates.",
       x=NULL, y="Quality share", fill=NULL) + TH
ggsave(file.path(FIGDIAG, paste0("zz_", "COMPARE_02_quality_share.png")), p2, width=8, height=4, dpi=200)

p3 <- ggplot(s, aes(participation, quality_share, colour=country, label=lab)) +
  geom_point(size=3) + geom_text(vjust=-.9, size=3, show.legend=FALSE) +
  labs(title="Where a market is wide, is it also deep?",
       subtitle="Participation on the horizontal axis, quality upgrading on the vertical",
       x="% of households purchasing", y="Quality share", colour=NULL) + TH
ggsave(file.path(FIGDIAG, paste0("zz_", "COMPARE_03_participation_vs_quality.png")), p3, width=7.5, height=5, dpi=200)

message("\nwritten -> ", RES_DIR, " and ", FIG)
###############################################################################


