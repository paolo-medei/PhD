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
| M14 | **Costo per grammo di proteina = spesa per acquisti divisa per TUTTA la proteina consumata**, autoproduzione compresa: mescolava il prezzo per grammo con la quota comprata. Trovato rileggendo il codice per l'articolo (13/11). | **corretto in v21**: spesa divisa per la proteina comprata. Elasticità ETH 0,276 → 0,279; TZA 0,052 → 0,099; NGA 0,026 → 0,052 |
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

## D. v22 (13 novembre 2026): tutto in R

- `code/pipeline/10_margins.R` (nuovo): tre margini della risposta al reddito (entrata, quantità, qualità)
  con bootstrap su famiglia-round (100 replicazioni, seme fisso), tabella degli intervalli di confidenza dei
  quattro disegni panel, caffè in Etiopia. Prima esistevano solo come script Python di prova per l'articolo:
  le stime puntuali R coincidono con quelle Python fino alla precisione di macchina; gli errori standard del
  bootstrap differiscono un po' perché le estrazioni casuali sono diverse (fanno fede quelli R).
- Errori standard aggiunti alle tabelle `_12_household_FE`, `_30_permanent_transitory`, `_31_long_differences`;
  le colonne esistenti non cambiano.
- `10_workbook.R` diventa `11_workbook.R`; `run_all.R` confronta da solo il nuovo workbook con
  `results_reference/` e stampa il verdetto.
- Avvisi silenziati, solo i due noti e innocui: 40 "non-integer #successes" del probit pesato (con pesi
  campionari è atteso) e 8 etichette di zona/stato diverse tra le wave nigeriane. Pannelli identici
  (md5) e 53 tabelle identiche prima e dopo.

## E. v23 (13 novembre 2026): Uganda e Malawi

Aggiunti su indicazione del 13/11: sono, con Etiopia e Tanzania, i paesi del programma ACT dell'UNIDO.
Le scelte sono state fatte leggendo etichette e domande di ogni wave; le trappole sono descritte in testa a
`03_build_UGA.R` (U1-U10) e `03_build_MWI.R` (M1-M6). Verifica indipendente colonna per colonna in
`checks/audit/UGA/` e `checks/audit/MWI/`.

**Uganda** (UNPS 2010/11 - 2019/20, sei wave; manca 2009/10, catalogo 1001). Panel: `panel_ids()` collega
le wave con gli identificativi che ogni wave dà della precedente; dal 2013 due famiglie che rivendicano
lo stesso predecessore iniziano entrambe una nuova unità. 1.258 famiglie sono in tutte e sei le wave.
- Il pollo non è mai pesato (pezzi, polli interi): le sue quantità non sono convertite.
- Il caffè ha "confezioni da 100 g" vendute al prezzo di una bustina: quantità non usate.
- Il latte in "Nice cup" (5-16% degli acquirenti) vale 0,5 l: costa quanto la tazza da mezzo litro
  (**deciso da Paolo, 13/11**).
- 2015: 25 acquisti di uova registrati come "1 uovo" a 8.000-9.300 UGX sono vassoi da 30: quantità x 30
  (**deciso da Paolo, 13/11**). Poi, per Uganda e Malawi: un acquisto ancora a più di 10 volte o meno di
  un decimo del prezzo mediano della wave per quel prodotto ha le quantità segnalate
  (`flag_price_outliers()`, `00_setup.R`).
- Verifica indipendente (`checks/audit/UGA/REPORT.md`): al secondo giro coincide su tutte le colonne di
  205.573 righe; i collegamenti tra wave al 99,95%. Gli errori trovati al primo giro (due capifamiglia,
  cluster falsi, dimensione della famiglia 2011, falsi zeri, Kampala, demografia delle famiglie senza
  aggregato) sono corretti. Resta: il 3-5% dei collegamenti segue un identificativo che punta a una
  famiglia "sorella" dopo una divisione (rumore negli effetti fissi).
- PIL pro capite PPP (dollari internazionali 2021), media degli anni d'indagine: 2.479.

**Malawi** (IHS3 2010, IHS4 2016, IHS5 2019, IHS6 2024; circa 49.000 famiglie). Il panel IHPS
(2010-13-16 e 2024) arrivato senza aggregato di consumo non è utilizzabile: il Malawi entra nelle analisi
trasversali, non negli effetti fissi familiari né nel reddito permanente. IHS2 2004 escluso (questionario
diverso).
- Conversioni: unità metriche, tabella ufficiale 2020 per pollo, latte e latte in polvere; "pezzo" di
  manzo, capra e maiale non convertito (la tabella dà 0,036 kg al Nord e 0,25 kg altrove).
