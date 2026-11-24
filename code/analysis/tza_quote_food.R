###############################################################################
## Tanzania: quota di ogni categoria proteica sulla spesa alimentare ufficiale,
## e peso di acquisti, autoconsumo e regali
##
## Pacchetti: readxl, dplyr, tidyr, writexl (se writexl manca si usa openxlsx)
##
## Regole
## - Denominatore: sempre food_cons_hh_annual (consumo alimentare ufficiale, annuo, TZS nominali).
## - <cat>_exp e' la spesa degli ultimi 7 giorni (TZS nominali): si porta ad anno con x 365/7.
##   Il denominatore non si tocca.
## - Zeri restano zeri (non consumato / fonte non usata), mancanti restano NA.
## - Categorie non raccolte in un round: tutte NA, escluse dalle tabelle e segnalate nei controlli.
## - Valore di autoconsumo e regali (non osservato in Tanzania): kg x prezzo unitario mediano
##   (spesa / kg acquistati) della stessa categoria e dello stesso round, calcolato solo su
##   chi ha comprato con kg osservati (kg_est = 0); servono almeno 5 acquisti.
## - Quantita' non plausibili (totale o una fonte oltre 2 kg al giorno per adulto equivalente in una
##   categoria, es. 8.500 kg di pollame in una settimana): kg e valori stimati di quella riga = NA.
## - "Media household" = media semplice sulle famiglie (non pesata, zeri inclusi);
##   "quota aggregata pesata" = somma pesata del numeratore / somma pesata del denominatore.
###############################################################################

suppressPackageStartupMessages({ library(readxl); library(dplyr); library(tidyr) })

percorso <- "C:/Users/Medei/OneDrive - Food and Agriculture Organization/Desktop/ASF_household_food_TZA_2026-11-24.xlsx"
args <- commandArgs(trailingOnly = TRUE); if (length(args) >= 1) percorso <- args[1]     # solo per eseguirlo altrove
uscita <- if (length(args) >= 2) args[2] else file.path(dirname(percorso), "TZA_quote_food_risultati.xlsx")

A_ANNO <- 365 / 7          # da 7 giorni ad anno
LIMITE_KG <- 2             # kg per adulto equivalente al giorno, oltre = non plausibile
N_MIN <- 5                 # acquisti minimi per un prezzo unitario

## ---------------------------------------------------------------------------
## 1. Lettura e variabili
## ---------------------------------------------------------------------------
dati <- read_excel(percorso, sheet = "Data", guess_max = 50000) %>% filter(country == "TZA")
stopifnot(!anyDuplicated(dati[, c("year", "hhid")]))

## categorie dal foglio Items ("beef_*" -> "beef") e controllo dei nomi esatti delle colonne
categorie <- sub("_\\*$", "", read_excel(percorso, sheet = "Items")$column)
suff <- c("cons", "kg_tot", "kg_pur", "kg_own", "kg_gift", "exp", "kg_est")
stopifnot(all(as.vector(outer(categorie, suff, paste, sep = "_")) %in% names(dati)),
          all(c("food_cons_hh_annual", "weight", "adulteq", "hhsize") %in% names(dati)))

## stesso periodo e stessa moneta? dal dizionario del file
diz <- read_excel(percorso, sheet = "Dictionary")
print(diz %>% filter(column %in% c("food_cons_hh_annual", "<item>_exp")) %>% select(column, definition, unit))
## food_cons_hh_annual: annuo, valuta locale (TZS);  <item>_exp: 7 giorni, valuta locale (TZS)

## formato lungo: famiglia x round x categoria
lungo <- dati %>%
  select(year, hhid, weight, adulteq, hhsize, food_cons_hh_annual, all_of(as.vector(outer(categorie, suff, paste, sep = "_")))) %>%
  pivot_longer(starts_with(categorie), names_to = c("categoria", ".value"),
               names_pattern = paste0("^(", paste(categorie, collapse = "|"), ")_(", paste(suff, collapse = "|"), ")$")) %>%
  mutate(categoria = factor(categoria, levels = categorie))

## categorie raccolte: almeno una famiglia del round con cons non mancante
raccolta <- lungo %>% group_by(year, categoria) %>% summarise(raccolta = any(!is.na(cons)), cons_mancante = sum(is.na(cons)), .groups = "drop")
lungo <- lungo %>% semi_join(filter(raccolta, raccolta), by = c("year", "categoria"))

