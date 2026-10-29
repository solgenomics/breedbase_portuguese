#SNOPSIS
#calculates genomic estimated breeding values (GEBVs) using rrBLUP,
#GBLUP method

#AUTHOR
# Isaak Y Tecle (iyt2@cornell.edu)

options(echo = FALSE)

# Scripts are copied individually to cluster workers, so this presentation helper
# is kept self-contained. Apply it only to generated prose, never to tabular data.
localize_analysis_report <- function(text, protected = character()) {
  if (is.null(text) || length(text) == 0) return(text)
  protected <- unique(as.character(protected))
  protected <- protected[!is.na(protected) & nzchar(protected)]
  protected <- protected[order(nchar(protected), decreasing = TRUE)]
  prefix <- "BB_LOCALIZED_NAME_"
  while (any(grepl(prefix, c(text, protected), fixed = TRUE), na.rm = TRUE)) prefix <- paste0(prefix, "_")
  tokens <- paste0(prefix, seq_along(protected), "_END")
  rules <- list(
    c("^Running ANOVA for trait (.*) from trial (.*)\\.$", "Executando a ANOVA da característica \\1 no ensaio \\2."),
    c("^This trial has (.*) experimental design and ANOVA will be run accordingly to calculate the clone adjusted means\\.$", "Este ensaio usa o delineamento \\1. A ANOVA será realizada conforme esse delineamento para calcular as médias ajustadas dos clones."),
    c("^Genotypes are fitted as fixed effects where as the environmental factors are fitted as random effects\\.$", "Os genótipos são ajustados como efeitos fixos e os fatores ambientais como efeitos aleatórios."),
    c("^Genotypes are fitted as random effects where as the environmental factors are fitted as random effects\\.$", "Os genótipos e os fatores ambientais são ajustados como efeitos aleatórios."),
    c("^Trial (.*) does not have a proper experimental design\\. Therefore ANOVA was not run on the trial to calculate the trait adjusted means\\.$", "O ensaio \\1 não tem um delineamento experimental adequado. Por isso, a ANOVA não foi realizada para calcular as médias ajustadas da característica."),
    c("^The (.*) values for the trial are arithmetic averages\\.$", "Os valores de \\1 para o ensaio são médias aritméticas."),
    c("^Can't perform ANOVA on this trait\\. Because, the trial has no proper or supported experimental design for the trait\\.$", "Não é possível realizar a ANOVA desta característica. O ensaio não tem um delineamento experimental adequado ou compatível para a característica."),
    c("^No of markers before applying any filter: (.*)$", "Número de marcadores antes da aplicação dos filtros: \\1"),
    c("^No\\. of markers \\(columns\\) remaining after filtering out markers with (.*)% or more missing data:(.*)$", "Número de marcadores (colunas) restantes após a remoção dos marcadores com \\1% ou mais de dados ausentes: \\2"),
    c("^No\\. of individuals \\(rows\\) before applying any filter: (.*)$", "Número de indivíduos (linhas) antes da aplicação dos filtros: \\1"),
    c("^No\\. of individuals \\(rows\\) remaining after filtering out individuals with (.*)% or more missing data: (.*)$", "Número de indivíduos (linhas) restantes após a remoção dos indivíduos com \\1% ou mais de dados ausentes: \\2"),
    c("^No\\. of markers before applying monomorphic markers filter: (.*)$", "Número de marcadores antes da filtragem dos marcadores monomórficos: \\1"),
    c("^No\\. of markers remaining after filtering out monomorphic markers: (.*)$", "Número de marcadores restantes após a remoção dos marcadores monomórficos: \\1"),
    c("^No of markers before applying MAF filter: (.*)$", "Número de marcadores antes da aplicação do filtro de MAF: \\1"),
    c("^No\\. of markers remaining after filtering out markers with (.*)% or less minor allele frequency \\(MAF\\): (.*)$", "Número de marcadores restantes após a remoção dos marcadores com frequência do alelo menor (MAF) de \\1% ou menos: \\2")
  )
  vapply(text, function(value) {
    if (is.na(value)) return(NA_character_)
    for (i in seq_along(protected)) value <- gsub(protected[i], tokens[i], value, fixed = TRUE)
    lines <- strsplit(sub("\n*$", "", value), "\n", fixed = TRUE)[[1]]
    for (rule in rules) lines <- sub(rule[1], rule[2], lines)
    result <- paste(lines, collapse = "\n")
    # Preserve the report's trailing line breaks.
    trailing <- regmatches(value, regexpr("\n*$", value))
    result <- paste0(result, trailing)
    for (i in seq_along(protected)) result <- gsub(tokens[i], protected[i], result, fixed = TRUE)
    result
  }, character(1), USE.NAMES = FALSE)
}


# options(warn = -1)
suppressWarnings(suppressPackageStartupMessages({
    library(methods)
    library(rrBLUP)
    library(plyr)
    library(stringr)
    library(randomForest)
    library(parallel)
    library(genoDataFilter)
    library(phenoAnalysis)
    library(caret)
    library(dplyr)
    library(tibble)
    library(rlang)
    library(jsonlite)
    library(data.table)
}))

library(genoDataFilter)
library(Matrix)

all_args <- commandArgs()
input_files <- tryCatch({
    scan(grep("input_files", all_args, value = TRUE), what = "character")
}, error = function(e) {
    stop("Os arquivos de entrada não foram informados ou não existem.")
})

output_files <- tryCatch({
    scan(grep("output_files", all_args, value = TRUE), what = "character")
}, error = function(e) {
    stop("Os arquivos de saída não foram informados ou não existem.")
})

message("input_files: ", paste(input_files, collapse = ", "))
message("output_files: ", paste(output_files, collapse = ", "))
# output_files <- scan(grep("output_files", allArgs, value = TRUE),
#                     what = "character")

traits_file <- grep("traits", input_files,  value = TRUE)

model_info_file  <- grep("model_info", input_files, value = TRUE)
message("model_info_file: ", model_info_file)

