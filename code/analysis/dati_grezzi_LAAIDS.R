###############################################################################
##  DATI GREZZI ARMONIZZATI PER IL LA/AIDS - ETIOPIA, MALAWI, NIGERIA, UGANDA (25 nov 2026)
##
##  Stesso formato dell'Excel della Tanzania (tza_dati_grezzi.R), per usare lo stesso script LA/AIDS:
##   - foglio dati: UNA RIGA PER FAMIGLIA x round, mai ripetuta. Colonne della famiglia, poi per ogni voce alimentare
##     le colonne c<codice>_<variabile> con i valori ORIGINALI del modulo a 7 giorni (nessuna conversione, nessun prezzo,
##     nessuna imputazione). Vuote = voce non consumata o domanda non fatta.
##   - fogli voci e unita: classificazione voce -> categoria -> gruppo (la stessa del dataset alimentare del 24 nov)
##     e codici delle unita'; foglio LEGGIMI: cosa c'e' e cosa e' diverso dalla Tanzania.
##  Le righe vengono da allfood_long_<paese>.csv.gz (build_allfood_long.R); le famiglie dal dataset armonizzato
##  (_wide_check), la spesa totale mancante dagli aggregati ufficiali (Nigeria, Uganda 2010-2011).
##  USO  Rscript dati_grezzi_LAAIDS.R <ETH|MWI|NGA|UGA> <_unzipped> <allfood_long_<paese>.csv.gz> <_wide_check.csv.gz>
##                                    <food_category_map.csv> <unit_codes.csv> <uscita.xlsx>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(tidyr); library(readr); library(openxlsx) })
a <- commandArgs(TRUE); PAESE <- a[1]; U <- a[2]
stopifnot(PAESE %in% c("ETH", "MWI", "NGA", "UGA"))
nn <- function(x) suppressWarnings(as.numeric(x))
idstr <- function(x) { x <- zap_labels(x); if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x)) }
trova <- function(pat, hint) { f <- list.files(U, pattern = pat, recursive = TRUE, full.names = TRUE); f <- f[grepl(hint, f)]; stopifnot(length(f) >= 1); f[1] }
# codici: numeri se tutti i valori sono numeri (es. 1, 23), altrimenti testo (Malawi: "10B")
codice <- function(x) { y <- nn(x); if (all(is.na(x) | !is.na(y))) y else x }

GRUPPO <- c(cereals = "cereali", starches = "tuberi", pulses_dry = "legumi_noci_semi", pulses_fresh = "legumi_noci_semi", groundnuts = "legumi_noci_semi",
            soy = "legumi_noci_semi", nuts = "legumi_noci_semi", seeds = "legumi_noci_semi", fruits = "frutta_verdura", vegetables = "frutta_verdura",
            beef = "manzo", pork = "maiale", goat_sheep = "altra_carne", processed_red_meat = "altra_carne", meat_other = "altra_carne",
            poultry = "pollame", fish_fresh = "pesce", fish_processed = "pesce", milk_fresh = "latte", dairy_processed = "latte", eggs = "uova",
            oils_fats = "altro", sugar_sweets = "altro", spices_other = "altro", beverages = "altro", other_food = "altro", excluded = "escluso",
            food_away = "fuori_casa")   # Malawi e Uganda: cibo pronto comprato da venditori o al ristorante, dentro il modulo a 7 giorni

## classificazione delle voci (la stessa del dataset alimentare). UNCLASSIFIED = voci del questionario che nessuna
## famiglia dichiara nel round: non entrano (controllo sotto)
M0 <- read_csv(a[5], col_types = cols(.default = col_character()), progress = FALSE) %>% filter(country == PAESE, category != "header")
stopifnot(all(as.numeric(M0$hh_consuming[M0$category == "UNCLASSIFIED"]) %in% 0))
M <- M0 %>% filter(category != "UNCLASSIFIED") %>%
  transmute(round = as.integer(round), campione = ifelse(is.na(sample), "", sample), codice_voce = as.integer(code), voce = clean_label,
            categoria = category, gruppo = unname(GRUPPO[category]), famiglie_che_consumano = as.numeric(hh_consuming))
