# pressR Shiny application
# Single-file implementation. All pressR functions accessed via pressR::.

options(shiny.maxRequestSize = getOption("pressR.max_upload_bytes", 128 * 1024^2))

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
    shiny::tags$link(
      rel = "stylesheet", type = "text/css",
      href = "custom.css"
    )
  ),
  bslib::nav_panel(
    "Import",
    shiny::fluidRow(
      shiny::column(
        4,
        shiny::h4("Load data"),
        shiny::fileInput("upload", "Upload file (.asc / .txt / .csv)",
          accept = c(".asc", ".txt", ".csv")
        ),
        shiny::selectInput(
          "example_type", "Or load example:",
          choices = c(
            "-", "insole", "platform", "saddle_horse",
            "saddle_bicycle", "wheelchair"
          ),
          selected = "-"
        ),
        shiny::actionButton("load_example", "Load example",
          class = "btn-primary"
        ),
        shiny::helpText("Examples are synthetic. A failed upload clears that recording and its results."),
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
          min = 1, max = 1, value = 1, step = 1
        ),
        shiny::selectInput("hm_type", "Summary type",
          choices = c("mpp", "mvp", "pti", "contact"),
          selected = "mpp"
        ),
        shiny::selectInput("palette", "Palette",
          choices = c(
            "viridis", "inferno", "plasma",
            "magma", "jet", "classic"
          ),
          selected = "viridis"
        ),
        shiny::checkboxInput("show_regions", "Show regions", FALSE),
        shiny::checkboxInput(
          "use_frame", "Single frame (vs summary)",
          FALSE
        )
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
          choices = c("default", "study_rowbands", "saddle_6", "symmetry"),
          selected = "default"
        ),
        shiny::selectInput("region_param", "Parameter",
          choices = c(
            "mpp", "mvp", "max_force",
            "contact_area", "pti_mean"
          ),
          selected = "mpp"
        )
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
    "Temporal",
    shiny::selectInput("temporal_profile", "Analysis profile", c("corrected", "legacy_method")),
    shiny::helpText("Corrected uses measured sampling and stable peak handling. Legacy method uses the historical 50 Hz assumption and does not guarantee exact replay."),
    shiny::actionButton("run_temporal", "Analyze temporal structure"),
    shiny::verbatimTextOutput("temporal_info"),
    DT::DTOutput("cycle_table")
  ),
  bslib::nav_panel(
    "Compare",
    shiny::fluidRow(
      shiny::column(
        4,
        shiny::h4("Second trial"),
        shiny::fileInput("upload_b", "Upload comparison recording", accept = c(".asc", ".txt", ".csv")),
        shiny::selectInput("compare_example", "Load example:",
          choices = c(
            "-", "insole", "saddle_horse",
            "wheelchair"
          ),
          selected = "-"
        ),
        shiny::actionButton("load_b", "Load as trial B",
          class = "btn-primary"
        ),
        shiny::selectInput("compare_type", "Display",
          choices = c(
            "heatmap", "difference",
            "parameters"
          ),
          selected = "heatmap"
        )
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
        shiny::selectInput("report_template", "Report", c("generic", "saddle", "foot")),
        shiny::selectInput("report_format", "Format", c("html", "pdf")),
        shiny::helpText("Reports require rmarkdown and Pandoc. PDF also requires LaTeX. Exports use the masks selected in Regions."),
        shiny::downloadButton("dl_report", "Download report"),
        shiny::br(),
        shiny::downloadButton("dl_summary", "Download summary CSV"),
        shiny::br(), shiny::br(),
        shiny::downloadButton("dl_regional", "Download regional CSV"),
        shiny::br(), shiny::br(),
        shiny::downloadButton("dl_pressure", "Download full pressure CSV"),
        shiny::helpText("Pressure CSV omits layout and calibration. Re-import with the correct layout in R; use pr_write_bundle() for exact reusable trial data.")
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

  load_upload <- function(upload, target) {
    if (is.null(upload)) {
      return()
    }
    target(NULL)
    tryCatch(shiny::withProgress(message = "Reading recording", value = .1, {
      tr <- pressR::pr_read_auto(upload$datapath, filename = upload$name, verbose = FALSE)
      if (!inherits(tr, "pr_trial")) cli::cli_abort("Select a pressure recording.")
      target(tr)

      shiny::incProgress(.9)
      shiny::showNotification("Trial loaded.", type = "message")
    }), error = function(e) shiny::showNotification(paste("Load failed:", conditionMessage(e)), type = "error"))
  }
  shiny::observeEvent(input$upload, load_upload(input$upload, trial_rv))
  shiny::observeEvent(input$upload_b, load_upload(input$upload_b, trial_b_rv))

  shiny::observeEvent(input$load_example, {
    typ <- input$example_type
    if (identical(typ, "-") || !nzchar(typ)) {
      return()
    }
    tryCatch(
      {
        trial_rv(pressR::pr_example_trial(typ))
        shiny::showNotification("Example loaded.", type = "message")
      },
      error = function(e) {
        shiny::showNotification(conditionMessage(e), type = "error")
      }
    )
  })

  shiny::observeEvent(input$load_b, {
    typ <- input$compare_example
    if (identical(typ, "-") || !nzchar(typ)) {
      return()
    }
    tryCatch(
      {
        trial_b_rv(pressR::pr_example_trial(typ, seed = 99))
        shiny::showNotification("Trial B loaded.", type = "message")
      },
      error = function(e) {
        shiny::showNotification(conditionMessage(e), type = "error")
      }
    )
  })

  shiny::observe({
    tr <- trial_rv()
    if (is.null(tr)) {
      return()
    }
    choices <- c("default", "saddle_6", "symmetry")
    study <- identical(tr$layout$name, pressR::pr_layout_saddle_novel()$name)
    if (study) choices <- c(choices, "study_rowbands")
    shiny::updateSelectInput(session, "mask_set", choices = choices, selected = if (study) "study_rowbands" else "default")
    parameters <- c("mpp", "mvp", "pti_mean")
    if (is.finite(tr$layout$sensor_area_cm2)) {
      parameters <- c(parameters, "max_force", "contact_area")
    } else if (identical(tr$layout$pressure_unit, "N")) parameters <- c(parameters, "max_force")
    shiny::updateSelectInput(session, "region_param", choices = parameters, selected = "mpp")
    shiny::updateSliderInput(
      session, "frame",
      min = 1, max = tr$n_frames, value = 1
    )
  })

  output$trial_info <- shiny::renderPrint({
    tr <- trial_rv()
    if (is.null(tr)) {
      cat("No trial loaded. Upload a file or load an example.")
      return()
    }
    provenance <- pressR::pr_report_info(tr)
    filename <- provenance$value[provenance$field == "recording"]
    cat("Recording:",filename,"\n")
    cat("Layout:",tr$layout$name,"\n")
    cat("Frames:",tr$n_frames,"\n")
    cat("Duration:",round(tr$duration,3),"s\n")
    cat("Sampling:",tr$sampling_hz,"Hz\n")
    cat("Measurement unit:", tr$layout$pressure_unit, "\n")
    cat("Coordinate unit:", if (is.null(tr$layout$coords_units)) "mm" else tr$layout$coords_units, "\n")
    if (is.na(tr$layout$sensor_area_cm2)) cat("Physical contact area is unavailable: sensor area is unknown.\n")
  })

  output$preview_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    pressR::pr_plot_heatmap(tr)
  }, alt = "Maximum measured value at each sensor across the current recording, arranged by sensor coordinates.")

  output$heatmap_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    if (isTRUE(input$use_frame)) {
      pressR::pr_plot_heatmap(
        tr,
        frame = input$frame, palette = input$palette,
        show_regions = input$show_regions
      )
    } else {
      pressR::pr_plot_heatmap(
        tr,
        type = input$hm_type, palette = input$palette,
        show_regions = input$show_regions
      )
    }
  }, alt = function() {
    if (isTRUE(input$use_frame)) {
      paste("Sensor map for frame", input$frame, "of the current recording.")
    } else {
      description <- switch(input$hm_type,
        mpp = "Maximum measured value", mvp = "Mean of positive measured values",
        pti = "Measurement-time integral", contact = "Fraction of frames with positive measurements"
      )
      paste(description, "at each sensor across the current recording.")
    }
  })

  masks_for <- shiny::reactive({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    switch(input$mask_set,
      default = pressR::pr_mask_default(tr$layout),
      saddle_6 = pressR::pr_mask_saddle_6(tr$layout),
      study_rowbands = pressR::pr_mask_rowbands(tr$layout, c(5, 11)),
      symmetry = pressR::pr_mask_symmetry(tr$layout, "vertical")
    )
  })

  output$region_plot <- shiny::renderPlot({
    tr <- trial_rv()
    m <- masks_for()
    if (is.null(tr) || length(m) == 0L) {
      return(NULL)
    }
    reg <- pressR::pr_calc_regional(tr, m)
    pressR::pr_plot_regional_bar(reg, input$region_param)
  }, alt = function() {
    paste("Regional", input$region_param, "for the selected", input$mask_set,
      "masks. Numeric values are in the regional table.")
  })

  output$region_table <- DT::renderDT({
    tr <- trial_rv()
    m <- masks_for()
    if (is.null(tr) || length(m) == 0L) {
      return(NULL)
    }
    pressR::pr_calc_regional(tr, m)
  })

  output$force_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    pressR::pr_plot_force_time(tr)
  }, alt = function() {
    tr <- trial_rv()
    if (is.null(tr) || !any(is.finite(pressR::pr_calc_force(tr)))) {
      "Force is unavailable because sensor area or pressure calibration is unknown."
    } else {
      "Total force in newtons versus recording time in seconds."
    }
  })

  output$pressure_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    pressR::pr_plot_pressure_time(tr)
  }, alt = function() {
    tr <- trial_rv()
    unit <- if (is.null(tr)) "recorded units" else tr$layout$pressure_unit
    paste("Peak and mean sensor measurements in", unit, "versus recording time in seconds.")
  })

  output$cop_plot <- shiny::renderPlot({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    pressR::pr_plot_cop(tr)
  }, alt = function() {
    tr <- trial_rv()
    unit <- if (is.null(tr)) NULL else tr$layout[["coords_units"]]
    if (is.null(unit)) unit <- "mm"
    paste("Center of pressure trajectory in", unit, "coordinates, colored by recording time in seconds.")
  })

  output$compare_plot <- shiny::renderPlot({
    a <- trial_rv()
    b <- trial_b_rv()
    if (is.null(a) || is.null(b)) {
      return(NULL)
    }
    pressR::pr_plot_comparison(a, b, type = input$compare_type)
  }, alt = function() {
    switch(input$compare_type,
      heatmap = "Maximum measured values at each sensor in trials A and B, shown side by side.",
      difference = "Difference in maximum sensor measurements, trial B minus trial A, on the matching sensor layout.",
      parameters = "Summary parameters for trials A and B, with each parameter's unit shown on its label."
    )
  })

  temporal_result <- shiny::reactiveVal(NULL)
  shiny::observeEvent(list(trial_rv(), input$temporal_profile), temporal_result(NULL), ignoreNULL = FALSE)
  shiny::observeEvent(input$run_temporal, {
    tr <- shiny::req(trial_rv())
    temporal_result(NULL)
    tryCatch(shiny::withProgress(message = "Analyzing temporal structure", value = .1, {
      temporal_result(pressR::pr_temporal_profile(tr, input$temporal_profile))
      shiny::incProgress(.9)
    }), error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
  })
  output$temporal_info <- shiny::renderPrint({
    result <- temporal_result()
    if (is.null(result)) {
      cat("No temporal analysis for this recording and profile.")
    } else {
      print(result$settings)
      print(result$dominant_frequency)
    }
  })
  output$cycle_table <- DT::renderDT({
    shiny::req(temporal_result())$cycles
  })

  output$summary_table <- DT::renderDT({
    tr <- trial_rv()
    if (is.null(tr)) {
      return(NULL)
    }
    pressR::pr_summary_long(tr)
  })

  export_current <- function(file, writer) {
    tr <- shiny::req(trial_rv())
    tryCatch(writer(tr, file), error = function(e) {
      shiny::showNotification(paste("Export failed:", conditionMessage(e)),
        type = "error", duration = NULL)
      shiny::req(FALSE)
    })
  }

  output$dl_report <- shiny::downloadHandler(
    filename = function() paste0("pressR-report.", input$report_format),
    content = function(file) {
      export_current(file, function(tr, path) {
        shiny::withProgress(message = "Rendering report", {
          pressR::pr_export_report(tr, path, format = input$report_format,
            template = input$report_template, masks = masks_for())
        })
      })
    }
  )
  output$dl_summary <- shiny::downloadHandler(
    filename = "trial_summary.csv",
    content = function(file) {
      export_current(file, function(tr, path) pressR::pr_export_csv(tr, path, what = "summary"))
    }
  )
  output$dl_regional <- shiny::downloadHandler(
    filename = "trial_regional.csv",
    content = function(file) {
      export_current(file, function(tr, path) pressR::pr_export_csv(tr, path, what = "regional", masks = masks_for()))
    }
  )
  output$dl_pressure <- shiny::downloadHandler(
    filename = "trial_pressure.csv",
    content = function(file) {
      export_current(file, function(tr, path) pressR::pr_export_csv(tr, path, what = "pressure"))
    }
  )
}

shiny::shinyApp(ui, server)
