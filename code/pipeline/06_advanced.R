###############################################################################
## PART 5 — ADVANCED: total consumption, household FE, instrumented selection
###############################################################################
RES_DIR <- RUN_DIR
FIG <- FIGDIAG
grab <- function(stem, hint=NULL) {
  p <- find_dta(stem, hint); if (is.na(p)) return(NULL)
  tryCatch(haven::read_dta(p), error=function(e) NULL)
}
###############################################################################
## COUNTRY CONFIGURATION
##  livestock: file stem, id, animal-code var, count var, and the code groups
##  that map onto our products.
###############################################################################
LS <- list(
  ## v21 (D5): every code and count below was checked against the value labels
  ## and question text of each wave (checks/varmap2.R). v20 used one grouping
  ## for all waves, which is wrong for Ethiopia 2011-2013 and 2015, and read
  ## Tanzania's PAST holdings (lf02_02) instead of current ones.
  ## Groups keep v20's meaning: cattle (milk), other meat animals, poultry (eggs).
  ETH = list(
    waves = c(w1="w1", w2="w2", w3="w3", w4="w4", w5="w5"),
    stem  = function(w) if (w %in% c("w1","w2")) paste0("sect8a_ls_", w)
                        else paste0("sect8_1_ls_", w),
    hint  = function(w) paste0("ETH_20", c(w1="11",w2="13",w3="15",w4="18",w5="21")[[w]]),
    id    = function(w) if (w %in% c("w2","w3")) "household_id2" else "household_id",
    code  = function(w) if (w %in% c("w1","w2")) "ls_s8aq00" else "ls_code",
    ## w1-w2: ls_s8aq13a "grand total owned"; w3: ls_sec_8_1q01; w4-w5: ls_s8_1q01
    count = function(w) c(w1="ls_s8aq13a", w2="ls_s8aq13a", w3="ls_sec_8_1q01",
                          w4="ls_s8_1q01", w5="ls_s8_1q01")[[w]],
    grp   = function(w) switch(w,
      ## 1 cattle, 2 sheep, 3 goats, 4-6 equines, 7 camels, 8-13 chicken
      w1 = , w2 = list(cattle=1, smallrum=c(2,3,7), poultry=8:13),
      ## 1-6 cattle classes, 7-9 goats, 10-12 sheep, 13-15 camels, 16-19 chicken
      w3 = list(cattle=1:6, smallrum=7:15, poultry=16:19),
      ## 1-6 cattle classes, 7 goats, 8 sheep, 9 camels, 10-12 chicken
      list(cattle=1:6, smallrum=7:9, poultry=10:12))),
  TZA = list(
    waves = c(w1="2008", w2="2010", w3="2012", w4="2014", w5="2020"),
    stem  = function(w) c(w1="SEC_10A", w2="AG_SEC10A", w3="LF_SEC_02",
                          w4="LF_SEC_02", w5="LF_SEC_02")[[w]],
    hint  = function(w) paste0("TZA_", c(w1="2008",w2="2010",w3="2012",
                                         w4="2014",w5="2020")[[w]]),
    id    = function(w) c(w1="hhid",w2="y2_hhid",w3="y3_hhid",
                          w4="y4_hhid",w5="y5_hhid")[[w]],
    code  = function(w) c(w1="animal", w2="lvstkcode", w3="lvstckid",
                          w4="lvstckid", w5="lvstckid")[[w]],
    ## CURRENT holdings, summed over breeds: "How many [ANIMAL] does this
    ## household currently own?" (indigenous / improved ...)
    count = function(w) c(w1="^s10aq4_[123]$", w2="^ag10a_05_[123]$",
                          w3="^lf02_04_[12]$", w4="^lf02_04_[12]$", w5="^lf02_04_[12]$")[[w]],
    ## 1-6 cattle, 7 goats, 8 sheep, 9 pigs | 2008-2010: 10 chickens, 11 turkeys;
    ## 2012-2020: 10 chickens, 11 ducks, 12 other poultry
    grp   = function(w) if (w %in% c("w1","w2"))
              list(cattle=1:6, smallrum=7:9, poultry=10:11) else
              list(cattle=1:6, smallrum=7:9, poultry=10:12))
)