## ---------------------------------------------------------------------------
## 2. Calcoli per famiglia x categoria
## ---------------------------------------------------------------------------
lungo <- lungo %>%
  mutate(ae = coalesce(ifelse(adulteq > 0, adulteq, NA), ifelse(hhsize > 0, hhsize, NA), 10),    # 10 se manca: segnala solo i casi estremi
         ## si controllano il totale e ogni fonte (es. 2014: 2.500 kg di legumi comprati con un totale di 1 kg)
         anomala = (pmax(kg_tot, kg_pur, kg_own, kg_gift, na.rm = TRUE) / ae / 7 > LIMITE_KG) %in% TRUE,
         across(c(kg_tot, kg_pur, kg_own, kg_gift), ~ ifelse(anomala, NA_real_, .x)),
         spesa_annua = exp * A_ANNO,                                                      # TZS per anno
         quota_food = ifelse(food_cons_hh_annual > 0, spesa_annua / food_cons_hh_annual, NA),
         kg_fonti = kg_pur + kg_own + kg_gift)                                          # quantita' totale = somma delle fonti

## prezzo unitario mediano per categoria e round (TZS per kg)
prezzi <- lungo %>% filter(cons %in% 1, kg_pur > 0, exp > 0, kg_est %in% 0) %>%
  group_by(year, categoria) %>% summarise(prezzo_kg = median(exp / kg_pur), acquisti = n(), .groups = "drop") %>%
  mutate(prezzo_kg = ifelse(acquisti >= N_MIN, prezzo_kg, NA))
lungo <- lungo %>% left_join(prezzi, by = c("year", "categoria")) %>%
  mutate(valore_acquisti = spesa_annua,                                                 # osservato
         valore_auto = ifelse(kg_own == 0, 0, kg_own * prezzo_kg * A_ANNO),             # stimato, TZS per anno
         valore_regali = ifelse(kg_gift == 0, 0, kg_gift * prezzo_kg * A_ANNO),
         valore_tot = valore_acquisti + valore_auto + valore_regali)

## ---------------------------------------------------------------------------
## 3. Tabelle per round e categoria
## ---------------------------------------------------------------------------
agg <- function(num, den, w) { ok <- !is.na(num) & !is.na(den) & !is.na(w); if (!any(ok)) NA_real_ else sum(num[ok] * w[ok]) / sum(den[ok] * w[ok]) }
media <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)

t1_quote <- lungo %>% group_by(round = year, categoria) %>%
  summarise(famiglie = n(),
            quota_consumatori = mean(cons %in% 1),
            spesa_media_annua_TZS = media(spesa_annua),                                 # media household, zeri inclusi
            quota_food_media_household = media(quota_food),                             # media delle quote familiari, non pesata
            quota_food_aggregata_pesata = agg(spesa_annua, food_cons_hh_annual, weight), # somma pesata / somma pesata
            .groups = "drop")

t2_quantita <- lungo %>% group_by(round = year, categoria) %>%
  summarise(famiglie = n(),
            kg_acquistati_medi = media(kg_pur), kg_autoconsumo_medi = media(kg_own), kg_regali_medi = media(kg_gift),   # kg in 7 giorni, media household
            quota_acquisti_kg_aggregata_pesata = agg(kg_pur, kg_fonti, weight),
            quota_autoconsumo_kg_aggregata_pesata = agg(kg_own, kg_fonti, weight),
            quota_regali_kg_aggregata_pesata = agg(kg_gift, kg_fonti, weight),
            quota_autoconsumo_kg_media_household = media(ifelse(kg_fonti > 0, kg_own / kg_fonti, NA)),   # solo chi consuma
            quota_regali_kg_media_household = media(ifelse(kg_fonti > 0, kg_gift / kg_fonti, NA)),
            .groups = "drop")

## senza prezzo (meno di 5 acquisti nel round) i valori stimati non esistono: NA, non 0
t3_valori <- lungo %>% group_by(round = year, categoria) %>%
  filter(!is.na(prezzo_kg)) %>%
  summarise(prezzo_kg_TZS = first(prezzo_kg),
            valore_acquisti_medio_annuo = media(valore_acquisti),
            valore_autoconsumo_medio_annuo = media(valore_auto),
            valore_regali_medio_annuo = media(valore_regali),
            quota_valore_autoconsumo_aggregata_pesata = agg(valore_auto, valore_tot, weight),
            quota_valore_regali_aggregata_pesata = agg(valore_regali, valore_tot, weight),
            quota_food_autoconsumo_aggregata_pesata = agg(valore_auto, food_cons_hh_annual, weight),   # stesso denominatore ufficiale
            quota_food_regali_aggregata_pesata = agg(valore_regali, food_cons_hh_annual, weight),
            .groups = "drop") %>%
  right_join(t1_quote %>% select(round, categoria), by = c("round", "categoria")) %>% arrange(round, categoria)