model_info  <- read.table(
    model_info_file,
    header = TRUE,
    sep = "\t",
    as.is = c("Value")
)

model_info  <- column_to_rownames(model_info, var="Name")
trait_id    <- model_info["trait_id", 1]
trait_abbr  <- model_info["trait_abbr", 1]
model_id   <- model_info["model_id", 1]
protocol_id <- model_info["protocol_id", 1]
protocol_page <- model_info["protocol_url", 1]

message("trait_id: ", trait_id)
message("trait_abbr: ", trait_abbr)
message("protocol_id: ", protocol_id)
message("protocol detail page: ", protocol_page)

message("model_id: ", model_id)

dataset_info_file <- grep("dataset_info", input_files, value = TRUE)
dataset_info     <- c()

if (length(dataset_info_file) != 0) {
    dataset_info <- scan(dataset_info_file, what = "character")
    dataset_info <- paste(dataset_info, collapse = " ")
} else {
    dataset_info <- c("single_population")
}

#validationTrait <- paste("validation", trait, sep = "_")
validation_file  <- grep("validation", output_files, value = TRUE)

if (is.null(validation_file)) {
    stop("O arquivo de saída da validação não foi informado.")
}

#kinshipTrait <- paste("rrblup_training_gebvs", trait, sep = "_")
blup_file <- grep("rrblup_training_gebvs", output_files, value = TRUE)

if (length(blup_file) == 0) {
    stop("O arquivo de GEBVs não foi informado.")
}

#markerTrait <- paste("marker_effects", trait, sep = "_")
marker_file  <- grep("marker_effects", output_files, value = TRUE)

#traitPhenoFile <- paste("trait_phenotype_data", trait_id, sep = "_")
model_pheno_file <- grep("model_phenodata", output_files, value = TRUE)
message("model input trait pheno file: ", model_pheno_file)
model_geno_file <- grep("model_genodata", output_files, value = TRUE)
message("model input trait geno file: ", model_geno_file)

training_pop_genetic_values_file <- grep(
    "training_genetic_values",
    output_files,
    value = TRUE
)

combined_training_gebvs_genetic_values_file <- grep(
    "combined_training_gebvs_genetic_values",
    output_files,
    value = TRUE
)

selection_pop_genetic_values_file <- grep(
    "selection_genetic_values",
    output_files,
    value = TRUE
)

combined_selection_gebvs_genetic_values_file <- grep(
    "combined_selection_gebvs_genetic_values",
    output_files,
    value = TRUE
)

trait_raw_pheno_file <- grep(
    "trait_raw_phenodata",
    output_files, 
    value = TRUE
)

variance_components_file <- grep(
    "variance_components",
    output_files,
    value = TRUE
)
analysis_report_file <- grep("_report_",
                             output_files,
                             value = TRUE)
geno_filtering_log_file <- grep("genotype_filtering_log",
                                output_files,
                                value = TRUE)

filtered_training_geno_file <- grep("filtered_training_genotype_data",
                                    output_files,
                                    value = TRUE)

filtered_sel_geno_file <- grep("filtered_selection_genotype_data",
                               output_files,
                               value = TRUE)

formatted_pheno_file <- grep("formatted_phenotype_data",
                             input_files,
                             value = TRUE)

geno_file <- grep("genotype_data_",
                  input_files,
                  value = TRUE)

if (is.null(geno_file)) {
    stop("O arquivo de dados genotípicos não foi informado.")
}

if (file.info(geno_file)$size == 0) {
    stop(paste0("O arquivo de dados genotípicos ", geno_file, " está vazio."))
}

read_filtered_training_geno_data <- c()
filtered_training_geno_data <- c()
geno_filter_log <- c()
formatted_pheno_data <- c()

pheno_data <- c()
geno_data  <- c()

maf <- 0.01
marker_filter_threshold <- 0.6
pheno_filter_threshold <- 0.8

log_heading <- paste0("Relatório da análise de predição genômica para ",
    trait_abbr,
    ".\n"
)

message("log heading: ", log_heading)
log_heading <- append(log_heading,
    paste0("Data: ",
           format(Sys.time(), "%d %b %Y %H:%M"),
           "\n\n\n")
)
message("log heading: ", log_heading)

log_heading <- format(log_heading, width = 80, justify = "c")

training_log <- paste0(
    "\n\n#Pré-processamento dos dados genotípicos da população de treinamento.\n\n"
)
training_log <- append(
    training_log,
    "Os seguintes filtros serão aplicados ao conjunto de dados genotípicos:\n\n"
)
training_log <- append(
    training_log,
    paste0("Marcadores com frequência do alelo menor (MAF) menor ou igual a ",
        maf * 100,
        "% serão removidos.\n"
    )
)

training_log <- append(
    training_log,
    paste0("\nMarcadores com proporção de valores ausentes maior ou igual a ",
        marker_filter_threshold * 100,
        "% serão removidos.\n"
    )
)
training_log <- append(
    training_log,
    paste0("Clones com proporção de valores ausentes maior ou igual a ",
        pheno_filter_threshold * 100,
        "% serão removidos.\n"
    )
)

if (length(filtered_training_geno_file) != 0 &&
        file.info(filtered_training_geno_file)$size != 0) {
    filtered_training_geno_data <- fread(filtered_training_geno_file,
                                         na.strings = c("NA", "", "--", "-"),
                                         header = TRUE)

    geno_data <-  data.frame(filtered_training_geno_data)
    geno_data <- column_to_rownames(geno_data, "V1")
    read_filtered_training_geno_data <- 1
}

