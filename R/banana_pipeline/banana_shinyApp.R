library(shiny)
library(DT)
library(knitr)
library(ggplot2)
library(leaflet)
library(shinythemes)
library(dplyr)
library(tidyr)
library(data.table)
library(lubridate)
# datasets
Overall <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\bananadata.csv")
plantlets <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\plantlets.csv") 
FloweringD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\all_flowering.csv")
FirstpollinationD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\firstpollination.csv")
RepeatPolln <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\repeatpollination.csv")
HarvestedD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\harvesting.csv")
RipenedD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\ripening.csv")
Plant_statusD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\status.csv")
Seed_extractionD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\extraction.csv")
EmbryorescueD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\rescued.csv")
Germinating_two_weeksD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\germinating2weeks.csv")
Germinating_6weeksD <-  read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\germinating6weeks.csv")
SubcultureD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\subculture.csv")
RootingD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\rooting.csv")
HardeningD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\hardening.csv")
ScreenhouseD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\screenhouse.csv")
OpenfieldD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\openfield.csv")
ContaminationD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\Contamination.csv")
StatusD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\status.csv")

All_data <- Overall %>% 
  select("crossnumber","mother", "mother_accessionName", "father", "father_accessionName", "firstpollination_date",
         starts_with("Male"),starts_with("repeatPollinationDate"), starts_with("Male_accessionName"),"harvesting_date", "days_to_maturity","ripen_date",
         "days_harvest_ripening","seed_extraction_date","number_seeds", "good_seeds","badseeds", "days_ripening_extraction","number_rescued",
         "rescue_date", "days_extraction_rescue","germination_after_2weeks_date","actively_germination_after_two_weeks","days_rescue_2weeksGermination",
         "germination_after_6weeks_date","actively_germination_after_6weeks","days_2weeksGermination_6weeksGermination",
         "subculture_date", "subcultures", "days_6weeks_Germination_subculture")
all_plantlets = plantlets %>%
  select("crossnumber","plantletID","subculture_date","date_rooting","days_subculture_rooting","screenhse_transfer_date","days_rooting_screenhse",
         "hardening_date","days_scrnhse_hardening","date_of_transfer_to_openfield","days_hardening_openfield")
Flowering <- FloweringD[,5:8]
colnames(Flowering) <- c("plot_number","accession_name","flowering_date","sex")
FirstPollination <- FirstpollinationD[,8:13]
colnames(FirstPollination) <- c("mother_plotNumber","mother_acc_name","father_plotNumber","father_acc_name","crossnumber","firstpollination_date")
Firstpollination <- FirstPollination[,c(5,1,2,3,4,6)]
RepeatPollination <- RepeatPolln[,-1]
Harvested <- HarvestedD[,c(4,6:7,3)]
Ripened <- RipenedD[,c(4,6:7,3)]
Seed_extraction <- Seed_extractionD[,c(4,6:8,3)]
Embryorescue <- EmbryorescueD[,c(4,6:10,3)]
Germinating_two_weeks <- Germinating_two_weeksD[,c(4,6:8,3)] 
Germinating_6weeks <- Germinating_6weeksD[,c(4,6:8,3)]
Subculture <- SubcultureD[,c(4,6:8,3)]
Rooting <- RootingD[,c(4,6:7,3)]
Screenhouse <- ScreenhouseD[,c(4,6:7,3)]
Hardening <- HardeningD[,c(4,6:7,3)]
Openfield <- OpenfieldD[,c(4,6:7,3)]
Contamination <- ContaminationD[,c(4,6:7,3)]
Plant_status = StatusD[,c(5:7,3)]

# # NUMBER OF ACCESSION IN DIFFERENT STAGES OF PROJECT
nTable = read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\nTable.csv", stringsAsFactors = F)
# DATA EXPLORER
cleantable <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\cleantable.csv", stringsAsFactors = F)

# Translate presentation copies only; CSV data and input values stay unchanged.
banana_activity_labels <- c(
  flowering = "Florescimento", firstpollination = "Primeira polinização",
  repeatpollination = "Repetição da polinização", harvested = "Colheita",
  ripened = "Maturação", extracted = "Extração de sementes",
  embryrescued = "Resgate de embriões", subcultured = "Subcultivo",
  rooted = "Enraizamento", screenhouse = "Telado", hardened = "Aclimatação",
  openfield = "Campo aberto", status = "Situação", contamination = "Contaminação",
  "germinated after 2 weeks" = "Germinação após duas semanas",
  "germinated after 6 weeks" = "Germinação após seis semanas"
)
banana_activity_label <- function(values) {
  result <- as.character(values)
  translated <- unname(banana_activity_labels[tolower(result)])
  found <- !is.na(translated)
  result[found] <- translated[found]
  result
}

