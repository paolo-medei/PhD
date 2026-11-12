###############################################################################
## Runs the pipeline module by module, in order, in one R session.
##
## The modules in pipeline/ are the v20 script (ASF_ALL_IN_ONE (20).R,
## 30 Sep 2026) cut at its own PART boundaries, then corrected one commit at a
## time (see docs/FINDINGS.md).
##
## How to run
##   RStudio: open this file and press "Source".
##   Terminal (from the repository root): Rscript code/run_all.R
## Data: if a folder "data" sits next to "code" (holding the ETH_*.zip,
## TZA_*.zip, NGA_*.zip archives) it is used, and results go to data/OUTPUT.
## Otherwise the script searches Desktop, Documents and OneDrive as v20 did.
###############################################################################
here <- function() {
  a <- commandArgs(FALSE); f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) return(dirname(normalizePath(f)))                 # Rscript
  for (i in rev(seq_len(sys.nframe()))) {                          # source()
    o <- sys.frame(i)$ofile; if (!is.null(o)) return(dirname(normalizePath(o)))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- rstudioapi::getSourceEditorContext()$path
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  getwd()
}
## If the file was run line by line (Run / Ctrl+Enter) instead of sourced,
## here() only sees the working directory; look in the usual places too.
has_mods <- function(d) length(list.files(file.path(d, "pipeline"),
                                          pattern = "^[0-9]{2}_.*[.]R$")) > 0
home <- unique(c(Sys.getenv("USERPROFILE"), path.expand("~"), dirname(path.expand("~"))))
home <- home[nzchar(home)]
cands <- c(here(), file.path(getwd(), "code"),
           if (nzchar(Sys.getenv("ASF_DATA_ROOT")))
             file.path(dirname(Sys.getenv("ASF_DATA_ROOT")), "code"),
           file.path(home, "Desktop", "PhD_v21", "code"),
           Sys.glob(file.path(home, "OneDrive*", "Desktop", "PhD_v21", "code")))
CODE_DIR <- Find(has_mods, cands, nomatch = cands[1])
data_dir <- file.path(dirname(CODE_DIR), "data")
if (!nzchar(Sys.getenv("ASF_DATA_ROOT")) && dir.exists(data_dir))
  Sys.setenv(ASF_DATA_ROOT = normalizePath(data_dir))
message("data: ", if (nzchar(Sys.getenv("ASF_DATA_ROOT"))) Sys.getenv("ASF_DATA_ROOT") else "auto-detect")

mods <- sort(list.files(file.path(CODE_DIR, "pipeline"), pattern = "^[0-9]{2}_.*[.]R$",
                        full.names = TRUE))
if (!length(mods)) stop("Cannot find the pipeline modules in ", file.path(CODE_DIR, "pipeline"),
  ".\nRun this file with source(), giving its full path, e.g.\n",
  '  source("C:/Users/<you>/Desktop/PhD_v21/code/run_all.R")')
message("code: ", CODE_DIR, " (", length(mods), " modules)")
for (m in mods) {
  message("\n>>> ", basename(m))
  sys.source(m, envir = globalenv())
}
