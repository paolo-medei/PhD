# Verifica indipendente dei pannelli (12-13 novembre 2026)

Per ogni paese un controllo separato ha ricostruito in Python ogni colonna di `panel_XXX.csv` dai file
`.dta` grezzi, scegliendo le variabili dalle etichette e senza leggere il codice R, e l'ha confrontata
riga per riga con il pannello della pipeline.

| Cartella | Prima verifica | Dopo le correzioni D11-D19 |
|---|---|---|
| `ETH/` | `match_rates.csv` | `match_rates_v2.csv`: 100% in ogni colonna tranne `coffee_plots`/`coffee_grower` 2011 (limite noto) |
| `TZA/` | `match_rates.csv` | `reaudit_rates.csv`: 100% con le convenzioni dichiarate (uova 55 g, latte kg = litri) |
| `NGA/` | `match_rates.csv` | `match_rates_v2.csv`: 100% in ogni colonna e wave |

`r_vs_python.csv`: le stime principali (decomposizione per wave, quote di acquirenti per quinto, effetti
fissi familiari, reddito permanente e transitorio, differenze lunghe, entrata, varietà) stimate dalla
pipeline R e da `checks/independent_estimates.py`. Coincidono esattamente; le quote per quinto differiscono
al massimo di 0,07 punti, per come vengono assegnate le famiglie ai confini tra quinti.

Gli script (`rebuild*.py`, `reaudit.py`, `recheck_v2.py`) sono conservati come registro: i percorsi dei
dati al loro interno sono quelli della macchina su cui sono stati eseguiti.
