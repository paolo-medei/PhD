###############################################################################
## PART 8b — FAOSTAT BENCHMARK (v24, 15 Nov 2026)
##
##  Compares what households report (LSMS, 7-day recall) with what FAO's food
##  balance sheets say is available per person, product by product, in the
##  same country and years - as Desiere et al. (2018, Global Food Security 16)
##  did for one round per country, here for all 23 rounds. Also: how much of
##  each product's national supply is imported (Step II).
##
##  Needs the FAOSTAT bulk files (Africa) next to the survey archives:
##    FoodBalanceSheets_E_Africa.zip          (2010-)
##    FoodBalanceSheetsHistoric_E_Africa.zip  (-2013, used for 2008 only)
##  Skipped if they are absent.
##
##  READ BEFORE USING THE NUMBERS
##  - FBS is SUPPLY, not intake: production + imports - exports - feed, seed,
##    losses, divided by population. It includes food eaten away from home
##    and waste; survey quantities exclude both.
##  - Meat in FBS is carcass weight; milk is milk equivalent (powder and
##    cheese converted back to liquid milk); fish is LIVE weight (a kilo of
##    dried fish is about three of live fish). Survey milk below is fresh milk
##    only; survey fish is the weight bought, fresh and dried mixed.
##  - Survey quantities exist only where units convert (column coverage =
##    share of consuming households with a converted quantity). Ugandan
##    poultry and fish and Malawian fish are essentially never weighed: there
##    the survey number is not a measurement and the ratio is not reported.
##  - Survey years span two calendar years: FBS is the mean of the label year
##    and the next (2023 only for Malawi 2024, the last FBS year).
##  - kg_trim100 leaves out quantities above 100 times the country-year-
##    product median among consumers (one Ugandan household's 10,000 kg of
##    pork in 2019 moves the national mean from 1.3 to 29.8 kg per person).
##    The ratio uses kg_trim100. NOT yet applied in the rest of the pipeline.
##  FAO producer prices were also checked and are not used: for these five
##  countries they stop before or early in the survey years (Nigeria 2008,
##  Tanzania 2004, Malawi 2017, Ethiopia 2018, nothing for Uganda).
###############################################################################
fao_zip <- function(stem) {
  roots <- unique(c(DATA_ROOT, dirname(OUT_DIR), ARCH_ROOT))
  f <- unlist(lapply(roots, function(r) list.files(r, pattern = paste0("^", stem, "\\.zip$"),
                                                   full.names = TRUE)))
  if (length(f)) f[1] else NA_character_
}
TH <- theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"), legend.position = "bottom")
fz_new <- fao_zip("FoodBalanceSheets_E_Africa")
fz_old <- fao_zip("FoodBalanceSheetsHistoric_E_Africa")
if (is.na(fz_new)) {
  message("PART 8b: FoodBalanceSheets_E_Africa.zip not found - FAO benchmark skipped")
} else {

FAO_AREA <- c("Malawi" = "MWI", "Ethiopia" = "ETH", "Uganda" = "UGA",
              "United Republic of Tanzania" = "TZA", "Nigeria" = "NGA")
FAO_ITEM <- c("2731" = "beef", "2732" = "goat_sheep", "2733" = "pork", "2734" = "poultry",
              "2949" = "eggs", "2848" = "milk", "2960" = "fish")
FAO_ELEM <- c("645" = "kg_cap", "5511" = "production_kt", "5611" = "imports_kt",
              "5911" = "exports_kt")

read_fbs <- function(zf) {
  inner <- grep("_NOFLAG\\.csv$", unzip(zf, list = TRUE)$Name, value = TRUE)[1]
  d <- read.csv(unz(zf, inner), fileEncoding = "latin1", check.names = FALSE,
                stringsAsFactors = FALSE)
  d <- d[d$Area %in% names(FAO_AREA) & as.character(d$`Item Code`) %in% names(FAO_ITEM) &
         as.character(d$`Element Code`) %in% names(FAO_ELEM), ]
  yc <- grep("^Y[0-9]{4}$", names(d), value = TRUE)
  d %>% select(Area, `Item Code`, `Element Code`, all_of(yc)) %>%
    pivot_longer(all_of(yc), names_to = "year", values_to = "v") %>%
    transmute(country = unname(FAO_AREA[Area]), year = as.integer(sub("^Y", "", year)),
              product = unname(FAO_ITEM[as.character(`Item Code`)]),
              element = unname(FAO_ELEM[as.character(`Element Code`)]), v = num(v)) %>%
    filter(!is.na(v))
}
fbs <- read_fbs(fz_new)
if (!is.na(fz_old)) fbs <- bind_rows(fbs, read_fbs(fz_old) %>% filter(year < min(fbs$year)))

## ---- survey side: kg per person per year, national, by product --------- #
lsms_pc <- list()
for (pf in list.files(OUT_DIR, pattern = "^panel_[A-Z]{3}\\.csv$", full.names = TRUE)) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[, 2]
  raw <- read.csv(pf, stringsAsFactors = FALSE)
  g1  <- function(...) { for (n in c(...)) if (n %in% names(raw)) return(raw[[n]]); rep(NA, nrow(raw)) }
  d <- tibble(hhid = as.character(raw$hhid), year = num(raw$year), product = raw$product,
              track = raw$track, std = if ("std" %in% names(raw)) raw$std else "kg",
              q = num(g1("qty_std", "qty_kg")), consumed = num(g1("consumed")),
              n = num(g1("hhsize", "hh_size")), w = num(g1("hhweight", "weight"))) %>%
    filter(track == "B", n > 0, w > 0) %>%
    mutate(q = ifelse(std == "piece", q * 0.055, q),           # eggs: 55 g each
           cons = coalesce(consumed, 0) == 1 | coalesce(q, 0) > 0) %>%
    group_by(year, product) %>%
    mutate(med = median(q[q > 0], na.rm = TRUE),
           q_trim = ifelse(!is.na(q) & q > 100 * med, NA_real_, q)) %>% ungroup()
  pop <- d %>% distinct(hhid, year, .keep_all = TRUE) %>% group_by(year) %>%
    summarise(pop = sum(w * n), .groups = "drop")
  lsms_pc[[cc]] <- d %>% group_by(year, product) %>%
    summarise(kg_raw     = 52 * sum(w * coalesce(q, 0)),
              kg_trim100 = 52 * sum(w * coalesce(q_trim, 0)),
              n_trimmed  = sum(!is.na(q) & is.na(q_trim)),
              pct_consuming = 100 * sum(w * cons) / sum(w),
              coverage   = sum(w * (cons & coalesce(q, 0) > 0)) / max(sum(w * cons), 1e-9),
              .groups = "drop") %>%
    left_join(pop, by = "year") %>%
    mutate(country = cc, kg_raw = kg_raw / pop, kg_trim100 = kg_trim100 / pop) %>%
    select(-pop)
}
lsms_pc <- bind_rows(lsms_pc)