if (is.null(filtered_training_geno_data)) {
    geno_data <- fread(geno_file,
                       na.strings = c("NA", "", "--", "-"),
                       header = TRUE)


    geno_data <- unique(geno_data, by = "V1")
    geno_data <- data.frame(geno_data)

    geno_data <- column_to_rownames(geno_data, "V1")
    #genoDataFilter::filterGenoData
    geno_data <- genoDataFilter::convertToNumeric(geno_data)

    training_log <- append(training_log,
        paste0(
            "#Limpeza dos dados genotípicos",
            " da população de treinamento.\n\n"
        )
    )

    message("training_log: ", training_log)

    geno_filter_output <- genoDataFilter::filterGenoData(
        geno_data,
        maf = maf,
        markerFilter = marker_filter_threshold,
        indFilter = pheno_filter_threshold,
        logReturn = TRUE
    )
    
    geno_data <- geno_filter_output$data
    geno_filtering_log <- geno_filter_output$log
    geno_data <- roundAlleleDosage(geno_data)
    filtered_training_geno_data   <- geno_data

} else {
    geno_filtering_log <- scan(geno_filtering_log_file,
        what = "character", sep = "\n"
    )

    geno_filtering_log <- paste0(geno_filtering_log, collapse = "\n")
}

message("geno filtering logfile: ", geno_filtering_log_file)
message("geno filtering log: ", geno_filtering_log)

geno_filtering_log <- localize_analysis_report(geno_filtering_log)
training_log <- append(training_log, geno_filtering_log)

geno_data <- geno_data[order(row.names(geno_data)), ]

if (length(formatted_pheno_file) != 0 && 
        file.info(formatted_pheno_file)$size != 0) {
    formatted_pheno_data <- data.frame(
        fread(formatted_pheno_file,
            header = TRUE,
            na.strings = c("NA", "", "--", "-", ".")
        )
    )
} else {
    if (dataset_info == "combined_populations") {
        pheno_file <- grep("model_phenodata",
            input_files,
            value = TRUE
        )
    } else {
        pheno_file <- grep("\\/phenotype_data",
            input_files,
            value = TRUE
        )
    }

    if (is.null(pheno_file)) {
        stop("O arquivo de dados fenotípicos não foi informado.")
    }

    if (file.info(pheno_file)$size == 0) {
        stop(paste0("O arquivo de dados fenotípicos ", pheno_file, " está vazio."))

    }

    pheno_data <- data.frame(fread(pheno_file,
                                   sep = "\t",
                                   na.strings = c("NA", "", "--", "-", "."),
                                   header = TRUE))
}

pheno_trait_data <- c()
trait_raw_pheno_data <- c()
anova_log <- paste0("#Pré-processamento dos dados fenotípicos da população de treinamento.\n\n")

if (dataset_info == "combined_populations") {
    anova_log <- scan(analysis_report_file, what = "character", sep = "\n")
    anova_log <- paste0(anova_log, collapse = "\n")

    if (!is.null(formatted_pheno_data)) {
        pheno_trait_data <- subset(formatted_pheno_data, select = trait_abbr)
        pheno_trait_data <- na.omit(pheno_trait_data)
    } else {
        if (any(grepl("Average", names(pheno_data)))) {
            pheno_trait_data <- pheno_data %>%
                select(V1, Average) %>%
                data.frame
        } else {
            pheno_trait_data <- pheno_data
        }

        colnames(pheno_trait_data)  <- c("genotypes", trait_abbr)
    }
} else {
    if (!is.null(formatted_pheno_data)) {
        pheno_trait_data <- subset(formatted_pheno_data, 
                                   select = c("V1", trait_abbr))

        pheno_trait_data <- as.data.frame(pheno_trait_data)
        pheno_trait_data <- na.omit(pheno_trait_data)
        colnames(pheno_trait_data)[1] <- "genotypes"

    } else if (length(grep("list", pheno_file)) != 0) {
        pheno_trait_data <- phenoAnalysis::averageTrait(pheno_data, trait_abbr)
    } else {
        pheno_adjusted_means_result <- phenoAnalysis::getAdjMeans(
            pheno_data,
            traitName = trait_abbr,
            calcAverages = TRUE,
            logReturn = TRUE
        )


        anova_log <- paste0(anova_log, localize_analysis_report(pheno_adjusted_means_result$log, c(trait_abbr, pheno_data$studyName)))
        pheno_trait_data <- pheno_adjusted_means_result$adjMeans
    }

    meta_cols_kept <- c("observationUnitName", "germplasmName",
                        "studyDbId", "locationName",
                        "studyYear", "replicate",
                        "blockNumber", trait_abbr)

    trait_raw_pheno_data <- pheno_data %>%
        select(all_of(meta_cols_kept))

}

mean_type <- names(pheno_trait_data)[2]
names(pheno_trait_data)  <- c("genotypes", trait_abbr)

selection_pop_temp_file <- grep("selection_population",
                                input_files, value = TRUE)

selection_pop_geno_file       <- c()
filtered_selection_geno_file <- c()
selection_all_files   <- c()

if (length(selection_pop_temp_file) != 0) {
    selection_all_files <- scan(selection_pop_temp_file,
                                what = "character")

    selection_pop_geno_file <- grep("\\/genotype_data",
                                    selection_all_files,
                                    value = TRUE)

  #filtered_selection_geno_file   <- grep("filtered_genotype_data_",  selection_all_files, value = TRUE)
}

selection_pop_gebvs_file <- grep("rrblup_selection_gebvs",
                                 output_files, value = TRUE)

selection_pop_data <- c()
# read_filtered_pred_geno_data <- c()
# filtered_pred_geno_data     <- c()

## if (length(filtered_selection_geno_file) != 0 && file.info(filtered_selection_geno_file)$size != 0) {
##   selection_pop_data <- fread(filtered_selection_geno_file, na.strings = c("NA", " ", "--", "-"),)
##   read_filtered_pred_geno_data <- 1

##   selection_pop_data           <- data.frame(selection_pop_data)
##   rownames(selection_pop_data) <- selection_pop_data[, 1]
##   selection_pop_data[, 1]      <- NULL

