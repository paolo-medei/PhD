###############################################################################
##  QUOTE DI SPESA ALIMENTARE E FONTI (acquisti, autoconsumo, regali), 5 paesi (24 nov 2026)
##
##  Dal dataset di tutti gli alimenti (ASF_food_budget_<data>.rds). Una tabella per paese, come quella della Tanzania:
##   - Quota media hh = media semplice delle quote familiari (<cat>_share), famiglie con cibo a casa;
##   - Quota aggregata pesata = somma pesata del valore della categoria / somma pesata del cibo a casa;
##   - Acquisti / Autoconsumo / Regali = somma pesata del valore da quella fonte / somma pesata del valore della categoria.
##  Valori: acquisti = spesa dichiarata (Nigeria 2012-2023: quantita' x prezzo unitario); autoconsumo e regali = quantita'
##  x prezzo mediano d'acquisto della stessa voce nella stessa area (EA -> distretto -> regione -> nazionale).
##  Denominatore delle quote = cibo a casa (26 categorie). Il cibo fuori casa e' una riga a parte: quota sul cibo totale.
##  Ogni numero e' prima calcolato per round, poi mediato sui round (stesso peso a ogni round). Una categoria che il
##  questionario di un round non chiede e' esclusa dalla media di quel round (vuota, non zero).
##  USO  Rscript quote_spesa_fonti.R <ASF_food_budget_<data>.rds> <uscita.xlsx>
###############################################################################
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(openxlsx) })
a <- commandArgs(TRUE)
D <- readRDS(a[1]); USCITA <- a[2]
CAT <- c(beef = "Manzo", goat_sheep = "Capra e pecora", pork = "Maiale", processed_red_meat = "Carne rossa lavorata", meat_other = "Altra carne",
         poultry = "Pollame", eggs = "Uova", milk_fresh = "Latte fresco", dairy_processed = "Latticini trasformati", fish_fresh = "Pesce fresco",
         fish_processed = "Pesce trasformato", pulses_dry = "Legumi secchi", pulses_fresh = "Legumi freschi", groundnuts = "Arachidi", soy = "Soia",
         nuts = "Frutta a guscio", seeds = "Semi", cereals = "Cereali", starches = "Tuberi e piantaggine", sugar_sweets = "Zucchero e dolci",
         vegetables = "Verdure", fruits = "Frutta", oils_fats = "Oli e grassi", spices_other = "Spezie, sale, condimenti", beverages = "Bevande (alcol incluso)",
         other_food = "Altro cibo")
PAESE <- c(ETH = "Etiopia", TZA = "Tanzania", MWI = "Malawi", NGA = "Nigeria", UGA = "Uganda")
ws <- function(n, d, w) { ok <- !is.na(n) & !is.na(d) & !is.na(w); if (!any(ok) || sum(d[ok] * w[ok]) == 0) NA_real_ else sum(n[ok] * w[ok]) / sum(d[ok] * w[ok]) }

## per round e categoria
L <- lapply(names(CAT), function(k) {
  D %>% group_by(country, year) %>% summarise(
    cat = k,
    quota_media_hh = if (all(is.na(.data[[paste0(k, "_share")]]))) NA_real_ else mean(.data[[paste0(k, "_share")]][food_home_value > 0], na.rm = TRUE),
    quota_aggregata = if (all(is.na(.data[[paste0(k, "_value")]]))) NA_real_ else ws(.data[[paste0(k, "_value")]], food_home_value, weight),
    acquisti = ws(.data[[paste0(k, "_value_pur")]], .data[[paste0(k, "_value")]], weight),
    autoconsumo = ws(.data[[paste0(k, "_value_own")]], .data[[paste0(k, "_value")]], weight),
    regali = ws(.data[[paste0(k, "_value_gift")]], .data[[paste0(k, "_value")]], weight), .groups = "drop") })
