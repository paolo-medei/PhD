###############################################################################
##                                                                           ##
##   ANALISI DELLA DOMANDA DI ALIMENTI DI ORIGINE ANIMALE                     ##
##   Versione semplificata e commentata                                       ##
##                                                                           ##
##   COSA FA: parte dai pannelli gia costruiti (panel_ETH.csv, panel_TZA.csv,
##   panel_NGA.csv) e produce tutti i risultati principali della ricerca.
##
##   COSA NON FA: non costruisce i pannelli dai file grezzi della Banca
##   Mondiale. Quello lo fa ASF_ALL_IN_ONE.R, che e' lungo perche' ogni wave
##   cambia i nomi dei file e delle variabili. Qui si da per scontato che i
##   pannelli esistano gia'.
##
##   COME SI USA: apri, premi Esegui. Cerca i pannelli da solo.
##
###############################################################################
##
##   GLOSSARIO DEI TERMINI TECNICI CHE TROVERAI NEI COMMENTI
##
##   WAVE          Un'ondata dell'indagine, cioe' un anno di rilevazione.
##                 La Tanzania ha 5 wave: 2008, 2010, 2012, 2014, 2020.
##
##   PANNELLO      Dataset in cui le stesse unita' (qui: le famiglie) sono
##                 osservate in piu' momenti nel tempo.
##
##   UNIT VALUE    Spesa diviso quantita'. Es: 6.000 scellini per 2 kg = 3.000
##   (valore       scellini/kg. NON e' un prezzo di mercato: dipende anche da
##    unitario)    COSA la famiglia ha scelto di comprare. Chi compra filetto
##                 ha un unit value piu' alto di chi compra ossobuco anche se
##                 va dallo stesso macellaio. E' proprio questa differenza che
##                 Deaton (1988) usa per misurare la QUALITA'.
##
##   ELASTICITA'   Di quanto cambia Y in percentuale quando X cambia dell'1%.
##                 Se l'elasticita' della quantita' di carne al reddito e' 0.6,
##                 vuol dire che +10% di reddito -> +6% di kg comprati.
##
##   LOG-LOG       Regressione in cui sia la variabile dipendente sia quella
##                 esplicativa sono in logaritmo: log(Y) ~ log(X). Il
##                 coefficiente di log(X) SI LEGGE DIRETTAMENTE come elasticita'.
##                 E' il motivo per cui si usa questa forma.
##
##   EFFETTI FISSI Variabili dummy che assorbono tutto cio' che e' costante
##   (fixed        dentro un gruppo. Mettendo effetti fissi di regione, si
##    effects)     confrontano solo famiglie della stessa regione, eliminando
##                 le differenze di prezzo e di abitudini fra regioni.
##
##   TWO-PART      Modello in due parti. Prima si spiega SE la famiglia compra
##   MODEL         (probit), poi QUANTO compra fra chi ha comprato (OLS).
##                 Serve perche' la maggioranza delle famiglie compra ZERO
##                 carne in una data settimana, e uno zero non e' un numero
##                 piccolo: e' una decisione diversa.
##
##   PROBIT        Regressione per variabili 0/1 (compra / non compra).
##
##   CENSURA       Il problema degli zeri: osserviamo la quantita' solo per chi
##                 compra. Se chi compra e' sistematicamente diverso, le stime
##                 sui soli acquirenti sono distorte.
##
##   ADULTO        Scala che pesa i membri della famiglia secondo il fabbisogno
##   EQUIVALENTE   (un bambino "conta" meno di un adulto). Serve per confrontare
##                 famiglie di dimensioni diverse.
##
##   HHI           Indice di Herfindahl: somma dei quadrati delle quote. Vicino
##                 a 1 = paniere concentrato su un prodotto solo; vicino a 0 =
##                 paniere diversificato.
##
###############################################################################

## ============================ IMPOSTAZIONI ============================== ##
PANEL_DIR <- ""    # "" = cerca da solo. Altrimenti metti il percorso della
                   # cartella OUTPUT, es: "C:/Users/.../Database ZIP/OUTPUT"

