###############################################################################
##  TANZANIA: DATI GREZZI ARMONIZZATI PER IL LA/AIDS (24 nov 2026)
##
##  Produce l'Excel di partenza dello script TZA_LAAIDS.R: SOLO valori originali dei moduli NPS, armonizzati
##  nei nomi tra i 5 round (2008, 2010, 2012, 2014, 2020). Nessuna conversione, nessun prezzo, nessuna imputazione.
##   - foglio voci: una riga per famiglia x voce CONSUMATA nei 7 giorni (modulo K1 nel 2008-2010, J1 nel 2012-2014,
##     JA1 e J1 nel 2020), con quantita' e unita' per fonte e spesa dichiarata;
##   - foglio famiglie: geografia (regione, distretto, ward, EA dei file di copertina), peso, caratteristiche,
##     spesa totale annua ufficiale (strumento per la spesa alimentare);
##   - fogli unita' e voci_gruppi: codici delle unita' e classificazione voce -> categoria -> gruppo (approvata il 24 nov).
##  Le righe vengono dai lettori di build_protein_dataset.R (allfood_long_TZA.csv.gz di build_allfood_long.R).
##  USO  Rscript tza_dati_grezzi.R <_unzipped> <allfood_long_TZA.csv.gz> <_wide_check.csv.gz> <food_category_map.csv> <unit_codes.csv> <uscita.xlsx>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(readr); library(openxlsx) })
a <- commandArgs(TRUE); U <- a[1]
num <- function(x) suppressWarnings(as.numeric(zap_labels(x)))
idstr <- function(x) { x <- zap_labels(x); if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x)) }
trova <- function(pat, hint) { f <- list.files(U, pattern = pat, recursive = TRUE, full.names = TRUE); f <- f[grepl(hint, f)]; stopifnot(length(f) >= 1); f[1] }

GRUPPO <- c(cereals = "cereali", starches = "tuberi", pulses_dry = "legumi_noci_semi", pulses_fresh = "legumi_noci_semi", groundnuts = "legumi_noci_semi",
            soy = "legumi_noci_semi", nuts = "legumi_noci_semi", seeds = "legumi_noci_semi", fruits = "frutta_verdura", vegetables = "frutta_verdura",
            beef = "carne_rossa", goat_sheep = "carne_rossa", pork = "carne_rossa", processed_red_meat = "carne_rossa", meat_other = "carne_rossa",
            poultry = "pollame", fish_fresh = "pesce", fish_processed = "pesce", milk_fresh = "latte", dairy_processed = "latte", eggs = "uova",
            oils_fats = "altro", sugar_sweets = "altro", spices_other = "altro", beverages = "altro", other_food = "altro", excluded = "escluso")

## classificazione delle voci (solo Tanzania)
M <- read_csv(a[4], col_types = cols(.default = col_character()), progress = FALSE) %>% filter(country == "TZA", category != "header") %>%
  transmute(round = as.integer(round), campione = ifelse(is.na(sample), "", sample), codice_voce = as.integer(code), voce = clean_label,
            categoria = category, gruppo = unname(GRUPPO[category]), famiglie_che_consumano = as.numeric(hh_consuming))
stopifnot(!any(is.na(M$gruppo)))

## voci consumate, valori originali
L <- read_csv(a[2], col_types = cols(.default = col_character()), progress = FALSE) %>% filter(cons == "1")
nn <- function(x) suppressWarnings(as.numeric(x))
V <- L %>% transmute(round = as.integer(year), hhid, campione = ifelse(as.integer(year) == 2020, module, ""), codice_voce = as.integer(code),
                     q_tot = nn(q_tot), u_tot = nn(u_tot), q_acq = nn(q_pur), u_acq = nn(u_pur), spesa_acq = nn(exp_pur),
                     q_auto = nn(q_own), u_auto = nn(u_own), q_regali = nn(q_gift), u_regali = nn(u_gift)) %>%
  left_join(M %>% select(round, campione, codice_voce, voce, categoria, gruppo), by = c("round", "campione", "codice_voce")) %>%
  relocate(voce, categoria, gruppo, .after = codice_voce) %>% arrange(round, hhid, codice_voce)
