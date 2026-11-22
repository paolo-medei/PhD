###############################################################################
##  ESEMPIO: SISTEMI DI DOMANDA (LA-AIDS, QUAIDS approssimato, EASI approssimato)
##  sugli alimenti di origine animale in Tanzania, NPS 2008-2020
##
##  Cosa fa  Secondo stadio di un bilancio a due stadi: la famiglia ha deciso
##           quanto spendere in alimenti di origine animale (gruppo G) e lo
##           divide fra 6 beni: manzo, pollo, altra carne (capra, pecora,
##           maiale), pesce, latticini, uova. Stima le quote di spesa con tre
##           sistemi e calcola le elasticita' DENTRO il gruppo.
##  Dati     data/OUTPUT/panel_TZA.csv prodotto da ASF_completo.R (traccia B,
##           prodotti disaggregati). Nessun pacchetto speciale: solo dplyr e
##           fixest, cosi' gira ovunque. I comandi con systemfit, micEconAids
##           ed easi sono nella guida (sezione 6).
##  Attenzione E' un esempio didattico: gli zeri dentro il gruppo non sono
##           corretti (Shonkwiler-Yen e' nella guida), i prezzi sono mediane
##           dei valori unitari nel cluster, la simmetria non e' imposta.
###############################################################################
suppressPackageStartupMessages({ library(dplyr); library(fixest) })

## il pannello prodotto da ASF_completo.R; se non lo trova, scrivi qui il percorso
PANEL <- Find(file.exists, c("data/OUTPUT/panel_TZA.csv", "../data/OUTPUT/panel_TZA.csv",
                             "../../data/OUTPUT/panel_TZA.csv",
                             file.path(Sys.getenv("USERPROFILE"), "Desktop/PhD_v21/data/OUTPUT/panel_TZA.csv"),
                             "/home/claude/work/single/data/OUTPUT/panel_TZA.csv"))
if (is.null(PANEL)) stop("panel_TZA.csv non trovato: scrivi il percorso nella variabile PANEL")

## ---- 1. dati: spesa e quantita' comprate per famiglia, wave e bene ----------- #
d <- read.csv(PANEL, colClasses = c(hhid = "character")) %>%
  filter(track == "B", product %in% c("beef", "poultry", "goat_sheep", "pork", "fish",
                                      "milk", "milk_processed", "eggs")) %>%
  mutate(good = case_when(product %in% c("goat_sheep", "pork") ~ "othmeat",
                          product %in% c("milk", "milk_processed") ~ "dairy",
                          TRUE ~ product))
G <- c("beef", "poultry", "othmeat", "fish", "dairy", "eggs")   # l'ultimo (uova) e' il numerario

hh <- d %>% distinct(hhid, year, .keep_all = TRUE) %>%
  transmute(hhid, year, region, clusterid, weight = hhweight, hhsize, welfare,
            rural = as.integer(trimws(as.character(urban)) %in% c("1", "1.0")))  # Tanzania: 1 = rurale

g <- d %>% group_by(hhid, year, good) %>%
  summarise(exp = sum(exp_conv[purch_std > 0], na.rm = TRUE),
            q   = sum(purch_std[purch_std > 0], na.rm = TRUE), .groups = "drop")

## ---- 2. prezzi: mediana del valore unitario nel cluster e nella wave ---------- #
## (se nel cluster nessuno compra: mediana della regione, poi del paese)
uv <- g %>% filter(exp > 0, q > 0) %>% mutate(v = exp / q) %>% left_join(hh, by = c("hhid", "year"))
p_cl <- uv %>% group_by(year, clusterid, good) %>% summarise(p_cl = median(v), .groups = "drop")
p_rg <- uv %>% group_by(year, region, good)    %>% summarise(p_rg = median(v), .groups = "drop")
p_nt <- uv %>% group_by(year, good)            %>% summarise(p_nt = median(v), .groups = "drop")

