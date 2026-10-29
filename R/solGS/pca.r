 #SNOPSIS

 #runs population structure analysis using PCA from SNPRelate, a bioconductor R package

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



library(randomForest)
library(data.table)
library(genoDataFilter)
library(tibble)
library(dplyr)
library(stringr)
library(phenoAnalysis)
library(ggplot2)

allArgs <- commandArgs()

outputFile  <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFile, what = "character")

inputFile  <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFile, what = "character")

scoresFile       <- grep("pca_scores", outputFiles, value = TRUE)
screeDataFile    <- grep("pca_scree_data", outputFiles, value = TRUE)
screeFile        <- grep("pca_scree_plot", outputFiles, value = TRUE)
loadingsFile     <- grep("pca_loadings", outputFiles, value = TRUE)
varianceFile     <- grep("pca_variance", outputFiles, value = TRUE)
combinedDataFile <- grep("combined_pca_data_file", outputFiles, value = TRUE)
reportFile       <- grep("report", outputFiles, value = TRUE)

if (is.null(inputFiles)) {
  stop("Os arquivos de entrada não foram informados.")
  q("no", 1, FALSE)
}

if (is.null(scoresFile)) {
  stop("O arquivo de saída dos escores não foi informado.")
  q("no", 1, FALSE)
}

if (is.null(loadingsFile)) {
  stop("O arquivo de cargas não foi informado.")
  q("no", 1, FALSE)
}

genoData         <- c()
genoMetaData     <- c()
filteredGenoFile <- c()
phenoData        <- c()
phenoDataNotes   <- c()

set.seed(235)

pcaDataFile <- grepl("genotype", ignore.case=TRUE, inputFiles)
dataType <- ifelse(isTRUE(pcaDataFile[1]), 'genotype', 'phenotype')

if (dataType == 'genotype') {
    if (length(inputFiles) > 1) {
        genoData <- genoDataFilter::combineGenoData(inputFiles)
        genoMetaData   <- genoData$trial
        genoData$trial <- NULL

    } else {
        genoDataFile <- grep("genotype_data", inputFiles,  value = TRUE)
        genoData     <- fread(genoDataFile,
                              header = TRUE,
                              na.strings = c("NA", " ", "--", "-", "."))

        if (is.null(genoData)) {
            filteredGenoFile <- grep("filtered_genotype_data_",
                                 genoDataFile,
                                 value = TRUE)

            if (filteredGenoFile) {
                genoData <- fread(filteredGenoFile,  header = TRUE)
            }
        }

        genoData <- unique(genoData, by='V1')
        genoData <- data.frame(genoData)
        genoData <- column_to_rownames(genoData, 'V1')

    }
} else if (dataType == 'phenotype') {

    metaDataFile <- grep("meta", inputFiles,  value = TRUE)
    phenoFiles <- grep("phenotype_data", inputFiles,  value = TRUE)

    if (length(phenoFiles) > 1 ) {

        phenoData <- phenoAnalysis::combinePhenoData(phenoFiles, metaDataFile = metaDataFile)
        phenoData <- phenoAnalysis::summarizeTraits(phenoData, groupBy=c('studyDbId', 'germplasmName'))

        if (all(is.na(phenoData$locationName))) {
            phenoData$locationName <- 'location'
        }

        phenoData <- na.omit(phenoData)
        genoMetaData <- phenoData$studyDbId

        phenoData <- phenoData %>% mutate(germplasmName = paste0(germplasmName, '_trial_', studyDbId))
        dropCols = c('replicate', 'blockNumber', 'locationName', 'studyDbId', 'studyYear')
        phenoData <- phenoData %>% select(-dropCols)
        rownames(phenoData) <- NULL
        phenoData <- column_to_rownames(phenoData, var="germplasmName")
    } else {
        phenoDataFile <- grep("phenotype_data", inputFiles,  value = TRUE)

        phenoData <- phenoAnalysis::cleanAveragePhenotypes(inputFiles, metaDataFile)
        phenoData <- na.omit(phenoData)
    }

    traits <- colnames(phenoData)
    phenoDataNotes <- paste0("\nEsta PCA é realizada com dados fenotípicos. \n")
    phenoDataNotes <- append(phenoDataNotes, 
    paste0("\n\nCaracterísticas antes da remoção daquelas com variância zero: ",
    paste(traits, collapse = ", ")))
    
    phenoData <- phenoData[, apply(phenoData, 2, var) != 0 ]
    traits <- colnames(phenoData)
    phenoDataNotes <- append(phenoDataNotes, 
    paste0("\n\nCaracterísticas após a remoção daquelas com variância zero: ",
    paste(traits, collapse = ", ")))
    phenoDataNotes <- append(phenoDataNotes, 
    paste0("\nOs dados das características são centrados e padronizados antes da PCA.\n"))
    phenoData <- scale(phenoData, center=TRUE, scale=TRUE)
    phenoData <- round(phenoData, 3)
}


