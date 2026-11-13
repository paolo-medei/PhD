###############################################################################
## Compare two RESULTS workbooks sheet by sheet, cell by cell.
##   compare_workbooks(reference.xlsx, new.xlsx)  ->  one row per sheet:
##     IDENTICAL        every number within 1e-6 (relative) and every label equal
##     ~same (<0.1%)    largest relative difference below 1e-3 (rounding, other
##                      package versions, threads)
##     NUMBERS DIFFER / LABELS DIFFER / DIFFERENT SHAPE   something changed
## Used at the end of run_all.R against results_reference/, and by
## checks/compare_runs.R from a terminal.
###############################################################################
compare_workbooks <- function(old, new, pat = ".") {
  so <- openxlsx::getSheetNames(old); sn <- openxlsx::getSheetNames(new)
  so <- setdiff(so[grepl(pat, so)], "CONTENTS"); sn <- setdiff(sn[grepl(pat, sn)], "CONTENTS")
  res <- list()
  for (s in setdiff(so, sn)) res[[s]] <- data.frame(sheet = s, status = "ONLY IN REFERENCE", detail = "")
  for (s in setdiff(sn, so)) res[[s]] <- data.frame(sheet = s, status = "ONLY IN NEW RUN", detail = "")
  for (s in sort(intersect(so, sn))) {
    o <- openxlsx::read.xlsx(old, s); n <- openxlsx::read.xlsx(new, s)
    if (!identical(dim(o), dim(n)) || !identical(names(o), names(n))) {
      res[[s]] <- data.frame(sheet = s, status = "DIFFERENT SHAPE",
                             detail = sprintf("reference %dx%d, new %dx%d", nrow(o), ncol(o), nrow(n), ncol(n)))
      next
    }
    num <- names(o)[sapply(o, is.numeric) & sapply(n, is.numeric)]
    chr <- setdiff(names(o), num)
    bad <- chr[!sapply(chr, function(k) identical(as.character(o[[k]]), as.character(n[[k]])))]
    d <- sapply(num, function(k) { x <- o[[k]]; y <- n[[k]]
      if (!identical(is.na(x), is.na(y))) return(Inf)
      m <- !is.na(x); if (!any(m)) 0 else max(abs(x[m] - y[m]) / pmax(1e-9, abs(x[m]))) })
    worst <- if (length(d)) max(d) else 0
    res[[s]] <- data.frame(sheet = s,
      status = if (length(bad)) "LABELS DIFFER" else if (worst < 1e-6) "IDENTICAL" else
               if (worst < 1e-3) "~same (<0.1%)" else "NUMBERS DIFFER",
      detail = if (length(bad)) paste("column", bad[1]) else
               if (length(d) && worst > 0) sprintf("max rel. diff %.3g in %s", worst, names(d)[which.max(d)]) else "")
  }
  out <- do.call(rbind, res); rownames(out) <- NULL
  out[order(out$status != "IDENTICAL", out$sheet), ]
}
