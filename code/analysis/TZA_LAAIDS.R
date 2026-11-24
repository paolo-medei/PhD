###############################################################################
##  LA/AIDS PER LA TANZANIA (NPS 2008, 2010, 2012, 2014, 2020)
##  Dai dati grezzi armonizzati alle elasticita' - script didattico, da eseguire sezione per sezione
##
##  Dati di partenza: TZA_dati_grezzi_LAAIDS_<data>.xlsx (fogli voci, famiglie, unita, voci_gruppi)
##  Metodo:
##   - prezzi: valori unitari degli acquisti (spesa / quantita'), mediane locali EA -> distretto -> regione -> paese
##   - autoconsumo e regali: quantita' x prezzo mediano locale (stessa voce, stessa unita')
##   - 10 gruppi; quote sul cibo consumato a casa
##   - prezzi dei gruppi: media geometrica pesata dei prezzi locali delle voci del gruppo
##   - indice di Stone con le quote MEDIE del campione (Moschini 1995), spesa reale = spesa / indice
##   - LA/AIDS con zeri: due stadi di Shonkwiler e Yen (1999); spesa alimentare endogena: control function
##     con la spesa totale della famiglia come strumento; SUR con omogeneita' e simmetria; adding-up dal gruppo "altro"
##   - elasticita' (spesa, Marshall, Hicks) ai valori medi, per tutto il campione e per round
##  Pacchetti: readxl, dplyr, tidyr, systemfit, openxlsx  ->  install.packages(c("readxl","dplyr","tidyr","systemfit","openxlsx"))
###############################################################################


## =============================================================================
## 0. IMPOSTAZIONI
## =============================================================================
library(readxl)
library(dplyr)
library(tidyr)
library(systemfit)
library(openxlsx)

FILE   <- "C:/Users/Medei/Desktop/PhD_v21/data/OUTPUT/analisi_TZA/TZA_dati_grezzi_LAAIDS_2026-11-24.xlsx"
USCITA <- file.path(dirname(FILE), paste0("risultati_LAAIDS_TZA_", Sys.Date()))   # cartella nuova: i dati originali non si toccano
dir.create(USCITA, showWarnings = FALSE)

N_MIN  <- 5     # numero minimo di acquisti per calcolare una mediana locale
SOGLIA <- 10    # prezzo anomalo: oltre 10 volte, o sotto 1/10, la mediana nazionale della stessa voce e unita'

GRUPPI <- c("cereali", "tuberi", "legumi_noci_semi", "frutta_verdura", "carne_rossa",
            "pollame", "pesce", "latte", "uova", "altro")
G      <- length(GRUPPI)          # 10 gruppi
GS     <- GRUPPI[1:(G - 1)]       # i 9 gruppi stimati; "altro" (oli, zucchero, spezie, bevande) e' il residuo
DEMO   <- c("ln_ampiezza", "rurale", "capo_donna")     # variabili demografiche nelle equazioni


## =============================================================================
## 1. CARICARE I DATI
## =============================================================================
voci     <- read_excel(FILE, sheet = "voci", guess_max = 1e6)       # una riga per famiglia x voce consumata (valori originali)
famiglie <- read_excel(FILE, sheet = "famiglie", guess_max = 1e6)   # una riga per famiglia x round
cat("Righe lette - voci:", nrow(voci), " famiglie:", nrow(famiglie), "\n")

# fuori: le voci escluse dal bilancio (burro-margarina, uccelli selvatici) e, nel 2020, le 419 famiglie del
# campione hh_sec_j1, che hanno risposto a un modulo di consumo diverso
voci     <- voci     %>% mutate(campione = coalesce(campione, "")) %>% filter(gruppo != "escluso", campione != "hh_sec_j1")
famiglie <- famiglie %>% mutate(campione = coalesce(campione, "")) %>% filter(campione != "hh_sec_j1")

# controllo valori mancanti nelle variabili che servono
cat("\nValori mancanti nel foglio famiglie:\n")
print(colSums(is.na(famiglie[, c("regione", "id_distretto", "id_ea", "ampiezza", "rurale", "capo_donna", "spesa_totale_annua")])))
cat("Voci consumate senza nessuna quantita':", sum(is.na(voci$q_tot) & is.na(voci$q_acq) & is.na(voci$q_auto) & is.na(voci$q_regali)), "\n")


