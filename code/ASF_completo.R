###############################################################################
###############################################################################
##
##   DOMANDA DI ALIMENTI DI ORIGINE ANIMALE IN AFRICA SUB-SAHARIANA
##   Script unico: dai file grezzi della Banca Mondiale ai risultati
##
##   Paolo Medei - Dottorato AGRISYSTEM, Universita' Cattolica del Sacro Cuore
##   Versione v24 (20 novembre 2026). Registro di ogni scelta: docs/FINDINGS.md
##
###############################################################################
###############################################################################
##
##  LA DOMANDA DI RICERCA (Step I della tesi)
##  Quando il reddito di una famiglia cresce, come cambia il suo consumo di
##  carne, latte, uova e pesce? Cresce perche' piu' famiglie cominciano a
##  comprare (ENTRATA), perche' chi compra compra di piu' (QUANTITA') o perche'
##  compra prodotti migliori e piu' cari (QUALITA')? La risposta serve agli
##  Step II e III: se il valore cresce piu' del volume, e passa sempre piu' dal
##  mercato, l'investimento zootecnico crea lavoro oltre l'allevatore.
##
##  I DATI
##  Indagini LSMS-ISA della Banca Mondiale, 5 paesi, 23 wave:
##    Etiopia   ESS/ESPS     2011, 2013, 2015, 2018, 2021
##    Tanzania  NPS          2008, 2010, 2012, 2014, 2020
##    Malawi    IHS          2010, 2016, 2019, 2024   (sezioni trasversali)
##    Nigeria   GHS-Panel    2010, 2012, 2015
##    Uganda    UNPS         2010, 2011, 2013, 2015, 2018, 2019
##  piu' i bilanci alimentari FAOSTAT (Africa) per il confronto della PARTE 13.
##  Gli archivi .zip si scaricano da https://microdata.worldbank.org e vanno
##  messi in una cartella "data" accanto alla cartella "code" che contiene
##  questo file (oppure in Desktop, Documents o OneDrive: lo script li cerca).
##  I microdati NON si ridistribuiscono: la cartella data non va su GitHub.
##
##  COME SI LANCIA
##    RStudio:   aprire questo file e premere "Source" (non "Run" riga per riga).
##    Terminale: Rscript code/ASF_completo.R   (dalla cartella del progetto)
##  La prima volta estrae gli archivi e installa i pacchetti mancanti; circa
##  30-40 minuti in tutto. Per rifare solo le stime senza ricostruire i
##  pannelli: RUN_BUILD <- FALSE nella PARTE 1 (pochi minuti).
##
##  COSA PRODUCE, in data/OUTPUT
##    panel_ETH.csv ... panel_UGA.csv   i pannelli armonizzati: una riga per
##                                      famiglia x prodotto x wave x traccia
##    run_<data-ora>/RESULTS_<data-ora>.xlsx   tutte le tabelle, un foglio per
##                                      tabella, con un indice (CONTENTS)
##    run_<data-ora>/figures/           le figure: VC_01..VC_10 in cima, le
##                                      altre (zz_*) sono diagnostiche
##  Alla fine (PARTE 16) il workbook nuovo si confronta cella per cella con
##  quello di riferimento in results_reference/: se tutto coincide, lo script
##  scrive "OK".
##
##  COME E' ORGANIZZATO
##    PARTE 0   avvio: dove sono il codice e i dati
##    PARTE 1   impostazioni, pacchetti, archivi, funzioni comuni (regole sui
##              valori estremi, quinti)
##    PARTE 2   Etiopia    \
##    PARTE 3   Tanzania    |  dai file grezzi al pannello armonizzato di ogni
##    PARTE 4   Malawi      |  paese: unita' convertite, benessere, pesi,
##    PARTE 5   Nigeria     |  famiglia, controlli di qualita' (GATE)
##    PARTE 6   Uganda     /
##    PARTE 7   stime principali: quantita' contro qualita' (Deaton 1988)
##    PARTE 8   confronto fra i paesi
##    PARTE 9   consumo totale, effetti fissi familiari, selezione
##    PARTE 10  paniere per quinto, proteine, varieta', quattro margini
##    PARTE 11  reddito permanente e transitorio, differenze lunghe, attenuazione
##    PARTE 12  filiera: mercatizzazione, paniere, spesa contro proteine
##    PARTE 13  confronto con i bilanci alimentari FAO
##    PARTE 14  tre margini (entrata, quantita', qualita') con bootstrap; caffe'
##    PARTE 15  un solo workbook con tutte le tabelle
##    PARTE 16  confronto con i risultati di riferimento
##
##  PAROLE CHE TORNANO SEMPRE
##    traccia A   prodotti confrontabili in tutte le wave (la carne e' un
##                aggregato, perche' alcune wave non la dividono)
##    traccia B   prodotti separati (manzo, capra e pecora, maiale, pollame, pesce)
##    qty_*       quantita' totale consumata nella settimana (tutte le fonti)
##    purch_*     quantita' acquistata; own_* autoprodotta; gift_* ricevuta
##                (suffisso _kg in Etiopia e Nigeria, _std = unita' standard
##                del prodotto - kg, litri o pezzi - negli altri paesi)
##    exp         spesa per gli acquisti della settimana
##    exp_conv    la spesa delle sole righe con quantita' acquistata convertita
##    uv          valore unitario = exp_conv / quantita' acquistata (moneta per
##                kg, litro o uovo): la misura della qualita'
##    unconv      1 se c'e' spesa ma la quantita' non si converte (mucchi, pezzi)
##    welfare     benessere: consumo annuo per adulto equivalente (per persona in
##                Malawi e Nigeria); e' la misura di reddito delle regressioni
##    adulteq     adulti equivalenti; weight/hhweight peso campionario
##    TRAP        una trappola dei dati trovata e gestita (per paese: TRAP 1-7
##                Etiopia e Tanzania, N Nigeria, U Uganda, M Malawi)
##    D1-D19, M1-M18   correzioni e decisioni, spiegate in docs/FINDINGS.md
##    v21...v24   la versione in cui una riga e' stata aggiunta o corretta
##
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 0 - AVVIO: DOVE SONO IL CODICE E I DATI
##
##  Lo script cerca la cartella in cui si trova (serve per trovare "data" e
##  "results_reference" accanto a "code"). Se c'e' una cartella "data" accanto
##  a "code", i dati sono li' e i risultati vanno in data/OUTPUT. Altrimenti la
##  PARTE 1 cerca gli archivi in Desktop, Documents e OneDrive.
##
###############################################################################
###############################################################################
here <- function() {
  a <- commandArgs(FALSE); f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) return(dirname(normalizePath(f)))                 # Rscript
  for (i in rev(seq_len(sys.nframe()))) {                          # source()
    o <- sys.frame(i)$ofile; if (!is.null(o)) return(dirname(normalizePath(o)))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- rstudioapi::getSourceEditorContext()$path
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  getwd()
}
## Se il file e' stato eseguito riga per riga (Run / Ctrl+Invio) invece che con
## Source, here() vede solo la cartella di lavoro: si guarda anche nei posti
## soliti.
has_me <- function(d) file.exists(file.path(d, "ASF_completo.R"))
home <- unique(c(Sys.getenv("USERPROFILE"), path.expand("~"), dirname(path.expand("~"))))
home <- home[nzchar(home)]
cands <- c(here(), file.path(getwd(), "code"),
           if (nzchar(Sys.getenv("ASF_DATA_ROOT")))
             file.path(dirname(Sys.getenv("ASF_DATA_ROOT")), "code"),
           file.path(home, "Desktop", "PhD_v21", "code"),
           Sys.glob(file.path(home, "OneDrive*", "Desktop", "PhD_v21", "code")))
CODE_DIR <- Find(has_me, cands, nomatch = cands[1])
data_dir <- file.path(dirname(CODE_DIR), "data")
if (!nzchar(Sys.getenv("ASF_DATA_ROOT")) && dir.exists(data_dir))
  Sys.setenv(ASF_DATA_ROOT = normalizePath(data_dir))
message("code: ", CODE_DIR)
message("data: ", if (nzchar(Sys.getenv("ASF_DATA_ROOT"))) Sys.getenv("ASF_DATA_ROOT") else "auto-detect")
t0 <- Sys.time()


###############################################################################
###############################################################################
##
##  PARTE 1 - IMPOSTAZIONI, PACCHETTI, DATI E FUNZIONI COMUNI
##
##  COSA FA   Non fa analisi. Prepara tutto quello che serve alle parti dopo:
##            gli interruttori per saltare dei pezzi, i pacchetti R, la ricerca
##            degli archivi della Banca Mondiale (estratti una volta sola), le
##            cartelle dei risultati e le funzioni usate da tutti i paesi.
##  PERCHE'   Le regole valgono uguali in tutti e cinque i paesi solo se sono
##            scritte in un posto solo. Qui stanno le regole sui valori estremi
##            (M17, M18), i quinti per famiglia (M16) e la soglia di copertura
##            dei valori unitari (MIN_UV_SHARE).
##
###############################################################################
###############################################################################

## ============================== INTERRUTTORI ============================== #
## TRUE = la parte gira, FALSE = la si salta. Utile per rifare solo le stime:
## con RUN_BUILD <- FALSE lo script non ricostruisce i pannelli dai file grezzi
## ma riusa i panel_XXX.csv gia' scritti in OUTPUT (pochi minuti invece di 30).
DATA_ROOT <- Sys.getenv("ASF_DATA_ROOT", "")  # "" = cerca da solo la cartella con gli zip; altrimenti il percorso
OUT_DIR   <- ""      # "" = cartella OUTPUT accanto agli archivi
RUN_BUILD <- TRUE    # FALSE = riusa i panel_XXX.csv gia' fatti e salta la costruzione
RUN_ADV   <- TRUE    # FALSE = salta la PARTE 9 (analisi avanzate)
RUN_DEEP  <- TRUE    # FALSE = salta la PARTE 10 (paniere, proteine)
RUN_PERM  <- TRUE    # FALSE = salta la PARTE 11 (spesa permanente/transitoria)
RUN_NGA   <- TRUE    # FALSE = salta la Nigeria
RUN_UGA   <- TRUE    # FALSE = salta l'Uganda (saltato comunque se mancano i suoi archivi)
RUN_MWI   <- TRUE    # FALSE = salta il Malawi (saltato comunque se mancano i suoi archivi)
RUN_VC    <- TRUE    # FALSE = salta la PARTE 12 (filiera)
RUN_MARGINS <- TRUE  # FALSE = salta la PARTE 14 (tre margini, intervalli panel, caffe')
MARGINS_B <- 100     # ripetizioni del bootstrap dei tre margini (100 = pochi minuti)

## ============================== PACCHETTI ================================= #
## Installa quelli che mancano (solo la prima volta) e li carica.
## haven legge i file Stata (.dta) della Banca Mondiale; dplyr/tidyr per
## manipolare le tabelle; fixest per le regressioni con effetti fissi;
## ggplot2 per le figure; openxlsx per scrivere il workbook finale.
need <- c("haven","dplyr","tidyr","stringr","purrr","labelled","ggplot2","fixest",
          "openxlsx","patchwork")
for (p in need) if (!requireNamespace(p, quietly=TRUE)) install.packages(p)
suppressPackageStartupMessages({
  library(haven); library(dplyr); library(tidyr); library(stringr)
  library(purrr); library(labelled); library(ggplot2); library(fixest)
  library(openxlsx)
})
options(dplyr.summarise.inform = FALSE)
num <- function(x) suppressWarnings(as.numeric(x))

## ================ TROVA GLI ARCHIVI E LI ESTRAE UNA VOLTA ================= #
## Se DATA_ROOT non e' stato indicato, cerca gli zip (ETH_*.zip, TZA_*.zip,
## NGA_*.zip, UGA_*.zip, MWI_*.zip) nelle cartelle Desktop, Documents e OneDrive
## dell'utente. Gli zip vengono estratti in DATA_ROOT/_unzipped la prima volta;
## le volte dopo si salta l'estrazione (la cartella esiste gia').
if (!nzchar(DATA_ROOT) || !dir.exists(DATA_ROOT)) {
  home  <- Sys.getenv("USERPROFILE"); if (!nzchar(home)) home <- path.expand("~")
  cands <- c(list.dirs(home, recursive = FALSE, full.names = TRUE), home)
  cands <- cands[grepl("OneDrive|Desktop|Documents", basename(cands), ignore.case = TRUE)]
  hit <- NULL
  for (r in c(cands, home)) {
    if (!dir.exists(r)) next
    z <- list.files(r, pattern = "^(ETH|TZA|NGA|UGA|MWI)_.*\\.zip$", recursive = TRUE, full.names = TRUE)
    if (length(z)) { hit <- dirname(z[1]); break }
    f <- list.files(r, pattern = "^(sect6a_hh_w5|hh_sec_ja1)\\.dta$",
                    recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    if (length(f)) { hit <- r; break }
  }
  if (is.null(hit)) stop(
    "Could not find the data.\n",
    "Set DATA_ROOT to the folder holding the ETH_*.zip and TZA_*.zip archives.\n",
    "Tip: Shift + right-click the folder -> 'Copy as path', paste it, turn \\ into /.")
  DATA_ROOT <- hit
  message("DATA_ROOT -> ", DATA_ROOT)
}

ARCH_ROOT <- DATA_ROOT
zips <- list.files(DATA_ROOT, pattern = "^(ETH|TZA|NGA|UGA|MWI)_.*\\.zip$",
                   recursive = TRUE, full.names = TRUE)
if (length(zips)) {
  UNZ <- file.path(DATA_ROOT, "_unzipped"); dir.create(UNZ, showWarnings = FALSE)
  for (z in zips) {
    dest <- file.path(UNZ, tools::file_path_sans_ext(basename(z)))
    if (dir.exists(dest) && length(list.files(dest, recursive = TRUE))) next
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    message("unzipping ", basename(z), " ...")
    utils::unzip(z, exdir = dest)
  }
  ARCH_ROOT <- UNZ
}
if (!nzchar(OUT_DIR)) OUT_DIR <- file.path(DATA_ROOT, "OUTPUT")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

## Ogni esecuzione scrive in una sua cartella datata (run_AAAA-MM-GG_HH-MM):
## niente viene sovrascritto e due esecuzioni si possono confrontare. I PANNELLI
## restano invece in OUTPUT: sono i dati, non un risultato, e un'esecuzione con
## RUN_BUILD = FALSE deve ritrovarli li'.
RUN_STAMP <- format(Sys.time(), "%Y-%m-%d_%H-%M")     # data + ora + minuto
RUN_DIR   <- file.path(OUT_DIR, paste0("run_", RUN_STAMP))
FIGDIR    <- file.path(RUN_DIR, "figures")
## Le tabelle si scrivono prima come CSV temporanei, poi la PARTE 15 le riunisce
## in UN workbook e cancella questa cartella. Alla fine la cartella
## dell'esecuzione contiene solo il file .xlsx e la cartella delle figure.
TMPCSV    <- file.path(RUN_DIR, "_tmp_tables")
## UNA cartella di figure. Le dieci che reggono l'argomento si chiamano
## VC_01..VC_10 e stanno in cima; tutte le altre iniziano con zz_ e stanno in fondo.
FIGDIAG   <- FIGDIR
dir.create(FIGDIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TMPCSV, recursive = TRUE, showWarnings = FALSE)
## Le versioni vecchie dello script scrivevano CSV e cartelle di figure
## direttamente in OUTPUT. Qui vengono spostati in _previous_runs, cosi' OUTPUT
## contiene solo i pannelli e le cartelle datate. Non si cancella niente.
stray_csv <- setdiff(list.files(OUT_DIR, pattern="\\.csv$", full.names=TRUE),
                     list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$",
                                full.names=TRUE))
stray_dir <- list.dirs(OUT_DIR, recursive=FALSE, full.names=TRUE)
stray_dir <- stray_dir[grepl("^figures", basename(stray_dir))]
if (length(stray_csv) || length(stray_dir)) {
  OLD <- file.path(OUT_DIR, "_previous_runs")
  dir.create(OLD, showWarnings=FALSE)
  for (f in c(stray_csv, stray_dir))
    suppressWarnings(file.rename(f, file.path(OLD, basename(f))))
  message("tidied ", length(stray_csv) + length(stray_dir),
          " leftover items from earlier runs -> ", OLD)
}

message("OUT_DIR   -> ", OUT_DIR)
message("RUN_DIR   -> ", RUN_DIR)

