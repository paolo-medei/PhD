###############################################################################
##  CODICI DELLE UNITA' DI MISURA, per l'allegato del dataset sulle proteine
##  Per ogni wave legge le variabili di unita' del modulo alimentare e ne
##  riporta i codici con l'etichetta del questionario e quante righe delle voci
##  proteiche li usano. Il Malawi tiene il codice come testo e l'etichetta in una
##  variabile a parte (hh_g03b_label): si leggono le coppie osservate.
##  USO  Rscript unit_codes.R <cartella _unzipped> <item_map.csv> <out.csv>
###############################################################################
suppressPackageStartupMessages({ library(haven); library(dplyr); library(purrr) })
args <- commandArgs(TRUE); ROOT <- args[1]; MAP <- read.csv(args[2]); OUTF <- args[3]
find_dta <- function(stem, hint) {
  f <- list.files(ROOT, pattern = paste0("^", stem, "\\.dta$"), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  g <- f[grepl(hint, f, ignore.case = TRUE)]; if (length(g)) g[1] else NA_character_ }
## file, variabile della voce, variabili di unita' per fonte
U <- tribble(~country, ~year, ~file, ~hint, ~item, ~vars,
  "ETH", 2011, "sect5a_hh_w1", "ETH_2011", "hh_s5aq00", "hh_s5aq02_b,hh_s5aq03_b,hh_s5aq05_b,hh_s5aq06_b",
  "ETH", 2013, "sect5a_hh_w2", "ETH_2013", "hh_s5aq00", "hh_s5aq02_b,hh_s5aq03_b,hh_s5aq05_b,hh_s5aq06_b",
  "ETH", 2015, "sect5a_hh_w3", "ETH_2015", "item_cd",   "hh_s5aq02_b,hh_s5aq03_b,hh_s5aq05_b,hh_s5aq06_b",
  "ETH", 2018, "sect6a_hh_w4", "ETH_2018", "item_cd",   "s6aq02b,s6aq03b,s6aq05b,s6aq06b",
  "ETH", 2021, "sect6a_hh_w5", "ETH_2021", "item_cd",   "s6aq02b,s6aq03b,s6aq05b,s6aq06b",
  "TZA", 2008, "SEC_K1",       "TZA_2008", "skcode",    "skq2_meas,skq3_meas,skq5_meas,skq6_meas",
  "TZA", 2010, "HH_SEC_K1",    "TZA_2010", "itemcode",  "hh_k02_1,hh_k03_1,hh_k05_1,hh_k06_1",
  "TZA", 2012, "HH_SEC_J1",    "TZA_2012", "itemcode",  "hh_j02_1,hh_j03_1,hh_j05_1,hh_j06_1",
  "TZA", 2014, "hh_sec_j1",    "TZA_2014", "itemcode",  "hh_j02_1,hh_j03_1,hh_j05_1,hh_j06_1",
  "TZA", 2020, "hh_sec_ja1",   "TZA_2020", "itemcode",  "hh_ja02_1,hh_ja03_1,hh_ja05_1,hh_ja06_1,hh_ja02b_1",
  "MWI", 2010, "hh_mod_g1",    "MWI_2010_IHS-III.*Full_Sample", "hh_g02", "hh_g03b,hh_g04b,hh_g06b,hh_g07b",
  "MWI", 2016, "hh_mod_g1",    "MWI_2016", "hh_g02",    "hh_g03b,hh_g04b,hh_g06b,hh_g07b",
  "MWI", 2019, "hh_mod_g1",    "MWI_2019", "hh_g02",    "hh_g03b,hh_g04b,hh_g06b,hh_g07b",
  "MWI", 2024, "hh_mod_g1",    "MWI_2024", "hh_g02",    "hh_g03b,hh_g04b,hh_g06b,hh_g07b",
  "NGA", 2010, "sect10b_harvestw1", "NGA_2010", "item_cd", "s10bq2b,s10bq3b,s10bq5b,s10bq6b",
  "NGA", 2012, "sect10b_harvestw2", "NGA_2012", "item_cd", "s10bq2b,s10bq3b,s10bq5b,s10bq6b,s10bq7b",
  "NGA", 2015, "sect10b_harvestw3", "NGA_2015", "item_cd", "s10bq2b,s10bq3b,s10bq5b,s10bq6b,s10bq7b",
  "UGA", 2010, "GSEC15b", "UGA_2010", "itmcd", "untcd",
  "UGA", 2011, "GSEC15B", "UGA_2011", "itmcd", "untcd",
  "UGA", 2013, "GSEC15B", "UGA_2013", "itmcd", "untcd",
  "UGA", 2015, "gsec15b", "UGA_2015", "itmcd", "untcd",
  "UGA", 2018, "GSEC15B", "UGA_2018", "CEB01", "CEB03C",
  "UGA", 2019, "gsec15b", "UGA_2019", "CEB01", "CEB03C")

one <- function(i) {
  r <- U[i, ]; p <- find_dta(r$file, r$hint); if (is.na(p)) stop("missing ", r$file, " ", r$hint)
  f <- read_dta(p); codes <- MAP$code[MAP$country == r$country & floor(MAP$year) == r$year]
  prot <- as.numeric(zap_labels(f[[r$item]])) %in% codes
  vs <- strsplit(r$vars, ",")[[1]]; vs <- vs[vs %in% names(f)]
  map_dfr(vs, function(v) {
    x <- f[[v]]; lab <- attr(x, "labels")
    lv <- paste0(v, "_label")
    obs <- trimws(as.character(zap_labels(x)))
    if (lv %in% names(f)) {                                   # Malawi: etichetta in una variabile a parte
      ol <- as.character(as_factor(f[[lv]]))
      t <- tibble(code = obs, label = ol, prot = prot) %>% filter(!is.na(code), code != "") %>%
        group_by(code) %>% summarise(label = names(sort(table(label), decreasing = TRUE))[1], rows_protein_items = sum(prot), .groups = "drop")
    } else {
      t <- tibble(code = obs, prot = prot) %>% filter(!is.na(code), code != "", code != "NA") %>%
        group_by(code) %>% summarise(rows_protein_items = sum(prot), .groups = "drop")
      if (!is.null(lab)) {
        L <- tibble(code = trimws(as.character(unname(lab))), label = names(lab))
        t <- full_join(L, t, by = "code") %>% mutate(rows_protein_items = coalesce(rows_protein_items, 0L))
      } else t$label <- NA_character_
    }
    t %>% mutate(country = r$country, year = r$year, file = basename(p), variable = v)
  })
}
out <- map_dfr(seq_len(nrow(U)), one) %>%
  mutate(code_num = suppressWarnings(as.numeric(code))) %>%
  arrange(country, year, variable, code_num, code) %>%
  select(country, year, file, variable, code, label, rows_protein_items)
write.csv(out, OUTF, row.names = FALSE, na = "")
cat(nrow(out), "unit-code rows\n")
print(out %>% count(country, year))