## =============================================================================
## 2. VALORI UNITARI DEGLI ACQUISTI: spesa / quantita' acquistata
## =============================================================================
# 2.1 Unita' standard: i grammi diventano kg (codice 1), i millilitri litri (codice 3); pezzi (5) e unita' locali
#     del 2020 (6-20) restano come sono. Il prezzo vale sempre "per unita'" della stessa voce.
voci <- voci %>% mutate(
  q_acq_s    = ifelse(u_acq    %in% c(2, 4), q_acq    / 1000, q_acq),
  u_acq_s    = ifelse(u_acq    == 2, 1, ifelse(u_acq    == 4, 3, u_acq)),
  q_auto_s   = ifelse(u_auto   %in% c(2, 4), q_auto   / 1000, q_auto),
  u_auto_s   = ifelse(u_auto   == 2, 1, ifelse(u_auto   == 4, 3, u_auto)),
  q_regali_s = ifelse(u_regali %in% c(2, 4), q_regali / 1000, q_regali),
  u_regali_s = ifelse(u_regali == 2, 1, ifelse(u_regali == 4, 3, u_regali)),
  q_tot_s    = ifelse(u_tot    %in% c(2, 4), q_tot    / 1000, q_tot),
  u_tot_s    = ifelse(u_tot    == 2, 1, ifelse(u_tot    == 4, 3, u_tot)))

# 2.2 Valore unitario: uv = spesa / quantita' acquistata (TSH per unita'), solo se entrambe sono positive
voci <- voci %>% mutate(uv = ifelse(q_acq_s > 0 & spesa_acq > 0, spesa_acq / q_acq_s, NA))

# 2.3 Prezzi anomali: confronto con la mediana nazionale della stessa voce e unita' nello stesso round
med_naz_uv <- voci %>% filter(!is.na(uv)) %>% group_by(round, codice_voce, u_acq_s) %>%
  summarise(med_uv = median(uv), n_uv = n(), .groups = "drop")
voci <- voci %>% left_join(med_naz_uv, by = c("round", "codice_voce", "u_acq_s")) %>%
  mutate(flag_uv_anomalo = !is.na(uv) & n_uv >= N_MIN & (uv > SOGLIA * med_uv | uv < med_uv / SOGLIA)) %>%
  select(-med_uv, -n_uv)
cat("\nValori unitari calcolati:", sum(!is.na(voci$uv)), " di cui anomali (esclusi dalle mediane):", sum(voci$flag_uv_anomalo), "\n")


## =============================================================================
## 3. PREZZI MEDIANI LOCALI per voce e unita': EA -> distretto -> regione -> paese
## =============================================================================
# il prezzo di una voce in un luogo e' la mediana dei valori unitari degli acquisti fatti li';
# si usa il livello piu' piccolo che ha almeno N_MIN acquisti
voci <- voci %>% left_join(famiglie %>% select(round, hhid, id_ea, id_distretto, regione), by = c("round", "hhid"))
acquisti <- voci %>% filter(!is.na(uv), !is.na(u_acq_s), !flag_uv_anomalo) %>% rename(unita = u_acq_s)

med_ea  <- acquisti %>% filter(!is.na(id_ea)) %>% group_by(round, codice_voce, unita, id_ea) %>%
  summarise(p_ea = median(uv), n_ea = n(), .groups = "drop") %>% filter(n_ea >= N_MIN)
med_dis <- acquisti %>% filter(!is.na(id_distretto)) %>% group_by(round, codice_voce, unita, id_distretto) %>%
  summarise(p_dis = median(uv), n_dis = n(), .groups = "drop") %>% filter(n_dis >= N_MIN)
med_reg <- acquisti %>% filter(!is.na(regione)) %>% group_by(round, codice_voce, unita, regione) %>%
  summarise(p_reg = median(uv), n_reg = n(), .groups = "drop") %>% filter(n_reg >= N_MIN)
med_naz <- acquisti %>% group_by(round, codice_voce, unita) %>%
  summarise(p_naz = median(uv), n_naz = n(), .groups = "drop") %>% filter(n_naz >= N_MIN)

