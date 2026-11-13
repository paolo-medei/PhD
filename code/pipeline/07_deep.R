###############################################################################
## PART 6 — THE DEEP LAYER
##
##  What was missing, and is added here:
##   * everything PER ADULT EQUIVALENT, not per household. A household total
##     confounds consumption with family size.
##   * meat DISAGGREGATED — beef, goat & sheep, pork, poultry, each on its own.
##     Track B was already in the panel and was going unused.
##   * the BASKET: what the richest fifth eats compared with the poorest, in
##     composition and not only in level.
##   * splits by LIVESTOCK OWNERSHIP and by COFFEE GROWING, because a producer
##     household is a different animal from a pure consumer.
##   * PROTEIN. A kilo of beef and a litre of milk are not comparable; a gram
##     of protein is. This makes every product commensurable and turns the
##     analysis into something nutritionally meaningful.
##
##  THE NEW IDEA — a fourth margin.
##  The literature splits the income response into QUANTITY and QUALITY. With
##  products separated we can test a third possibility that neither captures:
##  that extra income buys VARIETY. A household that moves from eating only
##  milk to eating milk, eggs and chicken has not bought more of anything, nor
##  anything more expensive — it has diversified. We measure it two ways: the
##  count of distinct animal products consumed, and the concentration of the
##  basket (Herfindahl). If the variety elasticity is large where the quality
##  elasticity is zero, the transition is about breadth, not grade.
##
##  And a better quality measure: PRICE PER GRAM OF PROTEIN. Unit value per kilo
##  cannot be compared across products; cost per gram of protein can, and it
##  says whether richer households pay more for the same nutrient.
###############################################################################
if (exists("RUN_DEEP") && !RUN_DEEP) message("PART 6 skipped") else {

RES_DIR <- RUN_DIR
FIGD <- FIGDIAG

## ---- protein content, standard food-composition values ------------------- #
## grams of protein per standard unit of the product as recorded in the panel.
PROT <- tibble::tribble(
  ~product,      ~std,     ~prot,
  "beef",        "kg",     260,
  "goat_sheep",  "kg",     250,
  "pork",        "kg",     250,
  "poultry",     "kg",     270,
  "meat_agg",    "kg",     255,
  "fish",        "kg",     200,
  "eggs",        "kg",     126,
  "eggs",        "piece",  6.9,     # a 55 g egg
  "milk",           "litre",  33,
  "milk",           "kg",     33,
  "milk_processed", "kg",    250,   # powder dominates; tinned is lower
  "milk_processed", "litre", 33,    # v21: Tanzania's 902 (cream, yoghurt) is liquid
  "cheese",      "kg",     200,
  "coffee",      "kg",     0        # a stimulant, not a protein source
)
## v21 (M5, decided 12 Nov 2026): fish OUT - the thesis is about livestock,
## and only Nigeria had fish in the basket, so counts were not comparable.
ANIMAL <- c("beef","goat_sheep","pork","poultry","eggs","milk",
            "milk_processed","cheese")

deep_prep <- function(pf) {
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  d <- raw %>%
    mutate(country = cc, hhid = as.character(hhid),
           std     = if ("std" %in% names(.)) as.character(std) else "kg",
           qty_pur = num(if ("purch_std" %in% names(.)) purch_std else purch_kg),
           qty_tot = num(if ("qty_std"   %in% names(.)) qty_std   else qty_kg),
           exp     = num(exp), uv = num(uv),
           welfare = num(if ("welfare" %in% names(.)) welfare else nom_totcons_aeq),
           adulteq = pmax(num(adulteq), 1),
           weight  = num(if ("hhweight" %in% names(.)) hhweight else weight),
           unconv  = ifelse(is.na(num(unconv)), 0, num(unconv))) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight)) %>%
    filter(track == "B")                      # DISAGGREGATED products
  ## per adult equivalent
  d %>% left_join(PROT, by=c("product","std")) %>%
    mutate(q_ae   = qty_tot / adulteq,
           qp_ae  = qty_pur / adulteq,
           exp_ae = exp / adulteq,
           prot_ae_day = (coalesce(qty_tot,0) * coalesce(prot,0)) / adulteq / 7,
           l_x = log(welfare), l_ae = log(adulteq))
}

