###############################################################################
##  DATASET DI FAMIGLIE SUGLI ALIMENTI RICCHI DI PROTEINE (v1, 23 nov 2026)
##
##  COSA FA   Dai moduli alimentari grezzi delle indagini LSMS-ISA costruisce
##            una tabella lunga (famiglia x voce alimentare) per OGNI voce ricca
##            di proteine: carne, pesce, uova, latticini, legumi, arachidi, frutta
##            a guscio, semi. Tiene le risposte originali (quantita', codice di
##            unita', spesa, per fonte) e aggiunge la quantita' nell'unita'
##            standard della voce, solo con fattori ufficiali o metrici.
##            Il file make_item_map.py decide, voce per voce e wave per wave,
##            a quale voce armonizzata (slot) appartiene ogni codice originale.
##            Il file assemble_dataset.py fa la tabella larga e il workbook.
##  REGOLE    Niente si cancella e niente si corregge: i valori anomali hanno un
##            segnale (flag), non vengono svuotati come nella pipeline dello
##            Step I. Una voce non consumata ha consumo 0 e quantita' 0; una voce
##            consumata ma senza quantita' convertibile ha la quantita' vuota (NA).
##            Una voce non presente nel questionario di quella wave e' vuota.
##  USO       Rscript build_protein_dataset.R <cartella _unzipped> <cartella output>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(tidyr); library(stringr); library(purrr) })
options(dplyr.summarise.inform = FALSE)
args <- commandArgs(TRUE)
ARCH_ROOT <- if (length(args) >= 1) args[1] else "/home/claude/work/single/data/_unzipped"
OUTD      <- if (length(args) >= 2) args[2] else "dataset_out"
MAPF      <- if (length(args) >= 3) args[3] else "item_map.csv"
dir.create(OUTD, showWarnings = FALSE, recursive = TRUE)
MAP <- read.csv(MAPF, stringsAsFactors = FALSE)

