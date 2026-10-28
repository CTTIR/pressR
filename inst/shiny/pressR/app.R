# pressR Shiny application
# Single-file implementation. All pressR functions accessed via pressR::.

# -------- UI ---------------------------------------------------------------
ui <- bslib::page_navbar(
  window_title = "pressR",
  title = shiny::tags$span(
    utils::getFromNamespace(".cttir_brand_logo", "pressR")(mode = "dark"),
    "pressR"
  ),
  theme = bslib::bs_theme(
    version = 5,
    bootswatch = "darkly",
    primary = "#00897B",
    secondary = "#26A69A",
    font_scale = 0.95
  ),
  header = shiny::tags$head(
    shiny::tags$link(rel = "stylesheet", type = "text/css",
                     href = "custom.css")
  ),

  bslib::nav_panel(
    "Import",
    shiny::fluidRow(
      shiny::column(
        4,
        shiny::h4("Load data"),
        shiny::fileInput("upload", "Upload file (.asc / .txt / .csv)",
                         accept = c(".asc", ".txt", ".csv")),
        shiny::selectInput(
          "example_type", "Or load example:",
          choices = c("-", "insole", "platform", "saddle_horse",
                      "saddle_bicycle", "wheelchair"),
          selected = "-"
        ),
        shiny::actionButton("load_example", "Load example",
                            class = "btn-primary"),
        shiny::hr(),
        shiny::verbatimTextOutput("trial_info")
      ),
      shiny::column(
        8,
        shiny::h4("Preview"),
        shiny::plotOutput("preview_plot", height = "520px")
      )
    )
  ),

  bslib::nav_panel(
    "Heatmap",
    shiny::fluidRow(
      shiny::column(
        3,
        shiny::sliderInput("frame", "Frame",
                           min = 1, max = 1, value = 1, step = 1),
        shiny::selectInput("hm_type", "Summary type",
                           choices = c("mpp", "mvp", "pti", "contact"),
                           selected = "mpp"),
        shiny::selectInput("palette", "Palette",
                           choices = c("viridis", "inferno", "plasma",
                                       "magma", "jet", "classic"),
                           selected = "viridis"),
        shiny::checkboxInput("show_regions", "Show regions", FALSE),
        shiny::checkboxInput("use_frame", "Single frame (vs summary)",
                             FALSE)
      ),
      shiny::column(
        9,
        shiny::plotOutput("heatmap_plot", height = "600px")
      )
    )
  ),

  bslib::nav_panel(
    "Regions",
    shiny::fluidRow(
      shiny::column(
        3,
        shiny::selectInput("mask_set", "Masks",
                           choices = c("default", "saddle_6", "symmetry"),
                           selected = "default"),
        shiny::selectInput("region_param", "Parameter",
                           choices = c("mpp", "mvp", "max_force",
                                       "contact_area", "pti_mean"),
                           selected = "mpp")
      ),
      shiny::column(
        9,
        shiny::plotOutput("region_plot", height = "400px"),
        DT::DTOutput("region_table")
      )
    )
  ),

  bslib::nav_panel(
    "Dynamics",
    shiny::fluidRow(
      shiny::column(
        12,
        shiny::plotOutput("force_plot", height = "260px"),
        shiny::plotOutput("pressure_plot", height = "260px"),
        shiny::plotOutput("cop_plot", height = "400px")
      )
    )
  ),

  bslib::nav_panel(
    "Compare",
    shiny::fluidRow(
      shiny::column(
        4,
        shiny::h4("Second trial"),
        shiny::selectInput("compare_example", "Load example:",
                           choices = c("-", "insole", "saddle_horse",
                                       "wheelchair"),
                           selected = "-"),
        shiny::actionButton("load_b", "Load as trial B",
                            class = "btn-primary"),
        shiny::selectInput("compare_type", "Display",
                           choices = c("heatmap", "difference",
                                       "parameters"),
                           selected = "heatmap")
      ),
      shiny::column(
        8,
        shiny::plotOutput("compare_plot", height = "600px")
      )
    )
  ),

  bslib::nav_panel(
    "Report",
    shiny::fluidRow(
      shiny::column(
        4,
        shiny::h4("Export"),
        shiny::downloadButton("dl_summary", "Download summary CSV"),
        shiny::br(), shiny::br(),
        shiny::downloadButton("dl_regional", "Download regional CSV"),
        shiny::br(), shiny::br(),
        shiny::downloadButton("dl_pressure", "Download full pressure CSV")
      ),
      shiny::column(
        8,
        shiny::h4("Trial summary"),
        DT::DTOutput("summary_table")
      )
    )
  )
)

