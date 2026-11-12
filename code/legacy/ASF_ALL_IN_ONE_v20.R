###############################################################################
##                                                                           ##
##   ANIMAL-SOURCE FOOD & COFFEE DEMAND — ETHIOPIA AND TANZANIA               ##
##   ONE SCRIPT: raw survey archives  ->  panels  ->  results  ->  comparison ##
##                                                                           ##
##   Just run it. It finds the .zip archives, extracts them once, builds both
##   country panels, validates them, estimates, compares, and runs the
##   advanced layer. Nothing to upload, nothing to run in sequence.
##
##   WHAT IT PRODUCES, in <archive folder>/OUTPUT
##     panel_ETH.csv, panel_TZA.csv          harmonised household x product
##     XXX_01_decomposition.csv              Deaton: quantity vs quality
##     XXX_02_price_elasticities.csv         price response
##     XXX_10..14_*.csv                      sources, total vs purchased,
##                                           household fixed effects,
##                                           instrumented selection, quintiles
##     COMPARE_*.csv                         cross-country synthesis
##     figures_ETH / figures_TZA / figures_COMPARE / figures_ADVANCED
##
##   WHAT IT DOES, and why each step exists
##     1  BUILD    every mapping verified against the survey's own variable and
##                 value labels. Seven documented traps per country: sections
##                 that move between waves, household ids that change meaning,
##                 unit codes that flip, a sample that splits in two.
##     2  VALIDATE six gates per country. The build is not trusted until the
##                 household counts reconcile with the published aggregates and
##                 the unit values track inflation.
##     3  ESTIMATE Deaton decomposition with household-size and demographic
##                 controls, a saturation test, and price elasticities from a
##                 price the household itself did not choose.
##     4  COMPARE  the countries on the income axis.
##     5  ADVANCE  total consumption rather than purchases only; household
##                 fixed effects; selection corrected with livestock ownership
##                 as the exclusion restriction.
##
##   RUN TIME roughly 10-20 minutes the first time (extraction plus an 84 MB
##   Ethiopian food module); a few minutes afterwards.
###############################################################################

## ============================== CONFIG ==================================== #
DATA_ROOT <- ""      # "" -> auto-detect the folder holding ETH_*.zip / TZA_*.zip
OUT_DIR   <- ""      # "" -> OUTPUT next to the archives
RUN_BUILD <- TRUE    # FALSE to reuse existing panel_XXX.csv and skip the build
RUN_ADV   <- TRUE    # FALSE to skip the advanced layer
RUN_DEEP  <- TRUE    # FALSE to skip the deep descriptive/analytical layer
RUN_PERM  <- TRUE    # FALSE to skip the permanent-vs-transitory tests
RUN_NGA   <- TRUE    # FALSE to skip Nigeria
RUN_VC    <- TRUE    # FALSE to skip the value-chain module

## ============================== PACKAGES ================================== #
need <- c("haven","dplyr","tidyr","stringr","purrr","labelled","ggplot2","fixest",
          "openxlsx","patchwork")
for (p in need) if (!requireNamespace(p, quietly=TRUE)) install.packages(p)
suppressPackageStartupMessages({
  library(haven); library(dplyr); library(tidyr); library(stringr)
  library(purrr); library(labelled); library(ggplot2); library(fixest)
  library(openxlsx)
})
options(dplyr.summarise.inform = FALSE)
num <- function(x) suppressWarnings(as.numeric(x))

## ==================== FIND THE ARCHIVES, EXTRACT ONCE ===================== #
if (!nzchar(DATA_ROOT) || !dir.exists(DATA_ROOT)) {
  home  <- Sys.getenv("USERPROFILE"); if (!nzchar(home)) home <- path.expand("~")
  cands <- c(list.dirs(home, recursive = FALSE, full.names = TRUE), home)
  cands <- cands[grepl("OneDrive|Desktop|Documents", basename(cands), ignore.case = TRUE)]
  hit <- NULL
  for (r in c(cands, home)) {
    if (!dir.exists(r)) next
    z <- list.files(r, pattern = "^(ETH|TZA|NGA)_.*\\.zip$", recursive = TRUE, full.names = TRUE)
    if (length(z)) { hit <- dirname(z[1]); break }
    f <- list.files(r, pattern = "^(sect6a_hh_w5|hh_sec_ja1)\\.dta$",
                    recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    if (length(f)) { hit <- r; break }
  }
  if (is.null(hit)) stop(
    "Could not find the data.\n",
    "Set DATA_ROOT to the folder holding the ETH_*.zip and TZA_*.zip archives.\n",
    "Tip: Shift + right-click the folder -> 'Copy as path', paste it, turn \\ into /.")
  DATA_ROOT <- hit
  message("DATA_ROOT -> ", DATA_ROOT)
}

ARCH_ROOT <- DATA_ROOT
zips <- list.files(DATA_ROOT, pattern = "^(ETH|TZA|NGA)_.*\\.zip$",
                   recursive = TRUE, full.names = TRUE)
if (length(zips)) {
  UNZ <- file.path(DATA_ROOT, "_unzipped"); dir.create(UNZ, showWarnings = FALSE)
  for (z in zips) {
    dest <- file.path(UNZ, tools::file_path_sans_ext(basename(z)))
    if (dir.exists(dest) && length(list.files(dest, recursive = TRUE))) next
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    message("unzipping ", basename(z), " ...")
    utils::unzip(z, exdir = dest)
  }
  ARCH_ROOT <- UNZ
}
if (!nzchar(OUT_DIR)) OUT_DIR <- file.path(DATA_ROOT, "OUTPUT")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

## Every run gets its own dated folder, so nothing is ever overwritten and two
## runs can be compared side by side. The PANELS stay in OUTPUT itself: they are
## the data, not a result, and a later run with RUN_BUILD = FALSE must find them.
RUN_STAMP <- format(Sys.time(), "%Y-%m-%d_%H-%M")     # date + hour + minute
RUN_DIR   <- file.path(OUT_DIR, paste0("run_", RUN_STAMP))
FIGDIR    <- file.path(RUN_DIR, "figures")
## the tables are written here as scratch CSVs, gathered into ONE workbook at
## the end, and this folder is then removed. The run folder ends up holding a
## single .xlsx and a figures folder - nothing else.
TMPCSV    <- file.path(RUN_DIR, "_tmp_tables")
## ONE figures folder. The ten that carry the argument are named VC_01..VC_10
## and sort to the top; everything else is prefixed zz_ and sorts to the bottom.
FIGDIAG   <- FIGDIR
dir.create(FIGDIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TMPCSV, recursive = TRUE, showWarnings = FALSE)
## Earlier versions of this script wrote loose CSVs and figure folders straight
## into OUTPUT. They are swept into _previous_runs so that OUTPUT holds only the
## panels and the dated run folders. Nothing is deleted.
stray_csv <- setdiff(list.files(OUT_DIR, pattern="\\.csv$", full.names=TRUE),
                     list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$",
                                full.names=TRUE))