## Pacchetti. fixest serve per le regressioni con effetti fissi: e' molto piu'
## veloce di lm() quando le dummy sono tante (centinaia di regioni x anni).
pkg <- c("dplyr","tidyr","ggplot2","fixest","openxlsx","stringr","purrr")
for (p in pkg) if (!requireNamespace(p, quietly=TRUE)) install.packages(p)
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2)
  library(fixest); library(openxlsx); library(stringr); library(purrr)
})
options(dplyr.summarise.inform = FALSE)

## ============================ DOVE SONO I DATI ========================== ##
if (!nzchar(PANEL_DIR)) {
  home <- Sys.getenv("USERPROFILE"); if (!nzchar(home)) home <- path.expand("~")
  f <- character(0)
  for (r in c(list.dirs(home, recursive=FALSE, full.names=TRUE), home)) {
    f <- list.files(r, pattern="^panel_[A-Z]{3}\\.csv$", recursive=TRUE, full.names=TRUE)
    if (length(f)) break
  }
  if (!length(f)) stop("Pannelli non trovati. Imposta PANEL_DIR a mano.")
  PANEL_DIR <- dirname(f[1])
}
OUT <- file.path(PANEL_DIR, paste0("analisi_", format(Sys.time(), "%Y-%m-%d_%H-%M")))
dir.create(OUT, recursive=TRUE, showWarnings=FALSE)
cat("dati in:", PANEL_DIR, "\nrisultati in:", OUT, "\n\n")

###############################################################################
## PASSO 1 — CARICARE E ARMONIZZARE
##
## I tre pannelli sono stati costruiti da indagini diverse, quindi le colonne
## hanno nomi diversi: l'Etiopia chiama la quantita' acquistata "purch_kg", la
## Tanzania "purch_std". Qui li portiamo a nomi comuni una volta per tutte,
## cosi' tutto il resto del codice puo' ignorare da quale paese arrivano.
###############################################################################

carica <- function(file) {
  d  <- read.csv(file, stringsAsFactors = FALSE)
  cc <- str_match(basename(file), "panel_([A-Z]{3})")[,2]

  ## prendi la prima colonna che esiste fra quelle elencate
  col <- function(...) { for (n in c(...)) if (n %in% names(d)) return(d[[n]]); NA }
  num <- function(x) suppressWarnings(as.numeric(x))

  tibble(
    paese     = cc,
    anno      = num(col("year")),
    hhid      = as.character(col("hhid")),
    prodotto  = as.character(col("product")),
    traccia   = as.character(col("track")),    # "A" = carne aggregata, "B" = disaggregata
    qta_tot   = num(col("qty_std",   "qty_kg")),    # consumata (comprata + autoprodotta + regali)
    qta_comp  = num(col("purch_std", "purch_kg")),  # solo comprata
    autoprod  = num(col("own_std",   "own_kg")),
    regali    = num(col("gift_std",  "gift_kg")),
    spesa     = num(col("exp")),
    uv        = num(col("uv")),                # unit value = spesa/quantita'
    benessere = num(col("welfare", "nom_totcons_aeq")),  # spesa totale per consumi
    adulti_eq = pmax(num(col("adulteq")), 1),
    peso      = num(col("hhweight", "weight")),          # peso campionario
    regione   = as.character(col("region")),
    cluster   = as.character(col("clusterid", "ea_id")), # area di enumerazione
    scartata  = num(col("unconv"))             # 1 = unita' non convertibile
  ) %>%
    mutate(
      ## peso campionario: quante famiglie della popolazione rappresenta questa
      ## famiglia del campione. Se manca, mettiamo 1 (tutte contano uguale).
      peso     = ifelse(is.na(peso) | peso <= 0, 1, peso),
      scartata = ifelse(is.na(scartata), 0, scartata),
      ## i logaritmi che useremo nelle regressioni
      l_ben    = log(benessere),
      l_ae     = log(adulti_eq)
    )
}

D <- map_dfr(list.files(PANEL_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE), carica)
cat("caricate", nrow(D), "righe,", n_distinct(D$paese), "paesi\n\n")

