# Animal-source food demand in sub-Saharan Africa — PhD, Step I

Domanda di alimenti di origine animale (carne, latte, uova) al crescere del reddito, da indagini familiari
LSMS-ISA della Banca Mondiale: Etiopia, Tanzania, Nigeria, Uganda (panel) e Malawi (indagini trasversali).

Paolo Medei — AGRISYSTEM Doctoral School, Università Cattolica del Sacro Cuore.

## Stato

- **Dal 21 novembre il codice è un file solo: `code/ASF_completo.R`**, diviso in 17 parti (PARTE 0-16),
  con le spiegazioni in italiano: cosa si fa, perché e come. Il codice è identico a quello dei 15 moduli
  di prima (verificato confrontando il codice analizzato da R, espressione per espressione) e i risultati
  coincidono cella per cella con `results_reference/`. I moduli restano nella storia del repository.
- La pipeline parte dalla v20 del 30 settembre 2026 (`code/legacy/ASF_ALL_IN_ONE_v20.R`); la v20, rifatta
  girare dai dati grezzi il 12 novembre, riproduce la run del 30 settembre.
- Ogni commit successivo "v21: …" corregge un errore, con i numeri prima e dopo nel messaggio.
  Registro completo: `docs/FINDINGS.md`. Numeri delle slide, v20 e v21: `docs/SLIDE_TRACE.md`.
- La run sul PC di Paolo (Windows, 12 novembre) coincide cella per cella con quella di riferimento;
  i suoi warning hanno fatto trovare D9 e D10.
- 13 novembre: verifica indipendente colonna per colonna dei tre pannelli e delle stime principali
  (`checks/audit/`); gli errori trovati (D11-D19, M12-M13) sono corretti.
- 13 novembre, v22: in R anche le analisi aggiunte per l'articolo (tre margini con bootstrap,
  intervalli di confidenza dei disegni panel, caffè in Etiopia: oggi PARTE 14); alla fine
  della run il nuovo workbook viene confrontato da solo con quello di `results_reference/`.
- 13 novembre, v23: Uganda (UNPS 2010/11-2019/20, sei wave, panel) e Malawi (IHS 2010, 2016, 2019, 2024,
  quattro indagini trasversali: il panel IHPS è distribuito senza aggregato di consumo) in
  oggi PARTI 6 e 4; trappole e scelte in `docs/FINDINGS.md`, sezione E.
  I due paesi si saltano da soli se i loro archivi non ci sono.
- 15 novembre, v24: il pesce torna come prodotto a sé (non carne) in tutti i paesi, deciso da Paolo;
  confronto con i bilanci alimentari FAO e quota importata dell'offerta (oggi PARTE 13, serve
  FAOSTAT: vedi Dati); corretto il costo per grammo di proteina (M15). `docs/FINDINGS.md`, sezione G.
- 20 novembre, v24 definitiva e nuovo riferimento (`results_reference/RESULTS_v24_2026-11-20.xlsx`, dal 21 novembre `RESULTS_v24_2026-11-21.xlsx` con le tabelle VC_04-05): una regola
  unica per i valori estremi in tutti e cinque i paesi, decisa da Paolo (filtro sul prezzo, quantità e spese
  oltre 100 volte la mediana: M17, M18); seconda verifica indipendente in `checks/audit/v24/REPORT_recheck.md`.
- 21 novembre, v25: la trasformazione misurata con le voci dei prodotti trasformati (PARTE 12, sezioni
  13-15), proteine comprate contro mangiate, fattori di conversione ufficiali con fonte (pollo ugandese
  1,3 kg, FAO; proteine FAO/INFOODS). Riferimento: `results_reference/RESULTS_v25_2026-11-21.xlsx`
  (88 tabelle). `docs/FINDINGS.md`, sezioni J e K.
- 22 novembre: la run di Paolo sul suo PC (Windows) coincide con quella di riferimento in 86 tabelle su 88;
  le altre due differivano solo per gli intervalli bootstrap (ordine delle famiglie dipendente dalla lingua
  del computer, corretto) e per celle vuote. Lo script ora trova `results_reference/` anche se lanciato da
  un'altra cartella.
- 22 novembre, v26: **Step I chiuso** con le prove di robustezza (PARTE 14b, ROB_01: dieci specificazioni,
  il valore al kg resta fra 2 e 10% della risposta della carne); la trasformazione si verifica **solo sui
  latticini**, detto e motivato nel deck; **Step II, parte A**: il lato del produttore dagli stessi
  sondaggi (PARTE 14c: prezzo alla stalla contro prezzo al consumo, chi vende, quanto, a chi; S2A_01-03).
  Riferimento: `results_reference/RESULTS_v26_2026-11-22.xlsx` (92 tabelle). `docs/FINDINGS.md`, sezioni L-N.