stopifnot(!any(is.na(M$gruppo)), !anyDuplicated(M[, c("round", "campione", "codice_voce")]))

## voci consumate, valori originali. Le 9 variabili della Tanzania, piu' quelle che questo paese chiede in piu'
BASE  <- c(q_tot = "q_tot", u_tot = "u_tot", q_acq = "q_pur", u_acq = "u_pur", spesa_acq = "exp_pur",
           q_auto = "q_own", u_auto = "u_own", q_regali = "q_gift", u_regali = "u_gift")
EXTRA <- c(taglia_tot = "us_tot", taglia_acq = "us_pur", taglia_auto = "us_own", taglia_regali = "us_gift",                  # Malawi, Nigeria: taglia dell'unita'
           u_altra_tot = "uo_tot", u_altra_acq = "uo_pur", u_altra_auto = "uo_own", u_altra_regali = "uo_gift",              # "altra unita' (specificare)", testo
           q_da_acq = "q_frompur", u_da_acq = "u_frompur",                                                                   # Nigeria: consumo venuto da acquisti
           acq_30gg = "pur30_yn", q_ultacq = "q_lastpur", u_ultacq = "u_lastpur", taglia_ultacq = "us_lastpur", spesa_ultacq = "val_lastpur",  # Nigeria 2018-2023
           val_auto = "val_own", val_regali = "val_gift", q_fuori = "q_away", val_fuori = "val_away")                        # Uganda: valori dichiarati
L <- read_csv(a[3], col_types = cols(.default = col_character()), progress = FALSE) %>% filter(cons == "1")
pieno <- function(v) v %in% names(L) && any(!is.na(L[[v]]) & L[[v]] != "")
EXTRA <- EXTRA[sapply(EXTRA, pieno)]
VAR <- c(BASE, EXTRA)
TESTO <- names(VAR)[grepl("^u_altra_", names(VAR))]
V <- L %>% transmute(round = as.integer(year), hhid, campione = "", codice_voce = as.integer(code), !!!lapply(VAR, function(v) rlang::sym(v)))
for (v in names(VAR)) V[[v]] <- if (v %in% TESTO) ifelse(V[[v]] == "", NA, V[[v]]) else if (grepl("^(u_|taglia_|acq_)", v)) codice(V[[v]]) else nn(V[[v]])
V <- V %>% left_join(M %>% select(round, campione, codice_voce, voce, categoria, gruppo), by = c("round", "campione", "codice_voce")) %>%
  relocate(voce, categoria, gruppo, .after = codice_voce) %>% arrange(round, hhid, codice_voce)