###############################################################################
## PASSO 2 — QUINTILI DI REDDITO
##
## Dividiamo le famiglie in 5 gruppi uguali per benessere, DENTRO ogni anno e
## ogni paese. Il quintile 1 e' il 20% piu' povero, il 5 il 20% piu' ricco.
## Va fatto per anno perche' il benessere e' nominale e l'inflazione lo gonfia:
## un valore del 2021 non e' confrontabile con lo stesso valore del 2011.
###############################################################################

D <- D %>%
  group_by(paese, anno) %>%
  mutate(quintile = ntile(benessere, 5)) %>%
  ungroup()

###############################################################################
## PASSO 3 — STATISTICHE DESCRITTIVE
##
## Tre cose per prodotto, paese e anno:
##  - partecipazione: % di famiglie che COMPRA (il margine estensivo)
##  - quantita' mediana fra chi compra (il margine intensivo)
##  - unit value mediano (serve anche come controllo: deve crescere con
##    l'inflazione, altrimenti c'e' un errore di conversione da qualche parte)
###############################################################################

descrittive <- D %>%
  filter(traccia == "A") %>%
  group_by(paese, anno, prodotto) %>%
  summarise(
    famiglie      = n_distinct(hhid),
    partecipaz    = round(100 * weighted.mean(!is.na(qta_comp) & qta_comp > 0,
                                              peso, na.rm=TRUE), 1),
    qta_mediana   = round(median(qta_comp[qta_comp > 0], na.rm=TRUE), 2),
    uv_mediano    = round(median(uv[uv > 0], na.rm=TRUE), 1),
    .groups = "drop"
  )

cat("=== PARTECIPAZIONE (% famiglie che comprano) ===\n")
print(as.data.frame(descrittive %>%
  select(paese, prodotto, anno, partecipaz) %>%
  pivot_wider(names_from = anno, values_from = partecipaz)))

## partecipazione per quintile: e' il risultato piu' forte di tutta l'analisi
quintili <- D %>%
  filter(traccia == "A", !is.na(quintile)) %>%
  group_by(paese, prodotto, quintile) %>%
  summarise(part = round(100 * weighted.mean(!is.na(qta_comp) & qta_comp > 0,
                                             peso, na.rm=TRUE), 1), .groups="drop") %>%
  pivot_wider(names_from = quintile, values_from = part, names_prefix = "Q")

cat("\n=== PARTECIPAZIONE PER QUINTILE DI REDDITO ===\n")
cat("    Q1 = 20% piu' povero, Q5 = 20% piu' ricco\n")
print(as.data.frame(quintili))

###############################################################################
## PASSO 4 — IL MODELLO PRINCIPALE (two-part + decomposizione di Deaton)
##
## L'IDEA. Quando il reddito sale, la spesa per carne sale. Ma sale perche' la
## famiglia compra PIU' CHILI o perche' compra chili PIU' CARI? Deaton (1988)
## mostra che si puo' separare, perche':
##
##        spesa = quantita' x unit value
##
## e passando ai logaritmi la moltiplicazione diventa somma:
##
##        log(spesa) = log(quantita') + log(unit value)
##
## quindi facendo DUE regressioni separate sullo stesso campione:
##
##        log(quantita')  ~ log(reddito)   ->  elasticita' QUANTITA'
##        log(unit value) ~ log(reddito)   ->  elasticita' QUALITA'
##
## e la somma delle due da' l'elasticita' della spesa. La "quota di qualita'"
## e' qualita'/(qualita'+quantita'): quanta parte della risposta al reddito
## passa per il prezzo unitario invece che per il volume.
##
## LE TRE EQUAZIONI. Il modello e' "two-part": la prima equazione usa TUTTE le
## famiglie (chi compra e chi no), le altre due solo chi compra.
##
##   (1) compra 0/1     ~ log(reddito) + controlli   [probit]
##   (2) log(quantita') ~ log(reddito) + controlli   [OLS, solo acquirenti]
##   (3) log(unitvalue) ~ log(reddito) + controlli   [OLS, solo acquirenti]
##
## I CONTROLLI. log(adulti equivalenti) per la dimensione familiare: senza,
## l'elasticita' esce NEGATIVA, perche' le famiglie numerose comprano piu' in
## totale ma sono piu' povere per persona. Non e' una sfumatura, cambia segno.
##
## GLI EFFETTI FISSI. "| regione" assorbe tutto cio' che e' fisso dentro una
## regione (livello dei prezzi, abitudini alimentari). Cosi' il coefficiente
## viene stimato confrontando famiglie della stessa regione fra loro.
##
## vcov="hetero": errori standard robusti all'eteroschedasticita', cioe' al
## fatto che la varianza dei residui non sia costante. Standard con dati
## familiari, dove le famiglie ricche hanno consumi molto piu' dispersi.
###############################################################################

