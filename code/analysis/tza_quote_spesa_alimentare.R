###############################################################################
## Tanzania (NPS 2008-2020): quote di spesa alimentare, peso di acquisti,
## autoconsumo e regali per gli alimenti ricchi di proteine
##
## Input : ASF_household_food_TZA_2026-11-24.xlsx (una riga per famiglia x round)
## Output: un file Excel con tabelle per famiglia, per categoria e round, e controlli
##
## Pacchetti: readxl, dplyr, tidyr; writexl per esportare (se manca si usa openxlsx)
##
## AVVERTENZE DI METODO (leggere prima di usare i numeri)
## 1. Il file contiene SOLO 17 categorie di alimenti ricchi di proteine (carni, pollame,
##    uova, latticini, pesce, legumi, arachidi, frutta a guscio, semi). Mancano cereali,
##    tuberi, verdure, frutta, oli, zucchero, bevande. Sommare le categorie NON da' la spesa
##    alimentare totale: da' solo la spesa per questi alimenti. Per la quota sul totale
##    alimentare si usa la variabile ufficiale food_cons_hh_annual (presente in tutti i 5 round:
##    foodIN + foodOUT, annuale, nominale, comprende autoconsumo e regali valorizzati, pasti
##    fuori casa e alcol), riportata a 7 giorni (x 7/365).
## 2. <cat>_exp e' la spesa a 7 giorni per la quantita' consumata che viene da acquisti.
##    "Quantita' acquistata" qui significa quantita' CONSUMATA proveniente da acquisti
##    (<cat>_kg_pur), non quantita' comprata.
## 3. Per autoconsumo e regali la Tanzania non registra valori monetari, solo quantita'.
##    Il valore e' STIMATO: kg x prezzo unitario mediano (spesa / kg acquistati) della stessa
##    categoria e dello stesso round, nella stessa regione e area (urbana/rurale) se ci sono
##    almeno 10 acquisti, altrimenti nella regione, altrimenti nel paese. I prezzi unitari
##    usano solo famiglie con kg osservati (kg_est = 0), per non usare chili gia' stimati dai prezzi.
## 4. I kg di categorie diverse non si sommano (un kg di latte non e' un kg di fagioli): il peso
##    delle fonti sul consumo totale si misura in valore, per categoria anche in quantita'.
## 5. Statistiche non pesate e pesate con il peso campionario (weight); le mediane pesate
##    sono la mediana della distribuzione pesata.
###############################################################################

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
})

## ---------------------------------------------------------------------------
## 0. Percorsi
## ---------------------------------------------------------------------------
percorso <- "C:/Users/Medei/OneDrive - Food and Agriculture Organization/Desktop/ASF_household_food_TZA_2026-11-24.xlsx"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) percorso <- args[1]                       # (solo per eseguirlo altrove)
uscita <- if (length(args) >= 2) args[2] else
  file.path(dirname(percorso), "TZA_quote_spesa_alimentare_risultati.xlsx")
stopifnot(file.exists(percorso))

GIORNI <- 7                    # periodo di richiamo del modulo alimentare
ANNO_A_7GG <- 7 / 365          # da annuale a 7 giorni
N_MIN_PREZZO <- 10             # acquisti minimi per un prezzo unitario mediano locale
N_MIN_PREZZO_PAESE <- 5        # acquisti minimi per il prezzo nazionale del round
TOLL <- 0.01                   # tolleranza relativa per "uguale" (1%)
LIMITE_KG_AE_GIORNO <- 2       # oltre 2 kg per adulto equivalente al giorno di una sola categoria: quantita' non plausibile
QUOTA_NON_CHIESTA <- 0.01      # se in un round piu' dell'1% delle famiglie non ha la voce, la voce non era nel loro questionario

## ---------------------------------------------------------------------------
## 1. Lettura e verifica dei fogli
## ---------------------------------------------------------------------------
fogli <- excel_sheets(percorso)
cat("Fogli nel file:", paste(fogli, collapse = ", "), "\n")
attesi <- c("README", "Dictionary", "Items", "Item_mapping", "Unit_weights", "Quality_control", "Data")
stopifnot(all(attesi %in% fogli))