stopifnot(!any(is.na(V$gruppo)))
escluse <- V %>% filter(gruppo == "escluso") %>% distinct(voce) %>% pull(voce)
cat("voci escluse dal bilancio, tolte:", sum(V$gruppo == "escluso"), "righe -", paste(unique(tolower(escluse)), collapse = "; "), "\n")
V <- V %>% filter(gruppo != "escluso")
## stessa voce dichiarata due volte dalla stessa famiglia (Uganda 2013: 7 famiglie, 14 righe). Regola:
##  righe identiche -> se ne tiene una (copia); stessa unita' -> quantita' e valori sommati;
##  unita' diverse -> si tiene la riga con il valore piu' alto (non si possono sommare quantita' in unita' diverse)
DOPPIE <- 0
if (anyDuplicated(V[, c("round", "hhid", "codice_voce")])) {
  chiave <- paste(V$round, V$hhid, V$codice_voce)
  dd <- chiave %in% chiave[duplicated(chiave)]
  X <- V[dd, ] %>% distinct()                                                     # copie identiche: una sola
  NUM <- names(VAR)[grepl("^(q_|spesa_|val_)", names(VAR))]
  X <- X %>% mutate(.valore = rowSums(across(any_of(c("spesa_acq", "val_auto", "val_regali", "spesa_ultacq"))), na.rm = TRUE)) %>%
    group_by(round, hhid, codice_voce) %>%
    group_modify(function(g, k) {
      if (nrow(g) == 1) return(g)
      if (n_distinct(g$u_tot) == 1) { s <- g[1, ]; for (v in NUM) s[[v]] <- if (all(is.na(g[[v]]))) NA else sum(g[[v]], na.rm = TRUE); return(s) }
      g[which.max(g$.valore), ] }) %>% ungroup() %>% select(-.valore)
  DOPPIE <- sum(dd)
  cat("righe doppie (stessa famiglia e voce):", DOPPIE, "->", nrow(X), "\n")
  V <- bind_rows(V[!dd, ], X %>% select(all_of(names(V)))) %>% arrange(round, hhid, codice_voce)
}
stopifnot(!anyDuplicated(V[, c("round", "hhid", "codice_voce")]))      # una sola riga per famiglia e voce
## voci segnate come consumate ma senza nessuna quantita', unita' o spesa: nel foglio dati restano vuote
SENZA <- V %>% filter(if_all(all_of(names(VAR)), is.na)) %>% count(round)
cat("voci consumate senza nessun valore (vuote nel foglio dati):", sum(SENZA$n), "\n")

## famiglie: dal dataset armonizzato (geografia, peso, caratteristiche, spesa totale)
H <- read_csv(a[4], col_types = cols(.default = col_character()), progress = FALSE,
              col_select = c(country, year, hhid, panel_id, weight, region, district, subdistrict, ea, rural, hhsize, adulteq, int_month,
                             head_female, head_age, cons_total_hh_annual)) %>% filter(country == PAESE)
# variabile ufficiale usata dal dataset armonizzato (build_long_food_dataset.py)
VAR_TOT <- c(ETH = "total_cons_ann (annuo, nominale)", MWI = "rexpagg (annuo, prezzi reali)", NGA = NA, UGA = "nrrexp30 x 12 (mensile, nominale)")
F <- H %>% transmute(round = as.integer(year), hhid, panel_id, campione = "", regione = region, distretto = district, sotto_distretto = subdistrict,
                     ea, peso = nn(weight), rurale = nn(rural), ampiezza = nn(hhsize), adulti_eq = nn(adulteq), mese_intervista = nn(int_month),
                     capo_donna = nn(head_female), eta_capo = nn(head_age), spesa_totale_annua = nn(cons_total_hh_annual),
                     spesa_totale_fonte = ifelse(is.na(cons_total_hh_annual), NA, paste("aggregato ufficiale:", VAR_TOT[PAESE])))
stopifnot(!anyDuplicated(F[, c("round", "hhid")]))

## Malawi 2010: il file non ha la regione; il codice del distretto la contiene (prima cifra: 1 Nord, 2 Centro, 3 Sud).
## Si ricava solo se negli altri round la regione coincide SEMPRE con la prima cifra del distretto (distretti 1xx-3xx;
## il 401 del 2024 e' il campione del campo profughi, nella regione Centro, e nel 2010 non c'e').
if (PAESE == "MWI") {
  ok <- F %>% filter(!is.na(regione), substr(distretto, 1, 1) %in% c("1", "2", "3")) %>% summarise(uguali = all(regione == substr(distretto, 1, 1))) %>% pull(uguali)
  stopifnot(ok, !any(F$round == 2010 & !substr(F$distretto, 1, 1) %in% c("1", "2", "3")))
  F <- F %>% mutate(regione = ifelse(is.na(regione) & round == 2010, substr(distretto, 1, 1), regione))
}

