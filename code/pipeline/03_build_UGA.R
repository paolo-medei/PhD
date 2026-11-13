###############################################################################
## PART 2c — BUILD UGANDA (UNPS 2010/11, 2011/12, 2013/14, 2015/16, 2018/19,
##                          2019/20)
##
##  Uganda is one of the five countries of UNIDO's ACT coffee programme and has
##  an LSMS-ISA panel. 2009/10 (catalogue 1001) is not among the archives yet;
##  add it to WAVES_UG when it is.
##
##  Every choice below was read off the value labels and question text of each
##  wave (13 Nov 2026), not assumed.
##
##  TRAP U1  2010-2015 list ONLY the items a household consumed (h15bq3a is
##           "Yes" on 99.8% of rows); 2018-2019 list every item for every
##           household with CEB03 = yes/no. The grid is completed, as for
##           Nigeria 2010, so that a household that ate no meat counts as a
##           zero rather than disappearing.
##  TRAP U2  2018 renames the whole module (h15bq* -> CEB*) and splits items:
##           pork 118 -> 1181, chicken 121 -> 1211-1214 (off-layer, broiler,
##           kroiler, local), and adds milk products (1251-1254, 1281).
##  TRAP U3  Chicken is NEVER weighed: "Piece-Big/Small" (2010-15) or "Whole
##           chicken big/medium/small" (2018-19), with kg for a few broilers.
##           The survey gives no weight per chicken, so these quantities are
##           FLAGGED as not convertible, never guessed (as in Tanzania and
##           Nigeria). Chicken spending still counts as buying meat.
##  TRAP U4  Unit code 54 means "Packet (unspecified)" in 2010-2015 and
##           "Packet (125g)" in 2018-2019. Units are therefore converted from
##           their LABEL in each wave, and only when the label states a metric
##           amount of the product ("Packet (500 g)", "Cup/Mug (0.5lt)" for a
##           liquid). "Nice cup" (60 g / 100 g, no volume) is read as 0.5 l
##           for milk: it costs what the 0.5-litre cup costs (Paolo, 13 Nov).
##  TRAP U5  Sex is coded Female = 0 / Male = 1 in 2010 and Male = 1 /
##           Female = 2 afterwards. Read from the label.
##  TRAP U6  The household id changes format three times: 10-digit numbers
##           (2010-2011), "H00101-04-01" (2013), "H00101-05-01" / "H0010101"
##           (2015), 32-character keys (2018-2019). The build keeps each wave's
##           own id; panel_ids() (06_advanced.R) links them.
##  TRAP U7  Purchases are split into "consumed at home" and "away from home".
##           Only home purchases enter purchases, spending and unit values, as
##           in the other countries (meals away are a separate module there);
##           away-from-home is about 1% of animal-food rows and enters the
##           total consumed only.
##  TRAP U9  Coffee quantities cannot be used: "Packet (100 g)" is bought at
##           100-200 UGX, the price of a sachet of instant coffee, not of 100 g
##           (a kilo would cost 1,000-2,000 UGX in 2010-13 against 10,000+ in
##           2015-19). Coffee keeps consumption and spending; its quantities
##           are flagged as not convertible. Only 2-7% of households buy it.
##  TRAP U10 2015 has no "tray" unit: 25 of 348 egg purchases (7%) are recorded
##           as ONE piece at 8,000-9,300 UGX, against a median of 350 per egg -
##           a tray of 30. Left in, they drive the 2015 egg "quality"
##           elasticity to 0.29. They are read as trays (quantity x 30; two
##           2019 "trays" priced as single eggs, / 30) - Paolo, 13 Nov. Then,
##           every product (also Malawi): a purchase still priced above 10 times
##           or below a tenth of the wave's median has its quantities flagged
##           (flag_price_outliers(), 00_setup.R).
##  TRAP U8  The consumption aggregate is monthly, per adult equivalent, in
##           constant prices (2005/06 base up to 2013, 2009/10 base from 2015).
##           It is put on an annual scale (x 12); the change of base sits in
##           the year effects of every model.
###############################################################################
if (exists("RUN_UGA") && !RUN_UGA) message("PART 2c skipped") else
if (!length(list.files(ARCH_ROOT, pattern = "^UGA_", include.dirs = TRUE))) {
  message("PART 2c: no Uganda archives (UGA_*.zip) found - Uganda skipped")
} else if (RUN_BUILD) {

rd_ug <- function(yr, stem) {
  p <- find_dta(stem, paste0("UGA_", yr))
  if (is.na(p)) stop("missing ", stem, " for Uganda ", yr)
  haven::read_dta(p)
}
## ids are numbers in 2010 and text later; never let R write 1e+09
idstr <- function(x) if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x))

