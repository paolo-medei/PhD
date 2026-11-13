###############################################################################
## PART 2b — BUILD NIGERIA (GHS-Panel waves 2010, 2012, 2015, 2018)
##
##  Nigeria widens the income axis: about $1,600 per head against $1,020 in
##  Ethiopia and $1,220 in Tanzania. That is the reason for adding it.
##
##  TRAP N1  TWO VISITS per wave. Every wave has a post-planting AND a
##           post-harvest food module, each complete. Only the POST-HARVEST
##           module is used, for comparability with the other countries.
##  TRAP N2  THE SPEND QUESTION CHANGES between 2015 and 2018. Up to 2015 it
##           asks what was spent on the item in the past 7 DAYS. From 2018 it
##           asks the value of the MOST RECENT PURCHASE, with the purchased
##           quantity referring to the past 30 days.
##           => quantity CONSUMED (7 days) stays comparable across all waves,
##              and so does the unit value (money per kg of the same purchase),
##              but 7-day expenditure does not exist after 2015. Nigerian budget
##              shares are therefore NOT comparable across waves and are not
##              used; participation is defined on CONSUMPTION, not purchase.
##  TRAP N3  The source columns shift. 2010 puts own-production in q5 and gifts
##           in q6; 2012 and 2015 insert "from purchases" at q5, pushing own to
##           q6 and gifts to q7.
##  TRAP N4  2023 (wave 5) EXISTS but has NO consumption aggregate and no
##           weights - the World Bank publishes those months after the
##           microdata. Without total expenditure there is no income variable,
##           so wave 5 is excluded. Add it here when the aggregate is released.
##
##  Conversion: 2018 carries a per-row factor (s10bq2_cvn, "Kg/L conversion").
##  2012 and 2015 ship conversion tables (2012 in grams/centilitres, D12).
##  2010 has none: only metric units are converted; containers whose label
##  gives a capacity ("Basin: Small (10 kg)") are FLAGGED, never guessed (D13).
###############################################################################
if (exists("RUN_NGA") && !RUN_NGA) message("PART 2b skipped") else if (RUN_BUILD) {

WAVES_NG <- list(
  w1 = list(year=2010, zipyr="2010", food="sect10b_harvestw1", pre="s10bq",
            agg="cons_agg_wave1_visit2", welfare="totcons", pc=TRUE,
            weight="hhweight", own="5", gift="6", cvn=FALSE),
  w2 = list(year=2012, zipyr="2012", food="sect10b_harvestw2", pre="s10bq",
            agg="cons_agg_wave2_visit2", welfare="totcons", pc=TRUE,
            weight="hhweight", own="6", gift="7", cvn=FALSE,
            conv="food_conv_w2ph"),
  w3 = list(year=2015, zipyr="2015", food="sect10b_harvestw3", pre="s10bq",
            agg="cons_agg_wave3_visit2", welfare="totcons", pc=TRUE,
            weight="hhweight", own="6", gift="7", cvn=FALSE,
            conv="food_conv_w3")
  ## w4 (2018-19) EXCLUDED from v21 (12 Nov 2026): the World Bank no longer
  ## serves it ("Data Access Not Available") and the copy on Drive lacks the
  ## household modules. It is also the wave whose spend question changes
  ## (TRAP N2), so it would need separate treatment anyway. To restore it,
  ## put this entry back:
  ##   w4 = list(year=2018, zipyr="2018", food="sect10b_harvestw4", pre="s10bq",
  ##             agg="totcons_final", welfare="totcons_pc", pc=TRUE,
  ##             weight="wt_wave4", own="6", gift="7", cvn=TRUE)
)

## item codes are STABLE across every Nigerian wave - no crosswalk needed
ITEMS_NG <- tibble::tribble(
  ~item, ~product,
   90,  "beef",
   91,  "goat_sheep",      # mutton
   93,  "goat_sheep",      # goat
   92,  "pork",
   80,  "poultry",         # chicken
   82,  "poultry",         # other domestic poultry
   83,  "eggs",            # agricultural eggs
   84,  "eggs",            # local eggs
  110,  "milk",            # fresh milk - kept separate so NGA stays comparable
  111,  "milk_processed",  # milk powder      } what Nigerians actually drink:
  113,  "milk_processed",  # tinned milk      } fresh milk is only ~6% of hh
  115,  "milk_processed",  # other milk products
  100,  "fish", 101, "fish", 102, "fish", 103, "fish",
  120,  "coffee"
)   # 112 baby formula deliberately excluded: a different market
MEAT_NG <- c("beef","goat_sheep","pork","poultry")

rd_ng <- function(yr, stem) {
  p <- find_dta(stem, paste0("NGA_", yr))
  if (is.na(p)) stop("missing ", stem, " for ", yr)
  haven::read_dta(p)
}

## kilograms per unit, read from the unit label where the survey states it
kg_from_labels <- function(x) {
  lv <- labelled::val_labels(x)
  if (is.null(lv)) return(setNames(numeric(0), character(0)))
  nm <- names(lv); code <- as.numeric(lv)
  kg <- rep(NA_real_, length(code))
  low <- tolower(nm)
  ## v21 (D13): container labels ("Basin: Small (10 kg)") give the size of the
  ## container, not the weight of what is in it: 40 small basins of fish became
  ## 400 kg and beef came out at 25 naira/kg against 700. Only metric units
  ## are converted; containers are flagged as not convertible.
  ## the plain metric units
  kg[low == "kilograms" | low == "kilogram" | low == "kg"] <- 1
  kg[low == "grams"     | low == "gram"]                   <- 1/1000
  kg[low == "litres"    | low == "litre"]                  <- 1
  kg[low == "mililitre" | low == "millilitre" | low == "ml"] <- 1/1000
  setNames(kg, as.character(code))
}

build_wave_ng <- function(w) {
  C <- WAVES_NG[[w]]; p <- C$pre
  f <- rd_ng(C$zipyr, C$food)

  need_cols <- c("hhid","item_cd", paste0(p,"1"), paste0(p,"2a"))
  miss <- setdiff(need_cols, names(f))
  if (length(miss)) stop("NGA ", C$year, ": missing ", paste(miss, collapse=", "))

  ## v21 (D1): every household that answered the food module, BEFORE keeping
  ## only animal-food rows. In 2010 the roster lists only items consumed, so a
  ## household that ate no animal food has no row after the filter below; the
  ## grid must still contain it, with zeros (473 of 4,826 households in 2010).
  hh_geo <- f %>% mutate(hhid = as.character(hhid)) %>%
    select(hhid, any_of(c("zone","state","lga","ea","sector"))) %>%
    distinct(hhid, .keep_all = TRUE)

  ## v21 (D11): "other milk products" is code 114 in 2010 and 115 from 2012
  ## (114 becomes cheese). Keying on 115 everywhere lost it in 2010.
  items <- if (w == "w1") ITEMS_NG %>% mutate(item = ifelse(item == 115, 114, item)) else ITEMS_NG
  f <- f %>% mutate(item = num(item_cd), hhid = as.character(hhid)) %>%
    inner_join(items, by="item")

  if (C$cvn) {
    ## 2018: the survey supplies the factor row by row, and the source columns
    ## are quantities in the SAME unit as the total, so they share the factor.
    cv <- num(f[[paste0(p,"2_cvn")]])
    f$qty_kg   <- num(f[[paste0(p,"2a")]]) * cv
    f$own_kg   <- num(f[[paste0(p,C$own,"a")]]) * cv
    f$gift_kg  <- num(f[[paste0(p,C$gift,"a")]]) * cv
    ## purchases are 30-day and carry their own factor; spend is that purchase
    f$purch_kg <- num(f[[paste0(p,"9a")]]) * num(f[[paste0(p,"9_cvn")]])
    f$exp      <- num(f[[paste0(p,"10")]])
    f$recall   <- "purchase_30d"
  } else if (!is.null(C$conv)) {
    ## TRAP N5  2012 and 2015 report in local units - mudu, congo, derica,
    ## paint rubber - whose labels carry no weight, so label-parsing fails and
    ## every quantity comes back missing. Both waves ship a conversion table
    ## keyed on item x unit; use it.
    cv <- rd_ng(C$zipyr, C$conv)
    key <- if ("nsu_cd" %in% names(cv)) "nsu_cd" else "unit_cd"
    val <- if ("conv" %in% names(cv)) "conv" else "conv_national"
    ## v21 (D12): the 2012 table is in GRAMS (g_cl = 1) or CENTILITRES (g_cl = 0),
    ## not kg: one egg was 50 kg. The 2015 table is already in kg.
    div <- if ("g_cl" %in% names(cv)) ifelse(num(cv$g_cl) == 1, 1000, 100) else 1
    cv <- cv %>% mutate(.div = div) %>%
      transmute(.ci = num(item_cd), .cu = num(.data[[key]]),
                .cf = num(.data[[val]]) / .div) %>%
      filter(!is.na(.cf)) %>% group_by(.ci, .cu) %>%
      summarise(.cf = mean(.cf), .groups="drop")
    ## TRAP N7  The 2012 table covers NO meat item at all - 90, 91, 92, 93, 80
    ## and 82 are simply absent - while those rows are reported in kilograms and
    ## grams, which need no table. Without a metric fallback, meat and milk
    ## vanished from 2012 entirely. Codes: 1 kg, 2 g, 3 litre, 4 CENTILITRE.
    metric <- c("1"=1, "2"=0.001, "3"=1, "4"=0.01)
    tokg <- function(qv, uv_) {
      if (!all(c(qv,uv_) %in% names(f))) return(rep(NA_real_, nrow(f)))
      tmp <- tibble(.ci = num(f$item_cd), .cu = num(f[[uv_]]), .q = num(f[[qv]])) %>%
        left_join(cv, by=c(".ci",".cu")) %>%
        mutate(.cf = ifelse(is.na(.cf), unname(metric[as.character(.cu)]), .cf))
      tmp$.q * tmp$.cf
    }
    f$qty_kg   <- tokg(paste0(p,"2a"), paste0(p,"2b"))
    f$purch_kg <- tokg(paste0(p,"3a"), paste0(p,"3b"))
    f$own_kg   <- tokg(paste0(p,C$own,"a"),  paste0(p,C$own,"b"))
    f$gift_kg  <- tokg(paste0(p,C$gift,"a"), paste0(p,C$gift,"b"))
    f$exp      <- num(f[[paste0(p,"4")]])
    f$recall   <- "spend_7d"
  } else {
    kgmap <- kg_from_labels(f[[paste0(p,"2b")]])
    tokg <- function(qv, uv_) {
      if (!all(c(qv,uv_) %in% names(f))) return(rep(NA_real_, nrow(f)))
      num(f[[qv]]) * unname(kgmap[as.character(num(f[[uv_]]))])
    }
    f$qty_kg   <- tokg(paste0(p,"2a"), paste0(p,"2b"))
    f$purch_kg <- tokg(paste0(p,"3a"), paste0(p,"3b"))
    f$own_kg   <- tokg(paste0(p,C$own,"a"),  paste0(p,C$own,"b"))
    f$gift_kg  <- tokg(paste0(p,C$gift,"a"), paste0(p,C$gift,"b"))
    f$exp      <- num(f[[paste0(p,"4")]])
    f$recall   <- "spend_7d"
  }
  f$consumed <- as.numeric(num(f[[paste0(p,"1")]]) == 1)

  geo <- intersect(c("zone","state","lga","ea","sector"), names(f))
  f <- f %>% select(hhid, product, consumed, qty_kg, purch_kg, own_kg, gift_kg,
                    exp, recall, all_of(geo))

  agg_by <- function(df, col) {
    df %>%
      ## v21: a purchase reported as 0 units with spending is not convertible
      mutate(.unconv   = as.integer(exp > 0 & (is.na(purch_kg) | purch_kg <= 0)),
             .exp_conv = ifelse(is.na(purch_kg) | purch_kg <= 0, NA_real_, exp)) %>%
      group_by(hhid, product = .data[[col]], recall,
               across(all_of(geo))) %>%
      summarise(consumed = suppressWarnings(max(consumed, na.rm=TRUE)),
                qty_kg   = sum(qty_kg,   na.rm=TRUE),
                purch_kg = sum(purch_kg, na.rm=TRUE),
                own_kg   = sum(own_kg,   na.rm=TRUE),
                gift_kg  = sum(gift_kg,  na.rm=TRUE),
                exp      = sum(exp,       na.rm=TRUE),
                exp_conv = sum(.exp_conv, na.rm=TRUE),
                unconv   = as.integer(any(.unconv == 1, na.rm=TRUE)),
                .groups="drop") %>%
      mutate(consumed = ifelse(is.finite(consumed), consumed, NA_real_),
             across(c(qty_kg, purch_kg, own_kg, gift_kg, exp, exp_conv),
                    ~ ifelse(.x == 0, NA_real_, .x)))
  }
  B <- agg_by(f, "product") %>% mutate(track = "B")
  A <- f %>% mutate(prodA = ifelse(product %in% MEAT_NG, "meat_agg", product)) %>%
    filter(prodA != "fish") %>% agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)

  ## TRAP N6  In 2010 the roster holds ONLY the items a household actually
  ## consumed (14.7 rows per household against 104-110 in the other waves), so
  ## a non-consuming household has no row at all and participation comes out at
  ## ~97%. The grid is completed here - every household x product combination
  ## exists, with a zero where the household consumed nothing - so that
  ## participation means the same thing in Nigeria as in the other countries.
  grid <- tidyr::crossing(hhid = hh_geo$hhid,
                          tidyr::nesting(product = out$product, track = out$track,
                                         recall = out$recall) %>% distinct())
  geo1 <- hh_geo %>% select(hhid, all_of(geo))
  out <- grid %>% left_join(out, by=c("hhid","product","track","recall")) %>%
    select(-any_of(geo)) %>% left_join(geo1, by="hhid") %>%
    mutate(consumed = ifelse(is.na(consumed), 0, consumed),
           unconv   = ifelse(is.na(unconv), 0L, unconv))

  ## welfare
  a <- rd_ng(C$zipyr, C$agg) %>% mutate(hhid = as.character(hhid))
  keep <- intersect(c("hhsize", C$welfare, C$weight), names(a))
  a <- a %>% select(hhid, all_of(keep))
  names(a)[names(a) == C$welfare] <- "welfare_raw"
  names(a)[names(a) == C$weight]  <- "hhweight"
  if (!"hhweight" %in% names(a)) a$hhweight <- NA_real_
  a <- a %>% distinct(hhid, .keep_all=TRUE) %>%
    ## v21 (D2): totcons is ALREADY per capita in 2010-2015 (label: "Total
    ## consumption per capita"); v20 divided it by hhsize a second time.
    mutate(welfare = if (C$pc) num(welfare_raw)
                     else num(welfare_raw) / pmax(num(hhsize), 1)) %>%
    select(-welfare_raw)

  out %>% left_join(a, by="hhid") %>%
    mutate(country="NGA", wave=w, year=C$year,
           adulteq = pmax(num(hhsize), 1),   # NGA ships no adult-equivalent scale
           std = "kg",
           uv = ifelse(purch_kg > 0 & exp_conv > 0, exp_conv / purch_kg, NA_real_),
           region = as.character(zone),
           ## v21: EA numbers repeat across LGAs (21-29 ids spanned two LGAs)
           clusterid = paste0(as.character(state), "_", as.character(lga), "_", as.character(ea)),
           urban = as.character(sector),
           across(c(hhid, region, urban, clusterid), as.character))
}

