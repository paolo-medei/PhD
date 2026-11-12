## Usage: ASF_DATA_ROOT=<data folder> OUTP=<output folder> Rscript checks/dump_panel_ids.R
## Writes pids_ETH/NGA/TZA.csv (panel_ids() of 06_advanced.R) for independent_estimates.py
suppressPackageStartupMessages({library(dplyr)})
me   <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
pipe <- file.path(dirname(dirname(me)), "code", "pipeline")
sys.source(file.path(pipe, "00_setup.R"), envir = globalenv())
ex <- parse(file.path(pipe, "06_advanced.R"))
for (e in ex) if (is.call(e) && identical(e[[1]], as.name("<-")) &&
                  is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))) eval(e, globalenv())
for (cc in c("ETH", "NGA", "TZA"))
  write.csv(panel_ids(cc), file.path(Sys.getenv("OUTP"), paste0("pids_", cc, ".csv")), row.names = FALSE)