D <- hh %>% tidyr::crossing(good = G) %>%
  left_join(g, by = c("hhid", "year", "good")) %>%
  left_join(p_cl, by = c("year", "clusterid", "good")) %>%
  left_join(p_rg, by = c("year", "region", "good")) %>%
  left_join(p_nt, by = c("year", "good")) %>%
  mutate(exp = ifelse(is.na(exp), 0, exp), p = coalesce(p_cl, p_rg, p_nt))

## prezzi normalizzati alla media del campione: l'indice di Stone non dipende
## piu' dalle unita' di misura (kg, litri, pezzi) -> problema di Moschini
D <- D %>% group_by(good) %>% mutate(p = p / mean(p)) %>% ungroup()

W <- D %>% group_by(hhid, year) %>% mutate(x = sum(exp)) %>% ungroup() %>%
  filter(x > 0) %>% mutate(w = exp / x) %>%
  tidyr::pivot_wider(id_cols = c(hhid, year, region, weight, hhsize, rural, welfare, x),
                     names_from = good, values_from = c(w, p), names_sep = "_")
W <- W %>% filter(if_all(starts_with("p_"), ~ !is.na(.x)), !is.na(weight), !is.na(region), !is.na(welfare)) %>%
  mutate(lnx = log(x), lnn = log(hhsize), fyear = factor(year), fregion = factor(region))
for (k in G) W[[paste0("lp_", k)]] <- log(W[[paste0("p_", k)]])
## prezzi relativi al numerario: impongono l'omogeneita' (sum_j gamma_ij = 0)
for (k in G[-length(G)]) W[[paste0("rp_", k)]] <- W[[paste0("lp_", k)]] - W$lp_eggs

wbar <- sapply(G, function(k) weighted.mean(W[[paste0("w_", k)]], W$weight))
cat(sprintf("Famiglie-wave che comprano alimenti di origine animale: %d\n", nrow(W)))
cat("Quote medie nel gruppo:\n"); print(round(wbar, 3))
cat("Famiglie con quota zero (%):\n")
print(round(100 * sapply(G, function(k) weighted.mean(W[[paste0("w_", k)]] == 0, W$weight)), 1))

## ---- 3. LA-AIDS --------------------------------------------------------------- #
## Indice di Stone con le quote MEDIE (evita w a destra e a sinistra)
W$lnP_stone <- as.vector(as.matrix(W[, paste0("lp_", G)]) %*% wbar)
W$lnxr <- W$lnx - W$lnP_stone                          # spesa reale del gruppo
RP <- paste0("rp_", G[-length(G)])
Z  <- "lnn + rural + fyear + fregion"                  # caratteristiche e effetti fissi
## Stesse variabili a destra in tutte le equazioni e nessun vincolo fra equazioni:
## SUR = OLS equazione per equazione, e le n equazioni rispettano da sole l'additivita'
aids <- lapply(G, function(k) lm(as.formula(paste0("w_", k, " ~ ", paste(RP, collapse = " + "),
                                                   " + lnxr + ", Z)), data = W, weights = weight))
names(aids) <- G
cat("\nAdditivita': somma dei beta =", round(sum(sapply(aids, function(m) coef(m)["lnxr"])), 6), "\n")

## gamma_ij completa (l'ultima colonna dall'omogeneita'), beta_i
gam <- t(sapply(aids, function(m) { gg <- coef(m)[RP]; c(gg, -sum(gg)) })); colnames(gam) <- G
bet <- sapply(aids, function(m) coef(m)["lnxr"]); names(bet) <- G

aids_elas <- function(gam, bet, w) {
  n <- length(w); e <- 1 + bet / w
  M <- -diag(n) + gam / w - outer(bet / w, w)            # Green e Alston (1990)
  H <- M + outer(e, w)                                   # Slutsky
  dimnames(M) <- dimnames(H) <- list(names(w), names(w))
  list(expenditure = e, marshall = M, hicks = H)
}
EA <- aids_elas(gam, bet, wbar)
cat("\nLA-AIDS, elasticita' alla spesa del gruppo:\n"); print(round(EA$expenditure, 2))
cat("LA-AIDS, elasticita' di prezzo marshalliane (riga = bene, colonna = prezzo):\n"); print(round(EA$marshall, 2))
cat("LA-AIDS, elasticita' hicksiane (compensate):\n"); print(round(EA$hicks, 2))
cat("Simmetria non imposta: gamma_ij - gamma_ji, valore massimo assoluto =",
    round(max(abs(gam - t(gam))), 3), "\n")