## } else
selection_prediction_log <- c()
if (length(selection_pop_geno_file) != 0) {
    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("#Pré-processamento dos dados genotípicos da população de seleção.\n\n")
    )

    selection_pop_data <- fread(selection_pop_geno_file,
                                header = TRUE,
                                na.strings = c("NA", "", "--", "-"))

    selection_pop_data <- data.frame(selection_pop_data)
    message("clones count selection_pop_data before removing duplicates:\n",
            length(rownames(selection_pop_data)))
    selection_pop_data <- selection_pop_data[!duplicated(selection_pop_data$V1), ]
    message("clones count selection_pop_data  after removing duplicates:\n",
            length(rownames(selection_pop_data)))
    selection_pop_data <- selection_pop_data[!is.na(selection_pop_data$V1), ]
    message("clones count selection_pop_data  after removing NA:\n",
            length(rownames(selection_pop_data)))

    selection_pop_data <- column_to_rownames(selection_pop_data, "V1")

    
    selection_pop_data <- genoDataFilter::convertToNumeric(selection_pop_data)

    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("Realizando a limpeza dos dados genotípicos da população de seleção.")
    )

    selection_pop_filtered_data <- filterGenoData(selection_pop_data,
        maf = maf,
        markerFilter = marker_filter_threshold,
        indFilter = pheno_filter_threshold,
        logReturn = TRUE
    )

    selection_pop_data <- selection_pop_filtered_data$data
    selection_prediction_log <- append(selection_prediction_log,
                                       localize_analysis_report(selection_pop_filtered_data$log))

    selection_pop_data <- roundAlleleDosage(selection_pop_data)
}

#impute genotype values for obs with missing values,
geno_data_missing <- c()

if (sum(is.na(geno_data)) > 0) {
    geno_data_missing <- c("yes")
    geno_data <- na.roughfix(geno_data)
    geno_data <- data.frame(geno_data)
}

#create phenotype and genotype datasets with
#common stocks only

#extract observation lines with both
#phenotype and genotype data only.
training_log <- append(
    training_log,
    paste0("\n\n#Filtragem dos genótipos da população de treinamento",
        " com dados fenotípicos e de marcadores.\n\n"
    )
)

training_log <- append(
    training_log,
    paste0("Após o cálculo das médias da característica,",
        " o conjunto de dados fenotípicos da população de treinamento contém ",
        length(rownames(pheno_trait_data)),
        " indivíduos.\n"
    )
)

training_log <- append(
    training_log,
    paste0("Após a limpeza dos valores ausentes,",
        " o conjunto de dados genotípicos da população de treinamento contém ",
        length(rownames(geno_data)),
        " indivíduos.\n"
    )
)

common_genotypes <- intersect(pheno_trait_data$genotypes, row.names(geno_data))

training_log <- append(
    training_log,
    paste0(length(common_genotypes),
        " indivíduos estão presentes tanto no conjunto de dados fenotípicos",
        " quanto no de dados genotípicos.\n"
    )
)

#remove genotyped lines without phenotype data
geno_data_filtered_genotypes <- geno_data[(rownames(geno_data) %in%
                                               common_genotypes), ]

training_log <- append(
    training_log,
    paste0("Após a remoção dos indivíduos sem dados fenotípicos,",
        " este conjunto de dados genotípicos contém ",
        length(rownames(geno_data_filtered_genotypes)),
        " indivíduos.\n"
    )
)

#remove phenotyped lines without genotype data
pheno_trait_data <- pheno_trait_data[(pheno_trait_data$genotypes %in%
                                          common_genotypes), ]

training_log <- append(
    training_log,
    paste0("Após a remoção dos indivíduos sem dados genotípicos,",
        " este conjunto de dados fenotípicos contém ",
        length(rownames(pheno_trait_data)),
        " indivíduos.\n"
    )
)

pheno_trait_for_mixed_solve           <- data.frame(pheno_trait_data)
rownames(pheno_trait_for_mixed_solve) <- pheno_trait_for_mixed_solve[, 1]
pheno_trait_for_mixed_solve[, 1]      <- NULL

#impute missing data in prediction data

selection_data_missing <- c()
if (length(selection_pop_data) != 0) {
    #purge markers unique to both populations
    training_pop_markers <- names(geno_data_filtered_genotypes)
    selection_pop_markers <-  names(selection_pop_data)

    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("#Comparação dos marcadores nos conjuntos de dados genotípicos das populações",
            " de treinamento e de seleção.\n\n"
        )
    )

    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("O conjunto de dados genotípicos da população de treinamento contém ",
            length(training_pop_markers),
            " marcadores.\n"
        )
    )

    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("O conjunto de dados genotípicos da população de seleção contém ",
            length(selection_pop_markers),
            " marcadores.\n"
        )
    )

    common_markers  <- intersect(training_pop_markers, selection_pop_markers)
    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("Os conjuntos de dados genotípicos das populações de treinamento e de seleção têm ",
            length(training_pop_markers),
            " marcadores em comum.\n"
        )
    )

    geno_data_filtered_genotypes <- subset(geno_data_filtered_genotypes,
                                           select = common_markers)

    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("Após a filtragem dos marcadores compartilhados,",
            " o conjunto de dados genotípicos da população de treinamento contém ",
            length(names(selection_pop_data)), " marcadores.\n"
        )
    )

    selection_pop_data <- subset(selection_pop_data, select = common_markers)
    selection_prediction_log <- append(
        selection_prediction_log,
        paste0("Após a filtragem dos marcadores compartilhados,",
            " o conjunto de dados genotípicos da população de seleção contém ",
            length(names(selection_pop_data)),
            " marcadores.\n"
        )
    )

    if (sum(is.na(selection_pop_data)) > 0) {
        selection_data_missing <- c("yes")
        selection_pop_data <- na.roughfix(selection_pop_data)
        selection_pop_data <- data.frame(selection_pop_data)
    }
}
#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genotype_encoding <- grep("2", geno_data_filtered_genotypes[1, ], value = TRUE)
if (length(genotype_encoding)) {
    geno_data <- geno_data - 1
    geno_data_filtered_genotypes <- geno_data_filtered_genotypes - 1
}

if (length(selection_pop_data) != 0) {
    genotype_encoding <- grep("2", selection_pop_data[1, ], value = TRUE)
    if (length(genotype_encoding) != 0) {
        selection_pop_data <- selection_pop_data - 1
    }
}

