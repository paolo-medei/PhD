###############################################################################
## PART 9 — THREE MARGINS, PANEL INTERVALS, COFFEE IN ETHIOPIA
##
##  9.1 THREE MARGINS (v22). Mean spending on a product, over buyers and
##      non-buyers, is P x q x uv: the share of households that buy, the kilos
##      a buyer buys, the price a buyer pays per kilo. Its elasticity with
##      respect to total expenditure is therefore the sum of
##        entry    = (dP / dlog x) / P     more households start buying
##        quantity =  dlog q  / dlog x     buyers buy more kilos
##        quality  =  dlog uv / dlog x     buyers pay more per kilo
##      (McDonald & Moffitt 1980). The Deaton decomposition of PART 3 covers
##      the last two only. Pooled over waves, region x year effects, survey
##      weights, unit values trimmed at 1-99% within each year; standard
##      errors and intervals for the shares by bootstrap over household-rounds
##      (MARGINS_B replications, fixed seed).
##  9.2 PANEL INTERVALS. The quality elasticity from the four panel designs
##      (permanent income, transitory income, household fixed effects, long
##      differences) with standard errors and 95% intervals in one table.
##  9.3 COFFEE IN ETHIOPIA. Who drinks, buys and grows coffee by year; what
##      coffee sales are worth to growers; whether growers buy meat more often
##      than non-growers at the same expenditure, region and year. Ethiopia
##      only: in Tanzania the food module lumps coffee with cocoa, and in
##      Nigeria hardly anyone grows it.
###############################################################################
if (exists("RUN_MARGINS") && !RUN_MARGINS) message("PART 9 skipped") else {
if (!exists("MARGINS_B")) MARGINS_B <- 100
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), panel.grid.minor=element_blank(),
        strip.text=element_text(face="bold"))

## coefficient on l_x only; standard errors come from the bootstrap
cx <- function(f, g) {
  m <- try(suppressMessages(feols(f, g, weights = ~weight, vcov = "iid", lean = TRUE)),
           silent = TRUE)
  if (inherits(m, "try-error") || !("l_x" %in% names(coef(m)))) NA_real_ else unname(coef(m)["l_x"])
}
three <- function(g, ctrl) {
  P  <- weighted.mean(g$buys, g$weight)
  sl <- cx(as.formula(paste("buys ~ l_x +", ctrl, "| ry")), g)
  b  <- g %>% filter(uv > 0, qty > 0, unconv == 0) %>% group_by(year) %>%
    filter(uv >= quantile(uv, .01), uv <= quantile(uv, .99)) %>% ungroup()
  c(P = P, slope = sl, entry = sl / P,
    qty  = cx(as.formula(paste("log(qty) ~ l_x +", ctrl, "| ry")), b),
    qual = cx(as.formula(paste("log(uv)  ~ l_x +", ctrl, "| ry")), b),
    n_uv = nrow(b))
}

