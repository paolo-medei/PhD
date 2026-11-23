# Dataset armonizzato sugli alimenti ricchi di proteine (v1, 23 novembre 2026)

Una riga per paese x wave x famiglia (127.501 famiglie, 23 wave: Etiopia 5, Tanzania 5, Malawi 4,
Nigeria 3, Uganda 6), ogni voce proteica separata (154 voci armonizzate: carne rossa, bianca, minore,
trasformata; pesce fresco, secco, in scatola; uova; latticini freschi e trasformati; legumi,
arachidi, frutta a guscio, semi), con le risposte grezze accanto ai valori armonizzati e i totali per
categoria. Il file .xlsx e il .csv.gz contengono dati di famiglia con gli identificativi: **non vanno
nel repository** (che e' pubblico) ne' si ridistribuiscono. Qui c'e' solo il codice.

## Come si rifa'

Dalla cartella `code/dataset/`, con gli archivi estratti in `data/_unzipped` e i pannelli dello Step I
in `data/OUTPUT` (dalla run di `ASF_completo.R`):

```
Rscript item_inventory.R <data/_unzipped> item_inventory.csv      # tutte le voci dei moduli alimentari, con etichetta
python3 make_item_map.py item_inventory.csv item_map.csv          # voce originale -> voce armonizzata, con controllo delle etichette
Rscript build_protein_dataset.R <data/_unzipped> <out> item_map.csv   # tabelle lunghe famiglia x voce, conversioni
Rscript hh_info.R ../ASF_completo.R <data> <data/OUTPUT> <out>/hh_info.csv   # variabili di famiglia dello Step I
Rscript unit_codes.R <data/_unzipped> item_map.csv <out>/unit_codes.csv     # codici delle unita' con etichetta
python3 assemble_dataset.py <out> item_map.csv <data/OUTPUT> ../../docs/external/wdi_gdp_pc_ppp.csv <cartella finale>
```

Tempi sul server: 4 minuti il build, 6 minuti l'assemblaggio (il file .xlsx pesa 150 MB: 45 milioni di
celle; per le analisi conviene il .csv.gz, identico cella per cella, verificato rileggendo l'.xlsx).

## Regole

- Niente si cancella e niente si corregge: i valori anomali hanno un segnale (`flag`), non vengono
  svuotati come nello Step I (M17, M18).
- 0 = non consumato o non comprato; vuoto = non risposto, non convertibile, o voce assente dal
  questionario di quella wave (il foglio Comparability_Matrix dice quale). Nessun vuoto diventa 0.
- Le quantita' si convertono solo con le tabelle ufficiali delle indagini o con unita' metriche.
- Le scelte che cambiano i totali o l'insieme delle voci sono nel foglio Harmonization_Log con stato
  NEEDS YOUR APPROVAL (D03-D08, D12, D13, D15-D17, D19, D26, D28).

## Controlli (foglio Quality_Control)

- 0 duplicati; 0 famiglie perse fra modulo alimentare e dataset; righe famiglia x voce = famiglie x voci
  chieste in tutte le 23 wave.
- Confronto con i pannelli dello Step I (manzo, capra/pecora, maiale, pollame, uova, latte, 23 wave):
  stessi consumatori, compratori e spesa, salvo differenze spiegate una per una (2 acquisti anomali che
  lo Step I svuota, 1 risposta "no" con quantita', 386 famiglie del campo profughi del Malawi 2024).
- Verifica indipendente sui moduli grezzi (6 wave, 193 voci): stesse risposte "si'" e stessa spesa.
- I totali per categoria ricalcolati dalle colonne della tabella larga coincidono (464 controlli).

## Trovato durante il lavoro

- Malawi, voce 522 (pezzi di pollo, 2016-2024): nel dataset c'e', nella lista ITEMS_MW dello Step I no.
  Lo Step I sottostima il pollame del Malawi 2016-2024 (da correggere nella PARTE 4).
- Nigeria 2018 (wave 4) e 2023 (wave 5) non ci sono ancora: gli archivi non erano estratti sul PC.