ordered_marker_effects <- c()
training_pop_gebvs          <- c()
all_validations          <- c()
combined_gebvs_file      <- c()
all_gebvs               <- c()
model_pheno_data       <- c()
kinship_matrix         <- c()
training_pop_genetic_values <- c()
selection_pop_genetic_values <- c()
combined_training_gebvs_genetic_values <- c()
combined_selection_gebvs_genetic_values <- c()
trait_genetic_values_header <- paste0(trait_abbr, "_genetic_values")
#additive relationship model
#calculate the inner products for
#genotypes (realized relationship matrix)
kinship_matrix_file <- grep(
    "relationship_matrix_table",
    output_files,
    value = TRUE
)

kinship_matrix_json_file <- grep(
    "relationship_matrix_json",
    output_files,
    value = TRUE
)

trait_kinship_matrix_file <- grep(
    "relationship_matrix_adjusted_table",
    output_files,
    value = TRUE
)

trait_kinship_matrix_json_file <- grep(
    "relationship_matrix_adjusted_json",
    output_files,
    value = TRUE
)

inbreeding_file <- grep(
    "inbreeding_coefficients",
    output_files,
    value = TRUE
)

average_kinship_file <- grep(
    "average_kinship",
    output_files,
    value = TRUE
)

inbreeding <- c()
average_kinship <- c()

if (length(kinship_matrix_file) != 0) {
    if (file.info(kinship_matrix_file)$size > 0) {
        kinship_matrix <- data.frame(
            fread(
                  kinship_matrix_file,
                  header = TRUE)
        )

        rownames(kinship_matrix) <- kinship_matrix[, 1]
        kinship_matrix[, 1]      <- NULL
        colnames(kinship_matrix) <- rownames(kinship_matrix)
        kinship_matrix           <- data.matrix(kinship_matrix)

    } else {
        kinship_matrix <- A.mat(geno_data)
        diag(kinship_matrix) <- diag(kinship_matrix) %>%
            replace(., . < 1, 1)
        kinship_matrix <- kinship_matrix %>%
            replace(., . <= 0, 0.00001)

        inbreeding <- diag(kinship_matrix)
        inbreeding <- inbreeding - 1
        inbreeding <- data.frame(inbreeding)

        inbreeding <- inbreeding %>%
            rownames_to_column("genotypes") %>%
            rename(Inbreeding = inbreeding) %>%
            arrange(Inbreeding) %>%
            mutate_at("Inbreeding", round, 3) %>%
            column_to_rownames("genotypes")
    }
}

kinship_matrix <- data.frame(kinship_matrix)
colnames(kinship_matrix) <- rownames(kinship_matrix)

kinship_matrix <- rownames_to_column(kinship_matrix, var = "genotypes")
kinship_matrix <- kinship_matrix %>% mutate_if(is.numeric, round, 5)
kinship_matrix <- column_to_rownames(kinship_matrix, var = "genotypes")

trait_kinship_matrix <- kinship_matrix[(rownames(kinship_matrix) %in%
                                            common_genotypes), ]

trait_kinship_matrix <- trait_kinship_matrix[,
                                            (colnames(trait_kinship_matrix) %in%
                                                common_genotypes)]

kinship_log <- c()
if (any(eigen(trait_kinship_matrix)$values < 0)) {
    kinship_log <- paste0(
        "\n\nObservação: a matriz de parentesco deste conjunto de dados causa",
        " \"Not positive semi-definite error\"",
        " durante a decomposição de Cholesky.",
        " Para corrigir isso e realizar a modelagem, foi calculada uma matriz",
        " semidefinida positiva corrigida",
        " usando a função \"Matrix::nearPD\". Os autovalores negativos",
        " dessa decomposição foram ajustados para valores positivos.\n\n"
    )

    trait_kinship_matrix <- Matrix::nearPD(as.matrix(trait_kinship_matrix))$mat
}

trait_kinship_matrix <- data.matrix(trait_kinship_matrix)

cores_count <- detectCores()

if (cores_count > 1) {
    cores_count <- (cores_count %/% 2)
} else {
    cores_count <- 1
}

variance_components <- c()

modeling_log <- paste0("\n\n#Treinamento de um modelo para ", trait_abbr, ".\n\n")
modeling_log <- append(
    modeling_log,
    paste0("A modelagem de predição genômica segue uma abordagem em duas etapas.",
        " Primeiro, os valores médios da característica, conforme descrito acima,",
        " são calculados para cada genótipo.",
        " Em seguida, o modelo é ajustado com base",
        " em um único valor fenotípico",
        " para cada genótipo e na matriz de parentesco ",
        " calculada a partir dos dados de marcadores.\n"
    )
)

if (length(kinship_log)) {
    modeling_log <- append(modeling_log, paste0(kinship_log))
}