R <- bind_rows(L)
## totale del cibo a casa e cibo fuori casa
pur <- rowSums(D[, paste0(names(CAT), "_value_pur")], na.rm = TRUE); own <- rowSums(D[, paste0(names(CAT), "_value_own")], na.rm = TRUE)
gif <- rowSums(D[, paste0(names(CAT), "_value_gift")], na.rm = TRUE)
TT <- D %>% mutate(pur = pur, own = own, gif = gif) %>% group_by(country, year) %>% summarise(
  tot_acq = ws(pur, food_home_value, weight), tot_own = ws(own, food_home_value, weight), tot_gif = ws(gif, food_home_value, weight),
  away_media = mean(food_away_share, na.rm = TRUE), away_aggr = ws(food_away_value, food_total_value, weight),
  famiglie = n(), round_note = first(not_collected[grepl("reported by no household", not_collected)]), .groups = "drop")

## tabella per paese: media dei round
tab <- function(cc) {
  r <- R %>% filter(country == cc) %>% group_by(cat) %>%
    summarise(round_con_dati = sum(!is.na(quota_aggregata)),
              across(c(quota_media_hh, quota_aggregata, acquisti, autoconsumo, regali), ~ if (all(is.na(.x))) NA_real_ else mean(.x, na.rm = TRUE)),
              .groups = "drop") %>%
    filter(round_con_dati > 0, !is.na(acquisti)) %>% arrange(desc(quota_aggregata))      # categorie mai consumate nel paese: fuori
  t <- R %>% filter(country == cc); tt <- TT %>% filter(country == cc)
  nr <- nrow(tt)
  out <- tibble(Categoria = unname(CAT[r$cat]), `Quota media hh` = r$quota_media_hh, `Quota aggregata pesata` = r$quota_aggregata,
                Acquisti = r$acquisti, Autoconsumo = r$autoconsumo, Regali = r$regali,
                `Round` = ifelse(r$round_con_dati < nr, paste0(r$round_con_dati, " di ", nr), ""))
  bind_rows(out,
    tibble(Categoria = "TOTALE CIBO A CASA", `Quota media hh` = 1, `Quota aggregata pesata` = 1, Acquisti = mean(tt$tot_acq), Autoconsumo = mean(tt$tot_own),
           Regali = mean(tt$tot_gif), Round = ""),
    tibble(Categoria = "Cibo fuori casa (quota sul cibo totale, fuori dalle quote sopra)", `Quota media hh` = mean(tt$away_media),
           `Quota aggregata pesata` = mean(tt$away_aggr), Acquisti = NA, Autoconsumo = NA, Regali = NA, Round = ""))
}