stray_dir <- list.dirs(OUT_DIR, recursive=FALSE, full.names=TRUE)
stray_dir <- stray_dir[grepl("^figures", basename(stray_dir))]
if (length(stray_csv) || length(stray_dir)) {
  OLD <- file.path(OUT_DIR, "_previous_runs")
  dir.create(OLD, showWarnings=FALSE)
  for (f in c(stray_csv, stray_dir))
    suppressWarnings(file.rename(f, file.path(OLD, basename(f))))
  message("tidied ", length(stray_csv) + length(stray_dir),
          " leftover items from earlier runs -> ", OLD)
}

message("OUT_DIR   -> ", OUT_DIR)
message("RUN_DIR   -> ", RUN_DIR)

## -------------------------------------------------------- file resolution --#
## Wave archives reuse file names (hh_sec_a.dta exists in several Tanzanian
## waves), so a stem can be disambiguated with a path hint such as "TZA_2012".
find_dta <- function(stem, hint = NULL) {
  f <- list.files(ARCH_ROOT, pattern = paste0("^", stem, "\\.dta$"),
                  recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (!is.null(hint) && length(f) > 1) {
    g <- f[grepl(hint, f, ignore.case = TRUE)]
    if (length(g)) f <- g
  }
  if (!length(f)) NA_character_ else f[1]
}
find_et <- function(stem) find_dta(stem)
rd_et <- function(stem) {
  p <- find_et(stem); if (is.na(p)) stop("missing file: ", stem)
  haven::read_dta(p)
}
rd_tz <- function(yr, stem) {
  p <- find_dta(stem, paste0("TZA_", yr))
  if (is.na(p)) stop("missing ", stem, " for ", yr)
  haven::read_dta(p)
}
val_labels <- labelled::val_labels


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
    product == "milk"   ~ (str_detect(lab,"litt|litre") & !str_detect(lab,"mili|milli")),
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
                    exp_conv = ifelse(is.na(purch_kg), NA_real_, exp),
                    unconv   = as.integer(exp > 0 & is.na(purch_kg)))
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
    mutate(.unconv  = as.integer(exp > 0 & is.na(purch_kg)),
           .exp_conv = ifelse(is.na(purch_kg), NA_real_, exp)) %>%
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
  r <- rd_et(C$roster) %>%
    mutate(hhid   = as.character(.data[[C$hhid]]),
           age    = num(.data[[C$age]]),
           female = as.numeric(num(.data[[C$sex]]) == 2),
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
  d %>% mutate(pitem = num(.data[[C$p_item]]), unit_lab = ulab,
               mkt_price = num(.data[[C$p_val]]),
               ea_id = as.character(ea_id)) %>%
    inner_join(CMAP, by="pitem") %>%
    filter(unit_ok(product, unit_lab), mkt_price > 0) %>%
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
  keep <- intersect(c("adulteq","hh_size","nom_totcons_aeq","total_cons_ann",
                      "food_cons_ann","cons_quint","ea_id", C$weight), names(agg))
  agg <- agg %>% select(hhid, all_of(keep)) %>%
    rename(weight = !!C$weight) %>% mutate(ea_id = as.character(ea_id))

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
    kc  <- intersect(c("clusterid","strataid"), names(cl))
    if (!is.na(idc) && length(kc)) {
      cl <- cl %>% mutate(hhid = as.character(.data[[idc]])) %>%
        select(hhid, all_of(kc)) %>% distinct(hhid, .keep_all=TRUE)
      a <- a %>% left_join(cl, by="hhid")
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
##  For 2010-2015 the unit LABELS state the weight themselves - "Sack/Bag:
##  Medium (50 kg)", "Basket: Small (15 kg)" - so the factor is read straight
##  out of the label, with the metric codes handled explicitly. Units whose
##  label carries no weight stay missing and are FLAGGED, never guessed.
###############################################################################
if (exists("RUN_NGA") && !RUN_NGA) message("PART 2b skipped") else if (RUN_BUILD) {

WAVES_NG <- list(
  w1 = list(year=2010, zipyr="2010", food="sect10b_harvestw1", pre="s10bq",
            agg="cons_agg_wave1_visit2", welfare="totcons", pc=FALSE,
            weight="hhweight", own="5", gift="6", cvn=FALSE),
  w2 = list(year=2012, zipyr="2012", food="sect10b_harvestw2", pre="s10bq",
            agg="cons_agg_wave2_visit2", welfare="totcons", pc=FALSE,
            weight="hhweight", own="6", gift="7", cvn=FALSE,
            conv="food_conv_w2ph"),
  w3 = list(year=2015, zipyr="2015", food="sect10b_harvestw3", pre="s10bq",
            agg="cons_agg_wave3_visit2", welfare="totcons", pc=FALSE,
            weight="hhweight", own="6", gift="7", cvn=FALSE,
            conv="food_conv_w3"),
  w4 = list(year=2018, zipyr="2018", food="sect10b_harvestw4", pre="s10bq",
            agg="totcons_final", welfare="totcons_pc", pc=TRUE,
            weight="wt_wave4", own="6", gift="7", cvn=TRUE)
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
  ## "... (50 kg)" or "... (15 Kg)"
  m <- regmatches(low, regexpr("\\(\\s*[0-9.]+\\s*kg", low))
  has <- lengths(regmatches(low, gregexpr("\\(\\s*[0-9.]+\\s*kg", low))) > 0
  kg[has] <- as.numeric(gsub("[^0-9.]", "", m))
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

  f <- f %>% mutate(item = num(item_cd), hhid = as.character(hhid)) %>%
    inner_join(ITEMS_NG, by="item")

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
    cv <- cv %>% transmute(.ci = num(item_cd), .cu = num(.data[[key]]),
                           .cf = num(.data[[val]])) %>%
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
      mutate(.unconv   = as.integer(exp > 0 & is.na(purch_kg)),
             .exp_conv = ifelse(is.na(purch_kg), NA_real_, exp)) %>%
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
  grid <- tidyr::crossing(hhid = unique(f$hhid),
                          tidyr::nesting(product = out$product, track = out$track,
                                         recall = out$recall) %>% distinct())
  geo1 <- f %>% select(hhid, all_of(geo)) %>% distinct(hhid, .keep_all=TRUE)
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
    ## 2018 already reports per capita; the others report the household total
    mutate(welfare = if (C$pc) num(welfare_raw)
                     else num(welfare_raw) / pmax(num(hhsize), 1)) %>%
    select(-welfare_raw)

  out %>% left_join(a, by="hhid") %>%
    mutate(country="NGA", wave=w, year=C$year,
           adulteq = pmax(num(hhsize), 1),   # NGA ships no adult-equivalent scale
           std = "kg",
           uv = ifelse(purch_kg > 0 & exp_conv > 0, exp_conv / purch_kg, NA_real_),
           region = as.character(zone),
           clusterid = paste0(as.character(state), "_", as.character(ea)),
           urban = as.character(sector),
           across(c(hhid, region, urban, clusterid), as.character))
}

panel_NG <- map_dfr(names(WAVES_NG), build_wave_ng)
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


###############################################################################
## PART 3 — ESTIMATE (all countries found)
###############################################################################
LABEL <- c(meat_agg="Meat", beef="Beef", goat_sheep="Goat & sheep", pork="Pork",
           poultry="Poultry", eggs="Eggs", milk="Fresh milk",
           milk_processed="Milk (powder/tinned)", cheese="Cheese",
           coffee="Coffee", fish="Fish")
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), panel.grid.minor=element_blank(),
        strip.text=element_text(face="bold"))

###############################################################################
## harmonise column names across country builds
##   ETH: purch_kg, exp_conv, nom_totcons_aeq, weight,    region, ea_id
##   TZA: purch_std, exp_conv, welfare,        hhweight,  region, clusterid
###############################################################################
prep <- function(d) {
  pick <- function(...) { for (n in c(...)) if (n %in% names(d)) return(d[[n]]); NA }
  out <- tibble(
    country = pick("country"), year = as.numeric(pick("year")),
    wave    = pick("wave"),    hhid = as.character(pick("hhid")),
    product = pick("product"), track = pick("track"),
    qty     = as.numeric(pick("purch_std","purch_kg")),
    exp_uv  = as.numeric(pick("exp_conv","exp")),
    exp     = as.numeric(pick("exp")),
    uv      = as.numeric(pick("uv")),
    unconv  = as.numeric(pick("unconv")),
    welfare = as.numeric(pick("welfare","nom_totcons_aeq")),
    adulteq = as.numeric(pick("adulteq")),
    hhsize  = as.numeric(pick("hhsize","hh_size")),
    weight  = as.numeric(pick("hhweight","weight")),
    region  = as.character(pick("region")),
    cluster = as.character(pick("clusterid","ea_id")),
    urban_r = as.character(pick("urban","urban_code")),
    mkt     = as.numeric(pick("mkt_price"))
  )
  out %>%
    mutate(adulteq = pmax(ifelse(is.na(adulteq), hhsize, adulteq), 1),
           weight  = ifelse(is.na(weight) | weight <= 0, 1, weight),
           urban   = as.integer(trimws(urban_r) %in% c("1","1.0","URBAN","Urban")),
           unconv  = ifelse(is.na(unconv), 0, unconv),
           l_x = log(welfare), l_ae = log(adulteq),
           region = factor(region))
}
CTRL <- "l_ae + urban"          # extended below if demographics are present

###############################################################################
## exogenous price: the CLUSTER median unit value of the OTHER households.
## Leave-one-out removes the household's own quality choice from its price.
###############################################################################
add_cluster_price <- function(d) {
  d %>% group_by(year, product, cluster) %>%
    mutate(n_cl   = sum(!is.na(uv) & uv > 0),
           sum_uv = sum(uv[!is.na(uv) & uv > 0]),
           p_loo  = ifelse(n_cl >= 4 & !is.na(uv),
                           (sum_uv - uv) / (n_cl - 1),
                           ifelse(n_cl >= 4, sum_uv / n_cl, NA_real_))) %>%
    ungroup() %>%
    mutate(price_exo = ifelse(!is.na(mkt), mkt, p_loo))
}

fit_cell <- function(g, ctrl) {
  b <- g %>% filter(uv > 0, qty > 0, welfare > 0, unconv == 0)
  if (nrow(b) > 100) { q <- quantile(b$uv, c(.01,.99), na.rm=TRUE)
                       b <- b %>% filter(uv >= q[1], uv <= q[2]) }
  if (nrow(b) < 80) return(tibble())
  fq <- as.formula(paste("log(uv)  ~ l_x +", ctrl, "| region"))
  fn <- as.formula(paste("log(qty) ~ l_x +", ctrl, "| region"))
  fs <- as.formula(paste("log(qty) ~ l_x + I(l_x^2) +", ctrl, "| region"))
  M <- function(f) try(feols(f, data=b, weights=~weight, vcov="hetero"), silent=TRUE)
  gv <- function(m,k) if (inherits(m,"try-error") || !(k %in% names(coef(m)))) c(NA,NA,NA)
                      else c(coef(m)[k], se(m)[k], pvalue(m)[k])
  a <- gv(M(fq),"l_x"); n <- gv(M(fn),"l_x"); s <- gv(M(fs),"I(l_x^2)")
  full <- g %>% filter(welfare > 0) %>%
    mutate(buys = as.integer(dplyr::coalesce(uv > 0 & qty > 0, FALSE)))
  tibble(n_buyers=nrow(b), participation=round(100*mean(full$buys),1),
         e_quality=a[1], se_quality=a[2], p_quality=a[3],
         e_quantity=n[1], se_quantity=n[2], p_quantity=n[3],
         e_expenditure=a[1]+n[1], quality_share=a[1]/(a[1]+n[1]),
         sat_b2=s[1], sat_p=s[3],
         plateau = !is.na(s[1]) && s[1] < 0 && !is.na(s[3]) && s[3] < .10)
}

fit_price <- function(g, ctrl) {
  b <- g %>% filter(qty > 0, welfare > 0, price_exo > 0, unconv == 0)
  if (nrow(b) < 120 || n_distinct(b$cluster) < 20) return(tibble())
  q <- quantile(b$qty, c(.01,.99), na.rm=TRUE)
  b <- b %>% filter(qty >= q[1], qty <= q[2])
  f <- as.formula(paste("log(qty) ~ log(price_exo) + l_x +", ctrl, "| region"))
  m <- try(feols(f, data=b, weights=~weight, cluster=~cluster), silent=TRUE)
  if (inherits(m,"try-error")) return(tibble())
  k <- "log(price_exo)"
  if (!(k %in% names(coef(m)))) return(tibble())
  tibble(n=nrow(b), n_clusters=n_distinct(b$cluster),
         e_price=unname(coef(m)[k]), se=unname(se(m)[k]), p=unname(pvalue(m)[k]),
         e_income=unname(coef(m)["l_x"]))
}

###############################################################################
## run
###############################################################################
panels <- list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)
if (!length(panels)) stop("no panels built")
for (pf in panels) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  d   <- prep(raw)

  ## use demographics only if this country's build supplied them
  ctrl <- CTRL
  for (v in c("share_child","share_elderly","head_age","head_female"))
    if (v %in% names(raw) && mean(!is.na(raw[[v]])) > .5) {
      d[[v]] <- as.numeric(raw[[v]]); ctrl <- paste(ctrl, "+", v)
    }
  message("\n==== ", cc, " ====  controls: ", ctrl)

  d <- add_cluster_price(d)
  A <- d %>% filter(track == "A")

  res <- A %>% group_by(year, product) %>% group_modify(~fit_cell(.x, ctrl)) %>% ungroup()
  pel <- A %>% group_by(year, product) %>% group_modify(~fit_price(.x, ctrl)) %>% ungroup()

  OUT <- RUN_DIR; FIG <- FIGDIAG
  write.csv(res, file.path(TMPCSV, paste0(cc,"_01_decomposition.csv")), row.names=FALSE)
  write.csv(pel, file.path(TMPCSV, paste0(cc,"_02_price_elasticities.csv")), row.names=FALSE)

  cat("\n--- DECOMPOSITION ---\n")
  print(as.data.frame(res %>% select(year,product,n_buyers,participation,
        e_quality,e_quantity,e_expenditure,quality_share) %>%
        mutate(across(where(is.numeric), ~round(.x,3)))))
  cat("\n--- AVERAGE OVER WAVES ---\n")
  print(as.data.frame(res %>% group_by(product) %>%
        summarise(quantity=round(mean(e_quantity,na.rm=TRUE),3),
                  quality =round(mean(e_quality ,na.rm=TRUE),3),
                  quality_share=round(mean(quality_share,na.rm=TRUE),3),
                  waves=n())))
  cat("\n--- SATURATION (plateau = TRUE) ---\n")
  print(as.data.frame(res %>% filter(plateau) %>% select(year,product,sat_b2,sat_p)))
  cat("\n--- PRICE ELASTICITIES (leave-one-out cluster price / market price) ---\n")
  print(as.data.frame(pel %>% mutate(across(where(is.numeric), ~round(.x,3)))))

  ## figures
  r <- res %>% filter(!is.na(e_quantity)) %>% mutate(lab = LABEL[product])
  p1 <- r %>% select(year,lab,Quantity=e_quantity,Quality=e_quality) %>%
    pivot_longer(c(Quantity,Quality), names_to="component", values_to="e") %>%
    ggplot(aes(factor(year), e, fill=component)) + geom_col() +
    facet_wrap(~lab, nrow=1) +
    scale_fill_manual(values=c(Quantity="#4E79A7", Quality="#59A14F")) +
    labs(title=paste0(cc, ": expenditure elasticity = quantity + quality"),
         x=NULL, y="Elasticity", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_01_decomposition.png"))), p1, width=11, height=3.4, dpi=200)

  p2 <- ggplot(r, aes(year, quality_share, colour=lab)) + geom_line() + geom_point() +
    geom_hline(yintercept=.5, linetype="dashed", colour="grey50") +
    labs(title=paste0(cc, ": share of the income response that is quality"),
         x=NULL, y="Quality share", colour=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_02_quality_share.png"))), p2, width=6.5, height=3.6, dpi=200)

  p3 <- ggplot(r, aes(year, participation, colour=lab)) + geom_line() + geom_point() +
    labs(title=paste0(cc, ": share of households purchasing"),
         x=NULL, y="%", colour=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_03_participation.png"))), p3, width=6.5, height=3.6, dpi=200)

  message("written -> ", OUT, " and ", FIG)
}
###############################################################################


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
INCOME <- tribble(~country, ~gdp_pc,
                  "ETH",  1020,
                  "TZA",  1220,
                  "UGA",   980,
                  "MWI",   580,
                  "NGA",  1600)

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
  ETH = list(
    waves = c(w1="w1", w2="w2", w3="w3", w4="w4", w5="w5"),
    ## waves 1-2 keep livestock in sect8a_ls_* with the code in ls_s8aq00 and
    ## the counts split across AGE CLASSES (ls_s8aq02a ... ls_s8aq12a, the "a"
    ## columns being the totals). Waves 3-5 use sect8_1_ls_* with a single
    ## "how many does the holder keep" variable. Same concept, different shape.
    stem  = function(w) if (w %in% c("w1","w2")) paste0("sect8a_ls_", w)
                        else paste0("sect8_1_ls_", w),
    hint  = function(w) paste0("ETH_20", c(w1="11",w2="13",w3="15",w4="18",w5="21")[[w]]),
    id    = function(w) if (w %in% c("w2","w3")) "household_id2" else "household_id",
    code  = function(w) if (w %in% c("w1","w2")) "ls_s8aq00" else "ls_code",
    count = function(w) if (w %in% c("w1","w2"))
                          "^ls_s8aq(0[2-9]|1[0-2])a$" else "ls_s8_1q01",
    ## verified: 1 bulls, 2 oxen, 3 cows, 4 steers, 5 heifers, 6 calves |
    ## 7 goats, 8 sheep, 9 camels | 10-12 chicken/chicks
    grp   = list(cattle=1:6, smallrum=7:9, poultry=10:12)),
  TZA = list(
    waves = c(w1="2008", w2="2010", w3="2012", w4="2014", w5="2020"),
    stem  = function(w) "LF_SEC_02",
    hint  = function(w) paste0("TZA_", c(w1="2008",w2="2010",w3="2012",
                                         w4="2014",w5="2020")[[w]]),
    id    = function(w) c(w1="hhid",w2="y2_hhid",w3="y3_hhid",
                          w4="y4_hhid",w5="y5_hhid")[[w]],
    ## verified: 1 bulls, 2 cows, 3 steers, 4 heifers, 5-6 calves | 7 goats,
    ## 8 sheep, 9 pigs | 10 chickens, 11 ducks, 12 other poultry
    code  = function(w) "lvstckid", count = function(w) "lf02_02",
    grp   = list(cattle=1:6, smallrum=7:9, poultry=10:12))
)

livestock_flags <- function(cc) {
  C <- LS[[cc]]; if (is.null(C)) return(NULL)
  map_dfr(names(C$waves), function(w) {
    d <- grab(C$stem(w), C$hint(w)); if (is.null(d)) return(NULL)
    idv <- C$id(w); codev <- C$code(w); cnt <- C$count(w)
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
      summarise(own_cattle   = as.integer(any(.code %in% C$grp$cattle   & .n > 0, na.rm=TRUE)),
                own_smallrum = as.integer(any(.code %in% C$grp$smallrum & .n > 0, na.rm=TRUE)),
                own_poultry  = as.integer(any(.code %in% C$grp$poultry  & .n > 0, na.rm=TRUE)),
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
    out <- list()
    d1 <- grab("TZY1.HH.Consumption", "TZA_2008")
    if (!is.null(d1)) out$w1 <- tibble(wave="w1", hhid=as.character(d1$hhid),
                                       pid=as.character(d1$hhid))
    d2 <- grab("TZY2.HH.Consumption", "TZA_2010")
    if (!is.null(d2) && "hhid_2008" %in% names(d2))
      out$w2 <- tibble(wave="w2", hhid=as.character(d2$y2_hhid),
                       pid=as.character(d2$hhid_2008))
    b3 <- grab("HH_SEC_B", "TZA_2012")
    if (!is.null(b3) && all(c("y3_hhid","y2_hhid") %in% names(b3)) && !is.null(out$w2)) {
      br <- b3 %>% distinct(y3_hhid, y2_hhid) %>%
        transmute(hhid=as.character(y3_hhid), y2=as.character(y2_hhid)) %>%
        left_join(out$w2 %>% select(y2=hhid, pid), by="y2")
      out$w3 <- br %>% transmute(wave="w3", hhid, pid)
    }
    d4 <- grab("consumptionNPS4", "TZA_2014")
    if (!is.null(d4)) out$w4 <- tibble(wave="w4", hhid=as.character(d4$y4_hhid),
                                       pid=as.character(d4$y4_hhid))
    b5 <- grab("hh_sec_b", "TZA_2020")
    if (!is.null(b5) && all(c("y5_hhid","y4_hhid") %in% names(b5)))
      out$w5 <- b5 %>% distinct(y5_hhid, y4_hhid) %>%
        transmute(wave="w5", hhid=as.character(y5_hhid), pid=as.character(y4_hhid))
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
    d <- d %>% left_join(pids, by=c("hhid","wave"))
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
              !(k %in% names(coef(m)))) c(NA,NA) else c(coef(m)[k], pvalue(m)[k])
      cq <- gv(mq); cn <- gv(mn)     # NOT `a`/`n`: tibble() would mask `n`
      tibble(n_obs=nrow(g), n_hh=n_distinct(g$pid),
             e_quality_FE=cq[1], p_quality=cq[2],
             e_quantity_FE=cn[1], p_quantity=cn[2],
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
    mutate(buys = as.integer(coalesce(qty_pur > 0, FALSE))) %>%
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
  "milk_processed", "litre", 250,
  "cheese",      "kg",     200,
  "coffee",      "kg",     0        # a stimulant, not a protein source
)
ANIMAL <- c("beef","goat_sheep","pork","poultry","eggs","milk",
            "milk_processed","cheese","fish")

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
    group_by(country, year, hhid, welfare, adulteq, weight, l_x) %>%
    summarise(
      n_products  = sum(coalesce(qty_tot,0) > 0),          # VARIETY, count
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
  shares <- d %>% filter(product %in% ANIMAL, !is.na(qt)) %>%
    group_by(qt) %>% mutate(tot = sum(coalesce(exp,0))) %>%
    group_by(qt, product) %>%
    summarise(share_of_asf_spend = round(100*sum(coalesce(exp,0))/first(tot), 1),
              .groups="drop")
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
    b <- g %>% filter(q_ae > 0, uv > 0, welfare > 0, unconv == 0)
    if (nrow(b) < 80) return(tibble())
    M <- function(f, dat) try(feols(f, dat, weights=~weight, vcov="hetero"), silent=TRUE)
    gv <- function(m,k="l_x") if (inherits(m,"try-error") ||
            !(k %in% names(coef(m)))) c(NA,NA) else c(coef(m)[k], pvalue(m)[k])
    full <- g %>% filter(welfare > 0) %>%
      mutate(buys = as.integer(coalesce(qty_tot > 0, FALSE)))
    mp <- try(feols(buys ~ l_x + l_ae | region^year, full, weights=~weight,
                    vcov="hetero"), silent=TRUE)
    ## region^year absorbs inflation AND local price level. Without a year
    ## effect, pooling 2011-2021 makes l_x pick up inflation: beef "quality"
    ## came out at 0.636 against 0.131 when estimated year by year.
    cq <- gv(M(as.formula("log(q_ae) ~ l_x + l_ae | region^year"), b))
    cu <- gv(M(as.formula("log(uv)   ~ l_x + l_ae | region^year"), b))
    cp <- gv(mp)
    tibble(n_obs=nrow(b), participation=round(100*mean(full$buys),1),
           e_participation=cp[1], p_part=cp[2],
           e_quantity_ae=cq[1],  p_qty=cq[2],
           e_quality=cu[1],      p_qual=cu[2])
  }
  fm <- d %>% filter(product %in% ANIMAL) %>%
    group_by(product) %>% group_modify(~marg_prod(.x)) %>% ungroup()
  print(as.data.frame(fm %>% mutate(across(where(is.numeric), ~round(.x,3)))))

  ## the fourth margin, estimated at household level
  vfit <- function(dat, dep) {
    m <- try(feols(as.formula(paste(dep, "~ l_x + log(adulteq) | year")),
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
                pct_consuming = round(100*weighted.mean(coalesce(qty_tot,0)>0,
                                                        weight, na.rm=TRUE),1),
                pct_buying    = round(100*weighted.mean(coalesce(qty_pur,0)>0,
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
           l_ae = log(adulteq)) %>%
    filter(track == "A", product %in% c("meat_agg","milk","eggs","coffee"),
           welfare > 0, uv > 0, qty_pur > 0, unconv == 0)

  ## link the waves
  pids <- try(panel_ids(cc), silent=TRUE)
  if (inherits(pids,"try-error") || is.null(pids) || !nrow(pids)) {
    message("no panel link for ", cc, " — skipped"); next
  }
  d <- d %>% left_join(pids, by=c("hhid","wave"), relationship="many-to-many") %>%
    filter(!is.na(pid))

  ## keep households seen in more than one wave
  d <- d %>% group_by(product, pid) %>% filter(n_distinct(year) > 1) %>% ungroup()
  if (!nrow(d)) { message("panel too thin"); next }

  ## split log welfare into a PERMANENT part (the household's own mean) and a
  ## TRANSITORY part (the deviation from it)
  d <- d %>% group_by(product, pid) %>%
    mutate(l_x      = log(welfare),
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
              weight= first(weight), .groups="drop") %>%
    filter(is.finite(d_lx), is.finite(d_luv), is.finite(d_lq), yrs >= 2)

  ldfit <- function(g) {
    if (nrow(g) < 100) return(tibble())
    gv <- function(m) if (inherits(m,"try-error")) c(NA,NA) else
            c(coef(m)["d_lx"], pvalue(m)["d_lx"])
    a <- gv(try(feols(d_luv ~ d_lx + d_lae, g, weights=~weight, vcov="hetero"), silent=TRUE))
    b <- gv(try(feols(d_lq  ~ d_lx + d_lae, g, weights=~weight, vcov="hetero"), silent=TRUE))
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
    within <- dec %>% summarise(q = mean(e_quality, na.rm=TRUE),
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


###############################################################################
## PART 8 — THE VALUE CHAIN
##
##  The argument this part is built to test:
##    investing in livestock creates value along the WHOLE chain, not only at
##    the farm gate, because as income rises the value that passes THROUGH the
##    market grows faster than the quantity produced on farms.
##
##  This does NOT require quantity to plateau - and it does not, at these income
##  levels. It requires four margins to be positive at once:
##
##    1  ENTRY          more households buy at all
##    2  MARKETISATION  more of what is eaten is bought rather than self-produced
##    3  PROCESSING     more of what is bought has been through a plant
##    4  UNIT VALUE     each kilo carries more value
##
##  Multiply them and you get the VALUE-CHAIN MULTIPLIER: how much faster the
##  market value grows than farm quantity. Above 1 means demand growth pulls the
##  chain harder than it pulls primary production - which is the policy claim.
##
##  CAVEAT, stated once: the multiplier assumes purchased value is a fair proxy
##  for value crossing the chain. Reasonable, not proven.
###############################################################################
if (exists("RUN_VC") && !RUN_VC) message("PART 8 skipped") else {

VCFIG <- FIGDIR      # the ten headline figures live here
PAL7  <- c("#4E79A7","#F28E2B","#59A14F","#E15759","#B07AA1","#76B7B2","#EDC948",
           "#FF9DA7","#9C755F","#BAB0AC")
THV <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold", size=12),
        plot.subtitle=element_text(colour="grey35", size=9),
        panel.grid.minor=element_blank(), strip.text=element_text(face="bold"),
        legend.position="bottom")

PROT_VC <- tibble::tribble(
  ~product,      ~prot,
  "beef",260, "goat_sheep",250, "pork",250, "poultry",270, "meat_agg",255,
  "fish",200, "eggs_kg",126, "eggs",6.9, "milk",33, "milk_processed",250,
  "cheese",200, "coffee",0)
ANIM <- c("beef","goat_sheep","pork","poultry","eggs","milk","milk_processed",
          "cheese","fish")

vc_load <- function(pf) {
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  ## Build an explicit, typed frame instead of carrying every column through.
  ## The three builds do not share a schema - clusterid is character in one
  ## country and numeric in another - and bind_rows refuses to combine them.
  g <- function(...) { for (n in c(...)) if (n %in% names(raw)) return(raw[[n]])
                       rep(NA, nrow(raw)) }
  tibble(
    country = cc,
    hhid    = as.character(g("hhid")),
    year    = num(g("year")),
    wave    = as.character(g("wave")),
    track   = as.character(g("track")),
    product = as.character(g("product")),
    std     = if ("std" %in% names(raw)) as.character(raw$std) else "kg",
    qtot    = num(g("qty_std","qty_kg")),
    qpur    = num(g("purch_std","purch_kg")),
    own     = num(g("own_std","own_kg")),
    gift    = num(g("gift_std","gift_kg")),
    exp     = num(g("exp")),
    uv      = num(g("uv")),
    welfare = num(g("welfare","nom_totcons_aeq")),
    adulteq = pmax(num(g("adulteq")), 1),
    weight  = num(g("hhweight","weight")),
    region  = as.character(g("region"))
  ) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight)) %>%
    filter(track == "B", product %in% ANIM) %>%
    left_join(PROT_VC %>% rename(prot = prot), by="product") %>%
    mutate(prot = ifelse(product=="eggs" & std=="kg", 126, prot),
           ## trim the top 0.1% of every flow: one household reporting tonnes
           ## can decide a whole year's average
           across(c(qtot,qpur,own,gift,exp), ~ pmin(.x, quantile(.x, .999, na.rm=TRUE)))) %>%
    group_by(year) %>% mutate(qt = ntile(welfare, 5)) %>% ungroup()
}

vc <- map_dfr(list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE),
              vc_load)
LABV <- c(beef="Beef", goat_sheep="Goat & sheep", pork="Pork", poultry="Poultry",
          eggs="Eggs", milk="Fresh milk", milk_processed="Milk, processed",
          cheese="Cheese", fish="Fish")
vc$lab <- unname(LABV[vc$product])

## ============ 1. MARKETISATION: bought against self-produced ============== #
mk <- vc %>% filter(!is.na(qt)) %>%
  mutate(p = coalesce(qpur,0), o = coalesce(own,0), g = coalesce(gift,0)) %>%
  group_by(country, lab, qt) %>%
  summarise(tot = sum(p+o+g), Purchased = sum(p)/tot*100,
            `Own production` = sum(o)/tot*100, Gifts = sum(g)/tot*100,
            .groups="drop") %>% filter(tot > 0) %>%
  select(-tot) %>%
  pivot_longer(c(Purchased,`Own production`,Gifts), names_to="source", values_to="pct")

g1 <- ggplot(mk, aes(factor(qt), pct, fill=source)) +
  geom_col(width=.85) + facet_grid(country ~ lab) +
  scale_fill_manual(values=c(Purchased="#4E79A7", `Own production`="#59A14F",
                             Gifts="#F28E2B")) +
  labs(title="The value chain forming: what is bought, what is grown at home",
       subtitle="Share of the quantity consumed, by welfare quintile. A widening blue band is the market taking over.",
       x="Welfare quintile (1 = poorest)", y="% of quantity consumed", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_01_marketisation_by_quintile.png"), g1, width=13, height=7, dpi=200)

## ============ 2. THE BASKET CHANGES SHAPE ================================ #
bk <- vc %>% filter(!is.na(qt), coalesce(exp,0) > 0) %>%
  group_by(country, qt) %>% mutate(tot = sum(exp, na.rm=TRUE)) %>%
  group_by(country, qt, lab) %>%
  summarise(share = 100*sum(exp, na.rm=TRUE)/first(tot), .groups="drop")
g2 <- ggplot(bk, aes(factor(qt), share, fill=lab)) +
  geom_col(width=.85) + facet_wrap(~country, nrow=1) +
  scale_fill_manual(values=PAL7) +
  labs(title="The basket does not just grow — it changes shape",
       subtitle="Composition of spending on animal-source food, poorest fifth to richest",
       x="Welfare quintile", y="% of animal-food spending", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_02_basket_composition.png"), g2, width=11, height=5, dpi=200)

## ============ 3. MARKET VALUE vs FARM QUANTITY =========================== #
vq <- vc %>% filter(!is.na(qt)) %>%
  group_by(country, qt) %>%
  summarise(qty = sum(coalesce(qtot,0)) / sum(weight),
            val = sum(coalesce(exp,0))  / sum(weight), .groups="drop") %>%
  group_by(country) %>%
  mutate(`Quantity consumed` = 100*qty/qty[which.min(qt)],
         `Value through the market` = 100*val/val[which.min(qt)]) %>%
  ungroup() %>%
  select(country, qt, `Quantity consumed`, `Value through the market`) %>%
  pivot_longer(-c(country,qt), names_to="series", values_to="idx")
g3 <- ggplot(vq, aes(qt, idx, colour=series)) +
  geom_line(linewidth=1) + geom_point(size=2) + facet_wrap(~country, nrow=1) +
  scale_colour_manual(values=c(`Quantity consumed`="#4E79A7",
                               `Value through the market`="#E15759")) +
  scale_x_continuous(breaks=1:5) +
  labs(title="Market value outruns farm quantity",
       subtitle="Index, poorest quintile = 100. The gap between the two lines is what the chain captures.",
       x="Welfare quintile", y="Index (Q1 = 100)", colour=NULL) + THV
ggsave(file.path(VCFIG,"VC_03_value_vs_quantity.png"), g3, width=11, height=4.5, dpi=200)

## ============ 4. FRESH vs PROCESSED (Nigeria) ============================ #
fp <- vc %>% filter(country=="NGA", product %in% c("milk","milk_processed"),
                    !is.na(qt)) %>%
  group_by(qt, lab) %>%
  summarise(part = 100*weighted.mean(coalesce(qtot,0) > 0, weight, na.rm=TRUE),
            .groups="drop")
if (nrow(fp)) {
  g4 <- ggplot(fp, aes(factor(qt), part, fill=lab)) +
    geom_col(position=position_dodge(.8), width=.7) +
    scale_fill_manual(values=c(`Fresh milk`="#59A14F", `Milk, processed`="#4E79A7")) +
    labs(title="Nigeria: the demand for processing plants, measured",
         subtitle="Fresh milk falls with income; powdered and tinned milk rises. That gap is a dairy industry.",
         x="Welfare quintile", y="% of households consuming", fill=NULL) + THV
  ggsave(file.path(VCFIG,"VC_04_fresh_vs_processed.png"), g4, width=8, height=4.5, dpi=200)
}

## ============ 5. WHERE THE TRANSFORMATION POINTS ARE ===================== #
tp <- vc %>% filter(!is.na(region), region != "NA", product %in%
                      c("beef","meat_agg","milk","milk_processed","poultry")) %>%
  mutate(p = coalesce(qpur,0), o = coalesce(own,0)) %>%
  group_by(country, region) %>%
  summarise(n_hh        = n_distinct(hhid),
            market_share= 100*sum(p)/pmax(sum(p+o), 1),
            uv_med      = median(uv[uv > 0], na.rm=TRUE),
            uv_rel      = NA_real_, .groups="drop") %>%
  group_by(country) %>%
  mutate(uv_rel = 100*uv_med/median(uv_med, na.rm=TRUE)) %>% ungroup() %>%
  filter(n_hh >= 100, is.finite(uv_rel))
if (nrow(tp)) {
  g5 <- ggplot(tp, aes(market_share, uv_rel, size=n_hh, colour=country)) +
    geom_hline(yintercept=100, linetype="dashed", colour="grey60") +
    geom_point(alpha=.75) + scale_colour_manual(values=PAL7) +
    scale_size_continuous(range=c(2,9)) +
    labs(title="Where a plant would find both a margin and a market",
         subtitle="Each point is a region. Right = product already moves through markets. Up = prices above the national median.",
         x="% of animal-source food that is purchased", y="Unit value, national median = 100",
         colour=NULL, size="households") + THV
  ggsave(file.path(VCFIG,"VC_05_transformation_map.png"), g5, width=9, height=6, dpi=200)
}

## ============ 6. THE MULTIPLIER, DECOMPOSED ============================== #
elas <- function(d, dep) {
  d <- d %>% filter(is.finite(.data[[dep]]), .data[[dep]] > 0, welfare > 0)
  if (nrow(d) < 200) return(NA_real_)
  m <- try(feols(as.formula(paste0("log(", dep, ") ~ log(welfare) + log(adulteq) | year")),
                 d, weights=~weight, vcov="hetero"), silent=TRUE)
  if (inherits(m,"try-error")) return(NA_real_)
  unname(coef(m)["log(welfare)"])
}
hh <- vc %>% group_by(country, year, hhid, welfare, adulteq, weight) %>%
  summarise(q_all = sum(coalesce(qtot,0)),
            v_mkt = sum(coalesce(exp,0)),
            n_prod= sum(coalesce(qtot,0) > 0),
            share_pur = sum(coalesce(qpur,0)) /
                        pmax(sum(coalesce(qpur,0)+coalesce(own,0)), 1e-9),
            .groups="drop")
mult <- hh %>% group_by(country) %>% group_modify(function(g, ...) {
  eq <- elas(g, "q_all"); ev <- elas(g, "v_mkt")
  ep <- elas(g %>% filter(share_pur > 0), "share_pur")
  en <- elas(g %>% filter(n_prod > 0), "n_prod")
  tibble(`Farm quantity`=eq, `Market value`=ev,
         `Marketisation`=ep, `Variety`=en,
         multiplier = ev/eq)
}) %>% ungroup()
cat("\n--- THE VALUE-CHAIN MULTIPLIER ---\n")
print(as.data.frame(mult %>% mutate(across(where(is.numeric), ~round(.x,3)))))
cat("\n   multiplier > 1 means the value passing through the market grows\n",
    "  FASTER than the quantity produced. That is the policy claim, in one number.\n")
write.csv(mult, file.path(TMPCSV, "VC_01_multiplier.csv"), row.names=FALSE)

g6 <- mult %>% select(country, `Farm quantity`, `Market value`) %>%
  pivot_longer(-country, names_to="k", values_to="e") %>%
  ggplot(aes(country, e, fill=k)) +
  geom_col(position=position_dodge(.8), width=.7) +
  geom_text(aes(label=sprintf("%.2f", e)), position=position_dodge(.8),
            vjust=-.4, size=3) +
  scale_fill_manual(values=c(`Farm quantity`="#4E79A7", `Market value`="#E15759")) +
  labs(title="For every 1% of income growth, the market grows faster than the farm",
       subtitle="Elasticity of total quantity consumed against value passing through the market",
       x=NULL, y="Elasticity", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_06_multiplier.png"), g6, width=8, height=4.5, dpi=200)

## ============ 7. PROTEIN ================================================= #
pr <- vc %>% filter(!is.na(qt)) %>%
  group_by(country, year, hhid, adulteq, weight, qt) %>%
  summarise(p_day = sum(coalesce(qtot,0)*coalesce(prot,0))/first(adulteq)/7,
            .groups="drop") %>%
  group_by(country, qt) %>%
  summarise(g = weighted.mean(p_day, weight, na.rm=TRUE), .groups="drop")
g7 <- ggplot(pr, aes(factor(qt), g, fill=country)) +
  geom_col(position=position_dodge(.8), width=.7) +
  geom_hline(yintercept=25, linetype="dashed", colour=RED <- "grey40") +
  scale_fill_manual(values=PAL7) +
  labs(title="Animal protein per adult equivalent per day",
       subtitle="Grams. Dashed line: roughly half the WHO total-protein reference of ~50 g.",
       x="Welfare quintile", y="g/day from animal sources", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_07_protein.png"), g7, width=9, height=4.5, dpi=200)

## ============ 8. PARTICIPATION GRID ====================================== #
pg <- vc %>% filter(!is.na(qt)) %>% group_by(country, lab, qt) %>%
  summarise(part = 100*weighted.mean(coalesce(qtot,0) > 0, weight, na.rm=TRUE),
            .groups="drop")
g8 <- ggplot(pg, aes(factor(qt), lab, fill=part)) +
  geom_tile(colour="white", linewidth=.6) +
  geom_text(aes(label=round(part)), size=2.8,
            colour=ifelse(pg$part > 45, "white", "grey15")) +
  facet_wrap(~country, nrow=1) +
  scale_fill_gradient(low="#EAF0F7", high="#1F3864", name="% of hh") +
  labs(title="Who eats what, and at which income",
       subtitle="Share of households consuming each product, by welfare quintile",
       x="Welfare quintile", y=NULL) + THV
ggsave(file.path(VCFIG,"VC_08_participation_grid.png"), g8, width=11, height=5, dpi=200)

## ============ 9. MARKETISATION OVER TIME ================================= #
mt <- vc %>% mutate(p = coalesce(qpur,0), o = coalesce(own,0)) %>%
  group_by(country, year, lab) %>%
  summarise(pct = 100*sum(p)/pmax(sum(p+o),1e-9), n = n(), .groups="drop") %>%
  filter(n >= 300)
g9 <- ggplot(mt, aes(year, pct, colour=lab)) +
  geom_line(linewidth=.8) + geom_point(size=1.6) +
  facet_wrap(~country, nrow=1, scales="free_x") +
  scale_colour_manual(values=PAL7) +
  labs(title="The chain is also forming over time, not only across incomes",
       subtitle="Share of the quantity consumed that was bought rather than produced at home",
       x=NULL, y="% purchased", colour=NULL) + THV
ggsave(file.path(VCFIG,"VC_09_marketisation_over_time.png"), g9, width=12, height=4.5, dpi=200)

## ============ 10. DESCRIPTIVE DASHBOARD + FULL TABLE ===================== #
desc <- vc %>% group_by(country, year, lab) %>%
  summarise(n_hh        = n_distinct(hhid),
            pct_consume = round(100*weighted.mean(coalesce(qtot,0) > 0, weight, na.rm=TRUE),1),
            pct_buy     = round(100*weighted.mean(coalesce(qpur,0) > 0, weight, na.rm=TRUE),1),
            med_qty_ae  = round(median((qtot/adulteq)[qtot > 0], na.rm=TRUE),3),
            med_uv      = round(median(uv[uv > 0], na.rm=TRUE),1),
            pct_purchased_of_qty = round(100*sum(coalesce(qpur,0))/
                                   pmax(sum(coalesce(qpur,0)+coalesce(own,0)),1e-9),1),
            .groups="drop")
write.csv(desc, file.path(TMPCSV, "VC_02_descriptive_statistics.csv"), row.names=FALSE)

hhsum <- hh %>% group_by(country, year) %>%
  summarise(households   = n_distinct(hhid),
            products_avg = round(weighted.mean(n_prod, weight, na.rm=TRUE),2),
            mkt_share    = round(100*weighted.mean(share_pur, weight, na.rm=TRUE),1),
            .groups="drop")
write.csv(hhsum, file.path(TMPCSV, "VC_03_household_summary.csv"), row.names=FALSE)

d1 <- ggplot(hhsum, aes(factor(year), households, fill=country)) +
  geom_col(position="dodge") + scale_fill_manual(values=PAL7) +
  labs(title="Households per wave", x=NULL, y=NULL, fill=NULL) + THV +
  theme(legend.position="none")
d2 <- ggplot(hhsum, aes(year, products_avg, colour=country)) +
  geom_line(linewidth=.8) + geom_point() + scale_colour_manual(values=PAL7) +
  labs(title="Animal products per household", x=NULL, y=NULL, colour=NULL) + THV
d3 <- ggplot(hhsum, aes(year, mkt_share, colour=country)) +
  geom_line(linewidth=.8) + geom_point() + scale_colour_manual(values=PAL7) +
  labs(title="% of quantity bought on the market", x=NULL, y=NULL, colour=NULL) + THV
d4 <- ggplot(desc %>% group_by(country, year) %>%
               summarise(p = mean(pct_consume), .groups="drop"),
             aes(year, p, colour=country)) +
  geom_line(linewidth=.8) + geom_point() + scale_colour_manual(values=PAL7) +
  labs(title="Average participation across products", x=NULL, y="%", colour=NULL) + THV

if (requireNamespace("patchwork", quietly=TRUE)) {
  library(patchwork)
  dash <- (d1 | d2) / (d3 | d4) +
    patchwork::plot_annotation(
      title = "Descriptive dashboard: three countries, fourteen waves",
      theme = theme(plot.title=element_text(face="bold", size=13)))
  ggsave(file.path(VCFIG,"VC_10_descriptive_dashboard.png"), dash,
         width=12, height=7.5, dpi=200)
} else {
  ggsave(file.path(VCFIG,"VC_10a_households.png"), d1, width=7, height=4, dpi=200)
  ggsave(file.path(VCFIG,"VC_10b_variety.png"),    d2, width=7, height=4, dpi=200)
  ggsave(file.path(VCFIG,"VC_10c_market_share.png"),d3, width=7, height=4, dpi=200)
  ggsave(file.path(VCFIG,"VC_10d_participation.png"),d4, width=7, height=4, dpi=200)
}

cat("\n--- DESCRIPTIVE STATISTICS (head) ---\n")
print(as.data.frame(head(desc, 15)))
message("value-chain figures written -> ", VCFIG)
}
###############################################################################

###############################################################################
## ONE WORKBOOK — every table produced by this run, one sheet each
###############################################################################
csvs <- sort(list.files(TMPCSV, pattern="\\.csv$", full.names=TRUE))
if (length(csvs)) {
  wb <- createWorkbook()
  hdr <- createStyle(textDecoration="bold", fgFill="#1F3864",
                     fontColour="#FFFFFF", halign="center", border="Bottom")
  ## a contents sheet, so the workbook explains itself
  idx <- tibble(sheet = character(), file = character(), rows = integer())
  for (f in csvs) {
    nm <- tools::file_path_sans_ext(basename(f))
    sh <- substr(gsub("[^A-Za-z0-9_]", "_", nm), 1, 31)   # Excel caps at 31 chars
    d  <- read.csv(f, stringsAsFactors=FALSE)
    addWorksheet(wb, sh)
    writeData(wb, sh, d, headerStyle=hdr)
    freezePane(wb, sh, firstRow=TRUE)
    setColWidths(wb, sh, cols=1:max(1,ncol(d)), widths="auto")
    idx <- bind_rows(idx, tibble(sheet=sh, file=basename(f), rows=nrow(d)))
  }
  addWorksheet(wb, "CONTENTS"); worksheetOrder(wb) <- c(nrow(idx)+1, seq_len(nrow(idx)))
  writeData(wb, "CONTENTS", idx, headerStyle=hdr)
  setColWidths(wb, "CONTENTS", cols=1:3, widths="auto")
  xlsx <- file.path(RUN_DIR, paste0("RESULTS_", RUN_STAMP, ".xlsx"))
  saveWorkbook(wb, xlsx, overwrite=TRUE)
  message("workbook  -> ", xlsx, "  (", nrow(idx), " sheets)")
  unlink(TMPCSV, recursive=TRUE)          # one workbook, no loose CSVs
}

message("\n=== ALL DONE ===")
message("  results  -> ", RUN_DIR)
message("  figures  -> ", FIGDIR, "   (VC_01..VC_10 first, zz_* are diagnostics)")
message("  panels   -> ", OUT_DIR)
###############################################################################
