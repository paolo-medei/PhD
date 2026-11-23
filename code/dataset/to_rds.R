# food_items_long and households as .rds for R: same columns and values as the csv.gz, text columns with few values as factors
suppressMessages(library(readr))
a <- commandArgs(TRUE); d <- a[1]; t <- a[2]
fac <- c("country", "survey_round", "item_detail", "item", "food_group", "food_supergroup", "item_comparability", "consumption_status",
         "unit_total_label", "qty_status", "conv_method", "protein_coef_quality", "not_collected", "currency")
t0 <- Sys.time()
L <- read_csv(file.path(d, sprintf("food_items_long_%s.csv.gz", t)), guess_max = 1e6, progress = FALSE, show_col_types = FALSE,
              col_types = cols(hh_uid = "c", hhid = "c", unit_total_orig = "c", item_code_orig = "c", .default = col_guess()))
for (v in fac) L[[v]] <- factor(L[[v]])
L <- as.data.frame(L); attr(L, "spec") <- NULL
stopifnot(nrow(L) == 4584424, ncol(L) == 43)
saveRDS(L, file.path(d, sprintf("food_items_long_%s.rds", t)), compress = "xz")
cat("long", nrow(L), ncol(L), format(object.size(L), units = "MB"), "\n"); print(sapply(L, function(x) class(x)[1]))
H <- read_csv(file.path(d, sprintf("households_%s.csv.gz", t)), guess_max = 2e5, progress = FALSE, show_col_types = FALSE,
              col_types = cols(hh_uid = "c", hhid = "c", panel_id = "c", region = "c", district = "c", subdistrict = "c", ea = "c", strata = "c",
                               urban_rural_code = "c", .default = col_guess()))
H <- as.data.frame(H); attr(H, "spec") <- NULL
saveRDS(H, file.path(d, sprintf("households_%s.rds", t)), compress = "xz")
cat("households", nrow(H), ncol(H), "\n"); print(Sys.time() - t0)
