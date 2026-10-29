 #SNOPSIS

 #runs ANOVA.
 
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




#library(dplyr)
library(data.table)
library(phenoAnalysis)
library(methods)

render_anova_table <- function(modelOut, tableType, traitName, out) {
    # Change the display table only, keeping the fitted model and its terms intact.
    table <- as.data.frame(stats::anova(modelOut))
    labels <- c("Sum Sq" = "Soma de quadrados", "Mean Sq" = "Quadrado médio",
                "NumDF" = "GL do numerador", "DenDF" = "GL do denominador",
                "Df" = "GL", "F value" = "Valor F", "Pr(>F)" = "Valor p")
    translated <- unname(labels[colnames(table)])
    found <- !is.na(translated)
    colnames(table)[found] <- translated[found]
    capture.output(stargazer::stargazer(table, type = tableType,
        title = paste0("Resultados da ANOVA: ", traitName), summary = FALSE,
        digits = 2, header = FALSE, out = out))
}


allArgs     <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

phenoDataFile <- grep("phenotype_data", inputFiles, value = TRUE)

traitsFile <- grep("traits", inputFiles, value = TRUE)

metadataFile <- grep("metadata", inputFiles, value = TRUE)

metaData <- scan(metadataFile, what="character")

designFactors <- c('germplasmName','studyYear', 'studyDesign', 'blockNumber', 'locationName', 'replicate')
dropCols <-  metaData[! metaData %in% designFactors]

phenoData <- fread(phenoDataFile,
                   header = TRUE,
                   sep="\t",
                   drop=dropCols,
                   na.strings=c("NA", "-", " ", ".", ".."))

phenoData <- data.frame(phenoData)

traits  <- scan(traitsFile,  what = "character")
traits  <- strsplit(traits, "\t")


#needs more work for multi traits anova
for (trait in traits) {
    
    message('trait: ', trait)
    anovaTableFiles     <- grep("anova_table",
                           outputFiles,
                           value = TRUE)

    anovaHtmlFile  <- grep("anova_table_html",
                           anovaTableFiles,
                           value = TRUE)

    anovaTxtFile   <- grep("anova_table_txt",
                           anovaTableFiles,
                           value = TRUE)

    modelSummFile <- grep("anova_model",
                          outputFiles,
                          value = TRUE)

    adjMeansFile  <- grep("adj_means",
                          outputFiles,
                          value = TRUE)

    diagnosticsFile  <- grep("anova_diagnostics",
                             outputFiles,
                             value = TRUE)

    errorFile  <- grep("anova_error",
                       outputFiles,
                       value = TRUE)

    anovaOut <- runAnova(phenoData, trait)
    if (class(anovaOut) == 'character') {
        cat(localize_analysis_report(anovaOut), file=errorFile)
    } else if (is.null(anovaOut)) {
        
        cat('Ocorreu um erro ao ajustar o modelo de ANOVA aos dados desta característica.
             Verifique os dados da característica e os fatores do delineamento.',
            file=errorFile)
        
    } else if (class(anovaOut)[1] == 'lmerModLmerTest' ||
               class(anovaOut)[1] == 'merModLmerTest') {
    
        png(diagnosticsFile, 960, 480)
        par(mfrow=c(1,2))
        plot(fitted(anovaOut), resid(anovaOut),
             xlab="Valores ajustados",
             ylab="Resíduos",
             main="Valores ajustados versus resíduos")
        abline(0,0)
        qqnorm(resid(anovaOut), main = "Gráfico Q-Q normal",
               xlab = "Quantis teóricos", ylab = "Quantis amostrais")
        dev.off()
 
        anovaHtmlTable <- render_anova_table(anovaOut,
                                    tableType="html",
                                    traitName=trait,
                                    out=anovaHtmlFile)

        anovaTxtTable <- render_anova_table(anovaOut,
                                    tableType="text",
                                    traitName=trait,
                                    out=anovaTxtFile)
        
  
        adjMeans   <- getAdjMeans(traitName=trait, modelOut=anovaOut)
  
        fwrite(adjMeans,
               file      = adjMeansFile,
               row.names = FALSE,
               sep       = "\t",
               quote     = FALSE,
               )

        sink(modelSummFile)
        print(anovaOut)
        sink()
    }
  
}


q(save = "no", runLast = FALSE)