# una sola funzione: dato un elenco (round, voce, unita, luogo) restituisce il prezzo locale e il livello usato
prezzo_locale <- function(d) {
  d <- d %>%
    left_join(med_ea,  by = c("round", "codice_voce", "unita", "id_ea")) %>%
    left_join(med_dis, by = c("round", "codice_voce", "unita", "id_distretto")) %>%
    left_join(med_reg, by = c("round", "codice_voce", "unita", "regione")) %>%
    left_join(med_naz, by = c("round", "codice_voce", "unita"))
  data.frame(prezzo  = coalesce(d$p_ea, d$p_dis, d$p_reg, d$p_naz),
             livello = case_when(!is.na(d$p_ea) ~ "EA", !is.na(d$p_dis) ~ "distretto", !is.na(d$p_reg) ~ "regione",
                                 !is.na(d$p_naz) ~ "paese", TRUE ~ "nessun prezzo"))
}


## =============================================================================
## 4. VALORE DI AUTOCONSUMO E REGALI: quantita' x prezzo locale imputato
## =============================================================================
pa <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_auto_s,   id_ea, id_distretto, regione))
pr <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_regali_s, id_ea, id_distretto, regione))
pq <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_acq_s,    id_ea, id_distretto, regione))
pt <- prezzo_locale(voci %>% transmute(round, codice_voce, unita = u_tot_s,    id_ea, id_distretto, regione))
voci <- voci %>% mutate(
  liv_prezzo_auto = ifelse(coalesce(q_auto_s, 0) > 0, pa$livello, NA), liv_prezzo_regali = ifelse(coalesce(q_regali_s, 0) > 0, pr$livello, NA),
  # autoconsumo e regali: valore = quantita' x prezzo locale (0 se la fonte non e' usata)
  val_auto   = ifelse(coalesce(q_auto_s, 0) > 0, q_auto_s * pa$prezzo, 0),
  val_regali = ifelse(coalesce(q_regali_s, 0) > 0, q_regali_s * pr$prezzo, 0),
  # acquisti: la spesa dichiarata; se manca, o se il valore unitario e' anomalo, quantita' x prezzo locale
  flag_acq_rivalutato = (coalesce(q_acq_s, 0) > 0) & (is.na(spesa_acq) | spesa_acq <= 0 | flag_uv_anomalo),
  val_acq    = case_when(flag_acq_rivalutato ~ q_acq_s * pq$prezzo,
                         spesa_acq > 0       ~ spesa_acq,
                         TRUE                ~ 0),
  # voce consumata ma senza nessuna fonte compilata: si valuta la quantita' totale
  flag_solo_totale = !(coalesce(q_acq_s, 0) > 0) & !(coalesce(q_auto_s, 0) > 0) & !(coalesce(q_regali_s, 0) > 0) & !(coalesce(spesa_acq, 0) > 0),
  val_solo_tot = ifelse(flag_solo_totale & coalesce(q_tot_s, 0) > 0, q_tot_s * pt$prezzo, 0))

# 4.1 Valori senza prezzo a nessun livello: imputati con la mediana del valore della stessa voce e fonte nel
#     round (tra le famiglie che hanno un valore) e segnalati (flag_imp_*). Quelli che restano senza valore
#     (la voce non ha nessun valore nel round) contano 0, sono contati a schermo e segnalati al passo 5.
imputa <- function(valore, fonte) {
  m <- voci %>% mutate(v = valore) %>% filter(coalesce(v, 0) > 0) %>% group_by(round, codice_voce) %>% summarise(med = median(v), .groups = "drop")
  med <- voci %>% select(round, codice_voce) %>% left_join(m, by = c("round", "codice_voce")) %>% pull(med)
  cat("  ", fonte, ": valori imputati", sum(is.na(valore) & !is.na(med)), " - ancora senza valore (contano 0)", sum(is.na(valore) & is.na(med)), "\n")
  list(valore = ifelse(is.na(valore), med, valore), flag = is.na(valore) & !is.na(med))
}
cat("\nImputazione dei valori senza prezzo:\n")
x <- imputa(voci$val_auto,     "autoconsumo"); voci$val_auto     <- x$valore; voci$flag_imp_auto     <- x$flag
x <- imputa(voci$val_regali,   "regali");      voci$val_regali   <- x$valore; voci$flag_imp_regali   <- x$flag
x <- imputa(voci$val_acq,      "acquisti");    voci$val_acq      <- x$valore; voci$flag_imp_acq      <- x$flag
x <- imputa(voci$val_solo_tot, "solo totale"); voci$val_solo_tot <- x$valore; voci$flag_imp_solo_tot <- x$flag
voci <- voci %>% mutate(flag_imputato = flag_imp_auto | flag_imp_regali | flag_imp_acq | flag_imp_solo_tot,
                        val_imputato  = flag_imp_auto * val_auto + flag_imp_regali * val_regali + flag_imp_acq * val_acq + flag_imp_solo_tot * val_solo_tot)