## ---------------- 9.1 three margins --------------------------------------- #
marg <- list()
for (pf in list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  d   <- prep(raw)                                   # PART 3
  cv  <- c("l_ae", "urban")
  for (v in c("share_child","share_elderly","head_age","head_female"))
    if (v %in% names(raw) && mean(!is.na(raw[[v]])) > .5) { d[[v]] <- as.numeric(raw[[v]]); cv <- c(cv, v) }
  ctrl <- paste(cv, collapse = " + ")
  prods <- c("meat_agg", "milk", "eggs", if (cc == "ETH") "coffee")
  d <- d %>% filter(track == "A", product %in% prods, welfare > 0) %>%
    filter(if_all(all_of(cv), ~ !is.na(.x))) %>%
    mutate(ry   = paste(as.character(region), year, sep = "_"),
           buys = as.integer(coalesce(qty > 0, FALSE) | coalesce(exp > 0, FALSE)))
  message("\n########## THREE MARGINS: ", cc, " ##########  (", MARGINS_B, " bootstrap draws)")
  for (p in prods) {
    g <- d %>% filter(product == p)
    if (sum(g$buys) < 100) next
    e <- three(g, ctrl)
    rows <- split(seq_len(nrow(g)), paste(g$hhid, g$year))
    set.seed(42)
    bt <- t(replicate(MARGINS_B, {
      gb <- g[unlist(rows[sample.int(length(rows), replace = TRUE)], use.names = FALSE), ]
      three(gb, ctrl)[c("entry", "qty", "qual")]
    }))
    sh <- bt / rowSums(bt); tot <- sum(e[c("entry", "qty", "qual")])
    q  <- function(x, a) unname(quantile(x, a, na.rm = TRUE))
    marg[[paste(cc, p)]] <- tibble(
      country = cc, product = p, n = nrow(g), n_buyers = sum(g$buys), n_unit_values = e[["n_uv"]],
      P = e[["P"]], slope = e[["slope"]],
      e_entry = e[["entry"]], se_entry = sd(bt[, 1]),
      e_qty   = e[["qty"]],   se_qty   = sd(bt[, 2]),
      e_qual  = e[["qual"]],  se_qual  = sd(bt[, 3]),
      e_total = tot,
      sh_entry = e[["entry"]] / tot, sh_entry_lo = q(sh[, 1], .025), sh_entry_hi = q(sh[, 1], .975),
      sh_qty   = e[["qty"]]   / tot,
      sh_qual  = e[["qual"]]  / tot, sh_qual_lo  = q(sh[, 3], .025), sh_qual_hi  = q(sh[, 3], .975),
      bootstrap_draws = MARGINS_B)
    message(sprintf("  %-9s entry %.3f  quantity %.3f  quality %.3f  -> shares %.0f / %.0f / %.0f %%",
                    p, e[["entry"]], e[["qty"]], e[["qual"]],
                    100 * e[["entry"]] / tot, 100 * e[["qty"]] / tot, 100 * e[["qual"]] / tot))
  }
}
if (length(marg)) {
  mg <- bind_rows(marg)
  write.csv(mg, file.path(TMPCSV, "MARGINS_01_three_margins.csv"), row.names = FALSE)
  pl <- mg %>% filter(product != "coffee") %>%
    select(country, product, Entry = sh_entry, Quantity = sh_qty, Quality = sh_qual) %>%
    pivot_longer(c(Entry, Quantity, Quality), names_to = "margin", values_to = "share") %>%
    mutate(margin = factor(margin, c("Quality", "Quantity", "Entry")),
           country = factor(country, c("ETH", "TZA", "NGA")))
  gm <- ggplot(pl, aes(product, 100 * share, fill = margin)) + geom_col(width = .7) +
    coord_flip() + facet_wrap(~country) +
    scale_fill_manual(values = c(Entry = "#4E79A7", Quantity = "#F28E2B", Quality = "#59A14F"),
                      breaks = c("Entry", "Quantity", "Quality")) +
    labs(title = "Most of the income response is more households buying, not dearer food",
         subtitle = "Share of the expenditure elasticity of mean spending: entry, quantity, quality",
         x = NULL, y = "% of the elasticity", fill = NULL) + TH
  ggsave(file.path(FIGDIR, "MARGINS_three_margins.png"), gm, width = 10, height = 4, dpi = 200)
}

## ---------------- 9.2 panel intervals ------------------------------------- #
rd <- function(f) { f <- file.path(TMPCSV, f); if (file.exists(f)) read.csv(f, stringsAsFactors = FALSE) else NULL }
ci <- list()
for (cc in c("ETH", "TZA", "NGA")) {
  pt <- rd(paste0(cc, "_30_permanent_transitory.csv"))
  fe <- rd(paste0(cc, "_12_household_FE.csv"))
  ld <- rd(paste0(cc, "_31_long_differences.csv"))
  one <- function(t, design, b, s, p) if (is.null(t) || !all(c(b, s, p) %in% names(t))) NULL else
    tibble(country = cc, product = t$product, design = design, b = t[[b]], se = t[[s]], p = t[[p]])
  ci[[cc]] <- bind_rows(
    one(pt, "Permanent income",        "qual_permanent",   "se_qual_perm",  "p_qual_perm"),
    one(pt, "Transitory income",       "qual_transitory",  "se_qual_trans", "p_qual_trans"),
    one(fe, "Household fixed effects", "e_quality_FE",     "se_quality",    "p_quality"),
    one(ld, "Long differences",        "quality_longdiff", "se_qual",       "p_qual"))
}
ci <- bind_rows(ci)
if (nrow(ci)) {
  ci <- ci %>% mutate(lo = b - 1.96 * se, hi = b + 1.96 * se) %>% arrange(country, product)
  write.csv(ci, file.path(TMPCSV, "PANEL_01_quality_intervals.csv"), row.names = FALSE)
  cp <- ci %>% filter(product == "meat_agg") %>%
    mutate(design = factor(design, rev(c("Permanent income", "Transitory income",
                                         "Household fixed effects", "Long differences"))),
           country = factor(country, c("ETH", "TZA", "NGA")))
  gc <- ggplot(cp, aes(b, design)) + geom_vline(xintercept = 0, colour = "grey60") +
    geom_errorbar(aes(xmin = lo, xmax = hi), width = .2, orientation = "y") + geom_point(size = 2) +
    facet_wrap(~country) +
    labs(title = "Meat quality responds to lasting income far more than to year-to-year changes",
         subtitle = "Quality (unit value) elasticity with 95% interval, households seen in more than one wave",
         x = "Quality elasticity", y = NULL) + TH
  ggsave(file.path(FIGDIR, "PANEL_meat_quality_intervals.png"), gc, width = 10, height = 3.5, dpi = 200)
}

