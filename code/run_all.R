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
## At the end the new RESULTS workbook is compared with the newest one in
## results_reference/ (next to code/), and the verdict is printed.
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
## v22 renamed 10_workbook.R to 11_workbook.R: a copy left over from v21 would run twice
mods <- mods[!(basename(mods) == "10_workbook.R" & any(basename(mods) == "11_workbook.R"))]
if (!length(mods)) stop("Cannot find the pipeline modules in ", file.path(CODE_DIR, "pipeline"),
  ".\nRun this file with source(), giving its full path, e.g.\n",
  '  source("C:/Users/<you>/Desktop/PhD_v21/code/run_all.R")')
message("code: ", CODE_DIR, " (", length(mods), " modules)")
t0 <- Sys.time()
for (m in mods) {
  message("\n>>> ", basename(m))
  sys.source(m, envir = globalenv())
}
message(sprintf("\nrun time: %.0f minutes", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

## ---- check this run against the reference results ---------------------------
## results_reference/ (next to code/) holds the workbook produced by the same
## code on the same archives. The newest RESULTS_*.xlsx there is compared with
## the one just written, sheet by sheet and cell by cell.
ref_dir <- file.path(dirname(CODE_DIR), "results_reference")
refs <- sort(list.files(ref_dir, pattern = "^RESULTS_.*[.]xlsx$", full.names = TRUE), decreasing = TRUE)
new_xlsx <- file.path(RUN_DIR, paste0("RESULTS_", RUN_STAMP, ".xlsx"))
if (!length(refs)) {
  message("\nno reference workbook in ", ref_dir, " - comparison skipped")
} else if (file.exists(new_xlsx)) {
  source(file.path(CODE_DIR, "compare_results.R"), local = TRUE)
  cmp <- compare_workbooks(refs[1], new_xlsx)
  write.csv(cmp, file.path(RUN_DIR, "COMPARISON_with_reference.csv"), row.names = FALSE)
  ok <- cmp$status %in% c("IDENTICAL", "~same (<0.1%)")
  message("\n=== CHECK against ", basename(refs[1]), " ===")
  print(table(cmp$status))
  if (all(ok)) {
    message("OK: all ", nrow(cmp), " tables match the reference.")
  } else {
    message("ATTENTION: ", sum(!ok), " of ", nrow(cmp), " tables differ from the reference:")
    print(cmp[!ok, ], row.names = FALSE, right = FALSE)
  }
  message("full list -> ", file.path(RUN_DIR, "COMPARISON_with_reference.csv"))
}