## ---------------------------------------------------------------------------
## 4. Controlli di qualita'
## ---------------------------------------------------------------------------
c_cat <- lungo %>% group_by(round = year, categoria) %>%
  summarise(famiglie = n(), consumatori = sum(cons %in% 1), non_consumatori = sum(cons %in% 0),
            cons_mancante = sum(is.na(cons)),                                         # pulses_fresh 2020: voce assente per una parte del campione
            spesa_mancante_tra_consumatori = sum(cons %in% 1 & is.na(exp)),
            zeri_coerenti_non_consumatori = all((kg_tot[cons %in% 0] %in% 0 | anomala[cons %in% 0]) & exp[cons %in% 0] %in% 0),
            kg_fonti_mancanti_tra_consumatori = sum(cons %in% 1 & is.na(kg_fonti)),
            fonti_diverse_da_kg_tot_oltre_1pct = sum(abs(kg_fonti - kg_tot) > 0.01 * kg_tot + 1e-9, na.rm = TRUE),
            kg_stimati_dai_prezzi = sum(kg_est %in% 1),
            quantita_non_plausibili = sum(anomala),
            negativi = sum(c(kg_tot, kg_pur, kg_own, kg_gift, exp) < 0, na.rm = TRUE),
            acquisti_per_prezzo = first(acquisti),
            autoconsumo_regali_senza_prezzo = sum((kg_own > 0 | kg_gift > 0) & is.na(prezzo_kg), na.rm = TRUE),
            .groups = "drop")
c_round <- dati %>% group_by(round = year) %>%
  summarise(famiglie = n(), food_mancante = sum(is.na(food_cons_hh_annual)), food_zero = sum(food_cons_hh_annual %in% 0),
            peso_mancante = sum(is.na(weight)), .groups = "drop") %>%
  left_join(raccolta %>% filter(!raccolta) %>% group_by(round = year) %>% summarise(categorie_non_raccolte = paste(categoria, collapse = ", ")), by = "round")
c_quote <- lungo %>% filter(kg_fonti > 0) %>% summarise(quote_fonti_che_sommano_a_1 = mean(abs((kg_pur + kg_own + kg_gift) / kg_fonti - 1) < 1e-9))
print(c_round); print(c_quote)
controlli <- bind_rows(c_round %>% mutate(categoria = "(tutte)"), c_cat %>% mutate(categoria = as.character(categoria))) %>%
  relocate(round, categoria) %>% arrange(round, categoria != "(tutte)")

## ---------------------------------------------------------------------------
## 5. Esportazione
## ---------------------------------------------------------------------------
note <- data.frame(nota = c(
  "Quota sul food = spesa della categoria (7 giorni x 365/7) / food_cons_hh_annual (annuo, TZS). Il denominatore e' sempre quello ufficiale.",
  "Media household = media semplice sulle famiglie (zeri inclusi), non pesata. Aggregata pesata = somma pesata del numeratore / somma pesata del denominatore.",
  "Quantita': kg consumati in 7 giorni. Quantita' totale = acquisti + autoconsumo + regali (kg_pur + kg_own + kg_gift).",
  "Autoconsumo e regali non hanno valori osservati: valore = kg x prezzo mediano (spesa/kg acquistati, kg osservati) della categoria nel round x 365/7.",
  "0 = non consumato o fonte non usata; vuoto = mancante. Categorie non raccolte: escluse (foglio controlli).",
  "Quantita' (totale o una fonte) oltre 2 kg per adulto equivalente al giorno in una categoria: kg e valori stimati della riga mancanti (foglio controlli).",
  "Valori stimati vuoti per le categorie con meno di 5 acquisti nel round (nessun prezzo).",
  "Foglio media_anni: media semplice dei 5 round (ogni round conta uguale), solo le 14 categorie raccolte in tutti i round (pulses_fresh solo nel 2020).",
  "Nel foglio media_anni la spesa e i valori in TZS sono nominali: la media mescola prezzi di anni diversi (inflazione), le quote no.",
  "Le quote sono in percentuale (colonne _pct)."))