WAVES_UG <- list(
  w1 = list(year=2010, yr="2010", style="old", food="GSEC15b", id_food="hh",
            cover="GSEC1", id_cover="HHID", roster="GSEC2", id_roster="HHID",
            agg="pov2010_11", id_agg="hh", weight="wgt10", cluster="comm"),
  w2 = list(year=2011, yr="2011", style="old", food="GSEC15B", id_food="HHID",
            cover="GSEC1", id_cover="HHID", roster="GSEC2", id_roster="HHID",
            agg="UNPS 2011-12 Consumption Aggregate", id_agg="HHID",
            weight="mult", cluster="comm"),
  w3 = list(year=2013, yr="2013", style="old", food="GSEC15B", id_food="hhid",
            cover="GSEC1", id_cover="hhid", roster="GSEC2", id_roster="hhid",
            agg="pov2013_14", id_agg="hhid", weight="wgt_X", cluster="ea"),
  w4 = list(year=2015, yr="2015", style="old", food="gsec15b", id_food="hh",
            cover="gsec1", id_cover="hh", roster="gsec2", id_roster="hh",
            agg="pov2015_16", id_agg="hh", weight="h_xwgt_W5", cluster="ea"),
  ## 2018-2019 have no EA code in the public files: the parish is the cluster
  ## (v23: with the county, since subcounties are numbered within county)
  w5 = list(year=2018, yr="2018", style="new", food="GSEC15B", id_food="hhid",
            cover="GSEC1", id_cover="hhid", roster="GSEC2", id_roster="hhid",
            agg="pov2018_19", id_agg="hhid", weight="wgt",
            cluster=c("district_code","county_code","subcounty_code","parish_code")),
  w6 = list(year=2019, yr="2019", style="new", food="gsec15b", id_food="hhid",
            cover="gsec1", id_cover="hhid", roster="gsec2", id_roster="hhid",
            agg="pov2019_20", id_agg="hhid", weight="wgt",
            cluster=c("dc_2018","cc_2018","sc_2018","pc_2018"))
)

## Products. 120 "other meat" (duck, rabbit, game) is left out, as in the other
## countries' meat; 1174 sausages, 1251 milk powder, 1253 ice cream and 1281
## cheese exist only in 2018-19 and have 1-12 consumers each.
ITEMS_UG <- tibble::tribble(
  ~item, ~product,         ~std,
   117,  "beef",           "kg",
   118,  "pork",           "kg",
  1181,  "pork",           "kg",
   119,  "goat_sheep",     "kg",     # label "Goat meat": no mutton item exists
   121,  "poultry",        "kg",
  1211,  "poultry",        "kg",
  1212,  "poultry",        "kg",
  1213,  "poultry",        "kg",
  1214,  "poultry",        "kg",
   124,  "eggs",           "piece",
   125,  "milk",           "litre",
  1252,  "milk_processed", "litre",  # fermented milk (bongo), 2018-19 only
  1254,  "milk_processed", "litre",  # yoghurt, 2018-19 only
   148,  "coffee",         "kg"
)
MEAT_UG <- c("beef","goat_sheep","pork","poultry")

## multiplier from the unit's LABEL into the product's standard unit (TRAP U4)
conv_ug <- function(lab, std) {
  l <- tolower(gsub("\\s+", " ", trimws(lab)))
  g <- suppressWarnings(as.numeric(sub("^(packet|sacket|nido tin) ?\\(([0-9.]+) ?g\\).*$", "\\2", l)))
  lt <- suppressWarnings(as.numeric(sub("^.*\\(([0-9.]+) ?lt\\).*$", "\\1", l)))
  dplyr::case_when(
    is.na(l)                                                ~ NA_real_,
    std == "piece" & grepl("^tray of 30", l)                ~ 30,
    std == "piece" & grepl("^(number of units|piece)", l)   ~ 1,
    std %in% c("kg","litre") & grepl("^kilogram", l)        ~ 1,   # milk: kg = litre
    std %in% c("kg","litre") & grepl("^gram", l)            ~ 1/1000,
    std %in% c("kg","litre") & grepl("^packet ?\\(1 ?kg\\)", l) ~ 1,
    std %in% c("kg","litre") & !is.na(g)                    ~ g / 1000,
    std == "litre" & grepl("^litre", l)                     ~ 1,
    std == "litre" & !is.na(lt)                             ~ lt,  # cup 0.5 l, glass 0.25 l
    ## v23 (decided by Paolo, 13 Nov): the "Nice cup" costs what the 0.5-litre
    ## cup costs and half a litre, in every wave
    std == "litre" & grepl("^nice cup", l)                  ~ 0.5,
    TRUE ~ NA_real_)
}

