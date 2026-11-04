test_that("server handles real upload metadata, failed replacement and comparison", {
  withr::local_options(list(pressR.preloaded_trial = NULL, shiny.maxRequestSize = NULL, sass.cache = FALSE))
  env <- new.env(parent = globalenv())
  sys.source(system.file("shiny", "pressR", "app.R", package = "pressR"), env)
  tr <- pr_example_trial("custom")
  path <- withr::local_tempfile()
  pr_export_csv(tr, path, "pressure")
  bad <- withr::local_tempfile()
  writeLines("broken file", bad)
  shiny::testServer(env$server, {
    session$setInputs(mask_set = "default", region_param = "mpp", hm_type = "mpp", palette = "viridis", compare_type = "heatmap", temporal_profile = "corrected")
    session$setInputs(upload = data.frame(name = "original.csv", size = file.info(path)$size, type = "text/csv", datapath = path))
    expect_s3_class(trial_rv(), "pr_trial")
    expect_match(output$trial_info, "Recording: original.csv",fixed=TRUE)
    expect_match(output$trial_info, "Frames: 100",fixed=TRUE)
    expect_identical(trial_rv()$metadata$source_filename, "original.csv")
    session$setInputs(upload_b = data.frame(name = "second.csv", size = file.info(path)$size, type = "text/csv", datapath = path))
    expect_identical(trial_b_rv()$metadata$source_filename, "second.csv")
    expect_equal(trial_b_rv()$pressure, trial_rv()$pressure)
    session$setInputs(upload = data.frame(name = "invalid.asc", size = file.info(bad)$size, type = "text/plain", datapath = bad))
    expect_null(trial_rv())
    expect_s3_class(trial_b_rv(), "pr_trial")
  })
})

test_that("failed export preserves the existing output", {
  path <- withr::local_tempfile()
  writeLines("existing", path)
  expect_error(pressR:::.atomic_output(path, function(tmp) {
    writeLines("partial", tmp)
    stop("render failed")
  }), "render failed")
  expect_identical(readLines(path), "existing")
})

test_that("difference plots reject coordinates and units that merely share a name", {
  a <- pr_example_trial("custom")
  b <- a
  b$layout$coords_mm$x_mm <- b$layout$coords_mm$x_mm + 1
  expect_error(pr_plot_comparison(a, b, "difference"), "matching layouts")
  b <- a
  b$layout$pressure_unit <- "Pa"
  expect_error(pr_plot_comparison(a, b, "difference"), "units")
  expect_error(pr_plot_comparison(a, b, "parameters"), "units")
})
