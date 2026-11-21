## Uso: ASF_DATA_ROOT=<cartella dati> OUTP=<cartella di uscita> Rscript checks/dump_panel_ids.R
## Scrive pids_ETH/NGA/TZA.csv (panel_ids(), PARTE 9 dello script unico) per
## independent_estimates.py. Esegue solo PARTE 0 e PARTE 1 dello script (fino
## alla prima costruzione) e poi definisce le funzioni, senza stimare niente.
suppressPackageStartupMessages({library(dplyr)})
me  <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
src <- file.path(dirname(dirname(me)), "code", "ASF_completo.R")
ex  <- parse(src)
is_fun <- function(e) is.call(e) && identical(e[[1]], as.name("<-")) &&
  is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))
k <- which(sapply(ex, function(e) is.call(e) && identical(e[[1]], as.name("if")) &&
                    identical(e[[2]], as.name("RUN_BUILD"))))[1]
for (e in ex[seq_len(k - 1)]) eval(e, globalenv())
for (e in ex[k:length(ex)]) if (is_fun(e)) eval(e, globalenv())
for (cc in c("ETH", "NGA", "TZA"))
  write.csv(panel_ids(cc), file.path(Sys.getenv("OUTP"), paste0("pids_", cc, ".csv")), row.names = FALSE)
