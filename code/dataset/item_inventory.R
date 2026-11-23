###############################################################################
##  INVENTARIO DELLE VOCI dei moduli alimentari (passo 0 del dataset sulle proteine)
##  Per ogni wave: codice della voce, etichetta del questionario, righe nel file
##  (anche le etichette senza righe). E' l'ingresso di make_item_map.py.
##  USO  Rscript item_inventory.R <cartella _unzipped> <item_inventory.csv>
###############################################################################
suppressPackageStartupMessages({library(haven); library(dplyr)})
args <- commandArgs(TRUE); ARCH_ROOT <- args[1]; OUTF <- if (length(args) > 1) args[2] else "item_inventory.csv"
find_dta <- function(stem, hint = NULL) {
  f <- list.files(ARCH_ROOT, pattern = paste0("^", stem, "\\.dta$"), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (!is.null(hint) && length(f) > 1) { g <- f[grepl(hint, f, ignore.case = TRUE)]; if (length(g)) f <- g }
  if (!length(f)) NA_character_ else f[1] }
S <- list(
 list("ETH",2011,"sect5a_hh_w1","ETH_2011","hh_s5aq00"), list("ETH",2013,"sect5a_hh_w2","ETH_2013","hh_s5aq00"),
 list("ETH",2015,"sect5a_hh_w3","ETH_2015","item_cd"), list("ETH",2018,"sect6a_hh_w4","ETH_2018","item_cd"),
 list("ETH",2021,"sect6a_hh_w5","ETH_2021","item_cd"),
 list("TZA",2008,"SEC_K1","TZA_2008","skcode"), list("TZA",2010,"HH_SEC_K1","TZA_2010","itemcode"),
 list("TZA",2012,"HH_SEC_J1","TZA_2012","itemcode"), list("TZA",2014,"hh_sec_j1","TZA_2014","itemcode"),
 list("TZA",2020,"hh_sec_ja1","TZA_2020","itemcode"), list("TZA",2020.1,"hh_sec_j1","TZA_2020","itemcode"),
 list("MWI",2010,"hh_mod_g1","MWI_2010_IHS-III.*Full_Sample","hh_g02"), list("MWI",2016,"hh_mod_g1","MWI_2016","hh_g02"),
 list("MWI",2019,"hh_mod_g1","MWI_2019","hh_g02"), list("MWI",2024,"hh_mod_g1","MWI_2024","hh_g02"),
 list("NGA",2010,"sect10b_harvestw1","NGA_2010","item_cd"), list("NGA",2012,"sect10b_harvestw2","NGA_2012","item_cd"),
 list("NGA",2015,"sect10b_harvestw3","NGA_2015","item_cd"),
 list("NGA",2018,"sect10b_harvestw4","NGA_2018","item_cd"),
 list("NGA",2023,"sect5b_harvestw5","NGA_2023","item_cd"),
 list("UGA",2010,"GSEC15b","UGA_2010","itmcd"), list("UGA",2011,"GSEC15B","UGA_2011","itmcd"),
 list("UGA",2013,"GSEC15B","UGA_2013","itmcd"), list("UGA",2015,"gsec15b","UGA_2015","itmcd"),
 list("UGA",2018,"GSEC15B","UGA_2018","CEB01"), list("UGA",2019,"gsec15b","UGA_2019","CEB01"))
out <- list()
for (s in S) {
  p <- find_dta(s[[3]], s[[4]]); if (is.na(p) || !grepl(s[[4]], p)) { cat("MISSING", unlist(s), "\n"); next }
  d <- read_dta(p, col_select = all_of(s[[5]]))
  x <- d[[1]]; lv <- attr(x, "labels")
  tb <- as.data.frame(table(code = as.numeric(zap_labels(x))), stringsAsFactors = FALSE)
  lab <- if (!is.null(lv)) names(lv)[match(as.numeric(tb$code), as.numeric(lv))] else NA
  out[[length(out)+1]] <- data.frame(country = s[[1]], year = s[[2]], file = sub(paste0(ARCH_ROOT,"/"), "", p),
                                     itemvar = s[[5]], code = as.numeric(tb$code), label = lab, rows = tb$Freq)
  ## labels defined but not present in data
  if (!is.null(lv)) { miss <- setdiff(as.numeric(lv), as.numeric(tb$code))
    if (length(miss)) out[[length(out)+1]] <- data.frame(country = s[[1]], year = s[[2]], file = sub(paste0(ARCH_ROOT,"/"), "", p),
        itemvar = s[[5]], code = miss, label = names(lv)[match(miss, as.numeric(lv))], rows = 0) }
}
inv <- bind_rows(out) %>% arrange(country, year, code)
write.csv(inv, OUTF, row.names = FALSE)
cat(nrow(inv), "rows\n")