## spesa totale annua della famiglia (strumento della spesa alimentare) dove il dataset armonizzato non la ha
agg <- function(f, hint, idv, v, fattore, fonte, y) {
  d <- read_dta(trova(f, hint)); x <- tibble(hhid = idstr(d[[idv]]), s = nn(zap_labels(d[[v]])), h = nn(zap_labels(d$hhsize %||% NA)))
  x <- x %>% transmute(round = y, hhid, s_agg = if (fattore == "hhsize") s * h else s * fattore, f_agg = fonte) %>% distinct(round, hhid, .keep_all = TRUE)
  cat("  ", y, fonte, ": famiglie nel file", nrow(x), " trovate", sum(x$hhid %in% F$hhid[F$round == y]), "\n"); x }
`%||%` <- function(a, b) if (is.null(a)) b else a
if (PAESE == "NGA") {
  # aggregato ufficiale pro capite annuo x componenti (hhsize dello stesso file): visita post-raccolto, la stessa del modulo alimentare
  S <- bind_rows(agg("^cons_agg_wave1_visit2\\.dta$", "NGA_2010", "hhid", "totcons", "hhsize", "totcons x hhsize (pro capite annuo, nominale)", 2010L),
                 agg("^cons_agg_wave2_visit2\\.dta$", "NGA_2012", "hhid", "totcons", "hhsize", "totcons x hhsize (pro capite annuo, nominale)", 2012L),
                 agg("^cons_agg_wave3_visit2\\.dta$", "NGA_2015", "hhid", "totcons", "hhsize", "totcons x hhsize (pro capite annuo, nominale)", 2015L),
                 agg("^totcons_final\\.dta$", "NGA_2018", "hhid", "totcons_pc", "hhsize", "totcons_pc x hhsize (pro capite annuo, nominale)", 2018L),
                 agg("^totcons_final\\.dta$", "NGA_2023", "hhid", "totcons_adj", "hhsize", "totcons_adj x hhsize (pro capite annuo, prezzi 2023 aggiustati: il file non ha il nominale)", 2023L))
}
if (PAESE == "UGA") {
  # aggregato ufficiale mensile x 12 (prezzi costanti 2005/06: il file non ha il nominale); dal 2013 il dataset armonizzato usa nrrexp30 x 12
  S <- bind_rows(agg("^pov2010_11\\.dta$", "UGA_2010", "hh", "cpexp30", 12, "cpexp30 x 12 (mensile, prezzi costanti 2005/06)", 2010L),
                 agg("Consumption Aggregate\\.dta$", "UGA_2011", "HHID", "cpexp30", 12, "cpexp30 x 12 (mensile, prezzi costanti 2005/06)", 2011L))
}
if (exists("S")) {
  F <- F %>% left_join(S, by = c("round", "hhid")) %>%
    mutate(spesa_totale_fonte = ifelse(is.na(spesa_totale_annua) & !is.na(s_agg), paste("aggregato ufficiale:", f_agg), spesa_totale_fonte),
           spesa_totale_annua = coalesce(spesa_totale_annua, s_agg)) %>% select(-s_agg, -f_agg)
}

## identificativi per i prezzi locali e per il bootstrap
##  id_distretto, id_ea: luogo dove la famiglia vive nel round (i codici si ripetono tra regioni o distretti: si usano composti)
##  cluster: unita' di campionamento per il bootstrap = id_ea del PRIMO round in cui la famiglia compare (panel_id), cosi'
##           una famiglia del panel resta nello stesso cluster anche se si trasferisce; senza panel_id, l'id_ea del round
F <- F %>% mutate(id_distretto = ifelse(is.na(distretto), NA, paste(regione, distretto, sep = "-")),
                  id_ea = ifelse(is.na(ea), NA, paste(regione, distretto, coalesce(sotto_distretto, ""), ea, sep = "-")))
primo <- F %>% filter(!is.na(panel_id), panel_id != "", !is.na(id_ea)) %>% arrange(round) %>% group_by(panel_id) %>%
  summarise(cluster_primo = first(id_ea), .groups = "drop")
