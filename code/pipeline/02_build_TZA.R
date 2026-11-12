###############################################################################
## PART 2 — BUILD TANZANIA (waves 2008, 2010, 2012, 2014, 2020)
###############################################################################
if (RUN_BUILD) {
###############################################################################
## WAVE CONFIGURATION — verified, traps encoded
##
## TRAP 1  The section letter MOVES: K1 (2008, 2010) -> J1 (2012, 2014)
##         -> JA1 (2020). Identified from the question text, which is identical
##         in all five waves.
## TRAP 2  In 2020 the sample is SPLIT, not subsampled: hh_sec_ja1 covers 4,290
##         households and hh_sec_j1 a DISJOINT 419 (overlap = 0, union = 4,709 =
##         the consumption aggregate). Only ja1 is used, so 2020 covers 91% of
##         the wave; the 419 are excluded because their module differs.
## TRAP 3  Suffix _1 is the UNIT and _2 the QUANTITY. Reading _1 as the quantity
##         turns every purchase into a number between 1 and 5.
## TRAP 4  The household id is renamed every wave.
###############################################################################
WAVES_TZ <- list(
  w1 = list(year=2008, zipyr="2008", food="SEC_K1",     style="old",
            hhid="hhid",    agg="TZY1.HH.Consumption", welfare="expmR",
            ## TRAP 7: SEC_A is EA-level and has no hhid; SEC_A_T is the household cover
            cover="SEC_A_T", itemvar="skcode",
            roster="SEC_B_C_D_E1_F_G1_U", age="sbq4", sex="sbq2", rel="sbq5"),
  w2 = list(year=2010, zipyr="2010", food="HH_SEC_K1",  style="new", pre="hh_k",
            yn="hh_k01_2",   # TRAP 5: 2010 calls it hh_k01_2, not hh_k01
            hhid="y2_hhid", agg="TZY2.HH.Consumption", welfare="expmR",
            cover="HH_SEC_A", itemvar="itemcode",
            roster="HH_SEC_B", age="hh_b04", sex="hh_b02", rel="hh_b05"),
  w3 = list(year=2012, zipyr="2012", food="HH_SEC_J1",  style="new", pre="hh_j",
            hhid="y3_hhid", agg="ConsumptionNPS3",     welfare="expmR",
            cover="HH_SEC_A", itemvar="itemcode",
            roster="HH_SEC_B", age="hh_b04", sex="hh_b02", rel="hh_b05"),
  w4 = list(year=2014, zipyr="2014", food="hh_sec_j1",  style="new", pre="hh_j",
            hhid="y4_hhid", agg="consumptionNPS4",     welfare="expmR",
            cover="hh_sec_a", itemvar="itemcode",
            roster="hh_sec_b", age="hh_b04", sex="hh_b02", rel="hh_b05"),
  w5 = list(year=2020, zipyr="2020", food="hh_sec_ja1", style="new", pre="hh_ja",
            hhid="y5_hhid", agg="consumption_real_y5", welfare="expmR_pae",
            cover="hh_sec_a", itemvar="itemcode",
            roster="hh_sec_b", age="hh_b04", sex="hh_b02", rel="hh_b05")
)

###############################################################################
## ITEMS_TZ — codes are STABLE 2008-2020, except that 2020 splits poultry.
##  Standard unit per product: meat and coffee in KG, milk in LITRES,
##  eggs in PIECES. Unit values are comparable across households within a
##  product, never across products.
###############################################################################
ITEMS_TZ <- tibble::tribble(
  ~item, ~product,      ~std,
   801,  "goat_sheep",  "kg",
   802,  "beef",        "kg",
   803,  "pork",        "kg",
   804,  "poultry",     "kg",
  8041,  "poultry",     "kg",     # 2020 splits 804 into chicken ...
  8042,  "poultry",     "kg",     # ... and other poultry
   807,  "eggs",        "piece",
   901,  "milk",        "litre",
   902,  "cheese",      "kg",     # "milk products (cream, cheese, yoghurt)"
  1102,  "coffee",      "kg"      # NB: label is "COFFEE AND COCOA" - impure
)
MEAT_TZ <- c("beef","goat_sheep","pork","poultry")

## TRAP 6  Eggs are reported in PIECES in 2008-2014 but mostly in GRAMS in
##  2020 (200 of 394 purchases). Accepting only "pieces" made egg participation
##  collapse from 12.3% to 3.7% - a measurement artefact that looks like a
##  behavioural change.
##  The conversion is NOT assumed: 425 households in 2020 reported eggs in
##  pieces AND gave a direct weight (hh_ja02b_*), giving a median of
##  55 g per egg (IQR 50-66). That figure is the survey calibrating itself.
GRAMS_PER_EGG <- 55

## unit code -> multiplier into the product's standard unit.
## Codes 6-20 are local units (heap, bunch, spoon, bucket, ...) with no
## conversion factor: those rows stay NA and are FLAGGED, never guessed.
conv_tz <- function(unit, std) {
  u <- num(unit)
  dplyr::case_when(
    std == "kg"    & u == 1 ~ 1,
    std == "kg"    & u == 2 ~ 1/1000,
    std == "litre" & u == 3 ~ 1,
    std == "litre" & u == 4 ~ 1/1000,
    std == "litre" & u == 1 ~ 1,               # milk occasionally reported in kg
    std == "litre" & u == 2 ~ 1/1000,
    std == "piece" & u == 5 ~ 1,               # already pieces
    std == "piece" & u == 2 ~ 1/GRAMS_PER_EGG, # grams -> pieces
    std == "piece" & u == 1 ~ 1000/GRAMS_PER_EGG,
    ## v21 (D6, decided 12 Nov 2026): in 2020, 34 egg purchases carry unit 20
    ## "OTHER (SPECIFY)" at a median 350 TSh per unit - exactly the price per
    ## egg bought in pieces - so they are read as pieces. Only eggs, 2020.
    std == "piece" & u == 20 ~ 1,
    TRUE ~ NA_real_)
}

###############################################################################
## BUILD
###############################################################################
build_wave_tz <- function(w) {
  C <- WAVES_TZ[[w]]
  f <- rd_tz(C$zipyr, C$food)

  if (C$style == "old") {                       # 2008 uses skq* names
    v <- list(yn="skq1", q_tot="skq2_amount", u_tot="skq2_meas",
              q_pur="skq3_amount", u_pur="skq3_meas", spend="skq4",
              q_own="skq5_amount", u_own="skq5_meas",
              q_gif="skq6_amount", u_gif="skq6_meas")
  } else {
    p <- C$pre
    v <- list(yn=if (!is.null(C$yn)) C$yn else paste0(p,"01"),
              q_tot=paste0(p,"02_2"), u_tot=paste0(p,"02_1"),
              q_pur=paste0(p,"03_2"), u_pur=paste0(p,"03_1"),
              spend=paste0(p,"04"),
              q_own=paste0(p,"05_2"), u_own=paste0(p,"05_1"),
              q_gif=paste0(p,"06_2"), u_gif=paste0(p,"06_1"))
  }

  ## fail loudly and specifically if a wave renamed something
  miss <- setdiff(c(unlist(v), C$itemvar, C$hhid), names(f))
  if (length(miss)) stop("wave ", w, " (", C$year, "): missing column(s) in ",
                         C$food, ": ", paste(miss, collapse=", "),
                         "\n   available: ", paste(names(f), collapse=", "))

  f <- f %>%
    mutate(item = num(.data[[C$itemvar]]),
           hhid = as.character(.data[[C$hhid]])) %>%
    inner_join(ITEMS_TZ, by="item")

  g <- function(q, u) num(f[[q]]) * conv_tz(f[[u]], f$std)
  f$qty_std   <- g(v$q_tot, v$u_tot)
  f$purch_std <- g(v$q_pur, v$u_pur)
  f$own_std   <- g(v$q_own, v$u_own)
  f$gift_std  <- g(v$q_gif, v$u_gif)
  f$exp       <- num(f[[v$spend]])
  f$consumed  <- as.numeric(num(f[[v$yn]]) == 1)

  f <- f %>% select(hhid, product, std, consumed,
                    qty_std, purch_std, own_std, gift_std, exp)

  ## a component with spend but no convertible quantity would inflate the unit
  ## value, so its spend is excluded from the matched total (see Ethiopia).
  agg_by <- function(df, prod_col) {
    df %>%
      mutate(.unconv   = as.integer(exp > 0 & is.na(purch_std)),
             .exp_conv = ifelse(is.na(purch_std), NA_real_, exp)) %>%
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

  B <- agg_by(f, "product") %>% mutate(track = "B")          # disaggregated
  A <- f %>%                                                  # meat pooled,
    mutate(prodA = ifelse(product %in% MEAT_TZ, "meat_agg", product)) %>%
    filter(prodA != "cheese") %>%
    agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)

  ## welfare, demographics, geography
  a <- rd_tz(C$zipyr, C$agg) %>% mutate(hhid = as.character(.data[[C$hhid]]))
  keep <- intersect(c("adulteq","hhsize","urban","region","hhweight",
                      C$welfare), names(a))
  a <- a %>% select(hhid, all_of(keep)) %>% rename(welfare = !!C$welfare)
  ## v21 (D3): expmR is the HOUSEHOLD total ("Total consumption, annual, real");
  ## only 2020's expmR_pae is per adult equivalent. Put 2008-2014 on the same
  ## footing, as in Ethiopia (nom_totcons_aeq).
  if (C$welfare == "expmR") a <- a %>% mutate(welfare = welfare / pmax(adulteq, 1))
  if (!"hhweight" %in% names(a)) a$hhweight <- NA_real_

  ## demographics — the SAME controls the Ethiopia build supplies, so the two
  ## countries are estimated on comparable specifications
  rr <- try(rd_tz(C$zipyr, C$roster), silent=TRUE)
  if (!inherits(rr, "try-error") &&
      all(c(C$age, C$sex, C$rel) %in% names(rr))) {
    idr <- if (C$hhid %in% names(rr)) C$hhid else names(rr)[grepl("hhid", names(rr))][1]
    dem <- rr %>%
      mutate(hhid   = as.character(.data[[idr]]),
             .age   = num(.data[[C$age]]),
             .fem   = as.numeric(num(.data[[C$sex]]) == 2),
             .head  = as.numeric(num(.data[[C$rel]]) == 1)) %>%
      group_by(hhid) %>%
      summarise(share_child   = mean(.age <  15, na.rm=TRUE),
                share_elderly = mean(.age >= 60, na.rm=TRUE),
                head_age      = mean(.age[.head == 1], na.rm=TRUE),
                head_female   = mean(.fem[.head == 1], na.rm=TRUE),
                .groups="drop")
    a <- a %>% left_join(dem, by="hhid")
  }

  ## cluster + stratum for design-based inference and cluster prices
  cl <- try(rd_tz(C$zipyr, C$cover), silent=TRUE)
  if (!inherits(cl, "try-error")) {
    idc <- if (C$hhid %in% names(cl)) C$hhid else names(cl)[grepl("hhid", names(cl))][1]
    ## 2008 names the primary sampling unit ea_id, later waves clusterid
    if (!"clusterid" %in% names(cl) && "ea_id" %in% names(cl))
      cl$clusterid <- cl$ea_id
    ## v21 (D4): 2012 keeps its weight (y3_weight) in the cover file only
    kc  <- intersect(c("clusterid","strataid","y3_weight"), names(cl))
    if (!is.na(idc) && length(kc)) {
      cl <- cl %>% mutate(hhid = as.character(.data[[idc]])) %>%
        select(hhid, all_of(kc)) %>% distinct(hhid, .keep_all=TRUE)
      a <- a %>% left_join(cl, by="hhid")
      if ("y3_weight" %in% names(a)) {
        a$hhweight <- ifelse(is.na(a$hhweight), num(a$y3_weight), a$hhweight)
        a$y3_weight <- NULL
      }
    }
  }
  if (!"clusterid" %in% names(a)) a$clusterid <- NA
  if (!"strataid"  %in% names(a)) a$strataid  <- NA

  out %>% left_join(a, by="hhid") %>%
    mutate(country="TZA", wave=w, year=C$year,
           uv = ifelse(purch_std > 0 & exp_conv > 0, exp_conv / purch_std, NA_real_),
           across(c(hhid, region, urban, clusterid, strataid), as.character))
}

panel_TZ <- map_dfr(names(WAVES_TZ), build_wave_tz)
write.csv(panel_TZ, file.path(OUT_DIR, "panel_TZA.csv"), row.names=FALSE)

###############################################################################
## VALIDATION GATES
###############################################################################
cat("\n===== GATE 1: household counts vs the consumption aggregate =====\n")
for (w in names(WAVES_TZ)) {
  C <- WAVES_TZ[[w]]
  n_agg <- rd_tz(C$zipyr, C$agg) %>% pull(!!C$hhid) %>% unique() %>% length()
  n_pan <- panel_TZ %>% filter(wave == w) %>% pull(hhid) %>% unique() %>% length()
  msg <- if (n_pan == n_agg) "OK"
         else if (n_pan >  n_agg) "panel_TZ > aggregate: food module covers households the aggregate drops (welfare will be NA)"
         else "panel_TZ < aggregate: 2020 sample split, the 419 hh_sec_j1 households are excluded by design"
  cat(sprintf("   %s %d: panel_TZ=%6d  aggregate=%6d  %s\n", w, C$year, n_pan, n_agg, msg))
}

cat("\n===== GATE 2: median weekly purchase among buyers (plausible?) =====\n")
print(panel_TZ %>% filter(track=="B", purch_std > 0) %>%
        group_by(product, std, year) %>%
        summarise(m = round(median(purch_std), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== GATE 3: median unit value (TSH) — must track inflation =====\n")
print(panel_TZ %>% filter(track=="B", uv > 0) %>%
        group_by(product, year) %>%
        summarise(m = round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== GATE 4: participation, % of households buying =====\n")
print(panel_TZ %>% filter(track=="B") %>%
        group_by(product, year) %>%
        summarise(p = round(100*mean(!is.na(purch_std) & purch_std > 0), 1),
                  .groups="drop") %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())

cat("\n===== GATE 5: unconvertible local units (flagged, not guessed) =====\n")
print(panel_TZ %>% filter(track=="B") %>% group_by(year) %>%
        summarise(flagged = round(mean(unconv, na.rm=TRUE), 3), .groups="drop") %>%
        as.data.frame())

cat("\n===== GATE 6: cluster identifiers present? =====\n")
print(panel_TZ %>% group_by(year) %>%
        summarise(with_cluster = round(mean(!is.na(clusterid)), 2), .groups="drop") %>%
        as.data.frame())

cat("\nrows:", nrow(panel_TZ), " households:", length(unique(panel_TZ$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_TZA.csv"), "\n")
###############################################################################

}


