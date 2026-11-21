## Confronta due workbook RESULTS foglio per foglio, cella per cella.
## Uso: Rscript checks/compare_runs.R vecchio.xlsx nuovo.xlsx [regex dei fogli]
## (code/ASF_completo.R lo fa da solo alla fine, PARTE 16, contro results_reference/.)
## La funzione compare_workbooks() si prende dallo script unico, senza eseguirlo.
me  <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
src <- file.path(dirname(dirname(me)), "code", "ASF_completo.R")
for (e in parse(src)) if (is.call(e) && identical(e[[1]], as.name("<-")) &&
                          identical(e[[2]], as.name("compare_workbooks"))) eval(e, globalenv())
a <- commandArgs(TRUE)
print(compare_workbooks(a[1], a[2], if (length(a) > 2) a[3] else "."), right = FALSE, row.names = FALSE)