## ------------------------------------------------ trovare i file .dta --------#
## Wave diverse usano lo stesso nome di file (hh_sec_a.dta c'e' in piu' wave
## della Tanzania): per distinguerle si passa un indizio sul percorso, come
## "TZA_2012". find_dta() restituisce il primo file che corrisponde.
## rd_et() legge un file dell'Etiopia, rd_tz() uno della Tanzania di un anno.
find_dta <- function(stem, hint = NULL) {
  f <- list.files(ARCH_ROOT, pattern = paste0("^", stem, "\\.dta$"),
                  recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (!is.null(hint) && length(f) > 1) {
    g <- f[grepl(hint, f, ignore.case = TRUE)]
    if (length(g)) f <- g
  }
  if (!length(f)) NA_character_ else f[1]
}
find_et <- function(stem) find_dta(stem)
rd_et <- function(stem) {
  p <- find_et(stem); if (is.na(p)) stop("missing file: ", stem)
  haven::read_dta(p)
}
rd_tz <- function(yr, stem) {
  p <- find_dta(stem, paste0("TZA_", yr))
  if (is.na(p)) stop("missing ", stem, " for ", yr)
  haven::read_dta(p)
}
val_labels <- labelled::val_labels

## ------------------------------------------- FILTRO SUL PREZZO (M17, parte 1) #
## COSA   Per ogni acquisto calcola il prezzo implicito: spesa / quantita'
##        acquistata convertita in kg (o litri, o pezzi). Lo confronta con la
##        mediana dello stesso prodotto nella stessa wave.
## PERCHE' Un prezzo 10 volte sopra o sotto la mediana non e' un prezzo vero:
##        e' un'unita' sbagliata (grammi letti come kg, un vassoio letto come un
##        uovo, una tabella di conversione errata). Se lo si tiene, il valore
##        unitario - cioe' la nostra misura della qualita' - e' sbagliato.
## COME   1. Uova: un vassoio da 30 registrato come un uovo costa 30 volte la
##           mediana. Se dividendo (o moltiplicando) per 30 il prezzo torna entro
##           un fattore 3 dalla mediana, le quantita' si correggono di 30
##           (deciso da Paolo, 13 novembre 2026). Solo dove le uova sono in pezzi.
##        2. Qualsiasi prodotto: se il prezzo resta sopra 10 volte o sotto un
##           decimo della mediana, la quantita' acquistata si svuota (NA). La
##           spesa resta: la famiglia conta come acquirente, ma non entra nella
##           stima della qualita'.
## Prima della v24 valeva solo in Uganda e Malawi; altrove c'erano valori
## unitari fino a 5.700 volte la mediana (regola unica decisa il 20 nov 2026).
flag_price_outliers <- function(f, all_sources = TRUE, sfx = "std") {
  ## all_sources = TRUE (Uganda): una sola unita' per tutte le fonti, quindi si
  ## correggono tutte e quattro le quantita' (totale, acquisto, autoproduzione,
  ## regali). FALSE (Tanzania, Nigeria, Etiopia, Malawi): ogni fonte ha la sua
  ## unita', si tocca solo l'acquisto; le altre fonti le gestisce
  ## follow_purchase_unit() qui sotto. sfx: suffisso delle colonne di quantita'
  ## ("std" = unita' standard del prodotto, "kg" = chilogrammi).
  pc  <- paste0("purch_", sfx)
  q4  <- if (all_sources) paste0(c("qty", "purch", "own", "gift"), "_", sfx) else pc
  pe  <- ifelse(f[[pc]] > 0 & f$exp > 0, f$exp / f[[pc]], NA)
  med <- ave(pe, f$product, FUN = function(x) median(x, na.rm = TRUE))
  near <- function(p) !is.na(p) & p > med / 3 & p < 3 * med
  ## vassoi da 30 registrati come uova singole: solo dove le uova sono in pezzi
  pcs <- if ("std" %in% names(f)) f$std == "piece" else rep(FALSE, nrow(f))
  up <- f$product == "eggs" & pcs & !is.na(pe) & pe > 10 * med & near(pe / 30)
  dn <- f$product == "eggs" & pcs & !is.na(pe) & pe < med / 10 & near(pe * 30)
  f[up, q4] <- f[up, q4] * 30
  f[dn, q4] <- f[dn, q4] / 30
  pe  <- ifelse(f[[pc]] > 0 & f$exp > 0, f$exp / f[[pc]], NA)
  bad <- !is.na(pe) & (pe > 10 * med | pe < med / 10)
  f[bad, q4] <- NA
  cat(sprintf("  price screen: %d purchases emptied, %d egg rows rescaled by 30\n",
              sum(bad), sum(up | dn)))
  f
}

## ------------------------- STESSA UNITA', STESSO ERRORE (M17, parte 1 bis) --#
## COSA   Dove ogni fonte ha la sua unita' (Tanzania, Nigeria, Etiopia), una
##        quantita' registrata nella STESSA unita' dell'acquisto scartato ha lo
##        stesso errore di conversione: segue l'acquisto (svuotata se l'acquisto
##        e' stato svuotato, moltiplicata per lo stesso fattore se e' stato
##        corretto per le uova). Il Malawi fa lo stesso nel suo blocco (TRAP M6).
## ESEMPIO Nigeria 2015: il latte in polvere in "bustina media" vale 0,4 kg
##        nella tabella ufficiale, contro 0,012 kg della bustina piccola; i
##        prezzi dicono che pesano uguale. Senza questa regola il consumo totale
##        di quelle famiglie, registrato in bustine medie, resterebbe gonfiato.
## p0: quantita' acquistata prima del filtro; units: list(purch=, qty=, own=,
## gift=) con i codici di unita' riga per riga, nello stesso ordine di f.
follow_purchase_unit <- function(f, p0, units, sfx = "std") {
  pc  <- paste0("purch_", sfx)
  cut <- !is.na(p0) & is.na(f[[pc]])
  fac <- ifelse(!is.na(p0) & !is.na(f[[pc]]) & p0 > 0, f[[pc]] / p0, 1)
  kp  <- as.character(units$purch)
  n   <- 0
  for (s in setdiff(names(units), "purch")) {
    col  <- paste0(s, "_", sfx)
    same <- !is.na(kp) & !is.na(units[[s]]) & as.character(units[[s]]) == kp
    hit  <- same & cut & !is.na(f[[col]])
    n    <- n + sum(hit)
    f[[col]][hit] <- NA
    f[[col]][same & !cut] <- f[[col]][same & !cut] * fac[same & !cut]
  }
  cat(sprintf("  price screen: %d other-source quantities in the purchase's unit emptied\n", n))
  f
}

## ---------------------------- QUANTITA' E SPESE ESTREME (M17 parte 2, M18) --#
## COSA   Sul pannello finale di ogni paese, per anno x prodotto x traccia:
##        - una spesa oltre 100 volte la mediana (tra chi spende) non si usa:
##          spesa, spesa convertita e valore unitario diventano NA (M18);
##        - una quantita' oltre 100 volte la mediana (tra chi ha quantita'
##          positiva) non si usa: tutte le quantita' NA, la spesa resta (M17).
## PERCHE' Sono errori di registrazione, non consumi. Esempi: una famiglia
##        ugandese con 10.000 kg di maiale in una settimana senza spesa; una
##        famiglia etiope con 70.000 birr per mezzo chilo di manzo (mediana 100)
##        che da sola portava la quota del manzo nel terzo quinto da 51,5 a 63,7%.
## NOTA   Se non resta nessuna quantita' e nessuna spesa, la famiglia non conta
##        piu' come acquirente di quel prodotto (7 righe su 10 per M18).
## Decise da Paolo il 20 novembre 2026. Prima M18 (spesa), poi M17 (quantita').
flag_extreme_values <- function(p, sfx = "std") {
  p <- p %>% group_by(year, product, track) %>%
    mutate(.me = median(exp[exp > 0], na.rm = TRUE)) %>% ungroup() %>%
    mutate(.xe = coalesce(exp > 100 * .me, FALSE))
  cat(sprintf("  M18: %d rows with spending > 100 x the median; spending not used\n",
              sum(p$.xe)))
  p$exp[p$.xe] <- NA; p$exp_conv[p$.xe] <- NA
  p <- p %>% select(-.me, -.xe)
  flag_extreme_qty(p, sfx)
}
flag_extreme_qty <- function(p, sfx = "std") {
  qc <- paste0(c("qty", "purch", "own", "gift"), "_", sfx)
  qc <- intersect(qc, names(p))
  tot <- paste0("qty_", sfx); pur <- paste0("purch_", sfx)
  p <- p %>% group_by(year, product, track) %>%
    mutate(.mt = median(.data[[tot]][.data[[tot]] > 0], na.rm = TRUE),
           .mp = median(.data[[pur]][.data[[pur]] > 0], na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(.x = coalesce(.data[[tot]] > 100 * .mt, FALSE) |
                coalesce(.data[[pur]] > 100 * .mp, FALSE))
  cat(sprintf("  M17: %d rows with a quantity > 100 x the median; quantities not used\n",
              sum(p$.x)))
  p[p$.x, qc] <- NA
  p$exp_conv[p$.x] <- NA
  p$unconv[p$.x & coalesce(p$exp, 0) > 0] <- 1
  p$uv <- ifelse(coalesce(p[[pur]], 0) > 0 & coalesce(p$exp_conv, 0) > 0,
                 p$exp_conv / p[[pur]], NA_real_)
  p %>% select(-.mt, -.mp, -.x)
}

## ------------------------------------- COPERTURA DEI VALORI UNITARI (v24) --#
## Per alcuni prodotti le quantita' quasi non si possono convertire (il pesce
## in Uganda e Malawi si compra a mucchi e a pezzi interi). I valori unitari
## esisterebbero solo per una piccola minoranza di acquirenti, non
## rappresentativa. Per i prodotti indicati qui, quantita' e qualita' si
## stimano solo se almeno questa quota degli acquirenti ha un valore unitario:
## per il pesce la meta'. Gli altri prodotti non sono soggetti alla regola.
MIN_UV_SHARE <- c(fish = 0.5)

## ------------------------------------------- QUINTI PER FAMIGLIA (M16) ------#
## I quinti di benessere si assegnano alle FAMIGLIE, una volta per anno, e poi
## si attaccano alle loro righe. Calcolarli sulle righe famiglia x prodotto
## poteva mettere le righe della stessa famiglia in due quinti diversi, e il
## taglio si spostava ogni volta che si aggiungeva un prodotto. Non pesati.
hh_quintile <- function(d) {
  q <- d %>% filter(!is.na(welfare)) %>% distinct(year, hhid, welfare) %>%
    group_by(year) %>% mutate(qt = ntile(welfare, 5)) %>% ungroup() %>%
    select(year, hhid, qt)
  d %>% select(-any_of("qt")) %>% left_join(q, by = c("year", "hhid"))
}


###############################################################################
###############################################################################
##
##  PARTE 2 - ETIOPIA: DAI FILE GREZZI AL PANNELLO
##            (ESS/ESPS, wave 2011, 2013, 2015, 2018, 2021)
##
##  COSA FA   Legge il modulo dei consumi alimentari di ogni wave, converte le
##            quantita' in kg con la tabella ufficiale, aggiunge benessere, pesi,
##            regione, composizione della famiglia, prezzi di mercato del
##            villaggio e coltivazione di caffe'. Scrive OUTPUT/panel_ETH.csv:
##            una riga per famiglia x prodotto x wave x traccia.
##  PERCHE'   Le wave non si possono semplicemente impilare: le sezioni del
##            questionario cambiano numero, l'identificativo della famiglia
##            cambia significato, le unita' cambiano codice. Ogni trappola
##            trovata e' scritta qui sotto (TRAP 1-5) ed e' gestita nel codice.
##  TRACCE    A = carne aggregata + latte + formaggio + uova + caffe', in tutte
##                le 5 wave (2011 e 2013 hanno la carne come voce unica);
##            B = prodotti separati (manzo, capra e pecora, pollo, pesce...),
##                solo 2015, 2018, 2021.
##
###############################################################################
###############################################################################
if (RUN_BUILD) {
###############################################################################
## CONFIGURAZIONE DELLE WAVE - nome dei file e delle variabili, tutto verificato
##
## TRAP 1  La numerazione delle sezioni si SCAMBIA. Wave 1-3: il cibo e' sect5a,
##         sect6a e' la spesa mensile NON alimentare. Wave 4-5: il cibo e' sect6a
##         e sect5a diventa il modulo dei RISPARMI. Verificato dal testo delle
##         domande.
## TRAP 2  Identificativo della famiglia. `household_id` e' quello della wave 1
##         e si ripete per le famiglie che si sono divise. Le wave 2-3 devono
##         usare `household_id2` (5.262 contro 3.777 valori unici nel 2013: il
##         28% del campione).
## TRAP 3  Chiave dell'unita' per la tabella di conversione. Nella wave 2 il
##         codice di unita' dichiarato contiene valori assenti da Food_CF_Wave2;
##         l'indagine fornisce una colonna apposita `_cf_unit`. Senza, l'acquisto
##         settimanale mediano di latte risulta 1.194 litri invece di 2.
###############################################################################
WAVES_ET <- list(
  w1 = list(year=2011, food="sect5a_hh_w1", pre="hh_s5aq", sep="_",
            itemvar="hh_s5aq00", cf="Food_CF_Wave1", weight="pw",
            hhid="household_id",  unitkey="b",
            cover="sect_cover_hh_w1", agg="cons_agg_w1", roster="sect1_hh_w1",
            age="hh_s1q04_a", sex="hh_s1q03", rel="hh_s1q02",
            price="sect10b1_com_w1", p_item="cs10b1q07_b", p_unit="cs10b1q07_d",
            p_val="cs10b1q07_f1",
            harv="sect9_ph_w1", harv_crop="crop_code",
            sale="sect12_ph_w1", sale_crop="crop_code"),
  w2 = list(year=2013, food="sect5a_hh_w2", pre="hh_s5aq", sep="_",
            itemvar="hh_s5aq00", cf="Food_CF_Wave2", weight="pw2",
            hhid="household_id2", unitkey="cf_unit",
            cover="sect_cover_hh_w2", agg="cons_agg_w2", roster="sect1_hh_w2",
            age="hh_s1q04_a", sex="hh_s1q03", rel="hh_s1q02",
            price="sect10a2_com_w2", p_item="cs10a2q02", p_unit="cs10a2q03_a",
            p_val="cs10a2q05",
            harv="sect9_ph_w2", harv_crop="crop_code",
            sale="sect12_ph_w2", sale_crop="crop_code"),
  w3 = list(year=2015, food="sect5a_hh_w3", pre="hh_s5aq", sep="_",
            itemvar="item_cd", cf="Food_CF_Wave3", weight="pw_w3",
            hhid="household_id2", unitkey="b",
            cover="sect_cover_hh_w3", agg="cons_agg_w3", roster="sect1_hh_w3",
            age="hh_s1q04a", sex="hh_s1q03", rel="hh_s1q02",
            price="sect10a2_com_w3", p_item="cs10a2q02", p_unit="cs10a2q03_a",
            p_val="cs10a2q05",
            harv="sect9_ph_w3", harv_crop="crop_code",
            sale="sect12_ph_w3", sale_crop="crop_code"),
  w4 = list(year=2018, food="sect6a_hh_w4", pre="s6aq", sep="",
            itemvar="item_cd", cf="Food_CF_Wave4", weight="pw_w4",
            hhid="household_id",  unitkey="b",
            cover="sect_cover_hh_w4", agg="cons_agg_w4", roster="sect1_hh_w4",
            age="s1q03a", sex="s1q02", rel="s1q01",
            price="sect10b_com_w4", p_item="cs10bq02", p_unit="cs10bq03",
            p_val="cs10bq05",
            harv="sect9_ph_w4", harv_crop="s9q00b",
            sale="sect11_ph_w4", sale_crop="s11q01"),
  w5 = list(year=2021, food="sect6a_hh_w5", pre="s6aq", sep="",
            itemvar="item_cd", cf="food_cf_wave5", weight="pw_w5",
            hhid="household_id",  unitkey="b",
            cover="sect_cover_hh_w5", agg="cons_agg_w5", roster="sect1_hh_w5",
            age="s1q03a", sex="s1q02", rel="s1q01",
            price="sect10b_com_w5", p_item="cs10bq02", p_unit="cs10bq03",
            p_val="cs10bq05",
            harv="sect9_ph_w5", harv_crop="s9q00b",
            sale="sect11_ph_w5", sale_crop="s11q01b")
)

###############################################################################
## QUALI VOCI DEL QUESTIONARIO DIVENTANO QUALI PRODOTTI
##  Le wave 1-2 riportano la CARNE COME UNA VOCE SOLA (codice 18); manzo, capra
##  e pollo compaiono solo dalla wave 3. Da qui le due tracce:
##    A  carne aggregata + latte + formaggio + uova + caffe'  -> tutte le 5 wave
##    B  tutto separato                                      -> solo wave 3-5
##
##  La tabella di conversione usa sempre i codici VECCHI (latte 19, caffe' 24,
##  manzo 181). Le wave 4-5 codificano i consumi come 701..801, quindi serve
##  una corrispondenza, costruita confrontando le ETICHETTE esatte, non a
##  occhio (701 "Goat & mutton meat" == 180 "Goat & mutton meat").
###############################################################################
map_old <- tibble::tribble(~item, ~product,     ~cf_item,
                            18,   "meat_agg",    18,
                            19,   "milk",        19,
                            20,   "cheese",      20,
                            21,   "eggs",        21,
                            24,   "coffee",      24)
map_w3  <- tibble::tribble(~item, ~product,     ~cf_item,
                           180,   "goat_sheep", 180,
                           181,   "beef",       181,
                           182,   "poultry",    182,
                           183,   "fish",       183,
                            19,   "milk",        19,
                            20,   "cheese",      20,
                            21,   "eggs",        21,
                            24,   "coffee",      24)
map_new <- tibble::tribble(~item, ~product,     ~cf_item,
                           701,   "goat_sheep", 180,
                           702,   "beef",       181,
                           703,   "poultry",    182,
                           704,   "fish",       183,
                           705,   "milk",        19,
                           706,   "cheese",      20,
                           709,   "eggs",        21,
                           801,   "coffee",      24)
ITEMMAP_ET <- list(w1=map_old, w2=map_old, w3=map_w3, w4=map_new, w5=map_new)
MEAT_ET <- c("beef","goat_sheep","poultry")   # pesce escluso: nel 2011-2013 la voce 18 e' "Meat"

###############################################################################
## PREZZI DI MERCATO DEL VILLAGGIO (voce 19 latte, 20 uova, 23 caffe')
##  Sono prezzi osservati al mercato dell'area di censimento (EA): non dipendono
##  dalla scelta di qualita' della famiglia, a differenza del valore unitario.
##  Servono per le elasticita' di prezzo e come controllo dei valori unitari.
##  TRAP 4  I prezzi sono in molte unita', compreso il "sini", una tazza di
##          caffe' GIA' PREPARATO. Mescolando le unita' il caffe' costa 10 birr
##          invece di 360. Per questo l'unita' si sceglie DALL'ETICHETTA; le
##          etichette hanno errori di battitura ("Littere", "Pices"), quindi si
##          confrontano le radici delle parole.
###############################################################################
CMAP <- tibble::tribble(~pitem, ~product,  19,"milk",  20,"eggs",  23,"coffee")
unit_ok <- function(product, lab) {
  lab <- tolower(ifelse(is.na(lab), "", lab))
  dplyr::case_when(
    ## v21: nel 2013 e' scritto "Liter": con "litt|litre" si perdevano tutti i
    ## prezzi del latte di quell'anno
    product == "milk"   ~ (str_detect(lab,"lit") & !str_detect(lab,"mil")),
    product == "eggs"   ~ str_detect(lab,"pice|piece|number"),
    product == "coffee" ~ str_detect(lab,"kilogram") | str_trim(lab) == "kg",
    TRUE ~ FALSE)
}

###############################################################################
## FUNZIONI CHE COSTRUISCONO IL PANNELLO
##  build_food_et()   consumi alimentari: quantita' in kg, spesa, tracce A e B
##  build_demog_et()  composizione della famiglia (bambini, anziani, capofamiglia)
##  build_prices_et() prezzi di mercato del villaggio
##  build_coffee_et() la famiglia coltiva o vende caffe'?
##  build_wave_et()   mette tutto insieme per una wave
###############################################################################
num <- function(x) suppressWarnings(as.numeric(x))

build_food_et <- function(w) {
  C <- WAVES_ET[[w]]; p <- C$pre; s <- C$sep; uk <- C$unitkey
  f  <- rd_et(C$food)
  cf <- rd_et(C$cf) %>% filter(!is.na(mean_cf_nat)) %>%
        group_by(item_cd, unit_cd) %>%
        summarise(cfac = mean(mean_cf_nat, na.rm=TRUE), .groups="drop")

  f <- f %>%
    mutate(item = num(.data[[C$itemvar]]),
           hhid = as.character(.data[[C$hhid]])) %>%
    inner_join(ITEMMAP_ET[[w]], by="item")

  # quantita' + unita' -> chilogrammi, con la tabella di conversione ufficiale
  # (fattore nazionale medio per voce x unita')
  tokg <- function(df, qv, uv_) {
    df %>% mutate(.q = num(.data[[qv]]), .u = num(.data[[uv_]])) %>%
      left_join(cf, by=c("cf_item"="item_cd", ".u"="unit_cd")) %>%
      mutate(.kg = .q * cfac) %>% pull(.kg)
  }
  f$qty_kg   <- tokg(f, paste0(p,"02",s,"a"), paste0(p,"02",s,uk))
  f$purch_kg <- tokg(f, paste0(p,"03",s,"a"), paste0(p,"03",s,uk))
  f$own_kg   <- tokg(f, paste0(p,"05",s,"a"), paste0(p,"05",s,uk))
  f$gift_kg  <- tokg(f, paste0(p,"06",s,"a"), paste0(p,"06",s,uk))
  f$exp      <- num(f[[paste0(p,"04")]])
  f$consumed <- as.numeric(num(f[[paste0(p,"01")]]) == 1)
  U <- lapply(list(purch = "03", qty = "02", own = "05", gift = "06"),
              function(k) num(f[[paste0(p, k, s, uk)]]))

  f <- f %>% select(hhid, product, consumed, qty_kg, purch_kg, own_kg, gift_kg, exp)
  ## v24 (M17): un acquisto con prezzo oltre 10 volte / sotto un decimo della
  ## mediana perde la quantita' (come in Uganda e Malawi). Qui ogni fonte ha la
  ## sua unita', quindi le altre fonti seguono solo se registrate nell'unita'
  ## dell'acquisto (funzioni nella PARTE 1)
  p0 <- f$purch_kg
  f <- flag_price_outliers(f, all_sources = FALSE, sfx = "kg")
  f <- follow_purchase_unit(f, p0, U, sfx = "kg")

  ## Traccia B: prodotti separati (solo wave 3-5). exp_conv = spesa delle sole
  ## righe con una quantita' acquistata convertita (serve per il valore
  ## unitario); unconv = 1 se c'e' spesa ma nessuna quantita' convertibile.
  B <- f %>% mutate(track = "B",
                    exp_conv = ifelse(is.na(purch_kg) | purch_kg <= 0, NA_real_, exp),
                    unconv   = as.integer(exp > 0 & (is.na(purch_kg) | purch_kg <= 0)))
  ## Traccia A: la carne si somma, cosi' le cinque wave sono confrontabili.
  ## TRAP 5  Sommare le componenti della carne puo' andare storto in due modi.
  ##  (a) max(.unconv) SENZA na.rm restituisce NA appena una componente manca,
  ##      cioe' quasi sempre (poche famiglie comprano manzo E capra E pollo).
  ##      Filtrando su unconv==0 la carne spariva dalle wave 3-5 (1.077
  ##      acquirenti nel 2015 diventavano 6).
  ##  (b) Una componente con spesa ma senza kg convertibili aggiungerebbe al
  ##      numeratore del valore unitario e niente al denominatore. Per questo la
  ##      spesa usata per il valore unitario somma SOLO le componenti convertite.
  ## Il pesce non entra nella carne aggregata (in 2011-2013 la voce 18 e' "Meat").
  A <- f %>%
    mutate(product = ifelse(product %in% MEAT_ET, "meat_agg", product)) %>%
    filter(product != "fish") %>%
    mutate(.unconv  = as.integer(exp > 0 & (is.na(purch_kg) | purch_kg <= 0)),
           .exp_conv = ifelse(is.na(purch_kg) | purch_kg <= 0, NA_real_, exp)) %>%
    group_by(hhid, product) %>%
    summarise(consumed = suppressWarnings(max(consumed, na.rm=TRUE)),
              qty_kg   = sum(qty_kg,   na.rm=TRUE),
              purch_kg = sum(purch_kg, na.rm=TRUE),
              own_kg   = sum(own_kg,   na.rm=TRUE),
              gift_kg  = sum(gift_kg,  na.rm=TRUE),
              exp      = sum(exp,       na.rm=TRUE),
              exp_conv = sum(.exp_conv, na.rm=TRUE),
              unconv   = as.integer(any(.unconv == 1, na.rm=TRUE)),
              .groups="drop") %>%
    mutate(track = "A",
           consumed = ifelse(is.finite(consumed), consumed, NA_real_),
           across(c(qty_kg, purch_kg, own_kg, gift_kg, exp, exp_conv),
                  ~ ifelse(.x == 0, NA_real_, .x)))

  if (w %in% c("w3","w4","w5")) bind_rows(A, B) else A
}

build_demog_et <- function(w) {
  C <- WAVES_ET[[w]]
  ## v21 (D15): dalla wave 2 l'elenco dei membri contiene anche chi ha LASCIATO
  ## la famiglia ("[NOME] e' ancora un membro?" = No): 2.373 / 4.597 / 784 /
  ## 2.568 righe nel 2013-2021. Venivano contati nelle quote e potevano
  ## risultare capofamiglia. Le wave 2-3 registrano anche eta' e sesso
  ## corretti, usati dove ci sono.
  still <- c(w2 = "hh_s1q04c", w3 = "hh_s1q04c", w4 = "s1q05", w5 = "s1q05")[w]
  r <- rd_et(C$roster)
  if (!is.na(still) && still %in% names(r))
    r <- r %>% filter(is.na(num(.data[[still]])) | num(.data[[still]]) != 2)
  age_c <- if ("hh_s1q04h" %in% names(r)) num(r$hh_s1q04h) else NA_real_
  sex_c <- if ("hh_s1q04e" %in% names(r)) num(r$hh_s1q04e) else NA_real_
  r <- r %>%
    mutate(hhid   = as.character(.data[[C$hhid]]),
           age    = dplyr::coalesce(age_c, num(.data[[C$age]])),
           female = as.numeric(dplyr::coalesce(sex_c, num(.data[[C$sex]])) == 2),
           head   = as.numeric(num(.data[[C$rel]]) == 1))
  r %>% group_by(hhid) %>%
    summarise(n_members    = n(),
              share_child  = mean(age < 15,  na.rm=TRUE),
              share_elderly= mean(age >= 60, na.rm=TRUE),
              share_female = mean(female,    na.rm=TRUE),
              head_age     = mean(age[head == 1],    na.rm=TRUE),
              head_female  = mean(female[head == 1], na.rm=TRUE),
              .groups="drop")
}

build_prices_et <- function(w) {
  C <- WAVES_ET[[w]]
  p <- find_et(C$price); if (is.na(p)) return(NULL)
  d <- haven::read_dta(p)
  if (!all(c(C$p_item, C$p_val) %in% names(d))) return(NULL)
  ulab <- if (C$p_unit %in% names(d)) {
    lv <- val_labels(d[[C$p_unit]])
    if (is.null(lv)) rep(NA_character_, nrow(d)) else names(lv)[match(num(d[[C$p_unit]]), lv)]
  } else rep(NA_character_, nrow(d))
  ## v21 (D16): l'identificativo dell'EA della wave stessa (2013-2015: ea_id2;
  ## ea_id e' l'EA del 2011 e manca per il nuovo campione urbano); i centesimi
  ## del 2011; e la quantita' a cui si riferisce il prezzo (30 birr per 5 uova
  ## sono 6 birr l'uno).
  ea   <- if (w %in% c("w2", "w3")) "ea_id2" else "ea_id"
  cent <- if ("cs10b1q07_f2" %in% names(d)) dplyr::coalesce(num(d$cs10b1q07_f2), 0) / 100 else 0
  amt  <- if (w == "w1") num(d$cs10b1q07_e1) + dplyr::coalesce(num(d$cs10b1q07_e2), 0) / 1000
          else num(d[[sub("05$", "04", C$p_val)]])
  amt  <- ifelse(is.na(amt) | amt <= 0, 1, amt)
  d %>% mutate(pitem = num(.data[[C$p_item]]), unit_lab = ulab,
               mkt_price = (num(.data[[C$p_val]]) + cent) / amt, .amt = amt,
               ea_id = as.character(.data[[ea]])) %>%
    inner_join(CMAP, by="pitem") %>%
    filter(unit_ok(product, unit_lab), mkt_price > 0, .amt <= 50) %>%
    group_by(ea_id, product) %>%
    summarise(mkt_price = median(mkt_price, na.rm=TRUE), .groups="drop")
}

## Coltivatori di caffe': appezzamenti con caffe' (codice coltura 72) nel modulo
## del raccolto e valore delle vendite nel modulo delle vendite. Serve per il
## confronto caffe' fra chi lo coltiva e chi lo compra (PARTE 14).
build_coffee_et <- function(w) {
  C <- WAVES_ET[[w]]; COFFEE <- 72
  h <- rd_et(C$harv); hid <- if (C$hhid %in% names(h)) C$hhid else "household_id"
  harv <- h %>% filter(num(.data[[C$harv_crop]]) == COFFEE) %>%
    mutate(hhid = as.character(.data[[hid]])) %>%
    count(hhid, name="coffee_plots")
  s <- rd_et(C$sale); sid <- if (C$hhid %in% names(s)) C$hhid else "household_id"
  s <- s %>% filter(num(.data[[C$sale_crop]]) == COFFEE) %>%
    mutate(hhid = as.character(.data[[sid]]))
  labs <- sapply(s, function(x) { l <- attr(x, "label"); if (is.null(l)) "" else tolower(l) })
  vcol <- names(labs)[str_detect(labs, "value") & str_detect(labs, "sold|sale|total")]
  s$coffee_sale <- if (length(vcol)) num(s[[vcol[1]]]) else NA_real_
  sale <- s %>% group_by(hhid) %>%
    summarise(coffee_sale_birr = sum(coffee_sale, na.rm=TRUE), .groups="drop")
  full_join(harv, sale, by="hhid") %>% mutate(coffee_grower = 1L)
}

## Una wave completa: consumi + aggregato di consumo (benessere, pesi, quinti) +
## geografia (regione, zona, urbano) + famiglia + caffe' + prezzi di mercato.
## Alla fine il valore unitario uv = spesa convertita / kg acquistati.
build_wave_et <- function(w) {
  C <- WAVES_ET[[w]]
  out <- build_food_et(w)

  agg <- rd_et(C$agg) %>% mutate(hhid = as.character(.data[[C$hhid]]))
  ea <- if (w %in% c("w2", "w3")) "ea_id2" else "ea_id"     # v21 (D16): EA della wave stessa
  keep <- intersect(c("adulteq","hh_size","nom_totcons_aeq","total_cons_ann",
                      "food_cons_ann","cons_quint", ea, C$weight), names(agg))
  agg <- agg %>% select(hhid, all_of(keep)) %>%
    rename(weight = !!C$weight, ea_id = !!ea) %>% mutate(ea_id = as.character(ea_id))

  cov <- rd_et(C$cover) %>% mutate(hhid = as.character(.data[[C$hhid]]))
  gk  <- intersect(c("saq01","saq02","saq03","rural","saq14"), names(cov))
  cov <- cov %>% select(hhid, all_of(gk)) %>% distinct(hhid, .keep_all=TRUE)
  names(cov)[names(cov) == "saq01"] <- "region"
  names(cov)[names(cov) == "saq02"] <- "zone"
  names(cov)[names(cov) == "saq03"] <- "woreda"
  if ("rural" %in% names(cov)) names(cov)[names(cov) == "rural"] <- "urban_code"
  if ("saq14" %in% names(cov)) names(cov)[names(cov) == "saq14"] <- "urban_code"

  out <- out %>%
    left_join(agg, by="hhid") %>%
    left_join(cov, by="hhid") %>%
    left_join(build_demog_et(w), by="hhid") %>%
    left_join(build_coffee_et(w), by="hhid")

  pr <- build_prices_et(w)
  if (!is.null(pr)) out <- out %>% left_join(pr, by=c("ea_id","product"))
  else out$mkt_price <- NA_real_

  out %>%
    mutate(country="ETH", wave=w, year=C$year,
           coffee_grower = ifelse(is.na(coffee_grower), 0L, coffee_grower),
           uv = ifelse(purch_kg > 0 & exp_conv > 0, exp_conv / purch_kg, NA_real_),
           across(c(region, zone, woreda, urban_code, ea_id, hhid), as.character))
}

## Tutte le wave impilate, poi le regole su spese e quantita' estreme (M18,
## M17), poi il pannello si scrive su disco.
panel_ET <- map_dfr(names(WAVES_ET), build_wave_et)
panel_ET <- flag_extreme_values(panel_ET, "kg")   # v24: regole M17 e M18 (PARTE 1)
write.csv(panel_ET, file.path(OUT_DIR, "panel_ETH.csv"), row.names=FALSE)

###############################################################################
## CONTROLLI (GATE) - il pannello non e' affidabile finche' non li passa.
##  Si leggono nella console mentre lo script gira.
##  GATE 1  le famiglie del pannello = quelle dell'aggregato di consumo ufficiale
##  GATE 2  acquisto settimanale mediano plausibile (kg o litri)
##  GATE 3  valore unitario mediano che sale con l'inflazione
##  GATE 4  valore unitario vicino al prezzo di mercato del villaggio
##  GATE 5  quota di righe con spesa ma senza quantita' convertibile
###############################################################################
cat("\n=========== GATE 1: household counts vs the consumption aggregate ======\n")
for (w in names(WAVES_ET)) {
  C <- WAVES_ET[[w]]
  n_agg <- rd_et(C$agg) %>% pull(!!C$hhid) %>% unique() %>% length()
  n_pan <- panel_ET %>% filter(wave == w) %>% pull(hhid) %>% unique() %>% length()
  cat(sprintf("   %s %d: panel_ET=%6d  aggregate=%6d  %s\n", w, C$year, n_pan, n_agg,
              ifelse(n_pan == n_agg, "OK", "*** MISMATCH ***")))
}

cat("\n=========== GATE 2: median weekly purchased quantity (plausible?) =====\n")
print(panel_ET %>% filter(purch_kg > 0) %>%
        group_by(product, year) %>% summarise(m = round(median(purch_kg), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n=========== GATE 3: median unit value — must track inflation ==========\n")
print(panel_ET %>% filter(uv > 0) %>%
        group_by(product, year) %>% summarise(m = round(median(uv), 1), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n=========== GATE 4: unit value vs INDEPENDENT market price ============\n")
cat("   (the strongest check: two instruments, two conversion paths)\n")
print(panel_ET %>% filter(!is.na(mkt_price), uv > 0) %>%
        group_by(year, product) %>%
        summarise(unit_value = round(median(uv), 1),
                  market_price = round(median(mkt_price), 1), .groups="drop") %>%
        as.data.frame())

cat("\n=========== GATE 5: rows with spend but no convertible quantity =======\n")
print(panel_ET %>% group_by(track, year) %>%
        summarise(flagged = round(mean(unconv, na.rm=TRUE), 3), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=flagged) %>% as.data.frame())

cat("\nrows:", nrow(panel_ET), " households:", length(unique(panel_ET$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_ETH.csv"), "\n")
###############################################################################

}


###############################################################################
###############################################################################
##
##  PARTE 3 - TANZANIA: DAI FILE GREZZI AL PANNELLO
##            (National Panel Survey, wave 2008, 2010, 2012, 2014, 2020)
##
##  COSA FA   Come per l'Etiopia: modulo dei consumi alimentari di ogni wave,
##            quantita' nell'unita' standard del prodotto (kg, litri, pezzi),
##            benessere per adulto equivalente, pesi, cluster, composizione della
##            famiglia. Scrive OUTPUT/panel_TZA.csv.
##  PERCHE'   Le stesse domande cambiano sezione e nome di variabile da una wave
##            all'altra (TRAP 1-7 qui sotto). Il benessere ufficiale non e' sulla
##            stessa scala in tutte le wave (D3, D18): va reso confrontabile.
##  TRACCE    A = carne aggregata + latte + uova + caffe' + pesce, B = tutto
##            separato; in Tanzania entrambe in tutte le 5 wave.
##
###############################################################################
###############################################################################
if (RUN_BUILD) {
###############################################################################
## CONFIGURAZIONE DELLE WAVE - verificata, trappole gestite
##
## TRAP 1  La lettera della sezione CAMBIA: K1 (2008, 2010) -> J1 (2012, 2014)
##         -> JA1 (2020). Riconosciuta dal testo delle domande, identico nelle
##         cinque wave.
## TRAP 2  Nel 2020 il campione e' DIVISO, non sotto-campionato: hh_sec_ja1 copre
##         4.290 famiglie e hh_sec_j1 altre 419 DIVERSE (nessuna in comune;
##         insieme 4.709 = l'aggregato di consumo). v21 (D19): si usano entrambi.
##         j1 fa le stesse domande (hh_j01-06) con unita' metriche e il pollame
##         non diviso (804).
## TRAP 3  Il suffisso _1 e' l'UNITA' e _2 la QUANTITA'. Leggendo _1 come
##         quantita' ogni acquisto diventa un numero fra 1 e 5.
## TRAP 4  L'identificativo della famiglia cambia nome a ogni wave.
###############################################################################
WAVES_TZ <- list(
  w1 = list(year=2008, zipyr="2008", food="SEC_K1",     style="old",
            hhid="hhid",    agg="TZY1.HH.Consumption", welfare="expmR",
            ## TRAP 7: SEC_A e' a livello di EA e non ha hhid; SEC_A_T e' la
            ## copertina della famiglia
            cover="SEC_A_T", itemvar="skcode",
            roster="SEC_B_C_D_E1_F_G1_U", age="sbq4", sex="sbq2", rel="sbq5"),
  w2 = list(year=2010, zipyr="2010", food="HH_SEC_K1",  style="new", pre="hh_k",
            yn="hh_k01_2",   # TRAP 5: nel 2010 si chiama hh_k01_2, non hh_k01
            hhid="y2_hhid", agg="TZY2.HH.Consumption", welfare="expmR",
            cover="HH_SEC_A", itemvar="itemcode",
            roster="HH_SEC_B", age="hh_b04", sex="hh_b02", rel="hh_b05"),
  w3 = list(year=2012, zipyr="2012", food="HH_SEC_J1",  style="new", pre="hh_j",
            hhid="y3_hhid", agg="ConsumptionNPS3",     welfare="expmR",
            cover="HH_SEC_A", itemvar="itemcode",
            roster="HH_SEC_B", age="hh_b04", sex="hh_b02", rel="hh_b05"),
  w4 = list(year=2014, zipyr="2014", food="hh_sec_j1",  style="new", pre="hh_j",
            hhid="y4_hhid", agg="consumptionNPS4",     welfare="expmR",
            cover="hh_sec_a", itemvar="itemcode",
            roster="hh_sec_b", age="hh_b04", sex="hh_b02", rel="hh_b05"),
  w5 = list(year=2020, zipyr="2020", food="hh_sec_ja1", style="new", pre="hh_ja",
            hhid="y5_hhid", agg="consumption_real_y5", welfare="expmR_pae",
            cover="hh_sec_a", itemvar="itemcode",
            roster="hh_sec_b", age="hh_b04", sex="hh_b02", rel="hh_b05")
)

###############################################################################
## ITEMS_TZ - i codici delle voci sono STABILI 2008-2020, tranne che il 2020
##  divide il pollame. Unita' standard per prodotto: carne, pesce e caffe' in KG,
##  latte in LITRI, uova in PEZZI. I valori unitari si confrontano fra famiglie
##  dentro un prodotto, mai fra prodotti diversi.
###############################################################################
ITEMS_TZ <- tibble::tribble(
  ~item, ~product,      ~std,
   801,  "goat_sheep",  "kg",
   802,  "beef",        "kg",
   803,  "pork",        "kg",
   804,  "poultry",     "kg",
  8041,  "poultry",     "kg",     # il 2020 divide 804 in pollo ...
  8042,  "poultry",     "kg",     # ... e altro pollame
   807,  "eggs",        "piece",
   901,  "milk",        "litre",
   ## v21 (D17): "MILK PRODUCTS (LIKE CREAM, CHEESE, YOGHURT)", ~97% registrato
   ## in litri o ml: con unita' standard kg solo 45 di 2.020 righe avevano una
   ## quantita'
   902,  "milk_processed", "litre",
  1102,  "coffee",      "kg",     # NB: l'etichetta e' "COFFEE AND COCOA", non solo caffe'
   ## v24 (Paolo, 15 nov 2026): il pesce torna, come prodotto a se' (non carne).
   ## 808 pesce fresco e frutti di mare compreso il dagaa (2020: diviso in 8081
   ## dagaa, 8082 kolekole, 8083 tilapia, 8084 altro), 809 secco/salato/in
   ## scatola, 810 confezionato. 2008-2014: oltre il 99% degli acquisti in kg o
   ## grammi; 2020: circa il 20% a mucchi o pezzi, che restano non convertiti
   ## (segnalati, mai indovinati).
   808,  "fish",        "kg",
  8081,  "fish",        "kg",
  8082,  "fish",        "kg",
  8083,  "fish",        "kg",
  8084,  "fish",        "kg",
   809,  "fish",        "kg",
   810,  "fish",        "kg"
)
MEAT_TZ <- c("beef","goat_sheep","pork","poultry")

## TRAP 6  Le uova sono in PEZZI nel 2008-2014 ma soprattutto in GRAMMI nel 2020
##  (200 acquisti su 394). Accettando solo i "pezzi" la partecipazione alle uova
##  crollava dal 12,3% al 3,7%: un artefatto di misura che sembra un cambiamento
##  di comportamento.
##  La conversione NON e' supposta: nel 2020 425 famiglie hanno dichiarato le
##  uova in pezzi E anche il peso (hh_ja02b_*), con una mediana di 55 g per uovo
##  (scarto interquartile 50-66). E' l'indagine che si calibra da sola.
GRAMS_PER_EGG <- 55

## codice di unita' -> moltiplicatore verso l'unita' standard del prodotto.
## Codici 1 kg, 2 g, 3 litri, 4 ml, 5 pezzi. I codici 6-20 sono unita' locali
## (mucchio, mazzo, cucchiaio, secchio...) senza fattore di conversione: quelle
## righe restano NA e sono SEGNALATE (unconv), mai indovinate.
conv_tz <- function(unit, std) {
  u <- num(unit)
  dplyr::case_when(
    std == "kg"    & u == 1 ~ 1,
    std == "kg"    & u == 2 ~ 1/1000,
    std == "litre" & u == 3 ~ 1,
    std == "litre" & u == 4 ~ 1/1000,
    std == "litre" & u == 1 ~ 1,               # il latte a volte e' dichiarato in kg
    std == "litre" & u == 2 ~ 1/1000,
    std == "piece" & u == 5 ~ 1,               # gia' in pezzi
    std == "piece" & u == 2 ~ 1/GRAMS_PER_EGG, # grammi -> pezzi
    std == "piece" & u == 1 ~ 1000/GRAMS_PER_EGG,
    ## v21 (D6, deciso il 12 nov 2026): nel 2020, 34 acquisti di uova hanno
    ## unita' 20 "OTHER (SPECIFY)" a una mediana di 350 TSh per unita', cioe'
    ## esattamente il prezzo di un uovo comprato a pezzi: si leggono come pezzi.
    ## Solo uova, solo 2020.
    std == "piece" & u == 20 ~ 1,
    TRUE ~ NA_real_)
}

###############################################################################
## COSTRUZIONE DI UNA WAVE
##  1. legge il modulo alimentare (nel 2020 i due moduli, TRAP 2)
##  2. trova i nomi delle variabili (2008 ha nomi diversi: skq*)
##  3. converte le quantita' e applica il filtro sul prezzo (M17)
##  4. somma le righe per famiglia x prodotto: tracce A e B
##  5. aggiunge benessere, composizione della famiglia, cluster e pesi
###############################################################################
build_wave_tz <- function(w) {
  C <- WAVES_TZ[[w]]
  f <- rd_tz(C$zipyr, C$food)
  if (w == "w5") {                       # v21 (D19): le 419 famiglie di hh_sec_j1
    j1 <- rd_tz(C$zipyr, "hh_sec_j1")
    names(j1) <- sub("^hh_j0", "hh_ja0", names(j1))
    f <- bind_rows(haven::zap_labels(f), haven::zap_labels(j1))
  }

  if (C$style == "old") {                       # il 2008 usa i nomi skq*
    v <- list(yn="skq1", q_tot="skq2_amount", u_tot="skq2_meas",
              q_pur="skq3_amount", u_pur="skq3_meas", spend="skq4",
              q_own="skq5_amount", u_own="skq5_meas",
              q_gif="skq6_amount", u_gif="skq6_meas")
  } else {
    p <- C$pre
    v <- list(yn=if (!is.null(C$yn)) C$yn else paste0(p,"01"),
              q_tot=paste0(p,"02_2"), u_tot=paste0(p,"02_1"),
              q_pur=paste0(p,"03_2"), u_pur=paste0(p,"03_1"),
              spend=paste0(p,"04"),
              q_own=paste0(p,"05_2"), u_own=paste0(p,"05_1"),
              q_gif=paste0(p,"06_2"), u_gif=paste0(p,"06_1"))
  }

  ## se una wave ha rinominato qualcosa, lo script si ferma e dice cosa manca
  miss <- setdiff(c(unlist(v), C$itemvar, C$hhid), names(f))
  if (length(miss)) stop("wave ", w, " (", C$year, "): missing column(s) in ",
                         C$food, ": ", paste(miss, collapse=", "),
                         "\n   available: ", paste(names(f), collapse=", "))

  f <- f %>%
    mutate(item = num(.data[[C$itemvar]]),
           hhid = as.character(.data[[C$hhid]])) %>%
    inner_join(ITEMS_TZ, by="item")

  g <- function(q, u) num(f[[q]]) * conv_tz(f[[u]], f$std)
  f$qty_std   <- g(v$q_tot, v$u_tot)
  f$purch_std <- g(v$q_pur, v$u_pur)
  f$own_std   <- g(v$q_own, v$u_own)
  f$gift_std  <- g(v$q_gif, v$u_gif)
  f$exp       <- num(f[[v$spend]])
  f$consumed  <- as.numeric(num(f[[v$yn]]) == 1)
  U <- lapply(list(purch = v$u_pur, qty = v$u_tot, own = v$u_own, gift = v$u_gif),
              function(u) num(f[[u]]))

  f <- f %>% select(hhid, product, std, consumed,
                    qty_std, purch_std, own_std, gift_std, exp)
  ## v24 (M17): un acquisto con prezzo oltre 10 volte / sotto un decimo della
  ## mediana perde la quantita' (come in Uganda e Malawi). Qui ogni fonte ha la
  ## sua unita', quindi le altre fonti seguono solo se registrate nell'unita'
  ## dell'acquisto (funzioni nella PARTE 1)
  p0 <- f$purch_std
  f <- flag_price_outliers(f, all_sources = FALSE)
  f <- follow_purchase_unit(f, p0, U)

  ## Somma per famiglia x prodotto. Una componente con spesa ma senza quantita'
  ## convertibile gonfierebbe il valore unitario, quindi la sua spesa e' esclusa
  ## dal totale abbinato exp_conv (come in Etiopia, TRAP 5).
  agg_by <- function(df, prod_col) {
    df %>%
      mutate(.unconv   = as.integer(exp > 0 & (is.na(purch_std) | purch_std <= 0)),
             .exp_conv = ifelse(is.na(purch_std) | purch_std <= 0, NA_real_, exp)) %>%
      group_by(hhid, product = .data[[prod_col]], std) %>%
      summarise(consumed  = suppressWarnings(max(consumed, na.rm=TRUE)),
                qty_std   = sum(qty_std,   na.rm=TRUE),
                purch_std = sum(purch_std, na.rm=TRUE),
                own_std   = sum(own_std,   na.rm=TRUE),
                gift_std  = sum(gift_std,  na.rm=TRUE),
                exp       = sum(exp,       na.rm=TRUE),
                exp_conv  = sum(.exp_conv, na.rm=TRUE),
                unconv    = as.integer(any(.unconv == 1, na.rm=TRUE)),
                .groups="drop") %>%
      mutate(consumed = ifelse(is.finite(consumed), consumed, NA_real_),
             across(c(qty_std, purch_std, own_std, gift_std, exp, exp_conv),
                    ~ ifelse(.x == 0, NA_real_, .x)))
  }

  B <- agg_by(f, "product") %>% mutate(track = "B")          # prodotti separati
  A <- f %>%                                                  # carne sommata
    mutate(prodA = ifelse(product %in% MEAT_TZ, "meat_agg", product)) %>%
    filter(!prodA %in% c("cheese", "milk_processed")) %>%
    agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)

  ## benessere, composizione della famiglia, geografia
  a <- rd_tz(C$zipyr, C$agg) %>% mutate(hhid = as.character(.data[[C$hhid]]))
  keep <- intersect(c("adulteq","hhsize","urban","region","hhweight",
                      C$welfare), names(a))
  a <- a %>% select(hhid, all_of(keep)) %>% rename(welfare = !!C$welfare)
  ## v21 (D3): expmR e' il totale della FAMIGLIA ("Total consumption, annual,
  ## real"); solo expmR_pae del 2020 e' per adulto equivalente. Si mettono le
  ## wave 2008-2014 sulla stessa base, come in Etiopia (nom_totcons_aeq).
  ## v21 (D18): si divide per gli adulti equivalenti veri; il minimo di 1 tagliava
  ## il benessere del 12-28% per 614 famiglie di una persona.
  if (C$welfare == "expmR") a <- a %>% mutate(welfare = welfare / adulteq)
  ## v21 (D18): expmR_pae e' "reale, PER 28 GIORNI, per adulto equivalente": si
  ## porta sulla scala annua del 2008-2014 (x 365/28 = 13,04).
  if (C$welfare == "expmR_pae") a <- a %>% mutate(welfare = welfare * 365 / 28)
  if (!"hhweight" %in% names(a)) a$hhweight <- NA_real_

  ## composizione della famiglia: gli STESSI controlli dell'Etiopia, cosi' i
  ## paesi si stimano con specificazioni confrontabili
  rr <- try(rd_tz(C$zipyr, C$roster), silent=TRUE)
  if (!inherits(rr, "try-error") &&
      all(c(C$age, C$sex, C$rel) %in% names(rr))) {
    idr <- if (C$hhid %in% names(rr)) C$hhid else names(rr)[grepl("hhid", names(rr))][1]
    dem <- rr %>%
      mutate(hhid   = as.character(.data[[idr]]),
             .age   = num(.data[[C$age]]),
             .fem   = as.numeric(num(.data[[C$sex]]) == 2),
             .head  = as.numeric(num(.data[[C$rel]]) == 1)) %>%
      group_by(hhid) %>%
      summarise(share_child   = mean(.age <  15, na.rm=TRUE),
                share_elderly = mean(.age >= 60, na.rm=TRUE),
                head_age      = mean(.age[.head == 1], na.rm=TRUE),
                head_female   = mean(.fem[.head == 1], na.rm=TRUE),
                .groups="drop")
    a <- a %>% left_join(dem, by="hhid")
  }

  ## cluster e strato: per l'inferenza secondo il disegno dell'indagine e per i
  ## prezzi medi del cluster (PARTE 7)
  cl <- try(rd_tz(C$zipyr, C$cover), silent=TRUE)
  if (!inherits(cl, "try-error")) {
    idc <- if (C$hhid %in% names(cl)) C$hhid else names(cl)[grepl("hhid", names(cl))][1]
    ## il 2008 chiama l'unita' di campionamento ea_id, le wave dopo clusterid
    if (!"clusterid" %in% names(cl) && "ea_id" %in% names(cl))
      cl$clusterid <- cl$ea_id
    ## v21 (D4): il 2012 ha il peso (y3_weight) solo nella copertina
    kc  <- intersect(c("clusterid","strataid","y3_weight"), names(cl))
    if (!is.na(idc) && length(kc)) {
      cl <- cl %>% mutate(hhid = as.character(.data[[idc]])) %>%
        select(hhid, all_of(kc)) %>% distinct(hhid, .keep_all=TRUE)
      a <- a %>% left_join(cl, by="hhid")
      if ("y3_weight" %in% names(a)) {
        a$hhweight <- ifelse(is.na(a$hhweight), num(a$y3_weight), a$hhweight)
        a$y3_weight <- NULL
      }
    }
  }
  if (!"clusterid" %in% names(a)) a$clusterid <- NA
  if (!"strataid"  %in% names(a)) a$strataid  <- NA

  out %>% left_join(a, by="hhid") %>%
    mutate(country="TZA", wave=w, year=C$year,
           uv = ifelse(purch_std > 0 & exp_conv > 0, exp_conv / purch_std, NA_real_),
           across(c(hhid, region, urban, clusterid, strataid), as.character))
}

## Tutte le wave impilate, poi spese e quantita' estreme (M18, M17), poi su disco.
panel_TZ <- map_dfr(names(WAVES_TZ), build_wave_tz)
panel_TZ <- flag_extreme_values(panel_TZ)   # v24: regole M17 e M18 (PARTE 1)
write.csv(panel_TZ, file.path(OUT_DIR, "panel_TZA.csv"), row.names=FALSE)

###############################################################################
## CONTROLLI (GATE), da leggere nella console
##  GATE 1 famiglie = aggregato ufficiale; GATE 2 acquisti mediani plausibili;
##  GATE 3 valori unitari che seguono l'inflazione; GATE 4 partecipazione;
##  GATE 5 unita' locali non convertibili; GATE 6 identificativi di cluster.
###############################################################################
cat("\n===== GATE 1: household counts vs the consumption aggregate =====\n")
for (w in names(WAVES_TZ)) {
  C <- WAVES_TZ[[w]]
  n_agg <- rd_tz(C$zipyr, C$agg) %>% pull(!!C$hhid) %>% unique() %>% length()
  n_pan <- panel_TZ %>% filter(wave == w) %>% pull(hhid) %>% unique() %>% length()
  msg <- if (n_pan == n_agg) "OK"
         else if (n_pan >  n_agg) "panel_TZ > aggregate: food module covers households the aggregate drops (welfare will be NA)"
         else "panel_TZ < aggregate: 2020 sample split, the 419 hh_sec_j1 households are excluded by design"
  cat(sprintf("   %s %d: panel_TZ=%6d  aggregate=%6d  %s\n", w, C$year, n_pan, n_agg, msg))
}

cat("\n===== GATE 2: median weekly purchase among buyers (plausible?) =====\n")
print(panel_TZ %>% filter(track=="B", purch_std > 0) %>%
        group_by(product, std, year) %>%
        summarise(m = round(median(purch_std), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== GATE 3: median unit value (TSH) — must track inflation =====\n")
print(panel_TZ %>% filter(track=="B", uv > 0) %>%
        group_by(product, year) %>%
        summarise(m = round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== GATE 4: participation, % of households buying =====\n")
print(panel_TZ %>% filter(track=="B") %>%
        group_by(product, year) %>%
        summarise(p = round(100*mean(!is.na(purch_std) & purch_std > 0), 1),
                  .groups="drop") %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())

cat("\n===== GATE 5: unconvertible local units (flagged, not guessed) =====\n")
print(panel_TZ %>% filter(track=="B") %>% group_by(year) %>%
        summarise(flagged = round(mean(unconv, na.rm=TRUE), 3), .groups="drop") %>%
        as.data.frame())

cat("\n===== GATE 6: cluster identifiers present? =====\n")
print(panel_TZ %>% group_by(year) %>%
        summarise(with_cluster = round(mean(!is.na(clusterid)), 2), .groups="drop") %>%
        as.data.frame())

cat("\nrows:", nrow(panel_TZ), " households:", length(unique(panel_TZ$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_TZA.csv"), "\n")
###############################################################################

}


###############################################################################
###############################################################################
##
##  PARTE 4 - MALAWI: DAI FILE GREZZI AL PANNELLO
##            (IHS3 2010, IHS4 2016, IHS5 2019, IHS6 2024)
##
##  COSA FA   Come per gli altri paesi: consumi alimentari, quantita' nell'unita'
##            standard, benessere, pesi, distretto, composizione della famiglia.
##            Scrive OUTPUT/panel_MWI.csv.
##  PERCHE' COSI'  Il Malawi e' il paese piu' povero dei cinque. Il suo panel
##            (IHPS 2010-13-16 e 2024) e' distribuito SENZA aggregato di
##            consumo, quindi senza misura di benessere: non si puo' usare. Si
##            usano invece le quattro indagini nazionali IHS (circa 49.000
##            famiglie, ognuna con il suo aggregato). Sono SEZIONI TRASVERSALI
##            RIPETUTE, non un panel: il Malawi entra in tutte le analisi
##            trasversali ma non negli effetti fissi familiari ne' nella spesa
##            permanente (panel_ids() non ha un ramo per il Malawi). L'IHS2 del
##            2004 e' escluso: questionario e struttura dei file diversi.
##
##  TRAP M1  L'IHS3 2010 contiene il modulo alimentare due volte, in Full_Sample/
##           (12.271 famiglie) e in Panel/ (il sotto-campione di base dell'IHPS).
##           Si legge Full_Sample; lo dice l'indizio sul percorso.
##  TRAP M2  Ogni fonte (totale, acquisto, autoproduzione, regalo) ha la SUA
##           unita'. Il 2010 aggiunge una lettera di taglia ad alcuni codici
##           ("9A", "9B", "9C" = pezzo piccolo, medio, grande; "22A/B" bustine):
##           il prezzo e' quello del codice semplice, la lettera si toglie.
##  TRAP M3  Le unita' si convertono col loro significato metrico (kg, grammo,
##           litro, millilitro) e, per i pezzi di pollo e le bustine e i
##           cucchiai di latte, con la tabella di conversione 2020 della Banca
##           Mondiale (kg per unita', per regione; un pollo intero pesa 1,27-1,48
##           kg). Il "pezzo" di manzo, capra o maiale NON si converte: la tabella
##           da' 0,036 kg al Nord e 0,25 kg al Centro e al Sud per la stessa
##           voce, che non e' una misura. Nemmeno i pezzi di "altro pollame"
##           (509) e i cucchiaini di latte in polvere, smentiti dai prezzi, ne'
##           il latte fresco "in grammi". "Altro (specificare)" si converte
##           quando il testo indica una quantita' metrica, un vassoio (30) o una
##           dozzina di uova, un pollo intero (1,26 kg) o mezzo, o una bustina di
##           latte; i pacchetti di latte fresco costano come le bustine e si
##           leggono come bustine (vedi oth_mw()).
##  TRAP M4  L'aggregato 2010 non ha ne' la dimensione della famiglia ne' il
##           peso: vengono dall'elenco dei membri e dalla copertina. L'aggregato
##           2024 non ha la scala di adulti equivalenti, quindi il Malawi usa la
##           dimensione della famiglia in tutte le wave (come la Nigeria):
##           benessere = consumo reale annuo per persona, adulteq = numero di
##           membri.
##  TRAP M6  Errori di unita' (grammi scritti come chili, millilitri come litri):
##           un acquisto con prezzo oltre 10 volte o sotto un decimo della
##           mediana perde le quantita', come in Uganda (flag_price_outliers(),
##           PARTE 1). 1-4% degli acquisti di pollo e latte trasformato, meno
##           dell'1% altrove.
##  TRAP M5  Solo tre regioni: come "regione" per gli effetti regionali si usa
##           il DISTRETTO (circa 30); il codice a tre regioni serve solo per
##           leggere la tabella di conversione (il 2010 non ha la variabile
##           regione: e' la cifra delle centinaia del codice di distretto).
##
###############################################################################
###############################################################################
if (exists("RUN_MWI") && !RUN_MWI) message("PART 2d skipped") else
if (!length(list.files(ARCH_ROOT, pattern = "^MWI_20(10|16|19|24)", include.dirs = TRUE))) {
  message("PART 2d: no Malawi IHS archives (MWI_*.zip) found - Malawi skipped")
} else if (RUN_BUILD) {

WAVES_MW <- list(
  w1 = list(year=2010, hint="MWI_2010_IHS-III.*Full_Sample", agg="ihs3fc2M_consumption"),
  w2 = list(year=2016, hint="MWI_2016_IHS-IV",               agg="ihs4 consumption aggregate"),
  w3 = list(year=2019, hint="MWI_2019_IHS-V",                agg="ihs5_consumption_aggregate"),
  w4 = list(year=2024, hint="MWI_2024-2025_IHS-VI",          agg="ihs6_consumptionaggregates")
)
## una wave si costruisce solo se il suo archivio c'e'
WAVES_MW <- WAVES_MW[sapply(WAVES_MW, function(C) !is.na(find_dta("hh_mod_g1", C$hint)) &&
                                            grepl(sub("\\.\\*.*", "", C$hint), find_dta("hh_mod_g1", C$hint)))]
rd_mw <- function(C, stem) {
  p <- find_dta(stem, C$hint)
  if (is.na(p) || !grepl(sub("\\.\\*.*", "", C$hint), p)) stop("missing ", stem, " for Malawi ", C$year)
  haven::read_dta(p)
}

ITEMS_MW <- tibble::tribble(
  ~item, ~product,         ~std,
   504,  "beef",           "kg",
   505,  "goat_sheep",     "kg",     # capra
   507,  "goat_sheep",     "kg",     # montone
   506,  "pork",           "kg",
   508,  "poultry",        "kg",     # pollo
   509,  "poultry",        "kg",     # faraona, colombe
   501,  "eggs",           "piece",
   701,  "milk",           "litre",  # latte fresco
   702,  "milk_processed", "kg",     # latte in polvere (come in Nigeria)
   902,  "coffee",         "kg",
   ## v24 (Paolo, 15 nov 2026): il pesce torna, come prodotto a se'. 502 secco,
   ## 503 fresco, 513 affumicato (2010; il 2016 ha entrambe le codifiche), poi
   ## per taglia della varieta': 5021-5023 essiccato al sole, 5031-5033 fresco,
   ## 5121-5123 affumicato.
   ## TRAP M7: il 97% degli acquisti di pesce e' a mucchi o pezzi. La tabella
   ## 2020 ha dei fattori, ma i prezzi la smentiscono: nella stessa voce e
   ## nello stesso anno un chilo comprato a mucchi piccoli costa 2-6 volte uno
   ## comprato a mucchi grandi (2024, essiccato grande: 11.628 contro 1.802
   ## MK/kg), e lo stesso pesce costa 2-3 volte di piu' al chilo in una regione
   ## che in un'altra. Come per i pezzi di carne rossa, i mucchi NON si
   ## convertono: il pesce conta per acquisto e spesa, con quantita' solo dove
   ## dichiarate in kg o grammi.
   502,  "fish",           "kg",
   503,  "fish",           "kg",
   513,  "fish",           "kg",
  5021,  "fish",           "kg",
  5022,  "fish",           "kg",
  5023,  "fish",           "kg",
  5031,  "fish",           "kg",
  5032,  "fish",           "kg",
  5033,  "fish",           "kg",
  5121,  "fish",           "kg",
  5122,  "fish",           "kg",
  5123,  "fish",           "kg"
)   # 512 carne o pesce in scatola, 514 zuppa di pesce, 705 chambiko, 706 yogurt, 707 formaggio, 82x cibo da venditori: non usati
MEAT_MW <- c("beef","goat_sheep","pork","poultry")

## la tabella di conversione 2020 della Banca Mondiale (kg per unita'), se c'e'.
## v23 (controllo indipendente): 509 "altro pollame" resta fuori - un pezzo
## costa da un decimo a un terzo di un pollo (colombe, piccioni), eppure la
## tabella gli da' il peso di un pollo; resta fuori anche il CUCCHIAINO di latte
## in polvere (codice 20), che la tabella fa piu' pesante del cucchiaio (0,06-
## 0,14 kg contro 0,01).
cf_path <- find_dta("ihs_foodconversion_factor_2020", "MWI_2019")
CF_MW <- if (is.na(cf_path)) NULL else haven::read_dta(cf_path) %>%
  transmute(region3 = num(region), item = num(item_code), unit = trimws(as.character(unit_code)),
            factor = num(factor)) %>%
  filter(unit != "23", item %in% c(508, 701, 702), !(item == 702 & unit == "20"), !is.na(factor)) %>%
  group_by(region3, item, unit) %>% summarise(cf = mean(factor), .groups = "drop")

## "Altro (specificare)" (codice 23). Si converte solo quando il testo indica una
## quantita' metrica (anche con errori di ortografia e virgola decimale:
## "MILLITER", "GRAMM", "0,3 KILOGRAMMES"), un vassoio / cassetta (30) o una
## dozzina di uova, un pezzo di uovo, un pollo intero o mezzo, o una bustina di
## latte (il valore della tabella per quella voce). v23: i PACCHETTI di latte
## fresco costano come le bustine in ogni wave, quindi si leggono come bustine,
## per analogia con la decisione di Paolo sulla "Nice cup" (Uganda).
oth_mw <- function(o, item, std, sachet) {
  o  <- toupper(trimws(ifelse(is.na(o), "", as.character(o))))
  o  <- sub("[.]+$", "", gsub("([0-9]),([0-9])", "\\1.\\2", o))
  KG <- "(KGS?|KILOS?|KILOGRAMM?E?S?)"
  G  <- "(GS?|GRMS?|GRAMM?E?S?|GARAMS?)"
  ML <- "(MLS?|MIL|MILL?I?LIT(RE|ER)S?|MILL?IT(RE|ER)S?|MILITRES?|MILLIMETRES?|MILLIGRAMS?)"
  amt <- function(re) {
    x <- rep(NA_real_, length(o)); pat <- paste0("([0-9]+[.]?[0-9]*) ?", re, "\\b")
    hit <- grepl(pat, o, perl = TRUE)
    x[hit] <- suppressWarnings(as.numeric(sub(paste0("^.*?", pat, ".*$"), "\\1", o[hit], perl = TRUE)))
    x
  }
  kg <- amt(KG); g <- amt(G) / 1000; ml <- amt(ML) / 1000
  dplyr::case_when(
    std == "piece" & grepl("^(TRAY|TREY|TRY|CRATE|CRETE)S?$", o)              ~ 30,
    std == "piece" & o == "DOZEN"                                             ~ 12,
    std == "piece" & grepl("^(PIECE|PEACE|PEICE)S?( ?[(].*[)])?$", o)        ~ 1,
    item == 508 & grepl("^HALF", o) & grepl("CHICKEN|WHOLE", o)               ~ 0.63,
    item == 508 & grepl("WHOLE|FULL|^([0-9]+ )?CHICKENS?$", o) &
      !grepl("HALF|PIECES? OF", o)                                            ~ 1.26,
    std %in% c("kg","litre") & !is.na(kg)                                     ~ kg,
    std %in% c("kg","litre") & !is.na(g)                                      ~ g,
    std == "litre" & !is.na(ml)                                               ~ ml,
    std %in% c("kg","litre") & grepl(paste0("^HALF ", KG, "$"), o)            ~ 0.5,
    std %in% c("kg","litre") & grepl(paste0("^", KG, "$"), o)                 ~ 1,
    std == "kg" & grepl(paste0("^", G, "$"), o)                               ~ 1/1000,
    std == "kg" & grepl("^GARAM", o)                                          ~ 1/1000,  # "GARAMSACHET"
    std == "litre" & grepl(paste0("^", ML, "$"), o)                           ~ 1/1000,
    item %in% c(701, 702) & grepl("SA?T?CHET|SACHET", o)                      ~ sachet,
    item == 701 & grepl("^(SMALL )?PACKETS?( [(]SMALL[)]| UNSPECIFIED)?$", o) ~ sachet,
    TRUE ~ NA_real_)
}

## Converte la quantita' di una fonte nell'unita' standard del prodotto, in base
## al codice di unita', al testo "altro" e alla regione (per la tabella).
conv_mw <- function(item, std, unit, oth, region3, ulab = NA) {
  ## TRAP M2: le lettere di taglia del 2010 ("9A", "22B") valgono come il codice
  ## semplice
  u <- sub("[A-Za-z]+$", "", trimws(as.character(unit)))
  tab <- function(uu) if (is.null(CF_MW)) rep(NA_real_, length(uu)) else
    CF_MW$cf[match(paste(region3, item, uu), paste(CF_MW$region3, CF_MW$item, CF_MW$unit))]
  t_u <- tab(u); t_sachet <- tab(rep("22", length(u)))
  ot <- oth_mw(oth, item, std, t_sachet)
  ## v23: le latte del 2016 (codici 71-73) hanno il peso nell'etichetta
  ## ("TIN 100G")
  la <- toupper(ifelse(is.na(ulab), "", as.character(ulab)))
  la_g <- suppressWarnings(as.numeric(ifelse(grepl("[0-9] ?G\\b", la),
            sub("^.*?([0-9]+) ?G\\b.*$", "\\1", la, perl = TRUE), NA))) / 1000
  dplyr::case_when(
    is.na(u) | u == ""                                  ~ NA_real_,
    std == "piece" & u == "9"                           ~ 1,
    std %in% c("kg","litre") & u == "1"                 ~ 1,      # latte: kg = litro
    ## il latte fresco "in grammi" costa 4,9 volte il prezzo al litro (2010):
    ## non si converte
    std == "kg" & u == "18"                             ~ 1/1000,
    std == "litre" & u == "15"                          ~ 1,
    std == "litre" & u == "19"                          ~ 1/1000,
    u == "23"                                           ~ ot,
    std %in% c("kg","litre") & grepl("^TIN", la) & !is.na(la_g) ~ la_g,
    ## i pacchetti di latte fresco (codici 51, 60) costano come una bustina
    item == 701 & u %in% c("51", "60")                  ~ t_sachet,
    item %in% c(508, 701, 702) & !is.na(t_u)            ~ t_u,       # TRAP M3
    TRUE ~ NA_real_)
}

## Una wave completa: consumi -> quantita' convertite -> filtro sul prezzo ->
## somma per famiglia x prodotto (tracce A e B) -> tutte le famiglie x tutti i
## prodotti (zero dove non consumato) -> membri, benessere, distretto e pesi.
build_wave_mw <- function(w) {
  C <- WAVES_MW[[w]]
  f  <- rd_mw(C, "hh_mod_g1")
  cv <- rd_mw(C, "hh_mod_a_filt")
  ## copertina: il distretto come "regione" (TRAP M5), le tre regioni per la
  ## tabella. v23: il 2024 aggiunge il campo profughi di Dzaleka (camp = 1, 386
  ## famiglie): un campione a parte senza aggregato di consumo, escluso.
  camp_hh <- if ("camp" %in% names(cv)) trimws(as.character(cv$case_id[num(cv$camp) %in% 1])) else character(0)
  dist <- num(if ("district" %in% names(cv)) cv$district else cv$hh_a01)
  cv <- tibble(hhid      = trimws(as.character(cv$case_id)),
               region    = as.character(dist),
               region3   = if ("region" %in% names(cv)) num(cv$region) else floor(dist / 100),
               urban     = ifelse(tolower(trimws(as.character(haven::as_factor(cv$reside)))) == "urban", "1", "0"),
               clusterid = trimws(as.character(cv$ea_id)),
               hhweight  = num(cv$hh_wgt)) %>% distinct(hhid, .keep_all = TRUE)

  f <- f %>% mutate(hhid = trimws(as.character(case_id)), item = num(hh_g02)) %>%
    filter(!hhid %in% camp_hh)
  hh_all <- unique(f$hhid)
  f <- f %>% inner_join(ITEMS_MW, by = "item") %>%
    left_join(cv %>% select(hhid, region3), by = "hhid")
  src <- function(q, u) {
    ov  <- intersect(paste0(u, c("_oth", "_os")), names(f))           # 2010: _os
    oth <- if (length(ov)) as.character(f[[ov[1]]]) else NA
    lv  <- paste0(u, "_label")
    ulab <- if (lv %in% names(f)) as.character(haven::as_factor(f[[lv]])) else NA
    num(f[[q]]) * conv_mw(f$item, f$std, haven::zap_labels(f[[u]]), oth, f$region3, ulab)
  }
  f$qty_std   <- src("hh_g03a", "hh_g03b")
  f$purch_std <- src("hh_g04a", "hh_g04b")
  f$own_std   <- src("hh_g06a", "hh_g06b")
  f$gift_std  <- src("hh_g07a", "hh_g07b")
  f$exp       <- num(f$hh_g05)
  ## v23: qualsiasi quantita' o spesa vuol dire che la voce e' stata consumata
  f$consumed  <- as.numeric(num(f$hh_g01) == 1 |
                            rowSums(cbind(num(f$hh_g03a), num(f$hh_g04a), num(f$hh_g06a),
                                          num(f$hh_g07a), f$exp) > 0, na.rm = TRUE) > 0)
  ## TRAP M6. Qui ogni fonte ha la sua unita', quindi un ACQUISTO con prezzo
  ## anomalo svuota solo la quantita' acquistata (in Uganda: un'unita' per tutte)
  p0 <- f$purch_std
  f <- flag_price_outliers(f, all_sources = FALSE)
  ## ... e qualsiasi altra fonte registrata nella STESSA unita' e con lo stesso
  ## testo dell'acquisto (270 righe su 279: il totale ripete l'unita'
  ## dell'acquisto)
  key <- function(b) { ov <- intersect(paste0(b, c("_oth", "_os")), names(f))
    paste(trimws(as.character(haven::zap_labels(f[[b]]))), if (length(ov)) toupper(trimws(f[[ov[1]]])) else "") }
  kp  <- key("hh_g04b")
  cut <- !is.na(p0) & is.na(f$purch_std)
  fac <- ifelse(!is.na(p0) & !is.na(f$purch_std) & p0 > 0, f$purch_std / p0, 1)
  for (s in list(c("qty_std", "hh_g03b"), c("own_std", "hh_g06b"), c("gift_std", "hh_g07b"))) {
    same <- key(s[2]) == kp
    f[[s[1]]][same & cut] <- NA
    f[[s[1]]][same & !cut] <- f[[s[1]]][same & !cut] * fac[same & !cut]
  }
  f <- f %>% select(hhid, product, std, consumed, qty_std, purch_std, own_std, gift_std, exp)

  ## somma per famiglia x prodotto, come in Tanzania (spesa abbinata exp_conv)
  agg_by <- function(df, prod_col) {
    df %>%
      mutate(.unconv   = as.integer(exp > 0 & (is.na(purch_std) | purch_std <= 0)),
             .exp_conv = ifelse(is.na(purch_std) | purch_std <= 0, NA_real_, exp)) %>%
      group_by(hhid, product = .data[[prod_col]], std) %>%
      summarise(consumed  = suppressWarnings(max(consumed, na.rm=TRUE)),
                qty_std   = sum(qty_std,   na.rm=TRUE),
                purch_std = sum(purch_std, na.rm=TRUE),
                own_std   = sum(own_std,   na.rm=TRUE),
                gift_std  = sum(gift_std,  na.rm=TRUE),
                exp       = sum(exp,       na.rm=TRUE),
                exp_conv  = sum(.exp_conv, na.rm=TRUE),
                unconv    = as.integer(any(.unconv == 1, na.rm=TRUE)),
                .groups="drop") %>%
      mutate(consumed = ifelse(is.finite(consumed), consumed, NA_real_),
             across(c(qty_std, purch_std, own_std, gift_std, exp, exp_conv),
                    ~ ifelse(.x == 0, NA_real_, .x)))
  }
  B <- agg_by(f, "product") %>% mutate(track = "B")
  A <- f %>% mutate(prodA = ifelse(product %in% MEAT_MW, "meat_agg", product)) %>%
    filter(prodA != "milk_processed") %>% agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)
  ## ogni famiglia con ogni prodotto: chi non ha consumato ha una riga a zero
  ## (il modulo del Malawi elenca solo le voci consumate)
  prods <- bind_rows(
    ITEMS_MW %>% distinct(product, std) %>% mutate(track = "B"),
    ITEMS_MW %>% mutate(product = ifelse(product %in% MEAT_MW, "meat_agg", product)) %>%
      filter(product != "milk_processed") %>% distinct(product, std) %>% mutate(track = "A"))
  out <- tidyr::crossing(hhid = hh_all, prods) %>%
    left_join(out, by = c("hhid", "product", "std", "track")) %>%
    mutate(consumed = ifelse(is.na(consumed), 0, consumed),
           unconv   = ifelse(is.na(unconv), 0L, unconv))

  ## elenco dei membri: dimensione e composizione (tutti i membri elencati,
  ## come in Tanzania)
  r  <- rd_mw(C, "hh_mod_b")
  sx <- tolower(trimws(as.character(haven::as_factor(r$hh_b03))))
  dem <- r %>% mutate(hhid = trimws(as.character(case_id)), .age = num(hh_b05a),
                      .fem = as.numeric(sx == "female"), .head = num(hh_b04) %in% 1) %>%
    group_by(hhid) %>%
    summarise(n_mem         = n(),
              share_child   = mean(.age <  15, na.rm=TRUE),
              share_elderly = mean(.age >= 60, na.rm=TRUE),
              head_age      = .age[.head][1],             # un solo capofamiglia: il primo elencato
              head_female   = .fem[.head][1], .groups="drop") %>%
    mutate(across(c(share_child, share_elderly), ~ ifelse(is.nan(.x), NA_real_, .x)))

  ## benessere (TRAP M4): consumo reale annuo per persona
  a <- rd_mw(C, C$agg) %>% mutate(hhid = trimws(as.character(case_id))) %>%
    distinct(hhid, .keep_all = TRUE)
  a <- a %>% transmute(hhid, rexp = num(rexpagg),
                       hhsize = if ("hhsize" %in% names(a)) num(hhsize) else NA_real_)

  ## le variabili dei membri per ogni famiglia, con o senza aggregato
  out %>% left_join(dem, by = "hhid") %>% left_join(a, by = "hhid") %>%
    mutate(hhsize  = ifelse(is.na(hhsize) & !is.na(rexp), n_mem, hhsize),
           welfare = rexp / hhsize, adulteq = hhsize) %>%
    select(-rexp, -n_mem) %>%
    left_join(cv %>% select(-region3), by = "hhid") %>%
    mutate(country = "MWI", wave = w, year = C$year, strataid = NA_character_,
           uv = ifelse(purch_std > 0 & exp_conv > 0, exp_conv / purch_std, NA_real_))
}

## Tutte le wave impilate, poi spese e quantita' estreme (M18, M17), poi su disco.
panel_MW <- map_dfr(names(WAVES_MW), build_wave_mw)
panel_MW <- flag_extreme_values(panel_MW)   # v24: regole M17 e M18 (PARTE 1)
write.csv(panel_MW, file.path(OUT_DIR, "panel_MWI.csv"), row.names=FALSE)

###############################################################################
## CONTROLLI (GATE), da leggere nella console: famiglie contro l'aggregato,
## acquisti mediani, valori unitari che seguono l'inflazione, partecipazione,
## acquisti non convertibili, presenza di pesi, cluster e benessere.
###############################################################################
cat("\n===== MWI GATE 1: households in the food module vs the consumption aggregate =====\n")
for (w in names(WAVES_MW)) {
  C <- WAVES_MW[[w]]
  n_agg <- nrow(rd_mw(C, C$agg))
  p <- panel_MW %>% filter(wave == w) %>% distinct(hhid, welfare)
  cat(sprintf("   %s %d: food module %6d  aggregate %6d  with welfare %6d\n",
              w, C$year, nrow(p), n_agg, sum(!is.na(p$welfare))))
}
cat("\n===== MWI GATE 2: median weekly purchase among buyers =====\n")
print(panel_MW %>% filter(track=="B", purch_std > 0) %>% group_by(product, std, year) %>%
        summarise(m = round(median(purch_std), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== MWI GATE 3: median unit value (MK) - must track inflation =====\n")
print(panel_MW %>% filter(track=="B", uv > 0) %>% group_by(product, year) %>%
        summarise(m = round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== MWI GATE 4: % of households buying (spending > 0) =====\n")
print(panel_MW %>% filter(track=="B") %>% group_by(product, year) %>%
        summarise(p = round(100*mean(coalesce(exp, 0) > 0), 1), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())
cat("\n===== MWI GATE 5: purchases whose unit does not convert (share of buyers) =====\n")
print(panel_MW %>% filter(track=="B", coalesce(exp, 0) > 0) %>% group_by(product, year) %>%
        summarise(flagged = round(mean(unconv), 3), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=flagged) %>% as.data.frame())
cat("\n===== MWI GATE 6: weights, clusters, demographics present =====\n")
print(panel_MW %>% distinct(year, hhid, hhweight, clusterid, head_age, welfare) %>% group_by(year) %>%
        summarise(weight = round(mean(!is.na(hhweight)), 3), cluster = round(mean(!is.na(clusterid)), 3),
                  head_age = round(mean(!is.na(head_age)), 3), welfare = round(mean(!is.na(welfare)), 3),
                  .groups="drop") %>% as.data.frame())
cat("\nrows:", nrow(panel_MW), " households:", n_distinct(paste(panel_MW$wave, panel_MW$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_MWI.csv"), "\n")
}
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 5 - NIGERIA: DAI FILE GREZZI AL PANNELLO
##            (GHS-Panel, wave 2010, 2012, 2015; il 2018 e' escluso, vedi sotto)
##
##  COSA FA   Consumi alimentari della visita post-raccolto, quantita' in kg con
##            le tabelle di conversione dell'indagine, benessere per persona,
##            pesi, zona, cluster. Scrive OUTPUT/panel_NGA.csv.
##  PERCHE'   La Nigeria allarga l'asse del reddito: il paese piu' ricco dei
##            cinque. E' il motivo per cui e' stata aggiunta.
##
##  TRAP N1  DUE VISITE per wave: dopo la semina e dopo il raccolto, ognuna con
##           un modulo alimentare completo. Si usa solo quello POST-RACCOLTO,
##           per confrontabilita' con gli altri paesi.
##  TRAP N2  LA DOMANDA SULLA SPESA CAMBIA tra 2015 e 2018. Fino al 2015 chiede
##           quanto si e' speso per la voce negli ultimi 7 GIORNI. Dal 2018 chiede
##           il valore dell'ACQUISTO PIU' RECENTE, con la quantita' acquistata
##           riferita agli ultimi 30 giorni. Quindi la quantita' CONSUMATA (7
##           giorni) e il valore unitario restano confrontabili, la spesa a 7
##           giorni no.
##  TRAP N3  Le colonne delle fonti si spostano. Il 2010 mette l'autoproduzione
##           in q5 e i regali in q6; 2012 e 2015 inseriscono "dagli acquisti" in
##           q5, spostando l'autoproduzione in q6 e i regali in q7.
##  TRAP N4  Il 2023 (wave 5) ESISTE ma non ha aggregato di consumo ne' pesi (la
##           Banca Mondiale li pubblica mesi dopo i microdati). Senza spesa totale
##           non c'e' misura di benessere, quindi la wave 5 e' esclusa.
##           Aggiungerla qui quando esce l'aggregato.
##
##  Conversione: il 2018 ha un fattore per riga (s10bq2_cvn, "Kg/L conversion").
##  2012 e 2015 hanno tabelle di conversione (il 2012 in grammi/centilitri,
##  D12). Il 2010 non ne ha: si convertono solo le unita' metriche; i
##  contenitori che dichiarano una capacita' ("Basin: Small (10 kg)") sono
##  SEGNALATI, mai indovinati (D13).
##
###############################################################################
###############################################################################
if (exists("RUN_NGA") && !RUN_NGA) message("PART 2b skipped") else if (RUN_BUILD) {

WAVES_NG <- list(
  w1 = list(year=2010, zipyr="2010", food="sect10b_harvestw1", pre="s10bq",
            agg="cons_agg_wave1_visit2", welfare="totcons", pc=TRUE,
            weight="hhweight", own="5", gift="6", cvn=FALSE),
  w2 = list(year=2012, zipyr="2012", food="sect10b_harvestw2", pre="s10bq",
            agg="cons_agg_wave2_visit2", welfare="totcons", pc=TRUE,
            weight="hhweight", own="6", gift="7", cvn=FALSE,
            conv="food_conv_w2ph"),
  w3 = list(year=2015, zipyr="2015", food="sect10b_harvestw3", pre="s10bq",
            agg="cons_agg_wave3_visit2", welfare="totcons", pc=TRUE,
            weight="hhweight", own="6", gift="7", cvn=FALSE,
            conv="food_conv_w3")
  ## w4 (2018-19) ESCLUSA dalla v21 (12 nov 2026): la Banca Mondiale non la
  ## distribuisce piu' ("Data Access Not Available") e la copia su Drive non ha
  ## i moduli delle famiglie. E' anche la wave in cui cambia la domanda sulla
  ## spesa (TRAP N2), quindi andrebbe trattata a parte. Per rimetterla, rimettere
  ## questa voce:
  ##   w4 = list(year=2018, zipyr="2018", food="sect10b_harvestw4", pre="s10bq",
  ##             agg="totcons_final", welfare="totcons_pc", pc=TRUE,
  ##             weight="wt_wave4", own="6", gift="7", cvn=TRUE)
)

## i codici delle voci sono STABILI in tutte le wave nigeriane: niente
## corrispondenze da costruire
ITEMS_NG <- tibble::tribble(
  ~item, ~product,
   90,  "beef",
   91,  "goat_sheep",      # montone
   93,  "goat_sheep",      # capra
   92,  "pork",
   80,  "poultry",         # pollo
   82,  "poultry",         # altro pollame domestico
   83,  "eggs",            # uova di allevamento
   84,  "eggs",            # uova locali
  110,  "milk",            # latte fresco - separato, cosi' la Nigeria resta confrontabile
  111,  "milk_processed",  # latte in polvere   } quello che i nigeriani bevono davvero:
  113,  "milk_processed",  # latte in scatola   } il latte fresco e' solo ~6% delle famiglie
  115,  "milk_processed",  # altri prodotti del latte
  100,  "fish", 101, "fish", 102, "fish", 103, "fish",
  ## v24: frutti di mare (105), pesce in scatola (106) e altro pesce (107) entrano
  ## nel pesce; le lumache (104) restano fuori
  105,  "fish", 106, "fish", 107, "fish",
  120,  "coffee"
)   # 112 latte per neonati escluso di proposito: e' un altro mercato
MEAT_NG <- c("beef","goat_sheep","pork","poultry")

rd_ng <- function(yr, stem) {
  p <- find_dta(stem, paste0("NGA_", yr))
  if (is.na(p)) stop("missing ", stem, " for ", yr)
  haven::read_dta(p)
}

## kg per unita', letti dall'etichetta dell'unita' quando l'indagine li dichiara
## (serve solo al 2010, che non ha tabella di conversione)
kg_from_labels <- function(x) {
  lv <- labelled::val_labels(x)
  if (is.null(lv)) return(setNames(numeric(0), character(0)))
  nm <- names(lv); code <- as.numeric(lv)
  kg <- rep(NA_real_, length(code))
  low <- tolower(nm)
  ## v21 (D13): le etichette dei contenitori ("Basin: Small (10 kg)") danno la
  ## capacita' del contenitore, non il peso del contenuto: 40 bacinelle piccole
  ## di pesce diventavano 400 kg e il manzo usciva a 25 naira/kg contro 700. Si
  ## convertono solo le unita' metriche; i contenitori restano non convertiti.
  ## le unita' metriche semplici
  kg[low == "kilograms" | low == "kilogram" | low == "kg"] <- 1
  kg[low == "grams"     | low == "gram"]                   <- 1/1000
  kg[low == "litres"    | low == "litre"]                  <- 1
  kg[low == "mililitre" | low == "millilitre" | low == "ml"] <- 1/1000
  setNames(kg, as.character(code))
}

## Una wave completa: modulo alimentare -> quantita' in kg (tre metodi a seconda
## della wave) -> filtro sul prezzo -> tracce A e B -> griglia completa
## famiglie x prodotti -> benessere e pesi.
build_wave_ng <- function(w) {
  C <- WAVES_NG[[w]]; p <- C$pre
  f <- rd_ng(C$zipyr, C$food)

  need_cols <- c("hhid","item_cd", paste0(p,"1"), paste0(p,"2a"))
  miss <- setdiff(need_cols, names(f))
  if (length(miss)) stop("NGA ", C$year, ": missing ", paste(miss, collapse=", "))

  ## v21 (D1): tutte le famiglie che hanno risposto al modulo alimentare, PRIMA
  ## di tenere solo le righe di alimenti animali. Nel 2010 l'elenco contiene solo
  ## le voci consumate, quindi una famiglia che non ha mangiato alimenti animali
  ## non avrebbe righe dopo il filtro; la griglia deve comunque contenerla, con
  ## zeri (473 famiglie su 4.826 nel 2010).
  hh_geo <- f %>% mutate(hhid = as.character(hhid)) %>%
    select(hhid, any_of(c("zone","state","lga","ea","sector"))) %>%
    distinct(hhid, .keep_all = TRUE)

  ## v21 (D11): "other milk products" e' il codice 114 nel 2010 e 115 dal 2012
  ## (114 diventa formaggio). Usando 115 ovunque si perdeva nel 2010.
  items <- if (w == "w1") ITEMS_NG %>% mutate(item = ifelse(item == 115, 114, item)) else ITEMS_NG
  f <- f %>% mutate(item = num(item_cd), hhid = as.character(hhid)) %>%
    inner_join(items, by="item")

  if (C$cvn) {
    ## 2018: l'indagine da' il fattore riga per riga, e le colonne delle fonti
    ## sono quantita' nella STESSA unita' del totale, quindi condividono il fattore.
    cv <- num(f[[paste0(p,"2_cvn")]])
    f$qty_kg   <- num(f[[paste0(p,"2a")]]) * cv
    f$own_kg   <- num(f[[paste0(p,C$own,"a")]]) * cv
    f$gift_kg  <- num(f[[paste0(p,C$gift,"a")]]) * cv
    ## gli acquisti sono a 30 giorni e hanno il loro fattore; la spesa e' quella
    ## dell'acquisto
    f$purch_kg <- num(f[[paste0(p,"9a")]]) * num(f[[paste0(p,"9_cvn")]])
    f$exp      <- num(f[[paste0(p,"10")]])
    f$recall   <- "purchase_30d"
  } else if (!is.null(C$conv)) {
    ## TRAP N5  2012 e 2015 usano unita' locali (mudu, congo, derica, paint
    ## rubber) le cui etichette non dicono il peso: leggendo le etichette ogni
    ## quantita' risulta mancante. Entrambe le wave hanno una tabella di
    ## conversione per voce x unita': si usa quella.
    cv <- rd_ng(C$zipyr, C$conv)
    key <- if ("nsu_cd" %in% names(cv)) "nsu_cd" else "unit_cd"
    val <- if ("conv" %in% names(cv)) "conv" else "conv_national"
    ## v21 (D12): la tabella del 2012 e' in GRAMMI (g_cl = 1) o CENTILITRI
    ## (g_cl = 0), non in kg: un uovo pesava 50 kg. La tabella 2015 e' gia' in kg.
    div <- if ("g_cl" %in% names(cv)) ifelse(num(cv$g_cl) == 1, 1000, 100) else 1
    cv <- cv %>% mutate(.div = div) %>%
      transmute(.ci = num(item_cd), .cu = num(.data[[key]]),
                .cf = num(.data[[val]]) / .div) %>%
      filter(!is.na(.cf)) %>% group_by(.ci, .cu) %>%
      summarise(.cf = mean(.cf), .groups="drop")
    ## TRAP N7  La tabella 2012 non ha NESSUNA carne: 90, 91, 92, 93, 80 e 82
    ## mancano del tutto, mentre quelle righe sono in chili e grammi, che non
    ## hanno bisogno di tabella. Senza un ripiego metrico, carne e latte
    ## sparivano dal 2012. Codici: 1 kg, 2 g, 3 litro, 4 CENTILITRO.
    metric <- c("1"=1, "2"=0.001, "3"=1, "4"=0.01)
    tokg <- function(qv, uv_) {
      if (!all(c(qv,uv_) %in% names(f))) return(rep(NA_real_, nrow(f)))
      tmp <- tibble(.ci = num(f$item_cd), .cu = num(f[[uv_]]), .q = num(f[[qv]])) %>%
        left_join(cv, by=c(".ci",".cu")) %>%
        mutate(.cf = ifelse(is.na(.cf), unname(metric[as.character(.cu)]), .cf))
      tmp$.q * tmp$.cf
    }
    f$qty_kg   <- tokg(paste0(p,"2a"), paste0(p,"2b"))
    f$purch_kg <- tokg(paste0(p,"3a"), paste0(p,"3b"))
    f$own_kg   <- tokg(paste0(p,C$own,"a"),  paste0(p,C$own,"b"))
    f$gift_kg  <- tokg(paste0(p,C$gift,"a"), paste0(p,C$gift,"b"))
    f$exp      <- num(f[[paste0(p,"4")]])
    f$recall   <- "spend_7d"
  } else {
    kgmap <- kg_from_labels(f[[paste0(p,"2b")]])
    tokg <- function(qv, uv_) {
      if (!all(c(qv,uv_) %in% names(f))) return(rep(NA_real_, nrow(f)))
      num(f[[qv]]) * unname(kgmap[as.character(num(f[[uv_]]))])
    }
    f$qty_kg   <- tokg(paste0(p,"2a"), paste0(p,"2b"))
    f$purch_kg <- tokg(paste0(p,"3a"), paste0(p,"3b"))
    f$own_kg   <- tokg(paste0(p,C$own,"a"),  paste0(p,C$own,"b"))
    f$gift_kg  <- tokg(paste0(p,C$gift,"a"), paste0(p,C$gift,"b"))
    f$exp      <- num(f[[paste0(p,"4")]])
    f$recall   <- "spend_7d"
  }
  f$consumed <- as.numeric(num(f[[paste0(p,"1")]]) == 1)
  ## unita' di ogni fonte (2018: autoproduzione e regali sono nell'unita' del totale)
  ucol <- function(k) { cn <- paste0(p, k, "b")
    if (cn %in% names(f)) num(f[[cn]]) else rep(NA_real_, nrow(f)) }
  U <- if (C$cvn) list(purch = ucol("9"), qty = ucol("2"), own = ucol("2"), gift = ucol("2")) else
       list(purch = ucol("3"), qty = ucol("2"), own = ucol(C$own), gift = ucol(C$gift))

  geo <- intersect(c("zone","state","lga","ea","sector"), names(f))
  f <- f %>% select(hhid, product, consumed, qty_kg, purch_kg, own_kg, gift_kg,
                    exp, recall, all_of(geo))
  ## v24 (M17): un acquisto con prezzo oltre 10 volte / sotto un decimo della
  ## mediana perde la quantita' (come in Uganda e Malawi). Qui ogni fonte ha la
  ## sua unita', quindi le altre fonti seguono solo se registrate nell'unita'
  ## dell'acquisto (funzioni nella PARTE 1)
  p0 <- f$purch_kg
  f <- flag_price_outliers(f, all_sources = FALSE, sfx = "kg")
  f <- follow_purchase_unit(f, p0, U, sfx = "kg")

  ## somma per famiglia x prodotto, con la spesa abbinata exp_conv (come in Etiopia)
  agg_by <- function(df, col) {
    df %>%
      ## v21: un acquisto di 0 unita' con spesa non e' convertibile
      mutate(.unconv   = as.integer(exp > 0 & (is.na(purch_kg) | purch_kg <= 0)),
             .exp_conv = ifelse(is.na(purch_kg) | purch_kg <= 0, NA_real_, exp)) %>%
      group_by(hhid, product = .data[[col]], recall,
               across(all_of(geo))) %>%
      summarise(consumed = suppressWarnings(max(consumed, na.rm=TRUE)),
                qty_kg   = sum(qty_kg,   na.rm=TRUE),
                purch_kg = sum(purch_kg, na.rm=TRUE),
                own_kg   = sum(own_kg,   na.rm=TRUE),
                gift_kg  = sum(gift_kg,  na.rm=TRUE),
                exp      = sum(exp,       na.rm=TRUE),
                exp_conv = sum(.exp_conv, na.rm=TRUE),
                unconv   = as.integer(any(.unconv == 1, na.rm=TRUE)),
                .groups="drop") %>%
      mutate(consumed = ifelse(is.finite(consumed), consumed, NA_real_),
             across(c(qty_kg, purch_kg, own_kg, gift_kg, exp, exp_conv),
                    ~ ifelse(.x == 0, NA_real_, .x)))
  }
  B <- agg_by(f, "product") %>% mutate(track = "B")
  A <- f %>% mutate(prodA = ifelse(product %in% MEAT_NG, "meat_agg", product)) %>%
    ## v24: il pesce c'e' in tutte le wave, quindi entra anche nella traccia A
    agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)

  ## TRAP N6  Nel 2010 l'elenco contiene SOLO le voci consumate (14,7 righe per
  ## famiglia contro 104-110 nelle altre wave): una famiglia che non consuma non
  ## ha righe, e la partecipazione risulta circa 97%. Qui si completa la griglia
  ## - ogni combinazione famiglia x prodotto esiste, con zero dove la famiglia
  ## non ha consumato - cosi' la partecipazione vuol dire la stessa cosa in
  ## Nigeria e negli altri paesi.
  grid <- tidyr::crossing(hhid = hh_geo$hhid,
                          tidyr::nesting(product = out$product, track = out$track,
                                         recall = out$recall) %>% distinct())
  geo1 <- hh_geo %>% select(hhid, all_of(geo))
  out <- grid %>% left_join(out, by=c("hhid","product","track","recall")) %>%
    select(-any_of(geo)) %>% left_join(geo1, by="hhid") %>%
    mutate(consumed = ifelse(is.na(consumed), 0, consumed),
           unconv   = ifelse(is.na(unconv), 0L, unconv))

  ## benessere
  a <- rd_ng(C$zipyr, C$agg) %>% mutate(hhid = as.character(hhid))
  keep <- intersect(c("hhsize", C$welfare, C$weight), names(a))
  a <- a %>% select(hhid, all_of(keep))
  names(a)[names(a) == C$welfare] <- "welfare_raw"
  names(a)[names(a) == C$weight]  <- "hhweight"
  if (!"hhweight" %in% names(a)) a$hhweight <- NA_real_
  a <- a %>% distinct(hhid, .keep_all=TRUE) %>%
    ## v21 (D2): totcons e' GIA' per persona nel 2010-2015 (etichetta: "Total
    ## consumption per capita"); la v20 lo divideva una seconda volta per hhsize.
    mutate(welfare = if (C$pc) num(welfare_raw)
                     else num(welfare_raw) / pmax(num(hhsize), 1)) %>%
    select(-welfare_raw)

  out %>% left_join(a, by="hhid") %>%
    mutate(country="NGA", wave=w, year=C$year,
           adulteq = pmax(num(hhsize), 1),   # la Nigeria non ha la scala di adulti equivalenti
           std = "kg",
           uv = ifelse(purch_kg > 0 & exp_conv > 0, exp_conv / purch_kg, NA_real_),
           region = as.character(zone),
           ## v21: i numeri di EA si ripetono fra LGA diverse (21-29 identificativi
           ## erano in due LGA), quindi il cluster e' stato_lga_ea
           clusterid = paste0(as.character(state), "_", as.character(lga), "_", as.character(ea)),
           urban = as.character(sector),
           across(c(hhid, region, urban, clusterid), as.character))
}

## v22: zona/stato/lga/settore hanno etichette Stata diverse fra le wave;
## impilarle dava 8 avvisi. Si usano solo i codici.
## Poi spese e quantita' estreme (M18, M17) e il pannello si scrive su disco.
panel_NG <- map_dfr(names(WAVES_NG), ~ zap_labels(build_wave_ng(.x)))
panel_NG <- flag_extreme_values(panel_NG, "kg")   # v24: regole M17 e M18 (PARTE 1)
write.csv(panel_NG, file.path(OUT_DIR, "panel_NGA.csv"), row.names=FALSE)

###############################################################################
## CONTROLLI (GATE), da leggere nella console: famiglie contro l'aggregato, kg
## consumati, valori unitari che seguono l'inflazione, partecipazione (sul
## CONSUMO, non sull'acquisto), unita' non convertibili.
###############################################################################
cat("\n===== NGA GATE 1: households vs the consumption aggregate =====\n")
for (w in names(WAVES_NG)) {
  C <- WAVES_NG[[w]]
  n_agg <- rd_ng(C$zipyr, C$agg) %>% pull(hhid) %>% unique() %>% length()
  n_pan <- panel_NG %>% filter(wave == w) %>% pull(hhid) %>% unique() %>% length()
  cat(sprintf("   %s %d: panel=%5d  aggregate=%5d  %s\n", w, C$year, n_pan, n_agg,
              ifelse(abs(n_pan-n_agg) <= 0.05*n_agg, "OK (within 5%)", "*** CHECK ***")))
}

cat("\n===== NGA GATE 2: median kg consumed in a week (plausible?) =====\n")
print(panel_NG %>% filter(track=="B", qty_kg > 0) %>%
        group_by(product, year) %>% summarise(m=round(median(qty_kg),2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== NGA GATE 3: median unit value (NGN/kg) — must track inflation =====\n")
print(panel_NG %>% filter(track=="B", uv > 0) %>%
        group_by(product, year) %>% summarise(m=round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())

cat("\n===== NGA GATE 4: % of households CONSUMING (not purchasing) =====\n")
cat("   NB: consumption, because 7-day expenditure does not exist after 2015\n")
## TRAP N6  Nel 2010 l'elenco contiene solo le voci consumate, quindi la quota
## di RIGHE con quantita' positiva e' circa 100% per costruzione. La
## partecipazione e' quindi: famiglie che consumano il prodotto / TUTTE le
## famiglie intervistate nella wave.
nhh_ng <- panel_NG %>% distinct(year, hhid) %>% count(year, name="n_hh")
print(panel_NG %>% filter(track=="B", !is.na(qty_kg), qty_kg > 0) %>%
        distinct(year, product, hhid) %>% count(year, product, name="n_cons") %>%
        left_join(nhh_ng, by="year") %>%
        mutate(p = round(100*n_cons/n_hh, 1)) %>%
        select(product, year, p) %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())

cat("\n===== NGA GATE 5: unconvertible units, flagged =====\n")
print(panel_NG %>% filter(track=="B") %>% group_by(year) %>%
        summarise(flagged=round(mean(unconv, na.rm=TRUE),3), .groups="drop") %>%
        as.data.frame())

cat("\nrows:", nrow(panel_NG), " households:", length(unique(panel_NG$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_NGA.csv"), "\n")
###############################################################################
}


###############################################################################
###############################################################################
##
##  PARTE 6 - UGANDA: DAI FILE GREZZI AL PANNELLO
##            (UNPS 2010/11, 2011/12, 2013/14, 2015/16, 2018/19, 2019/20)
##
##  COSA FA   Consumi alimentari di ogni wave, quantita' convertite leggendo
##            l'etichetta dell'unita', benessere annuo per adulto equivalente,
##            pesi, cluster, composizione della famiglia. Scrive
##            OUTPUT/panel_UGA.csv.
##  PERCHE'   L'Uganda e' uno dei cinque paesi del programma ACT dell'UNIDO sul
##            caffe' e ha un panel LSMS-ISA. Il 2009/10 (catalogo 1001) non e'
##            ancora fra gli archivi; aggiungerlo a WAVES_UG quando c'e'.
##  Ogni scelta qui sotto e' stata letta dalle etichette dei valori e dal testo
##  delle domande di ogni wave (13 nov 2026), non supposta.
##
##  TRAP U1  2010-2015 elencano SOLO le voci consumate dalla famiglia (h15bq3a e'
##           "Si'" sul 99,8% delle righe); 2018-2019 elencano tutte le voci per
##           tutte le famiglie con CEB03 = si'/no. La griglia si completa, come
##           per la Nigeria 2010, cosi' una famiglia che non ha mangiato carne
##           conta come zero invece di sparire.
##  TRAP U2  Il 2018 rinomina tutto il modulo (h15bq* -> CEB*) e divide le voci:
##           maiale 118 -> 1181, pollo 121 -> 1211-1214 (ovaiola a fine ciclo,
##           broiler, kroiler, locale), e aggiunge prodotti del latte
##           (1251-1254, 1281).
##  TRAP U3  Il pollo NON e' mai pesato: "Piece-Big/Small" (2010-15) o "Whole
##           chicken big/medium/small" (2018-19), con kg per pochi broiler.
##           L'indagine non da' il peso di un pollo, quindi queste quantita' sono
##           SEGNALATE come non convertibili, mai indovinate (come in Tanzania e
##           Nigeria). La spesa per il pollo conta comunque come acquisto di carne.
##  TRAP U4  Il codice di unita' 54 vuol dire "Packet (unspecified)" nel
##           2010-2015 e "Packet (125g)" nel 2018-2019. Le unita' si convertono
##           quindi dalla loro ETICHETTA in ogni wave, e solo quando l'etichetta
##           dichiara una quantita' metrica ("Packet (500 g)", "Cup/Mug (0.5lt)"
##           per un liquido). La "Nice cup" (60 g / 100 g, nessun volume) vale
##           0,5 l per il latte: costa come la tazza da mezzo litro (Paolo, 13 nov).
##  TRAP U5  Il sesso e' codificato Femmina = 0 / Maschio = 1 nel 2010 e
##           Maschio = 1 / Femmina = 2 dopo. Si legge dall'etichetta.
##  TRAP U6  L'identificativo della famiglia cambia formato tre volte: numeri a
##           10 cifre (2010-2011), "H00101-04-01" (2013), "H00101-05-01" /
##           "H0010101" (2015), chiavi di 32 caratteri (2018-2019). La
##           costruzione tiene l'identificativo di ogni wave; panel_ids()
##           (PARTE 9) li collega.
##  TRAP U7  Gli acquisti sono divisi fra "consumati a casa" e "fuori casa". Solo
##           quelli a casa entrano in acquisti, spesa e valori unitari, come
##           negli altri paesi (dove i pasti fuori casa sono un modulo a parte);
##           il fuori casa e' circa l'1% delle righe di alimenti animali ed entra
##           solo nel totale consumato.
##  TRAP U9  Le quantita' di caffe' non si possono usare: il "Packet (100 g)" si
##           compra a 100-200 UGX, il prezzo di una bustina di caffe' solubile,
##           non di 100 g (un chilo costerebbe 1.000-2.000 UGX nel 2010-13 contro
##           oltre 10.000 nel 2015-19). Il caffe' tiene consumo e spesa; le
##           quantita' sono segnalate come non convertibili. Lo compra solo il
##           2-7% delle famiglie.
##  TRAP U10 Il 2015 non ha l'unita' "vassoio": 25 acquisti di uova su 348 (7%)
##           sono registrati come UN pezzo a 8.000-9.300 UGX, contro una mediana
##           di 350 per uovo: un vassoio da 30. Lasciati cosi', portano
##           l'elasticita' di "qualita'" delle uova del 2015 a 0,29. Si leggono
##           come vassoi (quantita' x 30; due "vassoi" del 2019 al prezzo di un
##           uovo, / 30) - Paolo, 13 nov. Poi, per ogni prodotto: un acquisto
##           ancora oltre 10 volte o sotto un decimo della mediana perde le
##           quantita' (flag_price_outliers(), PARTE 1).
##  TRAP U8  L'aggregato di consumo e' mensile, per adulto equivalente, a prezzi
##           costanti (base 2005/06 fino al 2013, base 2009/10 dal 2015). Si
##           porta su scala annua (x 12); il cambio di base sta negli effetti
##           dell'anno di ogni modello.
##
###############################################################################
###############################################################################
if (exists("RUN_UGA") && !RUN_UGA) message("PART 2c skipped") else
if (!length(list.files(ARCH_ROOT, pattern = "^UGA_", include.dirs = TRUE))) {
  message("PART 2c: no Uganda archives (UGA_*.zip) found - Uganda skipped")
} else if (RUN_BUILD) {

rd_ug <- function(yr, stem) {
  p <- find_dta(stem, paste0("UGA_", yr))
  if (is.na(p)) stop("missing ", stem, " for Uganda ", yr)
  haven::read_dta(p)
}
## gli identificativi sono numeri nel 2010 e testo dopo: R non deve mai
## scriverli come 1e+09
idstr <- function(x) if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x))

WAVES_UG <- list(
  w1 = list(year=2010, yr="2010", style="old", food="GSEC15b", id_food="hh",
            cover="GSEC1", id_cover="HHID", roster="GSEC2", id_roster="HHID",
            agg="pov2010_11", id_agg="hh", weight="wgt10", cluster="comm"),
  w2 = list(year=2011, yr="2011", style="old", food="GSEC15B", id_food="HHID",
            cover="GSEC1", id_cover="HHID", roster="GSEC2", id_roster="HHID",
            agg="UNPS 2011-12 Consumption Aggregate", id_agg="HHID",
            weight="mult", cluster="comm"),
  w3 = list(year=2013, yr="2013", style="old", food="GSEC15B", id_food="hhid",
            cover="GSEC1", id_cover="hhid", roster="GSEC2", id_roster="hhid",
            agg="pov2013_14", id_agg="hhid", weight="wgt_X", cluster="ea"),
  w4 = list(year=2015, yr="2015", style="old", food="gsec15b", id_food="hh",
            cover="gsec1", id_cover="hh", roster="gsec2", id_roster="hh",
            agg="pov2015_16", id_agg="hh", weight="h_xwgt_W5", cluster="ea"),
  ## 2018-2019 non hanno il codice di EA nei file pubblici: il cluster e' la
  ## parrocchia (v23: con la contea, perche' le sottocontee sono numerate
  ## dentro la contea)
  w5 = list(year=2018, yr="2018", style="new", food="GSEC15B", id_food="hhid",
            cover="GSEC1", id_cover="hhid", roster="GSEC2", id_roster="hhid",
            agg="pov2018_19", id_agg="hhid", weight="wgt",
            cluster=c("district_code","county_code","subcounty_code","parish_code")),
  w6 = list(year=2019, yr="2019", style="new", food="gsec15b", id_food="hhid",
            cover="gsec1", id_cover="hhid", roster="gsec2", id_roster="hhid",
            agg="pov2019_20", id_agg="hhid", weight="wgt",
            cluster=c("dc_2018","cc_2018","sc_2018","pc_2018"))
)

## Prodotti. 120 "altra carne" (anatra, coniglio, selvaggina) resta fuori, come
## negli altri paesi; 1174 salsicce, 1251 latte in polvere, 1253 gelato e 1281
## formaggio esistono solo nel 2018-19 e hanno 1-12 consumatori ciascuno.
ITEMS_UG <- tibble::tribble(
  ~item, ~product,         ~std,
   117,  "beef",           "kg",
   118,  "pork",           "kg",
  1181,  "pork",           "kg",
   119,  "goat_sheep",     "kg",     # etichetta "Goat meat": non esiste una voce per il montone
   121,  "poultry",        "kg",
  1211,  "poultry",        "kg",
  1212,  "poultry",        "kg",
  1213,  "poultry",        "kg",
  1214,  "poultry",        "kg",
   124,  "eggs",           "piece",
   125,  "milk",           "litre",
  1252,  "milk_processed", "litre",  # latte fermentato (bongo), solo 2018-19
  1254,  "milk_processed", "litre",  # yogurt, solo 2018-19
   148,  "coffee",         "kg",
   ## v24 (Paolo, 15 nov 2026): il pesce torna, come prodotto a se'. 122
   ## fresco, 123 secco/affumicato (2010-15); 2018-19 diviso per specie: 1221
   ## tilapia fresca, 1222 persico del Nilo fresco, 1231 tilapia secca/
   ## affumicata, 1232 persico del Nilo secco/affumicato, 1235 altro fresco,
   ## 1236 altro secco/affumicato, 1237 pesciolino argentato (mukene).
   ## TRAP U11: il pesce si compra intero (piccolo/medio/grande), a mucchi, a
   ## mazzi e a tazze; solo i chili e la famiglia "Nice cup (100 g)" dichiarano
   ## un peso, il 3-27% degli acquisti. Come il pollo, il pesce conta per
   ## acquisto e spesa; le sue quantita' sono troppo poche e troppo selezionate
   ## per i valori unitari (MIN_UV_SHARE: serve meta' degli acquirenti).
   122,  "fish",           "kg",
   123,  "fish",           "kg",
  1221,  "fish",           "kg",
  1222,  "fish",           "kg",
  1231,  "fish",           "kg",
  1232,  "fish",           "kg",
  1235,  "fish",           "kg",
  1236,  "fish",           "kg",
  1237,  "fish",           "kg",
  ## v24 (controllo del 20 nov): 1234 nkejje secco, un piccolo pesce di lago,
  ## mancava
  1234,  "fish",           "kg"
)
MEAT_UG <- c("beef","goat_sheep","pork","poultry")

## moltiplicatore dall'ETICHETTA dell'unita' all'unita' standard del prodotto
## (TRAP U4)
conv_ug <- function(lab, std) {
  l <- tolower(gsub("\\s+", " ", trimws(lab)))
  g <- suppressWarnings(as.numeric(sub("^(packet|sacket|nido tin) ?\\(([0-9.]+) ?g\\).*$", "\\2", l)))
  lt <- suppressWarnings(as.numeric(sub("^.*\\(([0-9.]+) ?lt\\).*$", "\\1", l)))
  ## v24 (controllo del 20 nov): ogni etichetta che dichiara i grammi - "Nice
  ## cup(100g)", "Metallic plate(80g)", "Nido Tin(400g)" - si converte, solo
  ## per i solidi
  ncg <- suppressWarnings(as.numeric(sub("^.*\\(([0-9.]+) ?g\\).*$", "\\1", l)))
  dplyr::case_when(
    is.na(l)                                                ~ NA_real_,
    std == "piece" & grepl("^tray of 30", l)                ~ 30,
    std == "piece" & grepl("^(number of units|piece)", l)   ~ 1,
    std %in% c("kg","litre") & grepl("^kilogram", l)        ~ 1,   # latte: kg = litro
    std %in% c("kg","litre") & grepl("^gram", l)            ~ 1/1000,
    std %in% c("kg","litre") & grepl("^packet ?\\(1 ?kg\\)", l) ~ 1,
    std %in% c("kg","litre") & !is.na(g)                    ~ g / 1000,
    ## v24: "Nice cup(100g)- Large" ecc. dichiarano un peso; vale solo per i
    ## solidi (pesciolino essiccato), mai per il latte (regola dei 0,5 l sotto)
    std == "kg" & !is.na(ncg)                               ~ ncg / 1000,
    std == "litre" & grepl("^litre", l)                     ~ 1,
    std == "litre" & !is.na(lt)                             ~ lt,  # tazza 0,5 l, bicchiere 0,25 l
    ## v23 (deciso da Paolo, 13 nov): la "Nice cup" costa come la tazza da mezzo
    ## litro e vale mezzo litro, in ogni wave
    std == "litre" & grepl("^nice cup", l)                  ~ 0.5,
    TRUE ~ NA_real_)
}

## Una wave completa: modulo alimentare -> quantita' dall'etichetta dell'unita'
## -> filtro sul prezzo -> tracce A e B -> griglia completa famiglie x prodotti
## -> benessere, membri, geografia, cluster e peso.
build_wave_ug <- function(w) {
  C <- WAVES_UG[[w]]
  f <- rd_ug(C$yr, C$food)
  v <- if (C$style == "old")
         list(item="itmcd", unit="untcd", yn="h15bq3a", q_pur="h15bq4", spend="h15bq5",
              q_away="h15bq6", q_own="h15bq8", q_gif="h15bq10")
       else
         list(item="CEB01", unit="CEB03C", yn="CEB03", q_pur="CEB06", spend="CEB07",
              q_away="CEB08", q_own="CEB10", q_gif="CEB012")
  miss <- setdiff(c(unlist(v), C$id_food), names(f))
  if (length(miss)) stop("Uganda ", C$year, ": missing column(s) in ", C$food, ": ",
                         paste(miss, collapse=", "))

  ulab <- labelled::val_labels(f[[v$unit]])
  f <- f %>%
    mutate(hhid = idstr(.data[[C$id_food]]), item = num(.data[[v$item]]),
           .ulab = names(ulab)[match(num(.data[[v$unit]]), ulab)])
  hh_all <- unique(f$hhid)                  # tutte le famiglie del modulo alimentare
  f <- f %>% inner_join(ITEMS_UG, by = "item") %>%
    mutate(.k = conv_ug(.ulab, std),
           .k = ifelse(product == "coffee", NA_real_, .k))      # TRAP U9

  q <- function(x) num(f[[x]])
  f$purch_std <- q(v$q_pur) * f$.k
  f$own_std   <- q(v$q_own) * f$.k
  f$gift_std  <- q(v$q_gif) * f$.k
  ## totale consumato = le quattro fonti (= h15bq14 sul 99,8-100% delle righe
  ## 2010-15)
  f$qty_std   <- rowSums(cbind(q(v$q_pur), q(v$q_away), q(v$q_own), q(v$q_gif)),
                         na.rm = TRUE) * f$.k
  f$qty_std[f$qty_std == 0] <- NA
  f$exp       <- q(v$spend)
  ## v23: sei righe del 2013 dicono "non consumato" accanto a un acquisto; un
  ## acquisto, un'autoproduzione o un regalo vogliono dire che e' consumato
  f$consumed  <- as.numeric(num(f[[v$yn]]) == 1 |
                            rowSums(cbind(q(v$q_pur), q(v$q_away), q(v$q_own), q(v$q_gif), f$exp) > 0,
                                    na.rm = TRUE) > 0)
  ## TRAP U10: un acquisto con prezzo oltre 10 volte, o sotto un decimo, della
  ## mediana della wave per il prodotto e' un errore di unita' (un vassoio
  ## registrato come un uovo); le sue quantita' si svuotano. Qui c'e' una sola
  ## unita' per tutte le fonti, quindi si toccano tutte e quattro.
  f <- flag_price_outliers(f)
  f <- f %>% select(hhid, product, std, consumed, qty_std, purch_std, own_std, gift_std, exp)

  ## somma per famiglia x prodotto, con la spesa abbinata exp_conv (come in Etiopia)
  agg_by <- function(df, prod_col) {
    df %>%
      mutate(.unconv   = as.integer(exp > 0 & (is.na(purch_std) | purch_std <= 0)),
             .exp_conv = ifelse(is.na(purch_std) | purch_std <= 0, NA_real_, exp)) %>%
      group_by(hhid, product = .data[[prod_col]], std) %>%
      summarise(consumed  = suppressWarnings(max(consumed, na.rm=TRUE)),
                qty_std   = sum(qty_std,   na.rm=TRUE),
                purch_std = sum(purch_std, na.rm=TRUE),
                own_std   = sum(own_std,   na.rm=TRUE),
                gift_std  = sum(gift_std,  na.rm=TRUE),
                exp       = sum(exp,       na.rm=TRUE),
                exp_conv  = sum(.exp_conv, na.rm=TRUE),
                unconv    = as.integer(any(.unconv == 1, na.rm=TRUE)),
                .groups="drop") %>%
      mutate(consumed = ifelse(is.finite(consumed), consumed, NA_real_),
             across(c(qty_std, purch_std, own_std, gift_std, exp, exp_conv),
                    ~ ifelse(.x == 0, NA_real_, .x)))
  }
  B <- agg_by(f, "product") %>% mutate(track = "B")
  A <- f %>% mutate(prodA = ifelse(product %in% MEAT_UG, "meat_agg", product)) %>%
    filter(prodA != "milk_processed") %>% agg_by("prodA") %>% mutate(track = "A")
  out <- bind_rows(A, B)

  ## TRAP U1: ogni famiglia x prodotto, zero dove non si e' consumato niente
  ## (milk_processed solo dove era chiesto: 2018-19)
  prods <- bind_rows(
    ITEMS_UG %>% distinct(product, std) %>% mutate(track = "B"),
    ITEMS_UG %>% mutate(product = ifelse(product %in% MEAT_UG, "meat_agg", product)) %>%
      filter(product != "milk_processed") %>% distinct(product, std) %>% mutate(track = "A"))
  out <- tidyr::crossing(hhid = hh_all, prods) %>%
    left_join(out, by = c("hhid", "product", "std", "track")) %>%
    filter(!(product == "milk_processed" & C$style == "old")) %>%
    mutate(consumed = ifelse(is.na(consumed), 0, consumed),
           unconv   = ifelse(is.na(unconv), 0L, unconv))

  ## benessere, dimensione della famiglia, adulti equivalenti
  a <- rd_ug(C$yr, C$agg) %>% mutate(hhid = idstr(.data[[C$id_agg]])) %>%
    distinct(hhid, .keep_all = TRUE)
  a <- a %>% transmute(hhid, welfare = num(welfare) * 12,           # TRAP U8
                       adulteq = num(equiv),
                       hhsize  = if ("hsize" %in% names(a)) num(hsize) else NA_real_)

  ## composizione: solo i membri abituali e regolari (non gli ospiti, ne' chi
  ## e' partito o morto, che sono pure nell'elenco)
  r <- rd_ug(C$yr, C$roster)
  keep <- usual <- rep(TRUE, nrow(r))
  if ("h2q7" %in% names(r)) {
    st <- trimws(tolower(as.character(haven::as_factor(r$h2q7))))
    keep  <- grepl("^(usual|regular) member (present|absent)$", st)
    usual <- grepl("^usual member (present|absent)$", st)    # la hsize dell'aggregato
  }
  sx <- tolower(trimws(as.character(haven::as_factor(r$h2q3))))       # TRAP U5
  ## quote di eta' sui membri di eta' nota; UN capofamiglia per famiglia (v23:
  ## una famiglia del 2013 ne elenca due - si tiene il primo dell'elenco)
  dem <- r %>% mutate(hhid = idstr(.data[[C$id_roster]]), .age = num(h2q8),
                      .fem = as.numeric(sx == "female"), .head = num(h2q4) %in% 1,
                      .usual = usual) %>%
    filter(keep) %>% group_by(hhid) %>%
    summarise(n_usual       = sum(.usual),
              share_child   = mean(.age <  15, na.rm=TRUE),
              share_elderly = mean(.age >= 60, na.rm=TRUE),
              head_age      = .age[.head][1],
              head_female   = .fem[.head][1], .groups="drop") %>%
    mutate(across(c(share_child, share_elderly), ~ ifelse(is.nan(.x), NA_real_, .x)))
  ## v23: dove l'aggregato non ha la dimensione della famiglia (2011) = i membri
  ## abituali, come li conta hsize dell'aggregato

  ## geografia, cluster e peso dalla copertina
  cv <- rd_ug(C$yr, C$cover)
  lab_of <- function(x) tolower(trimws(as.character(haven::as_factor(x))))
  cl  <- lapply(C$cluster, function(k) idstr(cv[[k]]))
  cv$.cl <- ifelse(Reduce(`|`, lapply(cl, function(x) is.na(x) | x %in% c("", "NA"))), NA,
                   do.call(paste, c(cl, sep = "_")))
  cv <- cv %>% transmute(
    hhid      = idstr(.data[[C$id_cover]]),
    ## v23: Kampala e' la regione 0 solo nel 2010; altrove sta dentro la Centrale
    region    = as.character(ifelse(num(region) == 0, 1, num(region))),
    urban     = ifelse(lab_of(urban) == "urban", "1", "0"),
    clusterid = .cl,
    hhweight  = num(.data[[C$weight]])) %>%
    distinct(hhid, .keep_all = TRUE)

  out %>% left_join(a, by = "hhid") %>% left_join(dem, by = "hhid") %>%
    mutate(hhsize = ifelse(is.na(hhsize) & n_usual > 0, n_usual, hhsize)) %>% select(-n_usual) %>%
    left_join(cv, by = "hhid") %>%
    mutate(country = "UGA", wave = w, year = C$year, strataid = NA_character_,
           uv = ifelse(purch_std > 0 & exp_conv > 0, exp_conv / purch_std, NA_real_))
}

## Tutte le wave impilate, poi spese e quantita' estreme (M18, M17), poi su disco.
panel_UG <- map_dfr(names(WAVES_UG), build_wave_ug)
panel_UG <- flag_extreme_values(panel_UG)   # v24: regole M17 e M18 (PARTE 1)
write.csv(panel_UG, file.path(OUT_DIR, "panel_UGA.csv"), row.names=FALSE)

###############################################################################
## CONTROLLI (GATE), da leggere nella console: famiglie contro l'aggregato,
## acquisti mediani, valori unitari che seguono l'inflazione, partecipazione,
## acquisti non convertibili, presenza di pesi, cluster e benessere.
###############################################################################
cat("\n===== UGA GATE 1: households in the food module vs the consumption aggregate =====\n")
for (w in names(WAVES_UG)) {
  C <- WAVES_UG[[w]]
  n_agg <- rd_ug(C$yr, C$agg) %>% pull(!!C$id_agg) %>% idstr() %>% unique() %>% length()
  p <- panel_UG %>% filter(wave == w) %>% distinct(hhid, welfare)
  cat(sprintf("   %s %d: food module %5d  aggregate %5d  with welfare %5d\n",
              w, C$year, nrow(p), n_agg, sum(!is.na(p$welfare))))
}
cat("\n===== UGA GATE 2: median weekly purchase among buyers =====\n")
print(panel_UG %>% filter(track=="B", purch_std > 0) %>% group_by(product, std, year) %>%
        summarise(m = round(median(purch_std), 2), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== UGA GATE 3: median unit value (UGX) - must track inflation =====\n")
print(panel_UG %>% filter(track=="B", uv > 0) %>% group_by(product, year) %>%
        summarise(m = round(median(uv)), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=m) %>% as.data.frame())
cat("\n===== UGA GATE 4: % of households buying (spending > 0) =====\n")
print(panel_UG %>% filter(track=="B") %>% group_by(product, year) %>%
        summarise(p = round(100*mean(coalesce(exp, 0) > 0), 1), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=p) %>% as.data.frame())
cat("\n===== UGA GATE 5: purchases whose unit does not convert (share of buyers) =====\n")
print(panel_UG %>% filter(track=="B", coalesce(exp, 0) > 0) %>% group_by(product, year) %>%
        summarise(flagged = round(mean(unconv), 3), .groups="drop") %>%
        pivot_wider(names_from=year, values_from=flagged) %>% as.data.frame())
cat("\n===== UGA GATE 6: weights, clusters, demographics present =====\n")
print(panel_UG %>% distinct(year, hhid, hhweight, clusterid, head_age, welfare) %>% group_by(year) %>%
        summarise(weight = round(mean(!is.na(hhweight)), 3), cluster = round(mean(!is.na(clusterid)), 3),
                  head_age = round(mean(!is.na(head_age)), 3), welfare = round(mean(!is.na(welfare)), 3),
                  .groups="drop") %>% as.data.frame())
cat("\nrows:", nrow(panel_UG), " households:", n_distinct(paste(panel_UG$wave, panel_UG$hhid)), "\n")
cat("written ->", file.path(OUT_DIR, "panel_UGA.csv"), "\n")
}
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 7 - LE STIME PRINCIPALI: QUANTITA' CONTRO QUALITA' (DEATON 1988)
##
##  DOMANDA   Quando il reddito cresce, la famiglia spende di piu' per la carne
##            perche' ne compra DI PIU' (quantita') o perche' la compra MIGLIORE
##            e piu' cara (qualita')?
##  IDEA      La spesa e' quantita' x valore unitario, dove il valore unitario e'
##            spesa / kg. In logaritmi: log(spesa) = log(kg) + log(valore
##            unitario). Quindi l'elasticita' della spesa al reddito si divide
##            esattamente in due pezzi:
##              elasticita' della spesa = elasticita' della quantita'
##                                      + elasticita' della qualita'
##            dove la "qualita'" e' quanto il valore unitario sale col reddito:
##            a parita' di prezzi, chi paga di piu' al kg compra tagli migliori,
##            prodotti piu' lavorati o confezionati.
##  COME      Per ogni paese x anno x prodotto, fra chi ha comprato (con un
##            valore unitario):
##              log(valore unitario) = b_qual  * log(benessere) + controlli
##              log(kg acquistati)   = b_quant * log(benessere) + controlli
##            minimi quadrati pesati con i pesi dell'indagine, effetti fissi di
##            regione, controlli: dimensione della famiglia (adulti equivalenti),
##            urbano, e dove ci sono quota di bambini, di anziani, eta' e sesso
##            del capofamiglia. Valori unitari tagliati all'1% e al 99%.
##            quality_share = b_qual / (b_qual + b_quant).
##  INOLTRE   - partecipazione: % di famiglie che comprano;
##            - saturazione: un termine al quadrato nel reddito (se negativo e
##              significativo la quantita' smette di crescere: "plateau");
##            - elasticita' di prezzo con un prezzo che la famiglia non sceglie:
##              il prezzo del mercato del villaggio (Etiopia) o la media dei
##              valori unitari delle ALTRE famiglie dello stesso cluster.
##  USA       Traccia A (confrontabile in tutte le wave). Legge i pannelli scritti
##            dalle PARTI 2-6. Tabelle XXX_01 e XXX_02 del workbook.
##
###############################################################################
###############################################################################
## nomi dei prodotti nelle figure
LABEL <- c(meat_agg="Meat", beef="Beef", goat_sheep="Goat & sheep", pork="Pork",
           poultry="Poultry", eggs="Eggs", milk="Fresh milk",
           milk_processed="Milk (powder/tinned)", cheese="Cheese",
           coffee="Coffee", fish="Fish")
## stile comune delle figure
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), panel.grid.minor=element_blank(),
        strip.text=element_text(face="bold"))

###############################################################################
## prep(): mette le colonne dei cinque paesi sotto gli stessi nomi.
##  I pannelli usano nomi diversi per la stessa cosa, ad esempio:
##   ETH: purch_kg,  exp_conv, nom_totcons_aeq, weight,   region, ea_id
##   TZA: purch_std, exp_conv, welfare,         hhweight, region, clusterid
##  pick() prende la prima colonna che esiste. Poi:
##   qty     = quantita' ACQUISTATA (kg, litri o pezzi);
##   l_x     = log(benessere): la misura di reddito delle regressioni;
##   l_ae    = log(adulti equivalenti), cioe' la dimensione della famiglia;
##   weight  = peso campionario (1 se manca);
##   urban   = 1 se la famiglia vive in area urbana.
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
CTRL <- "l_ae + urban"          # esteso sotto se ci sono le variabili demografiche

###############################################################################
## Prezzo esogeno per le elasticita' di prezzo: il valore unitario MEDIO delle
## ALTRE famiglie dello stesso cluster (almeno 4) nello stesso anno. Togliendo
## la famiglia stessa ("leave-one-out") si toglie dal prezzo la sua scelta di
## qualita'. In Etiopia, dove c'e', si usa il prezzo del mercato del villaggio.
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

## fit_cell(): la decomposizione per UNA cella (paese x anno x prodotto).
## Restituisce acquirenti usati, partecipazione, elasticita' di qualita' e di
## quantita' con errori standard e p-value, la loro somma (elasticita' della
## spesa), la quota della qualita' e il test di saturazione.
## v24: MIN_UV_SHARE (PARTE 1) - per il pesce i valori unitari devono coprire
## almeno meta' degli acquirenti, altrimenti la cella resta vuota.
fit_cell <- function(g, ctrl, prod = NA_character_) {
  b <- g %>% filter(uv > 0, qty > 0, welfare > 0, unconv == 0)
  if (nrow(b) > 100) { q <- quantile(b$uv, c(.01,.99), na.rm=TRUE)
                       b <- b %>% filter(uv >= q[1], uv <= q[2]) }
  if (nrow(b) < 80) return(tibble())
  if (!is.na(prod) && prod %in% names(MIN_UV_SHARE)) {
    nb <- sum(dplyr::coalesce(g$qty > 0, FALSE) | dplyr::coalesce(g$exp > 0, FALSE), na.rm = TRUE)
    if (nrow(b) < MIN_UV_SHARE[[prod]] * nb) return(tibble())
  }
  fq <- as.formula(paste("log(uv)  ~ l_x +", ctrl, "| region"))
  fn <- as.formula(paste("log(qty) ~ l_x +", ctrl, "| region"))
  ## v21 (D7): quadrato esplicito; fixest >= 0.14 rinomina I(l_x^2) in I(I(l_x^2))
  b$l_x2 <- b$l_x^2
  fs <- as.formula(paste("log(qty) ~ l_x + l_x2 +", ctrl, "| region"))
  M <- function(f) try(feols(f, data=b, weights=~weight, vcov="hetero"), silent=TRUE)
  gv <- function(m,k) if (inherits(m,"try-error") || !(k %in% names(coef(m)))) c(NA,NA,NA)
                      else c(coef(m)[k], se(m)[k], pvalue(m)[k])
  a <- gv(M(fq),"l_x"); n <- gv(M(fn),"l_x"); s <- gv(M(fs),"l_x2")
  full <- g %>% filter(welfare > 0) %>%
    ## v21 (D14): compra = ha speso qualcosa o ha comprato una quantita' convertibile
    mutate(buys = as.integer(dplyr::coalesce(qty > 0, FALSE) | dplyr::coalesce(exp > 0, FALSE)))
  tibble(n_buyers=nrow(b), participation=round(100*mean(full$buys),1),
         e_quality=a[1], se_quality=a[2], p_quality=a[3],
         e_quantity=n[1], se_quantity=n[2], p_quantity=n[3],
         e_expenditure=a[1]+n[1], quality_share=a[1]/(a[1]+n[1]),
         sat_b2=s[1], sat_p=s[3],
         plateau = !is.na(s[1]) && s[1] < 0 && !is.na(s[3]) && s[3] < .10)
}

## fit_price(): elasticita' della quantita' al prezzo esogeno (sopra), con
## errori standard per cluster. Servono almeno 120 acquirenti in 20 cluster.
fit_price <- function(g, ctrl, prod = NA_character_) {
  b <- g %>% filter(qty > 0, welfare > 0, price_exo > 0, unconv == 0)
  if (nrow(b) < 120 || n_distinct(b$cluster) < 20) return(tibble())
  if (!is.na(prod) && prod %in% names(MIN_UV_SHARE) &&
      nrow(b) < MIN_UV_SHARE[[prod]] * sum(dplyr::coalesce(g$qty > 0, FALSE) | dplyr::coalesce(g$exp > 0, FALSE), na.rm = TRUE))
    return(tibble())
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
## ESECUZIONE: per ogni paese, legge il pannello, sceglie i controlli, stima
## decomposizione e prezzi per ogni anno x prodotto della traccia A, scrive le
## tabelle e tre figure (decomposizione, quota della qualita', partecipazione).
###############################################################################
panels <- list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)
if (!length(panels)) stop("no panels built")
for (pf in panels) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  d   <- prep(raw)

  ## i controlli demografici si usano solo se il pannello del paese li ha
  ## (per almeno meta' delle righe)
  ctrl <- CTRL
  for (v in c("share_child","share_elderly","head_age","head_female"))
    if (v %in% names(raw) && mean(!is.na(raw[[v]])) > .5) {
      d[[v]] <- as.numeric(raw[[v]]); ctrl <- paste(ctrl, "+", v)
    }
  message("\n==== ", cc, " ====  controls: ", ctrl)

  d <- add_cluster_price(d)
  A <- d %>% filter(track == "A")

  res <- A %>% group_by(year, product) %>% group_modify(~fit_cell(.x, ctrl, .y$product)) %>% ungroup()
  pel <- A %>% group_by(year, product) %>% group_modify(~fit_price(.x, ctrl, .y$product)) %>% ungroup()

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

  ## figure
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


###############################################################################
###############################################################################
##
##  PARTE 8 - CONFRONTO FRA I PAESI
##
##  COSA FA   Mette insieme le decomposizioni dei cinque paesi (PARTE 7): medie
##            sulle wave per carne, latte, uova e caffe', paesi ordinati per PIL
##            pro capite. Poi: la quota della qualita' sale col PIL? qualche
##            paese ha raggiunto la saturazione? quante elasticita' di prezzo
##            hanno il segno sbagliato?
##  ATTENZIONE Con cinque paesi la relazione col PIL e' DESCRITTIVA, non un test:
##            i paesi differiscono anche per questionario, unita' e periodo.
##  USA       Le tabelle temporanee della PARTE 7. Tabelle COMPARE_01, COMPARE_02.
##
###############################################################################
###############################################################################
## legge e impila le tabelle di tutti i paesi con lo stesso suffisso
RES_DIR <- RUN_DIR
read_set <- function(suffix) {
  fs <- list.files(TMPCSV, pattern=paste0("_", suffix, "\\.csv$"), full.names=TRUE)
  if (!length(fs)) return(tibble())
  map_dfr(fs, function(f) {
    d <- read.csv(f, stringsAsFactors=FALSE)
    d$country <- str_match(basename(f), "^([A-Z]{3})_")[,2]
    d
  })
}
dec <- read_set("01_decomposition")
pri <- read_set("02_price_elasticities")
if (!nrow(dec)) stop("nothing to compare")

## PIL pro capite, usato SOLO per ordinare i paesi sull'asse del reddito.
## v21 (M8): PIL pro capite a parita' di potere d'acquisto, dollari
## internazionali costanti 2021 (WDI NY.GDP.PCAP.PP.KD, file
## docs/external/wdi_gdp_pc_ppp.csv), MEDIA SUGLI ANNI DELLE INDAGINI DI OGNI
## PAESE. La v20 aveva valori recenti di un solo anno in dollari correnti
## (1.020 / 1.220 / 1.600), che mettevano la Nigeria appena sopra l'Etiopia.
##   ETH 2011-2021: 1.493 -> 2.588   TZA 2008-2020: 2.493 -> 3.450
##   NGA 2010-2015: 7.963 -> 8.892
## v22: UGA 2010-2019 (anni 2010, 2011, 2013, 2015, 2018, 2019): 2.245 ->
##   2.689, media 2.479. Stessa serie WDI, letta dalla copia di Our World in
##   Data (i suoi valori per la Tanzania coincidono al dollaro con l'estratto WDI).
##   MWI 2010-2024 (anni 2010, 2016, 2019, 2024): 1.504 -> 1.634, media 1.605.
INCOME <- tribble(~country, ~gdp_pc,
                  "MWI",  1605,
                  "ETH",  2009,
                  "UGA",  2479,
                  "TZA",  2890,
                  "NGA",  8374)

## i prodotti presenti in tutti i paesi
CORE  <- c("meat_agg","milk","eggs","coffee")
LABEL <- c(meat_agg="Meat", milk="Fresh milk",
           milk_processed="Milk (powder/tinned)", eggs="Eggs",
           coffee="Coffee", cheese="Cheese")
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), plot.subtitle=element_text(colour="grey35"),
        panel.grid.minor=element_blank(), strip.text=element_text(face="bold"))

###############################################################################
## 1. la tabella di confronto principale (medie sulle wave)
###############################################################################
summ <- dec %>% filter(product %in% CORE, !is.na(e_quantity)) %>%
  group_by(country, product) %>%
  summarise(waves         = n(),
            participation = round(mean(participation, na.rm=TRUE), 1),
            quantity      = round(mean(e_quantity,    na.rm=TRUE), 3),
            quality       = round(mean(e_quality,     na.rm=TRUE), 3),
            expenditure   = round(mean(e_expenditure, na.rm=TRUE), 3),
            quality_share = round(mean(quality_share, na.rm=TRUE), 3),
            .groups="drop") %>%
  left_join(INCOME, by="country") %>% arrange(product, gdp_pc)

write.csv(summ, file.path(TMPCSV, "COMPARE_01_summary.csv"), row.names=FALSE)
cat("\n=========== CROSS-COUNTRY SUMMARY ===========\n")
print(as.data.frame(summ))

###############################################################################
## 2. la quota della qualita' sale con il reddito del paese? (descrittivo)
###############################################################################
cat("\n=========== QUALITY SHARE vs INCOME ===========\n")
qs <- summ %>% filter(!is.na(gdp_pc))
if (n_distinct(qs$country) >= 3) {
  fit <- lm(quality_share ~ log(gdp_pc) + factor(product), data=qs)
  print(summary(fit)$coefficients)
  cat("\nNB: with fewer than ~5 countries this slope is descriptive, not a test.\n")
} else {
  cat("Only", n_distinct(qs$country), "countries so far — no gradient can be fitted.\n")
  print(as.data.frame(qs %>% select(country, gdp_pc, product, quality_share) %>%
                        pivot_wider(names_from=product, values_from=quality_share)))
}

###############################################################################
## 3. saturazione: qualche paese ha raggiunto il plateau?
###############################################################################
cat("\n=========== SATURATION ===========\n")
sat <- dec %>% group_by(country) %>%
  summarise(cells = n(), plateaus = sum(plateau, na.rm=TRUE),
            share = round(mean(plateau, na.rm=TRUE), 3), .groups="drop")
print(as.data.frame(sat))

###############################################################################
## 4. elasticita' di prezzo: quelle col SEGNO SBAGLIATO (positive e
##    significative) restano visibili, non si nascondono
###############################################################################
if (nrow(pri)) {
  cat("\n=========== PRICE ELASTICITIES ===========\n")
  ps <- pri %>% mutate(sig = p < .05,
                       wrong_sign = e_price > 0 & p < .05) %>%
    group_by(country, product) %>%
    summarise(n_est = n(), median_e = round(median(e_price, na.rm=TRUE), 3),
              n_sig = sum(sig, na.rm=TRUE),
              n_wrong_sign = sum(wrong_sign, na.rm=TRUE), .groups="drop")
  print(as.data.frame(ps))
  write.csv(ps, file.path(TMPCSV, "COMPARE_02_price.csv"), row.names=FALSE)
  if (sum(ps$n_wrong_sign) > 0)
    cat("\n!! Positive, significant own-price elasticities remain. The leave-one-out\n",
        "   cluster price is not a clean instrument: in clusters where everyone buys\n",
        "   the expensive cut, price and quantity rise together. Report this.\n")
}

###############################################################################
## 5. figure
###############################################################################
FIG <- FIGDIAG
s <- summ %>% mutate(lab = LABEL[product],
                     ctry = paste0(country, "\n$", gdp_pc))

p1 <- s %>% select(ctry, lab, Quantity=quantity, Quality=quality) %>%
  pivot_longer(c(Quantity,Quality), names_to="component", values_to="e") %>%
  ggplot(aes(ctry, e, fill=component)) + geom_col() + facet_wrap(~lab, nrow=1) +
  scale_fill_manual(values=c(Quantity="#4E79A7", Quality="#59A14F")) +
  labs(title="Quantity dominates in both countries",
       subtitle="Expenditure elasticity split into its two margins, averaged over waves",
       x=NULL, y="Elasticity", fill=NULL) + TH
ggsave(file.path(FIGDIAG, paste0("zz_", "COMPARE_01_decomposition.png")), p1, width=10, height=3.6, dpi=200)

p2 <- ggplot(s, aes(reorder(ctry, gdp_pc), quality_share, fill=lab)) +
  geom_col(position=position_dodge(.8), width=.75) +
  geom_hline(yintercept=.5, linetype="dashed", colour="grey50") +
  labs(title="Share of the income response that is quality",
       subtitle="Countries ordered by GDP per capita. Above the dashed line, upgrading dominates.",
       x=NULL, y="Quality share", fill=NULL) + TH
ggsave(file.path(FIGDIAG, paste0("zz_", "COMPARE_02_quality_share.png")), p2, width=8, height=4, dpi=200)

p3 <- ggplot(s, aes(participation, quality_share, colour=country, label=lab)) +
  geom_point(size=3) + geom_text(vjust=-.9, size=3, show.legend=FALSE) +
  labs(title="Where a market is wide, is it also deep?",
       subtitle="Participation on the horizontal axis, quality upgrading on the vertical",
       x="% of households purchasing", y="Quality share", colour=NULL) + TH
ggsave(file.path(FIGDIAG, paste0("zz_", "COMPARE_03_participation_vs_quality.png")), p3, width=7.5, height=5, dpi=200)

message("\nwritten -> ", RES_DIR, " and ", FIG)
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 9 - ANALISI AVANZATE: CONSUMO TOTALE, EFFETTI FISSI, SELEZIONE
##
##  COSA FA   Per carne, latte, uova e caffe' (traccia A), in ogni paese:
##   (A) DA DOVE VIENE il cibo animale: % comprata, autoprodotta, regalata.
##       E la decomposizione rifatta sul consumo TOTALE invece che sui soli
##       acquisti (tabelle XXX_10, XXX_11).
##   (B) EFFETTI FISSI FAMILIARI: la stessa famiglia osservata in piu' wave.
##       Se la qualita' sale con il reddito anche DENTRO la famiglia, l'effetto
##       non e' dovuto a differenze di gusti fra famiglie ricche e povere
##       (tabella XXX_12). Serve un identificativo che colleghi le wave:
##       panel_ids(), qui sotto.
##   (C) SELEZIONE (Heckman): chi compra non e' un campione casuale. Si corregge
##       con il possesso di animali come variabile di esclusione: chi ha mucche
##       compra meno latte, ma il possesso non dovrebbe cambiare quanto ne
##       compra chi lo compra (tabella XXX_13).
##   (D) partecipazione per quinto di benessere (tabella XXX_14).
##  NOTA      Le funzioni (livestock_flags, panel_ids) sono definite sempre,
##            anche con RUN_ADV = FALSE, perche' la PARTE 11 le riusa.
##
###############################################################################
###############################################################################
RES_DIR <- RUN_DIR
FIG <- FIGDIAG
## legge un file .dta, oppure NULL se non c'e' (invece di fermare lo script)
grab <- function(stem, hint=NULL) {
  p <- find_dta(stem, hint); if (is.na(p)) return(NULL)
  tryCatch(haven::read_dta(p), error=function(e) NULL)
}
###############################################################################
## ANIMALI POSSEDUTI, per paese: file, identificativo, variabile del codice
##  dell'animale, variabile del numero di capi, e i gruppi di codici che
##  corrispondono ai nostri prodotti: bovini (latte), altri animali da carne
##  (carne), pollame (uova).
###############################################################################
LS <- list(
  ## v21 (D5): ogni codice e conteggio qui sotto e' stato controllato sulle
  ## etichette dei valori e sul testo delle domande di ogni wave
  ## (checks/varmap2.R). La v20 usava un solo raggruppamento per tutte le wave,
  ## sbagliato per l'Etiopia 2011-2013 e 2015, e leggeva i capi POSSEDUTI IN
  ## PASSATO della Tanzania (lf02_02) invece di quelli attuali.
  ## I gruppi mantengono il significato della v20: bovini (latte), altri animali
  ## da carne, pollame (uova).
  ETH = list(
    waves = c(w1="w1", w2="w2", w3="w3", w4="w4", w5="w5"),
    stem  = function(w) if (w %in% c("w1","w2")) paste0("sect8a_ls_", w)
                        else paste0("sect8_1_ls_", w),
    hint  = function(w) paste0("ETH_20", c(w1="11",w2="13",w3="15",w4="18",w5="21")[[w]]),
    id    = function(w) if (w %in% c("w2","w3")) "household_id2" else "household_id",
    code  = function(w) if (w %in% c("w1","w2")) "ls_s8aq00" else "ls_code",
    ## w1-w2: ls_s8aq13a "totale posseduto"; w3: ls_sec_8_1q01; w4-w5: ls_s8_1q01
    count = function(w) c(w1="ls_s8aq13a", w2="ls_s8aq13a", w3="ls_sec_8_1q01",
                          w4="ls_s8_1q01", w5="ls_s8_1q01")[[w]],
    grp   = function(w) switch(w,
      ## 1 bovini, 2 pecore, 3 capre, 4-6 equini, 7 cammelli, 8-13 polli
      w1 = , w2 = list(cattle=1, smallrum=c(2,3,7), poultry=8:13),
      ## 1-6 classi di bovini, 7-9 capre, 10-12 pecore, 13-15 cammelli, 16-19 polli
      w3 = list(cattle=1:6, smallrum=7:15, poultry=16:19),
      ## 1-6 classi di bovini, 7 capre, 8 pecore, 9 cammelli, 10-12 polli
      list(cattle=1:6, smallrum=7:9, poultry=10:12))),
  TZA = list(
    waves = c(w1="2008", w2="2010", w3="2012", w4="2014", w5="2020"),
    stem  = function(w) c(w1="SEC_10A", w2="AG_SEC10A", w3="LF_SEC_02",
                          w4="LF_SEC_02", w5="LF_SEC_02")[[w]],
    hint  = function(w) paste0("TZA_", c(w1="2008",w2="2010",w3="2012",
                                         w4="2014",w5="2020")[[w]]),
    id    = function(w) c(w1="hhid",w2="y2_hhid",w3="y3_hhid",
                          w4="y4_hhid",w5="y5_hhid")[[w]],
    code  = function(w) c(w1="animal", w2="lvstkcode", w3="lvstckid",
                          w4="lvstckid", w5="lvstckid")[[w]],
    ## capi posseduti ORA, sommati sulle razze: "Quanti [ANIMALE] possiede
    ## attualmente questa famiglia?" (locali / migliorati ...)
    count = function(w) c(w1="^s10aq4_[123]$", w2="^ag10a_05_[123]$",
                          w3="^lf02_04_[12]$", w4="^lf02_04_[12]$", w5="^lf02_04_[12]$")[[w]],
    ## 1-6 bovini, 7 capre, 8 pecore, 9 maiali | 2008-2010: 10 polli, 11 tacchini;
    ## 2012-2020: 10 polli, 11 anatre, 12 altro pollame
    grp   = function(w) if (w %in% c("w1","w2"))
              list(cattle=1:6, smallrum=7:9, poultry=10:11) else
              list(cattle=1:6, smallrum=7:9, poultry=10:12))
)

## livestock_flags(): per ogni famiglia e wave, 1 se possiede bovini / piccoli
## ruminanti / pollame, e il numero totale di capi.
livestock_flags <- function(cc) {
  C <- LS[[cc]]; if (is.null(C)) return(NULL)
  map_dfr(names(C$waves), function(w) {
    d <- grab(C$stem(w), C$hint(w)); if (is.null(d)) return(NULL)
    idv <- C$id(w); codev <- C$code(w); cnt <- C$count(w); G <- C$grp(w)
    if (!(idv %in% names(d)) || !(codev %in% names(d))) return(NULL)
    ## il conteggio e' una colonna sola oppure un gruppo di colonne da sommare
    cols <- if (grepl("^\\^", cnt)) grep(cnt, names(d), value=TRUE) else
            intersect(cnt, names(d))
    if (!length(cols)) return(NULL)
    d$.n <- rowSums(sapply(cols, function(k) num(d[[k]])), na.rm=TRUE)
    d %>% transmute(hhid = as.character(.data[[idv]]),
                    .code = num(.data[[codev]]),
                    .n    = .n) %>%
      group_by(hhid) %>%
      summarise(own_cattle   = as.integer(any(.code %in% G$cattle   & .n > 0, na.rm=TRUE)),
                own_smallrum = as.integer(any(.code %in% G$smallrum & .n > 0, na.rm=TRUE)),
                own_poultry  = as.integer(any(.code %in% G$poultry  & .n > 0, na.rm=TRUE)),
                n_tlu        = sum(.n, na.rm=TRUE), .groups="drop") %>%
      mutate(wave = w)
  })
}

###############################################################################
## IDENTIFICATIVO PANEL: collega la stessa famiglia fra le wave.
##  La costruzione usa l'identificativo della wave, che NON collega le wave.
##  L'Etiopia usa household_id2 nelle wave 2-3 mentre il collegamento e'
##  household_id; la Tanzania collega 2008 -> 2010 -> 2012 con hhid_2008 e
##  y2_hhid. Il Malawi non c'e': le sue indagini non sono un panel.
###############################################################################
panel_ids <- function(cc) {
  if (cc == "ETH") {
    out <- list()
    for (w in c("w1","w4","w5")) {
      d <- grab(paste0("cons_agg_", w), paste0("ETH_20",
             c(w1="11",w4="18",w5="21")[[w]]))
      if (!is.null(d)) out[[w]] <- tibble(wave=w,
        hhid=as.character(d$household_id), pid=as.character(d$household_id))
    }
    for (w in c("w2","w3")) {
      d <- grab(paste0("cons_agg_", w), paste0("ETH_20", c(w2="13",w3="15")[[w]]))
      if (!is.null(d) && all(c("household_id","household_id2") %in% names(d)))
        out[[w]] <- tibble(wave=w, hhid=as.character(d$household_id2),
                           pid=as.character(d$household_id))
    }
    return(bind_rows(out))
  }
  if (cc == "TZA") {
    ## v21 (D9): un'unita' panel per famiglia, un collegamento per famiglia.
    ## La copertina (HH_SEC_A) da' a ogni famiglia l'identificativo della
    ## famiglia da cui viene e dice se e' la famiglia ORIGINALE o una che si e'
    ## STACCATA (2010 hh_a11: 1-2 originale, 3 staccata; 2012 e 2020 hh_a10: 1
    ## originale, 2 staccata). L'originale continua l'unita' della precedente;
    ## una staccata ne inizia una sua, e cosi' ogni famiglia di una discendenza
    ## con piu' di un'"originale". La v20 collegava 2012 e 2020 attraverso i
    ## singoli membri, cosi' 56 famiglie avevano due identificativi (le loro
    ## righe contate due volte) e famiglia madre e staccata, nella stessa wave,
    ## erano trattate come una sola nei modelli a effetti fissi e di reddito
    ## permanente.
    link <- function(w, hhid, prev, orig, prev_pid = NULL) {
      x <- tibble(hhid = as.character(hhid), prev = as.character(prev),
                  orig = orig %in% TRUE)
      x <- x %>% group_by(prev) %>% mutate(n_orig = sum(orig)) %>% ungroup()
      if (!is.null(prev_pid)) x <- x %>% left_join(prev_pid, by = "prev")
      else x$ppid <- x$prev
      x %>% transmute(wave = w, hhid,
        pid = ifelse(orig & n_orig == 1 & !is.na(prev) & nzchar(prev) & !is.na(ppid),
                     ppid, paste0(w, "_", hhid)))
    }
    out <- list()
    d1 <- grab("TZY1.HH.Consumption", "TZA_2008")
    if (!is.null(d1)) out$w1 <- tibble(wave="w1", hhid=as.character(d1$hhid),
                                       pid=as.character(d1$hhid))
    d2 <- grab("TZY2.HH.Consumption", "TZA_2010"); a2 <- grab("HH_SEC_A", "TZA_2010")
    if (!is.null(d2) && !is.null(a2) && "hhid_2008" %in% names(d2)) {
      x <- d2 %>% transmute(y2_hhid = as.character(y2_hhid), prev = as.character(hhid_2008)) %>%
        left_join(a2 %>% transmute(y2_hhid = as.character(y2_hhid),
                                   orig = as.numeric(hh_a11) %in% c(1, 2)), by = "y2_hhid")
      out$w2 <- link("w2", x$y2_hhid, x$prev, x$orig)
    }
    a3 <- grab("HH_SEC_A", "TZA_2012")
    if (!is.null(a3) && !is.null(out$w2) && all(c("y3_hhid","hh_a09","hh_a10") %in% names(a3)))
      out$w3 <- link("w3", a3$y3_hhid, a3$hh_a09, as.numeric(a3$hh_a10) == 1,
                     prev_pid = out$w2 %>% select(prev = hhid, ppid = pid))
    d4 <- grab("consumptionNPS4", "TZA_2014")
    if (!is.null(d4)) out$w4 <- tibble(wave="w4", hhid=as.character(d4$y4_hhid),
                                       pid=as.character(d4$y4_hhid))
    a5 <- grab("hh_sec_a", "TZA_2020")
    if (!is.null(a5) && all(c("y5_hhid","y4_hhid","hh_a10") %in% names(a5)))
      out$w5 <- link("w5", a5$y5_hhid, a5$y4_hhid, as.numeric(a5$hh_a10) == 1)
    return(bind_rows(out) %>% filter(!is.na(pid)))
  }
  if (cc == "NGA") {
    ## v21 (M7): il GHS-Panel tiene UN hhid in tutte le wave (HHTrack.dta
    ## registra lo stato di ogni famiglia wave per wave); 4.387 famiglie sono in
    ## tutte e tre.
    yrs <- c(w1 = "2010", w2 = "2012", w3 = "2015")
    out <- lapply(names(yrs), function(w) {
      d <- grab(paste0("cons_agg_wave", substr(w, 2, 2), "_visit2"), paste0("NGA_", yrs[[w]]))
      if (is.null(d)) NULL else tibble(wave = w, hhid = as.character(d$hhid), pid = as.character(d$hhid))
    })
    return(bind_rows(out))
  }
  if (cc == "UGA") {
    ## v22: un'unita' panel per famiglia, come in Tanzania (D9). Ogni wave dice
    ## quale famiglia precedente continua: l'HHID a 10 cifre resta nel
    ## 2010-2011; il 2013 da' HHID_old; il 2015 rinumera "H00101-04-01" del 2013
    ## come "H00101-05-01"; il 2018 da' t0_hhid ("H0010101" del 2015) e il 2019
    ## hhidold (la chiave del 2018). Solo i file 2010-11 dicono quale famiglia e'
    ## l'originale e quale si e' staccata, quindi dal 2013 in poi, quando due
    ## famiglie dichiarano la stessa precedente, ENTRAMBE iniziano unita' nuove
    ## (5 casi nel 2018, 68 nel 2019). Un terzo del campione e' stato sostituito
    ## nel 2013: anche quelle famiglie iniziano unita' nuove.
    ids <- function(x) if (is.numeric(x)) sprintf("%.0f", x) else trimws(as.character(x))
    chain <- function(w, hhid, prev, prev_pid) {
      x <- tibble(hhid = ids(hhid), prev = ids(prev)) %>%
        mutate(prev = ifelse(prev %in% c("", "NA"), NA, prev)) %>%
        group_by(prev) %>% mutate(n_claim = n()) %>% ungroup() %>%
        left_join(prev_pid, by = "prev")
      x %>% transmute(wave = w, hhid,
                      pid = ifelse(!is.na(prev) & n_claim == 1 & !is.na(ppid), ppid,
                                   paste0(w, "_", hhid)))
    }
    out <- list()
    g1 <- grab("GSEC1", "UGA_2010"); g2 <- grab("GSEC1", "UGA_2011")
    if (!is.null(g1)) out$w1 <- tibble(wave = "w1", hhid = ids(g1$HHID), pid = ids(g1$HHID))
    if (!is.null(g2)) out$w2 <- tibble(wave = "w2", hhid = ids(g2$HHID), pid = ids(g2$HHID))
    earlier <- bind_rows(out) %>% distinct(prev = hhid, ppid = pid)
    g3 <- grab("GSEC1", "UGA_2013")
    if (!is.null(g3)) {
      ## una famiglia del 2013 la cui precedente non e' nel 2010-11 tiene
      ## quell'identificativo come unita', cosi' si collega se il 2009/10 verra'
      ## aggiunto
      out$w3 <- chain("w3", g3$hhid, g3$HHID_old,
                      bind_rows(earlier, tibble(prev = ids(g3$HHID_old), ppid = ids(g3$HHID_old))) %>%
                        filter(!is.na(prev), prev != "NA") %>% distinct(prev, .keep_all = TRUE))
    }
    g4 <- grab("gsec1", "UGA_2015")
    if (!is.null(g4) && !is.null(out$w3))
      out$w4 <- chain("w4", g4$hh, sub("-05-", "-04-", ids(g4$hh)),
                      out$w3 %>% select(prev = hhid, ppid = pid))
    g5 <- grab("GSEC1", "UGA_2018")
    if (!is.null(g5) && !is.null(out$w4)) {
      k4 <- tibble(prev = ids(g4$hhid), hh = ids(g4$hh)) %>%
        inner_join(out$w4 %>% select(hh = hhid, ppid = pid), by = "hh") %>% select(prev, ppid)
      out$w5 <- chain("w5", g5$hhid, g5$t0_hhid, k4)
    }
    g6 <- grab("gsec1", "UGA_2019")
    if (!is.null(g6) && !is.null(out$w5))
      out$w6 <- chain("w6", g6$hhid, g6$hhidold, out$w5 %>% select(prev = hhid, ppid = pid))
    return(bind_rows(out) %>% filter(!is.na(pid)))
  }
  NULL
}

###############################################################################
## ESECUZIONE (le funzioni sopra sono definite sempre, la PARTE 11 le riusa)
###############################################################################
if (RUN_ADV) {
panels <- list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)
CORE <- c("meat_agg","milk","eggs","coffee")
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), panel.grid.minor=element_blank(),
        strip.text=element_text(face="bold"))

for (pf in panels) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  message("\n================ ", cc, " ================")

  d <- raw %>%
    mutate(hhid    = as.character(hhid),
           qty_pur = num(if ("purch_std" %in% names(.)) purch_std else purch_kg),
           qty_tot = num(if ("qty_std"   %in% names(.)) qty_std   else qty_kg),
           own     = num(if ("own_std"   %in% names(.)) own_std   else own_kg),
           gift    = num(if ("gift_std"  %in% names(.)) gift_std  else gift_kg),
           welfare = num(if ("welfare" %in% names(.)) welfare else nom_totcons_aeq),
           weight  = num(if ("hhweight" %in% names(.)) hhweight else weight),
           adulteq = pmax(num(adulteq), 1),
           uv = num(uv), exp = num(exp),
           unconv = ifelse(is.na(num(unconv)), 0, num(unconv))) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight),
           l_x = log(welfare), l_ae = log(adulteq),
           region = factor(region)) %>%
    filter(track == "A", product %in% CORE)

  ## ---- animali posseduti ------------------------------------------------ #
  ls_df <- livestock_flags(cc)
  if (!is.null(ls_df) && nrow(ls_df)) {
    d <- d %>% left_join(ls_df, by=c("hhid","wave"))
    message("livestock merged for ", sum(!is.na(d$own_cattle)), " rows")
  } else {
    d$own_cattle <- NA_integer_; d$own_smallrum <- NA_integer_
    d$own_poultry <- NA_integer_
    message("!! livestock module not found for ", cc, " — (C) will be skipped")
  }
  ## la variabile di esclusione adatta a ogni prodotto: bovini per il latte,
  ## pollame per le uova, bovini o piccoli ruminanti per la carne
  d <- d %>% mutate(own_rel = case_when(
    product == "milk"     ~ own_cattle,
    product == "eggs"     ~ own_poultry,
    product == "meat_agg" ~ pmax(own_smallrum, own_cattle, na.rm=TRUE),
    TRUE ~ NA_integer_))

  ## ---- identificativo panel --------------------------------------------- #
  pids <- panel_ids(cc)
  if (!is.null(pids) && nrow(pids)) {
    d <- d %>% left_join(pids, by=c("hhid","wave"), relationship="many-to-one")
    nrep <- d %>% filter(!is.na(pid)) %>% distinct(pid, wave) %>%
      count(pid) %>% filter(n > 1) %>% nrow()
    message("panel: ", nrep, " households observed in more than one wave")
  } else d$pid <- NA_character_

  ####################### (A) TOTALE CONTRO ACQUISTATO #######################
  cat("\n--- (A) how much animal protein never passes through a market ---\n")
  ## Denominatore = le tre fonti stesse, cosi' le quote sommano a 100. Dividendo
  ## per qty_tot usciva 181% autoprodotto e -83% acquistato, perche' alcune
  ## famiglie dichiarano una fonte piu' grande del totale.
  ## Una famiglia tanzaniana dichiarava 8.500 kg di carne ricevuta in regalo in
  ## una settimana - 8,5 tonnellate, chiaramente un errore di inserimento, e da
  ## sola il 96% dei regali di quell'anno. Le somme non resistono a un solo
  ## valore anomalo, quindi ogni fonte si taglia al 99,9-esimo percentile per
  ## prodotto x anno.
  src <- d %>%
    mutate(.p = coalesce(qty_pur,0), .o = coalesce(own,0), .g = coalesce(gift,0)) %>%
    group_by(product, year) %>%
    mutate(across(c(.p,.o,.g), ~ pmin(.x, quantile(.x, .999, na.rm=TRUE)))) %>%
    ungroup() %>%
    mutate(.tot = .p + .o + .g) %>%
    ## v24: i prodotti in MIN_UV_SHARE (pesce) solo dove le quantita' convertite
    ## coprono abbastanza consumatori - non i mucchi di pesce di Uganda e Malawi
    group_by(product, year) %>%
    mutate(.cover = sum(.tot > 0) / max(1, sum(coalesce(num(consumed), 0) == 1 | .tot > 0))) %>%
    ungroup() %>%
    filter(!(product %in% names(MIN_UV_SHARE)) | .cover >= MIN_UV_SHARE[product]) %>%
    filter(.tot > 0) %>%
    group_by(product, year) %>%
    summarise(pct_purchased = round(100*sum(.p)/sum(.tot),1),
              pct_own       = round(100*sum(.o)/sum(.tot),1),
              pct_gift      = round(100*sum(.g)/sum(.tot),1),
              .groups="drop")
  print(as.data.frame(src))
  write.csv(src, file.path(TMPCSV, paste0(cc,"_10_sources.csv")), row.names=FALSE)

  ## la stessa decomposizione sul consumo TOTALE invece che sugli acquisti
  fitA <- function(g, prod = NA_character_) {
    b <- g %>% filter(qty_tot > 0, uv > 0, welfare > 0, unconv == 0)
    if (nrow(b) < 80) return(tibble())
    if (!is.na(prod) && prod %in% names(MIN_UV_SHARE) &&
        nrow(b) < MIN_UV_SHARE[[prod]] * sum(coalesce(g$qty_pur, 0) > 0 | coalesce(num(g$exp), 0) > 0)) return(tibble())
    m <- try(feols(log(qty_tot) ~ l_x + l_ae | region, b, weights=~weight,
                   vcov="hetero"), silent=TRUE)
    p <- try(feols(log(qty_pur) ~ l_x + l_ae | region,
                   b %>% filter(qty_pur > 0), weights=~weight, vcov="hetero"),
             silent=TRUE)
    gv <- function(m) if (inherits(m,"try-error")) NA else unname(coef(m)["l_x"])
    tibble(n=nrow(b), e_qty_total=gv(m), e_qty_purchased=gv(p))
  }
  totq <- d %>% group_by(year, product) %>% group_modify(~fitA(.x, .y$product)) %>% ungroup()
  cat("\n--- quantity elasticity: TOTAL consumption vs PURCHASES only ---\n")
  print(as.data.frame(totq %>% mutate(across(where(is.numeric), ~round(.x,3)))))
  write.csv(totq, file.path(TMPCSV, paste0(cc,"_11_total_vs_purchased.csv")),
            row.names=FALSE)

  ####################### (B) EFFETTI FISSI FAMILIARI ########################
  ## Solo famiglie osservate in piu' di un anno. Regressioni con effetti fissi
  ## della famiglia (pid) e dell'anno: il coefficiente di l_x misura come
  ## cambiano qualita' e quantita' quando QUELLA famiglia diventa piu' ricca.
  ## Errori standard raggruppati per famiglia.
  cat("\n--- (B) household fixed effects: the same family getting richer ---\n")
  fe <- d %>% filter(!is.na(pid), uv > 0, qty_pur > 0, welfare > 0, unconv == 0)
  if (nrow(fe) > 200) {
    fe <- fe %>% group_by(product, pid) %>% filter(n_distinct(year) > 1) %>% ungroup()
    fefit <- function(g) {
      if (nrow(g) < 100 || n_distinct(g$pid) < 50) return(tibble())
      mq <- try(feols(log(uv)      ~ l_x + l_ae | pid + year, g, weights=~weight,
                      cluster=~pid), silent=TRUE)
      mn <- try(feols(log(qty_pur) ~ l_x + l_ae | pid + year, g, weights=~weight,
                      cluster=~pid), silent=TRUE)
      gv <- function(m,k="l_x") if (inherits(m,"try-error") ||
              !(k %in% names(coef(m)))) c(NA,NA,NA) else c(coef(m)[k], se(m)[k], pvalue(m)[k])
      cq <- gv(mq); cn <- gv(mn)     # NON `a`/`n`: tibble() maschererebbe `n`
      tibble(n_obs=nrow(g), n_hh=n_distinct(g$pid),
             e_quality_FE=cq[1], se_quality=cq[2], p_quality=cq[3],
             e_quantity_FE=cn[1], se_quantity=cn[2], p_quantity=cn[3],
             quality_share_FE=cq[1]/(cq[1]+cn[1]))
    }
    feres <- fe %>% group_by(product) %>% group_modify(~fefit(.x)) %>% ungroup()
    print(as.data.frame(feres %>% mutate(across(where(is.numeric), ~round(.x,3)))))
    write.csv(feres, file.path(TMPCSV, paste0(cc,"_12_household_FE.csv")),
              row.names=FALSE)
    cat("\nCompare these with the cross-sectional shares: if they differ a lot,\n",
        "the cross-section was picking up taste, not income.\n")
  } else cat("panel too thin for fixed effects\n")

  ####################### (C) HECKMAN CON UNO STRUMENTO #####################
  ## Primo stadio: probit della decisione di comprare su reddito, dimensione e
  ## possesso dell'animale. Da li' il termine di selezione (inverso del
  ## rapporto di Mills, imr), aggiunto alla regressione della quantita' fra
  ## chi compra.
  cat("\n--- (C) selection, using livestock ownership as the exclusion ---\n")
  if (any(!is.na(d$own_rel))) {
    hk <- d %>% filter(welfare > 0, !is.na(own_rel)) %>%
      mutate(buys = as.integer(coalesce(qty_pur > 0 & uv > 0, FALSE)))
    hres <- hk %>% group_by(year, product) %>% group_modify(function(g, ...) {
      if (sum(g$buys) < 80 || n_distinct(g$own_rel) < 2) return(tibble())
      ## SEPARAZIONE PERFETTA: una cella vuota nella tabella 2x2 fa divergere il
      ## probit, con coefficienti dell'ordine di 1e14. Si salta invece di
      ## stampare rumore.
      tab <- table(g$own_rel, g$buys)
      if (any(dim(tab) < 2) || any(tab < 10)) return(tibble())
      ## i pesi dell'indagine non sono pesi di frequenza; il primo stadio si
      ## stima senza pesi e serve solo a costruire il termine di selezione.
      pr <- try(glm(buys ~ l_x + l_ae + own_rel, data=g,
                    family=binomial("probit")), silent=TRUE)
      if (inherits(pr,"try-error") || !isTRUE(pr$converged)) return(tibble())
      z  <- coef(summary(pr))
      if (abs(z["own_rel","Estimate"]) > 10) return(tibble())
      g$imr <- dnorm(predict(pr, g)) / pmax(pnorm(predict(pr, g)), 1e-6)
      s <- g %>% filter(buys == 1)
      m <- try(feols(log(qty_pur) ~ l_x + l_ae + imr | region, s,
                     weights=~weight, vcov="hetero"), silent=TRUE)
      if (inherits(m,"try-error")) return(tibble())
      if (!("imr" %in% names(coef(m)))) return(tibble())  # tolto -> non identificato
      tibble(first_stage_own = round(z["own_rel","Estimate"], 3),
             first_stage_p   = round(z["own_rel","Pr(>|z|)"], 4),
             e_quantity_corrected = unname(coef(m)["l_x"]),
             imr_coef = unname(coef(m)["imr"]),
             imr_p    = unname(pvalue(m)["imr"]))
    }) %>% ungroup()
    print(as.data.frame(hres %>% mutate(across(where(is.numeric), ~round(.x,3)))))
    write.csv(hres, file.path(TMPCSV, paste0(cc,"_13_heckman_instrumented.csv")),
              row.names=FALSE)
    cat("\nfirst_stage_own should be NEGATIVE and significant: owning the animal\n",
        "reduces the probability of buying. If it is, the exclusion has bite.\n")
  } else cat("no livestock data — skipped\n")

  ####################### partecipazione per quinto #########################
  cat("\n--- participation by welfare quintile ---\n")
  q <- d %>% filter(welfare > 0) %>% hh_quintile() %>%
    ## v21 (D14): un acquisto la cui unita' non si converte e' comunque un acquisto
    mutate(buys = as.integer(coalesce(qty_pur > 0, FALSE) | coalesce(exp > 0, FALSE))) %>%
    group_by(product, qt) %>%
    summarise(participation = round(100*weighted.mean(buys, weight, na.rm=TRUE),1),
              .groups="drop") %>%
    pivot_wider(names_from=qt, values_from=participation, names_prefix="Q")
  print(as.data.frame(q))
  write.csv(q, file.path(TMPCSV, paste0(cc,"_14_participation_quintile.csv")),
            row.names=FALSE)

  p1 <- src %>% pivot_longer(c(pct_own, pct_gift, pct_purchased),
                             names_to="source", values_to="pct") %>%
    ggplot(aes(factor(year), pct, fill=source)) + geom_col() +
    facet_wrap(~product, nrow=1) +
    scale_fill_manual(values=c(pct_purchased="#4E79A7", pct_own="#59A14F",
                               pct_gift="#F28E2B")) +
    labs(title=paste0(cc, ": where animal-source food actually comes from"),
         x=NULL, y="% of quantity consumed", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_sources.png"))), p1, width=10, height=3.4, dpi=200)
}
message("\ndone -> ", RES_DIR, " and ", FIG)
###############################################################################

}


###############################################################################
###############################################################################
##
##  PARTE 10 - PANIERE, PROTEINE, VARIETA' E QUATTRO MARGINI (traccia B)
##
##  COSA AGGIUNGE, e perche':
##   * tutto PER ADULTO EQUIVALENTE, non per famiglia: un totale familiare
##     mescola il consumo con la dimensione della famiglia.
##   * la carne DIVISA - manzo, capra e pecora, maiale, pollame, ognuno per
##     conto suo (traccia B) - e il pesce.
##   * il PANIERE: cosa mangia il quinto piu' ricco rispetto al piu' povero, come
##     composizione e non solo come livello (tabella XXX_20).
##   * PROTEINE: un chilo di manzo e un litro di latte non si confrontano, un
##     grammo di proteine si'. Rende confrontabili i prodotti e da' un
##     significato nutrizionale all'analisi (tabella XXX_21).
##   * chi ALLEVA o COLTIVA CAFFE' contro gli altri: una famiglia che produce e'
##     diversa da una che compra soltanto (tabella XXX_23).
##
##  L'IDEA NUOVA - un quarto margine (tabella XXX_22).
##  La letteratura divide la risposta al reddito in QUANTITA' e QUALITA'. Con i
##  prodotti separati si puo' verificare una terza possibilita': che il reddito
##  in piu' compri VARIETA'. Una famiglia che passa dal solo latte a latte, uova
##  e pollo non ha comprato di piu' di qualcosa, ne' qualcosa di piu' caro: ha
##  diversificato. Si misura in due modi: il numero di prodotti animali diversi
##  consumati, e la concentrazione del paniere (indice di Herfindahl). Se
##  l'elasticita' della varieta' e' grande dove quella della qualita' e' zero,
##  la transizione riguarda l'ampiezza, non il livello.
##
##  E una misura di qualita' migliore: il COSTO PER GRAMMO DI PROTEINE. Il valore
##  unitario al kg non si confronta fra prodotti; il costo per grammo di proteine
##  si', e dice se le famiglie piu' ricche pagano di piu' lo stesso nutriente.
##
###############################################################################
###############################################################################
if (exists("RUN_DEEP") && !RUN_DEEP) message("PART 6 skipped") else {

RES_DIR <- RUN_DIR
FIGD <- FIGDIAG

## ---- contenuto di proteine, valori standard delle tabelle di composizione -- #
## grammi di proteine per unita' standard del prodotto, come registrata nel
## pannello.
PROT <- tibble::tribble(
  ~product,      ~std,     ~prot,
  "beef",        "kg",     260,
  "goat_sheep",  "kg",     250,
  "pork",        "kg",     250,
  "poultry",     "kg",     270,
  "meat_agg",    "kg",     255,
  ## v24: il pesce ha quantita' solo in Tanzania e Nigeria, e il pesce secco ha
  ## circa il triplo delle proteine di quello fresco: resta fuori dalle somme
  ## di proteine
  "fish",        "kg",     NA_real_,
  "eggs",        "kg",     126,
  "eggs",        "piece",  6.9,     # un uovo da 55 g
  "milk",           "litre",  33,
  "milk",           "kg",     33,
  "milk_processed", "kg",    250,   # domina la polvere; quello in scatola ne ha meno
  "milk_processed", "litre", 33,    # v21: il 902 della Tanzania (panna, yogurt) e' liquido
  "cheese",      "kg",     200,
  "coffee",      "kg",     0        # uno stimolante, non una fonte di proteine
)
## v21 (M5, 12 nov 2026): pesce fuori. v24 (Paolo, 15 nov 2026): il pesce
## rientra, ora che ogni paese lo registra (l'Etiopia separatamente dal 2015):
## entra nelle tabelle di paniere, varieta' e acquisto, non nelle somme di
## proteine (PROT).
ANIMAL <- c("beef","goat_sheep","pork","poultry","eggs","milk",
            "milk_processed","cheese","fish")

## deep_prep(): legge un pannello, tiene la traccia B (prodotti separati) e
## calcola quantita', spesa e proteine per adulto equivalente.
deep_prep <- function(pf) {
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  d <- raw %>%
    mutate(country = cc, hhid = as.character(hhid),
           std     = if ("std" %in% names(.)) as.character(std) else "kg",
           qty_pur = num(if ("purch_std" %in% names(.)) purch_std else purch_kg),
           qty_tot = num(if ("qty_std"   %in% names(.)) qty_std   else qty_kg),
           exp     = num(exp), uv = num(uv),
           exp_conv = num(if ("exp_conv" %in% names(.)) exp_conv else NA),
           welfare = num(if ("welfare" %in% names(.)) welfare else nom_totcons_aeq),
           adulteq = pmax(num(adulteq), 1),
           weight  = num(if ("hhweight" %in% names(.)) hhweight else weight),
           unconv  = ifelse(is.na(num(unconv)), 0, num(unconv))) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight)) %>%
    filter(track == "B")                      # prodotti SEPARATI
  ## per adulto equivalente
  d %>% left_join(PROT, by=c("product","std")) %>%
    mutate(q_ae   = qty_tot / adulteq,
           qp_ae  = qty_pur / adulteq,
           exp_ae = exp / adulteq,
           prot_ae_day = (coalesce(qty_tot,0) * coalesce(prot,0)) / adulteq / 7,
           l_x = log(welfare), l_ae = log(adulteq))
}

## ---- totali per famiglia: paniere, varieta', proteine, costo per grammo ---- #
hh_level <- function(d) {
  d %>% filter(product %in% ANIMAL) %>%
    group_by(country, year, region, hhid, welfare, adulteq, weight, l_x) %>%
    summarise(
      ## v21 (D14): consumato = l'ha detto, oppure c'e' una quantita' convertibile
      n_products  = sum(coalesce(qty_tot,0) > 0 | coalesce(consumed,0) == 1),  # VARIETA', numero di prodotti
      asf_exp     = sum(coalesce(exp,0)),
      asf_prot    = sum(coalesce(prot,0)*coalesce(qty_tot,0)),
      ## v21 (M14): il costo di un grammo e' la spesa per gli acquisti divisa per
      ## le proteine ACQUISTATE; dividere per tutte le proteine consumate
      ## mescolava l'autoproduzione
      asf_prot_pur = sum(coalesce(prot,0)*coalesce(qty_pur,0) *
                         (coalesce(exp_conv,0) > 0)),   # v24 (controllo): abbinato alla spesa
      ## v24 (M15): ... e la spesa deve riguardare gli STESSI acquisti: solo
      ## quelli con quantita' convertita (exp_conv) di prodotti con un contenuto
      ## di proteine. Prima tutta la spesa si divideva per le proteine dei soli
      ## acquisti convertiti: il pollo ugandese (mai pesato) aggiungeva costo e
      ## nessuna proteina, e il pesce avrebbe fatto lo stesso.
      asf_exp_pur_prot = sum(coalesce(exp_conv,0) * !is.na(prot) * (coalesce(qty_pur,0) > 0)),
      hhi         = { s <- coalesce(exp,0); s <- s/ifelse(sum(s)>0,sum(s),NA)
                      sum(s^2, na.rm=TRUE) },              # concentrazione del paniere
      .groups="drop") %>%
    mutate(prot_ae_day = asf_prot/adulteq/7,
           asf_exp_ae  = asf_exp/adulteq,
           cost_per_g  = ifelse(asf_prot_pur > 0, asf_exp_pur_prot/asf_prot_pur, NA_real_))
}

for (pf in list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)) {

  cc <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  message("\n############ DEEP: ", cc, " ############")
  d  <- deep_prep(pf)
  H  <- hh_level(d)

  ## quinti di benessere, per famiglia e per anno
  d <- hh_quintile(d)          # v24 (M16)
  H <- H %>% left_join(d %>% distinct(year, hhid, qt), by = c("year", "hhid"))

  ## ======================= 10.1 IL PANIERE, RICCHI CONTRO POVERI ========= #
  cat("\n--- 6.1 what the richest fifth eats, against the poorest ---\n")
  basket <- d %>% filter(product %in% ANIMAL, !is.na(qt)) %>%
    group_by(qt, product) %>%
    ## v24: consumato = una quantita' convertita OPPURE la dichiarazione di
    ## consumo (pollo e pesce ugandesi non sono mai pesati, e risultavano 0%)
    summarise(pct_consuming = round(100*weighted.mean(coalesce(qty_tot,0) > 0 | coalesce(consumed,0) == 1,
                                                      weight, na.rm=TRUE), 1),
              kg_per_ae_wk  = round(weighted.mean(coalesce(q_ae,0), weight, na.rm=TRUE), 3),
              share_of_asf_spend = NA_real_, .groups="drop")
  ## v21 (M10): quote dentro ogni anno (non si sommano spese nominali di anni
  ## con inflazione diversa), pesate sulla popolazione, poi la media sulle wave:
  ## ogni wave conta uguale.
  shares <- d %>% filter(product %in% ANIMAL, !is.na(qt)) %>%
    group_by(year, qt) %>% mutate(tot = sum(coalesce(exp,0) * weight)) %>%
    group_by(year, qt, product) %>%
    summarise(s = 100*sum(coalesce(exp,0) * weight)/first(tot), .groups="drop") %>%
    group_by(qt, product) %>%
    summarise(share_of_asf_spend = round(mean(s, na.rm=TRUE), 1), .groups="drop")
  basket <- basket %>% select(-share_of_asf_spend) %>%
    left_join(shares, by=c("qt","product"))
  print(as.data.frame(basket %>%
    select(product, qt, pct_consuming) %>%
    pivot_wider(names_from=qt, values_from=pct_consuming, names_prefix="Q")))
  write.csv(basket, file.path(TMPCSV, paste0(cc,"_20_basket_by_quintile.csv")),
            row.names=FALSE)

  cat("\n--- composition of the animal-food basket, % of ASF spending ---\n")
  print(as.data.frame(basket %>% select(product, qt, share_of_asf_spend) %>%
    pivot_wider(names_from=qt, values_from=share_of_asf_spend, names_prefix="Q")))

  ## ======================= 10.2 PROTEINE E VARIETA' ====================== #
  cat("\n--- 6.2 protein, variety and cost per gram, by quintile ---\n")
  pv <- H %>% filter(!is.na(qt)) %>% group_by(year, qt) %>%
    summarise(prot_g_ae_day = round(weighted.mean(prot_ae_day, weight, na.rm=TRUE), 1),
              n_products    = round(weighted.mean(n_products,  weight, na.rm=TRUE), 2),
              hhi           = round(weighted.mean(hhi, weight, na.rm=TRUE), 3),
              cost_per_g    = round(median(cost_per_g, na.rm=TRUE), 2),
              .groups="drop")
  print(as.data.frame(pv %>% select(year, qt, prot_g_ae_day) %>%
    pivot_wider(names_from=qt, values_from=prot_g_ae_day, names_prefix="Q")))
  cat("\n   number of distinct animal products consumed:\n")
  print(as.data.frame(pv %>% select(year, qt, n_products) %>%
    pivot_wider(names_from=qt, values_from=n_products, names_prefix="Q")))
  write.csv(pv, file.path(TMPCSV, paste0(cc,"_21_protein_variety.csv")),
            row.names=FALSE)

  ## ======================= 10.3 I QUATTRO MARGINI ======================== #
  ## partecipazione | quantita' per adulto eq. | qualita' (valore unitario) |
  ## VARIETA'
  cat("\n--- 6.3 the four margins of the income response ---\n")
  marg_prod <- function(g) {
    ## v21 (M1-M2, deciso il 12 nov 2026): ogni margine riguarda gli ACQUISTI -
    ## entrata = ha comprato negli ultimi 7 giorni, quantita' = kg comprati per
    ## adulto equivalente. La v20 usava il consumo (con autoproduzione e
    ## regali) per entrambi.
    b <- g %>% filter(qp_ae > 0, uv > 0, welfare > 0, unconv == 0)
    if (nrow(b) < 80) return(tibble())
    M <- function(f, dat) try(feols(f, dat, weights=~weight, vcov="hetero"), silent=TRUE)
    gv <- function(m,k="l_x") if (inherits(m,"try-error") ||
            !(k %in% names(coef(m)))) c(NA,NA) else c(coef(m)[k], pvalue(m)[k])
    full <- g %>% filter(welfare > 0) %>%
      ## v21 (D14): un acquisto la cui unita' non si converte e' comunque un acquisto
      mutate(buys = as.integer(coalesce(qty_pur > 0, FALSE) | coalesce(exp > 0, FALSE)))
    ## principale: modello di probabilita' lineare, pesato, effetti regione x anno
    mp <- try(feols(buys ~ l_x + l_ae | region^year, full, weights=~weight,
                    vcov="hetero"), silent=TRUE)
    ## robustezza: probit pesato, effetto marginale medio del log del benessere.
    ## v22: con i pesi dell'indagine i "successi" non sono interi e glm lo dice
    ## ogni volta (40 avvisi per esecuzione); la stima e' un probit pesato
    ## (pseudo-verosimiglianza), quindi quell'avviso e' atteso e viene zittito.
    pb <- try(withCallingHandlers(
                feglm(buys ~ l_x + l_ae | region^year, full, weights=~weight,
                      family=binomial("probit"), vcov="hetero",
                      glm.iter = 100),                 # v21: 25 non bastavano per la Tanzania
                warning = function(w) if (grepl("non-integer #successes", conditionMessage(w)))
                  invokeRestart("muffleWarning")), silent=TRUE)
    ame <- if (inherits(pb, "try-error") || !("l_x" %in% names(coef(pb)))) c(NA, NA) else {
      used <- obs(pb); xb <- predict(pb, type = "link")[used]
      c(unname(coef(pb)["l_x"]) * weighted.mean(dnorm(xb), full$weight[used], na.rm = TRUE),
        unname(pvalue(pb)["l_x"])) }
    ## region^year assorbe l'inflazione E il livello dei prezzi locale. Senza
    ## effetto dell'anno, mettendo insieme 2011-2021, l_x prende l'inflazione: la
    ## "qualita'" del manzo usciva 0,636 contro 0,131 stimata anno per anno.
    cq <- gv(M(as.formula("log(qp_ae) ~ l_x + l_ae | region^year"), b))
    cu <- gv(M(as.formula("log(uv)   ~ l_x + l_ae | region^year"), b))
    cp <- gv(mp)
    tibble(n_obs=nrow(b), participation=round(100*mean(full$buys),1),
           e_participation=cp[1], p_part=cp[2],
           e_part_probit_ame=ame[1], p_part_probit=ame[2],
           e_quantity_ae=cq[1],  p_qty=cq[2],
           e_quality=cu[1],      p_qual=cu[2])
  }
  fm <- d %>% filter(product %in% ANIMAL) %>%
    group_by(product) %>% group_modify(~marg_prod(.x)) %>% ungroup()
  print(as.data.frame(fm %>% mutate(across(where(is.numeric), ~round(.x,3)))))

  ## il quarto margine, stimato a livello di famiglia
  vfit <- function(dat, dep) {
    ## v21 (M6): effetti regione x anno, come in tutti gli altri modelli
    m <- try(feols(as.formula(paste(dep, "~ l_x + log(adulteq) | region^year")),
                   dat, weights=~weight, vcov="hetero"), silent=TRUE)
    ## gli effetti dell'anno sono essenziali anche qui: il benessere e' nominale
    if (inherits(m,"try-error")) return(c(NA,NA))
    c(coef(m)["l_x"], pvalue(m)["l_x"])
  }
  Hs <- H %>% filter(welfare > 0, n_products > 0)
  v1 <- vfit(Hs, "log(n_products)")
  v2 <- vfit(Hs %>% filter(prot_ae_day > 0), "log(prot_ae_day)")
  v3 <- vfit(Hs %>% filter(!is.na(hhi), hhi > 0), "log(hhi)")
  v4 <- vfit(Hs %>% filter(!is.na(cost_per_g), cost_per_g > 0), "log(cost_per_g)")
  four <- tibble(
    margin = c("VARIETY (n. of products)", "PROTEIN per adult eq per day",
               "CONCENTRATION of basket (HHI)", "COST per gram of protein"),
    elasticity = round(c(v1[1], v2[1], v3[1], v4[1]), 3),
    p_value    = round(c(v1[2], v2[2], v3[2], v4[2]), 4))
  cat("\n--- the fourth margin: does income buy VARIETY? ---\n")
  print(as.data.frame(four))
  write.csv(bind_rows(fm %>% mutate(level="product"),
                      four %>% rename(product=margin, e_quantity_ae=elasticity,
                                      p_qty=p_value) %>% mutate(level="household")),
            file.path(TMPCSV, paste0(cc,"_22_four_margins.csv")), row.names=FALSE)

  ## ======================= 10.4 PRODUTTORI CONTRO CONSUMATORI ============ #
  cat("\n--- 6.4 livestock owners and coffee growers against the rest ---\n")
  own_col <- intersect(c("own_cattle","own_poultry","own_smallrum"), names(d))
  if (!length(own_col) && exists("livestock_flags")) {
    lsdf <- try(livestock_flags(cc), silent=TRUE)
    if (!inherits(lsdf,"try-error") && !is.null(lsdf) && nrow(lsdf))
      d <- d %>% left_join(lsdf, by=c("hhid","wave"))
  }
  if ("own_cattle" %in% names(d)) {
    sp <- d %>% filter(product %in% c("milk","eggs","beef"), !is.na(own_cattle)) %>%
      mutate(owner = ifelse(product=="eggs", own_poultry, own_cattle)) %>%
      filter(!is.na(owner)) %>%
      group_by(product, owner) %>%
      summarise(n_hh = n_distinct(hhid),
                pct_consuming = round(100*weighted.mean(coalesce(qty_tot,0)>0 | coalesce(consumed,0)==1,
                                                        weight, na.rm=TRUE),1),
                pct_buying    = round(100*weighted.mean(coalesce(qty_pur,0)>0 | coalesce(exp,0)>0,
                                                        weight, na.rm=TRUE),1),
                kg_per_ae     = round(weighted.mean(coalesce(q_ae,0), weight, na.rm=TRUE),3),
                .groups="drop")
    print(as.data.frame(sp))
    write.csv(sp, file.path(TMPCSV, paste0(cc,"_23_owners_vs_not.csv")),
              row.names=FALSE)
    cat("\n   owner = 1 keeps the animal. Consuming can be high while buying is\n",
        "  near zero: that is the market these households are NOT in.\n")
  }
  if ("coffee_grower" %in% names(d)) {          # gia' nel pannello
    dd <- d
    cs <- dd %>% filter(product %in% ANIMAL, !is.na(coffee_grower)) %>%
      group_by(coffee_grower) %>%
      summarise(n_hh=n_distinct(hhid),
                kg_per_ae=round(weighted.mean(coalesce(q_ae,0), weight, na.rm=TRUE),3),
                .groups="drop")
    cat("\n   coffee growers vs the rest, animal food per adult equivalent:\n")
    print(as.data.frame(cs))
  }

  ## ======================= 10.5 FIGURE =================================== #
  bp <- basket %>% filter(!is.na(share_of_asf_spend))
  g1 <- ggplot(bp, aes(factor(qt), share_of_asf_spend, fill=product)) +
    geom_col() +
    labs(title=paste0(cc, ": the animal-food basket, poorest to richest"),
         subtitle="Composition of spending on animal-source food, by welfare quintile",
         x="Welfare quintile", y="% of animal-food spending", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_basket.png"))), g1, width=8, height=4.5, dpi=200)

  g2 <- ggplot(pv, aes(factor(qt), prot_g_ae_day, fill=factor(year))) +
    geom_col(position="dodge") +
    labs(title=paste0(cc, ": animal protein per adult equivalent per day"),
         subtitle="Grams. The WHO reference for total protein is about 50 g/day.",
         x="Welfare quintile", y="g/day from animal sources", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_protein.png"))), g2, width=8, height=4.5, dpi=200)

  g3 <- ggplot(pv, aes(factor(qt), n_products, fill=factor(year))) +
    geom_col(position="dodge") +
    labs(title=paste0(cc, ": variety — how many animal products a household eats"),
         subtitle="The margin that neither quantity nor quality captures",
         x="Welfare quintile", y="distinct products", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_variety.png"))), g3, width=8, height=4.5, dpi=200)

  g4 <- ggplot(fm %>% filter(!is.na(e_quantity_ae)) %>%
                 select(product, Participation=e_participation,
                        Quantity=e_quantity_ae, Quality=e_quality) %>%
                 pivot_longer(-product, names_to="margin", values_to="e"),
               aes(product, e, fill=margin)) +
    geom_col(position="dodge") + coord_flip() +
    labs(title=paste0(cc, ": the income response, three margins, product by product"),
         x=NULL, y="Elasticity", fill=NULL) + TH
  ggsave(file.path(FIGDIAG, paste0("zz_", paste0(cc,"_margins.png"))), g4, width=9, height=5, dpi=200)

  message("written -> ", RES_DIR, " and ", FIGD)
}
}
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 11 - L'EFFETTO QUALITA' MANCA DAVVERO? REDDITO PERMANENTE E TRANSITORIO
##
##  PERCHE'   Gli effetti fissi familiari (PARTE 9) danno un'elasticita' della
##            qualita' vicina a zero, che sembra contraddire sia il confronto fra
##            famiglie (0,13 per la carne in Etiopia) sia la teoria. Prima di
##            accettarlo bisogna escludere tre cose. Ognuna e' una regressione,
##            non un'opinione.
##
##  11.1 REDDITO PERMANENTE CONTRO TRANSITORIO.
##      Gli effetti fissi usano le variazioni di reddito dentro la famiglia, che
##      sono in gran parte rumore da un anno all'altro. Comprare PIU' carne e'
##      una decisione immediata e reversibile; cambiare macellaio e taglio e'
##      un'abitudine, e le abitudini rispondono al reddito PERMANENTE. Se la
##      qualita' risponde alla parte permanente e la quantita' a quella
##      transitoria, le due stime rispondono a domande diverse e sono giuste
##      entrambe.
##      TEST: il log del benessere di ogni famiglia si divide nella sua media
##      sulle wave (permanente) e nello scarto dalla media (transitorio), e le
##      due parti entrano separate. Un coefficiente grande sulla media e piccolo
##      sullo scarto e' il segnale.
##
##  11.2 DIFFERENZE LUNGHE.
##      Si confronta la PRIMA e l'ULTIMA osservazione di ogni famiglia. Una
##      variazione di reddito su dieci anni e' persistente, una su un anno no.
##      Se la qualita' ricompare sulle differenze lunghe, 11.1 e' confermato.
##
##  11.3 ATTENUAZIONE.
##      Il benessere e' misurato con errore. Gli effetti fissi amplificano
##      l'attenuazione, perche' il rapporto segnale/rumore e' peggiore dentro la
##      famiglia che fra famiglie. Un effetto piccolo come la qualita' ne soffre
##      molto di piu' di uno grande come la quantita'.
##      TEST: si ristima con il benessere MEDIO della famiglia, che media via
##      l'errore. Se il coefficiente sale, il problema era l'attenuazione.
##
##  11.4 DOVE AVVIENE DAVVERO IL MIGLIORAMENTO.
##      Il valore unitario al kg misura la qualita' DENTRO un prodotto. Ma in un
##      paese povero il miglioramento e' FRA prodotti: lasciare il latte per la
##      carne. Il costo per grammo di proteine lo cattura ed e' confrontabile fra
##      prodotti. Qui la quota della qualita' si riporta in entrambi i modi.
##
##  Solo paesi panel (il Malawi non lo e'). Tabelle XXX_30 - XXX_33.
##
###############################################################################
###############################################################################
if (exists("RUN_PERM") && !RUN_PERM) message("PART 7 skipped") else {

perm_out <- list()

for (pf in list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  message("\n########## PERMANENT vs TRANSITORY: ", cc, " ##########")
  raw <- read.csv(pf, stringsAsFactors=FALSE)

  d <- raw %>%
    mutate(hhid    = as.character(hhid),
           qty_pur = num(if ("purch_std" %in% names(.)) purch_std else purch_kg),
           welfare = num(if ("welfare" %in% names(.)) welfare else nom_totcons_aeq),
           weight  = num(if ("hhweight" %in% names(.)) hhweight else weight),
           adulteq = pmax(num(adulteq), 1), uv = num(uv),
           unconv  = ifelse(is.na(num(unconv)), 0, num(unconv))) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight),
           l_ae = log(adulteq))
  ## v21 (M12): il benessere e' nominale (Etiopia, Nigeria) o deflazionato solo
  ## dentro la wave (Tanzania). La media di una famiglia sulle wave mescolava
  ## quindi il suo reddito con l'inflazione degli anni in cui e' stata
  ## osservata. Per questo il log del benessere si prende rispetto alla sua
  ## media pesata nell'anno (una riga per famiglia); con gli effetti dell'anno
  ## in ogni modello questo non cambia nient'altro.
  ym <- d %>% filter(track == "A", welfare > 0) %>% distinct(hhid, year, .keep_all = TRUE) %>%
    group_by(year) %>% summarise(lx_year = weighted.mean(log(welfare), weight), .groups = "drop")
  d <- d %>% left_join(ym, by = "year") %>%
    filter(track == "A", product %in% c("meat_agg","milk","eggs","coffee"),
           welfare > 0, uv > 0, qty_pur > 0, unconv == 0)

  ## collega le wave (panel_ids(), PARTE 9)
  pids <- try(panel_ids(cc), silent=TRUE)
  if (inherits(pids,"try-error") || is.null(pids) || !nrow(pids)) {
    message("no panel link for ", cc, " — skipped"); next
  }
  d <- d %>% left_join(pids, by=c("hhid","wave"), relationship="many-to-one") %>%
    filter(!is.na(pid))

  ## solo famiglie osservate in piu' di una wave
  d <- d %>% group_by(product, pid) %>% filter(n_distinct(year) > 1) %>% ungroup()
  if (!nrow(d)) { message("panel too thin"); next }

  ## il log del benessere si divide in una parte PERMANENTE (la media della
  ## famiglia) e una TRANSITORIA (lo scarto dalla media)
  d <- d %>% group_by(product, pid) %>%
    mutate(l_x      = log(welfare) - lx_year,
           lx_perm  = mean(l_x, na.rm=TRUE),
           lx_trans = l_x - lx_perm) %>% ungroup()

  ## ---------------- 11.1 permanente contro transitorio ------------------ #
  pt <- function(g) {
    if (nrow(g) < 120 || n_distinct(g$pid) < 60) return(tibble())
    gv <- function(m,k) if (inherits(m,"try-error") || !(k %in% names(coef(m))))
            c(NA,NA,NA) else c(coef(m)[k], se(m)[k], pvalue(m)[k])
    ## qui niente effetti fissi familiari: il termine permanente E' la parte fra
    ## famiglie
    mq <- try(feols(log(uv)      ~ lx_perm + lx_trans + l_ae | year,
                    g, weights=~weight, cluster=~pid), silent=TRUE)
    mn <- try(feols(log(qty_pur) ~ lx_perm + lx_trans + l_ae | year,
                    g, weights=~weight, cluster=~pid), silent=TRUE)
    qp <- gv(mq,"lx_perm"); qt <- gv(mq,"lx_trans")
    np <- gv(mn,"lx_perm"); nt <- gv(mn,"lx_trans")
    tibble(n_obs=nrow(g), n_hh=n_distinct(g$pid),
           qual_permanent=qp[1], se_qual_perm=qp[2], p_qual_perm=qp[3],
           qual_transitory=qt[1], se_qual_trans=qt[2], p_qual_trans=qt[3],
           qty_permanent=np[1],  se_qty_perm=np[2],  p_qty_perm=np[3],
           qty_transitory=nt[1], se_qty_trans=nt[2], p_qty_trans=nt[3])
  }
  r1 <- d %>% group_by(product) %>% group_modify(~pt(.x)) %>% ungroup()
  cat("\n--- 7.1 permanent vs transitory income ---\n")
  print(as.data.frame(r1 %>% mutate(across(where(is.numeric), ~round(.x,3)))))
  cat("\n   If qual_permanent >> qual_transitory, quality responds to lasting\n",
      "  income and the fixed-effects zero was answering a different question.\n")

  ## ---------------- 11.2 differenze lunghe ------------------------------ #
  ld <- d %>% group_by(product, pid) %>%
    filter(n() > 1) %>%
    arrange(year, .by_group=TRUE) %>%
    summarise(d_lx  = last(log(welfare)) - first(log(welfare)),
              d_luv = last(log(uv))      - first(log(uv)),
              d_lq  = last(log(qty_pur)) - first(log(qty_pur)),
              d_lae = last(l_ae)         - first(l_ae),
              yrs   = last(year) - first(year),
              pair  = paste(first(year), last(year)),
              weight= first(weight), .groups="drop") %>%
    filter(is.finite(d_lx), is.finite(d_luv), is.finite(d_lq), yrs >= 2)

  ldfit <- function(g) {
    if (nrow(g) < 100) return(tibble())
    gv <- function(m) if (inherits(m,"try-error")) c(NA,NA,NA) else
            c(coef(m)["d_lx"], se(m)["d_lx"], pvalue(m)["d_lx"])
    ## v21 (M12): un effetto per coppia di anni (prima, ultima). Senza,
    ## l'inflazione fra i due anni sta sia in d_lx sia in d_luv, e le coppie piu'
    ## lontane sembrano "famiglie piu' ricche che comprano carne piu' cara".
    a <- gv(try(feols(d_luv ~ d_lx + d_lae | pair, g, weights=~weight, vcov="hetero"), silent=TRUE))
    b <- gv(try(feols(d_lq  ~ d_lx + d_lae | pair, g, weights=~weight, vcov="hetero"), silent=TRUE))
    tibble(n_hh=nrow(g), median_years=median(g$yrs),
           quality_longdiff=a[1], se_qual=a[2], p_qual=a[3],
           quantity_longdiff=b[1], se_qty=b[2], p_qty=b[3],
           quality_share=a[1]/(a[1]+b[1]))
  }
  r2 <- ld %>% group_by(product) %>% group_modify(~ldfit(.x)) %>% ungroup()
  cat("\n--- 7.2 long differences: first vs last observation ---\n")
  print(as.data.frame(r2 %>% mutate(across(where(is.numeric), ~round(.x,3)))))

  ## ---------------- 11.3 attenuazione ----------------------------------- #
  at <- function(g) {
    if (nrow(g) < 120 || n_distinct(g$pid) < 60) return(tibble())
    gv <- function(m,k) if (inherits(m,"try-error") || !(k %in% names(coef(m))))
            NA else unname(coef(m)[k])
    m_cur  <- try(feols(log(uv) ~ l_x     + l_ae | year, g, weights=~weight,
                        cluster=~pid), silent=TRUE)
    m_mean <- try(feols(log(uv) ~ lx_perm + l_ae | year, g, weights=~weight,
                        cluster=~pid), silent=TRUE)
    tibble(n_obs=nrow(g),
           quality_current_welfare = gv(m_cur,"l_x"),
           quality_mean_welfare    = gv(m_mean,"lx_perm"),
           ratio = gv(m_mean,"lx_perm") / gv(m_cur,"l_x"))
  }
  r3 <- d %>% group_by(product) %>% group_modify(~at(.x)) %>% ungroup()
  cat("\n--- 7.3 attenuation: current welfare vs household-mean welfare ---\n")
  print(as.data.frame(r3 %>% mutate(across(where(is.numeric), ~round(.x,3)))))
  cat("\n   A ratio well above 1 means measurement error was flattening the\n",
      "  estimate; the mean averages the error away.\n")

  write.csv(r1, file.path(TMPCSV, paste0(cc,"_30_permanent_transitory.csv")), row.names=FALSE)
  write.csv(r2, file.path(TMPCSV, paste0(cc,"_31_long_differences.csv")), row.names=FALSE)
  write.csv(r3, file.path(TMPCSV, paste0(cc,"_32_attenuation.csv")), row.names=FALSE)
  perm_out[[cc]] <- r1

  ## ---------------- 11.4 qualita' dentro e fra prodotti ----------------- #
  f22 <- file.path(TMPCSV, paste0(cc,"_22_four_margins.csv"))
  d01 <- file.path(TMPCSV, paste0(cc,"_01_decomposition.csv"))
  if (file.exists(f22) && file.exists(d01)) {
    fm  <- read.csv(f22, stringsAsFactors=FALSE)
    dec <- read.csv(d01, stringsAsFactors=FALSE)
    ## v21 (M13): il caffe' non e' un alimento di origine animale (M9); stava in
    ## questa media
    within <- dec %>% filter(product != "coffee") %>%
      summarise(q = mean(e_quality, na.rm=TRUE),
                                e = mean(e_expenditure, na.rm=TRUE))
    cst <- fm %>% filter(grepl("COST", product)) %>% pull(e_quantity_ae)
    prt <- fm %>% filter(grepl("PROTEIN", product)) %>% pull(e_quantity_ae)
    if (length(cst) && length(prt)) {
      comp <- tibble(
        measure = c("WITHIN product (unit value per kg)",
                    "BETWEEN products (cost per gram of protein)"),
        quality_elasticity = round(c(within$q, cst[1]), 3),
        total_elasticity   = round(c(within$e, prt[1] + cst[1]), 3),
        quality_share      = round(c(within$q/within$e, cst[1]/(prt[1]+cst[1])), 3))
      cat("\n--- 7.4 where the upgrading happens ---\n")
      print(as.data.frame(comp))
      cat("\n   Measuring quality only within a product misses the shift BETWEEN\n",
          "  products - dropping milk for meat - which is the real upgrading\n",
          "  margin at these income levels.\n")
      write.csv(comp, file.path(TMPCSV, paste0(cc,"_33_within_vs_between.csv")),
                row.names=FALSE)
    }
  }
}

## ---------------- una figura che riassume la risposta -------------------- #
if (length(perm_out)) {
  pp <- bind_rows(perm_out, .id="country") %>%
    select(country, product, Permanent=qual_permanent, Transitory=qual_transitory) %>%
    pivot_longer(c(Permanent, Transitory), names_to="component", values_to="e") %>%
    filter(!is.na(e))
  if (nrow(pp)) {
    gp <- ggplot(pp, aes(product, e, fill=component)) +
      geom_col(position=position_dodge(.8), width=.7) + coord_flip() +
      facet_wrap(~country) +
      scale_fill_manual(values=c(Permanent="#59A14F", Transitory="#BAB0AC")) +
      labs(title="Quality responds to PERMANENT income, not to year-to-year swings",
           subtitle="Quality elasticity split into the household's own mean income and its deviation",
           x=NULL, y="Quality elasticity", fill=NULL) + TH
    ggsave(file.path(FIGDIAG, paste0("zz_", "PERM_quality_permanent_vs_transitory.png")),
           gp, width=10, height=4.5, dpi=200)
  }
}
}
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 12 - LA FILIERA (ponte verso lo Step II)
##
##  L'IPOTESI che questa parte verifica:
##    investire nella zootecnia crea valore lungo TUTTA la filiera, non solo
##    all'azienda, perche' quando il reddito cresce il valore che passa PER il
##    mercato cresce piu' in fretta della quantita' prodotta nelle aziende.
##
##  Non serve che la quantita' si fermi (e a questi redditi non si ferma). Serve
##  che quattro margini siano positivi insieme:
##    1  ENTRATA          piu' famiglie comprano
##    2  MERCATIZZAZIONE  una parte maggiore di cio' che si mangia e' comprata
##                        invece che autoprodotta
##    3  TRASFORMAZIONE   una parte maggiore di cio' che si compra e' passata da
##                        un impianto
##    4  VALORE UNITARIO  ogni chilo porta piu' valore
##
##  Il rapporto fra l'elasticita' della spesa per acquisti e quella delle
##  proteine consumate qui si chiama "moltiplicatore": sopra 1, la spesa sul
##  mercato cresce piu' in fretta del consumo. ATTENZIONE: non e' un
##  moltiplicatore occupazionale ne' un valore aggiunto. La spesa e' a prezzi al
##  dettaglio; che rappresenti il valore che attraversa la filiera e'
##  ragionevole, non dimostrato (v21, M4).
##
##  Il pesce resta fuori: queste sono le tabelle della filiera ZOOTECNICA; il
##  pesce sta nelle tabelle della dieta (PARTE 10). Figure VC_01..VC_10 in cima
##  alla cartella delle figure; tabelle VC_01..VC_03 del workbook.
##
###############################################################################
###############################################################################
if (exists("RUN_VC") && !RUN_VC) message("PART 8 skipped") else {

VCFIG <- FIGDIR      # qui stanno le dieci figure principali
PAL7  <- c("#4E79A7","#F28E2B","#59A14F","#E15759","#B07AA1","#76B7B2","#EDC948",
           "#FF9DA7","#9C755F","#BAB0AC")
THV <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold", size=12),
        plot.subtitle=element_text(colour="grey35", size=9),
        panel.grid.minor=element_blank(), strip.text=element_text(face="bold"),
        legend.position="bottom")

## proteine per unita' standard (come nella PARTE 10)
PROT_VC <- tibble::tribble(
  ~product,      ~prot,
  "beef",260, "goat_sheep",250, "pork",250, "poultry",270, "meat_agg",255,
  "fish",200, "eggs_kg",126, "eggs",6.9, "milk",33, "milk_processed",250,
  "cheese",200, "coffee",0)
## v21 (M5): pesce fuori. v24: resta fuori qui - sono le tabelle della filiera
## zootecnica (Step II); il pesce e' nelle tabelle della dieta (PARTE 10)
ANIM <- c("beef","goat_sheep","pork","poultry","eggs","milk","milk_processed",
          "cheese")

## vc_load(): legge un pannello e tiene solo le colonne che servono, con tipi
## espliciti; traccia B, prodotti animali, proteine, taglio dello 0,1% piu'
## alto di ogni flusso, quinti per famiglia.
vc_load <- function(pf) {
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  ## Si costruisce una tabella esplicita, con tipi fissati, invece di portarsi
  ## dietro tutte le colonne. I pannelli dei paesi non hanno lo stesso schema
  ## (clusterid e' testo in un paese e numero in un altro) e bind_rows si
  ## rifiuta di unirli.
  g <- function(...) { for (n in c(...)) if (n %in% names(raw)) return(raw[[n]])
                       rep(NA, nrow(raw)) }
  tibble(
    country = cc,
    hhid    = as.character(g("hhid")),
    year    = num(g("year")),
    wave    = as.character(g("wave")),
    track   = as.character(g("track")),
    product = as.character(g("product")),
    std     = if ("std" %in% names(raw)) as.character(raw$std) else "kg",
    qtot    = num(g("qty_std","qty_kg")),
    qpur    = num(g("purch_std","purch_kg")),
    own     = num(g("own_std","own_kg")),
    gift    = num(g("gift_std","gift_kg")),
    exp     = num(g("exp")),
    cons    = num(g("consumed")),
    uv      = num(g("uv")),
    welfare = num(g("welfare","nom_totcons_aeq")),
    adulteq = pmax(num(g("adulteq")), 1),
    weight  = num(g("hhweight","weight")),
    region  = as.character(g("region"))
  ) %>%
    mutate(weight = ifelse(is.na(weight) | weight <= 0, 1, weight)) %>%
    filter(track == "B", product %in% ANIM) %>%
    left_join(PROT_VC %>% rename(prot = prot), by="product") %>%
    mutate(prot = ifelse(product=="eggs" & std=="kg", 126, prot),
           ## v21 (D17): i prodotti del latte della Tanzania (panna, yogurt) sono
           ## in litri
           prot = ifelse(product=="milk_processed" & std=="litre", 33, prot),
           ## si taglia lo 0,1% piu' alto di ogni flusso: una famiglia che dichiara
           ## tonnellate puo' decidere la media di un anno intero
           across(c(qtot,qpur,own,gift,exp), ~ pmin(.x, quantile(.x, .999, na.rm=TRUE)))) %>%
    hh_quintile()                # v24 (M16)
}

vc <- map_dfr(list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE),
              vc_load)
LABV <- c(beef="Beef", goat_sheep="Goat & sheep", pork="Pork", poultry="Poultry",
          eggs="Eggs", milk="Fresh milk", milk_processed="Milk, processed",
          cheese="Cheese", fish="Fish")
vc$lab <- unname(LABV[vc$product])

## ============ 1. MERCATIZZAZIONE: comprato contro autoprodotto ============ #
mk <- vc %>% filter(!is.na(qt)) %>%
  mutate(p = coalesce(qpur,0), o = coalesce(own,0), g = coalesce(gift,0)) %>%
  group_by(country, lab, qt) %>%
  summarise(tot = sum(p+o+g), Purchased = sum(p)/tot*100,
            `Own production` = sum(o)/tot*100, Gifts = sum(g)/tot*100,
            .groups="drop") %>% filter(tot > 0) %>%
  select(-tot) %>%
  pivot_longer(c(Purchased,`Own production`,Gifts), names_to="source", values_to="pct")

g1 <- ggplot(mk, aes(factor(qt), pct, fill=source)) +
  geom_col(width=.85) + facet_grid(country ~ lab) +
  scale_fill_manual(values=c(Purchased="#4E79A7", `Own production`="#59A14F",
                             Gifts="#F28E2B")) +
  labs(title="The value chain forming: what is bought, what is grown at home",
       subtitle="Share of the quantity consumed, by welfare quintile. A widening blue band is the market taking over.",
       x="Welfare quintile (1 = poorest)", y="% of quantity consumed", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_01_marketisation_by_quintile.png"), g1, width=13, height=7, dpi=200)

## ============ 2. IL PANIERE CAMBIA FORMA ================================= #
## v21 (M10): dentro l'anno, pesato, poi media sulle wave (come nella PARTE 10)
bk <- vc %>% filter(!is.na(qt), coalesce(exp,0) > 0) %>%
  group_by(country, year, qt) %>% mutate(tot = sum(exp * weight, na.rm=TRUE)) %>%
  group_by(country, year, qt, lab) %>%
  summarise(s = 100*sum(exp * weight, na.rm=TRUE)/first(tot), .groups="drop") %>%
  group_by(country, qt, lab) %>% summarise(share = mean(s, na.rm=TRUE), .groups="drop")
g2 <- ggplot(bk, aes(factor(qt), share, fill=lab)) +
  geom_col(width=.85) + facet_wrap(~country, nrow=1) +
  scale_fill_manual(values=PAL7) +
  labs(title="The basket does not just grow — it changes shape",
       subtitle="Composition of spending on animal-source food, poorest fifth to richest",
       x="Welfare quintile", y="% of animal-food spending", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_02_basket_composition.png"), g2, width=11, height=5, dpi=200)

## ============ 3. VALORE DI MERCATO CONTRO QUANTITA' ====================== #
vq <- vc %>% filter(!is.na(qt)) %>%
  group_by(country, qt) %>%
  ## v21 (M4): quantita' in grammi di PROTEINE (kg, litri e uova a pezzi non si
  ## sommano), ed entrambe le serie pesate sulla popolazione
  summarise(qty = sum(coalesce(qtot,0) * coalesce(prot,0) * weight) / sum(weight),
            val = sum(coalesce(exp,0) * weight) / sum(weight), .groups="drop") %>%
  group_by(country) %>%
  mutate(`Protein consumed` = 100*qty/qty[which.min(qt)],
         `Purchase spending` = 100*val/val[which.min(qt)]) %>%
  ungroup() %>%
  select(country, qt, `Protein consumed`, `Purchase spending`) %>%
  pivot_longer(-c(country,qt), names_to="series", values_to="idx")
g3 <- ggplot(vq, aes(qt, idx, colour=series)) +
  geom_line(linewidth=1) + geom_point(size=2) + facet_wrap(~country, nrow=1) +
  scale_colour_manual(values=c(`Protein consumed`="#4E79A7",
                               `Purchase spending`="#E15759")) +
  scale_x_continuous(breaks=1:5) +
  labs(title="Spending on purchases vs protein consumed, by income",
       subtitle="Index, poorest quintile = 100. Spending is at retail prices, not value added.",
       x="Welfare quintile", y="Index (Q1 = 100)", colour=NULL) + THV
ggsave(file.path(VCFIG,"VC_03_value_vs_quantity.png"), g3, width=11, height=4.5, dpi=200)

## ============ 4. FRESCO CONTRO TRASFORMATO (Nigeria) ===================== #
fp <- vc %>% filter(country=="NGA", product %in% c("milk","milk_processed"),
                    !is.na(qt)) %>%
  group_by(qt, lab) %>%
  summarise(part = 100*weighted.mean(coalesce(qtot,0) > 0, weight, na.rm=TRUE),
            .groups="drop")
if (nrow(fp)) {
  g4 <- ggplot(fp, aes(factor(qt), part, fill=lab)) +
    geom_col(position=position_dodge(.8), width=.7) +
    scale_fill_manual(values=c(`Fresh milk`="#59A14F", `Milk, processed`="#4E79A7")) +
    labs(title="Nigeria: the demand for processing plants, measured",
         subtitle="Fresh milk falls with income; powdered and tinned milk rises. That gap is a dairy industry.",
         x="Welfare quintile", y="% of households consuming", fill=NULL) + THV
  ggsave(file.path(VCFIG,"VC_04_fresh_vs_processed.png"), g4, width=8, height=4.5, dpi=200)
}

## ============ 5. DOVE SONO I PUNTI DI TRASFORMAZIONE ===================== #
## per regione: quota acquistata e valore unitario rispetto alla mediana
## nazionale; regioni con almeno 100 famiglie
tp <- vc %>% filter(!is.na(region), region != "NA", product %in%
                      c("beef","meat_agg","milk","milk_processed","poultry")) %>%
  mutate(p = coalesce(qpur,0), o = coalesce(own,0)) %>%
  group_by(country, region) %>%
  summarise(n_hh        = n_distinct(hhid),
            market_share= 100*sum(p)/pmax(sum(p+o), 1),
            uv_med      = median(uv[uv > 0], na.rm=TRUE),
            uv_rel      = NA_real_, .groups="drop") %>%
  group_by(country) %>%
  mutate(uv_rel = 100*uv_med/median(uv_med, na.rm=TRUE)) %>% ungroup() %>%
  filter(n_hh >= 100, is.finite(uv_rel))
if (nrow(tp)) {
  g5 <- ggplot(tp, aes(market_share, uv_rel, size=n_hh, colour=country)) +
    geom_hline(yintercept=100, linetype="dashed", colour="grey60") +
    geom_point(alpha=.75) + scale_colour_manual(values=PAL7) +
    scale_size_continuous(range=c(2,9)) +
    labs(title="Where a plant would find both a margin and a market",
         subtitle="Each point is a region. Right = product already moves through markets. Up = prices above the national median.",
         x="% of animal-source food that is purchased", y="Unit value, national median = 100",
         colour=NULL, size="households") + THV
  ggsave(file.path(VCFIG,"VC_05_transformation_map.png"), g5, width=9, height=6, dpi=200)
}

## ============ 6. IL "MOLTIPLICATORE", SCOMPOSTO ========================== #
## elasticita' al reddito, a livello di famiglia, di: proteine consumate,
## spesa per acquisti, quota acquistata (mercatizzazione), numero di prodotti
elas <- function(d, dep) {
  d <- d %>% filter(is.finite(.data[[dep]]), .data[[dep]] > 0, welfare > 0)
  if (nrow(d) < 200) return(NA_real_)
  ## v21 (M6): effetti regione x anno, come in tutti gli altri modelli
  m <- try(feols(as.formula(paste0("log(", dep, ") ~ log(welfare) + log(adulteq) | region^year")),
                 d, weights=~weight, vcov="hetero"), silent=TRUE)
  if (inherits(m,"try-error")) return(NA_real_)
  unname(coef(m)["log(welfare)"])
}
hh <- vc %>% group_by(country, year, region, hhid, welfare, adulteq, weight) %>%
  ## v21 (M4): proteine, non una somma di kg + litri + uova
  summarise(q_all = sum(coalesce(qtot,0) * coalesce(prot,0)),
            v_mkt = sum(coalesce(exp,0)),
            n_prod= sum(coalesce(qtot,0) > 0 | coalesce(cons,0) == 1),   # v21 (D14)
            share_pur = sum(coalesce(qpur,0)) /
                        pmax(sum(coalesce(qpur,0)+coalesce(own,0)), 1e-9),
            .groups="drop")
mult <- hh %>% group_by(country) %>% group_modify(function(g, ...) {
  eq <- elas(g, "q_all"); ev <- elas(g, "v_mkt")
  ep <- elas(g %>% filter(share_pur > 0), "share_pur")
  en <- elas(g %>% filter(n_prod > 0), "n_prod")
  ## v21 (M4): cosa sono davvero i due numeri - consumo (con l'autoproduzione)
  ## in proteine; spesa per acquisti a prezzi al dettaglio, che NON e' valore
  ## aggiunto lungo la filiera
  tibble(`Protein consumed`=eq, `Purchase spending`=ev,
         `Marketisation`=ep, `Variety`=en,
         multiplier = ev/eq)
}) %>% ungroup()
cat("\n--- THE VALUE-CHAIN MULTIPLIER ---\n")
print(as.data.frame(mult %>% mutate(across(where(is.numeric), ~round(.x,3)))))
cat("\n   multiplier = elasticity of purchase spending / elasticity of protein consumed.\n",
    "  Above 1: spending on purchases grows faster than consumption. Spending is at\n",
    "  retail prices, so this is NOT value added along the chain (v21, M4).\n")
write.csv(mult, file.path(TMPCSV, "VC_01_multiplier.csv"), row.names=FALSE)

g6 <- mult %>% select(country, `Protein consumed`, `Purchase spending`) %>%
  pivot_longer(-country, names_to="k", values_to="e") %>%
  ggplot(aes(country, e, fill=k)) +
  geom_col(position=position_dodge(.8), width=.7) +
  geom_text(aes(label=sprintf("%.2f", e)), position=position_dodge(.8),
            vjust=-.4, size=3) +
  scale_fill_manual(values=c(`Protein consumed`="#4E79A7", `Purchase spending`="#E15759")) +
  labs(title="Income elasticity: protein consumed vs spending on purchases",
       subtitle="Animal-source food. Spending is at retail prices: it is not value added along the chain",
       x=NULL, y="Elasticity", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_06_multiplier.png"), g6, width=8, height=4.5, dpi=200)

## ============ 7. PROTEINE ================================================ #
pr <- vc %>% filter(!is.na(qt)) %>%
  group_by(country, year, hhid, adulteq, weight, qt) %>%
  summarise(p_day = sum(coalesce(qtot,0)*coalesce(prot,0))/first(adulteq)/7,
            .groups="drop") %>%
  group_by(country, qt) %>%
  summarise(g = weighted.mean(p_day, weight, na.rm=TRUE), .groups="drop")
g7 <- ggplot(pr, aes(factor(qt), g, fill=country)) +
  geom_col(position=position_dodge(.8), width=.7) +
  geom_hline(yintercept=25, linetype="dashed", colour=RED <- "grey40") +
  scale_fill_manual(values=PAL7) +
  labs(title="Animal protein per adult equivalent per day",
       subtitle="Grams. Dashed line: roughly half the WHO total-protein reference of ~50 g.",
       x="Welfare quintile", y="g/day from animal sources", fill=NULL) + THV
ggsave(file.path(VCFIG,"VC_07_protein.png"), g7, width=9, height=4.5, dpi=200)

## ============ 8. GRIGLIA DELLA PARTECIPAZIONE ============================ #
pg <- vc %>% filter(!is.na(qt)) %>% group_by(country, lab, qt) %>%
  summarise(part = 100*weighted.mean(coalesce(qtot,0) > 0, weight, na.rm=TRUE),
            .groups="drop")
g8 <- ggplot(pg, aes(factor(qt), lab, fill=part)) +
  geom_tile(colour="white", linewidth=.6) +
  geom_text(aes(label=round(part)), size=2.8,
            colour=ifelse(pg$part > 45, "white", "grey15")) +
  facet_wrap(~country, nrow=1) +
  scale_fill_gradient(low="#EAF0F7", high="#1F3864", name="% of hh") +
  labs(title="Who eats what, and at which income",
       subtitle="Share of households consuming each product, by welfare quintile",
       x="Welfare quintile", y=NULL) + THV
ggsave(file.path(VCFIG,"VC_08_participation_grid.png"), g8, width=11, height=5, dpi=200)

## ============ 9. MERCATIZZAZIONE NEL TEMPO =============================== #
mt <- vc %>% mutate(p = coalesce(qpur,0), o = coalesce(own,0)) %>%
  group_by(country, year, lab) %>%
  summarise(pct = 100*sum(p)/pmax(sum(p+o),1e-9), n = n(), .groups="drop") %>%
  filter(n >= 300)
g9 <- ggplot(mt, aes(year, pct, colour=lab)) +
  geom_line(linewidth=.8) + geom_point(size=1.6) +
  facet_wrap(~country, nrow=1, scales="free_x") +
  scale_colour_manual(values=PAL7) +
  labs(title="The chain is also forming over time, not only across incomes",
       subtitle="Share of the quantity consumed that was bought rather than produced at home",
       x=NULL, y="% purchased", colour=NULL) + THV
ggsave(file.path(VCFIG,"VC_09_marketisation_over_time.png"), g9, width=12, height=4.5, dpi=200)

## ============ 10. STATISTICHE DESCRITTIVE E TABELLA COMPLETA ============= #
desc <- vc %>% group_by(country, year, lab) %>%
  summarise(n_hh        = n_distinct(hhid),
            pct_consume = round(100*weighted.mean(coalesce(qtot,0) > 0 | coalesce(cons,0) == 1, weight, na.rm=TRUE),1),
            pct_buy     = round(100*weighted.mean(coalesce(qpur,0) > 0 | coalesce(exp,0) > 0, weight, na.rm=TRUE),1),
            med_qty_ae  = round(median((qtot/adulteq)[qtot > 0], na.rm=TRUE),3),
            med_uv      = round(median(uv[uv > 0], na.rm=TRUE),1),
            pct_purchased_of_qty = round(100*sum(coalesce(qpur,0))/
                                   pmax(sum(coalesce(qpur,0)+coalesce(own,0)),1e-9),1),
            .groups="drop")
write.csv(desc, file.path(TMPCSV, "VC_02_descriptive_statistics.csv"), row.names=FALSE)

hhsum <- hh %>% group_by(country, year) %>%
  summarise(households   = n_distinct(hhid),
            products_avg = round(weighted.mean(n_prod, weight, na.rm=TRUE),2),
            mkt_share    = round(100*weighted.mean(share_pur, weight, na.rm=TRUE),1),
            .groups="drop")
write.csv(hhsum, file.path(TMPCSV, "VC_03_household_summary.csv"), row.names=FALSE)

d1 <- ggplot(hhsum, aes(factor(year), households, fill=country)) +
  geom_col(position="dodge") + scale_fill_manual(values=PAL7) +
  labs(title="Households per wave", x=NULL, y=NULL, fill=NULL) + THV +
  theme(legend.position="none")
d2 <- ggplot(hhsum, aes(year, products_avg, colour=country)) +
  geom_line(linewidth=.8) + geom_point() + scale_colour_manual(values=PAL7) +
  labs(title="Animal products per household", x=NULL, y=NULL, colour=NULL) + THV
d3 <- ggplot(hhsum, aes(year, mkt_share, colour=country)) +
  geom_line(linewidth=.8) + geom_point() + scale_colour_manual(values=PAL7) +
  labs(title="% of quantity bought on the market", x=NULL, y=NULL, colour=NULL) + THV
d4 <- ggplot(desc %>% group_by(country, year) %>%
               summarise(p = mean(pct_consume), .groups="drop"),
             aes(year, p, colour=country)) +
  geom_line(linewidth=.8) + geom_point() + scale_colour_manual(values=PAL7) +
  labs(title="Average participation across products", x=NULL, y="%", colour=NULL) + THV

if (requireNamespace("patchwork", quietly=TRUE)) {
  library(patchwork)
  dash <- (d1 | d2) / (d3 | d4) +
    patchwork::plot_annotation(
      title = "Descriptive dashboard: three countries, fourteen waves",
      theme = theme(plot.title=element_text(face="bold", size=13)))
  ggsave(file.path(VCFIG,"VC_10_descriptive_dashboard.png"), dash,
         width=12, height=7.5, dpi=200)
} else {
  ggsave(file.path(VCFIG,"VC_10a_households.png"), d1, width=7, height=4, dpi=200)
  ggsave(file.path(VCFIG,"VC_10b_variety.png"),    d2, width=7, height=4, dpi=200)
  ggsave(file.path(VCFIG,"VC_10c_market_share.png"),d3, width=7, height=4, dpi=200)
  ggsave(file.path(VCFIG,"VC_10d_participation.png"),d4, width=7, height=4, dpi=200)
}

cat("\n--- DESCRIPTIVE STATISTICS (head) ---\n")
print(as.data.frame(head(desc, 15)))
message("value-chain figures written -> ", VCFIG)
}
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 13 - CONFRONTO CON I BILANCI ALIMENTARI FAO (v24, 15 nov 2026)
##
##  COSA FA   Confronta quello che dichiarano le famiglie (LSMS, ultimi 7 giorni)
##            con quello che i bilanci alimentari FAO dicono disponibile per
##            persona, prodotto per prodotto, negli stessi paesi e anni - come
##            Desiere et al. (2018, Global Food Security 16) per una wave per
##            paese, qui per tutte le 23. Inoltre: quanta parte dell'offerta
##            nazionale di ogni prodotto e' importata (utile per lo Step II).
##            Tabelle FAO_01, FAO_02; figura FAO_01.
##
##  Servono i file FAOSTAT (Africa) accanto agli archivi delle indagini:
##    FoodBalanceSheets_E_Africa.zip          (dal 2010)
##    FoodBalanceSheetsHistoric_E_Africa.zip  (fino al 2013, usato solo per il 2008)
##  Se mancano, la parte si salta.
##
##  DA LEGGERE PRIMA DI USARE I NUMERI
##  - Il bilancio FAO e' OFFERTA, non consumo: produzione + importazioni -
##    esportazioni - mangimi, sementi, perdite, diviso la popolazione. Comprende
##    il cibo mangiato fuori casa e lo spreco; le quantita' delle indagini no.
##  - La carne FAO e' a peso carcassa; il latte in equivalente latte (polvere e
##    formaggio riportati a latte liquido); il pesce a peso VIVO (un chilo di
##    pesce secco sono circa tre di pesce vivo). Il latte delle indagini qui e'
##    solo latte fresco; il pesce e' il peso comprato, fresco e secco insieme.
##  - Le quantita' delle indagini esistono solo dove le unita' si convertono
##    (colonna coverage = quota delle famiglie che consumano con una quantita'
##    convertita). Pollame e pesce in Uganda e pesce in Malawi non sono quasi
##    mai pesati: li' il numero dell'indagine non e' una misura e il rapporto
##    non si riporta.
##  - Gli anni delle indagini coprono due anni solari: il valore FAO e' la media
##    dell'anno dell'etichetta e del successivo (per il Malawi 2024 solo il 2023,
##    l'ultimo anno FAO).
##  - kg_trim100 esclude le quantita' oltre 100 volte la mediana paese-anno-
##    prodotto fra chi consuma (i 10.000 kg di maiale di una famiglia ugandese nel
##    2019 portavano la media nazionale da 1,3 a 29,8 kg per persona). Il rapporto
##    usa kg_trim100. Dalla v24 (M17) i pannelli escludono gia' queste quantita',
##    quindi kg_trim100 deve coincidere con kg_raw: resta come controllo.
##  Anche i prezzi alla produzione FAO sono stati guardati e non si usano: per
##  questi cinque paesi finiscono prima o all'inizio degli anni delle indagini
##  (Nigeria 2008, Tanzania 2004, Malawi 2017, Etiopia 2018, niente per l'Uganda).
##
###############################################################################
###############################################################################
## trova uno zip FAOSTAT nelle cartelle dei dati
fao_zip <- function(stem) {
  roots <- unique(c(DATA_ROOT, dirname(OUT_DIR), ARCH_ROOT))
  f <- unlist(lapply(roots, function(r) list.files(r, pattern = paste0("^", stem, "\\.zip$"),
                                                   full.names = TRUE)))
  if (length(f)) f[1] else NA_character_
}
TH <- theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"), legend.position = "bottom")
fz_new <- fao_zip("FoodBalanceSheets_E_Africa")
fz_old <- fao_zip("FoodBalanceSheetsHistoric_E_Africa")
if (is.na(fz_new)) {
  message("PART 8b: FoodBalanceSheets_E_Africa.zip not found - FAO benchmark skipped")
} else {

## nomi dei paesi, codici dei prodotti e degli elementi nei file FAO
FAO_AREA <- c("Malawi" = "MWI", "Ethiopia" = "ETH", "Uganda" = "UGA",
              "United Republic of Tanzania" = "TZA", "Nigeria" = "NGA")
FAO_ITEM <- c("2731" = "beef", "2732" = "goat_sheep", "2733" = "pork", "2734" = "poultry",
              "2949" = "eggs", "2848" = "milk", "2960" = "fish")
FAO_ELEM <- c("645" = "kg_cap", "5511" = "production_kt", "5611" = "imports_kt",
              "5911" = "exports_kt")

## legge un file dei bilanci alimentari dallo zip, senza estrarlo, e tiene solo
## paesi, prodotti ed elementi che servono, in formato lungo (un anno per riga)
read_fbs <- function(zf) {
  inner <- grep("_NOFLAG\\.csv$", unzip(zf, list = TRUE)$Name, value = TRUE)[1]
  d <- read.csv(unz(zf, inner), fileEncoding = "latin1", check.names = FALSE,
                stringsAsFactors = FALSE)
  d <- d[d$Area %in% names(FAO_AREA) & as.character(d$`Item Code`) %in% names(FAO_ITEM) &
         as.character(d$`Element Code`) %in% names(FAO_ELEM), ]
  yc <- grep("^Y[0-9]{4}$", names(d), value = TRUE)
  d %>% select(Area, `Item Code`, `Element Code`, all_of(yc)) %>%
    pivot_longer(all_of(yc), names_to = "year", values_to = "v") %>%
    transmute(country = unname(FAO_AREA[Area]), year = as.integer(sub("^Y", "", year)),
              product = unname(FAO_ITEM[as.character(`Item Code`)]),
              element = unname(FAO_ELEM[as.character(`Element Code`)]), v = num(v)) %>%
    filter(!is.na(v))
}
fbs <- read_fbs(fz_new)
if (!is.na(fz_old)) fbs <- bind_rows(fbs, read_fbs(fz_old) %>% filter(year < min(fbs$year)))

## ---- lato indagine: kg per persona per anno, nazionale, per prodotto ----- #
## kg settimanali x 52, sommati con i pesi, divisi la popolazione stimata
## (somma dei pesi x numero di membri).
lsms_pc <- list()
for (pf in list.files(OUT_DIR, pattern = "^panel_[A-Z]{3}\\.csv$", full.names = TRUE)) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[, 2]
  raw <- read.csv(pf, stringsAsFactors = FALSE)
  g1  <- function(...) { for (n in c(...)) if (n %in% names(raw)) return(raw[[n]]); rep(NA, nrow(raw)) }
  d <- tibble(hhid = as.character(raw$hhid), year = num(raw$year), product = raw$product,
              track = raw$track, std = if ("std" %in% names(raw)) raw$std else "kg",
              q = num(g1("qty_std", "qty_kg")), consumed = num(g1("consumed")),
              n = num(g1("hhsize", "hh_size")), w = num(g1("hhweight", "weight"))) %>%
    filter(track == "B", n > 0, w > 0) %>%
    mutate(q = ifelse(std == "piece", q * 0.055, q),           # uova: 55 g l'una
           cons = coalesce(consumed, 0) == 1 | coalesce(q, 0) > 0) %>%
    group_by(year, product) %>%
    mutate(med = median(q[q > 0], na.rm = TRUE),
           q_trim = ifelse(!is.na(q) & q > 100 * med, NA_real_, q)) %>% ungroup()
  pop <- d %>% distinct(hhid, year, .keep_all = TRUE) %>% group_by(year) %>%
    summarise(pop = sum(w * n), .groups = "drop")
  lsms_pc[[cc]] <- d %>% group_by(year, product) %>%
    summarise(kg_raw     = 52 * sum(w * coalesce(q, 0)),
              kg_trim100 = 52 * sum(w * coalesce(q_trim, 0)),
              n_trimmed  = sum(!is.na(q) & is.na(q_trim)),
              pct_consuming = 100 * sum(w * cons) / sum(w),
              coverage   = sum(w * (cons & coalesce(q, 0) > 0)) / max(sum(w * cons), 1e-9),
              .groups = "drop") %>%
    left_join(pop, by = "year") %>%
    mutate(country = cc, kg_raw = kg_raw / pop, kg_trim100 = kg_trim100 / pop) %>%
    select(-pop)
}
lsms_pc <- bind_rows(lsms_pc)

fao_kg <- fbs %>% filter(element == "kg_cap")
fao_at <- function(c, y, p) {
  ys <- if (y < max(fao_kg$year)) c(y, y + 1) else max(fao_kg$year)
  v <- fao_kg$v[fao_kg$country == c & fao_kg$product == p & fao_kg$year %in% ys]
  if (length(v)) mean(v) else NA_real_
}
MEATS <- c("beef", "goat_sheep", "pork", "poultry")
lv <- lsms_pc %>% filter(product %in% c(MEATS, "eggs", "milk", "fish")) %>% mutate(meats_included = NA_character_)
## carne totale sulle carni che l'indagine pesa davvero (coverage >= 0,5),
## confrontata con il totale FAO sulle STESSE carni (Uganda: niente pollame)
meat_tot <- lsms_pc %>% filter(product %in% MEATS, coverage >= 0.5) %>% group_by(country, year) %>%
  summarise(kg_raw = sum(kg_raw), kg_trim100 = sum(kg_trim100), n_trimmed = sum(n_trimmed),
            pct_consuming = NA_real_, coverage = min(coverage),
            meats_included = paste(product, collapse = "+"), .groups = "drop") %>%
  mutate(product = "meat")
lv <- bind_rows(lv, meat_tot)
lv$fao_kg <- mapply(function(c, y, p, mi)
  if (p == "meat") sum(sapply(strsplit(mi, "+", fixed = TRUE)[[1]], function(m) fao_at(c, y, m)))
  else fao_at(c, y, p),
  lv$country, lv$year, lv$product, lv$meats_included)
lv <- lv %>%
  mutate(ratio_lsms_fao = ifelse(coverage >= 0.5 & fao_kg > 0, kg_trim100 / fao_kg, NA_real_),
         country = factor(country, intersect(c("MWI", "ETH", "UGA", "TZA", "NGA"), unique(country)))) %>%
  arrange(product, country, year) %>%
  mutate(across(c(kg_raw, kg_trim100, fao_kg, pct_consuming), ~ round(.x, 2)),
         across(c(coverage, ratio_lsms_fao), ~ round(.x, 2)))
cat("\n--- 8b.1 kg per person per year: survey (trimmed) / FAO food balance ---\n")
print(as.data.frame(lv %>% select(product, country, year, kg_trim100, fao_kg, ratio_lsms_fao, coverage)))
write.csv(lv, file.path(TMPCSV, "FAO_01_levels_lsms_vs_fbs.csv"), row.names = FALSE)

## ---- quota importata dell'offerta nazionale ---------------------------- #
imp <- fbs %>% filter(element %in% c("production_kt", "imports_kt", "exports_kt")) %>%
  pivot_wider(names_from = element, values_from = v) %>%
  mutate(supply_kt = production_kt + coalesce(imports_kt, 0) - coalesce(exports_kt, 0),
         import_share = ifelse(supply_kt > 0, 100 * coalesce(imports_kt, 0) / supply_kt, NA_real_)) %>%
  filter(year >= 2008) %>% arrange(country, product, year) %>%
  mutate(across(where(is.numeric) & !year, ~ round(.x, 1)))
cat("\n--- 8b.2 imports as % of national supply (FBS, milk in milk equivalent) ---\n")
print(as.data.frame(imp %>% filter(year %in% c(2010, 2014, 2018, 2022)) %>%
        select(country, product, year, import_share) %>%
        pivot_wider(names_from = year, values_from = import_share)))
write.csv(imp, file.path(TMPCSV, "FAO_02_import_share.csv"), row.names = FALSE)

## ---- figura: indagine contro FAO nel tempo, carne, latte e pesce -------- #
fp <- bind_rows(
  lv %>% filter(product %in% c("meat", "milk", "fish"), coverage >= 0.5) %>%
    transmute(country, year, product, source = "Household survey (LSMS)", kg = kg_trim100),
  fao_kg %>% filter(product %in% c("milk", "fish"), year >= 2008) %>%
    transmute(country, year, product, source = "FAO food balance", kg = v),
  ## carne FAO sulle carni che l'indagine di ogni paese pesa (Uganda: niente
  ## pollame; Etiopia: manzo e capra/pecora)
  fao_kg %>% filter(product %in% MEATS, year >= 2008,
                    !(country == "UGA" & product == "poultry"),
                    !(country == "ETH" & product %in% c("poultry", "pork"))) %>%
    group_by(country, year) %>% summarise(kg = sum(v), .groups = "drop") %>%
    mutate(product = "meat", source = "FAO food balance")) %>%
  mutate(country = factor(country, c("MWI", "ETH", "UGA", "TZA", "NGA"),
                          c("Malawi", "Ethiopia", "Uganda", "Tanzania", "Nigeria")),
         product = factor(product, c("meat", "milk", "fish"), c("Meat", "Milk", "Fish")))
gf <- ggplot(fp, aes(year, kg, colour = source)) +
  geom_line(data = fp %>% filter(source == "FAO food balance")) +
  geom_point(data = fp %>% filter(source != "FAO food balance"), size = 2) +
  facet_grid(product ~ country, scales = "free_y") +
  scale_colour_manual(values = c("FAO food balance" = "grey45", "Household survey (LSMS)" = "#1F5FA8")) +
  labs(title = "Household surveys and FAO food balances: kg per person per year",
       subtitle = "Meat = the meats the survey weighs (Uganda without poultry, Ethiopia beef and goat & mutton). FAO: supply incl. waste and food away from home; meat in carcass weight, milk in milk equivalent, fish in live weight.\nSurvey: 7-day recall x 52, only where units convert for at least half of consumers.",
       x = NULL, y = "kg per person per year", colour = NULL) + TH
ggsave(file.path(FIGDIR, "FAO_01_lsms_vs_fbs.png"), gf, width = 12, height = 7, dpi = 200)
}


###############################################################################
###############################################################################
##
##  PARTE 14 - TRE MARGINI, INTERVALLI DEI DISEGNI PANEL, CAFFE' IN ETIOPIA
##
##  14.1 TRE MARGINI (v22) - il risultato principale dell'articolo.
##       La spesa media per un prodotto, su chi compra e chi no, e' P x q x uv:
##       la quota di famiglie che comprano, i kg che compra un acquirente, il
##       prezzo al kg che paga. La sua elasticita' alla spesa totale e' quindi
##       la somma di
##         entrata  = (dP / dlog x) / P   piu' famiglie cominciano a comprare
##         quantita' =  dlog q  / dlog x   chi compra compra piu' kg
##         qualita'  =  dlog uv / dlog x   chi compra paga di piu' al kg
##       (McDonald & Moffitt 1980). La decomposizione di Deaton della PARTE 7
##       copre solo gli ultimi due. Qui: wave messe insieme, effetti regione x
##       anno, pesi dell'indagine, valori unitari tagliati all'1-99% dentro ogni
##       anno; errori standard e intervalli delle quote con il bootstrap sulle
##       coppie famiglia-anno (MARGINS_B ripetizioni, seme fisso 42, quindi
##       risultati identici a ogni esecuzione). Tabella MARGINS_01.
##       NOTA: "compra" = ha comprato negli ultimi 7 giorni.
##  14.2 INTERVALLI DEI DISEGNI PANEL. L'elasticita' della qualita' dai quattro
##       disegni panel (reddito permanente, reddito transitorio, effetti fissi
##       familiari, differenze lunghe) con errori standard e intervalli al 95%
##       in una tabella sola (PANEL_01).
##  14.3 CAFFE' IN ETIOPIA. Chi beve, compra e coltiva caffe', anno per anno;
##       quanto valgono le vendite di caffe' per chi lo coltiva; se chi coltiva
##       compra carne piu' spesso degli altri a parita' di spesa, regione e anno.
##       Solo Etiopia: in Tanzania il modulo alimentare mette insieme caffe' e
##       cacao, e in Nigeria quasi nessuno lo coltiva (COFFEE_01-03).
##
###############################################################################
###############################################################################
if (exists("RUN_MARGINS") && !RUN_MARGINS) message("PART 9 skipped") else {
if (!exists("MARGINS_B")) MARGINS_B <- 100
## paesi in ordine di PIL pro capite (PARTE 8), quelli costruiti
CC_ORDER <- c("MWI", "ETH", "UGA", "TZA", "NGA")
TH <- theme_minimal(base_size=10) +
  theme(plot.title=element_text(face="bold"), panel.grid.minor=element_blank(),
        strip.text=element_text(face="bold"))

## solo il coefficiente di l_x; gli errori standard vengono dal bootstrap
cx <- function(f, g) {
  m <- try(suppressMessages(feols(f, g, weights = ~weight, vcov = "iid", lean = TRUE)),
           silent = TRUE)
  if (inherits(m, "try-error") || !("l_x" %in% names(coef(m)))) NA_real_ else unname(coef(m)["l_x"])
}
## three(): i tre margini per un prodotto in un paese. Entrata = pendenza della
## probabilita' di comprare (modello lineare) divisa per la quota che compra;
## quantita' e qualita' come nella PARTE 7, fra chi compra con valore unitario.
three <- function(g, ctrl) {
  P  <- weighted.mean(g$buys, g$weight)
  sl <- cx(as.formula(paste("buys ~ l_x +", ctrl, "| ry")), g)
  b  <- g %>% filter(uv > 0, qty > 0, unconv == 0) %>% group_by(year) %>%
    filter(uv >= quantile(uv, .01), uv <= quantile(uv, .99)) %>% ungroup()
  ## v24: quantita' e qualita' solo dove i valori unitari coprono abbastanza
  ## acquirenti (MIN_UV_SHARE: il pesce ne vuole la meta'); servono almeno 200
  ## valori unitari
  ok <- nrow(b) >= 200 && !(g$product[1] %in% names(MIN_UV_SHARE) &&
                             nrow(b) < MIN_UV_SHARE[[g$product[1]]] * sum(g$buys))
  c(P = P, slope = sl, entry = sl / P,
    qty  = if (ok) cx(as.formula(paste("log(qty) ~ l_x +", ctrl, "| ry")), b) else NA_real_,
    qual = if (ok) cx(as.formula(paste("log(uv)  ~ l_x +", ctrl, "| ry")), b) else NA_real_,
    n_uv = nrow(b))
}

## ---------------- 14.1 tre margini ---------------------------------------- #
marg <- list()
for (pf in list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$", full.names=TRUE)) {
  cc  <- str_match(basename(pf), "panel_([A-Z]{3})")[,2]
  raw <- read.csv(pf, stringsAsFactors=FALSE)
  d   <- prep(raw)                                   # prep() della PARTE 7
  cv  <- c("l_ae", "urban")
  for (v in c("share_child","share_elderly","head_age","head_female"))
    if (v %in% names(raw) && mean(!is.na(raw[[v]])) > .5) { d[[v]] <- as.numeric(raw[[v]]); cv <- c(cv, v) }
  ctrl <- paste(cv, collapse = " + ")
  ## v24: il pesce dove c'e' in ogni wave (tutti tranne l'Etiopia, dove e'
  ## separato solo dal 2015)
  prods <- c("meat_agg", "milk", "eggs", if (cc == "ETH") "coffee",
             if (any(raw$product == "fish" & raw$track == "A")) "fish")
  d <- d %>% filter(track == "A", product %in% prods, welfare > 0) %>%
    filter(if_all(all_of(cv), ~ !is.na(.x))) %>%
    mutate(ry   = paste(as.character(region), year, sep = "_"),
           buys = as.integer(coalesce(qty > 0, FALSE) | coalesce(exp > 0, FALSE)))
  message("\n########## THREE MARGINS: ", cc, " ##########  (", MARGINS_B, " bootstrap draws)")
  for (p in prods) {
    g <- d %>% filter(product == p)
    if (sum(g$buys) < 100) next
    e <- three(g, ctrl)
    ## bootstrap: si ricampionano le coppie famiglia-anno con reinserimento e si
    ## ristimano i tre margini MARGINS_B volte
    rows <- split(seq_len(nrow(g)), paste(g$hhid, g$year))
    set.seed(42)
    bt <- t(replicate(MARGINS_B, {
      gb <- g[unlist(rows[sample.int(length(rows), replace = TRUE)], use.names = FALSE), ]
      three(gb, ctrl)[c("entry", "qty", "qual")]
    }))
    sh <- bt / rowSums(bt); tot <- sum(e[c("entry", "qty", "qual")])
    q  <- function(x, a) unname(quantile(x, a, na.rm = TRUE))
    marg[[paste(cc, p)]] <- tibble(
      country = cc, product = p, n = nrow(g), n_buyers = sum(g$buys), n_unit_values = e[["n_uv"]],
      P = e[["P"]], slope = e[["slope"]],
      e_entry = e[["entry"]], se_entry = sd(bt[, 1]),
      e_qty   = e[["qty"]],   se_qty   = sd(bt[, 2]),
      e_qual  = e[["qual"]],  se_qual  = sd(bt[, 3]),
      e_total = tot,
      sh_entry = e[["entry"]] / tot, sh_entry_lo = q(sh[, 1], .025), sh_entry_hi = q(sh[, 1], .975),
      sh_qty   = e[["qty"]]   / tot,
      sh_qual  = e[["qual"]]  / tot, sh_qual_lo  = q(sh[, 3], .025), sh_qual_hi  = q(sh[, 3], .975),
      bootstrap_draws = MARGINS_B)
    message(sprintf("  %-9s entry %.3f  quantity %.3f  quality %.3f  -> shares %.0f / %.0f / %.0f %%",
                    p, e[["entry"]], e[["qty"]], e[["qual"]],
                    100 * e[["entry"]] / tot, 100 * e[["qty"]] / tot, 100 * e[["qual"]] / tot))
  }
}
if (length(marg)) {
  mg <- bind_rows(marg)
  write.csv(mg, file.path(TMPCSV, "MARGINS_01_three_margins.csv"), row.names = FALSE)
  pl <- mg %>% filter(product != "coffee", !is.na(sh_qty)) %>%
    select(country, product, Entry = sh_entry, Quantity = sh_qty, Quality = sh_qual) %>%
    pivot_longer(c(Entry, Quantity, Quality), names_to = "margin", values_to = "share") %>%
    mutate(margin = factor(margin, c("Quality", "Quantity", "Entry")),
           country = factor(country, intersect(CC_ORDER, unique(country))))
  gm <- ggplot(pl, aes(product, 100 * share, fill = margin)) + geom_col(width = .7) +
    coord_flip() + facet_wrap(~country) +
    scale_fill_manual(values = c(Entry = "#4E79A7", Quantity = "#F28E2B", Quality = "#59A14F"),
                      breaks = c("Entry", "Quantity", "Quality")) +
    labs(title = "Most of the income response is more households buying, not dearer food",
         subtitle = "Share of the expenditure elasticity of mean spending: entry, quantity, quality",
         x = NULL, y = "% of the elasticity", fill = NULL) + TH
  ggsave(file.path(FIGDIR, "MARGINS_three_margins.png"), gm, width = 10, height = 4, dpi = 200)
}

## ---------------- 14.2 intervalli dei disegni panel ----------------------- #
rd <- function(f) { f <- file.path(TMPCSV, f); if (file.exists(f)) read.csv(f, stringsAsFactors = FALSE) else NULL }
ci <- list()
for (cc in CC_ORDER) {
  pt <- rd(paste0(cc, "_30_permanent_transitory.csv"))
  fe <- rd(paste0(cc, "_12_household_FE.csv"))
  ld <- rd(paste0(cc, "_31_long_differences.csv"))
  one <- function(t, design, b, s, p) if (is.null(t) || !all(c(b, s, p) %in% names(t))) NULL else
    tibble(country = cc, product = t$product, design = design, b = t[[b]], se = t[[s]], p = t[[p]])
  ci[[cc]] <- bind_rows(
    one(pt, "Permanent income",        "qual_permanent",   "se_qual_perm",  "p_qual_perm"),
    one(pt, "Transitory income",       "qual_transitory",  "se_qual_trans", "p_qual_trans"),
    one(fe, "Household fixed effects", "e_quality_FE",     "se_quality",    "p_quality"),
    one(ld, "Long differences",        "quality_longdiff", "se_qual",       "p_qual"))
}
ci <- bind_rows(ci)
if (nrow(ci)) {
  ci <- ci %>% mutate(lo = b - 1.96 * se, hi = b + 1.96 * se) %>% arrange(country, product)
  write.csv(ci, file.path(TMPCSV, "PANEL_01_quality_intervals.csv"), row.names = FALSE)
  cp <- ci %>% filter(product == "meat_agg") %>%
    mutate(design = factor(design, rev(c("Permanent income", "Transitory income",
                                         "Household fixed effects", "Long differences"))),
           country = factor(country, intersect(CC_ORDER, unique(country))))
  gc <- ggplot(cp, aes(b, design)) + geom_vline(xintercept = 0, colour = "grey60") +
    geom_errorbar(aes(xmin = lo, xmax = hi), width = .2, orientation = "y") + geom_point(size = 2) +
    facet_wrap(~country) +
    labs(title = "Meat quality responds to lasting income far more than to year-to-year changes",
         subtitle = "Quality (unit value) elasticity with 95% interval, households seen in more than one wave",
         x = "Quality elasticity", y = NULL) + TH
  ggsave(file.path(FIGDIR, "PANEL_meat_quality_intervals.png"), gc, width = 10, height = 3.5, dpi = 200)
}

## ---------------- 14.3 caffe' in Etiopia ---------------------------------- #
pe <- file.path(OUT_DIR, "panel_ETH.csv")
if (file.exists(pe)) {
  e <- read.csv(pe, stringsAsFactors = FALSE) %>% filter(track == "A") %>%
    mutate(hhid = as.character(hhid), w = num(weight), w = ifelse(is.na(w) | w <= 0, 1, w),
           across(any_of(c("coffee_grower","coffee_sale_birr","total_cons_ann","nom_totcons_aeq",
                           "purch_kg","own_kg","qty_kg","exp","consumed","adulteq")), num))
  if (all(c("coffee_grower", "coffee_sale_birr", "total_cons_ann") %in% names(e))) {
    message("\n########## COFFEE: ETH ##########")
    cf <- e %>% filter(product == "coffee") %>%
      mutate(buys = as.integer(coalesce(purch_kg > 0, FALSE) | coalesce(exp > 0, FALSE)),
             cons = as.integer(coalesce(qty_kg > 0, FALSE) | coalesce(consumed == 1, FALSE)),
             own  = as.integer(coalesce(own_kg > 0, FALSE)),
             grower = coalesce(coffee_grower, 0), sale = coalesce(coffee_sale_birr, 0))
    wm <- function(x, w) 100 * weighted.mean(x, w)
    c1 <- cf %>% group_by(year) %>%
      summarise(n = n(), pct_consume = wm(cons, w), pct_buy = wm(buys, w),
                pct_own_production = wm(own, w), pct_grower = wm(grower, w),
                n_growers = sum(grower), pct_sell_coffee = wm(sale > 0, w))
    c2 <- cf %>% filter(grower == 1) %>% mutate(sale_share = sale / total_cons_ann) %>%
      group_by(year) %>%
      summarise(n_growers = n(), n_sellers = sum(sale > 0),
                median_sales_pct_of_consumption = 100 * median(sale_share, na.rm = TRUE),
                median_among_sellers = 100 * median(sale_share[sale > 0], na.rm = TRUE),
                pct_consume = wm(cons, w), pct_buy = wm(buys, w), pct_own_production = wm(own, w))
    ## il 2011 resta fuori: l'elenco delle colture del 2011 non identifica
    ## bene chi coltiva
    mt <- e %>% filter(product == "meat_agg", nom_totcons_aeq > 0, year >= 2013) %>%
      left_join(cf %>% distinct(hhid, year, grower), by = c("hhid", "year")) %>%
      mutate(grower = coalesce(grower, 0),
             buys = as.integer(coalesce(purch_kg > 0, FALSE) | coalesce(exp > 0, FALSE)),
             l_x = log(nom_totcons_aeq), l_ae = log(pmax(adulteq, 1)),
             ry = paste(region, year, sep = "_"))
    m <- feols(buys ~ grower + l_x + l_ae | ry, mt, weights = ~w, cluster = ~ea_id)
    c3 <- tibble(years = "2013-2021", n = nobs(m),
                 b_grower = unname(coef(m)["grower"]), se_grower = unname(se(m)["grower"]),
                 p_grower = unname(pvalue(m)["grower"]), b_log_expenditure = unname(coef(m)["l_x"]),
                 pct_buy_meat_growers = with(mt[mt$grower == 1, ], wm(buys, w)),
                 pct_buy_meat_others  = with(mt[mt$grower == 0, ], wm(buys, w)))
    print(as.data.frame(c1 %>% mutate(across(where(is.numeric), ~ round(.x, 1)))))
    print(as.data.frame(c3 %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
    write.csv(c1, file.path(TMPCSV, "COFFEE_01_ETH_by_year.csv"), row.names = FALSE)
    write.csv(c2, file.path(TMPCSV, "COFFEE_02_ETH_growers.csv"), row.names = FALSE)
    write.csv(c3, file.path(TMPCSV, "COFFEE_03_ETH_meat_growers.csv"), row.names = FALSE)
  }
}
}
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 15 - UN SOLO WORKBOOK CON TUTTE LE TABELLE
##
##  COSA FA   Ogni tabella scritta come CSV temporaneo dalle parti precedenti
##            diventa un foglio di RESULTS_<data>.xlsx (nome del foglio = nome
##            della tabella, al massimo 31 caratteri come vuole Excel), con un
##            foglio CONTENTS che fa da indice. Poi la cartella dei CSV
##            temporanei si cancella.
##
###############################################################################
###############################################################################
csvs <- sort(list.files(TMPCSV, pattern="\\.csv$", full.names=TRUE))
if (length(csvs)) {
  wb <- createWorkbook()
  hdr <- createStyle(textDecoration="bold", fgFill="#1F3864",
                     fontColour="#FFFFFF", halign="center", border="Bottom")
  ## un foglio indice, cosi' il workbook si spiega da solo
  idx <- tibble(sheet = character(), file = character(), rows = integer())
  for (f in csvs) {
    nm <- tools::file_path_sans_ext(basename(f))
    sh <- substr(gsub("[^A-Za-z0-9_]", "_", nm), 1, 31)   # Excel accetta al massimo 31 caratteri
    d  <- read.csv(f, stringsAsFactors=FALSE)
    addWorksheet(wb, sh)
    writeData(wb, sh, d, headerStyle=hdr)
    freezePane(wb, sh, firstRow=TRUE)
    setColWidths(wb, sh, cols=1:max(1,ncol(d)), widths="auto")
    idx <- bind_rows(idx, tibble(sheet=sh, file=basename(f), rows=nrow(d)))
  }
  addWorksheet(wb, "CONTENTS"); worksheetOrder(wb) <- c(nrow(idx)+1, seq_len(nrow(idx)))
  writeData(wb, "CONTENTS", idx, headerStyle=hdr)
  setColWidths(wb, "CONTENTS", cols=1:3, widths="auto")
  xlsx <- file.path(RUN_DIR, paste0("RESULTS_", RUN_STAMP, ".xlsx"))
  saveWorkbook(wb, xlsx, overwrite=TRUE)
  message("workbook  -> ", xlsx, "  (", nrow(idx), " sheets)")
  unlink(TMPCSV, recursive=TRUE)          # un workbook, niente CSV sparsi
}

message("\n=== ALL DONE ===")
message("  results  -> ", RUN_DIR)
message("  figures  -> ", FIGDIR, "   (VC_01..VC_10 first, zz_* are diagnostics)")
message("  panels   -> ", OUT_DIR)
###############################################################################


###############################################################################
###############################################################################
##
##  PARTE 16 - CONFRONTO CON I RISULTATI DI RIFERIMENTO
##
##  PERCHE'   Ogni modifica al codice deve dire cosa cambia nei risultati. In
##            results_reference/ (accanto a code/) c'e' il workbook prodotto
##            dallo stesso codice sugli stessi archivi. Il piu' recente si
##            confronta con quello appena scritto, foglio per foglio e cella per
##            cella:
##              IDENTICAL        ogni numero entro 1e-6 (relativo), etichette uguali
##              ~same (<0.1%)    differenza massima sotto 1e-3 (arrotondamenti,
##                               versioni dei pacchetti, numero di processori)
##              NUMBERS DIFFER / LABELS DIFFER / DIFFERENT SHAPE   qualcosa e'
##                               cambiato: va capito prima di usare i risultati
##            Se nessuna modifica e' voluta, deve uscire "OK".
##            Il confronto completo si salva in COMPARISON_with_reference.csv.
##
###############################################################################
###############################################################################
message(sprintf("\nrun time: %.0f minutes", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

compare_workbooks <- function(old, new, pat = ".") {
  so <- openxlsx::getSheetNames(old); sn <- openxlsx::getSheetNames(new)
  so <- setdiff(so[grepl(pat, so)], "CONTENTS"); sn <- setdiff(sn[grepl(pat, sn)], "CONTENTS")
  res <- list()
  for (s in setdiff(so, sn)) res[[s]] <- data.frame(sheet = s, status = "ONLY IN REFERENCE", detail = "")
  for (s in setdiff(sn, so)) res[[s]] <- data.frame(sheet = s, status = "ONLY IN NEW RUN", detail = "")
  for (s in sort(intersect(so, sn))) {
    o <- openxlsx::read.xlsx(old, s); n <- openxlsx::read.xlsx(new, s)
    if (!identical(dim(o), dim(n)) || !identical(names(o), names(n))) {
      res[[s]] <- data.frame(sheet = s, status = "DIFFERENT SHAPE",
                             detail = sprintf("reference %dx%d, new %dx%d", nrow(o), ncol(o), nrow(n), ncol(n)))
      next
    }
    ## colonne numeriche: differenza relativa massima; colonne di testo: uguali?
    num <- names(o)[sapply(o, is.numeric) & sapply(n, is.numeric)]
    chr <- setdiff(names(o), num)
    bad <- chr[!sapply(chr, function(k) identical(as.character(o[[k]]), as.character(n[[k]])))]
    d <- sapply(num, function(k) { x <- o[[k]]; y <- n[[k]]
      if (!identical(is.na(x), is.na(y))) return(Inf)
      m <- !is.na(x); if (!any(m)) 0 else max(abs(x[m] - y[m]) / pmax(1e-9, abs(x[m]))) })
    worst <- if (length(d)) max(d) else 0
    res[[s]] <- data.frame(sheet = s,
      status = if (length(bad)) "LABELS DIFFER" else if (worst < 1e-6) "IDENTICAL" else
               if (worst < 1e-3) "~same (<0.1%)" else "NUMBERS DIFFER",
      detail = if (length(bad)) paste("column", bad[1]) else
               if (length(d) && worst > 0) sprintf("max rel. diff %.3g in %s", worst, names(d)[which.max(d)]) else "")
  }
  out <- do.call(rbind, res); rownames(out) <- NULL
  out[order(out$status != "IDENTICAL", out$sheet), ]
}

ref_dir <- file.path(dirname(CODE_DIR), "results_reference")
refs <- sort(list.files(ref_dir, pattern = "^RESULTS_.*[.]xlsx$", full.names = TRUE), decreasing = TRUE)
new_xlsx <- file.path(RUN_DIR, paste0("RESULTS_", RUN_STAMP, ".xlsx"))
if (!length(refs)) {
  message("\nno reference workbook in ", ref_dir, " - comparison skipped")
} else if (file.exists(new_xlsx)) {
  cmp <- compare_workbooks(refs[1], new_xlsx)
  write.csv(cmp, file.path(RUN_DIR, "COMPARISON_with_reference.csv"), row.names = FALSE)
  ok <- cmp$status %in% c("IDENTICAL", "~same (<0.1%)")
  message("\n=== CHECK against ", basename(refs[1]), " ===")
  print(table(cmp$status))
  if (all(ok)) {
    message("OK: all ", nrow(cmp), " tables match the reference.")
  } else {
    message("ATTENTION: ", sum(!ok), " of ", nrow(cmp), " tables differ from the reference:")
    print(cmp[!ok, ], row.names = FALSE, right = FALSE)
  }
  message("full list -> ", file.path(RUN_DIR, "COMPARISON_with_reference.csv"))
}
###############################################################################
## FINE
###############################################################################