cat("\nLivello geografico del prezzo usato per l'autoconsumo (righe):\n"); print(table(voci$liv_prezzo_auto, useNA = "no"))


## =============================================================================
## 5. VALORE TOTALE DEL CONSUMO = acquisti + autoconsumo + regali
## =============================================================================
voci <- voci %>% mutate(val_tot = coalesce(val_acq, 0) + coalesce(val_auto, 0) + coalesce(val_regali, 0) + coalesce(val_solo_tot, 0),
                        flag_senza_valore = val_tot <= 0)
cat("\nVoci consumate con valore zero (nessuna quantita' valutabile):", sum(voci$flag_senza_valore), "\n")


## =============================================================================
## 6. AGGREGAZIONE NEI 10 GRUPPI (una riga per famiglia)
## =============================================================================
gruppi_hh <- voci %>% group_by(round, hhid, gruppo) %>%
  summarise(valore = sum(val_tot), imputato = sum(val_imputato, na.rm = TRUE), .groups = "drop")
valori <- gruppi_hh %>% select(-imputato) %>% pivot_wider(names_from = gruppo, values_from = valore, values_fill = 0, names_prefix = "v_")
dati <- famiglie %>% left_join(valori, by = c("round", "hhid")) %>%
  left_join(gruppi_hh %>% group_by(round, hhid) %>% summarise(valore_imputato = sum(imputato), .groups = "drop"), by = c("round", "hhid"))
for (g in GRUPPI) dati[[paste0("v_", g)]] <- coalesce(dati[[paste0("v_", g)]], 0)   # gruppo non consumato = 0
dati$valore_imputato <- coalesce(dati$valore_imputato, 0)


## =============================================================================
## 7. BUDGET ALIMENTARE E QUOTE DI SPESA
## =============================================================================
# budget alimentare x = somma dei 10 gruppi (cibo consumato a casa, 7 giorni, TSH)
# quota del gruppo g: w_g = v_g / x  (le 10 quote sommano a 1)
dati$x <- rowSums(dati[, paste0("v_", GRUPPI)])
dati$flag_budget_zero <- dati$x <= 0
n_budget_zero <- sum(dati$flag_budget_zero)
cat("\nFamiglie con budget alimentare nullo (mangiano solo fuori casa, escluse dalla stima):", n_budget_zero, "\n")
dati <- dati %>% filter(!flag_budget_zero)
for (g in GRUPPI) dati[[paste0("w_", g)]] <- dati[[paste0("v_", g)]] / dati$x
stopifnot(all(abs(rowSums(dati[, paste0("w_", GRUPPI)]) - 1) < 1e-9))      # controllo: le quote sommano a 1
dati$quota_imputata <- dati$valore_imputato / dati$x
cat("Quota del budget imputata: media", round(100 * mean(dati$quota_imputata), 2), "%\n")


## =============================================================================
## 8. PREZZI DEI GRUPPI, INDICE DI STONE, SPESA REALE
## =============================================================================
# 8.1 Unita' di riferimento di ogni voce: quella con piu' acquisti nel round (il prezzo della voce sara' in quella unita')
rif <- acquisti %>% count(round, codice_voce, gruppo, unita) %>% group_by(round, codice_voce) %>% slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>% select(round, codice_voce, gruppo, unita)