F <- F %>% left_join(primo, by = "panel_id") %>% mutate(cluster = coalesce(cluster_primo, id_ea)) %>% select(-cluster_primo) %>%
  select(round, hhid, panel_id, campione, regione, distretto, sotto_distretto, ea, id_distretto, id_ea, cluster, peso, rurale, ampiezza, adulti_eq,
         mese_intervista, capo_donna, eta_capo, spesa_totale_annua, spesa_totale_fonte) %>% arrange(round, hhid)
cat("famiglie senza geografia:", sum(is.na(F$regione)), " | voci di famiglie non in elenco:", sum(!paste(V$round, V$hhid) %in% paste(F$round, F$hhid)), "\n")
stopifnot(all(paste(V$round, V$hhid) %in% paste(F$round, F$hhid)))
riep <- F %>% group_by(round) %>% summarise(famiglie = n(), con_voci = sum(paste(round, hhid) %in% paste(V$round, V$hhid)),
  regione_NA = sum(is.na(regione)), distretto_NA = sum(is.na(distretto)), ea_NA = sum(is.na(ea)), cluster = n_distinct(cluster),
  peso_NA = sum(is.na(peso)), spesa_tot_NA = sum(is.na(spesa_totale_annua)), fonte_spesa_tot = paste(unique(na.omit(spesa_totale_fonte)), collapse = " | "))
print(as.data.frame(riep))

## una riga per famiglia: le voci diventano colonne c<codice>_<variabile>
W <- V %>% select(round, hhid, codice_voce, all_of(names(VAR))) %>%
  pivot_wider(names_from = codice_voce, values_from = all_of(names(VAR)), names_glue = "c{codice_voce}_{.value}")
ord <- unlist(lapply(sort(unique(V$codice_voce)), function(k) paste0("c", k, "_", names(VAR))))
ord <- ord[ord %in% names(W)]
# colonne di una variabile mai compilata per quella voce (es. taglia per una voce senza taglie): tolte
vuote <- ord[sapply(ord, function(v) all(is.na(W[[v]])))]
ord <- setdiff(ord, vuote)
D <- F %>% left_join(W, by = c("round", "hhid")) %>% select(all_of(names(F)), all_of(ord))
stopifnot(!anyDuplicated(D[, c("round", "hhid")]), nrow(D) == nrow(F))
cat("dati: righe", nrow(D), " colonne", ncol(D), " (voci", length(unique(V$codice_voce)), ", variabili per voce:", paste(names(VAR), collapse = ", "), ")\n")

## controllo: le somme delle quantita' e della spesa nel foglio dati sono quelle del file di partenza
for (v in intersect(c("q_tot", "q_acq", "spesa_acq", "q_auto", "q_regali", "spesa_ultacq", "val_auto"), names(VAR))) {
  s1 <- sum(V[[v]], na.rm = TRUE); s2 <- sum(sapply(grep(paste0("_", v, "$"), names(D), value = TRUE), function(k) sum(D[[k]], na.rm = TRUE)))
  cat(sprintf("  controllo somma %-12s voci %.6g  dati %.6g\n", v, s1, s2)); stopifnot(isTRUE(all.equal(s1, s2)))
}

## unita'
UN <- read_csv(a[6], col_types = cols(.default = col_character()), show_col_types = FALSE) %>% filter(country == PAESE, !is.na(label)) %>%
  transmute(round = as.integer(year), variabile_originale = variable, codice = code, etichetta = label) %>%
  distinct(round, variabile_originale, codice, .keep_all = TRUE) %>% arrange(round, variabile_originale, nn(codice), codice)

## LEGGIMI
NOMI  <- c(ETH = "Etiopia", MWI = "Malawi", NGA = "Nigeria", UGA = "Uganda")
GEO   <- c(ETH = "regione = region (saq01), distretto = zona (saq02), sotto_distretto = woreda (saq03), ea = ea_id (unico nel paese).",
           MWI = "regione = region (2010: ricavata dalla prima cifra del codice del distretto, 1 Nord, 2 Centro, 3 Sud), distretto = district, sotto_distretto vuoto, ea = ea_id.",
           NGA = "regione = zona geopolitica (zone), distretto = stato (state), sotto_distretto = LGA, ea = ea (il codice si ripete tra LGA: usare id_ea).",
           UGA = "regione = region, distretto = district (2010-2011 nome, poi codice), sotto_distretto = subcounty (solo 2018-2019), ea = comm (2010-2011), ea (2013-2015), parish (2018-2019): usare id_ea.")
