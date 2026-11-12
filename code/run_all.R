###############################################################################
## Runs the pipeline module by module, in order, in one R session.
##
## The modules in pipeline/ are the v20 script (ASF_ALL_IN_ONE (20).R,
## 30 Sep 2026) cut at its own PART boundaries. Concatenated, they are
## byte-identical to v20, so this runner reproduces v20 exactly.
##
## Usage (from the repository root):   Rscript code/run_all.R
###############################################################################
here <- function() {
  a <- commandArgs(FALSE); f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}
mods <- sort(list.files(file.path(here(), "pipeline"), pattern = "^[0-9]{2}_.*[.]R$",
                        full.names = TRUE))
for (m in mods) {
  message("\n>>> ", basename(m))
  sys.source(m, envir = globalenv())
}
