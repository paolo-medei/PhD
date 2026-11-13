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
| D9 | **Tanzania: panel collegato attraverso i singoli membri, non le famiglie.** Per il 2012 e il 2020 il legame con la wave precedente veniva preso dal ruolo individuale (coppie membro-famiglia precedente): 56 famiglie ricevevano due identificativi e le loro righe erano contate due volte (48 nel 2012, 8 nel 2020). Inoltre la famiglia originale e quelle nate da una sua scissione (*split-off*) avevano lo stesso identificativo anche nella stessa wave (559 casi nel 2010, 1.107 nel 2012, 840 nel 2020): gli effetti fissi "familiari" confrontavano famiglie diverse. | Warning `many-to-many` nella run sul PC di Paolo (12/11); copertina `HH_SEC_A`: `hh_a09` e `hh_a10` (2012), `y4_hhid` e `hh_a10` (2020), `hh_a11` (2010: 1-2 originale, 3 split-off). | Effetti fissi familiari, reddito permanente/transitorio, differenze lunghe della Tanzania; marginalmente le tabelle della Parte 5. | **corretto in v21**: un solo legame per famiglia, preso dalla copertina; la famiglia originale continua l'unità del panel, lo split-off ne inizia una nuova. Carne: qualità sul reddito transitorio 0,047 (p = 0,014) → 0,007 (p = 0,77); sul permanente 0,172 → 0,167; effetto fisso sulla qualità 0,027 → −0,002; famiglie nel panel 2.105 → 1.963; comprano carne Q1 15,4% → 15,3%. Etiopia: 4 casi simili, trascurabili, lasciati |
| D10 | **Probit di controllo non convergente** (Tanzania, latte): 25 iterazioni non bastavano. | Warning "Absence of convergence" nella stessa run. | Solo la colonna `e_part_probit_ame`. | **corretto in v21**: 100 iterazioni; effetto marginale 0,151 → 0,152 |
| D11 | **Nigeria 2010: "altri prodotti del latte" persi.** È il codice 114 nel 2010, 115 dal 2012 (114 diventa formaggio). | Etichette di `item_cd`, audit indipendente (13/11). | 70 famiglie: consumatori di latte trasformato 1.239 → 1.309. | **corretto in v21** |
| D12 | **Nigeria 2012: tabella di conversione in grammi e centilitri letta come kg e litri.** Un uovo pesava 50 kg. | `food_conv_w2ph`: `conv` in grammi se `g_cl` = 1, centilitri se 0. | Uova 2012 (valore unitario mediano 0,6 naira/kg invece di 600), latte trasformato, proteine. Insieme a D11 e D13: quota della qualità della carne 8,3% → 6,5%; costo per grammo di proteina −0,119 → +0,026; elasticità delle proteine 0,903 → 0,765; moltiplicatore 0,88 → 1,04; effetto fisso sulla qualità della carne 0,025 (n.s.) → 0,041 (p = 0,02). | **corretto in v21** |
| D13 | **Nigeria 2010: contenitori convertiti con la capacità scritta nell'etichetta** ("Basin: Small (10 kg)"). 40 bacinelle di pesce diventavano 400 kg; manzo a 25 naira/kg invece di 700. | Audit indipendente. | 382 acquisti ora non convertibili (solo kg, g, litri, ml). | **corretto in v21** |
| D14 | **Acquisto e consumo dipendevano dalla conversione delle unità.** Un acquisto in un'unità senza fattore di conversione contava come "non compra" (Etiopia carne 2021: 13% degli acquirenti; Nigeria uova 2012: 73%). | Conteggi sul pannello. | Ora compra = spesa > 0 o quantità convertita > 0; consuma = lo dichiara o quantità > 0. Comprano carne, Q1/Q5: Etiopia 4,1/41,8 → 4,6/45,8; Nigeria 35,1/66,5 → 35,2/67,4. | **corretto in v21** |
| D15 | **Etiopia 2013-2021: nel ruolo familiare contati anche i membri usciti dalla famiglia** ("ancora membro?" = No): 2.373 / 4.597 / 784 / 2.568 righe; in 28-31 famiglie il capofamiglia era una persona uscita. | Audit indipendente; `hh_size` ufficiale = membri attuali nel 100% dei casi. | Controlli demografici. Quota della qualità della carne 15,2% → 15,3%. | **corretto in v21** (anche età e sesso corretti del 2013-2015) |
| D16 | **Etiopia 2013: identificativo dell'EA del 2011** (mancante per le 1.456 famiglie del nuovo campione urbano); prezzi di comunità senza centesimi (2011), senza la quantità a cui si riferisce il prezzo, senza il latte 2013 ("Liter"). | Audit indipendente. | Solo le elasticità di prezzo, che non sono nei risultati principali. | **corretto in v21** |
| D17 | **Tanzania: prodotti del latte (902) in kg**, ma riportati al 97% in litri: solo 45 righe su 2.020 avevano una quantità. | Audit indipendente. | Ora `milk_processed` in litri (traccia B). | **corretto in v21** |
| D18 | **Tanzania: scala della spesa.** 2008-2014 divisa per max(adulti equivalenti, 1), che riduceva del 12-28% 614 famiglie di una persona; 2020 per 28 giorni invece che annua (13 volte più piccola). | Etichette di `expmR`, `expmR_pae`. | Nessun effetto nei modelli con effetti fissi d'anno; quintili delle famiglie di una persona. | **corretto in v21** |
| D19 | **Tanzania 2020: 419 famiglie (8,9%) escluse**: hanno risposto al modulo alimentare `hh_sec_j1`, con le stesse domande. | Audit indipendente. | Varietà 0,357 → 0,377; proteine 0,872 → 0,840; moltiplicatore 1,04 → 1,07. | **corretto in v21** |

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
| M12 | **Parte 7 (reddito permanente, differenze lunghe, attenuazione): spesa non deflazionata tra le wave.** La spesa è nominale in Etiopia e Nigeria e deflazionata solo dentro la wave in Tanzania. La media di una famiglia su più anni mescolava reddito e inflazione degli anni in cui era osservata; nelle differenze lunghe l'inflazione tra il primo e l'ultimo anno entrava sia nella spesa sia nel prezzo al kg. Trovato con la riverifica indipendente in Python del 12/11. | **corretto in v21**: logaritmo della spesa rispetto alla media pesata dell'anno; differenze lunghe con un effetto fisso per coppia di anni. Carne, qualità sul reddito permanente quasi invariata (0,166 / 0,167 / 0,081 → 0,172 / 0,170 / 0,083), transitorio sempre non significativo. **Differenze lunghe, qualità: Tanzania 0,053 (p < 0,001) → −0,010 (n.s.), Nigeria 0,061 (p = 0,03) → 0,046 (n.s.), Etiopia −0,055 → −0,178 (n.s.)**; quantità Tanzania 0,073 → 0,479 |
| M13 | **Parte 7.4: la qualità "entro il prodotto" era la media di tutte le stime, caffè compreso.** | **corretto in v21**: caffè escluso; Etiopia 0,130 → 0,144 (Tanzania e Nigeria non avevano il caffè in quella tabella) |
| M11 | **Endogeneità della spesa totale** come misura di reddito: non trattata (servirebbe uno strumento: reddito o indice di beni). | **aperto**: da discutere con il Professore (strumento: reddito o indice di beni) |

