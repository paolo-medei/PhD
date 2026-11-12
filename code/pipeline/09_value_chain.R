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
## v21 (M5): fish out, as in ANIMAL (07_deep.R)
ANIM <- c("beef","goat_sheep","pork","poultry","eggs","milk","milk_processed",
          "cheese")

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