build_wave_ug <- function(w) {
  C <- WAVES_UG[[w]]
  f <- rd_ug(C$yr, C$food)
  v <- if (C$style == "old")
         list(item="itmcd", unit="untcd", yn="h15bq3a", q_pur="h15bq4", spend="h15bq5",
              q_away="h15bq6", q_own="h15bq8", q_gif="h15bq10")
       else
         list(item="CEB01", unit="CEB03C", yn="CEB03", q_pur="CEB06", spend="CEB07",
              q_away="CEB08", q_own="CEB10", q_gif="CEB012")
  miss <- setdiff(c(unlist(v), C$id_food), names(f))
  if (length(miss)) stop("Uganda ", C$year, ": missing column(s) in ", C$food, ": ",
                         paste(miss, collapse=", "))

  ulab <- labelled::val_labels(f[[v$unit]])
  f <- f %>%
    mutate(hhid = idstr(.data[[C$id_food]]), item = num(.data[[v$item]]),
           .ulab = names(ulab)[match(num(.data[[v$unit]]), ulab)])
  hh_all <- unique(f$hhid)                  # every household in the food module
  f <- f %>% inner_join(ITEMS_UG, by = "item") %>%
    mutate(.k = conv_ug(.ulab, std),
           .k = ifelse(product == "coffee", NA_real_, .k))      # TRAP U9

  q <- function(x) num(f[[x]])
  f$purch_std <- q(v$q_pur) * f$.k
  f$own_std   <- q(v$q_own) * f$.k
  f$gift_std  <- q(v$q_gif) * f$.k
  ## total consumed = the four sources (= h15bq14 on 99.8-100% of rows 2010-15)
  f$qty_std   <- rowSums(cbind(q(v$q_pur), q(v$q_away), q(v$q_own), q(v$q_gif)),
                         na.rm = TRUE) * f$.k
  f$qty_std[f$qty_std == 0] <- NA
  f$exp       <- q(v$spend)
  ## v23: six 2013 rows say "not consumed" next to a purchase; a purchase,
  ## own production or gift means it was consumed
  f$consumed  <- as.numeric(num(f[[v$yn]]) == 1 |
                            rowSums(cbind(q(v$q_pur), q(v$q_away), q(v$q_own), q(v$q_gif), f$exp) > 0,
                                    na.rm = TRUE) > 0)
  ## TRAP U10: a purchase priced at more than 10 times, or less than a tenth
  ## of, the wave's median for the product is a unit error (a tray recorded
  ## as one egg); its quantities are flagged
  f <- flag_price_outliers(f)
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
  A <- f %>% mutate(prodA = ifelse(product %in% MEAT_UG, "meat_agg", product)) %>%
    filter(prodA != "milk_processed") %>% agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)

  ## TRAP U1: every household x product, zero where nothing was consumed
  ## (milk_processed only where it was asked: 2018-19)
  prods <- bind_rows(
    ITEMS_UG %>% distinct(product, std) %>% mutate(track = "B"),
    ITEMS_UG %>% mutate(product = ifelse(product %in% MEAT_UG, "meat_agg", product)) %>%
      filter(product != "milk_processed") %>% distinct(product, std) %>% mutate(track = "A"))
  out <- tidyr::crossing(hhid = hh_all, prods) %>%
    left_join(out, by = c("hhid", "product", "std", "track")) %>%
    filter(!(product == "milk_processed" & C$style == "old")) %>%
    mutate(consumed = ifelse(is.na(consumed), 0, consumed),
           unconv   = ifelse(is.na(unconv), 0L, unconv))

  ## welfare, household size, adult equivalents
  a <- rd_ug(C$yr, C$agg) %>% mutate(hhid = idstr(.data[[C$id_agg]])) %>%
    distinct(hhid, .keep_all = TRUE)
  a <- a %>% transmute(hhid, welfare = num(welfare) * 12,           # TRAP U8
                       adulteq = num(equiv),
                       hhsize  = if ("hsize" %in% names(a)) num(hsize) else NA_real_)

  ## demographics: usual and regular members only (not guests, not people who
  ## left or died, who are also on the roster)
  r <- rd_ug(C$yr, C$roster)
  keep <- usual <- rep(TRUE, nrow(r))
  if ("h2q7" %in% names(r)) {
    st <- trimws(tolower(as.character(haven::as_factor(r$h2q7))))
    keep  <- grepl("^(usual|regular) member (present|absent)$", st)
    usual <- grepl("^usual member (present|absent)$", st)    # the aggregate's hsize
  }
  sx <- tolower(trimws(as.character(haven::as_factor(r$h2q3))))       # TRAP U5
  ## age shares over members of known age; ONE head per household (v23: one
  ## 2013 household lists two - the first on the roster is kept)
  dem <- r %>% mutate(hhid = idstr(.data[[C$id_roster]]), .age = num(h2q8),
                      .fem = as.numeric(sx == "female"), .head = num(h2q4) %in% 1,
                      .usual = usual) %>%
    filter(keep) %>% group_by(hhid) %>%
    summarise(n_usual       = sum(.usual),
              share_child   = mean(.age <  15, na.rm=TRUE),
              share_elderly = mean(.age >= 60, na.rm=TRUE),
              head_age      = .age[.head][1],
              head_female   = .fem[.head][1], .groups="drop") %>%
    mutate(across(c(share_child, share_elderly), ~ ifelse(is.nan(.x), NA_real_, .x)))
  ## v23: household size where the aggregate has none (2011) = usual members,
  ## as the aggregate's hsize counts them

  ## geography, cluster and weight from the cover page
  cv <- rd_ug(C$yr, C$cover)
  lab_of <- function(x) tolower(trimws(as.character(haven::as_factor(x))))
  cl  <- lapply(C$cluster, function(k) idstr(cv[[k]]))
  cv$.cl <- ifelse(Reduce(`|`, lapply(cl, function(x) is.na(x) | x %in% c("", "NA"))), NA,
                   do.call(paste, c(cl, sep = "_")))
  cv <- cv %>% transmute(
    hhid      = idstr(.data[[C$id_cover]]),
    ## v23: Kampala is region 0 in 2010 only; elsewhere it is inside Central
    region    = as.character(ifelse(num(region) == 0, 1, num(region))),
    urban     = ifelse(lab_of(urban) == "urban", "1", "0"),
    clusterid = .cl,
    hhweight  = num(.data[[C$weight]])) %>%
    distinct(hhid, .keep_all = TRUE)

  out %>% left_join(a, by = "hhid") %>% left_join(dem, by = "hhid") %>%
    mutate(hhsize = ifelse(is.na(hhsize) & n_usual > 0, n_usual, hhsize)) %>% select(-n_usual) %>%
    left_join(cv, by = "hhid") %>%
    mutate(country = "UGA", wave = w, year = C$year, strataid = NA_character_,
           uv = ifelse(purch_std > 0 & exp_conv > 0, exp_conv / purch_std, NA_real_))
}