# -------- Server ------------------------------------------------------------
server <- function(input, output, session) {

  trial_rv <- shiny::reactiveVal(getOption("pressR.preloaded_trial"))
  trial_b_rv <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$upload, {
    req <- input$upload
    if (is.null(req)) return()
    tryCatch({
      tr <- pressR::pr_read_auto(req$datapath, verbose = FALSE)
      trial_rv(tr)
      shiny::showNotification("Trial loaded.", type = "message")
    }, error = function(e) {
      shiny::showNotification(
        sprintf("Load failed: %s", conditionMessage(e)),
        type = "error"
      )
    })
  })

  shiny::observeEvent(input$load_example, {
    typ <- input$example_type
    if (identical(typ, "-") || !nzchar(typ)) return()
    tryCatch({
      trial_rv(pressR::pr_example_trial(typ))
      shiny::showNotification("Example loaded.", type = "message")
    }, error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "error")
    })
  })

  shiny::observeEvent(input$load_b, {
    typ <- input$compare_example
    if (identical(typ, "-") || !nzchar(typ)) return()
    tryCatch({
      trial_b_rv(pressR::pr_example_trial(typ, seed = 99))
      shiny::showNotification("Trial B loaded.", type = "message")
    }, error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "error")
    })
  })

  shiny::observe({
    tr <- trial_rv()
    if (is.null(tr)) return()
    shiny::updateSliderInput(
      session, "frame", min = 1, max = tr$n_frames, value = 1
    )
  })

  output$trial_info <- shiny::renderPrint({
    tr <- trial_rv()
    if (is.null(tr)) {
      cat("No trial loaded. Upload a file or load an example.")
      return()
    }
    print(tr)
  })

  output$preview_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    pressR::pr_plot_heatmap(tr)
  })

  output$heatmap_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    if (isTRUE(input$use_frame)) {
      pressR::pr_plot_heatmap(
        tr, frame = input$frame, palette = input$palette,
        show_regions = input$show_regions
      )
    } else {
      pressR::pr_plot_heatmap(
        tr, type = input$hm_type, palette = input$palette,
        show_regions = input$show_regions
      )
    }
  })

  masks_for <- shiny::reactive({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    switch(
      input$mask_set,
      default  = pressR::pr_mask_default(tr$layout),
      saddle_6 = pressR::pr_mask_saddle_6(tr$layout),
      symmetry = pressR::pr_mask_symmetry(tr$layout, "vertical")
    )
  })

  output$region_plot <- shiny::renderPlot({
    tr <- trial_rv(); m <- masks_for()
    if (is.null(tr) || length(m) == 0L) return(NULL)
    reg <- pressR::pr_calc_regional(tr, m)
    pressR::pr_plot_regional_bar(reg, input$region_param)
  })

  output$region_table <- DT::renderDT({
    tr <- trial_rv(); m <- masks_for()
    if (is.null(tr) || length(m) == 0L) return(NULL)
    pressR::pr_calc_regional(tr, m)
  })

  output$force_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    pressR::pr_plot_force_time(tr)
  })

  output$pressure_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    pressR::pr_plot_pressure_time(tr)
  })

  output$cop_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    pressR::pr_plot_cop(tr)
  })

  output$compare_plot <- shiny::renderPlot({
    a <- trial_rv(); b <- trial_b_rv()
    if (is.null(a) || is.null(b)) return(NULL)
    pressR::pr_plot_comparison(a, b, type = input$compare_type)
  })

  output$summary_table <- DT::renderDT({
    tr <- trial_rv()
    if (is.null(tr)) return(NULL)
    pressR::pr_summary(tr)
  })

  output$dl_summary <- shiny::downloadHandler(
    filename = "trial_summary.csv",
    content = function(file) {
      tr <- trial_rv()
      if (is.null(tr)) return()
      pressR::pr_export_csv(tr, file, what = "summary")
    }
  )
  output$dl_regional <- shiny::downloadHandler(
    filename = "trial_regional.csv",
    content = function(file) {
      tr <- trial_rv()
      if (is.null(tr)) return()
      pressR::pr_export_csv(tr, file, what = "regional")
    }
  )
  output$dl_pressure <- shiny::downloadHandler(
    filename = "trial_pressure.csv",
    content = function(file) {
      tr <- trial_rv()
      if (is.null(tr)) return()
      pressR::pr_export_csv(tr, file, what = "pressure")
    }
  )
}

shiny::shinyApp(ui, server)