readme     <- read_excel(percorso, "README", col_names = FALSE, .name_repair = "minimal")
dizionario <- read_excel(percorso, "Dictionary")
voci       <- read_excel(percorso, "Items")
mapping    <- read_excel(percorso, "Item_mapping")
pesi_unita <- read_excel(percorso, "Unit_weights")
dati       <- read_excel(percorso, "Data", guess_max = 50000,
                         col_types = NULL)   # tipi indovinati su tutte le righe

## solo Tanzania
dati <- dati %>% filter(country == "TZA")
cat("Famiglie x round in Tanzania:", nrow(dati), "\n"); print(table(dati$year))
stopifnot(!any(duplicated(dati[, c("year", "hhid")])))          # una riga per famiglia e round

## ---------------------------------------------------------------------------
## 2. Identificazione delle variabili
## ---------------------------------------------------------------------------
## le categorie dal foglio Items ("beef_*" -> "beef"); verifica che esistano nel foglio Data
categorie <- sub("_\\*$", "", voci$column)
SUFF <- c("cons", "kg_tot", "kg_pur", "kg_own", "kg_gift", "exp", "kg_est")
mancanti <- setdiff(as.vector(outer(categorie, SUFF, paste, sep = "_")), names(dati))
if (length(mancanti)) stop("Colonne attese assenti nel foglio Data: ", paste(mancanti, collapse = ", "))
stopifnot(all(c("weight", "region", "rural", "hhsize", "food_cons_hh_annual", "cons_total_hh_annual", "not_collected") %in% names(dati)))

## formato lungo: una riga per famiglia x round x categoria
lungo <- dati %>%
  select(year, hhid, weight, region, rural, all_of(as.vector(outer(categorie, SUFF, paste, sep = "_")))) %>%
  pivot_longer(-c(year, hhid, weight, region, rural),
               names_to = c("categoria", ".value"),
               names_pattern = paste0("^(", paste(categorie, collapse = "|"), ")_(", paste(SUFF, collapse = "|"), ")$")) %>%
  mutate(categoria = factor(categoria, levels = categorie))

## disponibilita' per categoria e round: raccolta se almeno una famiglia ha cons non mancante;
## si confronta con la colonna not_collected del file
disp <- lungo %>% group_by(year, categoria) %>%
  summarise(famiglie = n(),
            cons_presente = mean(!is.na(cons)),
            exp_presente = mean(!is.na(exp[cons %in% 1])),
            kg_tot_presente = mean(!is.na(kg_tot[cons %in% 1])),
            kg_pur_presente = mean(!is.na(kg_pur[cons %in% 1])),
            kg_own_presente = mean(!is.na(kg_own[cons %in% 1])),
            kg_gift_presente = mean(!is.na(kg_gift[cons %in% 1])),
            .groups = "drop") %>%
  mutate(raccolta = cons_presente > 0)
nc <- dati %>% distinct(year, not_collected) %>%
  mutate(not_collected = ifelse(is.na(not_collected), "", not_collected))
disp <- disp %>% left_join(nc, by = "year") %>%
  mutate(dichiarata_non_raccolta = mapply(function(c, s) grepl(paste0("(^|, )", c, "_\\*"), s), as.character(categoria), not_collected),
         coerente = raccolta != dichiarata_non_raccolta) %>% select(-not_collected)
stopifnot(all(disp$coerente))
cat("\nCategorie non raccolte per round:\n")
print(disp %>% filter(!raccolta) %>% select(year, categoria) %>% as.data.frame())
## categorie raccolte solo in parte (es. pulses_fresh 2020: una parte del campione non ha la voce)
print(disp %>% filter(raccolta, cons_presente < 1) %>% select(year, categoria, cons_presente) %>% as.data.frame())

lungo <- lungo %>% semi_join(disp %>% filter(raccolta), by = c("year", "categoria"))
## righe con cons mancante. Se in un round mancano per molte famiglie (> 1%), la voce non era nel loro
## questionario (in Tanzania: pulses_fresh 2020, 419 famiglie): si escludono come una categoria non raccolta
## e per queste famiglie i totali non comprendono la categoria. Se sono poche, sono risposte mancanti:
## restano NA e rendono NA i totali di quella famiglia.
na_cons <- lungo %>% group_by(year, categoria) %>% summarise(famiglie_cons_mancante = sum(is.na(cons)), quota = mean(is.na(cons)), .groups = "drop") %>%
  filter(famiglie_cons_mancante > 0) %>% mutate(trattamento = ifelse(quota > QUOTA_NON_CHIESTA, "voce non chiesta: esclusa", "risposta mancante: NA"))
