# Da dove viene ogni numero delle slide (presentazione del 7 ottobre 2026)

Fonte: `RESULTS_2026-09-30_18-49.xlsx`, la run della v20 del 30 settembre. Le slide sono state
costruite su quella run; `ANALISI_semplice.R` (5 ottobre) non è la fonte dei numeri.

| Slide | Numero | Fonte | Esito |
|---|---|---|---|
| 6 | 25.914 / 19.841 / 18.668 osservazioni | conteggio famiglie × wave nei pannelli | torna (con Nigeria 2018) |
| 8 | Etiopia: comprano carne dal 4% al 42% (×10) | `ETH_14_participation_quintile`, `meat_agg` Q1 4,1 → Q5 41,8 | torna; quintili su acquisti |
| 8 | "Probit (beef)" 0,16 / 0,23 / 0,20 | `*_22_four_margins`, `beef`, `e_participation` = 0,159 / 0,229 / 0,197 | **modello lineare sul consumo, non probit sugli acquisti** (M1) |
| 9 | "significativo in 12 wave su 14" | `*_01_decomposition`, `meat_agg`, `p_quality < 0,05`: 3/5 + 5/5 + 4/4 | torna |
| 9 | qualità = 8-16% della risposta | `COMPARE_01_summary`, `quality_share` (carne 8,4-15,2%; il 16% è il caffè) | da precisare |
| 9 | kg ×1,7-×4,0; prezzo al kg +10%-+52%; bande bootstrap | nessuna tabella della v20 né di `ANALISI_semplice.R` | **non rintracciato** |
| 10 | Etiopia: latticini 32% → 11%, capre e pecore 24% → 41% | `ETH_20_basket_by_quintile`, quote ricalcolate **escludendo il pesce** | torna |
| 10 | Nigeria: manzo 61% → 45%, pollame 5% → 23% | `NGA_20_basket_by_quintile`, quote ricalcolate **escludendo il pesce** | torna; ma quintili nigeriani sbagliati (D2) |
| 10 | elasticità della varietà 0,26-0,32 | `VC_01_multiplier`, `Variety` = 0,259 / 0,324 / 0,281 | torna; modello senza effetti fissi regionali (M6) |
| 11 | "PIL pro capite 1.000-1.600 USD" | tabella `INCOME` nello script | **sbagliato** (M8) |
| 12 | "per adulto equivalente in Etiopia e Tanzania" | etichette dei file | **vero solo per l'Etiopia e la Tanzania 2020** (D3) |

Il copione (docx) riporta le quote del paniere *con* il pesce (30% → 11%, 22% → 41%, 40% → 28%,
3% → 14%): stessa tabella, base diversa.