stima_cella <- function(g) {

  ## chi compra: quantita' e unit value positivi, dati puliti
  compratori <- g %>% filter(uv > 0, qta_comp > 0, benessere > 0, scartata == 0)

  ## TRIMMING: togliamo l'1% piu' basso e l'1% piu' alto degli unit value.
  ## Servono a eliminare errori di battitura (chi dichiara 8 tonnellate di
  ## carne in una settimana) che da soli sposterebbero la media.
  if (nrow(compratori) > 100) {
    q <- quantile(compratori$uv, c(.01, .99), na.rm = TRUE)
    compratori <- compratori %>% filter(uv >= q[1], uv <= q[2])
  }
  if (nrow(compratori) < 80) return(tibble())   # cella troppo piccola: saltala

  tutti <- g %>% filter(benessere > 0) %>%
    mutate(compra = as.integer(!is.na(qta_comp) & qta_comp > 0))

  ## (1) partecipazione — probit su tutte le famiglie
  m_part <- try(feglm(compra ~ l_ben + l_ae | regione, data = tutti,
                      family = binomial("probit")), silent = TRUE)
  ## (2) quantita' — OLS log-log sui soli acquirenti
  m_qta  <- try(feols(log(qta_comp) ~ l_ben + l_ae | regione, data = compratori,
                      weights = ~peso, vcov = "hetero"), silent = TRUE)
  ## (3) qualita' — OLS log-log sull'unit value, stessi acquirenti
  m_qual <- try(feols(log(uv) ~ l_ben + l_ae | regione, data = compratori,
                      weights = ~peso, vcov = "hetero"), silent = TRUE)

  ## estrae coefficiente e p-value, restituendo NA se il modello non ha girato
  prendi <- function(m, k = "l_ben") {
    if (inherits(m, "try-error") || !(k %in% names(coef(m)))) return(c(NA, NA))
    c(coef(m)[k], pvalue(m)[k])
  }
  p <- prendi(m_part); q <- prendi(m_qta); a <- prendi(m_qual)

  tibble(
    n_compratori  = nrow(compratori),
    partecipaz    = round(100 * mean(tutti$compra), 1),
    e_partecipaz  = p[1], p_part  = p[2],
    e_quantita    = q[1], p_qta   = q[2],
    e_qualita     = a[1], p_qual  = a[2],
    e_spesa       = q[1] + a[1],                 # somma: elasticita' della spesa
    quota_qualita = a[1] / (a[1] + q[1])         # quanta parte e' qualita'
  )
}

cat("\n=== DECOMPOSIZIONE (elasticita' al reddito) ===\n")
decomp <- D %>%
  filter(traccia == "A", prodotto %in% c("meat_agg","milk","eggs","coffee")) %>%
  group_by(paese, anno, prodotto) %>%
  group_modify(~ stima_cella(.x)) %>%
  ungroup()

print(as.data.frame(decomp %>%
  mutate(across(where(is.numeric), ~round(.x, 3)))))

cat("\n=== MEDIA SULLE WAVE ===\n")
media <- decomp %>%
  group_by(paese, prodotto) %>%
  summarise(wave          = n(),
            partecipaz    = round(mean(partecipaz, na.rm=TRUE), 1),
            quantita      = round(mean(e_quantita, na.rm=TRUE), 3),
            qualita       = round(mean(e_qualita,  na.rm=TRUE), 3),
            quota_qualita = round(mean(quota_qualita, na.rm=TRUE), 3),
            .groups="drop")