wb <- createWorkbook()
hs <- createStyle(textDecoration = "bold", fgFill = "#DDEBF7", border = "TopBottomLeftRight", wrapText = TRUE, valign = "top")
pc <- createStyle(numFmt = "0.0%"); bold <- createStyle(textDecoration = "bold"); it <- createStyle(textDecoration = "italic", wrapText = TRUE)
## primo foglio: le cinque quote aggregate pesate affiancate
conf <- R %>% group_by(country, cat) %>% summarise(q = if (all(is.na(quota_aggregata))) NA_real_ else mean(quota_aggregata, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = country, values_from = q) %>% mutate(Categoria = unname(CAT[cat])) %>% select(Categoria, any_of(names(PAESE)))
ord <- rowMeans(conf[, -1], na.rm = TRUE); conf <- conf[order(-ord), ]
names(conf) <- c("Categoria", PAESE[names(conf)[-1]])
src <- TT %>% group_by(country) %>% summarise(Acquisti = mean(tot_acq), Autoconsumo = mean(tot_own), Regali = mean(tot_gif),
                                              `Cibo fuori casa sul totale` = mean(away_aggr), .groups = "drop") %>%
  mutate(Paese = unname(PAESE[country])) %>% select(Paese, Acquisti, Autoconsumo, Regali, `Cibo fuori casa sul totale`)
src <- src[match(PAESE, src$Paese), ]
addWorksheet(wb, "confronto")
writeData(wb, "confronto", "Quota aggregata pesata sul cibo a casa, media dei round", startRow = 1); addStyle(wb, "confronto", bold, 1, 1)
writeData(wb, "confronto", conf, startRow = 2, headerStyle = hs)
addStyle(wb, "confronto", pc, rows = 3:(nrow(conf) + 2), cols = 2:6, gridExpand = TRUE)
r0 <- nrow(conf) + 5
writeData(wb, "confronto", "Cibo a casa per fonte (valore), media dei round", startRow = r0); addStyle(wb, "confronto", bold, r0, 1)
writeData(wb, "confronto", src, startRow = r0 + 1, headerStyle = hs)
addStyle(wb, "confronto", pc, rows = (r0 + 2):(r0 + 6), cols = 2:5, gridExpand = TRUE)
setColWidths(wb, "confronto", 1, 30); setColWidths(wb, "confronto", 2:6, 14)
for (cc in names(PAESE)) {
  t <- tab(cc); sh <- PAESE[[cc]]
  addWorksheet(wb, sh)
  rr <- paste(sort(unique(R$year[R$country == cc])), collapse = ", ")
  writeData(wb, sh, paste0(sh, ": quote di spesa alimentare e fonti, media dei round ", rr), startRow = 1); addStyle(wb, sh, bold, 1, 1)
  writeData(wb, sh, t, startRow = 2, headerStyle = hs)
  addStyle(wb, sh, pc, rows = 3:(nrow(t) + 2), cols = 2:6, gridExpand = TRUE)
  addStyle(wb, sh, bold, rows = nrow(t) + 1, cols = 1:6, gridExpand = TRUE, stack = TRUE)
  setColWidths(wb, sh, 1, 34); setColWidths(wb, sh, 2:6, 14); setColWidths(wb, sh, 7, 10)
  nt <- TT$round_note[TT$country == cc]; nt <- unique(nt[!is.na(nt)])
  if (length(nt)) { writeData(wb, sh, paste("Attenzione:", paste(nt, collapse = "; ")), startRow = nrow(t) + 4); addStyle(wb, sh, it, nrow(t) + 4, 1) }
}
## per round (tutto)
pr <- R %>% mutate(Paese = unname(PAESE[country]), Categoria = unname(CAT[cat])) %>%
  select(Paese, Round = year, Categoria, `Quota media hh` = quota_media_hh, `Quota aggregata pesata` = quota_aggregata, Acquisti = acquisti,
         Autoconsumo = autoconsumo, Regali = regali)
addWorksheet(wb, "per_round"); writeData(wb, "per_round", pr, headerStyle = hs)
addStyle(wb, "per_round", pc, rows = 2:(nrow(pr) + 1), cols = 4:8, gridExpand = TRUE); setColWidths(wb, "per_round", 1:3, c(10, 7, 30)); freezePane(wb, "per_round", firstRow = TRUE)
note <- data.frame(Nota = c(
  "Quota media hh: media semplice delle quote delle famiglie (famiglie con cibo a casa). Quota aggregata pesata: somma pesata del valore della categoria / somma pesata del cibo a casa.",
  "Acquisti, Autoconsumo, Regali: parte del valore della categoria che viene da ciascuna fonte (somme pesate). Sommano a 100%.",
  "Valori: acquisti = spesa dichiarata (Nigeria 2012-2023: quantita' consumata dagli acquisti x prezzo unitario). Autoconsumo e regali = quantita' x prezzo mediano d'acquisto della stessa voce, stessa unita', stessa area (EA, poi distretto, regione, nazionale; almeno 5 acquisti).",
  "Denominatore = cibo a casa (26 categorie): le quote sommano a 100%. Cibo fuori casa: solo valore, ultima riga, quota sul cibo totale (casa + fuori).",
  "Ogni numero e' calcolato per round e poi mediato sui round. Una categoria non chiesta in un round non entra nella media di quel round (colonna Round).",
  "Uganda 2019: lo zucchero (codice 147) non e' dichiarato da nessuna famiglia nel file; abbassa Zucchero e dolci dell'Uganda. Etiopia 2021: tella (bevanda) idem."))
addWorksheet(wb, "note"); writeData(wb, "note", note, headerStyle = hs); setColWidths(wb, "note", 1, 160)
saveWorkbook(wb, USCITA, overwrite = TRUE)
for (cc in names(PAESE)) { cat("\n==", PAESE[[cc]], "\n"); t <- tab(cc); t[, 2:6] <- lapply(t[, 2:6], function(x) round(100 * x, 1)); print(as.data.frame(t)) }
cat("\n"); print(as.data.frame(src %>% mutate(across(-Paese, ~ round(100 * .x, 1)))))