if (length(selection_pop_data) == 0) {

    training_model_result  <- kin.blup(
        data   = pheno_trait_data,
        geno   = "genotypes",
        pheno  = trait_abbr,
        K      = trait_kinship_matrix,
        n.core = cores_count,
        PEV    = TRUE
    )

    modeling_log <- paste0(modeling_log, 
        "\nO treinamento do modelo usa o pacote R rrBLUP, versão ",
        packageVersion("rrBLUP"),
        ". Os GEBVs são preditos usando a função kin.blup",
        " e o método GBLUP.\n\n"
    )

    training_pop_genetic_values <- data.frame(
        round(training_model_result$pred, 2)
    )
    
    colnames(training_pop_genetic_values) <- trait_genetic_values_header
    training_pop_genetic_values <- training_pop_genetic_values %>%
        arrange(across(trait_genetic_values_header, desc))
    
    training_pop_genetic_values <- rownames_to_column(
        training_pop_genetic_values,
        var = "genotypes"
    )

    training_pop_gebvs <- training_model_result$g
    training_gebv_pev <- training_model_result$PEV
    training_gebv_stderr  <- sqrt(training_gebv_pev)
    training_gebv_stderr  <- data.frame(round(training_gebv_stderr, 2))

    training_pop_gebvs <- data.frame(round(training_pop_gebvs, 2))

    colnames(training_gebv_stderr) <- c("SE")
    colnames(training_pop_gebvs) <- trait_abbr

    training_gebv_stderr <- rownames_to_column(training_gebv_stderr,
                                               var = "genotypes")

    training_pop_gebvs   <- rownames_to_column(training_pop_gebvs, var = "genotypes")

    training_gebv_stderr <- full_join(training_pop_gebvs, training_gebv_stderr)



    training_gebv_stderr <-  training_gebv_stderr %>%
        arrange(across(trait_abbr, desc))

    training_gebv_stderr <- column_to_rownames(training_gebv_stderr,
                                               var = "genotypes")

    training_pop_gebvs <- training_pop_gebvs %>% arrange(across(trait_abbr, desc))

    if (!is.null(training_pop_genetic_values) &&
    !is.null(training_pop_gebvs)) {
        combined_training_gebvs_genetic_values <- inner_join(
            training_pop_gebvs,
            training_pop_genetic_values,
            by = 'genotypes'
        )
    }

    combined_training_gebvs_genetic_values <- column_to_rownames(
        combined_training_gebvs_genetic_values,
        var = "genotypes"
    )

    training_pop_genetic_values <- column_to_rownames(
        training_pop_genetic_values,
        var = "genotypes"
    )

    training_pop_gebvs <- column_to_rownames(
        training_pop_gebvs,
        var = "genotypes"
    )

    pheno_trait_for_mixed_solve <- data.matrix(pheno_trait_for_mixed_solve)
    geno_data_filtered_genotypes <- data.matrix(geno_data_filtered_genotypes)

    mixed_solve_output <- mixed.solve(
        y = pheno_trait_for_mixed_solve,
        Z = geno_data_filtered_genotypes
    )

    ordered_marker_effects <- data.matrix(mixed_solve_output$u)
    ordered_marker_effects <- data.matrix(
        ordered_marker_effects [order(-ordered_marker_effects[, 1]), ]
    )
    ordered_marker_effects <- round(ordered_marker_effects, 5)

    colnames(ordered_marker_effects) <- c("Marker Effects")
    ordered_marker_effects <- data.frame(ordered_marker_effects)

    model_pheno_data <- data.frame(round(pheno_trait_for_mixed_solve, 2))

    heritability <- round((
                           training_model_result$Vg / (training_model_result$Ve +
                           training_model_result$Vg)), 2)

    additive_variance <- round(training_model_result$Vg, 2)
    error_variance <- round(training_model_result$Ve, 2)

    variance_components <- c("\nVariância genética aditiva\t",
                             additive_variance, "\n")
    variance_components <- append(variance_components,
        c("Variância residual\t",
          error_variance, "\n")
    )

    variance_components <- append(variance_components,
        c("Herdabilidade baseada em SNPs (h)\t",
          heritability, "\n"))

    combined_gebvs_file <- grep(
        "selected_traits_gebv",
        output_files,
        ignore.case = TRUE,
        value = TRUE
    )

    if (length(combined_gebvs_file) != 0) {
        file_size <- file.info(combined_gebvs_file)$size
        if (file_size != 0) {
            combined_gebvs <- data.frame(fread(combined_gebvs_file,
                                                header = TRUE))

            rownames(combined_gebvs) <- combined_gebvs[, 1]
            combined_gebvs[, 1]       <- NULL

            all_gebvs <- merge(combined_gebvs, training_pop_gebvs,
                by = 0,
                all = TRUE
            )

            rownames(all_gebvs) <- all_gebvs[, 1]
            all_gebvs[, 1] <- NULL
        }
    }

    #cross-validation

    if (is.null(selection_pop_geno_file)) {
        genotypes_count <- nrow(pheno_trait_data)

        if (genotypes_count < 20 ) {
            warning(genotypes_count, " é um número muito pequeno de genótipos.")
        }

        set.seed(4567)

        k <- 10
        reps <- 2
        cross_val_folds <- createMultiFolds(pheno_trait_data[, 2],
                                            k = k, times = reps)

        modeling_log <- paste0(
            modeling_log,
            "A acurácia preditiva do modelo é avaliada usando",
            " o método de validação cruzada. São usados ",
            k,
            " grupos, com ",
            reps,
            " repetições, para estimar a acurácia do modelo.\n\n"
        )

        for (rep in 1:reps) {
            rep_name <- paste0("Rep", rep)

            for (i in 1:k) {
                validation_group_name <- ifelse(i < 10, "Fold0", "Fold")

                validation_training_rep_name <- paste0(validation_group_name,
                                                       i, ".", rep_name)

                validation_training_clones <- cross_val_folds[[validation_training_rep_name]]
                validation_selection_clones <- as.numeric(
                    rownames(
                        pheno_trait_data[-validation_training_clones, ]
                    )
                )

                kblup <- paste("rKblup", i, sep = ".")

                validation_prediction_result <- kin.blup(
                    data  = pheno_trait_data[validation_training_clones, ],
                    geno  = "genotypes",
                    pheno = trait_abbr,
                    K     = trait_kinship_matrix,
                    n.core = cores_count,
                    PEV    = TRUE
                )

                assign(kblup, validation_prediction_result)

                #calculate cross-validation accuracy
                validation_group_gebvs   <- validation_prediction_result$g
                validation_group_gebvs   <- data.frame(validation_group_gebvs)

                validation_selection_clones <- validation_selection_clones[
                    which(validation_selection_clones <= nrow(pheno_trait_data))
                ]

                validation_selection_geno_data <- pheno_trait_data[(
                                                    rownames(pheno_trait_data) %in%
                                                    validation_selection_clones), ]

                rownames(validation_selection_geno_data) <- validation_selection_geno_data[, 1]
                validation_selection_geno_data[, 1] <- NULL

                validation_group_gebvs <-  rownames_to_column(validation_group_gebvs,
                                                              var = "genotypes")

                validation_selection_geno_data <- rownames_to_column(
                                                    validation_selection_geno_data, 
                                                    var = "genotypes"
                )

                validation_corr_data <- inner_join(
                    validation_selection_geno_data,
                    validation_group_gebvs,
                    by = "genotypes"
                )

                validation_corr_data$genotypes <- NULL

                accuracy   <- try(cor(validation_corr_data))
                validation <- paste("validation",
                    validation_training_rep_name,
                    sep = "."
                )

                cross_validation_name <- paste("CV",
                    validation_training_rep_name, sep = " "
                )

                if (inherits(accuracy, "try-error") == FALSE) {
                    accuracy <- round(accuracy[1, 2], digits = 3)
                    accuracy <- data.matrix(accuracy)

                    colnames(accuracy) <- c("correlation")
                    rownames(accuracy) <- cross_validation_name

                    assign(validation, accuracy)

                    if (!is.na(accuracy[1, 1])) {
                        all_validations <- rbind(all_validations, accuracy)
                    }
                }
            }
        }

        all_validations <- data.frame(
            all_validations[order(-all_validations[, 1]), ]
        )
        colnames(all_validations) <- c("Correlation")
    }
}