## v22: zone/state/lga/sector keep their Stata value labels, which differ
## between waves; stacking them warned 8 times. Only the codes are used.
panel_NG <- map_dfr(names(WAVES_NG), ~ zap_labels(build_wave_ng(.x)))
write.csv(panel_NG, file.path(OUT_DIR, "panel_NGA.csv"), row.names=FALSE)

###############################################################################
## VALIDATION GATES
###############################################################################
cat("\n===== NGA GATE 1: households vs the consumption aggregate =====\n")
for (w in names(WAVES_NG)) {
  C <- WAVES_NG[[w]]
  n_agg <- rd_ng(C$zipyr, C$agg) %>% pull(hhid) %>% unique() %>% length()
  n_pan <- panel_NG %>% filter(wave == w) %>% pull(hhid) %>% unique() %>% length()
  cat(sprintf("   %s %d: panel=%5d  aggregate=%5d  %s\n", w, C$year, n_pan, n_agg,
              ifelse(abs(n_pan-n_agg) <= 0.05*n_agg, "OK (within 5%)", "*** CHECK ***")))
}

cat("\n===== NGA GATE 2: median kg consumed in a week (plausible?) =====\n")
print(panel_NG %>% filter(track=="B", qty_kg > 0) %>%
        group_by(product, year) %>% summarise(m=round(median(qty_kg),2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== NGA GATE 3: median unit value (NGN/kg) — must track inflation =====\n")
print(panel_NG %>% filter(track=="B", uv > 0) %>%
        group_by(product, year) %>% summarise(m=round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== NGA GATE 4: % of households CONSUMING (not purchasing) =====\n")
cat("   NB: consumption, because 7-day expenditure does not exist after 2015\n")
## TRAP N6  In 2010 the roster holds only the items a household actually
## consumed, so the share of ROWS with a positive quantity is ~100% by
## construction. Participation is therefore households consuming the product
## over ALL households interviewed in that wave.
nhh_ng <- panel_NG %>% distinct(year, hhid) %>% count(year, name="n_hh")
print(panel_NG %>% filter(track=="B", !is.na(qty_kg), qty_kg > 0) %>%
        distinct(year, product, hhid) %>% count(year, product, name="n_cons") %>%
        left_join(nhh_ng, by="year") %>%
        mutate(p = round(100*n_cons/n_hh, 1)) %>%
        select(product, year, p) %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())

cat("\n===== NGA GATE 5: unconvertible units, flagged =====\n")
print(panel_NG %>% filter(track=="B") %>% group_by(year) %>%
        summarise(flagged=round(mean(unconv, na.rm=TRUE),3), .groups="drop") %>%
        as.data.frame())

cat("\nrows:", nrow(panel_NG), " households:", length(unique(panel_NG$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_NGA.csv"), "\n")
###############################################################################
}