banana_column_labels <- c(
  location = "Local", activity = "Atividade", Activity = "Atividade",
  accession = "Acesso", accession_name = "Nome do acesso", date = "Data",
  contributor = "Colaborador", submitted_by = "Enviado por", N = "Quantidade",
  crossnumber = "Número do cruzamento", plantletID = "ID da muda",
  mother = "Progenitor feminino", mother_accessionName = "Acesso feminino",
  father = "Progenitor masculino", father_accessionName = "Acesso masculino",
  mother_plotNumber = "Parcela do progenitor feminino", mother_acc_name = "Acesso feminino",
  father_plotNumber = "Parcela do progenitor masculino", father_acc_name = "Acesso masculino",
  plot_number = "Número da parcela", sex = "Sexo", flowering_date = "Data de florescimento",
  firstpollination_date = "Data da primeira polinização", harvesting_date = "Data de colheita",
  days_to_maturity = "Dias até a maturidade", ripen_date = "Data de maturação",
  days_harvest_ripening = "Dias entre colheita e maturação",
  seed_extraction_date = "Data de extração das sementes", number_seeds = "Número de sementes",
  good_seeds = "Sementes boas", badseeds = "Sementes ruins",
  days_ripening_extraction = "Dias entre maturação e extração",
  number_rescued = "Número de embriões resgatados", rescue_date = "Data de resgate",
  days_extraction_rescue = "Dias entre extração e resgate",
  germination_after_2weeks_date = "Data de germinação após duas semanas",
  actively_germination_after_two_weeks = "Germinação ativa após duas semanas",
  days_rescue_2weeksGermination = "Dias entre resgate e germinação em duas semanas",
  germination_after_6weeks_date = "Data de germinação após seis semanas",
  actively_germination_after_6weeks = "Germinação ativa após seis semanas",
  days_2weeksGermination_6weeksGermination = "Dias entre as avaliações de germinação",
  subculture_date = "Data de subcultivo", subcultures = "Subcultivos",
  days_6weeks_Germination_subculture = "Dias entre germinação e subcultivo",
  date_rooting = "Data de enraizamento", days_subculture_rooting = "Dias entre subcultivo e enraizamento",
  screenhse_transfer_date = "Data de transferência ao telado",
  days_rooting_screenhse = "Dias entre enraizamento e telado",
  hardening_date = "Data de aclimatação", days_scrnhse_hardening = "Dias entre telado e aclimatação",
  date_of_transfer_to_openfield = "Data de transferência ao campo",
  days_hardening_openfield = "Dias entre aclimatação e campo"
)
banana_column_label <- function(values) {
  result <- banana_activity_label(values)
  translated <- unname(banana_column_labels[values])
  found <- !is.na(translated)
  result[found] <- translated[found]
  result
}
banana_display_data <- function(data) {
  for (column in intersect(c("activity", "Activity"), names(data))) {
    data[[column]] <- banana_activity_label(data[[column]])
  }
  names(data) <- banana_column_label(names(data))
  data
}
banana_table_language <- list(
  emptyTable = "Nenhum dado disponível na tabela", info = "Exibindo _START_ a _END_ de _TOTAL_ registros",
  infoEmpty = "Exibindo 0 a 0 de 0 registros", infoFiltered = "(filtrado de _MAX_ registros)",
  lengthMenu = "Exibir _MENU_ registros", loadingRecords = "Carregando...",
  processing = "Processando...", search = "Buscar:", zeroRecords = "Nenhum registro encontrado",
  paginate = list(first = "Primeira", last = "Última", "next" = "Próxima", previous = "Anterior"),
  aria = list(sortAscending = ": ativar para ordenar em ordem crescente",
              sortDescending = ": ativar para ordenar em ordem decrescente")
)
banana_datatable <- function(data) {
  DT::datatable(banana_display_data(data), options = list(language = banana_table_language))
}