## C. Verifica indipendente colonna per colonna (12-13 novembre 2026)

Tre controlli separati, uno per paese, hanno ricostruito in Python ogni colonna dei pannelli dai file
grezzi, scegliendo le variabili dalle etichette e senza leggere il codice R, e le hanno confrontate riga
per riga con i pannelli della pipeline. Hanno trovato D11-D19. Dopo le correzioni le ricostruzioni coincidono con i pannelli al 100% in ogni
colonna e in ogni wave, salvo i limiti elencati sotto (`checks/audit/`). Le stime principali sono state riprodotte con
un'implementazione indipendente in Python (`checks/independent_estimates.py`), che ha trovato M12; dopo
le correzioni R e Python danno gli stessi coefficienti (`checks/audit/r_vs_python.csv`).

Convenzioni rimaste, documentate e non errori:
- Etiopia: `urban_code` è il codice grezzo, con significato diverso per wave; come controllo la pipeline
  usa una variabile che vale 1 per le zone **rurali** (Etiopia, Tanzania) e **urbane** (Nigeria): le
  elasticità non cambiano, il segno del suo coefficiente sì.
- Etiopia 2011: `coffee_plots` viene dal file post-raccolto, che copre solo parte dei campi (117 famiglie
  invece di 863); prezzi di comunità del formaggio non usati. Da rivedere quando si lavorerà sul caffè.
- Etiopia 2011-2013: la carne è un'unica voce e può includere pesce; dal 2015 il pesce è escluso.
- Etiopia: restano singoli prezzi di comunità estremi (uova 2011, caffè 2013); servono solo alle elasticità
  di prezzo, già segnalate come non affidabili.
- Tanzania: uova in grammi convertite a 55 g per uovo; latte in kg letto come litri (anche 45 righe di
  prodotti del latte in kg, probabilmente formaggio); una famiglia 2008 con uova autoprodotte ma "non consumate"; "capre e pecore" è
  solo capra (non esiste un codice per la pecora).
- Nigeria: `year` è l'etichetta del round (raccolta dati 2011, 2013, 2016); il 42% degli acquisti di uova
  2012 non ha unità e resta non convertito; anatra, latte in polvere per bambini e formaggio esclusi.