livestock_flags <- function(cc) {
  C <- LS[[cc]]; if (is.null(C)) return(NULL)
  map_dfr(names(C$waves), function(w) {
    d <- grab(C$stem(w), C$hint(w)); if (is.null(d)) return(NULL)
    idv <- C$id(w); codev <- C$code(w); cnt <- C$count(w); G <- C$grp(w)
    if (!(idv %in% names(d)) || !(codev %in% names(d))) return(NULL)
    ## the count is either one column or a set of age-class totals to be summed
    cols <- if (grepl("^\\^", cnt)) grep(cnt, names(d), value=TRUE) else
            intersect(cnt, names(d))
    if (!length(cols)) return(NULL)
    d$.n <- rowSums(sapply(cols, function(k) num(d[[k]])), na.rm=TRUE)
    d %>% transmute(hhid = as.character(.data[[idv]]),
                    .code = num(.data[[codev]]),
                    .n    = .n) %>%
      group_by(hhid) %>%
      summarise(own_cattle   = as.integer(any(.code %in% G$cattle   & .n > 0, na.rm=TRUE)),
                own_smallrum = as.integer(any(.code %in% G$smallrum & .n > 0, na.rm=TRUE)),
                own_poultry  = as.integer(any(.code %in% G$poultry  & .n > 0, na.rm=TRUE)),
                n_tlu        = sum(.n, na.rm=TRUE), .groups="drop") %>%
      mutate(wave = w)
  })
}