print(as.data.frame(na_cons))
lungo <- lungo %>% left_join(na_cons %>% select(year, categoria, trattamento), by = c("year", "categoria")) %>%
  filter(!(is.na(cons) & trattamento %in% "voce non chiesta: esclusa")) %>% select(-trattamento)

## quantita' non plausibili: kg totali per adulto equivalente al giorno oltre il limite
## (es. 8.500 kg di pollame ricevuti in regalo in una settimana). Le quantita' di quella riga diventano NA
## (non zero); la spesa osservata resta; il valore stimato di autoconsumo e regali diventa NA.
## adulti equivalenti; se mancano anche i componenti (famiglie fuori dal file dell'aggregato) si usa 10,
## un valore volutamente alto per segnalare solo i casi estremi
AE_SE_MANCANTE <- 10
ae <- dati %>% transmute(year, hhid, ae = case_when(adulteq > 0 ~ adulteq, hhsize > 0 ~ hhsize, TRUE ~ AE_SE_MANCANTE))
lungo <- lungo %>% left_join(ae, by = c("year", "hhid")) %>%
  mutate(kg_ae_giorno = kg_tot / ae / GIORNI,
         anomalia_kg = (kg_ae_giorno > LIMITE_KG_AE_GIORNO) %in% TRUE,
         across(c(kg_tot, kg_pur, kg_own, kg_gift), ~ ifelse(anomalia_kg, NA_real_, .x)))
qc_anomalie <- lungo %>% filter(anomalia_kg) %>% select(year, hhid, categoria, ae, kg_ae_giorno, exp)
cat("\nRighe con quantita' non plausibili (messe NA):", nrow(qc_anomalie), "\n")

## ---------------------------------------------------------------------------
## 3. Prezzi unitari (per valorizzare autoconsumo e regali)
## ---------------------------------------------------------------------------
## prezzo unitario osservato = spesa / kg consumati da acquisti, solo con kg osservati
acq <- lungo %>% filter(cons %in% 1, kg_pur > 0, exp > 0, kg_est %in% 0) %>% mutate(pu = exp / kg_pur)
med_rr <- acq %>% group_by(year, categoria, region, rural) %>% summarise(pu_rr = median(pu), n_rr = n(), .groups = "drop")
med_r  <- acq %>% group_by(year, categoria, region) %>% summarise(pu_r = median(pu), n_r = n(), .groups = "drop")
med_p  <- acq %>% group_by(year, categoria) %>% summarise(pu_p = median(pu), n_p = n(), .groups = "drop")

lungo <- lungo %>%
  left_join(med_rr, by = c("year", "categoria", "region", "rural")) %>%
  left_join(med_r, by = c("year", "categoria", "region")) %>%
  left_join(med_p, by = c("year", "categoria")) %>%
  mutate(prezzo_unitario = case_when(n_rr >= N_MIN_PREZZO ~ pu_rr, n_r >= N_MIN_PREZZO ~ pu_r, n_p >= N_MIN_PREZZO_PAESE ~ pu_p),
         livello_prezzo = case_when(n_rr >= N_MIN_PREZZO ~ "regione x area", n_r >= N_MIN_PREZZO ~ "regione",
                                    n_p >= N_MIN_PREZZO_PAESE ~ "paese", TRUE ~ "nessuno")) %>%
  select(-pu_rr, -n_rr, -pu_r, -n_r, -pu_p, -n_p)