panel_UG <- map_dfr(names(WAVES_UG), build_wave_ug)
write.csv(panel_UG, file.path(OUT_DIR, "panel_UGA.csv"), row.names=FALSE)

###############################################################################
## VALIDATION GATES
###############################################################################
cat("\n===== UGA GATE 1: households in the food module vs the consumption aggregate =====\n")
for (w in names(WAVES_UG)) {
  C <- WAVES_UG[[w]]
  n_agg <- rd_ug(C$yr, C$agg) %>% pull(!!C$id_agg) %>% idstr() %>% unique() %>% length()
  p <- panel_UG %>% filter(wave == w) %>% distinct(hhid, welfare)
  cat(sprintf("   %s %d: food module %5d  aggregate %5d  with welfare %5d\n",
              w, C$year, nrow(p), n_agg, sum(!is.na(p$welfare))))
}
cat("\n===== UGA GATE 2: median weekly purchase among buyers =====\n")
print(panel_UG %>% filter(track=="B", purch_std > 0) %>% group_by(product, std, year) %>%
        summarise(m = round(median(purch_std), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== UGA GATE 3: median unit value (UGX) - must track inflation =====\n")
print(panel_UG %>% filter(track=="B", uv > 0) %>% group_by(product, year) %>%
        summarise(m = round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== UGA GATE 4: % of households buying (spending > 0) =====\n")
print(panel_UG %>% filter(track=="B") %>% group_by(product, year) %>%
        summarise(p = round(100*mean(coalesce(exp, 0) > 0), 1), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())
cat("\n===== UGA GATE 5: purchases whose unit does not convert (share of buyers) =====\n")
print(panel_UG %>% filter(track=="B", coalesce(exp, 0) > 0) %>% group_by(product, year) %>%
        summarise(flagged = round(mean(unconv), 3), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=flagged) %>% as.data.frame())
cat("\n===== UGA GATE 6: weights, clusters, demographics present =====\n")
print(panel_UG %>% distinct(year, hhid, hhweight, clusterid, head_age, welfare) %>% group_by(year) %>%
        summarise(weight = round(mean(!is.na(hhweight)), 3), cluster = round(mean(!is.na(clusterid)), 3),
                  head_age = round(mean(!is.na(head_age)), 3), welfare = round(mean(!is.na(welfare)), 3),
                  .groups="drop") %>% as.data.frame())
cat("\nrows:", nrow(panel_UG), " households:", n_distinct(paste(panel_UG$wave, panel_UG$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_UGA.csv"), "\n")
}
###############################################################################