- 23 novembre: **dataset armonizzato** sugli alimenti ricchi di proteine, una riga per famiglia e wave
  (127.501 famiglie, 23 wave, 154 voci con risposte grezze e valori armonizzati, totali per categoria,
  documentazione e controlli nel workbook). Codice in `code/dataset/`, spiegazioni in `docs/DATASET.md`;
  i dati di famiglia NON sono nel repository.
- **Come si lancia:** aprire `code/ASF_completo.R` dalla cartella del progetto (non una copia in Download)
  e premere *Source* (Ctrl+Maiusc+S).
- Aperto: M11 (strumento per la spesa totale: la variabile strumentale con la spesa della wave precedente è
  ora una prova di robustezza, S9; resta da discutere con il Professore); EASI; taglio dello 0,1% prodotto per
  prodotto nella PARTE 12 (FINDINGS K); Step II parti B-C (FAOSTAT, SAM IFPRI, UNIDO).
- Informazioni su produzione zootecnica e caffè, per dopo: `docs/PRODUZIONE_E_CAFFE.md`.

## Struttura

```
code/ASF_completo.R     TUTTO: dai file grezzi ai risultati, con le spiegazioni (PARTE 0-16; indice in cima)
results_reference/      RESULTS_*.xlsx della run di riferimento (stesso codice, stessi archivi; il piu' recente per nome e' quello usato)
code/dataset/           dataset armonizzato sulle proteine (docs/DATASET.md); nessun dato di famiglia
code/legacy/            v20 originale e ANALISI_semplice.R (5 ottobre), per riferimento
checks/                 varmap.R, varmap2.R: ogni colonna usata, con l'etichetta del file
                        compare_runs.R: confronto cella per cella tra due RESULTS_*.xlsx
docs/                   registro degli errori, tracciamento delle slide, mappe delle variabili
```

## Dati

I dati grezzi **non** vanno nel repository: le condizioni d'uso della Banca Mondiale non ne permettono
la ridistribuzione (`.gitignore` li esclude). Servono gli archivi in formato Stata, tutti nella stessa cartella (Uganda e Malawi sono facoltativi):

| Paese | Wave | Catalogo Microdata Library |
|---|---|---|
| Etiopia | 2011, 2013, 2015, 2018, 2021 | 2053, 2247, 2783, 3823, 6161 |
| Tanzania | 2008, 2010, 2012, 2014, 2020 | 76 (v02), 1050, 2252, 2862, 5639 |
| Nigeria | 2010, 2012, 2015 | 1002, 1952, 2734 |
| Uganda | 2010/11, 2011/12, 2013/14, 2015/16, 2018/19, 2019/20 | 2166, 2059, 2663, 3460, 3795, 3902 |
| Malawi | IHS3 2010, IHS4 2016, IHS5 2019, IHS6 2024 | archivi `MWI_2010_IHS-III`, `MWI_2016_IHS-IV`, `MWI_2019_IHS-V`, `MWI_2024-2025_IHS-VI` |

Nigeria 2018 (catalogo 3557) è esclusa: oggi non è scaricabile.

Facoltativi, per il confronto con la FAO (PARTE 13; senza, la parte si salta da sola): dalla
pagina FAOSTAT di ogni dominio, "Bulk Downloads" → Africa, nella stessa cartella degli archivi:
`FoodBalanceSheets_E_Africa.zip` (Food Balances 2010-) e `FoodBalanceSheetsHistoric_E_Africa.zip`
(Food Balances -2013, usato solo per la Tanzania 2008).

## Come si esegue

```
Rscript code/ASF_completo.R
```

In RStudio: *Session → Restart R*, poi aprire `code/ASF_completo.R` e premere **Source** (non *Run*),
oppure nella Console `source("C:/Users/<nome>/Desktop/PhD_v21/code/ASF_completo.R")`. Se accanto a `code/` c'è una cartella `data/` con gli archivi, viene usata quella e i
risultati vanno in `data/OUTPUT/run_<data>/`. Alla fine la run stampa `=== CHECK against … ===`: "OK"
se ogni tabella coincide con `results_reference/`, altrimenti l'elenco delle tabelle diverse
(`COMPARISON_with_reference.csv` nella cartella della run).

Verifica indipendente del numero principale: `python3 checks/independent_nga_tza.py data/_unzipped`.

Lo script cerca da solo la cartella con gli archivi (`ETH_*.zip`, `TZA_*.zip`, `NGA_*.zip`) in
Desktop, Documents o OneDrive; altrimenti si imposta `DATA_ROOT` nella PARTE 1 di `code/ASF_completo.R`.
Per rifare solo le stime senza ricostruire i pannelli: `RUN_BUILD <- FALSE` nella PARTE 1.
Pacchetti: haven, dplyr, tidyr, stringr, purrr, labelled, ggplot2, fixest, openxlsx, patchwork.
Le verifiche del 12 novembre sono state fatte con R 4.4.3 e fixest 0.14.2.
