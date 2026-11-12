## Inventory of PRODUCTION information in the LSMS-ISA archives: livestock
## holdings, milk / eggs / meat output and sales, coffee plots, trees, harvest
## and sales. Reads variable labels only (no data). Writes docs/production_inventory.csv.
## Usage: Rscript checks/production_inventory.R [folder with one subfolder per survey]
suppressPackageStartupMessages({ library(haven); library(dplyr); library(purrr) })
a <- commandArgs(TRUE); ROOT <- if (length(a)) a[1] else Sys.getenv("ASF_UNZIPPED", "data/_unzipped")
TOPICS <- list(
  livestock_holdings = "how many .*(own|keep)|number of .*owned|currently (own|keep)|livestock code|lvstck|animal code|type of animal",
  milk_production    = "milk(ed)?.*(produc|litre|liter|quantity|sold|milking)|(produc|sold).*milk",
  egg_production     = "egg.*(produc|laid|clutch|sold)|(produc|sold).*egg",
  meat_slaughter     = "slaught|carcass|meat.*(produc|sold)",
  animal_sales       = "sold alive|sell.*(livestock|animal)|livestock.*sold|value of .*sold",
  coffee             = "coffee",
  trees_permanent    = "tree|permanent crop|perennial|stand",
  crop_harvest_sales = "harvest|quantity sold|value of .*crop")
dirs <- list.dirs(ROOT, recursive = FALSE)
res <- map_dfr(dirs, function(d) {
  survey <- basename(d)
  map_dfr(list.files(d, "[.]dta$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE), function(f) {
    x <- tryCatch(read_dta(f, n_max = 0), error = function(e) NULL); if (is.null(x)) return(NULL)
    labs <- vapply(x, function(v) { l <- attr(v, "label"); if (is.null(l)) "" else paste(as.character(l), collapse = " ") }, "")
    vls  <- vapply(x, function(v) { l <- names(attr(v, "labels")); if (is.null(l)) "" else paste(l, collapse = " ") }, "")
    map_dfr(names(TOPICS), function(t) {
      hit <- grepl(TOPICS[[t]], labs, ignore.case = TRUE) |
             (t == "coffee" & grepl("coffee", vls, ignore.case = TRUE))
      if (!any(hit)) return(NULL)
      tibble(survey, file = basename(f), topic = t, n_vars = sum(hit),
             examples = paste(head(paste0(names(x)[hit], ": ", substr(labs[hit], 1, 70)), 3), collapse = " | "))
    })
  })
})
dir.create("docs", showWarnings = FALSE)
write.csv(res, "docs/production_inventory.csv", row.names = FALSE)
s <- res %>% group_by(survey, topic) %>% summarise(files = n(), vars = sum(n_vars), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = topic, values_from = vars, values_fill = 0)
print(as.data.frame(s), row.names = FALSE)