## ---------------- 9.3 coffee in Ethiopia ---------------------------------- #
pe <- file.path(OUT_DIR, "panel_ETH.csv")
if (file.exists(pe)) {
  e <- read.csv(pe, stringsAsFactors = FALSE) %>% filter(track == "A") %>%
    mutate(hhid = as.character(hhid), w = num(weight), w = ifelse(is.na(w) | w <= 0, 1, w),
           across(any_of(c("coffee_grower","coffee_sale_birr","total_cons_ann","nom_totcons_aeq",
                           "purch_kg","own_kg","qty_kg","exp","consumed","adulteq")), num))
  if (all(c("coffee_grower", "coffee_sale_birr", "total_cons_ann") %in% names(e))) {
    message("\n########## COFFEE: ETH ##########")
    cf <- e %>% filter(product == "coffee") %>%
      mutate(buys = as.integer(coalesce(purch_kg > 0, FALSE) | coalesce(exp > 0, FALSE)),
             cons = as.integer(coalesce(qty_kg > 0, FALSE) | coalesce(consumed == 1, FALSE)),
             own  = as.integer(coalesce(own_kg > 0, FALSE)),
             grower = coalesce(coffee_grower, 0), sale = coalesce(coffee_sale_birr, 0))
    wm <- function(x, w) 100 * weighted.mean(x, w)
    c1 <- cf %>% group_by(year) %>%
      summarise(n = n(), pct_consume = wm(cons, w), pct_buy = wm(buys, w),
                pct_own_production = wm(own, w), pct_grower = wm(grower, w),
                n_growers = sum(grower), pct_sell_coffee = wm(sale > 0, w))
    c2 <- cf %>% filter(grower == 1) %>% mutate(sale_share = sale / total_cons_ann) %>%
      group_by(year) %>%
      summarise(n_growers = n(), n_sellers = sum(sale > 0),
                median_sales_pct_of_consumption = 100 * median(sale_share, na.rm = TRUE),
                median_among_sellers = 100 * median(sale_share[sale > 0], na.rm = TRUE),
                pct_consume = wm(cons, w), pct_buy = wm(buys, w), pct_own_production = wm(own, w))
    ## 2011 is left out: the 2011 crop roster does not identify growers reliably
    mt <- e %>% filter(product == "meat_agg", nom_totcons_aeq > 0, year >= 2013) %>%
      left_join(cf %>% distinct(hhid, year, grower), by = c("hhid", "year")) %>%
      mutate(grower = coalesce(grower, 0),
             buys = as.integer(coalesce(purch_kg > 0, FALSE) | coalesce(exp > 0, FALSE)),
             l_x = log(nom_totcons_aeq), l_ae = log(pmax(adulteq, 1)),
             ry = paste(region, year, sep = "_"))
    m <- feols(buys ~ grower + l_x + l_ae | ry, mt, weights = ~w, cluster = ~ea_id)
    c3 <- tibble(years = "2013-2021", n = nobs(m),
                 b_grower = unname(coef(m)["grower"]), se_grower = unname(se(m)["grower"]),
                 p_grower = unname(pvalue(m)["grower"]), b_log_expenditure = unname(coef(m)["l_x"]),
                 pct_buy_meat_growers = with(mt[mt$grower == 1, ], wm(buys, w)),
                 pct_buy_meat_others  = with(mt[mt$grower == 0, ], wm(buys, w)))
    print(as.data.frame(c1 %>% mutate(across(where(is.numeric), ~ round(.x, 1)))))
    print(as.data.frame(c3 %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
    write.csv(c1, file.path(TMPCSV, "COFFEE_01_ETH_by_year.csv"), row.names = FALSE)
    write.csv(c2, file.path(TMPCSV, "COFFEE_02_ETH_growers.csv"), row.names = FALSE)
    write.csv(c3, file.path(TMPCSV, "COFFEE_03_ETH_meat_growers.csv"), row.names = FALSE)
  }
}
}
###############################################################################