## ---- household-level aggregates: basket, variety, protein ---------------- #
hh_level <- function(d) {
  d %>% filter(product %in% ANIMAL) %>%
    group_by(country, year, region, hhid, welfare, adulteq, weight, l_x) %>%
    summarise(
      ## v21 (D14): consumed = said so, or a convertible quantity
      n_products  = sum(coalesce(qty_tot,0) > 0 | coalesce(consumed,0) == 1),  # VARIETY, count
      asf_exp     = sum(coalesce(exp,0)),
      asf_prot    = sum(coalesce(prot,0)*coalesce(qty_tot,0)),
      hhi         = { s <- coalesce(exp,0); s <- s/ifelse(sum(s)>0,sum(s),NA)
                      sum(s^2, na.rm=TRUE) },              # basket concentration
      .groups="drop") %>%
    mutate(prot_ae_day = asf_prot/adulteq/7,
           asf_exp_ae  = asf_exp/adulteq,
           cost_per_g  = ifelse(asf_prot > 0, asf_exp/asf_prot, NA_real_))
}

for (pf in list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)) {

  cc <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  message("\n############ DEEP: ", cc, " ############")
  d  <- deep_prep(pf)
  H  <- hh_level(d)

  ## quintiles of welfare, within year
  d <- d %>% group_by(year) %>% mutate(qt = ntile(welfare, 5)) %>% ungroup()
  H <- H %>% group_by(year) %>% mutate(qt = ntile(welfare, 5)) %>% ungroup()

  ## ======================= 6.1 THE BASKET, RICH vs POOR ================== #
  cat("\n--- 6.1 what the richest fifth eats, against the poorest ---\n")
  basket <- d %>% filter(product %in% ANIMAL, !is.na(qt)) %>%
    group_by(qt, product) %>%
    summarise(pct_consuming = round(100*weighted.mean(coalesce(qty_tot,0) > 0,
                                                      weight, na.rm=TRUE), 1),
              kg_per_ae_wk  = round(weighted.mean(coalesce(q_ae,0), weight, na.rm=TRUE), 3),
              share_of_asf_spend = NA_real_, .groups="drop")
  ## v21 (M10): shares within each year (no adding up nominal spending across
  ## years with different inflation), weighted to the population, then the
  ## average over waves - every wave counts the same.
  shares <- d %>% filter(product %in% ANIMAL, !is.na(qt)) %>%
    group_by(year, qt) %>% mutate(tot = sum(coalesce(exp,0) * weight)) %>%
    group_by(year, qt, product) %>%
    summarise(s = 100*sum(coalesce(exp,0) * weight)/first(tot), .groups="drop") %>%
    group_by(qt, product) %>%
    summarise(share_of_asf_spend = round(mean(s, na.rm=TRUE), 1), .groups="drop")
  basket <- basket %>% select(-share_of_asf_spend) %>%
    left_join(shares, by=c("qt","product"))
  print(as.data.frame(basket %>%
    select(product, qt, pct_consuming) %>%
    pivot_wider(names_from=qt, values_from=pct_consuming, names_prefix="Q")))
  write.csv(basket, file.path(TMPCSV, paste0(cc,"_20_basket_by_quintile.csv")),
            row.names=FALSE)

  cat("\n--- composition of the animal-food basket, % of ASF spending ---\n")
  print(as.data.frame(basket %>% select(product, qt, share_of_asf_spend) %>%
    pivot_wider(names_from=qt, values_from=share_of_asf_spend, names_prefix="Q")))

  ## ======================= 6.2 PROTEIN AND VARIETY ======================= #
  cat("\n--- 6.2 protein, variety and cost per gram, by quintile ---\n")
  pv <- H %>% filter(!is.na(qt)) %>% group_by(year, qt) %>%
    summarise(prot_g_ae_day = round(weighted.mean(prot_ae_day, weight, na.rm=TRUE), 1),
              n_products    = round(weighted.mean(n_products,  weight, na.rm=TRUE), 2),
              hhi           = round(weighted.mean(hhi, weight, na.rm=TRUE), 3),
              cost_per_g    = round(median(cost_per_g, na.rm=TRUE), 2),
              .groups="drop")
  print(as.data.frame(pv %>% select(year, qt, prot_g_ae_day) %>%
    pivot_wider(names_from=qt, values_from=prot_g_ae_day, names_prefix="Q")))
  cat("\n   number of distinct animal products consumed:\n")
  print(as.data.frame(pv %>% select(year, qt, n_products) %>%
    pivot_wider(names_from=qt, values_from=n_products, names_prefix="Q")))
  write.csv(pv, file.path(TMPCSV, paste0(cc,"_21_protein_variety.csv")),
            row.names=FALSE)

  ## ======================= 6.3 THE FOUR MARGINS ========================== #
  ## participation | quantity per AE | quality (unit value) | VARIETY
  cat("\n--- 6.3 the four margins of the income response ---\n")
  marg_prod <- function(g) {
    ## v21 (M1-M2, decided 12 Nov 2026): every margin is about PURCHASES -
    ## entry = bought in the last 7 days, quantity = kg bought per adult eq.
    ## v20 used consumption (incl. own production and gifts) for both.
    b <- g %>% filter(qp_ae > 0, uv > 0, welfare > 0, unconv == 0)
    if (nrow(b) < 80) return(tibble())
    M <- function(f, dat) try(feols(f, dat, weights=~weight, vcov="hetero"), silent=TRUE)
    gv <- function(m,k="l_x") if (inherits(m,"try-error") ||
            !(k %in% names(coef(m)))) c(NA,NA) else c(coef(m)[k], pvalue(m)[k])
    full <- g %>% filter(welfare > 0) %>%
      ## v21 (D14): a purchase whose unit does not convert is still a purchase
      mutate(buys = as.integer(coalesce(qty_pur > 0, FALSE) | coalesce(exp > 0, FALSE)))
    ## main: linear probability model, weighted, region x year effects
    mp <- try(feols(buys ~ l_x + l_ae | region^year, full, weights=~weight,
                    vcov="hetero"), silent=TRUE)
    ## robustness: weighted probit, average marginal effect of log welfare
    pb <- try(feglm(buys ~ l_x + l_ae | region^year, full, weights=~weight,
                    family=binomial("probit"), vcov="hetero",
                    glm.iter = 100), silent=TRUE)   # v21: 25 was not enough for TZA
    ame <- if (inherits(pb, "try-error") || !("l_x" %in% names(coef(pb)))) c(NA, NA) else {
      used <- obs(pb); xb <- predict(pb, type = "link")[used]
      c(unname(coef(pb)["l_x"]) * weighted.mean(dnorm(xb), full$weight[used], na.rm = TRUE),
        unname(pvalue(pb)["l_x"])) }
    ## region^year absorbs inflation AND local price level. Without a year
    ## effect, pooling 2011-2021 makes l_x pick up inflation: beef "quality"
    ## came out at 0.636 against 0.131 when estimated year by year.
    cq <- gv(M(as.formula("log(qp_ae) ~ l_x + l_ae | region^year"), b))
    cu <- gv(M(as.formula("log(uv)   ~ l_x + l_ae | region^year"), b))
    cp <- gv(mp)
    tibble(n_obs=nrow(b), participation=round(100*mean(full$buys),1),
           e_participation=cp[1], p_part=cp[2],
           e_part_probit_ame=ame[1], p_part_probit=ame[2],
           e_quantity_ae=cq[1],  p_qty=cq[2],
           e_quality=cu[1],      p_qual=cu[2])
  }
  fm <- d %>% filter(product %in% ANIMAL) %>%
    group_by(product) %>% group_modify(~marg_prod(.x)) %>% ungroup()
  print(as.data.frame(fm %>% mutate(across(where(is.numeric), ~round(.x,3)))))

  ## the fourth margin, estimated at household level
  vfit <- function(dat, dep) {
    ## v21 (M6): region x year effects, like every other model (slide 7)
    m <- try(feols(as.formula(paste(dep, "~ l_x + log(adulteq) | region^year")),
                   dat, weights=~weight, vcov="hetero"), silent=TRUE)
    ## year effects are essential here for the same reason: nominal welfare
    if (inherits(m,"try-error")) return(c(NA,NA))
    c(coef(m)["l_x"], pvalue(m)["l_x"])
  }
  Hs <- H %>% filter(welfare > 0, n_products > 0)
  v1 <- vfit(Hs, "log(n_products)")
  v2 <- vfit(Hs %>% filter(prot_ae_day > 0), "log(prot_ae_day)")
  v3 <- vfit(Hs %>% filter(!is.na(hhi), hhi > 0), "log(hhi)")
  v4 <- vfit(Hs %>% filter(!is.na(cost_per_g), cost_per_g > 0), "log(cost_per_g)")
  four <- tibble(
    margin = c("VARIETY (n. of products)", "PROTEIN per adult eq per day",
               "CONCENTRATION of basket (HHI)", "COST per gram of protein"),
    elasticity = round(c(v1[1], v2[1], v3[1], v4[1]), 3),
    p_value    = round(c(v1[2], v2[2], v3[2], v4[2]), 4))
  cat("\n--- the fourth margin: does income buy VARIETY? ---\n")
  print(as.data.frame(four))
  write.csv(bind_rows(fm %>% mutate(level="product"),
                      four %>% rename(product=margin, e_quantity_ae=elasticity,
                                      p_qty=p_value) %>% mutate(level="household")),
            file.path(TMPCSV, paste0(cc,"_22_four_margins.csv")), row.names=FALSE)

  ## ======================= 6.4 PRODUCERS vs CONSUMERS ==================== #
  cat("\n--- 6.4 livestock owners and coffee growers against the rest ---\n")
  own_col <- intersect(c("own_cattle","own_poultry","own_smallrum"), names(d))
  if (!length(own_col) && exists("livestock_flags")) {
    lsdf <- try(livestock_flags(cc), silent=TRUE)
    if (!inherits(lsdf,"try-error") && !is.null(lsdf) && nrow(lsdf))
      d <- d %>% left_join(lsdf, by=c("hhid","wave"))
  }
  if ("own_cattle" %in% names(d)) {
    sp <- d %>% filter(product %in% c("milk","eggs","beef"), !is.na(own_cattle)) %>%
      mutate(owner = ifelse(product=="eggs", own_poultry, own_cattle)) %>%
      filter(!is.na(owner)) %>%
      group_by(product, owner) %>%
      summarise(n_hh = n_distinct(hhid),
                pct_consuming = round(100*weighted.mean(coalesce(qty_tot,0)>0 | coalesce(consumed,0)==1,
                                                        weight, na.rm=TRUE),1),
                pct_buying    = round(100*weighted.mean(coalesce(qty_pur,0)>0 | coalesce(exp,0)>0,
                                                        weight, na.rm=TRUE),1),
                kg_per_ae     = round(weighted.mean(coalesce(q_ae,0), weight, na.rm=TRUE),3),
                .groups="drop")
    print(as.data.frame(sp))
    write.csv(sp, file.path(TMPCSV, paste0(cc,"_23_owners_vs_not.csv")),
              row.names=FALSE)
    cat("\n   owner = 1 keeps the animal. Consuming can be high while buying is\n",
        "  near zero: that is the market these households are NOT in.\n")
  }
  if ("coffee_grower" %in% names(d)) {          # already in the panel
    dd <- d
    cs <- dd %>% filter(product %in% ANIMAL, !is.na(coffee_grower)) %>%
      group_by(coffee_grower) %>%
      summarise(n_hh=n_distinct(hhid),
                kg_per_ae=round(weighted.mean(coalesce(q_ae,0), weight, na.rm=TRUE),3),
                .groups="drop")
    cat("\n   coffee growers vs the rest, animal food per adult equivalent:\n")
    print(as.data.frame(cs))
  }

  ## ======================= 6.5 FIGURES =================================== #
  bp <- basket %>% filter(!is.na(share_of_asf_spend))
  g1 <- ggplot(bp, aes(factor(qt), share_of_asf_spend, fill=product)) +
    geom_col() +
    labs(title=paste0(cc, ": the animal-food basket, poorest to richest"),
         subtitle="Composition of spending on animal-source food, by welfare quintile",
         x="Welfare quintile", y="% of animal-food spending", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_basket.png"))), g1, width=8, height=4.5, dpi=200)

  g2 <- ggplot(pv, aes(factor(qt), prot_g_ae_day, fill=factor(year))) +
    geom_col(position="dodge") +
    labs(title=paste0(cc, ": animal protein per adult equivalent per day"),
         subtitle="Grams. The WHO reference for total protein is about 50 g/day.",
         x="Welfare quintile", y="g/day from animal sources", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_protein.png"))), g2, width=8, height=4.5, dpi=200)

  g3 <- ggplot(pv, aes(factor(qt), n_products, fill=factor(year))) +
    geom_col(position="dodge") +
    labs(title=paste0(cc, ": variety — how many animal products a household eats"),
         subtitle="The margin that neither quantity nor quality captures",
         x="Welfare quintile", y="distinct products", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_variety.png"))), g3, width=8, height=4.5, dpi=200)

  g4 <- ggplot(fm %>% filter(!is.na(e_quantity_ae)) %>%
                 select(product, Participation=e_participation,
                        Quantity=e_quantity_ae, Quality=e_quality) %>%
                 pivot_longer(-product, names_to="margin", values_to="e"),
               aes(product, e, fill=margin)) +
    geom_col(position="dodge") + coord_flip() +
    labs(title=paste0(cc, ": the income response, three margins, product by product"),
         x=NULL, y="Elasticity", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_margins.png"))), g4, width=9, height=5, dpi=200)

  message("written -> ", RES_DIR, " and ", FIGD)
}
}
###############################################################################