- Benessere = consumo reale annuo per persona (l'IHS6 non ha la scala di adulti equivalenti);
  "regione" = distretto (le regioni sono solo tre).
- PIL pro capite PPP, media degli anni d'indagine: 1.605 (il più povero dei cinque).
- Verifica indipendente (`checks/audit/MWI/REPORT.md`): al secondo giro 27 colonne su 28 identiche in
  ogni riga, l'ultima diversa in una sola famiglia. Corretti dopo il primo giro: escluso il campo
  profughi di Dzaleka (2024, 386 famiglie senza aggregato); lette le unità metriche scritte male e con la
  virgola; non usati i valori della tabella ufficiale che i prezzi smentiscono ("altro pollame" pesato
  come un pollo, cucchiaino di latte in polvere più pesante del cucchiaio); latte fresco "in grammi"
  non convertito; i pacchetti di latte fresco costano quanto le bustine e valgono come bustine (per
  analogia con la "Nice cup" dell'Uganda: **da confermare con Paolo**); un acquisto con prezzo anomalo
  svuota solo la quantità acquistata, e la quantità totale solo se registrata nella stessa unità.
- I risultati: acquirenti di carne dal 5,6% (quinto più povero) al 61% (più ricco); tre margini della
  carne entrata 63%, quantità 33%, qualità 4%.

I numeri PPP vengono dalla serie WDI NY.GDP.PCAP.PP.KD letta tramite la copia di Our World in Data (i
valori di Tanzania e Nigeria coincidono con l'estratto WDI già usato).

## F. Articolo e slide a cinque paesi (15 novembre 2026)

- Articolo (Claude Docs, bozza v0.2): testo, Tabella 1 e le tre figure aggiornati ai cinque paesi con i
  numeri di `RESULTS_v23_2026-11-13.xlsx`; ogni numero ricontrollato sul workbook. Messaggio invariato:
  entrata 47-63%, quantità 33-49%, qualità 3-7% per la carne; dentro la famiglia la qualità sale (poco)
  solo in Uganda e Nigeria.
- Slide "Research Update": dati, metodi, risultati, conclusioni e note aggiornati; tre figure nuove
  (`docs/slides/deck_figures_v23.py`). **Cambiato il messaggio delle conclusioni**: la vecchia slide diceva
  "quando i redditi crescono, la domanda passa alla qualità". Con cinque paesi da 1.600 a 8.400 dollari PPP
  la quota della qualità non sale con il reddito nazionale (è la più bassa in Nigeria, il più ricco): ora
  la slide dice "non ancora".
- **Aperto: quantità estreme.** La regola dei prezzi (10 volte la mediana) tocca solo gli acquisti di
  Uganda e Malawi. Restano 89 righe con una quantità consumata oltre 100 volte la mediana della wave per
  quel prodotto (29 senza spesa): 64 in Etiopia (soprattutto caffè 2011, fino a 400 kg a settimana),
  16 in Tanzania (pollo 2012: 8.500 unità), 7 in Nigeria (uova 2012), 1 in Uganda (maiale 2019:
  10.000 kg), 1 in Malawi. Nei modelli sui valori unitari il taglio all'1° e 99° percentile le esclude
  quasi certamente; spostano invece le medie descrittive di proteine e quantità (es. `UGA_21` 2019, terzo
  quintile, 103,9 g). Proposta: segnalarle
  in tutti i paesi come quantità non utilizzabili (da decidere). **Deciso il 20 novembre: regola M17,
  sezione G.**
- **Da confermare (Paolo):** i pacchetti di latte fresco del Malawi letti come bustine (sezione E).

## G. v24 (15-20 novembre 2026): pesce, FAO e una regola unica per i valori estremi

Confronto con i risultati provvisori v24 del 15 novembre (`RESULTS_v24_provvisorio_2026-11-15.xlsx`).

**Pesce come prodotto a sé.** Traccia B in tutti i paesi, traccia A tranne l'Etiopia. Codici: Tanzania 808-810
(2020 anche 8081-8084); Uganda 122, 123, 1221-1237, compreso 1234 (nkejje secco, aggiunto dopo la verifica);
Malawi 502, 503, 513, 5021-5023, 5031-5033, 5121-5123 (mucchi e pezzi non convertiti, TRAP M7); Nigeria
100-103 e 105-107 (lumache, 104, escluse); Etiopia 183 (2015) e 704 (2018, 2021). Pesce fuori dalle
tabelle della filiera zootecnica (`09_value_chain.R`).

**Copertura dei valori unitari (MIN_UV_SHARE).** Quantità e qualità del pesce solo dove almeno metà degli
acquirenti ha un valore unitario: Tanzania 92%, Nigeria 94%. Non in Uganda (15%) né in Malawi (0,2%), dove
il pesce si compra a mucchi e a pezzi; lì il pesce entra solo nella partecipazione e nelle quote di spesa.

**M15, costo per grammo di proteine.** Spesa e proteine delle stesse righe acquistate (prima la spesa
poteva venire da righe senza proteine). **M16, quinti.** Per famiglia, non per riga.

**M17, una regola per i valori estremi in tutti e cinque i paesi (decisa da Paolo il 20 novembre).**
1. Prezzo: un acquisto pagato più di 10 volte o meno di un decimo della mediana del prodotto nella wave
   perde la quantità acquistata (conta come acquisto, non come valore unitario). Le altre fonti
   (totale, autoproduzione, regali) la seguono solo se registrate nella stessa unità dell'acquisto, come
   già in Malawi. Uova: un vassoio registrato come uovo è riportato a 30 uova dove le uova si contano a
   pezzi. Prima valeva solo in Uganda e Malawi; altrove c'erano valori unitari fino a 5.700 volte la mediana.
2. Quantità: oltre 100 volte la mediana di wave × prodotto × traccia, le quantità non si usano; la spesa resta.

| | ETH | TZA | NGA | UGA | MWI |
|---|---|---|---|---|---|
| acquisti esclusi dal filtro sul prezzo | 566 | 127 | 357 | 7 | 286 |
| altre fonti nella stessa unità, escluse | 528 | 105 | 349 | (unità unica) | (già prima) |
| righe con quantità oltre 100 volte la mediana | 32 | 18 | 6 | 3 | 4 |

Il filtro ha trovato un errore nella tabella ufficiale di conversione della Nigeria 2015: il latte in
polvere in "bustina media" vale 0,4 kg e in "bustina grande" 0,9 kg, contro 0,012 kg della piccola; i prezzi
dicono che la media pesa quanto la piccola (58 delle 69 bustine medie e 10 delle 11 grandi escluse). Per
questo nel 2015 escono 133 dei 1.106 acquirenti di latte trasformato (12%).

**Cosa cambia nei risultati.**
- Tre margini della carne: praticamente nulla (Etiopia, quota della qualità da 7,3 a 8,0%; altri paesi
  ±0,1). Il messaggio resta: entrata 47-63%, quantità 33-49%, qualità 3-8%.
- Effetti fissi familiari, carne: Etiopia da −0,153 (p 0,15) a −0,055 (p 0,51); Tanzania da −0,001 a 0,018
  (p 0,25); Nigeria da 0,041 a 0,033 (p 0,03); Uganda invariata (0,027). Resta: dentro la famiglia la qualità
  sale (poco) solo in Uganda e Nigeria.
- Elasticità della qualità per prodotto: si muovono in Etiopia e Nigeria. Etiopia manzo da 0,144 a 0,207,
  capra e pecora da 0,081 (non significativa) a 0,168; Nigeria latte fresco da 0,116 a 0,074, latte
  trasformato da 0,123 a 0,055. Carne in Etiopia per anno: 2011 da 0,040 a 0,114, 2018 da 0,049 a 0,105.
  Le stime per anno in Etiopia dipendevano da pochi acquisti con l'unità sbagliata, nonostante il taglio
  al 1° e 99° percentile.
- Costo per grammo di proteine: Etiopia da 0,169 a 0,221; Nigeria da 0,046 a 0,035; Tanzania da 0,096 a
  0,089; Uganda e Malawi invariati.
- Caffè in Etiopia, effetti fissi: da −0,161 (p 0,001) a +0,047 (p 0,02). Il segno negativo veniva dagli
  acquisti con l'unità sbagliata.
- Proteine per quinto (`_21`): spariti i valori assurdi (Uganda 2019, terzo quinto, da 103,9 a 8,4 g;
  Tanzania 2010, quarto quinto, da 42,6 a 16,3 g; Tanzania 2014 e 2020 nei quinti alti).
- Quote di spesa (`_20`) e partecipazione: invariate (la regola tocca solo le quantità).
- FAO_01: `kg_trim100` ora coincide con `kg_raw` ovunque (nessuna riga tagliata): la colonna resta come controllo.
- Etiopia 2018: il formaggio scende sotto la soglia di acquirenti ed esce da `ETH_01`.

**Verifica indipendente** (`checks/audit/v24/REPORT.md`): pesce ricostruito riga per riga dai file grezzi,
99,9-100% di coincidenza su ogni colonna; regola di copertura, M16 e FAO_01 riprodotti. Corretti dopo la
verifica: nkejje secco (1234) ora è pesce; ogni unità che dichiara i grammi nell'etichetta è convertita
(prima "Nido Tin (400g)" sì e "Metallic plate (80g)" no); M15 con le stesse righe per spesa e proteine;
filtro sul prezzo in tutti i paesi.

**Seconda verifica, solo delle parti cambiate** (`checks/audit/v24/REPORT_recheck.md`, 20 novembre, sul giro
delle 20:36): conteggi del filtro sul prezzo identici al log in Etiopia, Tanzania, Nigeria e Uganda in ogni wave;
pannelli identici cella per cella in quei quattro paesi (1,68 milioni di righe in tutto); in Malawi 14 celle
diverse su 4,8 milioni, dovute alle conversioni che il controllore ha dovuto dedurre, non alla regola. Righe M17
identiche in tutti e cinque i paesi. Pesce dell'Uganda con nkejje ed etichette in grammi: identico. Costo per
grammo identico in quattro paesi; in Etiopia 0,2229 contro 0,221 (scarto dell'1%, già presente al primo giro,
causa non trovata). Confermato l'errore della tabella nigeriana del latte in polvere. Due precisazioni: il caffè
dell'Uganda non è mai convertito (il caffè si analizza solo in Etiopia: altrove entra solo con la spesa) e la
"Nice cup" di latte a 0,5 litri è la regola decisa il 13 novembre sui prezzi. Il controllore ha trovato
identificativi familiari in due file vecchi del repository (`checks/audit/TZA/match_rates.csv`,
`checks/audit/UGA/dup2018.py`): tolti dai file attuali; restano nella storia finché il repository è pubblico.

**Storia del repository.** Un file con identificativi familiari (`fish_mismatches.csv`, microdati) era stato
pubblicato nel repository pubblico; con l'OK di Paolo è stato tolto da tutta la storia (20 novembre). GitHub
può conservare in cache i commit vecchi: meglio rendere il repository privato.

**M18, spese estreme (decisa da Paolo il 20 novembre: "elimina questi estremi").** La regola M17 non toccava
la spesa. Etiopia 2015: una famiglia dichiara 70.000 birr per mezzo chilo di manzo (mediana 100). Da sola
portava la quota del manzo nel terzo quinto (media delle tre wave) da 51,5 a 63,7%: la "gobba" a metà
distribuzione era questo errore. Regola: una spesa oltre 100 volte la mediana di wave × prodotto × traccia
(tra chi spende) non si usa: spesa, spesa convertita e valore unitario mancanti, le quantità restano. Righe:
9 in Etiopia (latte 2011 e 2018, caffè 2013, manzo e carne 2015), 1 in Malawi (latte trasformato 2010),
nessuna altrove. In 7 righe su 10 non resta nemmeno una quantità usabile, quindi la famiglia non conta più
come acquirente di quel prodotto in quella wave (la partecipazione si muove al massimo di 0,1 punti: Etiopia, latte 2011). Effetto: in Etiopia la quota del
manzo per quinto diventa 52,1 / 51,7 / 51,5 / 51,1 / 38,6%, senza gobba; tutto il resto praticamente invariato
(tre margini entro 0,02 punti). Non coperta dalla seconda verifica (decisa dopo): 10 righe, elencate qui sopra.

## H. Un solo file (21 novembre 2026)

Su richiesta di Paolo, i 15 moduli di `code/pipeline/`, `code/run_all.R` e `code/compare_results.R` sono
diventati un file solo, `code/ASF_completo.R`, con tutti i commenti in italiano (cosa si fa, perché, come)
e un indice in cima. Il codice non è cambiato: il codice analizzato da R (`parse`, senza commenti) delle
parti 1-15 è identico, espressione per espressione, a quello dei 15 moduli; solo l'avvio (PARTE 0) e il
confronto finale (PARTE 16) sono riscritti, perché non devono più cercare i moduli. Una run completa dello
script unico coincide cella per cella con `results_reference/RESULTS_v24_2026-11-20.xlsx`.
`checks/compare_runs.R` e `checks/dump_panel_ids.R` prendono le funzioni dallo script unico.

Le sezioni precedenti di questo registro citano i moduli; la corrispondenza è:

| modulo di prima | parte dello script unico |
|---|---|
| `run_all.R` (avvio) | PARTE 0 |
| `00_setup.R` | PARTE 1 |
| `01_build_ETH.R`, `02_build_TZA.R`, `03_build_MWI.R`, `03_build_NGA.R`, `03_build_UGA.R` | PARTI 2, 3, 4, 5, 6 |
| `04_estimate.R` | PARTE 7 |
| `05_compare.R` | PARTE 8 |
| `06_advanced.R` | PARTE 9 |
| `07_deep.R` | PARTE 10 |
| `08_permanent_transitory.R` | PARTE 11 |
| `09_value_chain.R` | PARTE 12 |
| `10_fao.R` | PARTE 13 |
| `10_margins.R` | PARTE 14 |
| `11_workbook.R` | PARTE 15 |
| `run_all.R` (confronto) e `compare_results.R` | PARTE 16 |

I nomi delle variabili, i messaggi stampati nella console e i nomi dei fogli del workbook restano in
inglese: cambiarli avrebbe cambiato il codice e i risultati da confrontare.

## I. Da dove viene il cibo consumato (21 novembre 2026)

Due tabelle nuove nella PARTE 12, solo aggiunte: le 76 tabelle di prima restano identiche (il riferimento
diventa `RESULTS_v24_2026-11-21.xlsx`, con 78 tabelle).

- **VC_04_sources_by_quintile**: quota della quantità consumata comprata, autoprodotta o regalata, per
  paese × prodotto × quinto; dentro l'anno, pesata, media sulle wave. Anche solo per le famiglie rurali.
- **VC_05_processed_dairy_by_quintile**: latte trasformato come quota della spesa per latticini, per quinto.

Latte fresco comprato, dal quinto più povero al più ricco: Etiopia 10 → 53%, Tanzania 19 → 71%, Uganda
34 → 63%, Malawi 43 → 87%, Nigeria 60 → 86%. Solo famiglie rurali: 8 → 20%, 18 → 46%, 33 → 48%, 41 → 75%,
57 → 71%: il gradiente resta, più debole; una parte è urbanizzazione. Uova: 20-67% → 70-93%; pollame:
7-40% → 52-84% (Uganda: pollo non pesato); manzo già comprato all'80-99% in ogni quinto. Latte
trasformato sulla spesa per latticini: Nigeria 36 → 95%, Malawi 28 → 50%, Tanzania 24 → 16%, Uganda
6 → 9% (solo 2018-19). Dai bilanci FAO, la Nigeria importa il 64-72% del latte disponibile; gli altri
paesi meno del 3% (Malawi 4-23%, in calo).

**Codici urbano/rurale (nota, nessun effetto sulle stime).** Il controllo `urban` di `prep()` (PARTE 7,
usato anche nella PARTE 14) vale 1 per il codice "1": in Etiopia e Tanzania il codice 1 è RURALE, in
Nigeria il codice 1 è urbano, in Uganda e Malawi 1 è urbano (0/1). Come controllo è indifferente (cambia
solo il segno del suo coefficiente, mai riportato), ma la variabile si chiama `urban` e in due paesi vuol
dire rurale. La tabella VC_04 usa la definizione corretta paese per paese.

### I.2 Composizione del paniere: spesa e consumo (21 novembre 2026)

Altre due tabelle nella PARTE 12, solo aggiunte (78 identiche + 2 nuove; il riferimento ora ha 80
tabelle). Il pesce resta fuori, come in tutta la PARTE 12.

- **VC_06_basket_spending_by_quintile**: quota della spesa per acquisti di alimenti animali, per
  prodotto e quinto (la stessa tabella del grafico VC_02, ora salvata).
- **VC_07_basket_protein_by_quintile**: quota delle proteine animali CONSUMATE (comprate + autoprodotte
  + regalate), per prodotto e quinto; proteine = quantità × valori standard di `PROT_VC`.

Le due composizioni non coincidono, e la differenza è l'autoconsumo. Etiopia, quinto più povero:
manzo 54% della spesa, ma latte e formaggio 75% delle proteine (latte comprato solo al 10%). Tanzania:
pollame 4% della spesa e 24% delle proteine nel primo quinto; Malawi 8% e 36%. Salendo col reddito il
consumo si sposta verso la carne comprata: in Etiopia manzo + ovicaprini 19 → 67% delle proteine,
in Tanzania manzo 26 → 45%.

Limiti: Uganda, pollo non pesato (quota proteica di pollame ~0, non reale); Malawi, pezzi di carne rossa
non convertiti; Etiopia solo 2015-21 (traccia B), e il "formaggio" è ayib, un formaggio fresco con meno
proteine dei 200 g/kg standard (la quota dei latticini etiopi è, semmai, un po' sovrastimata).
