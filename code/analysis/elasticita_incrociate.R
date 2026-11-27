###############################################################################
##  SELECTED CROSS-PRICE ELASTICITIES: ANIMAL-SOURCE FOODS vs PLANT PROTEINS, 5 COUNTRIES
##  Paolo Medei - AGRISYSTEM, Universita' Cattolica. Added 27 November 2026.
##
##  WHAT IT DOES
##  Reads the results of LAAIDS_2stadi.R (one folder per country, main specification with regional fixed effects)
##  and builds cross-price elasticities between GROUPS of protein categories:
##    - how the demand for meat, fish, dairy, eggs and all animal-source foods (ASF) reacts when the price of
##      plant proteins rises by 1%;
##    - how the demand for plant proteins reacts when the prices of meat, fish, dairy, eggs or all ASF rise by 1%.
##  Nothing is re-estimated: the script only adds up the category elasticities that LAAIDS_2stadi.R already wrote.
##
##  HOW THE GROUPS ARE BUILT (the same rules as the aggregates of section 14 of LAAIDS_2stadi.R)
##    demand of a group G (e.g. meat) = categories of G weighted by their mean share of the food budget:
##        e(G <- p_j) = sum_{k in G} (w_k / w_G) * e_kj
##    price of a group H (e.g. all ASF) = all the prices of H rise together by 1%:
##        e(k <- p_H) = sum_{j in H} e_kj
##  e_kj = UNCONDITIONAL elasticity of category k with respect to the price of category j (Edgerton 1997: both
##  stages re-optimised, food budget fixed), averaged over households: sheets unc_hicks and unc_marshall.
##    Hicks (compensated): the income effect of the price change is taken out, so the sign says whether two goods
##      are substitutes (+) or complements (-) for the household.
##    Marshall (uncompensated): what one observes in the market, income effect included.
##  Standard errors: the same formulas applied to each of the 200 bootstrap replications (repliche_bootstrap.rds),
##  with the weights kept at their full-sample values.
##
##  USE: Rscript elasticita_incrociate.R <folder with analisi_<P>/> <date of the runs> <output.xlsx>
##  Results only (no household data): the output can be shared.
###############################################################################
suppressMessages({ library(readxl); library(openxlsx) })
arg <- commandArgs(trailingOnly = TRUE)
CART <- arg[1]; DATA <- arg[2]; OUT <- arg[3]
PAESI <- c(TZA = "Tanzania", ETH = "Ethiopia", MWI = "Malawi", NGA = "Nigeria", UGA = "Uganda")
GRUPPI <- list(meat = c("beef", "sheep_goat", "pork_other_meat", "poultry"), fish = "fish",
               dairy = c("fluid_milk", "other_dairy"), eggs = "eggs",
               ASF = c("beef", "sheep_goat", "pork_other_meat", "poultry", "fish", "fluid_milk", "other_dairy", "eggs"))
PIANTE <- "plant_protein"

righe <- list()
for (p in names(PAESI)) {
  dir <- file.path(CART, paste0("analisi_", p), paste0("risultati_LAAIDS_2stadi_", p, "_", DATA))
  xl  <- file.path(dir, paste0("risultati_LAAIDS_2stadi_", p, ".xlsx"))
  rep <- readRDS(file.path(dir, "repliche_bootstrap.rds"))
  w   <- read_excel(xl, "unc_expenditure"); w <- setNames(w$mean_share, w$category)     # shares of the food budget
  for (tipo in c("hicks", "marshall")) {
    E  <- as.data.frame(read_excel(xl, paste0("unc_", tipo))); rownames(E) <- E$category; E$category <- NULL
    Eb <- rep[[tipo]]$unc                                                                    # replications x rows x columns
    for (g in names(GRUPPI)) {
      k <- intersect(GRUPPI[[g]], rownames(E))                                               # Ethiopia: no pork
      # (1) demand of group g when the price of plant proteins rises by 1%
      pesi <- w[k] / sum(w[k])
      est  <- sum(pesi * E[k, PIANTE])
      boot <- apply(Eb[, k, PIANTE, drop = FALSE], 1, function(m) sum(pesi * m))
      righe[[length(righe) + 1]] <- data.frame(country = PAESI[[p]], code = p, measure = tipo, direction = "ASF demand <- plant protein price",
                                               demand = g, price = "plant_protein", estimate = est, se = sd(boot, na.rm = TRUE))
      # (2) demand of plant proteins when all the prices of group g rise by 1%
      est  <- sum(as.numeric(E[PIANTE, k]))
      boot <- apply(Eb[, PIANTE, k, drop = FALSE], 1, sum)
      righe[[length(righe) + 1]] <- data.frame(country = PAESI[[p]], code = p, measure = tipo, direction = "plant protein demand <- ASF price",
                                               demand = "plant_protein", price = g, estimate = est, se = sd(boot, na.rm = TRUE))
    }
  }
}
R <- do.call(rbind, righe)
R$t <- R$estimate / R$se
R$significant_5pct <- abs(R$t) > 1.96

note <- data.frame(notes = c(
  "Cross-price elasticities between groups of protein categories, two-stage LA/AIDS, main specification (regional fixed effects).",
  "Unconditional elasticities (Edgerton 1997: both stages re-optimised, food budget fixed), averaged over households.",
  "Demand of a group = its categories weighted by their mean share of the food budget; price of a group = all its prices rise together by 1%.",
  "hicks = compensated (income effect removed): + substitutes, - complements. marshall = uncompensated (as observed in the market).",
  "se: the same formulas on the 200 bootstrap replications (weights fixed at the full-sample values). significant_5pct: |estimate / se| > 1.96.",
  "Ethiopia: no pork in the questionnaire; fish is a Gambella result (73% of fish eaters), not a national one.",
  paste("Source runs:", DATA, "- script elasticita_incrociate.R")))
wb <- createWorkbook()
for (nm in c("leggimi", "hicks", "marshall")) addWorksheet(wb, nm)
writeData(wb, "leggimi", note)
writeData(wb, "hicks", R[R$measure == "hicks", ]); writeData(wb, "marshall", R[R$measure == "marshall", ])
setColWidths(wb, "leggimi", 1, 150); for (nm in c("hicks", "marshall")) setColWidths(wb, nm, 1:11, "auto")
saveWorkbook(wb, OUT, overwrite = TRUE)
cat("written", OUT, "\n")
print(within(R[R$measure == "hicks", c("code", "direction", "demand", "price", "estimate", "se")], { estimate <- round(estimate, 3); se <- round(se, 3) }), row.names = FALSE)