###############################################################################
## PANEL IDENTIFIER
##  The build uses the wave's own id, which does NOT link waves. Ethiopia's
##  waves 2-3 are keyed on household_id2 while the panel link is household_id;
##  Tanzania chains 2008 -> 2010 -> 2012 through hhid_2008 and y2_hhid.
###############################################################################
panel_ids <- function(cc) {
  if (cc == "ETH") {
    out <- list()
    for (w in c("w1","w4","w5")) {
      d <- grab(paste0("cons_agg_", w), paste0("ETH_20",
             c(w1="11",w4="18",w5="21")[[w]]))
      if (!is.null(d)) out[[w]] <- tibble(wave=w,
        hhid=as.character(d$household_id), pid=as.character(d$household_id))
    }
    for (w in c("w2","w3")) {
      d <- grab(paste0("cons_agg_", w), paste0("ETH_20", c(w2="13",w3="15")[[w]]))
      if (!is.null(d) && all(c("household_id","household_id2") %in% names(d)))
        out[[w]] <- tibble(wave=w, hhid=as.character(d$household_id2),
                           pid=as.character(d$household_id))
    }
    return(bind_rows(out))
  }
  if (cc == "TZA") {
    ## v21 (D9): one panel unit per household, one link per household.
    ## The cover page (HH_SEC_A) gives each household its predecessor id and
    ## says whether it is the ORIGINAL household or a SPLIT-OFF (2010 hh_a11:
    ## 1-2 original, 3 split-off; 2012 and 2020 hh_a10: 1 original, 2 split-off).
    ## The original continues its predecessor's unit; a split-off starts its own,
    ## and so does every household of a lineage with more than one "original".
    ## v20 linked 2012 and 2020 through the individual roster, so 56 households
    ## got two ids (their rows were counted twice) and parent and split-off
    ## households, in the same wave, were treated as one "household" in the
    ## fixed-effects and permanent-income models.
    link <- function(w, hhid, prev, orig, prev_pid = NULL) {
      x <- tibble(hhid = as.character(hhid), prev = as.character(prev),
                  orig = orig %in% TRUE)
      x <- x %>% group_by(prev) %>% mutate(n_orig = sum(orig)) %>% ungroup()
      if (!is.null(prev_pid)) x <- x %>% left_join(prev_pid, by = "prev")
      else x$ppid <- x$prev
      x %>% transmute(wave = w, hhid,
        pid = ifelse(orig & n_orig == 1 & !is.na(prev) & nzchar(prev) & !is.na(ppid),
                     ppid, paste0(w, "_", hhid)))
    }
    out <- list()
    d1 <- grab("TZY1.HH.Consumption", "TZA_2008")
    if (!is.null(d1)) out$w1 <- tibble(wave="w1", hhid=as.character(d1$hhid),
                                       pid=as.character(d1$hhid))
    d2 <- grab("TZY2.HH.Consumption", "TZA_2010"); a2 <- grab("HH_SEC_A", "TZA_2010")
    if (!is.null(d2) && !is.null(a2) && "hhid_2008" %in% names(d2)) {
      x <- d2 %>% transmute(y2_hhid = as.character(y2_hhid), prev = as.character(hhid_2008)) %>%
        left_join(a2 %>% transmute(y2_hhid = as.character(y2_hhid),
                                   orig = as.numeric(hh_a11) %in% c(1, 2)), by = "y2_hhid")
      out$w2 <- link("w2", x$y2_hhid, x$prev, x$orig)
    }
    a3 <- grab("HH_SEC_A", "TZA_2012")
    if (!is.null(a3) && !is.null(out$w2) && all(c("y3_hhid","hh_a09","hh_a10") %in% names(a3)))
      out$w3 <- link("w3", a3$y3_hhid, a3$hh_a09, as.numeric(a3$hh_a10) == 1,
                     prev_pid = out$w2 %>% select(prev = hhid, ppid = pid))
    d4 <- grab("consumptionNPS4", "TZA_2014")
    if (!is.null(d4)) out$w4 <- tibble(wave="w4", hhid=as.character(d4$y4_hhid),
                                       pid=as.character(d4$y4_hhid))
    a5 <- grab("hh_sec_a", "TZA_2020")
    if (!is.null(a5) && all(c("y5_hhid","y4_hhid","hh_a10") %in% names(a5)))
      out$w5 <- link("w5", a5$y5_hhid, a5$y4_hhid, as.numeric(a5$hh_a10) == 1)
    return(bind_rows(out) %>% filter(!is.na(pid)))
  }
  if (cc == "NGA") {
    ## v21 (M7): the GHS-Panel keeps ONE hhid across waves (HHTrack.dta records
    ## each household's status wave by wave); 4,387 households are in all three.
    yrs <- c(w1 = "2010", w2 = "2012", w3 = "2015")
    out <- lapply(names(yrs), function(w) {
      d <- grab(paste0("cons_agg_wave", substr(w, 2, 2), "_visit2"), paste0("NGA_", yrs[[w]]))
      if (is.null(d)) NULL else tibble(wave = w, hhid = as.character(d$hhid), pid = as.character(d$hhid))
    })
    return(bind_rows(out))
  }
  if (cc == "UGA") {
    ## v22: one panel unit per household, as for Tanzania (D9). Each wave says
    ## which earlier household a household continues: the 10-digit HHID is
    ## kept in 2010-2011; 2013 gives HHID_old; 2015 renumbers 2013's
    ## "H00101-04-01" as "H00101-05-01"; 2018 gives t0_hhid (2015's "H0010101")
    ## and 2019 hhidold (2018's key). Only the 2010-11 files say which household
    ## is the original and which a split-off, so from 2013 on, when two
    ## households claim the same predecessor, BOTH start new units (5 cases in
    ## 2018, 68 in 2019). A third of the sample was replaced in 2013 (rotated
    ## in): those households start new units too.
    ids <- function(x) if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x))
    chain <- function(w, hhid, prev, prev_pid) {
      x <- tibble(hhid = ids(hhid), prev = ids(prev)) %>%
        mutate(prev = ifelse(prev %in% c("", "NA"), NA, prev)) %>%
        group_by(prev) %>% mutate(n_claim = n()) %>% ungroup() %>%
        left_join(prev_pid, by = "prev")
      x %>% transmute(wave = w, hhid,
                      pid = ifelse(!is.na(prev) & n_claim == 1 & !is.na(ppid), ppid,
                                   paste0(w, "_", hhid)))
    }
    out <- list()
    g1 <- grab("GSEC1", "UGA_2010"); g2 <- grab("GSEC1", "UGA_2011")
    if (!is.null(g1)) out$w1 <- tibble(wave = "w1", hhid = ids(g1$HHID), pid = ids(g1$HHID))
    if (!is.null(g2)) out$w2 <- tibble(wave = "w2", hhid = ids(g2$HHID), pid = ids(g2$HHID))
    earlier <- bind_rows(out) %>% distinct(prev = hhid, ppid = pid)
    g3 <- grab("GSEC1", "UGA_2013")
    if (!is.null(g3)) {
      ## a 2013 household whose predecessor is not in 2010-11 keeps that id as
      ## its unit, so it links if 2009/10 is added later
      out$w3 <- chain("w3", g3$hhid, g3$HHID_old,
                      bind_rows(earlier, tibble(prev = ids(g3$HHID_old), ppid = ids(g3$HHID_old))) %>%
                        filter(!is.na(prev), prev != "NA") %>% distinct(prev, .keep_all = TRUE))
    }
    g4 <- grab("gsec1", "UGA_2015")
    if (!is.null(g4) && !is.null(out$w3))
      out$w4 <- chain("w4", g4$hh, sub("-05-", "-04-", ids(g4$hh)),
                      out$w3 %>% select(prev = hhid, ppid = pid))
    g5 <- grab("GSEC1", "UGA_2018")
    if (!is.null(g5) && !is.null(out$w4)) {
      k4 <- tibble(prev = ids(g4$hhid), hh = ids(g4$hh)) %>%
        inner_join(out$w4 %>% select(hh = hhid, ppid = pid), by = "hh") %>% select(prev, ppid)
      out$w5 <- chain("w5", g5$hhid, g5$t0_hhid, k4)
    }
    g6 <- grab("gsec1", "UGA_2019")
    if (!is.null(g6) && !is.null(out$w5))
      out$w6 <- chain("w6", g6$hhid, g6$hhidold, out$w5 %>% select(prev = hhid, ppid = pid))
    return(bind_rows(out) %>% filter(!is.na(pid)))
  }
  NULL
}

