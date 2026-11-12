# Registro degli errori — pipeline v20

Ogni voce dice cosa è sbagliato, come lo si è verificato, cosa cambia nei risultati e se è già corretta.
Le verifiche sono state fatte il 12 novembre 2026 sui 13 archivi grezzi LSMS-ISA, leggendo le
etichette dei file `.dta` (`checks/varmap.R`, `checks/varmap2.R`) e ricostruendo i pannelli da zero.

**Riproducibilità.** La v20, rifatta girare dai dati grezzi, dà stime identiche alla run del
30 settembre 2026 per Etiopia, Tanzania e Nigeria 2010-2015 (tutte le tabelle per anno). Gli errori
standard differiscono di poco per la versione di `fixest` (0.14.2); nessuno dei 249 p-value
controllati cambia soglia di significatività. Gli errori qui sotto sono quindi sistematici, non casuali.

**Verifica indipendente (12/11/2026, dopo le correzioni D1-D5, D7).** `checks/independent_nga_tza.py`
riconta da zero, in Python e senza riusare il codice della pipeline, la quota di famiglie che comprano
carne nel quinto più povero e più ricco. Nigeria: 35,2% / 67,4% (pipeline 35,2% / 67,2%).
Tanzania: 15,5% / 71,8% (pipeline 15,4% / 71,5%). Le piccole differenze vengono dalla definizione di
acquisto (spesa > 0 invece di quantità convertita > 0).

Stato: **aperto** · **corretto in v21** · **deciso**

## A. Errori nei dati (colonna sbagliata o dato perso)