fao_kg <- fbs %>% filter(element == "kg_cap")
fao_at <- function(c, y, p) {
  ys <- if (y < max(fao_kg$year)) c(y, y + 1) else max(fao_kg$year)
  v <- fao_kg$v[fao_kg$country == c & fao_kg$product == p & fao_kg$year %in% ys]
  if (length(v)) mean(v) else NA_real_
}
MEATS <- c("beef", "goat_sheep", "pork", "poultry")
lv <- lsms_pc %>% filter(product %in% c(MEATS, "eggs", "milk", "fish")) %>% mutate(meats_included = NA_character_)
## total meat over the meats the survey actually weighs (coverage >= 0.5),
## compared with FAO's total over the SAME meats (Uganda: no poultry)
meat_tot <- lsms_pc %>% filter(product %in% MEATS, coverage >= 0.5) %>% group_by(country, year) %>%
  summarise(kg_raw = sum(kg_raw), kg_trim100 = sum(kg_trim100), n_trimmed = sum(n_trimmed),
            pct_consuming = NA_real_, coverage = min(coverage),
            meats_included = paste(product, collapse = "+"), .groups = "drop") %>%
  mutate(product = "meat")
lv <- bind_rows(lv, meat_tot)
lv$fao_kg <- mapply(function(c, y, p, mi)
  if (p == "meat") sum(sapply(strsplit(mi, "+", fixed = TRUE)[[1]], function(m) fao_at(c, y, m)))
  else fao_at(c, y, p),
  lv$country, lv$year, lv$product, lv$meats_included)