# ui
library(shinyjs)

ui <- navbarPage("BP - TOOL", theme = shinytheme("united"),
                 tabPanel("PAINEL", value = "DASHBOARD",
                          fluidRow(
                                   column(6,h4("Total de envios por dia"),
                                          plotOutput("tsubs", height = 250),
                                          
                                       h5("Atividades por colaborador"),
                                              plotOutput("csubs", height = 300)),
                                   column(4,offset = 1, h4("Número de acessos nas diferentes etapas do projeto"),
                                          hr(),
                                          DT::dataTableOutput("nAccessions"))
                          )),
                 tabPanel("RELATÓRIO DO DIA", value = "TODAY'S REPORT",
                          fluidRow(
                            column(3, h4("Tabela: resumo do dia"), br(),tableOutput("dsumTable")),
                            column(6, h4("Tabela: registros do dia"),br(), tableOutput("dTable"))
                            ),
                          fluidRow( column(10, offset = 1, htmlOutput("text")))
                          ),
                 navbarMenu("TABELAS DE DADOS",
                            tabPanel("Dados de cruzamentos", value = "Crosses datasets",
                                     fluidRow(
                                       column(2,offset=1, 
                                              selectInput("select_activity", "Dados de cruzamentos",
                                                          choices = c("Todos os dados de cruzamentos" = "All crosses data","Florescimento" = "Flowering","Primeira polinização" = "Firstpollination","Repetição da polinização" = "RepeatPollination","Colhidos" = "Harvested",
                                                                      "Maduros" = "Ripened","Extração de sementes" = "Seed_extraction","Resgate de embriões" = "Embryorescue","Germinação em duas semanas" = "Germinating_two_weeks",
                                                                      "Germinação em seis semanas" = "Germinating_6weeks","Subcultivo" = "Subculture")))),
                                      fluidRow(
                                        hr(),
                                        column(10,offset=1, 
                                              div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                                  DT::dataTableOutput("crossesTable")),
                                              downloadButton('downloadcrosses', 'Baixar dados')))
                                     ),
                            tabPanel("Dados de mudas", value = "Plantlets datasets",
                                     fluidRow(
                                       column(2, offset = 1,
                                              selectInput("plantlets","Dados de mudas",
                                                          choices = c("Todos os dados de mudas" = "All plantlets data","Enraizamento" = "Rooting","Telado" = "Screenhouse","Aclimatação" = "Hardening","Campo aberto" = "Openfield")))),
                                     hr(),
                                     fluidRow(
                                       column(10,offset=1, 
                                              div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                                  DT::dataTableOutput("plantletsTable")),
                                              downloadButton('downloadplantlets', 'Baixar dados')))
                                     ),
                            tabPanel("Situação e contaminação", value = "Status and contamination",
                                      fluidRow(           
                                       column(2, offset = 1,
                                              selectInput("statusCont","Situação e contaminação", choices = c("Situação" = "Status","Contaminação" = "Contamination")))
                                     ),
                                     hr(),
                                     fluidRow(
                                       column(10,offset=1, 
                                              div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                                  DT::dataTableOutput("statusConTable")),
                                              downloadButton('downloadstatusCont', 'Baixar dados')))
                                     )
                            ),
                  tabPanel("EXPLORADOR DE DADOS", value = "DATA EXPLORER",
                                     fluidRow(
                                       column(3,selectInput("locations", "Locais", c("Todos os locais"="", unique(cleantable$location)), multiple=TRUE)),
                                       column(3,conditionalPanel("input.locations",
                                                                 selectInput("activities", "Atividades", c("Atividades"=""), multiple=TRUE))),
                                       column(3,conditionalPanel("input.locations",
                                                                 selectInput("accessions", "Acessos", c("Acessos"=""), multiple=TRUE)))
                                     ),
                                     fluidRow(
                                       column(10, offset = 1,
                                              DT::dataTableOutput("dataExplorer"))
                                     )
                            )
                 
)

