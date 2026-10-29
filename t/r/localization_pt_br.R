# Run from the repository root: Rscript t/r/localization_pt_br.R
# No database, network access or application server is required.
# Pin the pre-translation baseline so these checks also work after committing.
original_revision <- "cbc5b92be8be38939a55998c199e5e379de5ac04"

read_original <- function(file) {
  sub("\r$", "", system2("git", c("show", paste0(original_revision, ":", file)), stdout = TRUE))
}

walk_calls <- function(x, names) {
  result <- list()
  visit <- function(x) {
    if (missing(x)) return(invisible(NULL))
    if (is.call(x)) {
      name <- paste(deparse(x[[1]]), collapse = "")
      if (name %in% names) result[[length(result) + 1L]] <<- x
      # Presentation helpers are tested independently below.
      if (identical(x[[1]], as.name("<-")) && is.symbol(x[[2]]) &&
          grepl("^(localize_|render_anova_table$|banana_)", as.character(x[[2]]))) {
        return(invisible(NULL))
      }
    }
    if (is.call(x) || is.expression(x)) for (item in as.list(x)) visit(item)
  }
  visit(x)
  result
}

load_definitions <- function(file) {
  env <- new.env(parent = globalenv())
  for (x in parse(file)) {
    if (is.call(x) && identical(x[[1]], as.name("<-")) && is.symbol(x[[2]]) &&
        (grepl("^(localize_|render_anova_table$|banana_)", as.character(x[[2]])) ||
         (is.call(x[[3]]) && identical(x[[3]][[1]], as.name("function"))))) eval(x, env)
  }
  env
}

files <- list.files("R", pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
legacy_errors <- c("R/BLUP_modelling.r", "R/banana_pipeline/banana_pipeline_analysisScript.R",
                   "R/solGS/banana_pipeline/banana_pipeline_analysisScript.R")
statistical_calls <- c("lmer", "lm", "prcomp", "kmeans", "stats::kmeans", "mixed.solve",
                       "kin.blup", "SpATS", "ammi", "gge", "getAdjMeans", "runAnova",
                       "filterGenoData", "genoDataFilter::filterGenoData", "scanone", "scantwo")
for (file in files) {
  original <- tryCatch(parse(text = read_original(file)), error = identity)
  current <- tryCatch(parse(file), error = identity)
  if (file %in% legacy_errors) {
    stopifnot(inherits(original, "error"), inherits(current, "error"),
              identical(readLines(file, warn = FALSE), read_original(file)))
  } else {
    stopifnot(!inherits(current, "error"), !inherits(original, "error"))
    stopifnot(identical(walk_calls(original, statistical_calls),
                        walk_calls(current, statistical_calls)))
  }
}
cat("PASS: all 50 scripts audited; statistical calls preserved; 3 unchanged legacy syntax errors.\n")

report_files <- c("R/solGS/anova.r", "R/solGS/pca.r", "R/solGS/combine_populations.r",
                  "R/solGS/rrblup_gblup_gs.r")
reports <- lapply(report_files, function(file) load_definitions(file)$localize_analysis_report)
for (translate in reports) {
  # Data names resembling English prose must survive interpolation verbatim.
  trait <- "The yield values for the trial are arithmetic averages"
  trial <- "Trial from trial São João <A&B>"
  input <- paste0("Running ANOVA for trait ", trait, " from trial ", trial, ".\n\n")
  result <- translate(input, protected = c(trait, trial))
  stopifnot(grepl(trait, result, fixed = TRUE), grepl(trial, result, fixed = TRUE),
            grepl("Executando a ANOVA", result, fixed = TRUE), endsWith(result, "\n\n"),
            identical(translate(result), result))
  untouched <- c("", "\n\n", NA_character_, "Unknown diagnostic: Trial A / 123.45\n\n")
  stopifnot(identical(translate(untouched), untouched), is.null(translate(NULL)),
            identical(translate(character()), character()))
}
cat("PASS: generated prose localized without changing names, unknown diagnostics or line breaks.\n")

shiny_files <- c("R/banana_pipeline/banana_shinyApp.R", "R/solGS/banana_pipeline/banana_shinyApp.R")
for (file in shiny_files) {
  original <- parse(text = read_original(file))
  current <- parse(file)
  before <- walk_calls(original, "selectInput")
  after <- walk_calls(current, "selectInput")
  stopifnot(length(before) == length(after))
  for (i in seq_along(before)) {
    stopifnot(identical(before[[i]][[2]], after[[i]][[2]]))
    if (before[[i]][[2]] %in% c("select_activity", "plantlets", "statusCont")) {
      stopifnot(identical(unname(eval(before[[i]]$choices)), unname(eval(after[[i]]$choices))))
    }
  }
  stopifnot(identical(walk_calls(original, "switch"), walk_calls(current, "switch")),
            identical(walk_calls(original, "write.csv"), walk_calls(current, "write.csv")))
  before_tabs <- walk_calls(original, "tabPanel")
  after_tabs <- walk_calls(current, "tabPanel")
  for (i in seq_along(before_tabs)) stopifnot(identical(before_tabs[[i]][[2]], after_tabs[[i]]$value))
  env <- load_definitions(file)
  data <- data.frame(activity = c("flowering", "custom stage", NA), accession = c("flowering", "A&B", "ç"),
                     date = as.Date(c("2026-01-01", "2026-01-02", NA)), N = c(5, 8, NA))
  saved <- data
  shown <- env$banana_display_data(data)
  stopifnot(identical(data, saved), identical(shown[[2]], data$accession),
            identical(shown[[3]], data$date), identical(shown[[4]], data$N),
            identical(shown[[1]], c("Florescimento", "custom stage", NA_character_)),
            identical(env$banana_activity_label(c("flowering", "custom stage")), c("Florescimento", "custom stage")))
  choices <- setNames(data$activity, env$banana_activity_label(data$activity))
  stopifnot(identical(unname(choices), data$activity))
  if (requireNamespace("shiny", quietly = TRUE) && requireNamespace("shinythemes", quietly = TRUE)) {
    ui_env <- new.env(parent = asNamespace("shiny"))
    ui_env$shinytheme <- shinythemes::shinytheme
    ui_env$cleantable <- data.frame(location = "Local A")
    for (x in current) {
      if (is.call(x) && identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name("ui"))) eval(x, ui_env)
    }
    html <- htmltools::renderTags(ui_env$ui)$html
    stopifnot(grepl("Repetição da polinização", html, fixed = TRUE),
              grepl('value="RepeatPollination"', html, fixed = TRUE))
  }
}
cat("PASS: both Shiny apps preserve filters, input values, tab IDs, CSV exports and original data.\n")