## ---------------------------------------------------------------------------
## 4. Calcoli per famiglia x round x categoria
## ---------------------------------------------------------------------------
## Regole: cons = 0 -> tutte le quantita' e la spesa sono 0 (gia' nel file);
##         valore mancante -> resta NA (mai 0); categoria non raccolta -> esclusa.
lungo <- lungo %>%
  mutate(
    kg_fonti = kg_pur + kg_own + kg_gift,                                   # somma delle fonti
    q_acq = ifelse(kg_fonti > 0, kg_pur / kg_fonti, NA),                    # quote in quantita'
    q_auto = ifelse(kg_fonti > 0, kg_own / kg_fonti, NA),
    q_regali = ifelse(kg_fonti > 0, kg_gift / kg_fonti, NA),
    val_acq = exp,                                                          # osservato
    val_auto = case_when(kg_own == 0 ~ 0, kg_own > 0 ~ kg_own * prezzo_unitario),     # stimato
    val_regali = case_when(kg_gift == 0 ~ 0, kg_gift > 0 ~ kg_gift * prezzo_unitario),
    val_tot = val_acq + val_auto + val_regali,
    val_stimato = (kg_own > 0 | kg_gift > 0) %in% TRUE                       # 1 se una parte del valore e' stimata
  )

## ---------------------------------------------------------------------------
## 5. Totali e quote per famiglia x round
## ---------------------------------------------------------------------------
## Totale rigoroso: mancante se manca la spesa di una categoria raccolta.
fam <- lungo %>% group_by(year, hhid) %>%
  summarise(weight = first(weight),
            categorie_raccolte = n(),
            categorie_exp_mancante = sum(is.na(exp)),
            spesa_prot = if (any(is.na(exp))) NA_real_ else sum(exp),              # spesa per i 15-16 alimenti proteici
            val_acq = if (any(is.na(val_acq))) NA_real_ else sum(val_acq),
            val_auto = if (any(is.na(val_auto))) NA_real_ else sum(val_auto),
            val_regali = if (any(is.na(val_regali))) NA_real_ else sum(val_regali),
            .groups = "drop") %>%
  mutate(val_prot = val_acq + val_auto + val_regali) %>%
  left_join(dati %>% select(year, hhid, food_cons_hh_annual, cons_total_hh_annual, hhsize, rural, region), by = c("year", "hhid")) %>%
  mutate(food_ufficiale_7gg = food_cons_hh_annual * ANNO_A_7GG,
         quota_prot_spesa_su_food = spesa_prot / food_ufficiale_7gg,           # acquisti proteici / consumo alimentare totale
         quota_prot_valore_su_food = val_prot / food_ufficiale_7gg,            # consumo proteico (tutte le fonti) / consumo alimentare
         quota_food_su_totale = food_cons_hh_annual / cons_total_hh_annual,
         q_val_acq = ifelse(val_prot > 0, val_acq / val_prot, NA),
         q_val_auto = ifelse(val_prot > 0, val_auto / val_prot, NA),
         q_val_regali = ifelse(val_prot > 0, val_regali / val_prot, NA))

## quote di categoria: sulla spesa proteica (composizione) e sul consumo alimentare ufficiale
lungo <- lungo %>%
  left_join(fam %>% select(year, hhid, spesa_prot, val_prot, food_ufficiale_7gg), by = c("year", "hhid")) %>%
  mutate(quota_su_spesa_prot = ifelse(spesa_prot > 0, exp / spesa_prot, NA),     # exp_cat / somma exp delle categorie
         quota_spesa_su_food = exp / food_ufficiale_7gg,                       # exp_cat / consumo alimentare ufficiale
         quota_valore_su_food = val_tot / food_ufficiale_7gg)                  # valore (tutte le fonti) / consumo alimentare

## ---------------------------------------------------------------------------
## 6. Tabelle
## ---------------------------------------------------------------------------
wmean <- function(x, w) { ok <- !is.na(x) & !is.na(w); if (!any(ok)) NA_real_ else sum(x[ok] * w[ok]) / sum(w[ok]) }
wmed <- function(x, w) { ok <- !is.na(x) & !is.na(w); if (!any(ok)) return(NA_real_)
  x <- x[ok]; w <- w[ok]; o <- order(x); x <- x[o]; cw <- cumsum(w[o]) / sum(w); x[which(cw >= 0.5)[1]] }
rapp <- function(num, den, w = NULL) { ok <- !is.na(num) & !is.na(den) & (if (is.null(w)) TRUE else !is.na(w))
  if (!any(ok)) return(NA_real_); if (is.null(w)) sum(num[ok]) / sum(den[ok]) else sum(num[ok] * w[ok]) / sum(den[ok] * w[ok]) }