FONTE <- c(ETH = "Ethiopia Socioeconomic Survey 2015/16, 2018/19 e ESPS 2021/22 (2011 e 2013 non inclusi: una sola voce per tutta la carne).",
           MWI = "Malawi Integrated Household Survey IHS3 2010/11, IHS4 2016/17, IHS5 2019/20, IHS6 2024/25 (sezioni trasversali: panel_id vuoto).",
           NGA = "Nigeria General Household Survey-Panel 2010/11, 2012/13, 2015/16, 2018/19, 2023/24 (visita post-raccolto).",
           UGA = "Uganda National Panel Survey 2010/11, 2011/12, 2013/14, 2015/16, 2018/19, 2019/20 (round 2010, 2011, 2013, 2015, 2018, 2019).")
DIVERSO <- c(
  ETH = "Diverso dalla Tanzania: nessuna voce di maiale nel questionario. Molte unita' locali (codici sopra 100, con taglia nel codice): vedi foglio unita.",
  MWI = "Diverso dalla Tanzania: le unita' sono un codice con lettera (es. 10B) e una TAGLIA (taglia_*: 1 piccola, 2 media, 3 grande): stessa unita' = stesso codice E stessa taglia. u_altra_*: unita' scritta a mano. File grande.",
  NGA = "Diverso dalla Tanzania: 2018 e 2023 NON chiedono quantita' e spesa degli acquisti dei 7 giorni (q_acq, spesa_acq vuote). Chiedono la quantita' consumata venuta da acquisti (q_da_acq) e l'ULTIMO acquisto a 30 giorni (acq_30gg 1 si' 2 no, q_ultacq, u_ultacq, taglia_ultacq, spesa_ultacq): i prezzi di quei round vanno presi da li'. 2012-2015 hanno anche q_da_acq. Taglia: taglia_tot, taglia_ultacq (2018-2023).",
  UGA = "Diverso dalla Tanzania: una sola unita' per voce (u_tot = u_acq = u_auto = u_regali). 2018-2019 non chiedono la quantita' totale (q_tot vuota: totale = somma delle fonti). Chiede anche il VALORE dell'autoconsumo e dei regali (val_auto, val_regali) e il consumo fuori casa della voce (q_fuori, val_fuori).")
