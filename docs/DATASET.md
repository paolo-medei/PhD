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