###############################################################################
## RUN  (helpers above are defined unconditionally so PART 7 can reuse them)
###############################################################################
if (RUN_ADV) {
panels <- list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)
CORE <- c("meat_agg","milk","eggs","coffee")
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), panel.grid.minor=element_blank(),
        strip.text=element_text(face="bold"))

for (pf in panels) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  message("\n================ ", cc, " ================")

  d <- raw %>%
    mutate(hhid    = as.character(hhid),
           qty_pur = num(if ("purch_std" %in% names(.)) purch_std else purch_kg),
           qty_tot = num(if ("qty_std"   %in% names(.)) qty_std   else qty_kg),
           own     = num(if ("own_std"   %in% names(.)) own_std   else own_kg),
           gift    = num(if ("gift_std"  %in% names(.)) gift_std  else gift_kg),
           welfare = num(if ("welfare" %in% names(.)) welfare else nom_totcons_aeq),
           weight  = num(if ("hhweight" %in% names(.)) hhweight else weight),
           adulteq = pmax(num(adulteq), 1),
           uv = num(uv), exp = num(exp),
           unconv = ifelse(is.na(num(unconv)), 0, num(unconv))) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight),
           l_x = log(welfare), l_ae = log(adulteq),
           region = factor(region)) %>%
    filter(track == "A", product %in% CORE)

  ## ---- livestock -------------------------------------------------------- #
  ls_df <- livestock_flags(cc)
  if (!is.null(ls_df) && nrow(ls_df)) {
    d <- d %>% left_join(ls_df, by=c("hhid","wave"))
    message("livestock merged for ", sum(!is.na(d$own_cattle)), " rows")
  } else {
    d$own_cattle <- NA_integer_; d$own_smallrum <- NA_integer_
    d$own_poultry <- NA_integer_
    message("!! livestock module not found for ", cc, " — (C) will be skipped")
  }
  ## the instrument relevant to each product
  d <- d %>% mutate(own_rel = case_when(
    product == "milk"     ~ own_cattle,
    product == "eggs"     ~ own_poultry,
    product == "meat_agg" ~ pmax(own_smallrum, own_cattle, na.rm=TRUE),
    TRUE ~ NA_integer_))

  ## ---- panel id --------------------------------------------------------- #
  pids <- panel_ids(cc)
  if (!is.null(pids) && nrow(pids)) {
    d <- d %>% left_join(pids, by=c("hhid","wave"), relationship="many-to-one")
    nrep <- d %>% filter(!is.na(pid)) %>% distinct(pid, wave) %>%
      count(pid) %>% filter(n > 1) %>% nrow()
    message("panel: ", nrep, " households observed in more than one wave")
  } else d$pid <- NA_character_

  ####################### (A) TOTAL vs PURCHASED #############################
  cat("\n--- (A) how much animal protein never passes through a market ---\n")
  ## Denominator = the three sources themselves, so the shares add to 100.
  ## Dividing by qty_tot gave 181% own-produced and -83% purchased, because a
  ## few households report one source larger than their stated total.
  ## One Tanzanian household reported 8,500 kg of meat received as a gift in a
  ## single week - 8.5 tonnes, plainly a data-entry error, and on its own 96%
  ## of that year's gift total. Sums are defenceless against a single outlier,
  ## so each source is trimmed at its 99.9th percentile within product-year.
  src <- d %>%
    mutate(.p = coalesce(qty_pur,0), .o = coalesce(own,0), .g = coalesce(gift,0)) %>%
    group_by(product, year) %>%
    mutate(across(c(.p,.o,.g), ~ pmin(.x, quantile(.x, .999, na.rm=TRUE)))) %>%
    ungroup() %>%
    mutate(.tot = .p + .o + .g) %>%
    filter(.tot > 0) %>%
    group_by(product, year) %>%
    summarise(pct_purchased = round(100*sum(.p)/sum(.tot),1),
              pct_own       = round(100*sum(.o)/sum(.tot),1),
              pct_gift      = round(100*sum(.g)/sum(.tot),1),
              .groups="drop")
  print(as.data.frame(src))
  write.csv(src, file.path(TMPCSV, paste0(cc,"_10_sources.csv")), row.names=FALSE)

  ## the same decomposition run on TOTAL consumption instead of purchases
  fitA <- function(g) {
    b <- g %>% filter(qty_tot > 0, uv > 0, welfare > 0, unconv == 0)
    if (nrow(b) < 80) return(tibble())
    m <- try(feols(log(qty_tot) ~ l_x + l_ae | region, b, weights=~weight,
                   vcov="hetero"), silent=TRUE)
    p <- try(feols(log(qty_pur) ~ l_x + l_ae | region,
                   b %>% filter(qty_pur > 0), weights=~weight, vcov="hetero"),
             silent=TRUE)
    gv <- function(m) if (inherits(m,"try-error")) NA else unname(coef(m)["l_x"])
    tibble(n=nrow(b), e_qty_total=gv(m), e_qty_purchased=gv(p))
  }
  totq <- d %>% group_by(year, product) %>% group_modify(~fitA(.x)) %>% ungroup()
  cat("\n--- quantity elasticity: TOTAL consumption vs PURCHASES only ---\n")
  print(as.data.frame(totq %>% mutate(across(where(is.numeric), ~round(.x,3)))))
  write.csv(totq, file.path(TMPCSV, paste0(cc,"_11_total_vs_purchased.csv")),
            row.names=FALSE)

  ####################### (B) HOUSEHOLD FIXED EFFECTS ########################
  cat("\n--- (B) household fixed effects: the same family getting richer ---\n")
  fe <- d %>% filter(!is.na(pid), uv > 0, qty_pur > 0, welfare > 0, unconv == 0)
  if (nrow(fe) > 200) {
    fe <- fe %>% group_by(product, pid) %>% filter(n_distinct(year) > 1) %>% ungroup()
    fefit <- function(g) {
      if (nrow(g) < 100 || n_distinct(g$pid) < 50) return(tibble())
      mq <- try(feols(log(uv)      ~ l_x + l_ae | pid + year, g, weights=~weight,
                      cluster=~pid), silent=TRUE)
      mn <- try(feols(log(qty_pur) ~ l_x + l_ae | pid + year, g, weights=~weight,
                      cluster=~pid), silent=TRUE)
      gv <- function(m,k="l_x") if (inherits(m,"try-error") ||
              !(k %in% names(coef(m)))) c(NA,NA,NA) else c(coef(m)[k], se(m)[k], pvalue(m)[k])
      cq <- gv(mq); cn <- gv(mn)     # NOT `a`/`n`: tibble() would mask `n`
      tibble(n_obs=nrow(g), n_hh=n_distinct(g$pid),
             e_quality_FE=cq[1], se_quality=cq[2], p_quality=cq[3],
             e_quantity_FE=cn[1], se_quantity=cn[2], p_quantity=cn[3],
             quality_share_FE=cq[1]/(cq[1]+cn[1]))
    }
    feres <- fe %>% group_by(product) %>% group_modify(~fefit(.x)) %>% ungroup()
    print(as.data.frame(feres %>% mutate(across(where(is.numeric), ~round(.x,3)))))
    write.csv(feres, file.path(TMPCSV, paste0(cc,"_12_household_FE.csv")),
              row.names=FALSE)
    cat("\nCompare these with the cross-sectional shares: if they differ a lot,\n",
        "the cross-section was picking up taste, not income.\n")
  } else cat("panel too thin for fixed effects\n")

  ####################### (C) HECKMAN WITH AN INSTRUMENT #####################
  cat("\n--- (C) selection, using livestock ownership as the exclusion ---\n")
  if (any(!is.na(d$own_rel))) {
    hk <- d %>% filter(welfare > 0, !is.na(own_rel)) %>%
      mutate(buys = as.integer(coalesce(qty_pur > 0 & uv > 0, FALSE)))
    hres <- hk %>% group_by(year, product) %>% group_modify(function(g, ...) {
      if (sum(g$buys) < 80 || n_distinct(g$own_rel) < 2) return(tibble())
      ## PERFECT SEPARATION: an empty cell in the 2x2 makes the probit diverge
      ## and report coefficients of order 1e14. Skip instead of printing noise.
      tab <- table(g$own_rel, g$buys)
      if (any(dim(tab) < 2) || any(tab < 10)) return(tibble())
      ## survey weights are not frequency weights; the first stage is estimated
      ## unweighted and used only to form the selection term.
      pr <- try(glm(buys ~ l_x + l_ae + own_rel, data=g,
                    family=binomial("probit")), silent=TRUE)
      if (inherits(pr,"try-error") || !isTRUE(pr$converged)) return(tibble())
      z  <- coef(summary(pr))
      if (abs(z["own_rel","Estimate"]) > 10) return(tibble())
      g$imr <- dnorm(predict(pr, g)) / pmax(pnorm(predict(pr, g)), 1e-6)
      s <- g %>% filter(buys == 1)
      m <- try(feols(log(qty_pur) ~ l_x + l_ae + imr | region, s,
                     weights=~weight, vcov="hetero"), silent=TRUE)
      if (inherits(m,"try-error")) return(tibble())
      if (!("imr" %in% names(coef(m)))) return(tibble())  # dropped -> unidentified
      tibble(first_stage_own = round(z["own_rel","Estimate"], 3),
             first_stage_p   = round(z["own_rel","Pr(>|z|)"], 4),
             e_quantity_corrected = unname(coef(m)["l_x"]),
             imr_coef = unname(coef(m)["imr"]),
             imr_p    = unname(pvalue(m)["imr"]))
    }) %>% ungroup()
    print(as.data.frame(hres %>% mutate(across(where(is.numeric), ~round(.x,3)))))
    write.csv(hres, file.path(TMPCSV, paste0(cc,"_13_heckman_instrumented.csv")),
              row.names=FALSE)
    cat("\nfirst_stage_own should be NEGATIVE and significant: owning the animal\n",
        "reduces the probability of buying. If it is, the exclusion has bite.\n")
  } else cat("no livestock data — skipped\n")

  ####################### richer descriptives ################################
  cat("\n--- participation by welfare quintile ---\n")
  q <- d %>% filter(welfare > 0) %>% group_by(year) %>%
    mutate(qt = ntile(welfare, 5)) %>% ungroup() %>%
    ## v21 (D14): a purchase whose unit does not convert is still a purchase
    mutate(buys = as.integer(coalesce(qty_pur > 0, FALSE) | coalesce(exp > 0, FALSE))) %>%
    group_by(product, qt) %>%
    summarise(participation = round(100*weighted.mean(buys, weight, na.rm=TRUE),1),
              .groups="drop") %>%
    pivot_wider(names_from=qt, values_from=participation, names_prefix="Q")
  print(as.data.frame(q))
  write.csv(q, file.path(TMPCSV, paste0(cc,"_14_participation_quintile.csv")),
            row.names=FALSE)

  p1 <- src %>% pivot_longer(c(pct_own, pct_gift, pct_purchased),
                             names_to="source", values_to="pct") %>%
    ggplot(aes(factor(year), pct, fill=source)) + geom_col() +
    facet_wrap(~product, nrow=1) +
    scale_fill_manual(values=c(pct_purchased="#4E79A7", pct_own="#59A14F",
                               pct_gift="#F28E2B")) +
    labs(title=paste0(cc, ": where animal-source food actually comes from"),
         x=NULL, y="% of quantity consumed", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_sources.png"))), p1, width=10, height=3.4, dpi=200)
}
message("\ndone -> ", RES_DIR, " and ", FIG)
###############################################################################

}


