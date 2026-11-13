###############################################################################
## PART 1 — BUILD ETHIOPIA (waves 2011, 2013, 2015, 2018, 2021)
###############################################################################
if (RUN_BUILD) {
###############################################################################
## WAVE CONFIGURATION — all verified, all traps encoded
##
## TRAP 1  Section numbering SWAPS. Waves 1-3: food is sect5a, sect6a is
##         NON-food monthly spending. Waves 4-5: food is sect6a, and sect5a
##         becomes the SAVINGS module. Verified from the question text.
## TRAP 2  Household id. `household_id` is the WAVE-1 id and repeats for
##         split-off households. Waves 2-3 must use `household_id2`
##         (5,262 vs 3,777 unique in 2013 -> 28% of the sample).
## TRAP 3  Unit key for the conversion table. Wave 2's reported unit code
##         contains values absent from Food_CF_Wave2; the survey ships a
##         dedicated `_cf_unit` column. Without it, median weekly milk
##         purchase comes out at 1,194 litres instead of 2.0.
###############################################################################
WAVES_ET <- list(
  w1 = list(year=2011, food="sect5a_hh_w1", pre="hh_s5aq", sep="_",
            itemvar="hh_s5aq00", cf="Food_CF_Wave1", weight="pw",
            hhid="household_id",  unitkey="b",
            cover="sect_cover_hh_w1", agg="cons_agg_w1", roster="sect1_hh_w1",
            age="hh_s1q04_a", sex="hh_s1q03", rel="hh_s1q02",
            price="sect10b1_com_w1", p_item="cs10b1q07_b", p_unit="cs10b1q07_d",
            p_val="cs10b1q07_f1",
            harv="sect9_ph_w1", harv_crop="crop_code",
            sale="sect12_ph_w1", sale_crop="crop_code"),
  w2 = list(year=2013, food="sect5a_hh_w2", pre="hh_s5aq", sep="_",
            itemvar="hh_s5aq00", cf="Food_CF_Wave2", weight="pw2",
            hhid="household_id2", unitkey="cf_unit",
            cover="sect_cover_hh_w2", agg="cons_agg_w2", roster="sect1_hh_w2",
            age="hh_s1q04_a", sex="hh_s1q03", rel="hh_s1q02",
            price="sect10a2_com_w2", p_item="cs10a2q02", p_unit="cs10a2q03_a",
            p_val="cs10a2q05",
            harv="sect9_ph_w2", harv_crop="crop_code",
            sale="sect12_ph_w2", sale_crop="crop_code"),
  w3 = list(year=2015, food="sect5a_hh_w3", pre="hh_s5aq", sep="_",
            itemvar="item_cd", cf="Food_CF_Wave3", weight="pw_w3",
            hhid="household_id2", unitkey="b",
            cover="sect_cover_hh_w3", agg="cons_agg_w3", roster="sect1_hh_w3",
            age="hh_s1q04a", sex="hh_s1q03", rel="hh_s1q02",
            price="sect10a2_com_w3", p_item="cs10a2q02", p_unit="cs10a2q03_a",
            p_val="cs10a2q05",
            harv="sect9_ph_w3", harv_crop="crop_code",
            sale="sect12_ph_w3", sale_crop="crop_code"),
  w4 = list(year=2018, food="sect6a_hh_w4", pre="s6aq", sep="",
            itemvar="item_cd", cf="Food_CF_Wave4", weight="pw_w4",
            hhid="household_id",  unitkey="b",
            cover="sect_cover_hh_w4", agg="cons_agg_w4", roster="sect1_hh_w4",
            age="s1q03a", sex="s1q02", rel="s1q01",
            price="sect10b_com_w4", p_item="cs10bq02", p_unit="cs10bq03",
            p_val="cs10bq05",
            harv="sect9_ph_w4", harv_crop="s9q00b",
            sale="sect11_ph_w4", sale_crop="s11q01"),
  w5 = list(year=2021, food="sect6a_hh_w5", pre="s6aq", sep="",
            itemvar="item_cd", cf="food_cf_wave5", weight="pw_w5",
            hhid="household_id",  unitkey="b",
            cover="sect_cover_hh_w5", agg="cons_agg_w5", roster="sect1_hh_w5",
            age="s1q03a", sex="s1q02", rel="s1q01",
            price="sect10b_com_w5", p_item="cs10bq02", p_unit="cs10bq03",
            p_val="cs10bq05",
            harv="sect9_ph_w5", harv_crop="s9q00b",
            sale="sect11_ph_w5", sale_crop="s11q01b")
)

###############################################################################
## ITEM MAPS
##  Waves 1-2 report MEAT_ET AS ONE AGGREGATED ITEM (code 18); beef / goat /
##  poultry appear only from wave 3. Hence the two tracks:
##    A  meat_agg + milk + cheese + eggs + coffee   -> all 5 waves
##    B  fully disaggregated                        -> waves 3-5 only
##
##  The conversion table always speaks the OLD coding (milk 19, coffee 24,
##  beef 181). Waves 4-5 code consumption as 701..801, so a crosswalk is
##  needed; it was built by EXACT LABEL MATCH, not by assumption
##  (701 "Goat & mutton meat" == 180 "Goat & mutton meat").
###############################################################################
map_old <- tibble::tribble(~item, ~product,     ~cf_item,
                            18,   "meat_agg",    18,
                            19,   "milk",        19,
                            20,   "cheese",      20,
                            21,   "eggs",        21,
                            24,   "coffee",      24)
map_w3  <- tibble::tribble(~item, ~product,     ~cf_item,
                           180,   "goat_sheep", 180,
                           181,   "beef",       181,
                           182,   "poultry",    182,
                           183,   "fish",       183,
                            19,   "milk",        19,
                            20,   "cheese",      20,
                            21,   "eggs",        21,
                            24,   "coffee",      24)
map_new <- tibble::tribble(~item, ~product,     ~cf_item,
                           701,   "goat_sheep", 180,
                           702,   "beef",       181,
                           703,   "poultry",    182,
                           704,   "fish",       183,
                           705,   "milk",        19,
                           706,   "cheese",      20,
                           709,   "eggs",        21,
                           801,   "coffee",      24)
ITEMMAP_ET <- list(w1=map_old, w2=map_old, w3=map_w3, w4=map_new, w5=map_new)
MEAT_ET <- c("beef","goat_sheep","poultry")   # fish excluded: item 18 is "Meat"

###############################################################################
## COMMUNITY MARKET PRICES  (item 19 milk, 20 EGGS, 23 coffee in this module)
##  These are EA-level observed market prices: exogenous to the household's
##  own quality choice, unlike a unit value.
##  TRAP 4  Prices are quoted in many units, including the "sini" — a cup of
##          BREWED coffee. Pooling units puts coffee at 10 Birr instead of 360.
##          The unit is therefore selected BY LABEL, and the survey's labels
##          contain typos ("Littere", "Pices"), so matching is on stems.
###############################################################################
CMAP <- tibble::tribble(~pitem, ~product,  19,"milk",  20,"eggs",  23,"coffee")
unit_ok <- function(product, lab) {
  lab <- tolower(ifelse(is.na(lab), "", lab))
  dplyr::case_when(
    ## v21: 2013 spells it "Liter" - "litt|litre" lost every milk price that year
    product == "milk"   ~ (str_detect(lab,"lit") & !str_detect(lab,"mil")),
    product == "eggs"   ~ str_detect(lab,"pice|piece|number"),
    product == "coffee" ~ str_detect(lab,"kilogram") | str_trim(lab) == "kg",
    TRUE ~ FALSE)
}

###############################################################################
## BUILDERS
###############################################################################
num <- function(x) suppressWarnings(as.numeric(x))

build_food_et <- function(w) {
  C <- WAVES_ET[[w]]; p <- C$pre; s <- C$sep; uk <- C$unitkey
  f  <- rd_et(C$food)
  cf <- rd_et(C$cf) %>% filter(!is.na(mean_cf_nat)) %>%
        group_by(item_cd, unit_cd) %>%
        summarise(cfac = mean(mean_cf_nat, na.rm=TRUE), .groups="drop")

  f <- f %>%
    mutate(item = num(.data[[C$itemvar]]),
           hhid = as.character(.data[[C$hhid]])) %>%
    inner_join(ITEMMAP_ET[[w]], by="item")

  # quantity + unit -> kilograms, via the conversion table
  tokg <- function(df, qv, uv_) {
    df %>% mutate(.q = num(.data[[qv]]), .u = num(.data[[uv_]])) %>%
      left_join(cf, by=c("cf_item"="item_cd", ".u"="unit_cd")) %>%
      mutate(.kg = .q * cfac) %>% pull(.kg)
  }
  f$qty_kg   <- tokg(f, paste0(p,"02",s,"a"), paste0(p,"02",s,uk))
  f$purch_kg <- tokg(f, paste0(p,"03",s,"a"), paste0(p,"03",s,uk))
  f$own_kg   <- tokg(f, paste0(p,"05",s,"a"), paste0(p,"05",s,uk))
  f$gift_kg  <- tokg(f, paste0(p,"06",s,"a"), paste0(p,"06",s,uk))
  f$exp      <- num(f[[paste0(p,"04")]])
  f$consumed <- as.numeric(num(f[[paste0(p,"01")]]) == 1)

  f <- f %>% select(hhid, product, consumed, qty_kg, purch_kg, own_kg, gift_kg, exp)

  ## Track B: disaggregated (waves 3-5 only)
  B <- f %>% mutate(track = "B",
                    exp_conv = ifelse(is.na(purch_kg) | purch_kg <= 0, NA_real_, exp),
                    unconv   = as.integer(exp > 0 & (is.na(purch_kg) | purch_kg <= 0)))
  ## Track A: meat summed so the five waves line up.
  ## TRAP 5  Summing treats a missing kilo as zero, so spend would be counted
  ##         while quantity is not, inflating the unit value. Flag it instead.
  ## TRAP 5  Two things go wrong when meat components are summed.
  ##  (a) max(.unconv) WITHOUT na.rm returns NA as soon as one component is
  ##      missing - i.e. nearly always, since few households buy beef AND goat
  ##      AND poultry. Filtering on unconv==0 then silently deleted meat from
  ##      waves 3-5 (1,077 buyers in 2015 collapsed to 6).
  ##  (b) A component with spend but no convertible kilo would add to the
  ##      numerator of the unit value and nothing to the denominator. So the
  ##      spend used for the unit value sums ONLY the components that converted.
  A <- f %>%
    mutate(product = ifelse(product %in% MEAT_ET, "meat_agg", product)) %>%
    filter(product != "fish") %>%
    mutate(.unconv  = as.integer(exp > 0 & (is.na(purch_kg) | purch_kg <= 0)),
           .exp_conv = ifelse(is.na(purch_kg) | purch_kg <= 0, NA_real_, exp)) %>%
    group_by(hhid, product) %>%
    summarise(consumed = suppressWarnings(max(consumed, na.rm=TRUE)),
              qty_kg   = sum(qty_kg,   na.rm=TRUE),
              purch_kg = sum(purch_kg, na.rm=TRUE),
              own_kg   = sum(own_kg,   na.rm=TRUE),
              gift_kg  = sum(gift_kg,  na.rm=TRUE),
              exp      = sum(exp,       na.rm=TRUE),
              exp_conv = sum(.exp_conv, na.rm=TRUE),
              unconv   = as.integer(any(.unconv == 1, na.rm=TRUE)),
              .groups="drop") %>%
    mutate(track = "A",
           consumed = ifelse(is.finite(consumed), consumed, NA_real_),
           across(c(qty_kg, purch_kg, own_kg, gift_kg, exp, exp_conv),
                  ~ ifelse(.x == 0, NA_real_, .x)))

  if (w %in% c("w3","w4","w5")) bind_rows(A, B) else A
}

build_demog_et <- function(w) {
  C <- WAVES_ET[[w]]
  ## v21 (D15): from wave 2 the roster also lists people who have LEFT the
  ## household ("Is [NAME] still a member?" = No): 2,373 / 4,597 / 784 / 2,568
  ## rows in 2013-2021. They were counted in the shares and could be the head.
  ## Waves 2-3 also record a corrected age and sex, used where given.
  still <- c(w2 = "hh_s1q04c", w3 = "hh_s1q04c", w4 = "s1q05", w5 = "s1q05")[w]
  r <- rd_et(C$roster)
  if (!is.na(still) && still %in% names(r))
    r <- r %>% filter(is.na(num(.data[[still]])) | num(.data[[still]]) != 2)
  age_c <- if ("hh_s1q04h" %in% names(r)) num(r$hh_s1q04h) else NA_real_
  sex_c <- if ("hh_s1q04e" %in% names(r)) num(r$hh_s1q04e) else NA_real_
  r <- r %>%
    mutate(hhid   = as.character(.data[[C$hhid]]),
           age    = dplyr::coalesce(age_c, num(.data[[C$age]])),
           female = as.numeric(dplyr::coalesce(sex_c, num(.data[[C$sex]])) == 2),
           head   = as.numeric(num(.data[[C$rel]]) == 1))
  r %>% group_by(hhid) %>%
    summarise(n_members    = n(),
              share_child  = mean(age < 15,  na.rm=TRUE),
              share_elderly= mean(age >= 60, na.rm=TRUE),
              share_female = mean(female,    na.rm=TRUE),
              head_age     = mean(age[head == 1],    na.rm=TRUE),
              head_female  = mean(female[head == 1], na.rm=TRUE),
              .groups="drop")
}

build_prices_et <- function(w) {
  C <- WAVES_ET[[w]]
  p <- find_et(C$price); if (is.na(p)) return(NULL)
  d <- haven::read_dta(p)
  if (!all(c(C$p_item, C$p_val) %in% names(d))) return(NULL)
  ulab <- if (C$p_unit %in% names(d)) {
    lv <- val_labels(d[[C$p_unit]])
    if (is.null(lv)) rep(NA_character_, nrow(d)) else names(lv)[match(num(d[[C$p_unit]]), lv)]
  } else rep(NA_character_, nrow(d))
  ## v21 (D16): the wave's own EA id (2013-2015: ea_id2; ea_id is the 2011 EA
  ## and is missing for the new urban sample); the cents of 2011; and the
  ## quantity the price is quoted for (30 birr for 5 eggs is 6 a piece).
  ea   <- if (w %in% c("w2", "w3")) "ea_id2" else "ea_id"
  cent <- if ("cs10b1q07_f2" %in% names(d)) dplyr::coalesce(num(d$cs10b1q07_f2), 0) / 100 else 0
  amt  <- if (w == "w1") num(d$cs10b1q07_e1) + dplyr::coalesce(num(d$cs10b1q07_e2), 0) / 1000
          else num(d[[sub("05$", "04", C$p_val)]])
  amt  <- ifelse(is.na(amt) | amt <= 0, 1, amt)
  d %>% mutate(pitem = num(.data[[C$p_item]]), unit_lab = ulab,
               mkt_price = (num(.data[[C$p_val]]) + cent) / amt, .amt = amt,
               ea_id = as.character(.data[[ea]])) %>%
    inner_join(CMAP, by="pitem") %>%
    filter(unit_ok(product, unit_lab), mkt_price > 0, .amt <= 50) %>%
    group_by(ea_id, product) %>%
    summarise(mkt_price = median(mkt_price, na.rm=TRUE), .groups="drop")
}

build_coffee_et <- function(w) {
  C <- WAVES_ET[[w]]; COFFEE <- 72
  h <- rd_et(C$harv); hid <- if (C$hhid %in% names(h)) C$hhid else "household_id"
  harv <- h %>% filter(num(.data[[C$harv_crop]]) == COFFEE) %>%
    mutate(hhid = as.character(.data[[hid]])) %>%
    count(hhid, name="coffee_plots")
  s <- rd_et(C$sale); sid <- if (C$hhid %in% names(s)) C$hhid else "household_id"
  s <- s %>% filter(num(.data[[C$sale_crop]]) == COFFEE) %>%
    mutate(hhid = as.character(.data[[sid]]))
  labs <- sapply(s, function(x) { l <- attr(x, "label"); if (is.null(l)) "" else tolower(l) })
  vcol <- names(labs)[str_detect(labs, "value") & str_detect(labs, "sold|sale|total")]
  s$coffee_sale <- if (length(vcol)) num(s[[vcol[1]]]) else NA_real_
  sale <- s %>% group_by(hhid) %>%
    summarise(coffee_sale_birr = sum(coffee_sale, na.rm=TRUE), .groups="drop")
  full_join(harv, sale, by="hhid") %>% mutate(coffee_grower = 1L)
}

build_wave_et <- function(w) {
  C <- WAVES_ET[[w]]
  out <- build_food_et(w)

  agg <- rd_et(C$agg) %>% mutate(hhid = as.character(.data[[C$hhid]]))
  ea <- if (w %in% c("w2", "w3")) "ea_id2" else "ea_id"     # v21 (D16)
  keep <- intersect(c("adulteq","hh_size","nom_totcons_aeq","total_cons_ann",
                      "food_cons_ann","cons_quint", ea, C$weight), names(agg))
  agg <- agg %>% select(hhid, all_of(keep)) %>%
    rename(weight = !!C$weight, ea_id = !!ea) %>% mutate(ea_id = as.character(ea_id))

  cov <- rd_et(C$cover) %>% mutate(hhid = as.character(.data[[C$hhid]]))
  gk  <- intersect(c("saq01","saq02","saq03","rural","saq14"), names(cov))
  cov <- cov %>% select(hhid, all_of(gk)) %>% distinct(hhid, .keep_all=TRUE)
  names(cov)[names(cov) == "saq01"] <- "region"
  names(cov)[names(cov) == "saq02"] <- "zone"
  names(cov)[names(cov) == "saq03"] <- "woreda"
  if ("rural" %in% names(cov)) names(cov)[names(cov) == "rural"] <- "urban_code"
  if ("saq14" %in% names(cov)) names(cov)[names(cov) == "saq14"] <- "urban_code"

  out <- out %>%
    left_join(agg, by="hhid") %>%
    left_join(cov, by="hhid") %>%
    left_join(build_demog_et(w), by="hhid") %>%
    left_join(build_coffee_et(w), by="hhid")

  pr <- build_prices_et(w)
  if (!is.null(pr)) out <- out %>% left_join(pr, by=c("ea_id","product"))
  else out$mkt_price <- NA_real_

  out %>%
    mutate(country="ETH", wave=w, year=C$year,
           coffee_grower = ifelse(is.na(coffee_grower), 0L, coffee_grower),
           uv = ifelse(purch_kg > 0 & exp_conv > 0, exp_conv / purch_kg, NA_real_),
           across(c(region, zone, woreda, urban_code, ea_id, hhid), as.character))
}

panel_ET <- map_dfr(names(WAVES_ET), build_wave_et)
write.csv(panel_ET, file.path(OUT_DIR, "panel_ETH.csv"), row.names=FALSE)

###############################################################################
## VALIDATION GATES — the build is not trusted until these pass
###############################################################################
cat("\n=========== GATE 1: household counts vs the consumption aggregate ======\n")
for (w in names(WAVES_ET)) {
  C <- WAVES_ET[[w]]
  n_agg <- rd_et(C$agg) %>% pull(!!C$hhid) %>% unique() %>% length()
  n_pan <- panel_ET %>% filter(wave == w) %>% pull(hhid) %>% unique() %>% length()
  cat(sprintf("   %s %d: panel_ET=%6d  aggregate=%6d  %s\n", w, C$year, n_pan, n_agg,
              ifelse(n_pan == n_agg, "OK", "*** MISMATCH ***")))
}

cat("\n=========== GATE 2: median weekly purchased quantity (plausible?) =====\n")
print(panel_ET %>% filter(purch_kg > 0) %>%
        group_by(product, year) %>% summarise(m = round(median(purch_kg), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n=========== GATE 3: median unit value — must track inflation ==========\n")
print(panel_ET %>% filter(uv > 0) %>%
        group_by(product, year) %>% summarise(m = round(median(uv), 1), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n=========== GATE 4: unit value vs INDEPENDENT market price ============\n")
cat("   (the strongest check: two instruments, two conversion paths)\n")
print(panel_ET %>% filter(!is.na(mkt_price), uv > 0) %>%
        group_by(year, product) %>%
        summarise(unit_value = round(median(uv), 1),
                  market_price = round(median(mkt_price), 1), .groups="drop") %>%
        as.data.frame())

cat("\n=========== GATE 5: rows with spend but no convertible quantity =======\n")
print(panel_ET %>% group_by(track, year) %>%
        summarise(flagged = round(mean(unconv, na.rm=TRUE), 3), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=flagged) %>% as.data.frame())

cat("\nrows:", nrow(panel_ET), " households:", length(unique(panel_ET$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_ETH.csv"), "\n")
###############################################################################

}