print(as.data.frame(media))

###############################################################################
## PASSO 5 — ELASTICITA' DI PREZZO
##
## IL PROBLEMA. Non possiamo usare l'unit value della famiglia come prezzo:
## contiene la sua scelta di qualita'. Se una famiglia compra il taglio caro,
## il suo unit value e' alto per scelta sua, non perche' il mercato sia caro.
## Regredire la quantita' su questo prezzo da' risultati senza senso.
##
## LA SOLUZIONE (imperfetta). Usiamo come prezzo la MEDIANA degli unit value
## delle ALTRE famiglie dello stesso cluster (area di enumerazione), escludendo
## la famiglia stessa. Si chiama "leave-one-out" ed e' un'approssimazione del
## prezzo locale che la famiglia subisce senza averlo scelto.
##
## IL LIMITE, che va dichiarato. Non e' uno strumento pulito: se in un cluster
## tutti comprano il taglio caro, prezzo e quantita' salgono insieme e
## l'elasticita' esce POSITIVA, che e' teoricamente impossibile per un bene
## normale. Succede in alcune celle tanzane e lo riportiamo invece di nasconderlo.
###############################################################################

D <- D %>%
  group_by(paese, anno, prodotto, cluster) %>%
  mutate(
    n_cl   = sum(!is.na(uv) & uv > 0),
    som_uv = sum(uv[!is.na(uv) & uv > 0]),
    ## media degli altri = (somma totale - il mio) / (quanti - 1)
    prezzo = ifelse(n_cl >= 4 & !is.na(uv), (som_uv - uv) / (n_cl - 1), NA_real_)
  ) %>%
  ungroup()

stima_prezzo <- function(g) {
  b <- g %>% filter(qta_comp > 0, benessere > 0, prezzo > 0, scartata == 0)
  if (nrow(b) < 120 || n_distinct(b$cluster) < 20) return(tibble())
  ## cluster=~cluster: errori standard che tengono conto del fatto che famiglie
  ## dello stesso villaggio non sono osservazioni indipendenti
  m <- try(feols(log(qta_comp) ~ log(prezzo) + l_ben + l_ae | regione,
                 data = b, weights = ~peso, cluster = ~cluster), silent = TRUE)
  if (inherits(m, "try-error")) return(tibble())
  k <- "log(prezzo)"
  if (!(k %in% names(coef(m)))) return(tibble())
  tibble(n = nrow(b), n_cluster = n_distinct(b$cluster),
         e_prezzo = unname(coef(m)[k]), p = unname(pvalue(m)[k]))
}

cat("\n=== ELASTICITA' DI PREZZO ===\n")
cat("    attesa NEGATIVA: se il prezzo sale, la quantita' scende\n")
prezzi <- D %>%
  filter(traccia == "A", prodotto %in% c("meat_agg","milk","eggs","coffee")) %>%
  group_by(paese, anno, prodotto) %>%
  group_modify(~ stima_prezzo(.x)) %>%
  ungroup()
print(as.data.frame(prezzi %>% mutate(across(where(is.numeric), ~round(.x, 3)))))

sbagliate <- sum(prezzi$e_prezzo > 0 & prezzi$p < .05, na.rm = TRUE)
if (sbagliate > 0)
  cat("\n   ATTENZIONE:", sbagliate, "celle con elasticita' POSITIVA e significativa.\n",
      "  E' il limite del prezzo leave-one-out descritto sopra. Va dichiarato.\n")