num   <- function(x) suppressWarnings(as.numeric(haven::zap_labels(x)))
chr   <- function(x) { x <- haven::zap_labels(x); ifelse(is.na(x), NA_character_, trimws(as.character(x))) }
idstr <- function(x) { x <- haven::zap_labels(x); if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x)) }
col   <- function(d, v, f = num) if (!is.null(v) && v %in% names(d)) f(d[[v]]) else if (identical(f, chr)) rep(NA_character_, nrow(d)) else rep(NA_real_, nrow(d))
find_dta <- function(stem, hint = NULL) {
  f <- list.files(ARCH_ROOT, pattern = paste0("^", stem, "\\.dta$"), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (!is.null(hint) && length(f) > 1) { g <- f[grepl(hint, f, ignore.case = TRUE)]; if (length(g)) f <- g }
  if (!length(f)) NA_character_ else f[1] }
rd <- function(stem, hint) { p <- find_dta(stem, hint); if (is.na(p) || !grepl(sub("\\.\\*.*", "", hint), p)) stop("missing ", stem, " (", hint, ")"); haven::read_dta(p) }

## una riga per famiglia x voce, con i nomi di ruolo comuni a tutti i paesi
ROLE <- c("cons_raw", "q_tot", "u_tot", "q_pur", "u_pur", "exp_pur", "q_own", "u_own", "q_gift", "u_gift",
          "uo_tot", "uo_pur", "uo_own", "uo_gift", "us_tot", "us_pur", "us_own", "us_gift",
          "q_away", "val_away", "val_own", "val_gift", "q_frompur", "u_frompur", "q_wt", "u_wt")
frame <- function(hhid, code, ...) {
  x <- list(...); n <- length(hhid)
  out <- tibble(hhid = hhid, code = code)
  for (r in ROLE) out[[r]] <- if (!is.null(x[[r]])) x[[r]] else if (startsWith(r, "u")) rep(NA_character_, n) else rep(NA_real_, n)
  out
}

###############################################################################
## ETIOPIA (ESS): unita' convertite con le tabelle ufficiali Food_CF (fattore
## nazionale medio per voce x unita'); i codici delle wave 2018-2021 si leggono
## nella tabella con il codice del 2015 (cf_code nella mappa). Le voci che la
## tabella non ha (cammello, veccia, fieno greco, fagiolo mungo, shiro, sesamo,
## girasole) si convertono solo dalle unita' metriche (kg, g, quintale, litro, ml).
###############################################################################
ETH_W <- list(
  `2011` = list(food = "sect5a_hh_w1", pre = "hh_s5aq", sep = "_", item = "hh_s5aq00", hhid = "household_id",  ukey = "b",       cf = "Food_CF_Wave1", oth = NULL),
  `2013` = list(food = "sect5a_hh_w2", pre = "hh_s5aq", sep = "_", item = "hh_s5aq00", hhid = "household_id2", ukey = "cf_unit", cf = "Food_CF_Wave2", oth = "_b_other"),
  `2015` = list(food = "sect5a_hh_w3", pre = "hh_s5aq", sep = "_", item = "item_cd",   hhid = "household_id2", ukey = "b",       cf = "Food_CF_Wave3", oth = "b_others3"),
  `2018` = list(food = "sect6a_hh_w4", pre = "s6aq",    sep = "",  item = "item_cd",   hhid = "household_id",  ukey = "b",       cf = "Food_CF_Wave4", oth = "b_os"),
  `2021` = list(food = "sect6a_hh_w5", pre = "s6aq",    sep = "",  item = "item_cd",   hhid = "household_id",  ukey = "b",       cf = "food_cf_wave5", oth = "b_os"))
## unita' metriche per wave (codici della wave): 2011-2013 1 grammo, 20 kg, 32 litro;
## 2015-2021 1 kg, 2 g, 3 quintale, 4 litro, 5 ml (dalle etichette dei valori)
ETH_METRIC <- list(old = c(`1` = 0.001, `20` = 1, `32` = 1), new = c(`1` = 1, `2` = 0.001, `3` = 100, `4` = 1, `5` = 0.001))
read_eth <- function(yr) {
  C <- ETH_W[[yr]]; p <- C$pre; s <- C$sep
  f <- rd(C$food, paste0("ETH_", yr))
  v <- function(k, x) paste0(p, k, s, x)
  oth <- function(k) { if (is.null(C$oth)) return(NULL)
    cand <- c(paste0(p, k, C$oth), paste0("s5aq", k, "b_others"), paste0(p, k, "b_os"))
    cand <- cand[cand %in% names(f)]; if (length(cand)) chr(f[[cand[1]]]) else NULL }
  out <- frame(idstr(f[[C$hhid]]), num(f[[C$item]]),
    cons_raw = col(f, paste0(p, "01")),
    q_tot = col(f, v("02", "a")), u_tot = col(f, v("02", "b"), chr),
    q_pur = col(f, v("03", "a")), u_pur = col(f, v("03", "b"), chr), exp_pur = col(f, paste0(p, "04")),
    q_own = col(f, v("05", "a")), u_own = col(f, v("05", "b"), chr),
    q_gift = col(f, v("06", "a")), u_gift = col(f, v("06", "b"), chr),
    uo_tot = oth("02"), uo_pur = oth("03"), uo_own = oth("05"), uo_gift = oth("06"))
  ## chiave dell'unita' per la tabella (2013: colonna _cf_unit, TRAP 3 della pipeline)
  key <- function(k) if (C$ukey == "cf_unit") col(f, paste0(p, k, "_cf_unit")) else col(f, v(k, "b"))
  out$k_tot <- key("02"); out$k_pur <- key("03"); out$k_own <- key("05"); out$k_gift <- key("06")
  cf <- rd(C$cf, paste0("ETH_", yr)) %>% transmute(cf_code = num(item_cd), unit = num(unit_cd), cfac = num(mean_cf_nat)) %>%
    filter(!is.na(cfac)) %>% group_by(cf_code, unit) %>% summarise(cfac = mean(cfac), .groups = "drop")
  attr(out, "conv") <- list(cf = cf, metric = if (yr %in% c("2011", "2013")) ETH_METRIC$old else ETH_METRIC$new)
  out
}
conv_eth <- function(d, mp) {
  cv <- attr(d, "conv"); d <- d %>% left_join(mp %>% select(code, cf_code), by = "code")
  one <- function(q, k) {
    x <- tibble(cf_code = d$cf_code, unit = k) %>% left_join(cv$cf, by = c("cf_code", "unit"))
    met <- unname(cv$metric[as.character(k)])
    fac <- ifelse(!is.na(d$cf_code), x$cfac, met)          # tabella ufficiale; metrico solo se la voce non c'e'
    q * fac
  }
  d %>% mutate(s_tot = one(q_tot, k_tot), s_pur = one(q_pur, k_pur), s_own = one(q_own, k_own), s_gift = one(q_gift, k_gift),
               conv_method = ifelse(!is.na(cf_code), "official table (Food_CF)", "metric units only")) %>%
    select(-cf_code, -k_tot, -k_pur, -k_own, -k_gift)
}

###############################################################################
## TANZANIA (NPS): codici di unita' 1 kg, 2 g, 3 litro, 4 ml, 5 pezzo; le unita'
## locali (6-20) restano non convertite. Uova: grammi a 55 g per uovo e codice 20
## "altro" del 2020 letto come pezzo (decisioni della pipeline, TRAP 6 e D6).
## Il 2020 ha due campioni distinti: hh_sec_ja1 (4.290 famiglie) e hh_sec_j1 (419).
###############################################################################
TZA_W <- list(
  `2008` = list(food = "SEC_K1",     hhid = "hhid",    style = "old"),
  `2010` = list(food = "HH_SEC_K1",  hhid = "y2_hhid", style = "new", pre = "hh_k", yn = "hh_k01_2"),
  `2012` = list(food = "HH_SEC_J1",  hhid = "y3_hhid", style = "new", pre = "hh_j"),
  `2014` = list(food = "hh_sec_j1",  hhid = "y4_hhid", style = "new", pre = "hh_j"),
  `2020` = list(food = "hh_sec_ja1", hhid = "y5_hhid", style = "new", pre = "hh_ja"))
read_tza <- function(yr) {
  C <- TZA_W[[yr]]; f <- rd(C$food, paste0("TZA_", yr))
  one <- function(f, C, part) {
    if (C$style == "old") v <- list(yn = "skq1", qt = "skq2_amount", ut = "skq2_meas", qp = "skq3_amount", up = "skq3_meas", e = "skq4",
                                   qo = "skq5_amount", uo = "skq5_meas", qg = "skq6_amount", ug = "skq6_meas", item = "skcode")
    else { p <- C$pre; v <- list(yn = if (!is.null(C$yn)) C$yn else paste0(p, "01"), qt = paste0(p, "02_2"), ut = paste0(p, "02_1"),
                                  qp = paste0(p, "03_2"), up = paste0(p, "03_1"), e = paste0(p, "04"), qo = paste0(p, "05_2"), uo = paste0(p, "05_1"),
                                  qg = paste0(p, "06_2"), ug = paste0(p, "06_1"), item = "itemcode") }
    frame(idstr(f[[C$hhid]]), num(f[[v$item]]), cons_raw = col(f, v$yn),
          q_tot = col(f, v$qt), u_tot = col(f, v$ut, chr), q_pur = col(f, v$qp), u_pur = col(f, v$up, chr), exp_pur = col(f, v$e),
          q_own = col(f, v$qo), u_own = col(f, v$uo, chr), q_gift = col(f, v$qg), u_gift = col(f, v$ug, chr),
          q_wt = col(f, if (C$style == "new") paste0(C$pre, "02b_2") else NULL), u_wt = col(f, if (C$style == "new") paste0(C$pre, "02b_1") else NULL, chr)) %>%
      mutate(module = part)
  }
  out <- one(f, C, C$food)
  if (yr == "2020") {                                       # le 419 famiglie del secondo campione
    j1 <- rd("hh_sec_j1", "TZA_2020"); C2 <- list(hhid = "y5_hhid", style = "new", pre = "hh_j")
    out <- bind_rows(out, one(j1, C2, "hh_sec_j1"))
  }
  out
}
conv_tza <- function(d, mp) {
  d <- d %>% left_join(mp %>% select(code, std), by = "code")
  fac <- function(u, std) { u <- num(u); case_when(
    std == "kg" & u == 1 ~ 1, std == "kg" & u == 2 ~ 1 / 1000,
    std == "litre" & u == 3 ~ 1, std == "litre" & u == 4 ~ 1 / 1000, std == "litre" & u == 1 ~ 1, std == "litre" & u == 2 ~ 1 / 1000,
    std == "piece" & u == 5 ~ 1,
    std == "piece" & d$code == 807 & u == 2 ~ 1 / 55, std == "piece" & d$code == 807 & u == 1 ~ 1000 / 55,
    std == "piece" & d$code == 807 & u == 20 & d$year == 2020 ~ 1,
    TRUE ~ NA_real_) }
  d %>% mutate(s_tot = q_tot * fac(u_tot, std), s_pur = q_pur * fac(u_pur, std), s_own = q_own * fac(u_own, std),
               s_gift = q_gift * fac(u_gift, std), conv_method = "metric units (codes 1-5)") %>% select(-std)
}

###############################################################################
## MALAWI (IHS): ogni fonte ha la sua unita' (con lettera di taglia nel 2010:
## "9A" vale come "9"). Si converte con il significato metrico (1 kg, 18 g, 15
## litro, 19 ml), il testo "altro (specificare)" quando dichiara una quantita'
## metrica, e la tabella ufficiale 2020 (kg per unita', per regione). Come nella
## pipeline, per la carne rossa, il pesce e "altro pollame" la tabella NON si usa
## (i prezzi la smentiscono); per pollo intero, latte fresco e in polvere si'.
## Per legumi, arachidi, frutta a guscio, semi e soia la tabella si usa: e' una
## scelta nuova di questo dataset, segnalata (conv_method).
###############################################################################
MWI_W <- list(`2010` = "MWI_2010_IHS-III.*Full_Sample", `2016` = "MWI_2016_IHS-IV", `2019` = "MWI_2019_IHS-V", `2024` = "MWI_2024-2025_IHS-VI")
MWI_CF_OK_ASF <- c(508, 701, 702)
read_mwi <- function(yr) {
  h <- MWI_W[[yr]]; f <- rd("hh_mod_g1", h)
  cvr <- rd("hh_mod_a_filt", h)
  dist <- num(if ("district" %in% names(cvr)) cvr$district else cvr$hh_a01)
  reg3 <- tibble(hhid = idstr(cvr$case_id), region3 = if ("region" %in% names(cvr)) num(cvr$region) else floor(dist / 100)) %>% distinct(hhid, .keep_all = TRUE)
  oth <- function(b) { v <- intersect(paste0(b, c("_oth", "_os")), names(f)); if (length(v)) chr(f[[v[1]]]) else NULL }
  sub <- function(b) { v <- intersect(paste0(b, c("c", "c_1")), names(f)); if (length(v)) chr(f[[v[1]]]) else NULL }
  out <- frame(idstr(f$case_id), num(f$hh_g02), cons_raw = col(f, "hh_g01"),
    q_tot = col(f, "hh_g03a"), u_tot = col(f, "hh_g03b", chr), q_pur = col(f, "hh_g04a"), u_pur = col(f, "hh_g04b", chr), exp_pur = col(f, "hh_g05"),
    q_own = col(f, "hh_g06a"), u_own = col(f, "hh_g06b", chr), q_gift = col(f, "hh_g07a"), u_gift = col(f, "hh_g07b", chr),
    uo_tot = oth("hh_g03b"), uo_pur = oth("hh_g04b"), uo_own = oth("hh_g06b"), uo_gift = oth("hh_g07b"),
    us_tot = sub("hh_g03"), us_pur = sub("hh_g04"), us_own = sub("hh_g06"), us_gift = sub("hh_g07"))
  lab <- function(b) { v <- paste0(b, "_label"); if (v %in% names(f)) as.character(haven::as_factor(f[[v]])) else rep(NA_character_, nrow(f)) }
  out$lab_tot <- lab("hh_g03b"); out$lab_pur <- lab("hh_g04b"); out$lab_own <- lab("hh_g06b"); out$lab_gift <- lab("hh_g07b")
  out <- out %>% left_join(reg3, by = "hhid")
  cfp <- find_dta("ihs_foodconversion_factor_2020", "MWI_2019")
  attr(out, "cf") <- if (is.na(cfp)) NULL else haven::read_dta(cfp) %>%
    transmute(region3 = num(region), code = num(item_code), unit = trimws(as.character(unit_code)), factor = num(factor)) %>%
    filter(unit != "23", !is.na(factor), !(code == 702 & unit == "20")) %>%
    group_by(region3, code, unit) %>% summarise(cf = mean(factor), .groups = "drop")
  out
}
oth_mw <- function(o, code, std, sachet) {             # come nella pipeline (TRAP M3)
  o  <- toupper(trimws(ifelse(is.na(o), "", as.character(o))))
  o  <- sub("[.]+$", "", gsub("([0-9]),([0-9])", "\\1.\\2", o))
  KG <- "(KGS?|KILOS?|KILOGRAMM?E?S?)"; G <- "(GS?|GRMS?|GRAMM?E?S?|GARAMS?)"
  ML <- "(MLS?|MIL|MILL?I?LIT(RE|ER)S?|MILL?IT(RE|ER)S?|MILITRES?|MILLIMETRES?|MILLIGRAMS?)"
  amt <- function(re) { x <- rep(NA_real_, length(o)); pat <- paste0("([0-9]+[.]?[0-9]*) ?", re, "\\b")
    hit <- grepl(pat, o, perl = TRUE); x[hit] <- suppressWarnings(as.numeric(sub(paste0("^.*?", pat, ".*$"), "\\1", o[hit], perl = TRUE))); x }
  kg <- amt(KG); g <- amt(G) / 1000; ml <- amt(ML) / 1000
  case_when(
    std == "piece" & grepl("^(TRAY|TREY|TRY|CRATE|CRETE)S?$", o) ~ 30, std == "piece" & o == "DOZEN" ~ 12,
    std == "piece" & grepl("^(PIECE|PEACE|PEICE)S?( ?[(].*[)])?$", o) ~ 1,
    code == 508 & grepl("^HALF", o) & grepl("CHICKEN|WHOLE", o) ~ 0.63,
    code == 508 & grepl("WHOLE|FULL|^([0-9]+ )?CHICKENS?$", o) & !grepl("HALF|PIECES? OF", o) ~ 1.26,
    std %in% c("kg", "litre") & !is.na(kg) ~ kg, std %in% c("kg", "litre") & !is.na(g) ~ g, std == "litre" & !is.na(ml) ~ ml,
    std %in% c("kg", "litre") & grepl(paste0("^HALF ", KG, "$"), o) ~ 0.5, std %in% c("kg", "litre") & grepl(paste0("^", KG, "$"), o) ~ 1,
    std == "kg" & grepl(paste0("^", G, "$"), o) ~ 1 / 1000, std == "litre" & grepl(paste0("^", ML, "$"), o) ~ 1 / 1000,
    code %in% c(701, 702) & grepl("SA?T?CHET|SACHET", o) ~ sachet,
    code == 701 & grepl("^(SMALL )?PACKETS?( [(]SMALL[)]| UNSPECIFIED)?$", o) ~ sachet,
    TRUE ~ NA_real_)
}
conv_mwi <- function(d, mp) {
  cf <- attr(d, "cf"); d <- d %>% left_join(mp %>% select(code, std, cat), by = "code")
  use_cf <- d$code %in% MWI_CF_OK_ASF | d$cat == "plant"
  tab <- function(u) if (is.null(cf)) rep(NA_real_, length(u)) else cf$cf[match(paste(d$region3, d$code, u), paste(cf$region3, cf$code, cf$unit))]
  one <- function(q, unit, oth, lab) {
    u <- sub("[A-Za-z]+$", "", trimws(as.character(unit)))
    t_u <- tab(u); t_sachet <- tab(rep("22", length(u)))
    ot <- oth_mw(oth, d$code, d$std, t_sachet)
    la <- toupper(ifelse(is.na(lab), "", lab))
    la_g <- suppressWarnings(as.numeric(ifelse(grepl("[0-9] ?G\\b", la), sub("^.*?([0-9]+) ?G\\b.*$", "\\1", la, perl = TRUE), NA))) / 1000
    fac <- case_when(
      is.na(u) | u == "" ~ NA_real_,
      d$std == "piece" & u == "9" ~ 1,
      d$std %in% c("kg", "litre") & u == "1" ~ 1,
      d$std == "kg" & u == "18" ~ 1 / 1000,
      d$std == "litre" & u == "15" ~ 1, d$std == "litre" & u == "19" ~ 1 / 1000,
      u == "23" ~ ot,
      d$std %in% c("kg", "litre") & grepl("^TIN", la) & !is.na(la_g) ~ la_g,
      d$code == 701 & u %in% c("51", "60") ~ t_sachet,
      use_cf & !is.na(t_u) ~ t_u,
      TRUE ~ NA_real_)
    q * fac
  }
  d %>% mutate(s_tot = one(q_tot, u_tot, uo_tot, lab_tot), s_pur = one(q_pur, u_pur, uo_pur, lab_pur),
               s_own = one(q_own, u_own, uo_own, lab_own), s_gift = one(q_gift, u_gift, uo_gift, lab_gift),
               conv_method = ifelse(use_cf, "metric, 'other' text, official 2020 table", "metric and 'other' text only (table not used)")) %>%
    select(-std, -cat, -region3, -lab_tot, -lab_pur, -lab_own, -lab_gift)
}

###############################################################################
## NIGERIA (GHS-Panel, visita post-raccolto): 2012 e 2015 con le tabelle di
## conversione dell'indagine (2012 in grammi o centilitri), con ripiego metrico
## (1 kg, 2 g, 3 litro, 4 centilitro); 2010 senza tabella: solo unita' metriche
## lette dalle etichette. Fonti: 2010 q5 autoproduzione, q6 regali; 2012-2015
## q5 "dagli acquisti", q6 autoproduzione, q7 regali (TRAP N3).
###############################################################################
NGA_W <- list(`2010` = list(food = "sect10b_harvestw1", own = "5", gift = "6", frompur = NULL, conv = NULL),
              `2012` = list(food = "sect10b_harvestw2", own = "6", gift = "7", frompur = "5", conv = "food_conv_w2ph"),
              `2015` = list(food = "sect10b_harvestw3", own = "6", gift = "7", frompur = "5", conv = "food_conv_w3"))
read_nga <- function(yr) {
  C <- NGA_W[[yr]]; f <- rd(C$food, paste0("NGA_", yr)); p <- "s10bq"
  q <- function(k) col(f, paste0(p, k, "a")); u <- function(k) col(f, paste0(p, k, "b"), chr)
  uo <- function(k) { v <- paste0(p, k, "b_os"); if (v %in% names(f)) chr(f[[v]]) else NULL }
  out <- frame(idstr(f$hhid), num(f$item_cd), cons_raw = col(f, "s10bq1"),
    q_tot = q("2"), u_tot = u("2"), q_pur = q("3"), u_pur = u("3"), exp_pur = col(f, "s10bq4"),
    q_own = q(C$own), u_own = u(C$own), q_gift = q(C$gift), u_gift = u(C$gift),
    q_frompur = if (!is.null(C$frompur)) q(C$frompur) else NULL, u_frompur = if (!is.null(C$frompur)) u(C$frompur) else NULL,
    uo_tot = uo("2"), uo_pur = uo("3"), uo_own = uo(C$own), uo_gift = uo(C$gift))
  if (!is.null(C$conv)) {
    cv <- rd(C$conv, paste0("NGA_", yr)); key <- if ("nsu_cd" %in% names(cv)) "nsu_cd" else "unit_cd"
    val <- if ("conv" %in% names(cv)) "conv" else "conv_national"
    div <- if ("g_cl" %in% names(cv)) ifelse(num(cv$g_cl) == 1, 1000, 100) else 1
    attr(out, "cv") <- tibble(code = num(cv$item_cd), unit = num(cv[[key]]), cf = num(cv[[val]]) / div) %>%
      filter(!is.na(cf)) %>% group_by(code, unit) %>% summarise(cf = mean(cf), .groups = "drop")
  } else {
    lv <- attr(f$s10bq2b, "labels"); low <- tolower(trimws(names(lv)))
    kg <- ifelse(low %in% c("kilograms", "kilogram", "kg"), 1, ifelse(low %in% c("grams", "gram"), 1 / 1000,
          ifelse(low %in% c("litres", "litre"), 1, ifelse(low %in% c("mililitre", "millilitre", "ml"), 1 / 1000, NA))))
    attr(out, "lab") <- setNames(kg, as.character(as.numeric(lv)))
  }
  out
}
conv_nga <- function(d, mp) {
  cv <- attr(d, "cv"); lab <- attr(d, "lab"); metric <- c(`1` = 1, `2` = 0.001, `3` = 1, `4` = 0.01)
  one <- function(q, u) { u <- num(u)
    if (!is.null(cv)) { t <- cv$cf[match(paste(d$code, u), paste(cv$code, cv$unit))]; t <- ifelse(is.na(t), unname(metric[as.character(u)]), t) }
    else t <- unname(lab[as.character(u)])
    q * t }
  d %>% mutate(s_tot = one(q_tot, u_tot), s_pur = one(q_pur, u_pur), s_own = one(q_own, u_own), s_gift = one(q_gift, u_gift),
               s_frompur = if (all(is.na(q_frompur))) NA_real_ else one(q_frompur, u_frompur),
               conv_method = if (!is.null(cv)) "survey conversion table, metric fallback" else "metric units from labels only")
}

###############################################################################
## UGANDA (UNPS): una sola unita' per tutte le fonti; si converte solo dalla sua
## ETICHETTA quando dichiara una quantita' metrica (TRAP U4); pollo intero o a
## pezzi 1,3 kg per capo (FAO, TRAP U3); "Nice cup" del latte 0,5 l. Fonti:
## acquisti a casa, acquisti fuori casa, autoproduzione, regali, ciascuna con
## quantita' e valore. Il totale consumato del 2010-2015 (h15bq14) c'e' solo in
## quelle wave; qui il totale e' la somma delle quattro fonti, come nella pipeline.
###############################################################################
UGA_W <- list(`2010` = list(food = "GSEC15b", id = "hh",   style = "old"), `2011` = list(food = "GSEC15B", id = "HHID", style = "old"),
              `2013` = list(food = "GSEC15B", id = "hhid", style = "old"), `2015` = list(food = "gsec15b", id = "hh",   style = "old"),
              `2018` = list(food = "GSEC15B", id = "hhid", style = "new"), `2019` = list(food = "gsec15b", id = "hhid", style = "new"))
read_uga <- function(yr) {
  C <- UGA_W[[yr]]; f <- rd(C$food, paste0("UGA_", yr))
  v <- if (C$style == "old") list(item = "itmcd", unit = "untcd", yn = "h15bq3a", qp = "h15bq4", vp = "h15bq5", qa = "h15bq6", va = "h15bq7",
                                  qo = "h15bq8", vo = "h15bq9", qg = "h15bq10", vg = "h15bq11", qt = "h15bq14")
       else list(item = "CEB01", unit = "CEB03C", yn = "CEB03", qp = "CEB06", vp = "CEB07", qa = "CEB08", va = "CEB09",
                 qo = "CEB10", vo = "CEB11", qg = "CEB012", vg = "CEB013", qt = NULL)
  lv <- attr(f[[v$unit]], "labels"); uc <- num(f[[v$unit]])
  out <- frame(idstr(f[[C$id]]), num(f[[v$item]]), cons_raw = col(f, v$yn),
    q_tot = col(f, v$qt), u_tot = col(f, v$unit, chr), q_pur = col(f, v$qp), u_pur = col(f, v$unit, chr), exp_pur = col(f, v$vp),
    q_own = col(f, v$qo), u_own = col(f, v$unit, chr), q_gift = col(f, v$qg), u_gift = col(f, v$unit, chr),
    q_away = col(f, v$qa), val_away = col(f, v$va), val_own = col(f, v$vo), val_gift = col(f, v$vg))
  out$ulab <- if (!is.null(lv)) names(lv)[match(uc, as.numeric(lv))] else NA_character_
  out
}
conv_ug <- function(lab, std) {                        # come nella pipeline
  l <- tolower(gsub("\\s+", " ", trimws(lab)))
  g  <- suppressWarnings(as.numeric(sub("^(packet|sacket|nido tin) ?\\(([0-9.]+) ?g\\).*$", "\\2", l)))
  lt <- suppressWarnings(as.numeric(sub("^.*\\(([0-9.]+) ?lt\\).*$", "\\1", l)))
  ncg <- suppressWarnings(as.numeric(sub("^.*\\(([0-9.]+) ?g\\).*$", "\\1", l)))
  case_when(is.na(l) ~ NA_real_,
    std == "piece" & grepl("^tray of 30", l) ~ 30, std == "piece" & grepl("^(number of units|piece)", l) ~ 1,
    std %in% c("kg", "litre") & grepl("^kilogram", l) ~ 1, std %in% c("kg", "litre") & grepl("^gram", l) ~ 1 / 1000,
    std %in% c("kg", "litre") & grepl("^packet ?\\(1 ?kg\\)", l) ~ 1, std %in% c("kg", "litre") & !is.na(g) ~ g / 1000,
    std == "kg" & !is.na(ncg) ~ ncg / 1000, std == "litre" & grepl("^litre", l) ~ 1, std == "litre" & !is.na(lt) ~ lt,
    std == "litre" & grepl("^nice cup", l) ~ 0.5, TRUE ~ NA_real_)
}
conv_uga <- function(d, mp) {
  d <- d %>% left_join(mp %>% select(code, std, cat, sub), by = "code")
  k <- conv_ug(d$ulab, d$std)
  chick <- d$cat == "meat" & d$sub == "white" & d$code %in% c(121, 1211, 1212, 1213, 1214)
  k <- ifelse(chick & is.na(k) & grepl("^(piece|whole chicken)", tolower(trimws(d$ulab))), 1.3, k)
  d %>% mutate(s_pur = q_pur * k, s_own = q_own * k, s_gift = q_gift * k, s_away = q_away * k,
               s_tot = { s <- rowSums(cbind(q_pur, q_away, q_own, q_gift), na.rm = TRUE); ifelse(s > 0, s * k, NA_real_) },
               conv_method = "unit label (metric content); chicken 1.3 kg per bird") %>%
    select(-std, -cat, -sub, -ulab)
}

###############################################################################
## PER OGNI WAVE: tutte le voci del modulo (per la spesa alimentare totale a 7
## giorni), poi solo le voci della mappa, poi la griglia completa famiglie x voci
###############################################################################
READ <- list(ETH = read_eth, TZA = read_tza, MWI = read_mwi, NGA = read_nga, UGA = read_uga)
CONV <- list(ETH = conv_eth, TZA = conv_tza, MWI = conv_mwi, NGA = conv_nga, UGA = conv_uga)
ONLY_CONSUMED <- c("NGA_2010", "UGA_2010", "UGA_2011", "UGA_2013", "UGA_2015")   # il modulo elenca solo le voci consumate
ROUNDS <- list(ETH = names(ETH_W), TZA = names(TZA_W), MWI = names(MWI_W), NGA = names(NGA_W), UGA = names(UGA_W))

LOG <- list(); HH <- list()
for (cc in names(ROUNDS)) {
  LONG <- list()
  for (yr in ROUNDS[[cc]]) {
    t0 <- Sys.time()
    d <- READ[[cc]](yr)
    keep_attr <- Filter(Negate(is.null), attributes(d)[c("conv", "cf", "cv", "lab")])
    d$year <- as.numeric(yr)
    ## spesa alimentare a 7 giorni del modulo, TUTTE le voci (anche non proteiche)
    hh <- d %>% group_by(hhid) %>% summarise(food_exp_7d_module = sum(exp_pur, na.rm = TRUE),
                                             n_item_rows = n(), .groups = "drop") %>%
      mutate(country = cc, year = as.numeric(yr))
    if (cc == "TZA") hh <- hh %>% left_join(d %>% distinct(hhid, module), by = "hhid")
    HH[[paste(cc, yr)]] <- hh
    mp <- MAP %>% filter(country == cc, floor(year) == as.numeric(yr)) %>% distinct(code, .keep_all = TRUE)
    if (cc == "TZA" && yr == "2020") mp <- MAP %>% filter(country == cc, floor(year) == 2020) %>% distinct(code, .keep_all = TRUE)
    x <- d %>% filter(code %in% mp$code)
    for (a in names(keep_attr)) attr(x, a) <- keep_attr[[a]]
    x <- CONV[[cc]](x, mp)
    ## righe duplicate famiglia x voce nel modulo (non dovrebbero esserci): si segnalano e si tengono separate
    dup <- x %>% count(hhid, code) %>% filter(n > 1)
    ## griglia completa: famiglie del modulo x voci chieste in questa wave
    grid_codes <- if (cc == "TZA" && yr == "2020") {
      bind_rows(tibble(module = "hh_sec_ja1", code = MAP$code[MAP$country == "TZA" & MAP$year == 2020]),
                tibble(module = "hh_sec_j1",  code = MAP$code[MAP$country == "TZA" & MAP$year == 2020.1])) %>%
        inner_join(hh %>% select(hhid, module), by = "module", relationship = "many-to-many") %>% select(hhid, code)
    } else tidyr::crossing(hhid = hh$hhid, code = mp$code)
    if (cc == "TZA") x <- x %>% select(-module)
    x <- grid_codes %>% left_join(x, by = c("hhid", "code")) %>% mutate(year = as.numeric(yr), country = cc)
    oc <- paste(cc, yr, sep = "_") %in% ONLY_CONSUMED
    any_q <- function(z) rowSums(cbind(z$q_tot, z$q_pur, z$q_own, z$q_gift, z$exp_pur, z$q_away) > 0, na.rm = TRUE) > 0
    x <- x %>% mutate(
      row_in_module = as.integer(!is.na(cons_raw) | any_q(x)),
      cons = case_when(cons_raw == 1 | any_q(x) ~ 1, cons_raw == 2 ~ 0,
                       is.na(cons_raw) & row_in_module == 0 & oc ~ 0, TRUE ~ NA_real_),
      across(c(s_tot, s_pur, s_own, s_gift), ~ ifelse(cons %in% 0, 0, .x)))
    if (!"s_away" %in% names(x)) x$s_away <- NA_real_
    if (!"s_frompur" %in% names(x)) x$s_frompur <- NA_real_
    x$s_away <- ifelse(x$cons %in% 0 & cc == "UGA", 0, x$s_away)
    x$s_frompur <- ifelse(x$cons %in% 0 & cc == "NGA" & yr != "2010", 0, x$s_frompur)
    ## Uganda: il questionario riempie solo le fonti usate; una fonte senza quantita'
    ## e senza valore e' una fonte non usata (zero strutturale, non un dato mancante)
    if (cc == "UGA") x <- x %>% mutate(
      s_pur  = ifelse(cons %in% 1 & is.na(q_pur)  & is.na(exp_pur),  0, s_pur),
      s_away = ifelse(cons %in% 1 & is.na(q_away) & is.na(val_away), 0, s_away),
      s_own  = ifelse(cons %in% 1 & is.na(q_own)  & is.na(val_own),  0, s_own),
      s_gift = ifelse(cons %in% 1 & is.na(q_gift) & is.na(val_gift), 0, s_gift))
    ## spesa d'acquisto armonizzata (7 giorni, valuta locale): 0 se la voce non e'
    ## consumata o non e' stata comprata (quantita' comprata 0 o spesa 0; in Uganda
    ## nessuna quantita' e nessun valore comprati); il valore dichiarato se positivo;
    ## NA se comprata ma senza valore. In Uganda sono gli acquisti consumati a casa,
    ## come nella pipeline; gli acquisti fuori casa restano in val_away.
    x <- x %>% mutate(exp = case_when(
      cons %in% 0 ~ 0,
      exp_pur > 0 ~ exp_pur,
      cons %in% 1 & exp_pur %in% 0 & (is.na(q_pur) | q_pur %in% 0) ~ 0,
      cons %in% 1 & q_pur %in% 0 & is.na(exp_pur) ~ 0,
      cons %in% 1 & cc == "UGA" & is.na(q_pur) & is.na(exp_pur) ~ 0,
      TRUE ~ NA_real_))
    ## segnali di coerenza: 8 risposta "no" ma quantita' o spesa dichiarate (consumo
    ## posto a 1); 16 risposta "si'" senza quantita' ne' spesa; 32 acquisto incoerente
    ## (quantita' comprata senza spesa positiva, o spesa con quantita' comprata 0);
    ## 64 consumata ma quantita' totale non convertibile nell'unita' standard
    x <- x %>% mutate(flag_c =
      8L  * as.integer(cons_raw %in% 2 & cons %in% 1) +
      16L * as.integer(cons_raw %in% 1 & !any_q(x)) +
      32L * as.integer(((q_pur > 0) %in% TRUE & !((exp_pur > 0) %in% TRUE)) | ((exp_pur > 0) %in% TRUE & q_pur %in% 0)) +
      64L * as.integer(cons %in% 1 & is.na(s_tot)))
    x$conv_method <- ifelse(is.na(x$conv_method), NA, x$conv_method)
    LOG[[paste(cc, yr)]] <- tibble(country = cc, year = as.numeric(yr), households = nrow(hh), items_mapped = nrow(mp),
                                   item_rows = nrow(x), consumed_rows = sum(x$cons %in% 1), cons_missing = sum(is.na(x$cons)),
                                   duplicated_hh_item = nrow(dup), only_consumed_listed = oc,
                                   seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    cat(sprintf("%s %s: %5d households, %3d items, %7d rows, %6d consumed, %d duplicated hh x item  (%ss)\n",
                cc, yr, nrow(hh), nrow(mp), nrow(x), sum(x$cons %in% 1), nrow(dup), LOG[[paste(cc, yr)]]$seconds))
    LONG[[yr]] <- x
  }
  L <- bind_rows(LONG)
  ## segnali (non cancellazioni): prezzo implicito fuori da 1/10-10 volte la mediana
  ## della voce nella wave (1), quantita' totale oltre 100 volte la mediana (2),
  ## spesa oltre 100 volte la mediana (4) - le soglie delle regole M17 e M18
  L <- L %>% left_join(MAP %>% mutate(year = floor(year)) %>% distinct(country, year, code, slot), by = c("country", "year", "code")) %>%
    group_by(year, slot) %>%
    mutate(.p = ifelse(s_pur > 0 & exp_pur > 0, exp_pur / s_pur, NA), .mp = median(.p, na.rm = TRUE),
           .mt = median(s_tot[s_tot > 0], na.rm = TRUE), .me = median(exp_pur[exp_pur > 0], na.rm = TRUE)) %>% ungroup() %>%
    mutate(flag = 1L * coalesce(.p > 10 * .mp | .p < .mp / 10, FALSE) + 2L * coalesce(s_tot > 100 * .mt, FALSE) +
                  4L * coalesce(exp_pur > 100 * .me, FALSE) + flag_c) %>% select(-.p, -.mp, -.mt, -.me, -flag_c)
  write.csv(L, gzfile(file.path(OUTD, paste0("long_", cc, ".csv.gz"))), row.names = FALSE, na = "")
  rm(L, LONG); gc()
}
write.csv(bind_rows(HH), file.path(OUTD, "module_households.csv"), row.names = FALSE, na = "")
write.csv(bind_rows(LOG), file.path(OUTD, "build_log.csv"), row.names = FALSE)
cat("done\n")