## campione per le quote: famiglie con denominatore valido
tab_cat <- lungo %>% group_by(year, categoria) %>%
  summarise(
    famiglie = n(),
    consumatori = sum(cons %in% 1),
    quota_consumatori = mean(cons %in% 1),
    quota_consumatori_pesata = wmean(as.numeric(cons %in% 1), weight),
    acquirenti = sum(exp > 0, na.rm = TRUE),
    ## spesa a 7 giorni (TZS): tutte le famiglie (zeri inclusi) e solo chi consuma
    spesa_media = mean(exp, na.rm = TRUE), spesa_mediana = median(exp, na.rm = TRUE),
    spesa_media_consumatori = mean(exp[cons %in% 1], na.rm = TRUE), spesa_mediana_consumatori = median(exp[cons %in% 1], na.rm = TRUE),
    spesa_media_pesata = wmean(exp, weight),
    ## quota sulla spesa proteica (composizione)
    quota_spesa_prot_media = mean(quota_su_spesa_prot, na.rm = TRUE),
    quota_spesa_prot_mediana = median(quota_su_spesa_prot, na.rm = TRUE),
    quota_spesa_prot_aggregata = rapp(exp[!is.na(quota_su_spesa_prot)], spesa_prot[!is.na(quota_su_spesa_prot)]),
    quota_spesa_prot_aggregata_pesata = rapp(exp[!is.na(quota_su_spesa_prot)], spesa_prot[!is.na(quota_su_spesa_prot)], weight[!is.na(quota_su_spesa_prot)]),
    ## quota della spesa (acquisti) sul consumo alimentare ufficiale
    quota_spesa_food_media = mean(quota_spesa_su_food, na.rm = TRUE),
    quota_spesa_food_mediana = median(quota_spesa_su_food, na.rm = TRUE),
    quota_spesa_food_media_pesata = wmean(quota_spesa_su_food, weight),
    quota_spesa_food_aggregata = rapp(exp, food_ufficiale_7gg),
    quota_spesa_food_aggregata_pesata = rapp(exp, food_ufficiale_7gg, weight),
    ## quota del valore (acquisti + autoconsumo e regali stimati) sul consumo alimentare ufficiale
    quota_valore_food_aggregata_pesata = rapp(val_tot, food_ufficiale_7gg, weight),
    ## quantita' (solo chi consuma)
    kg_medi_consumatori = mean(kg_tot[cons %in% 1], na.rm = TRUE),
    kg_mediani_consumatori = median(kg_tot[cons %in% 1], na.rm = TRUE),
    kg_medi_pesati_consumatori = wmean(kg_tot[cons %in% 1], weight[cons %in% 1]),
    consumatori_senza_kg = sum(cons %in% 1 & is.na(kg_tot)),
    consumatori_kg_stimati = sum(cons %in% 1 & kg_est %in% 1),
    ## quote delle fonti in quantita': aggregata pesata e media delle quote familiari
    q_acq_aggregata_pesata = rapp(kg_pur, kg_fonti, weight),
    q_auto_aggregata_pesata = rapp(kg_own, kg_fonti, weight),
    q_regali_aggregata_pesata = rapp(kg_gift, kg_fonti, weight),
    q_acq_media = mean(q_acq, na.rm = TRUE), q_auto_media = mean(q_auto, na.rm = TRUE), q_regali_media = mean(q_regali, na.rm = TRUE),
    q_auto_aggregata_pesata_kg_osservati = rapp(kg_own[kg_est %in% 0], kg_fonti[kg_est %in% 0], weight[kg_est %in% 0]),
    ## valori (7 giorni, TZS): acquisti osservati, autoconsumo e regali stimati
    val_acq_medio_pesato = wmean(val_acq, weight),
    val_auto_medio_pesato = wmean(val_auto, weight),
    val_regali_medio_pesato = wmean(val_regali, weight),
    qv_acq_aggregata_pesata = rapp(val_acq, val_tot, weight),
    qv_auto_aggregata_pesata = rapp(val_auto, val_tot, weight),
    qv_regali_aggregata_pesata = rapp(val_regali, val_tot, weight),
    autoconsumo_regali_senza_prezzo = sum((kg_own > 0 | kg_gift > 0) & is.na(prezzo_unitario), na.rm = TRUE),
    .groups = "drop")