###############################################################################
## PASSO 6 — I MARGINI A LIVELLO FAMILIARE
##
## Fin qui abbiamo guardato un prodotto alla volta. Ma il reddito puo' cambiare
## il paniere anche senza cambiare nessun singolo prodotto: una famiglia che
## passa dal mangiare solo latte a mangiare latte, uova e pollo non ha comprato
## piu' di niente ne' niente di piu' caro. Ha DIVERSIFICATO.
##
## Misuriamo quattro cose a livello di famiglia:
##  - VARIETA': quanti prodotti animali distinti consuma
##  - HHI: quanto e' concentrato il paniere (sale = si concentra)
##  - PROTEINE per adulto equivalente al giorno (rende i prodotti confrontabili:
##    un kg di manzo e un litro di latte non lo sono, un grammo di proteina si')
##  - COSTO PER GRAMMO DI PROTEINA: e' una misura di qualita' confrontabile
##    FRA prodotti, mentre l'unit value lo e' solo DENTRO un prodotto
##
## NOTA sull'effetto fisso "| anno": qui e' essenziale. Il benessere e' nominale
## e l'inflazione lo gonfia nel tempo; senza effetto anno il coefficiente
## catturerebbe l'inflazione invece del reddito reale.
###############################################################################

## contenuto proteico in grammi per unita' standard (valori di composizione
## degli alimenti; per le uova dipende se sono in kg o in pezzi)
proteine <- tibble::tribble(
  ~prodotto,        ~g_prot,
  "beef", 260, "goat_sheep", 250, "pork", 250, "poultry", 270,
  "fish", 200, "milk", 33, "milk_processed", 250, "cheese", 200,
  "eggs", 6.9                      # un uovo da 55 g
)

fam <- D %>%
  filter(traccia == "B") %>%       # traccia B = prodotti disaggregati
  left_join(proteine, by = "prodotto") %>%
  group_by(paese, anno, hhid, benessere, adulti_eq, peso) %>%
  summarise(
    n_prodotti = sum(coalesce(qta_tot, 0) > 0),
    spesa_asf  = sum(coalesce(spesa, 0)),
    prot_tot   = sum(coalesce(g_prot, 0) * coalesce(qta_tot, 0)),
    ## HHI: somma dei quadrati delle quote di spesa
    hhi        = { s <- coalesce(spesa, 0)
                   s <- s / ifelse(sum(s) > 0, sum(s), NA)
                   sum(s^2, na.rm = TRUE) },
    .groups = "drop"
  ) %>%
  mutate(
    prot_giorno = prot_tot / adulti_eq / 7,
    costo_prot  = ifelse(prot_tot > 0, spesa_asf / prot_tot, NA_real_),
    l_ben = log(benessere)
  ) %>%
  filter(benessere > 0, n_prodotti > 0)

elast_fam <- function(dati, y) {
  dati <- dati %>% filter(is.finite(.data[[y]]), .data[[y]] > 0)
  if (nrow(dati) < 200) return(c(NA, NA))
  m <- try(feols(as.formula(paste0("log(", y, ") ~ l_ben + log(adulti_eq) | anno")),
                 data = dati, weights = ~peso, vcov = "hetero"), silent = TRUE)
  if (inherits(m, "try-error")) return(c(NA, NA))
  c(coef(m)["l_ben"], pvalue(m)["l_ben"])
}

cat("\n=== I MARGINI A LIVELLO FAMILIARE ===\n")
margini <- fam %>% group_by(paese) %>% group_modify(function(g, ...) {
  v <- elast_fam(g, "n_prodotti")
  p <- elast_fam(g, "prot_giorno")
  h <- elast_fam(g, "hhi")
  c_ <- elast_fam(g, "costo_prot")
  tibble(
    margine    = c("Varieta' (n. prodotti)", "Proteine per adulto eq./giorno",
                   "Concentrazione paniere (HHI)", "Costo per grammo proteina"),
    elasticita = round(c(v[1], p[1], h[1], c_[1]), 3),
    p_value    = round(c(v[2], p[2], h[2], c_[2]), 4)
  )
}) %>% ungroup()
print(as.data.frame(margini))

###############################################################################
## PASSO 7 — MARKETIZZAZIONE
##
## Quanta parte di cio' che si mangia passa per il MERCATO invece di venire
## dall'orto o dalla stalla di casa. E' l'indicatore di quanto la filiera
## esiste: ogni chilo che smette di essere autoconsumato e comincia a essere
## comprato attraversa raccolta, trasporto, trasformazione e vendita.
##
## NOTA sul trimming al 99.9%: una sola famiglia tanzana aveva dichiarato 8.500
## kg di carne ricevuti in regalo in una settimana. Da sola faceva il 96% dei
## regali di quell'anno. Le somme sono indifese contro un valore anomalo.
###############################################################################