# 8.2 Peso di ogni voce nel suo gruppo: quota della voce nel valore del gruppo, nel round (uguale per tutte le famiglie)
pesi <- voci %>% group_by(round, gruppo, codice_voce) %>% summarise(v = sum(val_tot), .groups = "drop") %>%
  group_by(round, gruppo) %>% mutate(peso = v / sum(v)) %>% ungroup() %>% select(round, codice_voce, peso)

# 8.3 Prezzo locale di ogni voce per OGNI famiglia, anche per chi non la compra (stessa mediana EA -> paese)
griglia <- dati %>% select(round, hhid, id_ea, id_distretto, regione) %>%
  inner_join(rif, by = "round", relationship = "many-to-many") %>% left_join(pesi, by = c("round", "codice_voce"))
pp <- prezzo_locale(griglia %>% select(round, codice_voce, unita, id_ea, id_distretto, regione))
griglia$prezzo <- pp$prezzo; griglia$livello <- pp$livello
cat("\nPrezzi delle voci per famiglia, per livello geografico:\n"); print(round(100 * prop.table(table(griglia$livello)), 1))

# 8.4 Prezzo del gruppo: media geometrica pesata dei prezzi delle voci, ln P_g = sum_i peso_i ln p_i / sum_i peso_i
#     (voci senza prezzo nel round: fuori dall'indice, i pesi delle altre si riproporzionano)
pg <- griglia %>% filter(!is.na(prezzo), peso > 0) %>% group_by(round, hhid, gruppo) %>%
  summarise(lnP = sum(peso * log(prezzo)) / sum(peso), .groups = "drop") %>%
  pivot_wider(names_from = gruppo, values_from = lnP, names_prefix = "lnP_")
dati <- dati %>% left_join(pg, by = c("round", "hhid"))
cat("Famiglie senza prezzo per almeno un gruppo:", sum(!complete.cases(dati[, paste0("lnP_", GRUPPI)])), "\n")

# 8.5 Indice di Stone con le quote MEDIE del campione: ln P* = sum_g wbar_g ln P_g
#     (con le quote della famiglia la quota comparirebbe a destra e a sinistra dell'equazione: Buse 1994, Moschini 1995)
wbar <- colMeans(dati[, paste0("w_", GRUPPI)]); names(wbar) <- GRUPPI
dati$lnP_stone <- as.vector(as.matrix(dati[, paste0("lnP_", GRUPPI)]) %*% wbar)

# 8.6 Spesa reale e prezzi relativi
dati <- dati %>% mutate(ln_x = log(x), ln_x_reale = ln_x - lnP_stone, ln_ampiezza = log(ampiezza), ln_spesa_tot = log(spesa_totale_annua))
for (g in GS) dati[[paste0("lnp_", g)]] <- dati[[paste0("lnP_", g)]] - dati$lnP_altro   # prezzi relativi a "altro": omogeneita' imposta
PREL <- paste0("lnp_", GS)


## =============================================================================
## 9. STIMA DEL LA/AIDS (Shonkwiler-Yen, control function, SUR con omogeneita' e simmetria)
## =============================================================================
# campione di stima: famiglie con tutti i prezzi, le demografiche e lo strumento
stima <- dati %>% filter(complete.cases(dati[, c(PREL, "ln_x_reale", DEMO, "ln_spesa_tot")]))
stima$round_f <- factor(stima$round)
ROUND <- paste0("r", levels(stima$round_f)[-1])
for (r in levels(stima$round_f)[-1]) stima[[paste0("r", r)]] <- as.numeric(stima$round == as.numeric(r))   # dummy di round (base 2008)
cat("\nFamiglie nella stima:", nrow(stima), "su", nrow(dati), "\n")

# 9.1 Control function: ln x (spesa alimentare) regredito sullo strumento ln(spesa totale) e su tutte le variabili esogene.
#     Il residuo v_hat entra nelle equazioni delle quote e "pulisce" l'endogeneita' della spesa alimentare.
cf <- lm(as.formula(paste("ln_x ~ ln_spesa_tot +", paste(c(PREL, DEMO, ROUND), collapse = " + "))), data = stima)
cat("Primo stadio: coefficiente dello strumento", round(coef(cf)["ln_spesa_tot"], 3),
    " t =", round(summary(cf)$coefficients["ln_spesa_tot", "t value"], 1), "(uno strumento forte ha t ben sopra 3)\n")
