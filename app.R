library(shiny)
library(shinydashboard)
library(dplyr)
library(plotly)

# Define the available datasets
datasets <- read.csv("data/phenoData.csv")

# number of datasets
num_data <- nrow(datasets)
# number of species
num_species <- length(unique(datasets$species))
# number of tissues and cell line
num_tissue <- sum(unique(datasets$tissue) != "NULL")
num_cellline <- sum(unique(datasets$cell_line) != "NULL")
num_tc <- num_tissue + num_cellline

# # Define UI for NAD-RNA page
# Define UI
ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = "NADepot"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Home", tabName = "home", icon = icon("house")),
      menuItem("NAD-RNA", tabName = "nad_rna", icon = icon("dna")),
      menuItem("Downloads", tabName = "downloads", icon = icon("download")),
      # menuItem("About", tabName = "about", icon = icon("info")),
      menuItem("Contact", tabName = "contact", icon = icon("envelope"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "home",
              fluidRow(
                box(
                  title = "Introduction",
                  status = "info",
                  width = 12,
                  solidHeader = TRUE,
                  p("Welcome to NADepot, a storage for NAD-RNA sequencing datasets. 
                    In eukaryotes, 5’,5’-triphosphate-linked 7-methylguanosine (m7G) 
                    is the predominant 5’-end cap structure of RNA (m7Gppp-RNA or m7G-RNA), 
                    essential for RNA stability, polyadenylation, splicing, localization, 
                    and translation. Recently, NAD, the adenine nucleotide containing metabolite,
                    emerged as a non-canonical initiating nucleotide (NCIN) incorporating at 
                    the 5’-terminus of RNA to result in NAD-capped RNAs (NAD-RNA). 
                    NAD capping may define a yet-to-be understood epitranscriptomic mechanism."),
                  div(
                    style = "text-align:center;",
                    img(src = "img/NAD_ill.jpg", width = "50%", height = "auto")
                  )
                )
              ),
              fluidRow(
                valueBox(num_data, "Datasets", icon = icon("database"), color = "green"),
                valueBox(num_species, "Species", icon = icon("globe"), color = "yellow"),
                valueBox(num_tc, "Tissue Types/Cell Lines", icon = icon("gauge-high"), color = "red")
              ),
              fluidRow(
                box(
                  title = "Release Notes",
                  status = "warning",
                  width = 12,
                  solidHeader = TRUE,
                  collapsible = TRUE,
                  p("Version 1.0.0 (Released on April 1, 2023):"),
                  tags$ul(
                    tags$li("Added NAD-RNA information box."),
                    tags$li("Added database statistics value boxes."),
                    tags$li("Added release notes message box.")
                    )
                  )
                )
              ),
      tabItem(tabName = "nad_rna",
              h2("NAD-RNA"),
              fluidRow(
                column(
                  width = 4,
                  box(
                    title = "",
                    status = "primary",
                    width = NULL,
                    selectInput("species", "Select Species:", 
                                choices = unique(datasets$species)),
                    selectInput("tissue", "Select Tissue:", 
                                choices = NULL),
                    selectInput("cell_line", "Select Cell Line:", 
                                choices = NULL),
                    selectInput("condition", "Select Condition:", 
                                choices = NULL),
                    actionButton("submit_btn", "Submit")
                  ),
                  box(title = "Gene Types", status = "primary", width = NULL,
                      plotOutput("gene_types_bar", height = "250px")
                  )
                ),
                column(
                  width = 8,
                  box(width=NULL,
                      DT::dataTableOutput("nad_data_table", width = "auto"))
                  )
                )
      ),
      tabItem(tabName = "downloads",
              h2("Downloads"),
              box(
                title = "Available Datasets",
                status = "primary",
                width = 12,
                solidHeader = TRUE,
                collapsible = TRUE,
                DT::dataTableOutput("datasets_table")
              ),
              box(
                title = "Download Selected Datasets",
                status = "warning",
                width = 12,
                solidHeader = TRUE,
                collapsible = TRUE,
                downloadButton("download_button", "Download Selected Datasets")
              )
              
      ),
      # tabItem(tabName = "about",
      #         h2("About NADepot"),
      #         p("Information about NADepot will be displayed here.")
      # ),
      tabItem(tabName = "contact",
              h2("Contact Us"),
              p("Contact: lida@sioc.ac.cn")
      )
    )
  )
)

