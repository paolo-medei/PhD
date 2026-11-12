###############################################################################
## ONE WORKBOOK — every table produced by this run, one sheet each
###############################################################################
csvs <- sort(list.files(TMPCSV, pattern="\\.csv$", full.names=TRUE))
if (length(csvs)) {
  wb <- createWorkbook()
  hdr <- createStyle(textDecoration="bold", fgFill="#1F3864",
                     fontColour="#FFFFFF", halign="center", border="Bottom")
  ## a contents sheet, so the workbook explains itself
  idx <- tibble(sheet = character(), file = character(), rows = integer())
  for (f in csvs) {
    nm <- tools::file_path_sans_ext(basename(f))
    sh <- substr(gsub("[^A-Za-z0-9_]", "_", nm), 1, 31)   # Excel caps at 31 chars
    d  <- read.csv(f, stringsAsFactors=FALSE)
    addWorksheet(wb, sh)
    writeData(wb, sh, d, headerStyle=hdr)
    freezePane(wb, sh, firstRow=TRUE)
    setColWidths(wb, sh, cols=1:max(1,ncol(d)), widths="auto")
    idx <- bind_rows(idx, tibble(sheet=sh, file=basename(f), rows=nrow(d)))
  }
  addWorksheet(wb, "CONTENTS"); worksheetOrder(wb) <- c(nrow(idx)+1, seq_len(nrow(idx)))
  writeData(wb, "CONTENTS", idx, headerStyle=hdr)
  setColWidths(wb, "CONTENTS", cols=1:3, widths="auto")
  xlsx <- file.path(RUN_DIR, paste0("RESULTS_", RUN_STAMP, ".xlsx"))
  saveWorkbook(wb, xlsx, overwrite=TRUE)
  message("workbook  -> ", xlsx, "  (", nrow(idx), " sheets)")
  unlink(TMPCSV, recursive=TRUE)          # one workbook, no loose CSVs
}

message("\n=== ALL DONE ===")
message("  results  -> ", RUN_DIR)
message("  figures  -> ", FIGDIR, "   (VC_01..VC_10 first, zz_* are diagnostics)")
message("  panels   -> ", OUT_DIR)
###############################################################################