stima$v_hat <- residuals(cf)

# 9.2 Primo stadio di Shonkwiler-Yen: per ogni gruppo un probit su "la famiglia lo consuma?" (w > 0),
#     con gli stessi regressori delle quote. Ne escono Phi = probabilita' di consumo e phi = densita' normale.
X_COM <- c(PREL, "ln_x_reale", DEMO, ROUND)
probit <- list()
for (g in GS) {
  stima[[paste0("d_", g)]] <- as.numeric(stima[[paste0("w_", g)]] > 0)
  probit[[g]] <- glm(as.formula(paste0("d_", g, " ~ ", paste(X_COM, collapse = " + "))), family = binomial(link = "probit"), data = stima)
  t_g <- predict(probit[[g]], type = "link")                       # indice lineare z'gamma
  stima[[paste0("t_", g)]]   <- t_g
  stima[[paste0("Phi_", g)]] <- pnorm(t_g)
  stima[[paste0("phi_", g)]] <- dnorm(t_g)
  cat(sprintf("  probit %-17s famiglie che consumano %5.1f%%\n", g, 100 * mean(stima[[paste0("d_", g)]])))
}

# 9.3 Secondo stadio: per ogni gruppo g
#     w_g = Phi_g * [ a_g + sum_j gamma_gj ln(p_j/p_altro) + beta_g ln(x/P*) + demografiche + round + rho_g v_hat ] + delta_g phi_g
#     L'equazione e' lineare nei parametri: ogni regressore tra parentesi viene moltiplicato per Phi_g.
X_LAT <- c(PREL, "ln_x_reale", DEMO, ROUND, "v_hat")     # regressori della parte "latente"
EQ <- setNames(gsub("_", "", GS), GS)                    # nomi delle equazioni senza "_" (systemfit non li accetta)
eqs <- list()
for (g in GS) {
  e <- EQ[g]
  nomi <- c(paste0(e, "_cost"), paste0(e, "_", X_LAT), paste0(e, "_phi"))
  stima[[nomi[1]]] <- stima[[paste0("Phi_", g)]]                                     # costante a_g
  for (v in X_LAT) stima[[paste0(e, "_", v)]] <- stima[[paste0("Phi_", g)]] * stima[[v]]
  stima[[nomi[length(nomi)]]] <- stima[[paste0("phi_", g)]]                          # termine delta_g * phi_g
  eqs[[e]] <- as.formula(paste0("w_", g, " ~ 0 + ", paste(nomi, collapse = " + ")))
}

# 9.4 Restrizioni. Omogeneita': gia' imposta (prezzi relativi). Simmetria: gamma_ij = gamma_ji per i, j fra i 9 gruppi.
#     In systemfit il coefficiente si chiama "<equazione>_<regressore>", es. "cereali_cereali_lnp_tuberi".
#     Nel sistema "legumi_noci_semi" si chiama "leguminocisemi", "carne_rossa" "carnerossa", ecc.
simm <- c()
for (i in 1:(G - 2)) for (j in (i + 1):(G - 1)) {
  gi <- GS[i]; gj <- GS[j]; ei <- EQ[gi]; ej <- EQ[gj]
  simm <- c(simm, paste0(ei, "_", ei, "_lnp_", gj, " - ", ej, "_", ej, "_lnp_", gi, " = 0"))
}
cat("\nRestrizioni di simmetria:", length(simm), "\n")

# 9.5 SUR (regressioni apparentemente non correlate) sulle 9 equazioni
sur <- systemfit(eqs, method = "SUR", data = stima, restrict.matrix = simm)
b   <- coef(sur)
cat("SUR stimato. R2 per equazione:\n"); print(round(sapply(summary(sur)$eq, function(e) e$r.squared), 3))

