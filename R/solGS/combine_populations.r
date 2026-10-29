#formats and combines phenotype (of a single trait)
#and genotype datasets of multiple
#populations

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



library(stringr)
library(randomForest)
library(lme4)
library(data.table)
library(phenoAnalysis)
library(dplyr)
library(tibble)
library(genoDataFilter)

allArgs <- commandArgs()

inFile <- grep("input_files",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

inFiles <- scan(inFile,
                what = "character"
                )

outFile <- grep("output_files",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

outFiles <- scan(outFile,
                 what = "character"
                 )

combinedGenoFile <- grep("genotype_data",
                         outFiles,
                         ignore.case = TRUE,
                         fixed = FALSE,
                         value = TRUE
                         )

combinedPhenoFile <- grep("model_phenodata",
                          outFiles,
                          ignore.case = TRUE,
                          fixed = FALSE,
                          value = TRUE
                          )

analysisReportFile <- grep("_report_",
                          outFiles,
                          ignore.case = TRUE,
                          fixed = FALSE,
                          value = TRUE
                          )

## traitFile <- grep("model_phenodata",
##                   inFiles,
##                   ignore.case = TRUE,
##                   fixed = FALSE,
##                   value = TRUE
##                   )

## trait <- scan(traitFile,
##               what = "character",
##               )

## traitInfo <- strsplit(trait, "\t");
## traitId   <- traitInfo[[1]]
## traitName <- traitInfo[[2]]

modelInfoFile  <- grep("model_info", inFiles, value = TRUE)
message('model_info_file ', modelInfoFile)

traitRawPhenoFile <- grep('trait_raw_phenodata', outFiles, value = TRUE)

modelInfo  <- read.table(modelInfoFile,
                         header=TRUE, sep ="\t",
                         as.is = c('Value'))

modelInfo  <- column_to_rownames(modelInfo, var="Name")
traitId    <- modelInfo["trait_id", 1]
traitAbbr  <- modelInfo["trait_abbr", 1]
modelId    <- modelInfo["model_id", 1]
protocolId <- modelInfo["protocol_id", 1]

message('class ', class(traitAbbr))
message('trait_id ', traitId)
message('trait_abbr ', traitAbbr)
message('protocol_id ', protocolId)
message('model_id ', modelId)

#extract trait phenotype data from all populations
#and combine them into one dataset

allPhenoFiles <- grep("phenotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )
message("phenotype files: ", allPhenoFiles)

allGenoFiles <- grep("genotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )

popIds            <- c()
combinedPhenoPops <- c()
cnt               <- 0
traitRawPhenoData <- c()

logHeading <- paste0("Relatório da análise de predição genômica para ", traitAbbr,  ".\n")
logHeading <- append(logHeading,  paste0("Data: ", format(Sys.time(), "%d %b %Y %H:%M"), "\n\n\n"))
logHeading <- format(logHeading, width=80, justify="c")

anovaLog <- paste0("#Pré-processamento dos dados fenotípicos da população de treinamento.\n\n")
anovaLog <- append(anovaLog, paste0("Esta população de treinamento é composta por ", length(allPhenoFiles), " ensaios. As médias ajustadas ou aritméticas das características de cada ensaio serão calculadas conforme descrito abaixo. Em seguida, será calculado um único valor por característica para cada entrada, obtido pela média das médias ajustadas ou aritméticas entre os ensaios.\n\n"))

for (popPhenoFile in allPhenoFiles) {

     cnt <- cnt + 1

    phenoData <- fread(popPhenoFile,
                       header = TRUE,
                       sep="\t",
                       na.strings = c("NA", "", "--", "-", "."))

     phenoData <- data.frame(phenoData)

     meansResult <- getAdjMeans(phenoData,
                               traitName = traitAbbr,
                               calcAverages = TRUE,
                               logReturn = TRUE)

   anovaLog <- append(anovaLog, localize_analysis_report(meansResult$log, c(traitAbbr, phenoData$studyName)))
   phenoTrait <- meansResult$adjMeans

    keepMetaCols <- c('observationUnitName', 'germplasmName', 'studyDbId', 'locationName',
                  'studyYear', 'replicate', 'blockNumber')

    trialTraitRawPhenoData <- phenoData %>%
                                        select(c(keepMetaCols, traitAbbr))

     popIdFile <- basename(popPhenoFile)
     popId     <- str_extract(popIdFile, "\\d+")
     popIds    <- c(popIds, popId)

     newTraitName <- paste(traitAbbr, popId, sep = "_")
     colnames(phenoTrait)[2] <- newTraitName

     if (cnt == 1 ) {
         combinedPhenoPops <- phenoTrait
         traitRawPhenoData <- trialTraitRawPhenoData
     } else {
           combinedPhenoPops <- full_join(combinedPhenoPops, phenoTrait, by='germplasmName')
           traitRawPhenoData <- bind_rows(traitRawPhenoData, trialTraitRawPhenoData)
     }
 }

combinedPhenoPops <- column_to_rownames(combinedPhenoPops, var='germplasmName')

# #fill in missing data in combined phenotype dataset
# #using row means
naIndices <- which(is.na(combinedPhenoPops), arr.ind=TRUE)
combinedPhenoPops <- as.matrix(combinedPhenoPops)
combinedPhenoPops[naIndices] <- rowMeans(combinedPhenoPops, na.rm=TRUE)[naIndices[,1]]
combinedPhenoPops <- as.data.frame(combinedPhenoPops)

message("combined total number of stocks in phenotype dataset (before averaging): ", length(rownames(combinedPhenoPops)))

combinedPhenoPops$Average<-round(apply(combinedPhenoPops, 1, function(x) { mean(x) }), digits = 2)

combinedGenoPops <- c()

if (file.size(combinedGenoFile) < 100 ) {
    combinedGenoPops       <- combineGenoData(allGenoFiles)
    combinedGenoPops$trial <- NULL
    combinedGenoPops       <- combinedGenoPops[order(rownames(combinedGenoPops)), ]
}

message("writing data to files...")
#if(length(combinedPhenoFile) != 0 )
#  {
      fwrite(combinedPhenoPops,
                  file = combinedPhenoFile,
                  sep = "\t",
                  quote = FALSE,
                  row.names = TRUE,
                  )
#  }
if (!is.null(traitRawPhenoData) & length(traitRawPhenoFile) != 0) {

    fwrite(traitRawPhenoData,
           file  = traitRawPhenoFile,
           row.names = FALSE,
           sep   = "\t",
           na = 'NA',
           quote = FALSE,
           )
}
if(!is.null(combinedGenoPops)) {
    fwrite(combinedGenoPops,
           file = combinedGenoFile,
           sep = "\t",
           quote = FALSE,
           row.names = TRUE,
           )
 }

cat(anovaLog, fill = TRUE,  file = analysisReportFile, append=FALSE)

q(save = "no", runLast = FALSE)
