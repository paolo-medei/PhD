###############################################################################
## PART 2d — BUILD MALAWI (IHS3 2010, IHS4 2016, IHS5 2019, IHS6 2024)
##
##  Malawi is one of the five ACT countries and the poorest of the set. Its
##  panel (IHPS 2010-13-16, IHPS 2024) ships WITHOUT a consumption aggregate,
##  so it has no income variable and cannot be used. The four national
##  Integrated Household Surveys are used instead: about 49,000 households,
##  each survey with its own aggregate. They are REPEATED CROSS-SECTIONS, not a
##  panel: Malawi enters every cross-sectional analysis but not the household
##  fixed-effects and permanent-income models (panel_ids() has no MWI branch).
##  IHS2 2004 is left out: different questionnaire and file structure.
##
##  TRAP M1  IHS3 2010 ships the food module twice, in Full_Sample/ (12,271
##           households) and Panel/ (the IHPS baseline subsample). Full_Sample
##           is read; the path hint says so.
##  TRAP M2  Every source (total, purchased, own, gift) has its OWN unit. 2010
##           adds a size letter to some codes ("9A", "9B", "9C" = small, medium,
##           large piece; "22A/B" sachets): priced like the plain code, the
##           letter is dropped.
##  TRAP M3  Units are converted by their metric meaning (kg, gram, litre,
##           millilitre) and, for chicken pieces and milk sachets and spoons,
##           by the World Bank's 2020 conversion table (kg per unit, by region;
##           a whole chicken weighs 1.27-1.48 kg). "Piece" of beef, goat or
##           pork is NOT converted: the table gives 0.036 kg in the North and
##           0.25 kg in the Centre and South for the same item, which is not a
##           measurement. Nor are the table's "other poultry" (509) pieces and
##           powdered-milk teaspoons, which the prices contradict, nor fresh
##           milk "in grams". "Other (specify)" is converted when its text
##           states a metric amount, a tray/crate (30) or dozen of eggs, a whole
##           (1.26 kg) or half chicken, or a milk sachet; fresh-milk packets
##           cost what sachets cost and are read as sachets (see oth_mw()).
##  TRAP M4  The 2010 aggregate has neither household size nor weight; they
##           come from the roster and the cover page. The 2024 aggregate has
##           no adult-equivalent scale, so Malawi uses household size
##           throughout (as Nigeria does): welfare = real annual consumption
##           per capita, adulteq = household size.
##  TRAP M6  Unit slips (grams typed as kilos, millilitres as litres): a
##           purchase priced above 10 times or below a tenth of the wave's
##           median for the product has its quantities flagged, as in Uganda
##           (flag_price_outliers(), 00_setup.R). 1-4% of chicken and
##           processed-milk purchases, under 1% elsewhere.
##  TRAP M5  Only three regions: the DISTRICT (about 30) is used as "region"
##           for the regional effects; the three-region code is kept only to
##           read the conversion table (2010 has no region variable: it is the
##           district code's hundreds digit).
###############################################################################
if (exists("RUN_MWI") && !RUN_MWI) message("PART 2d skipped") else
if (!length(list.files(ARCH_ROOT, pattern = "^MWI_20(10|16|19|24)", include.dirs = TRUE))) {
  message("PART 2d: no Malawi IHS archives (MWI_*.zip) found - Malawi skipped")
} else if (RUN_BUILD) {

WAVES_MW <- list(
  w1 = list(year=2010, hint="MWI_2010_IHS-III.*Full_Sample", agg="ihs3fc2M_consumption"),
  w2 = list(year=2016, hint="MWI_2016_IHS-IV",               agg="ihs4 consumption aggregate"),
  w3 = list(year=2019, hint="MWI_2019_IHS-V",                agg="ihs5_consumption_aggregate"),
  w4 = list(year=2024, hint="MWI_2024-2025_IHS-VI",          agg="ihs6_consumptionaggregates")
)
## a wave is built only if its archive is there
WAVES_MW <- WAVES_MW[sapply(WAVES_MW, function(C) !is.na(find_dta("hh_mod_g1", C$hint)) &&
                                            grepl(sub("\\.\\*.*", "", C$hint), find_dta("hh_mod_g1", C$hint)))]
rd_mw <- function(C, stem) {
  p <- find_dta(stem, C$hint)
  if (is.na(p) || !grepl(sub("\\.\\*.*", "", C$hint), p)) stop("missing ", stem, " for Malawi ", C$year)
  haven::read_dta(p)
}

ITEMS_MW <- tibble::tribble(
  ~item, ~product,         ~std,
   504,  "beef",           "kg",
   505,  "goat_sheep",     "kg",     # goat
   507,  "goat_sheep",     "kg",     # mutton
   506,  "pork",           "kg",
   508,  "poultry",        "kg",     # chicken
   509,  "poultry",        "kg",     # guinea fowl, doves
   501,  "eggs",           "piece",
   701,  "milk",           "litre",  # fresh milk
   702,  "milk_processed", "kg",     # powdered milk (as Nigeria's)
   902,  "coffee",         "kg"
)   # 503-515 fish, 705 chambiko, 706 yoghurt, 707 cheese, 82x vendor food: not used
MEAT_MW <- c("beef","goat_sheep","pork","poultry")

## the World Bank's 2020 food conversion table (kg per unit), if present.
## v23 (independent check): 509 "other poultry" is left out - a piece costs a
## tenth to a third of a chicken (doves, pigeons), yet the table gives it a
## chicken's weight; so is the powdered-milk TEASPOON (code 20), which the
## table makes heavier than the tablespoon (0.06-0.14 kg against 0.01).
cf_path <- find_dta("ihs_foodconversion_factor_2020", "MWI_2019")
CF_MW <- if (is.na(cf_path)) NULL else haven::read_dta(cf_path) %>%
  transmute(region3 = num(region), item = num(item_code), unit = trimws(as.character(unit_code)),
            factor = num(factor)) %>%
  filter(unit != "23", item %in% c(508, 701, 702), !(item == 702 & unit == "20"), !is.na(factor)) %>%
  group_by(region3, item, unit) %>% summarise(cf = mean(factor), .groups = "drop")

## "Other (specify)" (code 23). Converted only when the text states a metric
## amount (spelling variants and decimal commas included: "MILLITER", "GRAMM",
## "0,3 KILOGRAMMES"), a tray / crate (30) or dozen of eggs, a piece of egg,
## a whole or half chicken, or a sachet of milk (the table's value for the
## item). v23: fresh-milk PACKETS cost what sachets cost in every wave, so they
## are read as sachets - by analogy with Paolo's "Nice cup" decision (Uganda).
oth_mw <- function(o, item, std, sachet) {
  o  <- toupper(trimws(ifelse(is.na(o), "", as.character(o))))
  o  <- sub("[.]+$", "", gsub("([0-9]),([0-9])", "\\1.\\2", o))
  KG <- "(KGS?|KILOS?|KILOGRAMM?E?S?)"
  G  <- "(GS?|GRMS?|GRAMM?E?S?|GARAMS?)"
  ML <- "(MLS?|MIL|MILL?I?LIT(RE|ER)S?|MILL?IT(RE|ER)S?|MILITRES?|MILLIMETRES?|MILLIGRAMS?)"
  amt <- function(re) {
    x <- rep(NA_real_, length(o)); pat <- paste0("([0-9]+[.]?[0-9]*) ?", re, "\\b")
    hit <- grepl(pat, o, perl = TRUE)
    x[hit] <- suppressWarnings(as.numeric(sub(paste0("^.*?", pat, ".*$"), "\\1", o[hit], perl = TRUE)))
    x
  }
  kg <- amt(KG); g <- amt(G) / 1000; ml <- amt(ML) / 1000
  dplyr::case_when(
    std == "piece" & grepl("^(TRAY|TREY|TRY|CRATE|CRETE)S?$", o)              ~ 30,
    std == "piece" & o == "DOZEN"                                             ~ 12,
    std == "piece" & grepl("^(PIECE|PEACE|PEICE)S?( ?[(].*[)])?$", o)        ~ 1,
    item == 508 & grepl("^HALF", o) & grepl("CHICKEN|WHOLE", o)               ~ 0.63,
    item == 508 & grepl("WHOLE|FULL|^([0-9]+ )?CHICKENS?$", o) &
      !grepl("HALF|PIECES? OF", o)                                            ~ 1.26,
    std %in% c("kg","litre") & !is.na(kg)                                     ~ kg,
    std %in% c("kg","litre") & !is.na(g)                                      ~ g,
    std == "litre" & !is.na(ml)                                               ~ ml,
    std %in% c("kg","litre") & grepl(paste0("^HALF ", KG, "$"), o)            ~ 0.5,
    std %in% c("kg","litre") & grepl(paste0("^", KG, "$"), o)                 ~ 1,
    std == "kg" & grepl(paste0("^", G, "$"), o)                               ~ 1/1000,
    std == "kg" & grepl("^GARAM", o)                                          ~ 1/1000,  # "GARAMSACHET"
    std == "litre" & grepl(paste0("^", ML, "$"), o)                           ~ 1/1000,
    item %in% c(701, 702) & grepl("SA?T?CHET|SACHET", o)                      ~ sachet,
    item == 701 & grepl("^(SMALL )?PACKETS?( [(]SMALL[)]| UNSPECIFIED)?$", o) ~ sachet,
    TRUE ~ NA_real_)
}

conv_mw <- function(item, std, unit, oth, region3, ulab = NA) {
  ## TRAP M2: 2010 size letters ("9A", "22B") are priced like the plain code
  u <- sub("[A-Za-z]+$", "", trimws(as.character(unit)))
  tab <- function(uu) if (is.null(CF_MW)) rep(NA_real_, length(uu)) else
    CF_MW$cf[match(paste(region3, item, uu), paste(CF_MW$region3, CF_MW$item, CF_MW$unit))]
  t_u <- tab(u); t_sachet <- tab(rep("22", length(u)))
  ot <- oth_mw(oth, item, std, t_sachet)
  ## v23: 2016 tins coded 71-73 say their weight in the label ("TIN 100G")
  la <- toupper(ifelse(is.na(ulab), "", as.character(ulab)))
  la_g <- suppressWarnings(as.numeric(ifelse(grepl("[0-9] ?G\\b", la),
            sub("^.*?([0-9]+) ?G\\b.*$", "\\1", la, perl = TRUE), NA))) / 1000
  dplyr::case_when(
    is.na(u) | u == ""                                  ~ NA_real_,
    std == "piece" & u == "9"                           ~ 1,
    std %in% c("kg","litre") & u == "1"                 ~ 1,      # milk: kg = litre
    ## fresh milk "in grams" costs 4.9 times the litre price (2010): not converted
    std == "kg" & u == "18"                             ~ 1/1000,
    std == "litre" & u == "15"                          ~ 1,
    std == "litre" & u == "19"                          ~ 1/1000,
    u == "23"                                           ~ ot,
    std %in% c("kg","litre") & grepl("^TIN", la) & !is.na(la_g) ~ la_g,
    ## fresh-milk packets (codes 51, 60) cost what a sachet costs
    item == 701 & u %in% c("51", "60")                  ~ t_sachet,
    item %in% c(508, 701, 702) & !is.na(t_u)            ~ t_u,       # TRAP M3
    TRUE ~ NA_real_)
}

build_wave_mw <- function(w) {
  C <- WAVES_MW[[w]]
  f  <- rd_mw(C, "hh_mod_g1")
  cv <- rd_mw(C, "hh_mod_a_filt")
  ## cover: district as "region" (TRAP M5), three regions for the table
  ## v23: 2024 adds the Dzaleka refugee camp (camp = 1, 386 households): a
  ## separate sample with no consumption aggregate - dropped
  camp_hh <- if ("camp" %in% names(cv)) trimws(as.character(cv$case_id[num(cv$camp) %in% 1])) else character(0)
  dist <- num(if ("district" %in% names(cv)) cv$district else cv$hh_a01)
  cv <- tibble(hhid      = trimws(as.character(cv$case_id)),
               region    = as.character(dist),
               region3   = if ("region" %in% names(cv)) num(cv$region) else floor(dist / 100),
               urban     = ifelse(tolower(trimws(as.character(haven::as_factor(cv$reside)))) == "urban", "1", "0"),
               clusterid = trimws(as.character(cv$ea_id)),
               hhweight  = num(cv$hh_wgt)) %>% distinct(hhid, .keep_all = TRUE)

  f <- f %>% mutate(hhid = trimws(as.character(case_id)), item = num(hh_g02)) %>%
    filter(!hhid %in% camp_hh)
  hh_all <- unique(f$hhid)
  f <- f %>% inner_join(ITEMS_MW, by = "item") %>%
    left_join(cv %>% select(hhid, region3), by = "hhid")
  src <- function(q, u) {
    ov  <- intersect(paste0(u, c("_oth", "_os")), names(f))           # 2010: _os
    oth <- if (length(ov)) as.character(f[[ov[1]]]) else NA
    lv  <- paste0(u, "_label")
    ulab <- if (lv %in% names(f)) as.character(haven::as_factor(f[[lv]])) else NA
    num(f[[q]]) * conv_mw(f$item, f$std, haven::zap_labels(f[[u]]), oth, f$region3, ulab)
  }
  f$qty_std   <- src("hh_g03a", "hh_g03b")
  f$purch_std <- src("hh_g04a", "hh_g04b")
  f$own_std   <- src("hh_g06a", "hh_g06b")
  f$gift_std  <- src("hh_g07a", "hh_g07b")
  f$exp       <- num(f$hh_g05)
  ## v23: any quantity or spending means the item was consumed
  f$consumed  <- as.numeric(num(f$hh_g01) == 1 |
                            rowSums(cbind(num(f$hh_g03a), num(f$hh_g04a), num(f$hh_g06a),
                                          num(f$hh_g07a), f$exp) > 0, na.rm = TRUE) > 0)
  ## TRAP M6. Each source has its own unit here, so a mispriced PURCHASE
  ## empties the purchased quantity only (Uganda: one unit for all sources)
  p0 <- f$purch_std
  f <- flag_price_outliers(f, all_sources = FALSE)
  ## ... and to any other source recorded in the SAME unit and text as the
  ## purchase (270 of 279 trimmed rows: the total repeats the purchase's unit)
  key <- function(b) { ov <- intersect(paste0(b, c("_oth", "_os")), names(f))
    paste(trimws(as.character(haven::zap_labels(f[[b]]))), if (length(ov)) toupper(trimws(f[[ov[1]]])) else "") }
  kp  <- key("hh_g04b")
  cut <- !is.na(p0) & is.na(f$purch_std)
  fac <- ifelse(!is.na(p0) & !is.na(f$purch_std) & p0 > 0, f$purch_std / p0, 1)
  for (s in list(c("qty_std", "hh_g03b"), c("own_std", "hh_g06b"), c("gift_std", "hh_g07b"))) {
    same <- key(s[2]) == kp
    f[[s[1]]][same & cut] <- NA
    f[[s[1]]][same & !cut] <- f[[s[1]]][same & !cut] * fac[same & !cut]
  }
  f <- f %>% select(hhid, product, std, consumed, qty_std, purch_std, own_std, gift_std, exp)

  agg_by <- function(df, prod_col) {
    df %>%
      mutate(.unconv   = as.integer(exp > 0 & (is.na(purch_std) | purch_std <= 0)),
             .exp_conv = ifelse(is.na(purch_std) | purch_std <= 0, NA_real_, exp)) %>%
      group_by(hhid, product = .data[[prod_col]], std) %>%
      summarise(consumed  = suppressWarnings(max(consumed, na.rm=TRUE)),
                qty_std   = sum(qty_std,   na.rm=TRUE),
                purch_std = sum(purch_std, na.rm=TRUE),
                own_std   = sum(own_std,   na.rm=TRUE),
                gift_std  = sum(gift_std,  na.rm=TRUE),
                exp       = sum(exp,       na.rm=TRUE),
                exp_conv  = sum(.exp_conv, na.rm=TRUE),
                unconv    = as.integer(any(.unconv == 1, na.rm=TRUE)),
                .groups="drop") %>%
      mutate(consumed = ifelse(is.finite(consumed), consumed, NA_real_),
             across(c(qty_std, purch_std, own_std, gift_std, exp, exp_conv),
                    ~ ifelse(.x == 0, NA_real_, .x)))
  }
  B <- agg_by(f, "product") %>% mutate(track = "B")
  A <- f %>% mutate(prodA = ifelse(product %in% MEAT_MW, "meat_agg", product)) %>%
    filter(prodA != "milk_processed") %>% agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)
  prods <- bind_rows(
    ITEMS_MW %>% distinct(product, std) %>% mutate(track = "B"),
    ITEMS_MW %>% mutate(product = ifelse(product %in% MEAT_MW, "meat_agg", product)) %>%
      filter(product != "milk_processed") %>% distinct(product, std) %>% mutate(track = "A"))
  out <- tidyr::crossing(hhid = hh_all, prods) %>%
    left_join(out, by = c("hhid", "product", "std", "track")) %>%
    mutate(consumed = ifelse(is.na(consumed), 0, consumed),
           unconv   = ifelse(is.na(unconv), 0L, unconv))

  ## roster: size and demographics (every listed member, as for Tanzania)
  r  <- rd_mw(C, "hh_mod_b")
  sx <- tolower(trimws(as.character(haven::as_factor(r$hh_b03))))
  dem <- r %>% mutate(hhid = trimws(as.character(case_id)), .age = num(hh_b05a),
                      .fem = as.numeric(sx == "female"), .head = num(hh_b04) %in% 1) %>%
    group_by(hhid) %>%
    summarise(n_mem         = n(),
              share_child   = mean(.age <  15, na.rm=TRUE),
              share_elderly = mean(.age >= 60, na.rm=TRUE),
              head_age      = .age[.head][1],             # one head: the first listed
              head_female   = .fem[.head][1], .groups="drop") %>%
    mutate(across(c(share_child, share_elderly), ~ ifelse(is.nan(.x), NA_real_, .x)))

  ## welfare (TRAP M4): real annual consumption per capita
  a <- rd_mw(C, C$agg) %>% mutate(hhid = trimws(as.character(case_id))) %>%
    distinct(hhid, .keep_all = TRUE)
  a <- a %>% transmute(hhid, rexp = num(rexpagg),
                       hhsize = if ("hhsize" %in% names(a)) num(hhsize) else NA_real_)

  ## roster variables for every household, with or without an aggregate
  out %>% left_join(dem, by = "hhid") %>% left_join(a, by = "hhid") %>%
    mutate(hhsize  = ifelse(is.na(hhsize) & !is.na(rexp), n_mem, hhsize),
           welfare = rexp / hhsize, adulteq = hhsize) %>%
    select(-rexp, -n_mem) %>%
    left_join(cv %>% select(-region3), by = "hhid") %>%
    mutate(country = "MWI", wave = w, year = C$year, strataid = NA_character_,
           uv = ifelse(purch_std > 0 & exp_conv > 0, exp_conv / purch_std, NA_real_))
}