tab_round <- fam %>% group_by(year) %>%
  summarise(
    famiglie = n(),
    famiglie_totale_completo = sum(!is.na(val_prot)),
    famiglie_con_food_ufficiale = sum(!is.na(food_cons_hh_annual)),
    food_ufficiale_7gg_medio_pesato = wmean(food_ufficiale_7gg, weight),
    spesa_prot_media_pesata = wmean(spesa_prot, weight),
    val_prot_medio_pesato = wmean(val_prot, weight),
    quota_food_su_consumo_totale_pesata = rapp(food_cons_hh_annual, cons_total_hh_annual, weight),
    quota_spesa_prot_su_food_aggregata_pesata = rapp(spesa_prot, food_ufficiale_7gg, weight),
    quota_valore_prot_su_food_aggregata_pesata = rapp(val_prot, food_ufficiale_7gg, weight),
    quota_valore_prot_su_food_mediana = median(quota_prot_valore_su_food, na.rm = TRUE),
    ## peso delle fonti sul consumo (in valore) degli alimenti proteici
    qv_acquisti_pesata = rapp(val_acq, val_prot, weight),
    qv_autoconsumo_pesata = rapp(val_auto, val_prot, weight),
    qv_regali_pesata = rapp(val_regali, val_prot, weight),
    qv_acquisti_non_pesata = rapp(val_acq, val_prot),
    qv_autoconsumo_non_pesata = rapp(val_auto, val_prot),
    qv_regali_non_pesata = rapp(val_regali, val_prot),
    qv_autoconsumo_media_familiare = mean(q_val_auto, na.rm = TRUE),
    .groups = "drop")

## per area (urbana / rurale), solo pesate
tab_round_area <- fam %>% group_by(year, area = ifelse(rural == 1, "rurale", "urbana")) %>%
  summarise(famiglie = n(),
            quota_valore_prot_su_food = rapp(val_prot, food_ufficiale_7gg, weight),
            qv_acquisti = rapp(val_acq, val_prot, weight), qv_autoconsumo = rapp(val_auto, val_prot, weight),
            qv_regali = rapp(val_regali, val_prot, weight), .groups = "drop")

prezzi <- acq %>% group_by(year, categoria) %>%
  summarise(acquisti_con_kg_osservati = n(), prezzo_mediano_TZS_kg = median(pu),
            p10 = quantile(pu, 0.1), p90 = quantile(pu, 0.9), .groups = "drop") %>%
  left_join(lungo %>% filter(kg_own > 0 | kg_gift > 0) %>% count(year, categoria, livello_prezzo) %>%
              pivot_wider(names_from = livello_prezzo, values_from = n, values_fill = 0, names_prefix = "valorizzati_con_prezzo_"),
            by = c("year", "categoria"))

## ---------------------------------------------------------------------------
## 7. Controlli di qualita'
## ---------------------------------------------------------------------------
qc_mancanti <- lungo %>% group_by(year, categoria) %>%
  summarise(famiglie = n(), cons_1 = sum(cons %in% 1), cons_0 = sum(cons %in% 0), cons_mancante = sum(is.na(cons)),
            consumato_spesa_mancante = sum(cons %in% 1 & is.na(exp)),
            consumato_spesa_zero = sum(cons %in% 1 & exp %in% 0),                # zero reale: consumato ma non comprato
            consumato_kg_tot_mancante = sum(cons %in% 1 & is.na(kg_tot)),
            consumato_kg_pur_mancante = sum(cons %in% 1 & is.na(kg_pur)),
            kg_pur_pos_spesa_mancante = sum(kg_pur > 0 & is.na(exp), na.rm = TRUE),
            spesa_pos_kg_pur_zero = sum(exp > 0 & kg_pur %in% 0, na.rm = TRUE),
            non_consumato_valori_non_zero = sum(cons %in% 0 & (is.na(kg_tot) | kg_tot != 0 | is.na(exp) | exp != 0)),
            .groups = "drop")