stopifnot(!any(is.na(V$gruppo)))

## famiglie: geografia dai file di copertina, il resto dal dataset armonizzato
cop <- list(
  `2008` = list("^SEC_A_T\\.dta$", "TZA_2008", "hhid", "region", "district", "ward", "ea"),
  `2010` = list("^HH_SEC_A\\.dta$", "TZA_2010", "y2_hhid", "region", "district", "ward", "ea"),
  `2012` = list("^HH_SEC_A\\.dta$", "TZA_2012", "y3_hhid", "hh_a01_1", "hh_a02_1", "hh_a03_1", "hh_a04_1"),
  `2014` = list("^hh_sec_a\\.dta$", "TZA_2014", "y4_hhid", "hh_a01_1", "hh_a02_1", "hh_a03_1", "hh_a04_1"),
  `2020` = list("^hh_sec_a\\.dta$", "TZA_2020", "y5_hhid", "hh_a01_1", "hh_a02_1", "hh_a03_1", "hh_a04_1"))
G <- bind_rows(lapply(names(cop), function(y) { k <- cop[[y]]; d <- read_dta(trova(k[[1]], k[[2]]))
  ## 2020: il codice EA (hh_a04_1) manca per 3.893 famiglie su 4.709; si usa y5_cluster, il cluster (EA) del campione,
  ## dentro il distretto dove la famiglia vive ora (le famiglie seguite dopo un trasloco restano nel cluster d'origine)
  tibble(round = as.integer(y), hhid = idstr(d[[k[[3]]]]), regione = num(d[[k[[4]]]]), distretto = num(d[[k[[5]]]]),
         ward = num(d[[k[[6]]]]), ea = if (y == "2020") as.character(d$y5_cluster) else as.character(num(d[[k[[7]]]]))) })) %>%
  distinct(round, hhid, .keep_all = TRUE)
H <- read_csv(a[3], col_types = cols(.default = col_character()), progress = FALSE,
              col_select = c(country, year, hhid, weight, rural, hhsize, adulteq, int_month, head_female, head_age, cons_total_hh_annual)) %>%
  filter(country == "TZA") %>% transmute(round = as.integer(year), hhid, peso = nn(weight), rurale = nn(rural), ampiezza = nn(hhsize), adulti_eq = nn(adulteq),
                                         mese_intervista = nn(int_month), capo_donna = nn(head_female), eta_capo = nn(head_age), spesa_totale_annua = nn(cons_total_hh_annual))
camp <- V %>% filter(round == 2020) %>% distinct(hhid, campione)
F <- H %>% left_join(G, by = c("round", "hhid")) %>% left_join(camp, by = "hhid") %>%
  mutate(campione = ifelse(round == 2020, coalesce(campione, ""), ""),
         id_distretto = ifelse(is.na(distretto), NA, paste(regione, distretto, sep = "-")),
         id_ea = ifelse(is.na(ea), NA, ifelse(round == 2020, paste(regione, distretto, ea, sep = "-"), paste(regione, distretto, ward, ea, sep = "-")))) %>%
  select(round, hhid, campione, regione, distretto, ward, ea, id_distretto, id_ea, peso, rurale, ampiezza, adulti_eq, mese_intervista,
         capo_donna, eta_capo, spesa_totale_annua) %>% arrange(round, hhid)
cat("famiglie senza geografia:", sum(is.na(F$regione)), " | voci di famiglie non in elenco:", sum(!V$hhid %in% F$hhid), "\n")
print(F %>% group_by(round) %>% summarise(famiglie = n(), regione_NA = sum(is.na(regione)), distretto_NA = sum(is.na(distretto)), ea_NA = sum(is.na(ea)),
                                          peso_NA = sum(is.na(peso)), spesa_tot_NA = sum(is.na(spesa_totale_annua))))