| ID | Problema | Evidenza | Cosa cambia | Stato |
|---|---|---|---|---|
| D1 | **Nigeria 2010: famiglie che non consumano prodotti animali escluse dal campione.** Il codice completa la griglia famiglia × prodotto solo per chi ha almeno una riga di prodotti animali, pesce o caffè. | 4.826 famiglie nel modulo alimentare, 4.353 nel pannello: 473 escluse (9,8%). | Partecipazione Nigeria 2010 sovrastimata di circa l'11%; Q1 (entrata nel mercato) per la Nigeria. | **corretto in v21** (commit cf0adaa): Q1 50,4% → 46,2% |
| D2 | **Nigeria 2010-2015: reddito diviso due volte per la dimensione della famiglia.** `totcons` è già pro capite (etichetta: "Total consumption per capita"); il codice lo divide di nuovo per `hhsize`. | Etichette di `cons_agg_wave1_visit2`, `wave2_visit2`, `wave3_visit2`. | Quintili nigeriani sbagliati (slide 8, 10). Elasticità invariate perché il modello controlla per log(dimensione famiglia). | **corretto in v21** (commit 112da68): comprano carne Q1 46,2% → 35,2%, Q5 54,1% → 67,2% |
| D3 | **Tanzania 2008-2014: reddito = consumo totale della famiglia, non per adulto equivalente.** `expmR` = "Total consumption, annual, real"; solo il 2020 (`expmR_pae`) è per adulto equivalente. | Etichette dei file di consumo NPS 1-5. | Quintili tanzaniani 2008-2014 sbagliati; slide 12 errata. Le stime anno per anno non cambiano; quelle che uniscono le wave sì, perché il 2020 era su una base diversa. | **corretto in v21** (commit 0ac835e): pendenza partecipazione manzo 0,229 → 0,278; elasticità varietà 0,281 → 0,325 |
| D4 | **Tanzania 2012 senza pesi campionari.** Il peso `y3_weight` sta in `HH_SEC_A`, il codice lo cerca in `ConsumptionNPS3`. Pesi mancanti diventano 1 (anche il 2% del 2010). | `hhweight` mancante nel 100% delle righe 2012 del pannello. | Tutte le stime tanzaniane 2012 e i pooled che lo includono. | **corretto in v21** (commit 4e0933a): elasticità quantità carne 2012 0,665 → 0,638 |
| D5 | **Bestiame (esclusione dell'Heckman, proprietari vs non).** Etiopia 2011-2013: codici animali diversi da quelli assunti (1 = bovini, 2 = pecore, 3 = capre, 4-6 equini, 7 = cammelli, 8-13 polli): il gruppo "bovini" 1-6 include pecore, capre ed equini, "polli" 10-12 esclude le galline. Etiopia 2015: variabile del numero di capi inesistente (`ls_s8_1q01` invece di `ls_sec_8_1q01`), quindi nessun dato. Tanzania: `lf02_02` è il numero di capi *al sondaggio precedente* (2014: "due anni fa"), non oggi (`lf02_04_1` + `lf02_04_2`). Tanzania 2008-2010: file del bestiame non trovato. | Etichette e codici di `sect8a_ls_w1/w2`, `sect8_1_ls_w3`, `LF_SEC_02`. | Tabelle `*_13_heckman_instrumented`, `*_23_owners_vs_not`. Non nelle slide. | **corretto in v21**: celle Heckman stimate Etiopia 10 → 14, Tanzania 9 → 14 |
| D6 | **Tanzania 2020: 34 acquisti di uova su 394 scartati.** Unità 20 = "altro", ma il prezzo per unità (350 TSh) coincide con quello per uovo. | Distribuzione di `hh_ja03_1` per l'item 807. | Uova Tanzania 2020 (minore). | **corretto in v21** (decisione del 12/11): lette come uova a pezzi; TZA 2020 uova, acquirenti 352 → 386 |
| D7 | **Test di saturazione silenziosamente vuoto con `fixest` ≥ 0.14.** Il coefficiente viene cercato come `I(l_x^2)`, nome cambiato. | `sat_b2` tutto NA nella nuova run, valorizzato in quella del 30/9. | Colonna `plateau` (non nelle slide). | **corretto in v21** |
| D8 | **Nigeria 2018 non disponibile.** Non scaricabile dalla Banca Mondiale ("Data Access Not Available"); la copia su Drive è incompleta. | 12/11/2026. | Esclusa: 13 wave invece di 14. È anche la wave con il cambio di domanda sulla spesa (vedi M3). | **deciso** (commit 8f2dce4) |

## B. Errori di metodo o di presentazione

| ID | Problema | Stato |
|---|---|---|
| M1 | **"Probit" della slide 8** = modello lineare di probabilità sul *consumo* (Parte 6.3, `e_participation`), non un probit sugli acquisti. Il probit di `ANALISI_semplice.R` è senza pesi e riporta il coefficiente, non l'effetto marginale. | **corretto in v21**: modello lineare pesato sugli acquisti come principale, probit con effetto marginale medio come controllo (coincidono) |
| M2 | **Partecipazione definita in due modi**: acquisto (Parti 3 e 5, quintili) e consumo (Parte 6, Nigeria). | **corretto in v21**: tutto sugli acquisti (decisione del 12/11) |
| M3 | **Nigeria 2018**: spesa = valore dell'ultimo acquisto, quantità acquistata a 30 giorni, ma usata insieme alle altre wave nelle Parti 6 e 8. Superato da D8. | superato |
| M4 | **"Moltiplicatore di filiera"**: somma kg, litri e uova a pezzi (`q_all`); "Market value" è spesa al dettaglio, non valore aggiunto; "Farm quantity" è quantità consumata. | **corretto in v21** (commit 31a5a32): quantità in proteine, etichette corrette; moltiplicatore (v20 del 30/9 → v21) ETH 2,20 → 1,28, TZA 1,21 → 1,04, NGA 0,96 → 0,88. Resta: il valore aggiunto lungo la filiera richiede i margini tra prezzo alla stalla e al consumo |
| M5 | **Pesce nel paniere solo per la Nigeria**: numero di prodotti non confrontabile tra paesi. | **corretto in v21**: pesce escluso ovunque (decisione del 12/11) |
| M6 | **Varietà e moltiplicatore** stimati con soli effetti fissi di anno; la slide 7 dichiara effetti fissi regionali per tutti i modelli. | **corretto in v21** (commit ef54158) |
| M7 | **Nessun effetto fisso familiare per la Nigeria** (`panel_ids()` non ha il ramo NGA). | **corretto in v21** (commit df0d446): 4.387 famiglie nigeriane presenti in tutte e tre le wave |
| M8 | **PIL pro capite** (`INCOME`): valori recenti di un solo anno, non degli anni d'indagine; Tanzania e Nigeria sono lower-middle income. | **corretto in v21**: PIL pro capite PPP (dollari internazionali 2021), media degli anni d'indagine: ETH 2.009, TZA 2.890, NGA 8.374 |
| M9 | **Caffè** incluso nelle stime principali: non è un alimento di origine animale. | **deciso**: il caffè resta come prodotto a sé, fuori dagli aggregati di origine animale (12/11) |
| M10 | **Quote del paniere**: somme di spesa nominale su anni diversi; gli anni con più inflazione pesano di più. | **corretto in v21** (commit ba06ae9): quote anno per anno, pesate, media delle wave |
| M11 | **Endogeneità della spesa totale** come misura di reddito: non trattata (servirebbe uno strumento: reddito o indice di beni). | **aperto**: da discutere con il Professore (strumento: reddito o indice di beni) |
