# all-food household budget as .rds for R (same columns and values as the csv.gz; identifiers and codes as text)
suppressMessages(library(readr))
a <- commandArgs(TRUE)
D <- read_csv(a[1], guess_max = 2e5, progress = FALSE, show_col_types = FALSE,
              col_types = cols(hhid = "c", panel_id = "c", region = "c", district = "c", subdistrict = "c", ea = "c", strata = "c",
                               not_collected = "c", sample = "c", food_away_flag = "c", welfare_scale = "c", welfare_var = "c", .default = col_guess()))
D <- as.data.frame(D); attr(D, "spec") <- NULL
saveRDS(D, a[2], compress = "xz"); cat(nrow(D), ncol(D), "\n")