server <- function(input, output, session){
  output$tsubs <- renderPlot({
    qplot(data=cleantable, x=date) + xlab("Data") + ylab("Número de envios") + theme(legend.position = "bottom")
  })
 output$csubs <- renderPlot({
    qplot(data=cleantable, x=contributor, fill=activity) +
      labs(x = "Colaborador", y = "Número de envios") +
      scale_fill_discrete(name = "Atividade", labels = banana_activity_label) + theme(legend.position = "right")
  })
 output$nAccessions <- DT::renderDataTable({
   banana_datatable(nTable)
 })
 
  crossesInput <- reactive({
    switch(input$select_activity, "All crosses data" = All_data,
           "Flowering" = Flowering,"Firstpollination" = Firstpollination,
           "RepeatPollination" = RepeatPollination,
           "Harvested" = Harvested,"Ripened" = Ripened,"Seed_extraction" = Seed_extraction,
           "Embryorescue" = Embryorescue,"Germinating_two_weeks" = Germinating_two_weeks,
           "Germinating_6weeks" = Germinating_6weeks,"Subculture" = Subculture)
  })
  
  plantletsInput <- reactive({
    switch(input$plantlets, "All plantlets data" = all_plantlets,
           "Rooting" = Rooting,"Screenhouse" = Screenhouse,"Hardening" = Hardening,"Openfield" = Openfield)
  })
  statusConInput <- reactive({
    switch(input$statusCont,"Status" = Plant_status,"Contamination" = Contamination)
  })
  
  output$crossesTable <- DT::renderDataTable({
    banana_datatable(crossesInput())
  })
  output$plantletsTable <- DT::renderDataTable({
    banana_datatable(plantletsInput())
  })
  output$statusConTable <- DT::renderDataTable({
    banana_datatable(statusConInput())
  })
  
  
  output$downloadData <- downloadHandler(
    filename = function() { paste(input$datasets, '.csv', sep='') },
    content = function(file) {
      write.csv(datasetInput(), file)
    })
  
  todaydata = dplyr::filter(cleantable, cleantable$date==Sys.Date())
  
  if (dim(todaydata)[1]==0)
  {
    output$text <- renderText({paste("Nenhuma atividade foi registrada hoje")})
  }
  else{
    mytable = table(todaydata$location,todaydata$activity)
    dtable = as.data.frame(mytable)
    names(dtable) = c("location","Activity","N")
    output$dsumTable <- renderTable(banana_display_data(dtable))
    output$dTable <- renderTable(banana_display_data(todaydata))
  }
  output$dPlot <- renderPlot({
    s<- ggplot(todaydata, aes(activity, fill=contributor))
    s + geom_bar(position = 'stack') +
      labs(x = "Atividade", y = "Número de envios", fill = "Colaborador") +
      scale_x_discrete(labels = banana_activity_label) +  theme(legend.position = "bottom") + coord_flip()
  })
  ggplot(todaydata, aes(x = reorder(activity, -accession), y = accession, fill = activity)) + 
    geom_bar(stat = "identity")
  
# Data explorer
  observe({
    activities <- if (is.null(input$locations)) character(0) else {
      filter(cleantable, location %in% input$locations) %>%
        `$`('activity') %>%
        unique() %>%
        sort()
    }
    stillSelected <- isolate(input$activities[input$activities %in% activities])
    updateSelectInput(session, "activities", choices = setNames(activities, banana_activity_label(activities)),
                      selected = stillSelected)
  })
  
  observe({
    accessions <- if (is.null(input$locations)) character(0) else {
      cleantable %>%
        filter(location %in% input$locations,
               is.null(input$activities) | activity %in% input$activities) %>%
        `$`('accession') %>%
        unique() %>%
        sort()
    }
    stillSelected <- isolate(input$accessions[input$accessions %in% accessions])
    updateSelectInput(session, "accessions",choices = accessions,
                      selected = stillSelected)
  })
  
  output$dataExplorer <- DT::renderDataTable({
    df <- cleantable %>%
      filter(
        is.null(input$locations) | location %in% input$locations,
        is.null(input$activities) | activity %in% input$activities,
        is.null(input$accessions) | accession %in% input$accessions
      ) #%>%
    #mutate(Action = paste('<a class="go-map" href="" data-lat="', Lat, '" data-long="', Long, '" data-zip="', Zipcode, '"><i class="fa fa-crosshairs"></i></a>', sep=""))
    display_df <- banana_display_data(df)
    action <- DT::dataTableAjax(session, display_df)
    
    DT::datatable(display_df, options = list(ajax = list(url = action),
                  language = banana_table_language), escape = FALSE)
  })
} 
shinyApp(ui = ui, server = server)