## ---- 4. QUAIDS approssimato (indice di Stone, b(p) = 1) ---------------------- #
W$lnxr2 <- W$lnxr^2
quaids <- lapply(G, function(k) lm(as.formula(paste0("w_", k, " ~ ", paste(RP, collapse = " + "),
                                                     " + lnxr + lnxr2 + ", Z)), data = W, weights = weight))
names(quaids) <- G
lam <- sapply(quaids, function(m) coef(m)["lnxr2"]); bq <- sapply(quaids, function(m) coef(m)["lnxr"])
cat("\nQUAIDS: lambda (termine quadratico) e p-value:\n")
print(round(t(sapply(quaids, function(m) summary(m)$coefficients["lnxr2", c(1, 4)])), 4))
## elasticita' alla spesa per quinto di spesa reale del gruppo
qx <- quantile(W$lnxr, c(.1, .3, .5, .7, .9))
eq <- sapply(seq_along(qx), function(r) 1 + (bq + 2 * lam * qx[r]) / wbar)
dimnames(eq) <- list(G, c("p10", "p30", "p50", "p70", "p90"))
cat("QUAIDS: elasticita' alla spesa del gruppo lungo la distribuzione (alle quote medie):\n"); print(round(eq, 2))

## ---- 5. EASI approssimato (polinomio di ordine 3 in y, y strumentata) -------- #
W$y  <- W$lnx - as.vector(as.matrix(W[, paste0("lp_", G)] * W[, paste0("w_", G)]) %*% rep(1, length(G)))
W$yh <- W$lnx - W$lnP_stone                            # strumento: quote medie
W <- W %>% mutate(y2 = y^2, y3 = y^3, yh2 = yh^2, yh3 = yh^3)
easi <- lapply(G, function(k) feols(as.formula(paste0("w_", k, " ~ ", paste(RP, collapse = " + "),
                                                      " + lnn + rural | fyear + fregion | y + y2 + y3 ~ yh + yh2 + yh3")),
                                    data = W, weights = ~weight, vcov = "hetero"))
names(easi) <- G
bE <- t(sapply(easi, function(m) coef(m)[c("fit_y", "fit_y2", "fit_y3")]))
aE <- t(sapply(easi, function(m) { a <- coef(m)[RP]; c(a, -sum(a)) })); colnames(aE) <- G
cat("\nEASI: primo stadio, F di Wald degli strumenti per y:",
    round(fitstat(easi[[1]], "ivwald")[[1]]$stat, 0), "\n")
qy <- quantile(W$y, c(.1, .3, .5, .7, .9))
eE <- sapply(seq_along(qy), function(r) 1 + (bE[, 1] + 2 * bE[, 2] * qy[r] + 3 * bE[, 3] * qy[r]^2) / wbar)
dimnames(eE) <- list(G, c("p10", "p30", "p50", "p70", "p90"))
cat("EASI: elasticita' alla spesa del gruppo lungo la distribuzione di y (alle quote medie):\n"); print(round(eE, 2))
HE <- -diag(length(G)) + aE / wbar; dimnames(HE) <- list(G, G)
cat("EASI: elasticita' hicksiane (a_jk / w_j - delta_jk):\n"); print(round(HE, 2))

## ---- 6. dal secondo al primo stadio (Edgerton, 1997) -------------------------- #
## e_i = e_i|G * e_G : e_G = elasticita' della spesa in alimenti di origine
## animale alla spesa totale, fra chi compra (qui una semplice log-log)
eG <- coef(feols(lnx ~ log(welfare) + lnn + rural | fyear + fregion, data = W, weights = ~weight))["log(welfare)"]
cat(sprintf("\ne_G (spesa del gruppo rispetto alla spesa totale, chi compra) = %.2f\n", eG))
cat("Elasticita' alla spesa TOTALE = e_i|G x e_G (LA-AIDS):\n"); print(round(EA$expenditure * eG, 2))
