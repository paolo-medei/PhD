# Produzione zootecnica e caffè: cosa c'è nelle indagini

Inventario fatto il 12 novembre 2026 leggendo le etichette delle variabili di tutti i file
(`checks/production_inventory.R`; elenco completo con nomi delle variabili in
`docs/production_inventory.csv`). È una ricerca per parole chiave: dice dove guardare, non
garantisce che ogni variabile sia utilizzabile. Per ora non è usato nella pipeline.

## Caffè

| | Consumo | Produzione |
|---|---|---|
| **Etiopia** | modulo alimentare, item 24 (2011-15) / 801 (2018-21): quantità, spesa, autoconsumo | campo per campo, codice coltura 72: superficie, coltura pura o mista, coltura arborea sì/no, **numero di piante** (`sect4_pp`); raccolto (`sect9_ph`, `sect12_ph`); vendite e valore (`sect11/12_ph`). La v20 usa già raccolto e vendite (`build_coffee_et`) |
| **Tanzania** | item 1102, **"coffee and cocoa" insieme**: non separabile | colture permanenti (`AG_SEC_6A/6B`, `SEC_6A/6B` nel 2008): **numero di piante per appezzamento, anno d'impianto, piante messe a dimora negli ultimi 12 mesi**; vendite delle colture permanenti (`AG_SEC_7A/7B`); contratti con acquirenti / outgrower (`AG_SEC_9C`, `SEC_8C`) |
| **Nigeria** | item 120 | colture arboree (`sect11f/11g`): area coperta da alberi, numero di piante; il caffè in Nigeria è marginale |

Le domande di comunità dell'Etiopia elencano anche le colture principali di ogni villaggio.

## Produzione zootecnica

| | Capi posseduti | Latte | Uova | Macellazione | Vendita di animali |
|---|---|---|---|---|---|
| **Etiopia** | tutte le wave (`sect8a_ls`, `sect8_1_ls`) | 2011-13 litri al giorno per capo; 2018-21 prodotto e venduto (`sect8_4_ls`) | uova per covata e vendute (tutte le wave) | 2015-21 capi macellati; 2011-13 capi destinati alla macellazione | sì |
| **Tanzania** | tutte le wave (`SEC_10A`, `AG_SEC10A`, `LF_SEC_02`) | 2012-20 litri al giorno per capo munto, mesi, vendite (`LF_SEC_06`) | da verificare | tutte le wave: capi macellati, venduti, peso vivo | sì |
| **Nigeria** | sì (`sect11i`) | non trovato nel 2010-15 | non trovato nel 2010-15 | capi macellati per vendita e per consumo | sì |

Con questi dati si possono costruire, per famiglia: se alleva, quanti capi per specie, quanto latte
produce e quanto ne vende, quanti animali macella o vende, e per il caffè quante piante ha, quanto
raccoglie e quanto vende. Per la Tanzania il caffè del modulo alimentare è mescolato al cacao.