qc_negativi <- lungo %>% summarise(across(c(kg_tot, kg_pur, kg_own, kg_gift, exp, val_auto, val_regali), ~ sum(.x < 0, na.rm = TRUE))) %>%
  pivot_longer(everything(), names_to = "variabile", values_to = "valori_negativi")
qc_fonti <- lungo %>% filter(cons %in% 1, !is.na(kg_tot), !is.na(kg_fonti)) %>% group_by(year, categoria) %>%
  summarise(consumatori_con_kg = n(),
            fonti_uguali_al_totale = mean(abs(kg_fonti - kg_tot) <= TOLL * kg_tot + 1e-9),
            fonti_uguali_al_totale_kg_osservati = mean((abs(kg_fonti - kg_tot) <= TOLL * kg_tot + 1e-9)[kg_est %in% 0]),
            rapporto_fonti_totale_mediano_se_diverso = median((kg_fonti / kg_tot)[abs(kg_fonti - kg_tot) > TOLL * kg_tot + 1e-9]),
            .groups = "drop")
qc_somme <- bind_rows(
  lungo %>% filter(!is.na(quota_su_spesa_prot)) %>% group_by(year, hhid) %>% summarise(s = sum(quota_su_spesa_prot), .groups = "drop") %>%
    group_by(year) %>% summarise(controllo = "quote di categoria sulla spesa proteica = 1", famiglie = n(), ok = sum(abs(s - 1) < 1e-9), .groups = "drop"),
  lungo %>% filter(!is.na(q_acq)) %>% group_by(year) %>%
    summarise(controllo = "quote acquisti + autoconsumo + regali (kg) = 1", famiglie = n(), ok = sum(abs(q_acq + q_auto + q_regali - 1) < 1e-9), .groups = "drop"),
  fam %>% filter(!is.na(q_val_acq)) %>% group_by(year) %>%
    summarise(controllo = "quote acquisti + autoconsumo + regali (valore) = 1", famiglie = n(), ok = sum(abs(q_val_acq + q_val_auto + q_val_regali - 1) < 1e-9), .groups = "drop"),
  tab_round %>% transmute(year, controllo = "quote aggregate pesate delle fonti (valore) = 1", famiglie = NA_integer_,
                          ok = as.integer(abs(qv_acquisti_pesata + qv_autoconsumo_pesata + qv_regali_pesata - 1) < 1e-9)))
qc_denominatori <- fam %>% group_by(year) %>%
  summarise(famiglie = n(),
            spesa_prot_zero = sum(spesa_prot %in% 0),                    # nessun acquisto di alimenti proteici: quota non definita
            spesa_prot_mancante = sum(is.na(spesa_prot)),
            valore_prot_zero = sum(val_prot %in% 0),
            valore_prot_mancante = sum(is.na(val_prot)),
            food_ufficiale_mancante = sum(is.na(food_cons_hh_annual)),
            food_ufficiale_zero = sum(food_cons_hh_annual %in% 0),
            peso_mancante = sum(is.na(weight)),
            quota_prot_su_food_oltre_1 = sum(quota_prot_valore_su_food > 1, na.rm = TRUE),
            .groups = "drop")
qc_conversioni <- lungo %>% filter(cons %in% 1) %>% group_by(year, categoria) %>%
  summarise(consumatori = n(), kg_stimati_dai_prezzi = sum(kg_est %in% 1), quota_kg_stimati = mean(kg_est %in% 1),
            autoconsumo_o_regali = sum((kg_own > 0 | kg_gift > 0) %in% TRUE),
            valore_stimato_prezzo_locale = sum((kg_own > 0 | kg_gift > 0) %in% TRUE & livello_prezzo %in% c("regione x area", "regione")),
            valore_stimato_prezzo_nazionale = sum((kg_own > 0 | kg_gift > 0) %in% TRUE & livello_prezzo == "paese"),
            valore_non_stimabile = sum((kg_own > 0 | kg_gift > 0) %in% TRUE & livello_prezzo == "nessuno"),
            .groups = "drop")

