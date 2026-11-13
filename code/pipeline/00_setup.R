###############################################################################
##                                                                           ##
##   ANIMAL-SOURCE FOOD & COFFEE DEMAND — ETHIOPIA AND TANZANIA               ##
##   ONE SCRIPT: raw survey archives  ->  panels  ->  results  ->  comparison ##
##                                                                           ##
##   Just run it. It finds the .zip archives, extracts them once, builds both
##   country panels, validates them, estimates, compares, and runs the
##   advanced layer. Nothing to upload, nothing to run in sequence.
##
##   WHAT IT PRODUCES, in <archive folder>/OUTPUT
##     panel_ETH.csv, panel_TZA.csv          harmonised household x product
##     XXX_01_decomposition.csv              Deaton: quantity vs quality
##     XXX_02_price_elasticities.csv         price response
##     XXX_10..14_*.csv                      sources, total vs purchased,
##                                           household fixed effects,
##                                           instrumented selection, quintiles
##     COMPARE_*.csv                         cross-country synthesis
##     figures_ETH / figures_TZA / figures_COMPARE / figures_ADVANCED
##
##   WHAT IT DOES, and why each step exists
##     1  BUILD    every mapping verified against the survey's own variable and
##                 value labels. Seven documented traps per country: sections
##                 that move between waves, household ids that change meaning,
##                 unit codes that flip, a sample that splits in two.
##     2  VALIDATE six gates per country. The build is not trusted until the
##                 household counts reconcile with the published aggregates and
##                 the unit values track inflation.
##     3  ESTIMATE Deaton decomposition with household-size and demographic
##                 controls, a saturation test, and price elasticities from a
##                 price the household itself did not choose.
##     4  COMPARE  the countries on the income axis.
##     5  ADVANCE  total consumption rather than purchases only; household
##                 fixed effects; selection corrected with livestock ownership
##                 as the exclusion restriction.
##
##   RUN TIME roughly 10-20 minutes the first time (extraction plus an 84 MB
##   Ethiopian food module); a few minutes afterwards.
###############################################################################

## ============================== CONFIG ==================================== #
DATA_ROOT <- Sys.getenv("ASF_DATA_ROOT", "")  # "" -> auto-detect the folder holding ETH_*.zip / TZA_*.zip
OUT_DIR   <- ""      # "" -> OUTPUT next to the archives
RUN_BUILD <- TRUE    # FALSE to reuse existing panel_XXX.csv and skip the build
RUN_ADV   <- TRUE    # FALSE to skip the advanced layer
RUN_DEEP  <- TRUE    # FALSE to skip the deep descriptive/analytical layer
RUN_PERM  <- TRUE    # FALSE to skip the permanent-vs-transitory tests
RUN_NGA   <- TRUE    # FALSE to skip Nigeria
RUN_UGA   <- TRUE    # FALSE to skip Uganda (skipped anyway if its archives are not there)
RUN_MWI   <- TRUE    # FALSE to skip Malawi (skipped anyway if its archives are not there)
RUN_VC    <- TRUE    # FALSE to skip the value-chain module
RUN_MARGINS <- TRUE  # FALSE to skip the three margins, panel intervals and coffee (PART 9)
MARGINS_B <- 100     # bootstrap replications for the three margins (100 takes a few minutes)

## ============================== PACKAGES ================================== #
need <- c("haven","dplyr","tidyr","stringr","purrr","labelled","ggplot2","fixest",
          "openxlsx","patchwork")
for (p in need) if (!requireNamespace(p, quietly=TRUE)) install.packages(p)
suppressPackageStartupMessages({
  library(haven); library(dplyr); library(tidyr); library(stringr)
  library(purrr); library(labelled); library(ggplot2); library(fixest)
  library(openxlsx)
})
options(dplyr.summarise.inform = FALSE)
num <- function(x) suppressWarnings(as.numeric(x))