selection_prediction_result <- c()
selection_pop_gebvs  <- c()
selection_pop_gebvs_stderr <- c()
selection_pop_genetic_values  <- c()

#selection pop geno data after  cleaning up
#and removing unique markers to selection pop

filtered_sel_geno_data <- selection_pop_data
if (length(selection_pop_data) != 0) {
    combined_training_selection_geno_data <- rbind(geno_data_filtered_genotypes,
        selection_pop_data
    )
    kinship_combined_training_selection_pop <- A.mat(combined_training_selection_geno_data)

    selection_prediction_result <- kin.blup(
        data   = pheno_trait_data,
        geno   = "genotypes",
        pheno  = trait_abbr,
        K      = kinship_combined_training_selection_pop,
        n.core = cores_count,
        PEV    = TRUE
    )

    selection_pop_genotypes <- rownames(selection_pop_data)

    selection_pop_genetic_values <- data.frame(
        round(selection_prediction_result$pred, 2)
    )

    colnames(selection_pop_genetic_values) <- trait_genetic_values_header
    selection_pop_genetic_values <- rownames_to_column(
        selection_pop_genetic_values,
        var = "genotypes"
    )

    selection_pop_genetic_values <-  selection_pop_genetic_values %>%
        filter(genotypes %in%
                   selection_pop_genotypes)

    selection_pop_genetic_values <- selection_pop_genetic_values %>%
        filter(genotypes %in%
                   selection_pop_genotypes)

    selection_pop_genetic_values <- selection_pop_genetic_values %>%
        arrange(across(all_of(trait_genetic_values_header), desc))

    selection_pop_gebvs <- round(data.frame(selection_prediction_result$g), 2)
    colnames(selection_pop_gebvs) <- trait_abbr
    selection_pop_gebvs <- rownames_to_column(
        selection_pop_gebvs,
        var = "genotypes"
    )

    selection_pop_gebvs <-  selection_pop_gebvs %>%
        filter(genotypes %in%
                   selection_pop_genotypes)

    # sortVar <- parse_expr(trait_abbr)
    
    selection_pop_pev <- selection_prediction_result$PEV
    selection_pop_stderr  <- sqrt(selection_pop_pev)
    selection_pop_stderr  <- data.frame(round(selection_pop_stderr, 2))
    colnames(selection_pop_stderr) <- "SE"
    selection_pop_stderr <- rownames_to_column(
        selection_pop_stderr,
        var = "genotypes"
    )
    selection_pop_stderr <-  selection_pop_stderr %>%
        filter(genotypes %in%
                   selection_pop_genotypes)

    selection_pop_gebvs_stderr <- inner_join(
        selection_pop_gebvs,
        selection_pop_stderr,
        by = "genotypes"
    )

    selection_pop_gebvs <- selection_pop_gebvs %>%
        arrange(across(all_of(trait_abbr), desc))

    
    if (!is.null(selection_pop_genetic_values) &&
        !is.null(selection_pop_gebvs)) {
        combined_selection_gebvs_genetic_values <- inner_join(selection_pop_gebvs,
        selection_pop_genetic_values, 
        by = 'genotypes')
    }

    combined_selection_gebvs_genetic_values <- column_to_rownames(
        combined_selection_gebvs_genetic_values,
        var = "genotypes"
    )

    selection_pop_genetic_values <- column_to_rownames(
        selection_pop_genetic_values,
        var = "genotypes"
    )
    
    selection_pop_gebvs <- column_to_rownames(
        selection_pop_gebvs,
        var = "genotypes"
    )

    selection_pop_gebvs_stderr <-  selection_pop_gebvs_stderr %>%
        arrange(across(all_of(trait_abbr), desc))

    selection_pop_gebvs_stderr <- column_to_rownames(
        selection_pop_gebvs_stderr,
        var = "genotypes"
    )
}