lv <- lv %>%
  mutate(ratio_lsms_fao = ifelse(coverage >= 0.5 & fao_kg > 0, kg_trim100 / fao_kg, NA_real_),
         country = factor(country, intersect(c("MWI", "ETH", "UGA", "TZA", "NGA"), unique(country)))) %>%
  arrange(product, country, year) %>%
  mutate(across(c(kg_raw, kg_trim100, fao_kg, pct_consuming), ~ round(.x, 2)),
         across(c(coverage, ratio_lsms_fao), ~ round(.x, 2)))
cat("\n--- 8b.1 kg per person per year: survey (trimmed) / FAO food balance ---\n")
print(as.data.frame(lv %>% select(product, country, year, kg_trim100, fao_kg, ratio_lsms_fao, coverage)))
write.csv(lv, file.path(TMPCSV, "FAO_01_levels_lsms_vs_fbs.csv"), row.names = FALSE)

## ---- import share of national supply ------------------------------------- #
imp <- fbs %>% filter(element %in% c("production_kt", "imports_kt", "exports_kt")) %>%
  pivot_wider(names_from = element, values_from = v) %>%
  mutate(supply_kt = production_kt + coalesce(imports_kt, 0) - coalesce(exports_kt, 0),
         import_share = ifelse(supply_kt > 0, 100 * coalesce(imports_kt, 0) / supply_kt, NA_real_)) %>%
  filter(year >= 2008) %>% arrange(country, product, year) %>%
  mutate(across(where(is.numeric) & !year, ~ round(.x, 1)))
cat("\n--- 8b.2 imports as % of national supply (FBS, milk in milk equivalent) ---\n")
print(as.data.frame(imp %>% filter(year %in% c(2010, 2014, 2018, 2022)) %>%
        select(country, product, year, import_share) %>%
        pivot_wider(names_from = year, values_from = import_share)))
write.csv(imp, file.path(TMPCSV, "FAO_02_import_share.csv"), row.names = FALSE)

## ---- figure: survey vs FAO over time, meat and milk ---------------------- #
fp <- bind_rows(
  lv %>% filter(product %in% c("meat", "milk", "fish"), coverage >= 0.5) %>%
    transmute(country, year, product, source = "Household survey (LSMS)", kg = kg_trim100),
  fao_kg %>% filter(product %in% c("milk", "fish"), year >= 2008) %>%
    transmute(country, year, product, source = "FAO food balance", kg = v),
  ## FAO meat over the meats each country's survey weighs (Uganda: no poultry)
  fao_kg %>% filter(product %in% MEATS, year >= 2008,
                    !(country == "UGA" & product == "poultry"),
                    !(country == "ETH" & product %in% c("poultry", "pork"))) %>%
    group_by(country, year) %>% summarise(kg = sum(v), .groups = "drop") %>%
    mutate(product = "meat", source = "FAO food balance")) %>%
  mutate(country = factor(country, c("MWI", "ETH", "UGA", "TZA", "NGA"),
                          c("Malawi", "Ethiopia", "Uganda", "Tanzania", "Nigeria")),
         product = factor(product, c("meat", "milk", "fish"), c("Meat", "Milk", "Fish")))
gf <- ggplot(fp, aes(year, kg, colour = source)) +
  geom_line(data = fp %>% filter(source == "FAO food balance")) +
  geom_point(data = fp %>% filter(source != "FAO food balance"), size = 2) +
  facet_grid(product ~ country, scales = "free_y") +
  scale_colour_manual(values = c("FAO food balance" = "grey45", "Household survey (LSMS)" = "#1F5FA8")) +
  labs(title = "Household surveys and FAO food balances: kg per person per year",
       subtitle = "Meat = the meats the survey weighs (Uganda without poultry, Ethiopia beef and goat & mutton). FAO: supply incl. waste and food away from home; meat in carcass weight, milk in milk equivalent, fish in live weight.\nSurvey: 7-day recall x 52, only where units convert for at least half of consumers.",
       x = NULL, y = "kg per person per year", colour = NULL) + TH
ggsave(file.path(FIGDIR, "FAO_01_lsms_vs_fbs.png"), gf, width = 12, height = 7, dpi = 200)
}
