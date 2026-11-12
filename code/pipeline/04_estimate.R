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


