# Animal-source food demand in sub-Saharan Africa — PhD, Step I

Domanda di alimenti di origine animale (carne, latte, uova) al crescere del reddito, da panel familiari
LSMS-ISA della Banca Mondiale: Etiopia, Tanzania, Nigeria.

Paolo Medei — AGRISYSTEM Doctoral School, Università Cattolica del Sacro Cuore.

## Stato

- `code/pipeline/` parte dalla v20 del 30 settembre 2026, tagliata nei suoi blocchi (PART). Il primo
  commit è identico byte per byte a `code/legacy/ASF_ALL_IN_ONE_v20.R`; la v20, rifatta girare dai dati
  grezzi il 12 novembre, riproduce la run del 30 settembre.
- Ogni commit successivo "v21: …" corregge un errore, con i numeri prima e dopo nel messaggio.
  Registro completo: `docs/FINDINGS.md`. Numeri delle slide, v20 e v21: `docs/SLIDE_TRACE.md`.
- La run sul PC di Paolo (Windows, 12 novembre) coincide cella per cella con quella di riferimento;
  i suoi warning hanno fatto trovare D9 e D10.
- Aperto: M11 (strumento per la spesa totale, da discutere con il Professore).
- Informazioni su produzione zootecnica e caffè, per dopo: `docs/PRODUZIONE_E_CAFFE.md`.

## Struttura

```
code/run_all.R          esegue i moduli in ordine
code/pipeline/          00_setup … 10_workbook (la pipeline)
code/legacy/            v20 originale e ANALISI_semplice.R (5 ottobre), per riferimento
checks/                 varmap.R, varmap2.R: ogni colonna usata, con l'etichetta del file
                        compare_runs.R: confronto cella per cella tra due RESULTS_*.xlsx
docs/                   registro degli errori, tracciamento delle slide, mappe delle variabili
```

## Dati

I dati grezzi **non** vanno nel repository: le condizioni d'uso della Banca Mondiale non ne permettono
la ridistribuzione (`.gitignore` li esclude). Servono 13 archivi in formato Stata, nella stessa cartella:

| Paese | Wave | Catalogo Microdata Library |
|---|---|---|
| Etiopia | 2011, 2013, 2015, 2018, 2021 | 2053, 2247, 2783, 3823, 6161 |
| Tanzania | 2008, 2010, 2012, 2014, 2020 | 76 (v02), 1050, 2252, 2862, 5639 |
| Nigeria | 2010, 2012, 2015 | 1002, 1952, 2734 |

Nigeria 2018 (catalogo 3557) è esclusa: oggi non è scaricabile.

## Come si esegue

```
Rscript code/run_all.R
```

In RStudio: aprire `code/run_all.R` e premere **Source**. Se accanto a `code/` c'è una cartella `data/`
con i 13 archivi, viene usata quella e i risultati vanno in `data/OUTPUT/`.

Verifica indipendente del numero principale: `python3 checks/independent_nga_tza.py data/_unzipped`.

Lo script cerca da solo la cartella con gli archivi (`ETH_*.zip`, `TZA_*.zip`, `NGA_*.zip`) in
Desktop, Documents o OneDrive; altrimenti si imposta `DATA_ROOT` in `code/pipeline/00_setup.R`.
Pacchetti: haven, dplyr, tidyr, stringr, purrr, labelled, ggplot2, fixest, openxlsx, patchwork.
Le verifiche del 12 novembre sono state fatte con R 4.4.3 e fixest 0.14.2.