env <- load_definitions("R/augmented_row_column.R")
stopifnot(isTRUE(env$validate_inputs(paste0("T", 1:8), "C", 3, 3, 3, 3, 1)))
err <- tryCatch(env$validate_inputs(character(), character(), 3, 3, 3, 3, 1), error = conditionMessage)
stopifnot(identical(err, "É necessário informar pelo menos uma testemunha."))
cat("PASS: valid design input accepted and validation error localized.\n")

if (requireNamespace("phenoAnalysis", quietly = TRUE) && requireNamespace("genoDataFilter", quietly = TRUE)) {
  pheno <- data.frame(germplasmName = rep(c("Alpha", "Beta", "Gamma"), each = 2), locationName = "Location",
    studyYear = 2026, blockNumber = rep(1:2, 3), replicate = rep(1:2, 3), studyName = "Trial A",
    studyDesign = NA_character_, yield = c(1, 2, 3, 5, 6, 7))
  means <- suppressWarnings(phenoAnalysis::getAdjMeans(pheno, traitName = "yield", calcAverages = TRUE, logReturn = TRUE))
  genotype <- data.frame(M1 = c(0, 1, 2, 0), M2 = c(2, 1, 0, 2), M3 = c(0, NA, 1, 2), row.names = paste0("G", 1:4))
  filtered <- genoDataFilter::filterGenoData(genotype, maf = 0.01, logReturn = TRUE)
  for (translate in reports) {
    stopifnot(!any(grepl("^(Trial |The |No[ .])", translate(c(means$log, filtered$log)))))
    numbers <- function(x) regmatches(x, gregexpr("[0-9]+(?:\\.[0-9]+)?", x, perl = TRUE))
    stopifnot(identical(numbers(filtered$log), numbers(translate(filtered$log))))
  }
  stopifnot(identical(means$adjMeans$yield_Arithmetic_mean, c(1.5, 4, 6.5)),
            identical(filtered$data, genotype))
  cat("PASS: actual phenoAnalysis and genoDataFilter reports localized; numeric results preserved.\n")
} else cat("SKIP: phenoAnalysis/genoDataFilter are not installed in the active R libraries.\n")

if (requireNamespace("lmerTest", quietly = TRUE) && requireNamespace("stargazer", quietly = TRUE)) {
  set.seed(23)
  data <- expand.grid(genotype = letters[1:6], block = 1:4)
  data$yield <- rnorm(nrow(data)) + rep(1:6, 4)
  model <- lmerTest::lmer(yield ~ genotype + (1 | block), data = data)
  before <- stats::anova(model)
  env <- load_definitions("R/solGS/anova.r")
  for (type in c("html", "text")) {
    path <- tempfile()
    output <- env$render_anova_table(model, type, "Yield <A&B>", path)
    stopifnot(any(grepl("Resultados da ANOVA", output)), any(grepl("Soma de quadrados", output)),
              identical(stats::anova(model), before), file.info(path)$size > 0)
    unlink(path)
  }
  cat("PASS: ANOVA HTML/text presentation localized without changing the fitted model.\n")
}

if (requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("waves", quietly = TRUE)) {
  set.seed(42)
  data <- as.data.frame(matrix(rnorm(30 * 30), nrow = 30))
  names(data) <- paste0("X", seq(1000, 1290, by = 10))
  data <- cbind(id = seq_len(nrow(data)), data)
  plot <- waves::plot_spectra(data, num.col.before.spectra = 1, window.size = 5, verbose = FALSE)
  before <- ggplot2::ggplot_build(plot)$data
  for (file in c("R/Nirs/nirs_visualize_spectra.R", "R/Nirs/nirs_upload_filter_aggregate.R")) {
    env <- new.env()
    env$spec.plot <- plot
    for (x in parse(file)) {
      if (is.call(x) && identical(x[[1]], as.name("if")) && grepl("outlier_scale", paste(deparse(x), collapse = ""))) eval(x, env)
    }
    stopifnot(identical(before, ggplot2::ggplot_build(env$spec.plot)$data),
              identical(env$spec.plot$labels$x, "Comprimento de onda"))
  }
  cat("PASS: actual waves spectra retain all plotted values after caption/legend translation.\n")
}