## ==================== FIND THE ARCHIVES, EXTRACT ONCE ===================== #
if (!nzchar(DATA_ROOT) || !dir.exists(DATA_ROOT)) {
  home  <- Sys.getenv("USERPROFILE"); if (!nzchar(home)) home <- path.expand("~")
  cands <- c(list.dirs(home, recursive = FALSE, full.names = TRUE), home)
  cands <- cands[grepl("OneDrive|Desktop|Documents", basename(cands), ignore.case = TRUE)]
  hit <- NULL
  for (r in c(cands, home)) {
    if (!dir.exists(r)) next
    z <- list.files(r, pattern = "^(ETH|TZA|NGA|UGA|MWI)_.*\\.zip$", recursive = TRUE, full.names = TRUE)
    if (length(z)) { hit <- dirname(z[1]); break }
    f <- list.files(r, pattern = "^(sect6a_hh_w5|hh_sec_ja1)\\.dta$",
                    recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    if (length(f)) { hit <- r; break }
  }
  if (is.null(hit)) stop(
    "Could not find the data.\n",
    "Set DATA_ROOT to the folder holding the ETH_*.zip and TZA_*.zip archives.\n",
    "Tip: Shift + right-click the folder -> 'Copy as path', paste it, turn \\ into /.")
  DATA_ROOT <- hit
  message("DATA_ROOT -> ", DATA_ROOT)
}

ARCH_ROOT <- DATA_ROOT
zips <- list.files(DATA_ROOT, pattern = "^(ETH|TZA|NGA|UGA|MWI)_.*\\.zip$",
                   recursive = TRUE, full.names = TRUE)
if (length(zips)) {
  UNZ <- file.path(DATA_ROOT, "_unzipped"); dir.create(UNZ, showWarnings = FALSE)
  for (z in zips) {
    dest <- file.path(UNZ, tools::file_path_sans_ext(basename(z)))
    if (dir.exists(dest) && length(list.files(dest, recursive = TRUE))) next
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    message("unzipping ", basename(z), " ...")
    utils::unzip(z, exdir = dest)
  }
  ARCH_ROOT <- UNZ
}
if (!nzchar(OUT_DIR)) OUT_DIR <- file.path(DATA_ROOT, "OUTPUT")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

## Every run gets its own dated folder, so nothing is ever overwritten and two
## runs can be compared side by side. The PANELS stay in OUTPUT itself: they are
## the data, not a result, and a later run with RUN_BUILD = FALSE must find them.
RUN_STAMP <- format(Sys.time(), "%Y-%m-%d_%H-%M")     # date + hour + minute
RUN_DIR   <- file.path(OUT_DIR, paste0("run_", RUN_STAMP))
FIGDIR    <- file.path(RUN_DIR, "figures")
## the tables are written here as scratch CSVs, gathered into ONE workbook at
## the end, and this folder is then removed. The run folder ends up holding a
## single .xlsx and a figures folder - nothing else.
TMPCSV    <- file.path(RUN_DIR, "_tmp_tables")
## ONE figures folder. The ten that carry the argument are named VC_01..VC_10
## and sort to the top; everything else is prefixed zz_ and sorts to the bottom.
FIGDIAG   <- FIGDIR
dir.create(FIGDIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TMPCSV, recursive = TRUE, showWarnings = FALSE)
## Earlier versions of this script wrote loose CSVs and figure folders straight
## into OUTPUT. They are swept into _previous_runs so that OUTPUT holds only the
## panels and the dated run folders. Nothing is deleted.
stray_csv <- setdiff(list.files(OUT_DIR, pattern="\\.csv$", full.names=TRUE),
                     list.files(OUT_DIR, pattern="^panel_[A-Z]{3}\\.csv$",
                                full.names=TRUE))
stray_dir <- list.dirs(OUT_DIR, recursive=FALSE, full.names=TRUE)
stray_dir <- stray_dir[grepl("^figures", basename(stray_dir))]
if (length(stray_csv) || length(stray_dir)) {
  OLD <- file.path(OUT_DIR, "_previous_runs")
  dir.create(OLD, showWarnings=FALSE)
  for (f in c(stray_csv, stray_dir))
    suppressWarnings(file.rename(f, file.path(OLD, basename(f))))
  message("tidied ", length(stray_csv) + length(stray_dir),
          " leftover items from earlier runs -> ", OLD)
}

message("OUT_DIR   -> ", OUT_DIR)
message("RUN_DIR   -> ", RUN_DIR)

## -------------------------------------------------------- file resolution --#
## Wave archives reuse file names (hh_sec_a.dta exists in several Tanzanian
## waves), so a stem can be disambiguated with a path hint such as "TZA_2012".
find_dta <- function(stem, hint = NULL) {
  f <- list.files(ARCH_ROOT, pattern = paste0("^", stem, "\\.dta$"),
                  recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (!is.null(hint) && length(f) > 1) {
    g <- f[grepl(hint, f, ignore.case = TRUE)]
    if (length(g)) f <- g
  }
  if (!length(f)) NA_character_ else f[1]
}
find_et <- function(stem) find_dta(stem)
rd_et <- function(stem) {
  p <- find_et(stem); if (is.na(p)) stop("missing file: ", stem)
  haven::read_dta(p)
}
rd_tz <- function(yr, stem) {
  p <- find_dta(stem, paste0("TZA_", yr))
  if (is.na(p)) stop("missing ", stem, " for ", yr)
  haven::read_dta(p)
}
val_labels <- labelled::val_labels

## v22: used by the Uganda and Malawi builds (TRAP U10, M6). The price of each
## purchase row (spending / converted quantity); above 10 times or below a
## tenth of the wave's median for the product it is a unit error (a tray
## recorded as one egg, grams typed as kilos): the row's quantities are
## emptied, so the purchase counts as bought but not as a unit value.
flag_price_outliers <- function(f) {
  pe  <- ifelse(f$purch_std > 0 & f$exp > 0, f$exp / f$purch_std, NA)
  med <- ave(pe, f$product, FUN = function(x) median(x, na.rm = TRUE))
  bad <- !is.na(pe) & (pe > 10 * med | pe < med / 10)
  f[bad, c("qty_std", "purch_std", "own_std", "gift_std")] <- NA
  f
}