## ---------------------------------------------------------------------------
## 5b. Media tra i round: una riga per categoria (solo categorie raccolte in tutti i round)
## ---------------------------------------------------------------------------
n_round <- n_distinct(t1_quote$round)
tutte <- t1_quote %>% count(categoria) %>% filter(n == n_round) %>% pull(categoria)
media_anni <- t1_quote %>%
  left_join(t2_quantita, by = c("round", "categoria", "famiglie")) %>%
  left_join(t3_valori, by = c("round", "categoria")) %>%
  filter(categoria %in% tutte) %>%
  group_by(categoria) %>%
  summarise(round = n(),
            spesa_media_annua_TZS = round(mean(spesa_media_annua_TZS)),
            quota_food_media_household_pct = 100 * mean(quota_food_media_household),
            quota_food_aggregata_pesata_pct = 100 * mean(quota_food_aggregata_pesata),
            kg_acquistati_medi_7gg = round(mean(kg_acquistati_medi), 3),
            kg_autoconsumo_medi_7gg = round(mean(kg_autoconsumo_medi), 3),
            kg_regali_medi_7gg = round(mean(kg_regali_medi), 3),
            quota_acquisti_kg_pct = 100 * mean(quota_acquisti_kg_aggregata_pesata),
            quota_autoconsumo_kg_pct = 100 * mean(quota_autoconsumo_kg_aggregata_pesata),
            quota_regali_kg_pct = 100 * mean(quota_regali_kg_aggregata_pesata),
            valore_autoconsumo_medio_annuo_TZS = round(mean(valore_autoconsumo_medio_annuo, na.rm = TRUE)),
            valore_regali_medio_annuo_TZS = round(mean(valore_regali_medio_annuo, na.rm = TRUE)),
            quota_valore_autoconsumo_pct = 100 * mean(quota_valore_autoconsumo_aggregata_pesata, na.rm = TRUE),
            quota_valore_regali_pct = 100 * mean(quota_valore_regali_aggregata_pesata, na.rm = TRUE),
            round_con_valori_stimati = sum(!is.na(valore_autoconsumo_medio_annuo)),
            .groups = "drop") %>%
  mutate(across(where(is.double), ~ ifelse(is.nan(.x), NA_real_, .x)))

## i valori del foglio media_anni si arrotondano solo alla fine (la tabella semplice parte dai valori non arrotondati)
media_anni_out <- media_anni %>% mutate(across(ends_with("_pct"), ~ round(.x, 2)))

## quote in percentuale anche negli altri fogli: colonne quota_* x 100, nome con _pct
in_pct <- function(x) x %>% mutate(across(starts_with("quota_") & where(is.numeric), ~ round(100 * .x, 2))) %>%
  rename_with(~ paste0(.x, "_pct"), starts_with("quota_") & where(is.numeric))
## tabella semplice (primo foglio): quote in %, ordinate per quota aggregata sul food
tabella <- media_anni %>% arrange(desc(quota_food_aggregata_pesata_pct)) %>%
  transmute(Categoria = as.character(categoria),
            `Quota media hh (%)` = round(quota_food_media_household_pct, 2),
            `Quota aggregata pesata (%)` = round(quota_food_aggregata_pesata_pct, 2),
            `Autoconsumo kg (%)` = round(quota_autoconsumo_kg_pct, 1),
            `Regali kg (%)` = round(quota_regali_kg_pct, 1),
            `Autoconsumo valore (%)` = round(quota_valore_autoconsumo_pct, 1),
            `Regali valore (%)` = round(quota_valore_regali_pct, 1))
print(as.data.frame(tabella))
fuori <- list(tabella = tabella, media_anni = media_anni_out, note = note, quote_spesa_food = in_pct(t1_quote), quantita_fonti = in_pct(t2_quantita),
              valori_stimati = in_pct(t3_valori), controlli = controlli)
fuori <- lapply(fuori, function(x) mutate(x, across(where(is.factor), as.character)))
if (requireNamespace("writexl", quietly = TRUE)) writexl::write_xlsx(fuori, uscita) else openxlsx::write.xlsx(fuori, uscita, overwrite = TRUE)
cat("Risultati in:", uscita, "\n")

## ---------------------------------------------------------------------------
## 6. Stampa compatta per round
## ---------------------------------------------------------------------------
pct <- function(x) round(100 * x, 1)
for (r in sort(unique(t1_quote$round))) {
  cat("\n=====", r, "=====\n")
  print(as.data.frame(t1_quote %>% filter(round == r) %>%
    left_join(t2_quantita, by = c("round", "categoria", "famiglie")) %>% left_join(t3_valori, by = c("round", "categoria")) %>%
    transmute(categoria, spesa_annua = round(spesa_media_annua_TZS), quota_media_pct = pct(quota_food_media_household),
              quota_aggr_pct = pct(quota_food_aggregata_pesata), kg_acq = round(kg_acquistati_medi, 3), kg_auto = round(kg_autoconsumo_medi, 3),
              kg_regali = round(kg_regali_medi, 3), auto_kg_pct = pct(quota_autoconsumo_kg_aggregata_pesata), regali_kg_pct = pct(quota_regali_kg_aggregata_pesata),
              val_auto = round(valore_autoconsumo_medio_annuo), val_regali = round(valore_regali_medio_annuo))), row.names = FALSE)
}
