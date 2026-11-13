## Compare two RESULTS workbooks sheet by sheet, cell by cell.
## Usage: Rscript checks/compare_runs.R old.xlsx new.xlsx [sheet-name-regex]
## (run_all.R does this by itself at the end, against results_reference/.)
me <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(dirname(dirname(me)), "code", "compare_results.R"))
a <- commandArgs(TRUE)
print(compare_workbooks(a[1], a[2], if (length(a) > 2) a[3] else "."), right = FALSE, row.names = FALSE)