## ---------------------------------------------------------------------------
## 8. Esportazione
## ---------------------------------------------------------------------------
metodo <- data.frame(punto = c("file", "categorie", "denominatore", "spesa", "autoconsumo e regali", "quantita'", "mancanti e anomalie", "pesi", "annualizzazione"),
  descrizione = c(percorso,
    "17 categorie di alimenti ricchi di proteine; in Tanzania non raccolte processed_red_meat e soy (tutti i round), pulses_fresh fino al 2014 e per 419 famiglie del 2020",
    "consumo alimentare ufficiale food_cons_hh_annual (foodIN + foodOUT) x 7/365; la somma delle categorie e' solo la spesa per alimenti proteici",
    "<cat>_exp = spesa a 7 giorni per la quantita' consumata da acquisti",
    paste0("valore stimato = kg x prezzo unitario mediano (spesa/kg acquistati, kg osservati) per categoria e round: regione x area urbana/rurale (>= ", N_MIN_PREZZO,
           " acquisti), regione (>= ", N_MIN_PREZZO, "), paese (>= ", N_MIN_PREZZO_PAESE, ")"),
    "quote delle fonti = kg della fonte / (kg acquisti + autoconsumo + regali); i kg di categorie diverse non si sommano",
    paste0("0 = non consumato o fonte non usata; NA = mancante; i totali familiari sono NA se manca una categoria raccolta; ",
           "quantita' oltre ", LIMITE_KG_AE_GIORNO, " kg per adulto equivalente al giorno in una categoria: NA (foglio qc_quantita_anomale)"),
    "statistiche pesate con weight (peso campionario della famiglia); medie e mediane non pesate dove indicato",
    "food_cons_hh_annual e' annuale: x 7/365 per confrontarlo con i 7 giorni del modulo alimentare"))
out <- list(metodo = metodo, disponibilita = disp, cons_mancante = na_cons, qc_quantita_anomale = qc_anomalie, tab_categoria_round = tab_cat, tab_round = tab_round, tab_round_area = tab_round_area,
            prezzi_unitari = prezzi, famiglie = fam, famiglie_categorie = lungo %>% mutate(categoria = as.character(categoria)),
            qc_mancanti_zeri = qc_mancanti, qc_negativi = qc_negativi, qc_fonti_vs_totale = qc_fonti, qc_somme_quote = qc_somme,
            qc_denominatori = qc_denominatori, qc_conversioni_stime = qc_conversioni)
if (requireNamespace("writexl", quietly = TRUE)) writexl::write_xlsx(out, uscita) else openxlsx::write.xlsx(out, uscita, overwrite = TRUE)
cat("\nRisultati scritti in:", uscita, "\n")

## ---------------------------------------------------------------------------
## 9. Stampa dei risultati principali
## ---------------------------------------------------------------------------
options(width = 200, pillar.sigfig = 4)
cat("\n== Peso delle fonti sul consumo (valore) degli alimenti proteici, per round ==\n")
print(as.data.frame(tab_round %>% mutate(across(where(is.double), ~ round(.x, 3)))))
cat("\n== Quota aggregata pesata del valore di ciascuna categoria sul consumo alimentare ufficiale ==\n")
print(as.data.frame(tab_cat %>% select(year, categoria, quota_valore_food_aggregata_pesata) %>%
  pivot_wider(names_from = year, values_from = quota_valore_food_aggregata_pesata) %>% mutate(across(-categoria, ~ round(.x, 4)))))
cat("\n== Quota aggregata pesata della spesa (acquisti) di ciascuna categoria sulla spesa proteica ==\n")
print(as.data.frame(tab_cat %>% select(year, categoria, quota_spesa_prot_aggregata_pesata) %>%
  pivot_wider(names_from = year, values_from = quota_spesa_prot_aggregata_pesata) %>% mutate(across(-categoria, ~ round(.x, 3)))))
cat("\n== Quota dell'autoconsumo in quantita' (aggregata pesata) ==\n")
print(as.data.frame(tab_cat %>% select(year, categoria, q_auto_aggregata_pesata) %>%
  pivot_wider(names_from = year, values_from = q_auto_aggregata_pesata) %>% mutate(across(-categoria, ~ round(.x, 3)))))
cat("\n== Controlli ==\n"); print(as.data.frame(qc_somme)); print(as.data.frame(qc_denominatori)); print(as.data.frame(qc_negativi))