if (!is.null(selection_pop_gebvs) && 
length(selection_pop_gebvs_file) != 0)  {
    fwrite(
        selection_pop_gebvs,
        file  = selection_pop_gebvs_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (!is.null(training_pop_genetic_values) &&
        length(training_pop_genetic_values_file) != 0)  {
    fwrite(
        training_pop_genetic_values,
        file  = training_pop_genetic_values_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )   
}


if (!is.null(combined_training_gebvs_genetic_values ) && 
    length(combined_training_gebvs_genetic_values_file) != 0)  {
        
    fwrite(
        combined_training_gebvs_genetic_values,
        file  = combined_training_gebvs_genetic_values_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}


if (!is.null(selection_pop_genetic_values) &&
    length(selection_pop_genetic_values_file) != 0)  {
    fwrite(
        selection_pop_genetic_values,
        file  = selection_pop_genetic_values_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}


if (!is.null(combined_selection_gebvs_genetic_values) &&
    length(combined_selection_gebvs_genetic_values_file) != 0)  {
    fwrite(
        combined_selection_gebvs_genetic_values,
        file  = combined_selection_gebvs_genetic_values_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (!is.null(all_validations)) {
    fwrite(
        all_validations,
        file  = validation_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (!is.null(ordered_marker_effects)) {
    fwrite(
        ordered_marker_effects,
        file  = marker_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}


if (!is.null(training_pop_gebvs)) {
    fwrite(
        training_pop_gebvs,
        file  = blup_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (length(combined_gebvs_file) != 0 ) {
    if (file.info(combined_gebvs_file)$size == 0) {
        fwrite(
            training_pop_gebvs,
            file  = combined_gebvs_file,
            row.names = TRUE,
            sep   = "\t",
            quote = FALSE,
        )
    } else {
        fwrite(
            all_gebvs,
            file  = combined_gebvs_file,
            row.names = TRUE,
            sep   = "\t",
            quote = FALSE,
        )
    }
}

if (!is.null(model_pheno_data) &&
        length(model_pheno_file) != 0) {

    if (!is.null(mean_type)) {
        colnames(model_pheno_data) <- mean_type
    }

    fwrite(
        model_pheno_data,
        file  = model_pheno_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (!is.null(geno_data_filtered_genotypes) &&
        length(model_geno_file) != 0) {

    fwrite(
        geno_data_filtered_genotypes,
        file  = model_geno_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (!is.null(trait_raw_pheno_data) &&
        length(trait_raw_pheno_file) != 0) {

    fwrite(
        trait_raw_pheno_data,
        file  = trait_raw_pheno_file,
        row.names = FALSE,
        sep   = "\t",
        na = "NA",
        quote = FALSE,
    )
}

if (!is.null(filtered_training_geno_data) &&
        file.info(filtered_training_geno_file)$size == 0) {
    fwrite(
        filtered_training_geno_data,
        file  = filtered_training_geno_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )

    cat(geno_filtering_log,
        fill = TRUE,
        file = geno_filtering_log_file, 
        append = FALSE
    )
}

if (length(filtered_sel_geno_file) != 0 &&
        file.info(filtered_sel_geno_file)$size == 0) {
    fwrite(
        filtered_sel_geno_data,
        file  = filtered_sel_geno_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

## if (!is.null(geno_data_missing)) {
##   write.table(geno_data,
##               file = geno_file,
##               sep = "\t",
##               col.names = NA,
##               quote = FALSE,
##             )

## }

## if (!is.null(predictionDataMissing)) {
##   write.table(predictionData,
##               file = predictionFile,
##               sep = "\t",
##               col.names = NA,
##               quote = FALSE,
##               )
## }

if (file.info(kinship_matrix_file)$size == 0) {

    fwrite(kinship_matrix,
        file  = kinship_matrix_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (file.info(kinship_matrix_json_file)$size == 0) {

    kinship_matrix_json <- kinship_matrix
    kinship_matrix_json[upper.tri(kinship_matrix_json)] <- NA


    kinship_matrix_json <- data.frame(kinship_matrix_json)

    kinship_matrix_list <- list(labels = names(kinship_matrix_json),
                                values = kinship_matrix_json)

    kinship_matrix_json <- jsonlite::toJSON(kinship_matrix_list)


    write(kinship_matrix_json,
        file  = kinship_matrix_json_file,
    )
}

if (file.info(trait_kinship_matrix_file)$size == 0) {

    inbre <- diag(trait_kinship_matrix)
    inbre <- inbre - 1

    diag(trait_kinship_matrix) <- inbre

    trait_kinship_matrix <- data.frame(trait_kinship_matrix) %>%
        replace(., . < 0, 0)

    fwrite(trait_kinship_matrix,
        file  = trait_kinship_matrix_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )

    if (file.info(trait_kinship_matrix_json_file)$size == 0) {

        trait_kinship_matrix_json <- trait_kinship_matrix
        trait_kinship_matrix_json[upper.tri(trait_kinship_matrix_json)] <- NA

        trait_kinship_matrix_json <- data.frame(trait_kinship_matrix_json)

        trait_kinship_matrix_list <- list(
            labels = names(trait_kinship_matrix_json),
            values = trait_kinship_matrix_json
        )

        trait_kinship_matrix_json <- jsonlite::toJSON(trait_kinship_matrix_list)

        write(trait_kinship_matrix_json,
            file  = trait_kinship_matrix_json_file,
        )
    }
}


if (file.info(inbreeding_file)$size == 0) {
    fwrite(inbreeding,
        file  = inbreeding_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (file.info(average_kinship_file)$size == 0) {
    average_kinship <- data.frame(apply(trait_kinship_matrix, 1, mean))

    average_kinship <- average_kinship %>%
        rownames_to_column("genotypes") %>%
        rename(Mean_kinship = contains("apply.trait_kinship_matrix")) %>%
        arrange(Mean_kinship) %>%
        mutate_at("Mean_kinship", round, 3) %>%
        column_to_rownames("genotypes")

    fwrite(average_kinship,
        file  = average_kinship_file,
        row.names = TRUE,
        sep   = "\t",
        quote = FALSE,
    )
}

if (file.info(formatted_pheno_file)$size == 0 &&
        !is.null(formatted_pheno_data)) {
    fwrite(formatted_pheno_data,
        file = formatted_pheno_file,
        row.names = TRUE,
        sep = "\t",
        quote = FALSE,
    )
}

if (!is.null(variance_components)) {
    cat(variance_components,
        file = variance_components_file
    )
}

if (!is.null(selection_prediction_log)) {
    cat(log_heading,
        selection_prediction_log,
        fill = TRUE,
        file = analysis_report_file,
        append = FALSE
    )
} else {
    cat(log_heading,
        anova_log,
        training_log,
        modeling_log,
        fill = TRUE,
        file = analysis_report_file,
        append = FALSE
    )
}

message("Done.")

q(save = "no", runLast = FALSE)