panel_MW <- map_dfr(names(WAVES_MW), build_wave_mw)
write.csv(panel_MW, file.path(OUT_DIR, "panel_MWI.csv"), row.names=FALSE)

###############################################################################
## VALIDATION GATES
###############################################################################
cat("\n===== MWI GATE 1: households in the food module vs the consumption aggregate =====\n")
for (w in names(WAVES_MW)) {
  C <- WAVES_MW[[w]]
  n_agg <- nrow(rd_mw(C, C$agg))
  p <- panel_MW %>% filter(wave == w) %>% distinct(hhid, welfare)
  cat(sprintf("   %s %d: food module %6d  aggregate %6d  with welfare %6d\n",
              w, C$year, nrow(p), n_agg, sum(!is.na(p$welfare))))
}
cat("\n===== MWI GATE 2: median weekly purchase among buyers =====\n")
print(panel_MW %>% filter(track=="B", purch_std > 0) %>% group_by(product, std, year) %>%
        summarise(m = round(median(purch_std), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== MWI GATE 3: median unit value (MK) - must track inflation =====\n")
print(panel_MW %>% filter(track=="B", uv > 0) %>% group_by(product, year) %>%
        summarise(m = round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== MWI GATE 4: % of households buying (spending > 0) =====\n")
print(panel_MW %>% filter(track=="B") %>% group_by(product, year) %>%
        summarise(p = round(100*mean(coalesce(exp, 0) > 0), 1), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())
cat("\n===== MWI GATE 5: purchases whose unit does not convert (share of buyers) =====\n")
print(panel_MW %>% filter(track=="B", coalesce(exp, 0) > 0) %>% group_by(product, year) %>%
        summarise(flagged = round(mean(unconv), 3), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=flagged) %>% as.data.frame())
cat("\n===== MWI GATE 6: weights, clusters, demographics present =====\n")
print(panel_MW %>% distinct(year, hhid, hhweight, clusterid, head_age, welfare) %>% group_by(year) %>%
        summarise(weight = round(mean(!is.na(hhweight)), 3), cluster = round(mean(!is.na(clusterid)), 3),
                  head_age = round(mean(!is.na(head_age)), 3), welfare = round(mean(!is.na(welfare)), 3),
                  .groups="drop") %>% as.data.frame())
cat("\nrows:", nrow(panel_MW), " households:", n_distinct(paste(panel_MW$wave, panel_MW$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_MWI.csv"), "\n")
}
###############################################################################