# 9.6 Parametri della parte latente, matrice gamma (9 x 10), beta, delta; il gruppo "altro" dall'adding-up
gam <- matrix(0, G, G, dimnames = list(GRUPPI, GRUPPI))
alfa <- beta <- delta <- setNames(rep(0, G), GRUPPI)
for (g in GS) {
  e <- EQ[g]
  alfa[g]  <- b[paste0(e, "_", e, "_cost")]
  beta[g]  <- b[paste0(e, "_", e, "_ln_x_reale")]
  delta[g] <- b[paste0(e, "_", e, "_phi")]
  for (j in GS) gam[g, j] <- b[paste0(e, "_", e, "_lnp_", j)]
  gam[g, "altro"] <- -sum(gam[g, GS])                      # omogeneita': ogni riga di gamma somma a zero
}
# adding-up: le quote latenti sommano a 1 -> sum_g alfa = 1, sum_g gamma_gj = 0, sum_g beta = 0
alfa["altro"] <- 1 - sum(alfa[GS]); beta["altro"] <- -sum(beta[GS]); gam["altro", ] <- -colSums(gam[GS, ])
cat("\nControlli: simmetria max|gamma - t(gamma)| =", signif(max(abs(gam - t(gam))), 3),
    "  omogeneita' max|somma righe| =", signif(max(abs(rowSums(gam))), 3), "\n")


## =============================================================================
## 10. ELASTICITA' (ai valori medi)
## =============================================================================
# Con Shonkwiler-Yen la quota attesa e' E(w_g) = Phi(t_g) * f_g + delta_g * phi(t_g), con f_g = parte latente.
# Derivata rispetto a una variabile s (ln x oppure ln p_j):
#     dE(w_g)/ds = Phi_g * df_g/ds  +  phi_g * (f_g - delta_g * t_g) * dt_g/ds
# perche' dPhi/dt = phi e dphi/dt = -t * phi. Con lo Stone a quote medie: d ln P*/d ln p_j = wbar_j.
#   df_g/d ln x   = beta_g                         dt_g/d ln x   = c_g (coeff. del probit su ln x reale)
#   df_g/d ln p_j = gamma_gj - beta_g wbar_j       dt_g/d ln p_j = c_gj - c_g wbar_j  (c_g,altro = -somma dei c_gj)
# Elasticita':  spesa  e_g  = 1 + (dE(w_g)/d ln x) / w_g
#               Marshall e_gj = -1(g=j) + (dE(w_g)/d ln p_j) / w_g
#               Hicks    e*_gj = e_gj + e_g * w_j              (equazione di Slutsky)
# Il gruppo "altro" ha derivate = -(somma delle derivate degli altri gruppi) (adding-up).
elasticita <- function(d) {
  w  <- colMeans(d[, paste0("w_", GRUPPI)]); names(w) <- GRUPPI          # quote medie del sottocampione
  dX <- setNames(rep(0, G), GRUPPI); dP <- matrix(0, G, G, dimnames = list(GRUPPI, GRUPPI))
  for (g in GS) {
    cp <- coef(probit[[g]])
    t  <- mean(d[[paste0("t_", g)]])                                       # indice del probit ai valori medi
    f  <- alfa[g] + sum(gam[g, GS] * colMeans(d[, PREL])) + beta[g] * mean(d$ln_x_reale) +
          sum(b[paste0(EQ[g], "_", EQ[g], "_", c(DEMO, ROUND, "v_hat"))] * colMeans(d[, c(DEMO, ROUND, "v_hat")]))   # parte latente ai valori medi
    k  <- dnorm(t) * (f - delta[g] * t)
    c_x <- cp["ln_x_reale"]; c_p <- c(cp[PREL], -sum(cp[PREL])); names(c_p) <- GRUPPI
    dX[g]   <- pnorm(t) * beta[g] + k * c_x
    dP[g, ] <- pnorm(t) * (gam[g, ] - beta[g] * wbar) + k * (c_p - c_x * wbar)
  }
  dX["altro"] <- -sum(dX[GS]); dP["altro", ] <- -colSums(dP[GS, ])
  e_spesa <- 1 + dX / w
  marsh   <- -diag(G) + dP / w                       # riga g divisa per w_g
  hicks   <- marsh + outer(e_spesa, w)
  dimnames(marsh) <- dimnames(hicks) <- list(GRUPPI, GRUPPI)
  list(w = w, spesa = e_spesa, marshall = marsh, hicks = hicks)
}
E <- elasticita(stima)
cat("\nElasticita' rispetto alla spesa alimentare (tutto il campione):\n"); print(round(E$spesa, 2))
cat("Elasticita' di prezzo proprie, Marshall:\n");                       print(round(diag(E$marshall), 2))
cat("Controllo adding-up: sum w_g e_g =", round(sum(E$w * E$spesa), 4), "(deve essere 1)\n")
cat("Controllo omogeneita': max |somma riga Marshall + e_spesa| =", signif(max(abs(rowSums(E$marshall) + E$spesa)), 3), "\n")

