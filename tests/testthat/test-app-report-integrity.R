test_that("reports use exact metadata fields and an explicit missing identity", {
  trial <- pr_example_trial("custom")
  trial$metadata$source_filename <- NULL
  trial$metadata$trial_id <- NULL
  trial$metadata$source_filename_unknown <- "wrong-source"
  trial$metadata$trial_id_unknown <- "wrong-trial"
  trial$metadata$source_sha256_unknown <- "wrong-hash"
  trial$metadata$analysis_profile_unknown <- "wrong-profile"
  info <- pr_report_info(trial)
  value <- stats::setNames(info$value, info$field)
  expect_identical(unname(value["recording"]), "not recorded")
  expect_identical(unname(value["source_sha256"]), "not recorded")
  expect_identical(unname(value["temporal_profile"]), "not applied")
  trial$metadata$trial_id <- "synthetic-001"
  expect_identical(pr_report_info(trial)$value[2], "synthetic-001")
  trial$metadata$source_filename <- "recording.csv"
  expect_identical(pr_report_info(trial)$value[2], "recording.csv")
  for (empty in list(NA_character_, "", character())) {
    trial$metadata$source_filename <- empty
    expect_identical(pr_report_info(trial)$value[2], "synthetic-001")
  }
})

test_that("app preload identity and failed exports cannot claim stale success", {
  trial <- pr_example_trial("custom")
  trial$metadata$trial_id <- NULL
  trial$metadata$source_filename_unknown <- "wrong-source"
  withr::local_options(list(pressR.preloaded_trial = trial,
    shiny.maxRequestSize = NULL, sass.cache = FALSE))
  env <- new.env(parent = globalenv())
  sys.source(system.file("shiny", "pressR", "app.R", package = "pressR"), env)
  notices <- character()
  testthat::local_mocked_bindings(showNotification = function(ui, ...) {
    notices <<- c(notices, as.character(ui))
    "notice"
  }, .package = "shiny")
  shiny::testServer(env$server, {
    session$setInputs(mask_set = "default", region_param = "mpp",
      hm_type = "mpp", palette = "viridis", compare_type = "heatmap")
    expect_match(output$trial_info, "Recording: not recorded", fixed = TRUE)
    path <- withr::local_tempfile(fileext = ".html")
    expect_error(export_current(path, function(tr, file) {
      cli::cli_abort("Pandoc is unavailable; install Pandoc to create reports.")
    }), class = "shiny.silent.error")
    expect_false(file.exists(path))
    expect_match(tail(notices, 1), "Export failed:.*Pandoc")
    expect_identical(trial_rv(), trial)
    export_current(path, function(tr, file) writeLines("completed report", file))
    expect_identical(readLines(path), "completed report")
  })
})

test_that("launcher restores existing options on return and failure", {
  previous <- pr_example_trial("custom")
  withr::local_options(list(pressR.preloaded_trial = previous, shiny.maxRequestSize = 123456))
  for (fail in c(FALSE, TRUE)) {
    testthat::local_mocked_bindings(runApp = function(appDir, ...) {
      expect_null(getOption("pressR.preloaded_trial"))
      options(shiny.maxRequestSize = 999)
      if (fail) cli::cli_abort("server start failed")
      invisible(NULL)
    }, .package = "shiny")
    if (fail) expect_error(pr_run_app(), "server start failed") else pr_run_app()
    expect_identical(getOption("pressR.preloaded_trial"), previous)
    expect_identical(getOption("shiny.maxRequestSize"), 123456)
  }
})

test_that("report tables retain literal text without active HTML or Markdown", {
  skip_if_not_installed("knitr")
  payload <- "<script>example()</script> [unexpected](https://example.invalid) | value & more"
  testthat::local_mocked_bindings(is_html_output = function(...) TRUE, .package = "knitr")
  html <- as.character(pressR:::.report_table(data.frame(recording = payload)))
  expect_false(grepl("<script>", html, fixed = TRUE))
  expect_false(grepl("<a ", html, fixed = TRUE))
  expect_match(html, "&lt;script&gt;example()&lt;/script&gt;", fixed = TRUE)
  expect_match(html, "[unexpected](https://example.invalid)", fixed = TRUE)
  expect_match(html, "| value &amp; more", fixed = TRUE)
})

test_that("PDF table content is escaped as literal LaTeX data", {
  skip_if_not_installed("knitr")
  testthat::local_mocked_bindings(is_html_output = function(...) FALSE,
    is_latex_output = function(...) TRUE, .package = "knitr")
  payload <- "name_1 & 50% $value$ {field}"
  latex <- as.character(pressR:::.report_table(data.frame(recording = payload)))
  expect_match(latex, "name\\_1", fixed = TRUE)
  expect_match(latex, "\\&", fixed = TRUE)
  expect_match(latex, "50\\%", fixed = TRUE)
  expect_match(latex, "\\$value\\$", fixed = TRUE)
  expect_match(latex, "\\begin{longtable}", fixed = TRUE)
})

test_that("actual HTML reports preserve literal metadata through Pandoc", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for report rendering")
  trial <- pr_example_trial("custom")
  trial$metadata$source_filename <- paste0(
    "<script>example()</script> [unexpected](https://example.invalid) ",
    "| literal `code` & value"
  )
  withr::local_options(htmltools.preserve.raw = TRUE)
  path <- withr::local_tempfile(fileext = ".html")
  pr_export_report(trial, path)
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(html, "&lt;script&gt;example()&lt;/script&gt;", fixed = TRUE)
  expect_match(html, "[unexpected](https://example.invalid)", fixed = TRUE)
  expect_match(html, "literal `code` &amp; value", fixed = TRUE)
  expect_false(grepl('href="https://example.invalid"', html, fixed = TRUE))
  expect_true(getOption("htmltools.preserve.raw"))
})


test_that("actual PDF reports include the escaped-table dependency", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for report rendering")
  skip_if(!nzchar(Sys.which("pdflatex")), "A LaTeX installation is required for PDF reports")
  trial <- pr_example_trial("custom")
  trial$metadata$source_filename <- "name_1 & 50% $value$ {field}"
  path <- withr::local_tempfile(fileext = ".pdf")
  pr_export_report(trial, path, format = "pdf")
  expect_identical(rawToChar(readBin(path, "raw", 4L)), "%PDF")
  expect_gt(file.info(path)$size, 1000)
})
