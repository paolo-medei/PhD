## Compare two RESULTS workbooks sheet by sheet, cell by cell.
## Usage: Rscript compare_runs.R old.xlsx new.xlsx [sheet-prefix-regex]
suppressPackageStartupMessages(library(openxlsx))
a <- commandArgs(TRUE); old <- a[1]; new <- a[2]; pat <- if (length(a) > 2) a[3] else "."
so <- getSheetNames(old); sn <- getSheetNames(new)
sh <- sort(intersect(so[grepl(pat, so)], sn))
cat("sheets only in old:", paste(setdiff(so[grepl(pat, so)], sn), collapse=", "), "\n")
cat("sheets only in new:", paste(setdiff(sn[grepl(pat, sn)], so), collapse=", "), "\n\n")
res <- list()
for (s in sh) {
  o <- read.xlsx(old, s); n <- read.xlsx(new, s)
  if (!identical(dim(o), dim(n)) || !identical(names(o), names(n))) {
    res[[s]] <- data.frame(sheet=s, status="DIFFERENT SHAPE",
                           detail=sprintf("old %dx%d, new %dx%d", nrow(o), ncol(o), nrow(n), ncol(n)))
    next
  }
  num <- names(o)[sapply(o, is.numeric) & sapply(n, is.numeric)]
  chr <- setdiff(names(o), num)
  same_chr <- all(sapply(chr, function(k) identical(as.character(o[[k]]), as.character(n[[k]]))))
  d <- sapply(num, function(k) { x <- o[[k]]; y <- n[[k]]
    if (!identical(is.na(x), is.na(y))) return(Inf)
    m <- !is.na(x); if (!any(m)) 0 else max(abs(x[m] - y[m]) / pmax(1e-9, abs(x[m]))) })
  worst <- if (length(d)) max(d) else 0
  res[[s]] <- data.frame(sheet=s,
    status = if (!same_chr) "LABELS DIFFER" else if (worst < 1e-6) "IDENTICAL" else if (worst < 1e-3) "~same (<0.1%)" else "NUMBERS DIFFER",
    detail = if (length(d) && worst > 0) sprintf("max rel. diff %.3g in %s", worst, names(d)[which.max(d)]) else "")
}
out <- do.call(rbind, res); rownames(out) <- NULL
print(out, right = FALSE)