# stesse stime, valori medi di ogni round
per_round <- lapply(sort(unique(stima$round)), function(r) {
  e <- elasticita(stima[stima$round == r, ])
  data.frame(round = r, gruppo = GRUPPI, quota_media = e$w, el_spesa = e$spesa, el_prezzo_propria_marshall = diag(e$marshall),
             el_prezzo_propria_hicks = diag(e$hicks))
})
per_round <- bind_rows(per_round)


## =============================================================================
## 11. SALVATAGGIO DEI RISULTATI (cartella separata)
## =============================================================================
controlli <- data.frame(controllo = c("righe voci usate", "famiglie", "valori unitari", "valori unitari anomali (esclusi dalle mediane)",
                                      "acquisti rivalutati (spesa mancante o valore unitario anomalo)", "voci con un valore imputato",
                                      "quota media del budget imputata (%)", "famiglie con budget nullo (escluse)", "famiglie nella stima",
                                      "t dello strumento (primo stadio)"),
                        valore = c(nrow(voci), nrow(famiglie), sum(!is.na(voci$uv)), sum(voci$flag_uv_anomalo), sum(voci$flag_acq_rivalutato, na.rm = TRUE),
                                   sum(voci$flag_imputato), round(100 * mean(dati$quota_imputata), 2), n_budget_zero,
                                   nrow(stima), round(summary(cf)$coefficients["ln_spesa_tot", "t value"], 1)))
coeff <- data.frame(coefficiente = names(b), stima = b, errore_std = sqrt(diag(vcov(sur))), row.names = NULL)
parametri <- data.frame(gruppo = GRUPPI, alfa = alfa, beta = beta, delta = delta, gam, row.names = NULL, check.names = FALSE)
pb <- bind_rows(lapply(GS, function(g) data.frame(gruppo = g, variabile = names(coef(probit[[g]])), coeff = coef(probit[[g]]), row.names = NULL)))
quote <- data.frame(gruppo = GRUPPI, quota_media = wbar, famiglie_che_consumano = colMeans(dati[, paste0("v_", GRUPPI)] > 0))
wb <- createWorkbook()
for (s in list(list("controlli", controlli), list("quote_medie", quote), list("elasticita_spesa", data.frame(gruppo = GRUPPI, elasticita = E$spesa)),
               list("marshall", data.frame(gruppo = GRUPPI, E$marshall, check.names = FALSE)), list("hicks", data.frame(gruppo = GRUPPI, E$hicks, check.names = FALSE)),
               list("per_round", per_round), list("parametri_AIDS", parametri), list("coefficienti_SUR", coeff), list("probit", pb))) {
  addWorksheet(wb, s[[1]]); writeData(wb, s[[1]], s[[2]])
}
saveWorkbook(wb, file.path(USCITA, "risultati_LAAIDS_TZA.xlsx"), overwrite = TRUE)
write.csv(dati,  file.path(USCITA, "famiglie_quote_prezzi.csv"), row.names = FALSE)           # dataset della stima, con i flag
write.csv(voci %>% select(round, hhid, codice_voce, voce, gruppo, uv, flag_uv_anomalo, liv_prezzo_auto, liv_prezzo_regali,
                          val_acq, val_auto, val_regali, val_solo_tot, val_tot, flag_acq_rivalutato, flag_imputato, flag_senza_valore),
          file.path(USCITA, "voci_valori_flag.csv"), row.names = FALSE)
cat("\nRisultati salvati in:", USCITA, "\n")
