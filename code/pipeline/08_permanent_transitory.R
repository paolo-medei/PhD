###############################################################################
## PART 7 — IS THE QUALITY EFFECT REALLY ABSENT?
##
##  The household fixed effects put the quality elasticity at roughly zero,
##  which looks like it contradicts both the cross-section (0.13 for Ethiopian
##  meat) and standard demand theory. Before accepting that, three things have
##  to be ruled out. Each is a regression, not an opinion.
##
##  7.1 PERMANENT vs TRANSITORY INCOME.
##      Fixed effects identify from within-household income changes, which are
##      largely year-to-year noise. Buying MORE meat is an immediate, reversible
##      decision; changing which butcher and which cut you buy is a habit, and
##      habits respond to PERMANENT income. If quality responds to the permanent
##      component and quantity to the transitory one, the two estimates answer
##      different questions and both are right.
##      TEST: split each household's log welfare into its own mean across waves
##      (permanent) and the deviation from it (transitory), and let the two
##      enter separately. A large coefficient on the mean and a small one on the
##      deviation is the signature.
##
##  7.2 LONG DIFFERENCES.
##      Compare each household's FIRST and LAST observation. A ten-year change
##      in income is persistent in a way a one-year change is not. If quality
##      reappears over long differences, 7.1 is confirmed.
##
##  7.3 ATTENUATION.
##      Welfare is measured with error. Fixed effects amplify the attenuation,
##      because the signal-to-noise ratio is worse within household than between.
##      A small effect like quality suffers proportionally far more than a large
##      one like quantity.
##      TEST: re-estimate using the household's MEAN welfare, which averages the
##      error away. If the coefficient rises, attenuation was the problem.
##
##  7.4 WHERE THE UPGRADING ACTUALLY HAPPENS.
##      Unit value per kilo measures quality WITHIN a product. But in a poor
##      country the upgrading is BETWEEN products - dropping milk for meat. Cost
##      per gram of protein captures that, and is comparable across products.
##      This section reports the quality share both ways.
###############################################################################
if (exists("RUN_PERM") && !RUN_PERM) message("PART 7 skipped") else {

perm_out <- list()

for (pf in list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  message("\n########## PERMANENT vs TRANSITORY: ", cc, " ##########")
  raw <- read.csv(pf, stringsAsFactors=FALSE)

  d <- raw %>%
    mutate(hhid    = as.character(hhid),
           qty_pur = num(if ("purch_std" %in% names(.)) purch_std else purch_kg),
           welfare = num(if ("welfare" %in% names(.)) welfare else nom_totcons_aeq),
           weight  = num(if ("hhweight" %in% names(.)) hhweight else weight),
           adulteq = pmax(num(adulteq), 1), uv = num(uv),
           unconv  = ifelse(is.na(num(unconv)), 0, num(unconv))) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight),
           l_ae = log(adulteq))
  ## v21 (M12): welfare is nominal (Ethiopia, Nigeria) or deflated only within
  ## the wave (Tanzania). A household's mean over waves then mixed its income
  ## with the inflation of the years it happened to be observed in. Log welfare
  ## is therefore taken relative to its weighted mean in the year (one row per
  ## household); with year effects in every model this changes nothing else.
  ym <- d %>% filter(track == "A", welfare > 0) %>% distinct(hhid, year, .keep_all = TRUE) %>%
    group_by(year) %>% summarise(lx_year = weighted.mean(log(welfare), weight), .groups = "drop")
  d <- d %>% left_join(ym, by = "year") %>%
    filter(track == "A", product %in% c("meat_agg","milk","eggs","coffee"),
           welfare > 0, uv > 0, qty_pur > 0, unconv == 0)

  ## link the waves
  pids <- try(panel_ids(cc), silent=TRUE)
  if (inherits(pids,"try-error") || is.null(pids) || !nrow(pids)) {
    message("no panel link for ", cc, " — skipped"); next
  }
  d <- d %>% left_join(pids, by=c("hhid","wave"), relationship="many-to-one") %>%
    filter(!is.na(pid))

  ## keep households seen in more than one wave
  d <- d %>% group_by(product, pid) %>% filter(n_distinct(year) > 1) %>% ungroup()
  if (!nrow(d)) { message("panel too thin"); next }

  ## split log welfare into a PERMANENT part (the household's own mean) and a
  ## TRANSITORY part (the deviation from it)
  d <- d %>% group_by(product, pid) %>%
    mutate(l_x      = log(welfare) - lx_year,
           lx_perm  = mean(l_x, na.rm=TRUE),
           lx_trans = l_x - lx_perm) %>% ungroup()

  ## ---------------- 7.1 permanent vs transitory ------------------------- #
  pt <- function(g) {
    if (nrow(g) < 120 || n_distinct(g$pid) < 60) return(tibble())
    gv <- function(m,k) if (inherits(m,"try-error") || !(k %in% names(coef(m))))
            c(NA,NA) else c(coef(m)[k], pvalue(m)[k])
    ## no household FE here: the permanent term IS the between-household part
    mq <- try(feols(log(uv)      ~ lx_perm + lx_trans + l_ae | year,
                    g, weights=~weight, cluster=~pid), silent=TRUE)
    mn <- try(feols(log(qty_pur) ~ lx_perm + lx_trans + l_ae | year,
                    g, weights=~weight, cluster=~pid), silent=TRUE)
    qp <- gv(mq,"lx_perm"); qt <- gv(mq,"lx_trans")
    np <- gv(mn,"lx_perm"); nt <- gv(mn,"lx_trans")
    tibble(n_obs=nrow(g), n_hh=n_distinct(g$pid),
           qual_permanent=qp[1], p_qual_perm=qp[2],
           qual_transitory=qt[1], p_qual_trans=qt[2],
           qty_permanent=np[1],  p_qty_perm=np[2],
           qty_transitory=nt[1], p_qty_trans=nt[2])
  }
  r1 <- d %>% group_by(product) %>% group_modify(~pt(.x)) %>% ungroup()
  cat("\n--- 7.1 permanent vs transitory income ---\n")
  print(as.data.frame(r1 %>% mutate(across(where(is.numeric), ~round(.x,3)))))
  cat("\n   If qual_permanent >> qual_transitory, quality responds to lasting\n",
      "  income and the fixed-effects zero was answering a different question.\n")

  ## ---------------- 7.2 long differences -------------------------------- #
  ld <- d %>% group_by(product, pid) %>%
    filter(n() > 1) %>%
    arrange(year, .by_group=TRUE) %>%
    summarise(d_lx  = last(log(welfare)) - first(log(welfare)),
              d_luv = last(log(uv))      - first(log(uv)),
              d_lq  = last(log(qty_pur)) - first(log(qty_pur)),
              d_lae = last(l_ae)         - first(l_ae),
              yrs   = last(year) - first(year),
              pair  = paste(first(year), last(year)),
              weight= first(weight), .groups="drop") %>%
    filter(is.finite(d_lx), is.finite(d_luv), is.finite(d_lq), yrs >= 2)

  ldfit <- function(g) {
    if (nrow(g) < 100) return(tibble())
    gv <- function(m) if (inherits(m,"try-error")) c(NA,NA) else
            c(coef(m)["d_lx"], pvalue(m)["d_lx"])
    ## v21 (M12): one effect per pair of years (first, last). Without it the
    ## inflation between the two years sits in both d_lx and d_luv, and pairs
    ## further apart look like "richer households buying dearer meat".
    a <- gv(try(feols(d_luv ~ d_lx + d_lae | pair, g, weights=~weight, vcov="hetero"), silent=TRUE))
    b <- gv(try(feols(d_lq  ~ d_lx + d_lae | pair, g, weights=~weight, vcov="hetero"), silent=TRUE))
    tibble(n_hh=nrow(g), median_years=median(g$yrs),
           quality_longdiff=a[1], p_qual=a[2],
           quantity_longdiff=b[1], p_qty=b[2],
           quality_share=a[1]/(a[1]+b[1]))
  }
  r2 <- ld %>% group_by(product) %>% group_modify(~ldfit(.x)) %>% ungroup()
  cat("\n--- 7.2 long differences: first vs last observation ---\n")
  print(as.data.frame(r2 %>% mutate(across(where(is.numeric), ~round(.x,3)))))

  ## ---------------- 7.3 attenuation ------------------------------------- #
  at <- function(g) {
    if (nrow(g) < 120 || n_distinct(g$pid) < 60) return(tibble())
    gv <- function(m,k) if (inherits(m,"try-error") || !(k %in% names(coef(m))))
            NA else unname(coef(m)[k])
    m_cur  <- try(feols(log(uv) ~ l_x     + l_ae | year, g, weights=~weight,
                        cluster=~pid), silent=TRUE)
    m_mean <- try(feols(log(uv) ~ lx_perm + l_ae | year, g, weights=~weight,
                        cluster=~pid), silent=TRUE)
    tibble(n_obs=nrow(g),
           quality_current_welfare = gv(m_cur,"l_x"),
           quality_mean_welfare    = gv(m_mean,"lx_perm"),
           ratio = gv(m_mean,"lx_perm") / gv(m_cur,"l_x"))
  }
  r3 <- d %>% group_by(product) %>% group_modify(~at(.x)) %>% ungroup()
  cat("\n--- 7.3 attenuation: current welfare vs household-mean welfare ---\n")
  print(as.data.frame(r3 %>% mutate(across(where(is.numeric), ~round(.x,3)))))
  cat("\n   A ratio well above 1 means measurement error was flattening the\n",
      "  estimate; the mean averages the error away.\n")

  write.csv(r1, file.path(TMPCSV, paste0(cc,"_30_permanent_transitory.csv")), row.names=FALSE)
  write.csv(r2, file.path(TMPCSV, paste0(cc,"_31_long_differences.csv")), row.names=FALSE)
  write.csv(r3, file.path(TMPCSV, paste0(cc,"_32_attenuation.csv")), row.names=FALSE)
  perm_out[[cc]] <- r1

  ## ---------------- 7.4 within-product vs between-product quality -------- #
  f22 <- file.path(TMPCSV, paste0(cc,"_22_four_margins.csv"))
  d01 <- file.path(TMPCSV, paste0(cc,"_01_decomposition.csv"))
  if (file.exists(f22) && file.exists(d01)) {
    fm  <- read.csv(f22, stringsAsFactors=FALSE)
    dec <- read.csv(d01, stringsAsFactors=FALSE)
    ## v21 (M13): coffee is not an animal-source food (M9); it was in this mean
    within <- dec %>% filter(product != "coffee") %>%
      summarise(q = mean(e_quality, na.rm=TRUE),
                                e = mean(e_expenditure, na.rm=TRUE))
    cst <- fm %>% filter(grepl("COST", product)) %>% pull(e_quantity_ae)
    prt <- fm %>% filter(grepl("PROTEIN", product)) %>% pull(e_quantity_ae)
    if (length(cst) && length(prt)) {
      comp <- tibble(
        measure = c("WITHIN product (unit value per kg)",
                    "BETWEEN products (cost per gram of protein)"),
        quality_elasticity = round(c(within$q, cst[1]), 3),
        total_elasticity   = round(c(within$e, prt[1] + cst[1]), 3),
        quality_share      = round(c(within$q/within$e, cst[1]/(prt[1]+cst[1])), 3))
      cat("\n--- 7.4 where the upgrading happens ---\n")
      print(as.data.frame(comp))
      cat("\n   Measuring quality only within a product misses the shift BETWEEN\n",
          "  products - dropping milk for meat - which is the real upgrading\n",
          "  margin at these income levels.\n")
      write.csv(comp, file.path(TMPCSV, paste0(cc,"_33_within_vs_between.csv")),
                row.names=FALSE)
    }
  }
}

## ---------------- a single figure summarising the answer ----------------- #
if (length(perm_out)) {
  pp <- bind_rows(perm_out, .id="country") %>%
    select(country, product, Permanent=qual_permanent, Transitory=qual_transitory) %>%
    pivot_longer(c(Permanent, Transitory), names_to="component", values_to="e") %>%
    filter(!is.na(e))
  if (nrow(pp)) {
    gp <- ggplot(pp, aes(product, e, fill=component)) +
      geom_col(position=position_dodge(.8), width=.7) + coord_flip() +
      facet_wrap(~country) +
      scale_fill_manual(values=c(Permanent="#59A14F", Transitory="#BAB0AC")) +
      labs(title="Quality responds to PERMANENT income, not to year-to-year swings",
           subtitle="Quality elasticity split into the household's own mean income and its deviation",
           x=NULL, y="Quality elasticity", fill=NULL) + TH
    ggsave(file.path(FIGDIAG, paste0("zz_", "PERM_quality_permanent_vs_transitory.png")),
           gp, width=10, height=4.5, dpi=200)
  }
}
}
###############################################################################