if (is.null(genoData) && is.null(phenoData)) {
  stop("Não há dados para realizar a PCA.")
  q("no", 1, FALSE)
}

notesHeader <- paste0("Relatório de análise de componentes principais (PCA)")
notesHeader <- append(notesHeader, paste0("\nData: ",
           format(Sys.time(), "%d %b %Y %H:%M"),
           "\n\n\n"))


# notesHeader<- format(notesHeader, width = 80, justify = "c")

genoProcessingNotes <- c()
genoDataMissing <- c()
if (dataType == 'genotype') {
    genoData <- genoDataFilter::convertToNumeric(genoData)
    filterGenoDataResult <- genoDataFilter::filterGenoData(genoData, maf=0.01, logReturn = TRUE)
    genoProcessingNotes <- paste0("\nPré-processamento dos dados genotípicos antes da PCA\n")
    genoProcessingNotes <- append(genoProcessingNotes, localize_analysis_report(filterGenoDataResult$log))
    genoData <- filterGenoDataResult$data
    genoData <- genoDataFilter::roundAlleleDosage(genoData)

    if (sum(is.na(genoData)) > 0) {
        genoDataMissing <- c('yes')
        # genoData <- na.roughfix(genoData)
    }
}

pcaData <- c()
if (!is.null(genoData)) {
    pcaData <- genoData
    genoData <- NULL
} else if(!is.null(phenoData)) {
    pcaData <- phenoData
    phenoData <- NULL
}

message("No. of missing values, ", sum(is.na(pcaData)) )
if (sum(is.na(pcaData)) > 0) {
    pcaData <- na.roughfix(pcaData)
}

pcsCnt <- ifelse(ncol(pcaData) < 10, ncol(pcaData), 10)
pcaNotes <- paste0("\n\nA PCA é realizada usando a função prcomp do R.\n")
pca    <- prcomp(pcaData, retx=TRUE)
pca    <- summary(pca)

scores   <- data.frame(pca$x)
scores   <- scores[, 1:pcsCnt]
scores   <- round(scores, 3)

if (!is.null(genoMetaData)) {
    scores$trial <- genoMetaData
    scores <- scores %>% data.frame
    scores <- scores %>% select(trial, everything()) %>% data.frame
} else {
  scores$trial <- 1000
  scores <- scores %>% select(trial, everything()) %>% data.frame
}

scores   <- scores[order(row.names(scores)), ]

varianceAllPCs <- data.frame(pca$importance)
varianceSelectPCs <- varianceAllPCs[2, 1:pcsCnt]
varianceSelectPCs <- round(varianceSelectPCs, 4) * 100
varianceSelectPCs <- data.frame(t(varianceSelectPCs))

colnames(varianceSelectPCs) <- 'Variances'

loadings <- data.frame(pca$rotation)
loadings <- loadings[, 1:pcsCnt]
loadings <- round(loadings, 3)

varianceAllPCs <- varianceAllPCs[2, ] %>%
    t() %>%
    round(3) * 100

colnames(varianceAllPCs) <- 'Variances'
varianceAllPCs <- data.frame(varianceAllPCs)

varianceAllPCs <- rownames_to_column(varianceAllPCs, 'PCs')
varianceAllPCs <- data.frame(varianceAllPCs)

screePlot <- ggplot(varianceAllPCs, aes(x = reorder(PCs, -Variances), y = Variances, group = 1)) +
    geom_line(color="red") +
    geom_point() +
    xlab('PCs') +
    ylab('Variância explicada (%)') +
    theme(axis.text.x = element_text(angle = 90))

png(screeFile)
screePlot
dev.off()


fwriteOutput <- function (data, dataFile) {
    fwrite(data,
    file      = dataFile,
    sep       = "\t",
    row.names = TRUE,
    quote     = FALSE,
    )

}

fwriteOutput(scores, scoresFile)
fwriteOutput(varianceAllPCs, screeDataFile)
fwriteOutput(loadings, loadingsFile)
fwriteOutput(varianceSelectPCs, varianceFile)

if (!is.null(genoData)) {
    if (length(inputFiles) > 1) {
        fwriteOutput(genoData, combinedDataFile)
    }
}

cat(notesHeader, 
    genoProcessingNotes, 
    phenoDataNotes,
    pcaNotes,
    fill=TRUE, 
    file = reportFile,
    append = FALSE
)

q(save = "no", runLast = FALSE)