# Define server
server <- function(input, output) {
  
  # Render the datasets table
  output$datasets_table <- DT::renderDT({
    DT::datatable(datasets[,-6], selection = "multiple", options = list(pageLength = 10))
  })
  
  # Define the download button server
  output$download_button <- downloadHandler(
    filename = function() {
      paste0("nadepot_data_", format(Sys.time(), "%Y%m%d%H%M%S"), ".zip")
    },
    content = function(file) {
      # Check if any dataset is selected
      if (is.null(input$datasets_table_rows_selected) || length(input$datasets_table_rows_selected) == 0) {
        return(NULL)
      }
      selected_datasets <- datasets[input$datasets_table_rows_selected, ]
      pathnames <- paste0("data/", selected_datasets$data_id)
      zip_filename <- paste0("nadepot_data_", format(Sys.time(), "%Y%m%d%H%M%S"), ".zip")
      zip(file, pathnames)
    }
  )

  # Call server function for NAD-RNA tab
  # Define server logic for NAD-RNA page
  # Load gene annotation
  gene_anno <- read.csv("data/gene_features.csv")
  
  species <- reactive({
    filter(datasets, species == input$species)
  })
  
  # dynamic update input selection
  observeEvent(species(), {
    updateSelectInput(inputId = "tissue", choices = unique(species()$tissue))
    updateSelectInput(inputId = "cell_line", choices = unique(species()$cell_line))
    updateSelectInput(inputId = "condition", choices = unique(species()$condition))
  })
  
  # Filter data based on selected criteria
  # and combine data with gene annotation
  filtered_data <- reactive({
    req(input$submit_btn)
    datasets <- datasets %>%
      filter(species == input$species, tissue == input$tissue, 
             cell_line == input$cell_line, condition == input$condition)
    nad_dat <- read.csv(paste0("data/",datasets$data_id))
    
    # Combine data with associated gene annotation
    nad_dat <- nad_dat %>% left_join(gene_anno, by="gene_id")
  })
  
  # Create bar chart for gene types
  output$gene_types_bar <- renderPlot({
    
    # count percentage of gene type
    df1 <- filtered_data() %>% 
      dplyr::count(gene_biotype, .drop=FALSE) %>% 
      mutate(pct=round(n/sum(n)*100,2),
             gene_biotype=forcats::fct_reorder(gene_biotype, pct, .desc = TRUE),
             label=paste0(gene_biotype, " ", pct, "%"))
    
    ggplot(df1, aes(x = gene_biotype, y = pct, fill = gene_biotype)) + 
      geom_bar(stat = "identity", fill = "#347ABF") +
      geom_text(aes(label = pct), data=subset(df1, pct<10),
                position = position_dodge(width = 0.9), vjust=-1) +
      theme_classic() +
      theme(axis.text.x = element_text(color="black", angle=45, vjust=0.5, hjust=0.5),
            axis.text.y = element_text(color="black"),
            legend.position = "none") +
      scale_x_discrete(labels = gsub("_"," ",levels(df1$gene_biotype))) +
      labs(title = paste0("Gene Types (n = ", sum(df1$n), ")"), y = "Percentage (%)", x = "")
  })
  
  # Display table of NAD-RNA data
  output$nad_data_table <- DT::renderDataTable({
    filtered_data() %>%
      mutate(logCPM = round(as.numeric(logCPM), 3),
             log2_fold_change = round(as.numeric(log2_fold_change), 3),
             FDR = round(as.numeric(FDR), 3)) %>%
      select(gene_id, symbol, gene_biotype, logCPM, log2_fold_change, FDR)
  })
}

# Add this line at the end to tell Shiny where to find the image and data file
addResourcePath("img", "img")
addResourcePath("data", "data")

# Run the application
options(shiny.host = '192.168.205.135')
options(shiny.port = 5000)
shinyApp(ui, server, enableBookmarking = "url")