market <- D %>%
  filter(traccia == "A") %>%
  mutate(c_ = coalesce(qta_comp, 0),
         a_ = coalesce(autoprod, 0),
         r_ = coalesce(regali,   0)) %>%
  group_by(paese, prodotto, anno) %>%
  mutate(across(c(c_, a_, r_), ~ pmin(.x, quantile(.x, .999, na.rm = TRUE)))) %>%
  summarise(totale = sum(c_ + a_ + r_),
            pct_comprato     = round(100 * sum(c_) / totale, 1),
            pct_autoprodotto = round(100 * sum(a_) / totale, 1),
            pct_regali       = round(100 * sum(r_) / totale, 1),
            .groups = "drop") %>%
  filter(totale > 0) %>% select(-totale)

cat("\n=== DA DOVE ARRIVA IL CIBO (% della quantita' consumata) ===\n")
print(as.data.frame(market))

###############################################################################
## PASSO 8 — SALVA TUTTO
##
## Un solo file Excel con un foglio per tabella, piu' tre figure.
###############################################################################

wb <- createWorkbook()
stile <- createStyle(textDecoration="bold", fgFill="#1F3864",
                     fontColour="#FFFFFF", halign="center")
tabelle <- list(descrittive = descrittive, partecip_quintile = quintili,
                decomposizione = decomp, media_wave = media,
                prezzi = prezzi, margini_familiari = margini,
                marketizzazione = market)
for (nm in names(tabelle)) {
  addWorksheet(wb, nm)
  writeData(wb, nm, tabelle[[nm]], headerStyle = stile)
  freezePane(wb, nm, firstRow = TRUE)
  setColWidths(wb, nm, cols = 1:ncol(tabelle[[nm]]), widths = "auto")
}
saveWorkbook(wb, file.path(OUT, "risultati.xlsx"), overwrite = TRUE)

tema <- theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank())

## Figura 1 — partecipazione per quintile
g1 <- quintili %>%
  pivot_longer(starts_with("Q"), names_to = "quintile", values_to = "pct") %>%
  ggplot(aes(quintile, pct, fill = paese)) +
  geom_col(position = "dodge") + facet_wrap(~prodotto, nrow = 1) +
  labs(title = "Chi compra, per quintile di reddito",
       x = NULL, y = "% di famiglie", fill = NULL) + tema
ggsave(file.path(OUT, "1_partecipazione.png"), g1, width = 11, height = 3.5, dpi = 200)

## Figura 2 — decomposizione quantita' vs qualita'
g2 <- media %>%
  select(paese, prodotto, Quantita = quantita, Qualita = qualita) %>%
  pivot_longer(c(Quantita, Qualita), names_to = "componente", values_to = "e") %>%
  ggplot(aes(prodotto, e, fill = componente)) +
  geom_col() + facet_wrap(~paese, nrow = 1) + coord_flip() +
  scale_fill_manual(values = c(Quantita = "#4E79A7", Qualita = "#59A14F")) +
  labs(title = "Elasticita' della spesa = quantita' + qualita'",
       x = NULL, y = "Elasticita'", fill = NULL) + tema
ggsave(file.path(OUT, "2_decomposizione.png"), g2, width = 10, height = 3.5, dpi = 200)

## Figura 3 — marketizzazione nel tempo
g3 <- market %>%
  ggplot(aes(anno, pct_comprato, colour = prodotto)) +
  geom_line(linewidth = .8) + geom_point() +
  facet_wrap(~paese, nrow = 1, scales = "free_x") +
  labs(title = "Quanta parte del cibo passa per il mercato",
       x = NULL, y = "% comprato", colour = NULL) + tema
ggsave(file.path(OUT, "3_marketizzazione.png"), g3, width = 11, height = 3.5, dpi = 200)

cat("\n=== FATTO ===\n")
cat("  risultati.xlsx  (7 fogli)\n  3 figure\n  ->", OUT, "\n")
###############################################################################