## unita'
UN <- read_csv(a[5], col_types = cols(.default = col_character()), show_col_types = FALSE) %>% filter(country == "TZA", !is.na(label)) %>%
  transmute(round = as.integer(year), codice = as.integer(code), etichetta = label) %>% distinct(round, codice, .keep_all = TRUE) %>% arrange(round, codice)

LEGGI <- data.frame(Foglio = c("voci", "", "", "", "", "famiglie", "", "", "unita", "voci_gruppi", "Fonte", "Nota"), Contenuto = c(
  "Una riga per famiglia x voce alimentare CONSUMATA negli ultimi 7 giorni (le voci non consumate non ci sono). Valori originali, nessuna conversione.",
  "q_tot / u_tot: quantita' totale consumata e codice unita'; q_acq / u_acq: quantita' venuta dagli acquisti e unita'; spesa_acq: quanto ha speso (TSH).",
  "q_auto / u_auto: quantita' da autoproduzione e unita'; q_regali / u_regali: quantita' da regali e altre fonti e unita'. Unita' 0 o vuota = fonte non usata.",
  "categoria: una delle 26 categorie del dataset armonizzato; gruppo: i 10 gruppi del LA/AIDS (cereali, tuberi, legumi_noci_semi, frutta_verdura, carne_rossa, pollame, pesce, latte, uova, altro); 'escluso' = fuori dal bilancio (burro-margarina, uccelli selvatici e insetti).",
  "campione (solo 2020): hh_sec_ja1 = campione principale (4.290 famiglie); hh_sec_j1 = 419 famiglie con il modulo di consumo alternativo.",
  "Una riga per famiglia x round. regione, distretto, ward, ea: codici dei file di copertina (SEC_A_T, HH_SEC_A, hh_sec_a); 2020: ea = y5_cluster (il codice EA del file manca per l'83% delle famiglie). Il codice del distretto si ripete tra regioni: usa id_distretto e id_ea.",
  "peso: peso campionario; rurale 1/0; ampiezza: membri; capo_donna 1/0; spesa_totale_annua: consumo totale annuo della famiglia (aggregato ufficiale NPS, TSH nominali).",
  "Famiglie senza voci nel foglio voci: nessun consumo a casa nei 7 giorni (mangiano solo fuori casa).",
  "Codici delle unita' per round: 1 kg, 2 grammi, 3 litri, 4 millilitri, 5 pezzi; dal 2020 anche unita' locali (6 mucchio, 7 casco, ...).",
  "Ogni codice voce del questionario con la sua categoria e il gruppo, e quante famiglie lo consumano.",
  "World Bank LSMS-ISA, Tanzania National Panel Survey 2008/09, 2010/11, 2012/13, 2014/15, 2020/21 (microdata.worldbank.org). Uso solo di ricerca: non ridistribuire.",
  "Costruito con tza_dati_grezzi.R (github.com/paolo-medei/PhD, code/analysis)."))
wb <- createWorkbook(); hs <- createStyle(textDecoration = "bold", fgFill = "#DDEBF7", border = "TopBottomLeftRight")
for (s in list(list("LEGGIMI", LEGGI), list("voci", V), list("famiglie", F), list("unita", UN), list("voci_gruppi", M))) {
  addWorksheet(wb, s[[1]]); writeData(wb, s[[1]], s[[2]], headerStyle = hs); freezePane(wb, s[[1]], firstRow = TRUE)
  setColWidths(wb, s[[1]], 1:ncol(s[[2]]), if (s[[1]] == "LEGGIMI") c(12, 150) else "auto") }
saveWorkbook(wb, a[6], overwrite = TRUE)
cat("voci:", nrow(V), " famiglie:", nrow(F), "\n"); print(table(V$round, V$gruppo))
