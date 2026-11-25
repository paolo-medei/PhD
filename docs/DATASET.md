# Dataset delle famiglie sugli alimenti ricchi di proteine, solo valori originali (v2, 23 novembre 2026)

Una riga per paese x wave x famiglia del modulo alimentare (25 wave: Etiopia 5, Tanzania 5, Malawi 4,
Nigeria 5, Uganda 6). Ogni voce proteica ha le sue colonne (carne, pesce, uova, latticini, legumi,
arachidi, frutta a guscio, semi) con le risposte del questionario COSI' COME SONO nei file .dta della
Banca Mondiale: consumato si'/no, quantita', codice dell'unita', spesa, per fonte (acquisto, produzione
propria, regali; Uganda anche fuori casa e i valori; Nigeria 2018-2023 l'ultimo acquisto a 30 giorni).
Accanto, le variabili della copertina (peso, regione, distretto, EA, strato, codice urbano/rurale) e
dell'aggregato ufficiale di consumo, con i nomi originali.

**Niente e' creato:** nessuna conversione delle unita', nessun totale, nessuna ricodifica, nessuna
imputazione, nessun taglio dei valori anomali, nessuno zero al posto di un vuoto (decisione di Paolo,
23 novembre: "solo cose originali"). La prima versione dello stesso giorno, con valori armonizzati e
totali, e' nella storia del repository.

Il file .xlsx e il .csv.gz contengono dati di famiglia con gli identificativi: **non vanno nel
repository** (che e' pubblico) ne' si ridistribuiscono. Qui c'e' solo il codice.

## Come si rifa'

Dalla cartella `code/dataset/`, con gli archivi estratti in `data/_unzipped`:

```
Rscript item_inventory.R <data/_unzipped> item_inventory.csv      # tutte le voci dei moduli alimentari, con etichetta
python3 make_item_map.py item_inventory.csv item_map.csv          # codice originale -> colonna della voce, con controllo delle etichette
Rscript build_protein_dataset.R <data/_unzipped> <out> item_map.csv     # famiglia x voce, valori originali
Rscript hh_raw.R <data/_unzipped> <out>/hh_raw.csv <out>/hh_raw_sources.csv   # copertina e aggregato, valori originali
Rscript role_vars.R <data/_unzipped> item_map.csv <out>/role_vars.csv     # variabile originale di ogni domanda e totali di controllo
Rscript unit_codes.R <data/_unzipped> item_map.csv <out>/unit_codes.csv   # codici delle unita' con etichetta
python3 assemble_dataset.py <out> item_map.csv <cartella finale>
```

(`build_protein_dataset.R` calcola anche quantita' convertite, che `assemble_dataset.py` non usa.)

## Controlli (foglio Quality_Control)

- 0 duplicati; ogni famiglia del modulo alimentare c'e'.
- Ogni domanda di ogni wave e' ricontata direttamente sul file .dta (`role_vars.R`, codice scritto a
  parte): righe non vuote e somma sulle voci proteiche coincidono con il dataset. Uniche differenze,
  spiegate: il Malawi 2024 salva quantita' e spese come testo e alcune celle contengono la lettera "a"
  (codice di mancante), che resta vuota.
- I numeri salvati in Stata come float a 4 byte sono scritti con le cifre piu' corte che ridanno lo stesso
  float (0,3 e non 0,300000011920929): stesso valore salvato, scritto come lo mostra Stata.

## Trovato durante il lavoro

- Malawi, voce 522 (pezzi di pollo, 2016-2024): nel dataset c'e', nella lista ITEMS_MW dello Step I no.
  Lo Step I sottostima il pollame del Malawi 2016-2024 (da correggere nella PARTE 4).
- Nigeria 2018-2023: l'acquisto e' una domanda a parte sugli ultimi 30 giorni (ultimo acquisto), non a 7
  giorni come prima; le voci "altro" hanno la specifica in item_os_cd (821 faraona, 961 pelle di vacca...).

## Dataset armonizzato sulle proteine (harmonize_protein.py, 23 novembre 2026)

Una riga per famiglia e wave (137.192 famiglie, 25 wave), 84 variabili: identificativi, pesi, disegno,
caratteristiche della famiglia e benessere dello Step I; per tre categorie (animale senza pesce, pesce,
vegetale: legumi, soia, arachidi, frutta a guscio, semi) consumo si'/no, grammi di proteine a settimana
e per adulto equivalente al giorno, per fonte (mercato, produzione propria, regali), chili, spesa a 7
giorni; limiti inferiori (`_lb`) con il numero di voci non convertite; stato di confrontabilita' della
wave per categoria.

```
python3 harmonize_protein.py <out> item_map.csv protein_coefficients.csv <hh_info.csv> ../../docs/external/wdi_gdp_pc_ppp.csv <cartella finale>
```

- Coefficienti in `protein_coefficients.csv` (proteine per 100 g di parte edibile; WAFCT 2012 come nello
  Step I, USDA SR Legacy per le altre voci; qualita' A/B/C/X). Da controllare sulle tabelle prima di pubblicare.
- Conversioni nuove rispetto allo Step I: stime di peso della Tanzania 2020 (hh_ja02b), fattori kg/l del
  file per la Nigeria 2018-2023, chili scritti nell'etichetta dell'unita' in Uganda.
- Un totale e' mancante se una voce consumata non si converte o la categoria non e' chiesta: mai zero.
- Limiti principali: solo alimenti ricchi di proteine (niente cereali); pesce del Malawi e dell'Uganda quasi
  mai convertibile (mucchietti, pezzi); spesa della Nigeria 2018-2023 a 30 giorni, non usata.

## Dataset LONG armonizzato per voce alimentare (build_long_food_dataset.py, 23 novembre 2026)

Sostituisce, come dataset di analisi, sia la versione "solo originali" (troppo larga: una colonna per
domanda e voce) sia quella a tre categorie (troppo aggregata). Una riga per **famiglia x wave x voce
originale del questionario** (solo alimenti ricchi di proteine: carni, pollame, uova, latticini, pesce,
legumi, soia, arachidi, frutta a guscio, semi, piu' le voci miste e i piatti pronti a base di questi),
43 colonne fisse uguali in tutti i paesi e le wave.

```
python3 item_classification.py item_map.csv item_classification.csv    # voce di dettaglio -> voce -> gruppo -> super-gruppo
python3 build_long_food_dataset.py <out> item_map.csv item_classification.csv protein_coefficients.csv <hh_info.csv> ../../docs/external/wdi_gdp_pc_ppp.csv <cartella finale>
# DOC_ONLY=1 rifà solo il workbook di documentazione dalle statistiche salvate
Rscript to_rds.R <cartella finale> <data>                               # le stesse tabelle in .rds per R (testi ripetuti come factor)
```

Uscite: `food_items_long_<data>.csv.gz` e `.rds` (4,6 milioni di righe: troppe per Excel; in R l'.rds occupa
circa 1,3 GB di memoria e si apre con `readRDS`; il .csv.gz va letto con `hhid` e `unit_total_orig` come testo), `households_<data>.csv.gz` e `.rds`
(137.192 famiglie, anche nel workbook), `food_dataset_documentation_<data>.xlsx` (README, Households,
Item_Classification, Item_Mapping, Data_Dictionary, Comparability_Matrix, Quality_Control).

- **Gerarchia**: `item_detail` (una per voce originale, 154) -> `item` (91 prodotti: beef, pork, goat,
  goat_sheep, chicken, poultry_other, eggs, milk_fresh, milk_processed, cheese, fish_fresh, beans_dry...)
  -> `food_group` (17) -> `food_supergroup` (animal_source, plant, mixed). Le categorie combinate del
  questionario restano tali (`meat_unspecified`, `goat_sheep`, `poultry_unspecified`, `fish_form_unspecified`)
  con `item_comparability = combined`: mai divise.
- **Una variabile per concetto**: `qty_total_kg`, `qty_from_purchases_kg` (consumato da acquisti),
  `qty_purchased_kg` (acquistato a 7 giorni: solo Nigeria 2010-2015, domanda diversa), `qty_own_kg`,
  `qty_gift_kg`, `qty_away_kg` (Uganda), `exp_purchases` (7 giorni), `value_*` (Uganda), e per la Nigeria
  2018-2023 l'ultimo acquisto a 30 giorni (`purchased_30d`, `qty_last_purchase_kg`, `value_last_purchase`).
  Le variabili originali di ogni wave sono nel Data_Dictionary e nella Comparability_Matrix.
- **Zero, mancante, non raccolto**: 0 = non consumato o fonte non usata; vuoto = mancante;
  `not_collected` elenca le variabili che la wave non chiede (vuote per tutte le famiglie della wave);
  `consumption_status` distingue consumed / not_consumed / not_listed (wave che elencano solo le voci
  consumate) / no_record / not_answered; `qty_status` distingue converted / not_convertible / no_quantity.
- **Benessere**: `welfare_annual` identico a quello dello Step I (verificato: scarto massimo 0). Variabile
  originale per paese e wave in `welfare_official_var` e `welfare_formula`. Il quintile nuovo e' pesato per
  la popolazione (peso x componenti); quello dello Step I non era pesato.
- **Correzioni rispetto al dataset a tre categorie**: i pezzi si convertono a 55 g solo per le uova (il cocco
  restava a 55 g per pezzo); in Tanzania uova e cocco registrati in kg o g ora sono convertiti.
- **Controlli** (foglio Quality_Control): 0 duplicati famiglia x wave x voce; ogni famiglia del modulo ha le sue
  righe; righe non vuote e somma della quantita' totale originale uguali ai file .dta in ogni wave (unica
  differenza: Malawi 2024, 9 celle con la lettera "a"); nessuna variabile "not collected" ha valori; nessun valore
  negativo; spot check di 6 righe (ETH 2018, TZA 2020, NGA 2018, UGA 2019, MWI 2019) rilette dai file .dta.
- **Limiti**: quantita' in kg per il 78% delle voci consumate (pesce 40%: mucchietti e pezzi in Malawi, Uganda,
  Etiopia; soia, legumi freschi, piatti pronti); Tanzania 2020: uova contate in pezzi a 55 g anche quando la
  famiglia ha dato il peso, quindi le fonti in grammi possono differire di poco dal totale; Uganda 2018-2019 non
  chiede il totale (totale = somma delle fonti); Malawi 2010 senza etichette delle unita' nel file.

## Dataset WIDE per famiglia (build_wide_food_dataset.py, 23 novembre 2026) — quello da usare

Una riga per famiglia x wave, mai ripetuta (127.961 righe, 23 wave: Etiopia 2011 e 2013 tolte perche' il
questionario ha una sola voce per tutta la carne, decisione di Paolo), 142 colonne decise con Paolo voce per
voce: 23 della famiglia e 17 alimenti x 7 (`_cons`, `_kg_tot`, `_kg_pur`, `_kg_own`, `_kg_gift`, `_exp`,
`_kg_est`). Un file Excel con tutti i paesi e uno per paese, stesse colonne nello stesso ordine.

```
Rscript nga_head.R <data/_unzipped> nga_head.csv      # sesso ed eta' del capofamiglia in Nigeria (roster sect1_harvestw1-w5)
python3 build_wide_food_dataset.py <out> food_items_long_<data>.csv.gz households_<data>.csv.gz item_classification.csv wide_items.csv item_map.csv nga_head.csv <cartella finale>
```

- **Voci** (`wide_items.csv`): beef, goat_sheep (capra + pecora + "capra e montone" ETH), pork, processed_red_meat,
  meat_other (con selvaggina, cammello, frattaglie), poultry (pollo +
  altro pollame), eggs, milk_fresh, dairy_processed (tutti gli altri latticini), fish_fresh, fish_processed,
  pulses_dry, pulses_fresh, groundnuts, soy, nuts, seeds. Pesce: il "Fish" dell'Etiopia va nel fresco; il mukene
  dell'Uganda e l'"altro pesce" della Nigeria (crayfish, stockfish) nel trasformato. Tolti: piatti pronti, burro-margarina,
  cocco, noce di cola, insetti, lumache, uccelli selvatici, voci "altro (specificare)".
- **Somme rigorose**: il valore di una colonna e' vuoto se una delle voci originali che somma e' sconosciuta.
- **Chili stimati**: per mucchietti, pezzi, tazze, piatti senza fattore di conversione, kg per unita' = mediana
  su chi ha comprato in quell'unita' di (spesa / quantita') diviso il prezzo al kg mediano della stessa voce,
  paese e wave (minimo 5 acquisti; se mancano, la stessa unita' in tutte le wave con stesso codice ed etichetta).
  Prima delle stime: unita' metriche e pesi scritti nell'etichetta (Malawi "PACKET (150G)"). `_kg_est = 1`
  segna i chili stimati; i pesi sono nel foglio Unit_weights. Copertura dei kg sulle voci consumate: dal 78%
  al 98%. Sono pesi "a valore" (un mucchietto pesa quanto i kg che costerebbero lo stesso): alcuni sono poco
  plausibili (formaggio wara in pezzi 3-6 g, Nigeria 2015) e vanno controllati.
- **Benessere**: annuo, per adulto equivalente o per persona (`welfare_scale`, `welfare_var`), uguale allo Step I.
- **Non raccolto**: la colonna `not_collected` elenca per wave le voci assenti dal questionario (`pork_*`) e le
  domande non fatte (`*_exp` Nigeria 2018-2023, `*_kg_pur` Nigeria 2010).

### Correzioni del 24 novembre 2026
- Tanzania: `food_cons_hh_annual` = foodIN + foodOUT in tutte le wave (il 2020 non ha foodbev; alcol e tabacco
  sono il 2% del cibo nel 2014). La quota del cibo scende nel 2020 perche' il totale 2020 aggiunge l'affitto
  imputato e il valore d'uso dei beni durevoli.
- Malawi: `cons_total_hh_annual` = rexpagg (reale), come il cibo (rexp_cat011) e il benessere; prima era nominale.
- Uganda 2018: tolto fnrfxp30, che vale 0 per l'80% delle famiglie (non e' il totale del cibo nonostante l'etichetta).
- `check_aggregates.R` rilegge i file ufficiali e confronta benessere, consumo totale e alimentare famiglia per
  famiglia: tutti uguali.

## Bilancio alimentare di tutte le voci, per il LA/AIDS (24 novembre 2026)

Una riga per famiglia x round (127.961), tutte le voci del modulo alimentare a 7 giorni in 26 categorie a casa
(le 17 proteiche + cereals, starches, sugar_sweets, vegetables, fruits, oils_fats, spices_other, beverages, other_food)
più `food_away` (pasti fuori casa: solo valore, senza prezzi, fuori dalle quote). Decisioni di Paolo del 24 novembre:
A1-A3, B1 alcol nelle bevande, B2 tabacco fuori, khat e noce di cola fuori, B3 a pasti fuori casa categoria a parte,
C3 voci escluse anche qui, D1 b prezzi unitari locali degli acquisti (EA -> distretto -> regione -> nazionale, almeno 5),
E1 a imputazione con la mediana dell'area (parte imputata in `<cat>_value_imp`), E2 a anomali -> mancanti -> imputati,
F kg (litri per le bevande liquide), G valori a 7 giorni in valuta locale, H2 a 12 gruppi aggregati, H3 denominatore = somma delle 26.

```
# classificazione voce per voce (anche il workbook di revisione)
python3 food_categories_map.py item_inventory.csv item_map.csv item_classification.csv wide_items.csv item_hh_counts.csv module_households.csv food_category_map.csv
python3 food_categories_review.py food_category_map.csv food_category_mapping_review.xlsx
# estrazione di tutte le voci (lettori di build_protein_dataset.R) + moduli dei pasti fuori casa
Rscript build_allfood_long.R <_unzipped> <out> item_map.csv food_category_map.csv
# valorizzazione, quantita', aggregazione per famiglia
python3 build_allfood_dataset.py <out> _wide_check.csv.gz module_households.csv item_map.csv food_category_map.csv unit_codes.csv <out2>
# controllo D3 e file Excel
Rscript official_food_aggregates.R <_unzipped> official_food.csv
python3 write_allfood_workbooks.py <out2>/_allfood_wide_<data>.csv.gz <out2>/_qc_<data>.pkl official_food.csv food_category_map.csv <out2>/_unit_weights_<data>.csv <xlsx>
Rscript allfood_to_rds.R <out2>/_allfood_wide_<data>.csv.gz ASF_food_budget_<data>.rds
```

Nigeria 2018 e 2023: il modulo dei pasti fuori casa (sect10a_harvestw4, sect5a_harvestw5) va preso dagli archivi completi
(non era tra i file estratti). Controllo con gli aggregati ufficiali (foglio Quality_control, tabella 8): Tanzania 1,00-1,06,
Etiopia 2018-2021 0,91-1,00, Malawi 0,97-1,16, Nigeria 0,86-1,18 (ufficiale pro capite); Etiopia 2015 1,33-1,41: l'aggregato
ufficiale del 2015 e' piu' basso in tutte le fonti, anche negli acquisti dichiarati. Problemi nei file: Uganda 2019 zucchero
(codice 147) dichiarato da nessuna famiglia; Etiopia 2021 tella (805) idem; segnalati in `not_collected`.

## Dati grezzi per il LA/AIDS degli altri paesi (25 novembre 2026)

Stesso formato del file della Tanzania (`tza_dati_grezzi.R`): una riga per famiglia x round, valori originali del modulo a
7 giorni in colonne `c<codice>_<variabile>`, fogli `voci`, `unita`, `LEGGIMI`, `controllo_famiglie`.

```
Rscript dati_grezzi_LAAIDS.R <ETH|MWI|NGA|UGA> <_unzipped> allfood_long_<paese>.csv.gz _wide_check.csv.gz food_category_map.csv unit_codes.csv <paese>_dati_grezzi_LAAIDS_<data>.xlsx
python3 quote_2stadi_5paesi.py _allfood_wide_<data>.csv.gz food_category_map.csv Quote_2stadi_5paesi_<data>.xlsx
```

- Variabili in piu' dove il paese le chiede: `taglia_*` (Malawi, Nigeria 2018-2023), `u_altra_*` (unita' scritta a mano),
  Nigeria `q_da_acq`, `acq_30gg`, `q_ultacq`, `u_ultacq`, `taglia_ultacq`, `spesa_ultacq` (2018 e 2023 non hanno gli acquisti
  a 7 giorni), Uganda `val_auto`, `val_regali`, `q_fuori`, `val_fuori`.
- Spesa totale (strumento): dataset armonizzato; Nigeria = aggregato pro capite x hhsize (2023: solo totcons_adj);
  Uganda 2010-2011 = cpexp30 x 12 (prezzi costanti). Malawi 2010: regione dalla prima cifra del distretto.
- `cluster` = id_ea del primo round della famiglia (panel_id). Uganda 2013: 7 righe doppie risolte (regola nel LEGGIMI).
- Malawi e Uganda: le voci "food_away" (cibo dai venditori) restano nel file con gruppo `fuori_casa`, da togliere dal budget.
- Controllo: somme di quantita' e spesa uguali al file di partenza per round; rilettura con readxl.
- Quote a due stadi (`quote_2stadi_5paesi.py`) dal dataset alimentare: per la Tanzania uguali a quelle dello script LA/AIDS.