LEGGI <- data.frame(Foglio = c("dati", "", "", "", "", "", "", "", "", "voci", "unita", "controllo_famiglie", "Fonte", "Nota"), Contenuto = c(
  paste0("UNA RIGA PER FAMIGLIA x round (", format(nrow(D), big.mark = ".", decimal.mark = ","), " righe, nessuna ripetuta). Valori originali dei questionari, nessuna conversione, nessun prezzo. Stesso formato del file della Tanzania."),
  "Famiglia: round, hhid, panel_id (stessa famiglia tra i round), campione (vuoto: c'e' per compatibilita' con lo script della Tanzania).",
  paste("Geografia (luogo del round):", GEO[PAESE], "id_distretto e id_ea sono codici composti."),
  "cluster: unita' di campionamento per il bootstrap = id_ea del primo round in cui la famiglia compare (una famiglia del panel resta nel suo cluster anche se si trasferisce).",
  paste0("peso: peso campionario; rurale 1/0; ampiezza: membri; capo_donna 1/0; spesa_totale_annua: consumo totale annuo della famiglia (aggregato ufficiale) = strumento della spesa alimentare; spesa_totale_fonte: da dove viene, per round. ",
         if (PAESE == "MWI") "Malawi: rexpagg, a prezzi reali." else if (PAESE == "NGA") "Nigeria: pro capite x componenti dello stesso file." else if (PAESE == "UGA") "Uganda: 2010-2011 a prezzi costanti, 2013-2019 nominale." else "Etiopia: nominale."),
  "Voci: per ogni codice del foglio voci le colonne c<codice>_<variabile>. q_tot/u_tot: quantita' totale consumata nei 7 giorni e unita'; q_acq/u_acq: dagli acquisti; spesa_acq: quanto ha speso (valuta locale).",
  "q_auto/u_auto: da autoproduzione; q_regali/u_regali: da regali e altre fonti. Celle vuote: voce non consumata, fonte non usata o domanda non fatta. Colonne mai compilate per una voce: tolte.",
  paste(DIVERSO[PAESE], if (DOPPIE > 0) paste0("Righe doppie nel file originale (stessa famiglia e voce): ", DOPPIE, "; copie identiche -> una, stessa unita' -> sommate, unita' diverse -> tenuta quella di valore piu' alto.") else "",
        if (any(V$gruppo == "fuori_casa")) "Voci con gruppo fuori_casa (categoria food_away): cibo pronto comprato da venditori o al ristorante, registrato nel modulo a 7 giorni. NON fa parte del cibo consumato a casa (decisione B3): va tolto dal budget del LA/AIDS." else ""),
  paste0(if (sum(SENZA$n) > 0) paste0("Voci segnate come consumate ma senza nessuna quantita', unita' o spesa (vuote nel foglio dati, come una voce non consumata): ",
                                     paste(SENZA$round, SENZA$n, sep = ": ", collapse = ", "), ". ") else "",
         "Fuori dal file (escluse dal bilancio, come per la Tanzania): ", paste(unique(tolower(escluse)), collapse = "; "), ". Famiglie senza nessuna voce: nessun consumo a casa."),
  "Ogni codice voce per round con etichetta, categoria del dataset alimentare e gruppo del LA/AIDS a 12 gruppi (cereali, tuberi, legumi_noci_semi, frutta_verdura, manzo, maiale, altra_carne, pollame, pesce, latte, uova, altro).",
  "Codici delle unita' per round e variabile originale del questionario, con etichetta.",
  "Per round: famiglie, famiglie con almeno una voce, valori mancanti di geografia, peso e spesa totale, numero di cluster, fonte della spesa totale.",
  paste("World Bank LSMS-ISA,", FONTE[PAESE], "microdata.worldbank.org. Uso solo di ricerca: non ridistribuire."),
  "Costruito con dati_grezzi_LAAIDS.R (github.com/paolo-medei/PhD, code/analysis)."))
M <- M %>% filter(gruppo != "escluso")
FOGLI <- list(LEGGIMI = LEGGI, dati = D, voci = M, unita = UN, controllo_famiglie = riep)
# writexl scrive file molto piu' piccoli di openxlsx (Nigeria: 119 MB contro circa 30) e non esaurisce la memoria con il Malawi;
# openxlsx (con intestazioni colorate e righe bloccate) solo se writexl non c'e'
if (!requireNamespace("writexl", quietly = TRUE)) {
  wb <- createWorkbook(); hs <- createStyle(textDecoration = "bold", fgFill = "#DDEBF7", border = "TopBottomLeftRight")
  for (s in names(FOGLI)) {
    addWorksheet(wb, s); writeData(wb, s, FOGLI[[s]], headerStyle = hs, keepNA = FALSE)
    freezePane(wb, s, firstRow = TRUE, firstCol = s == "dati")
    if (s == "LEGGIMI") setColWidths(wb, s, 1:2, c(12, 160)) else if (s != "dati") setColWidths(wb, s, 1:ncol(FOGLI[[s]]), "auto") }
  saveWorkbook(wb, a[7], overwrite = TRUE)
} else writexl::write_xlsx(FOGLI, a[7])
print(table(V$round, V$gruppo))
cat("salvato:", a[7], "\n")
