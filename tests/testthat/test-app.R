# Tests for R/app.R: pr_run_app validation and runApp dispatch (mocked, so
# no Shiny server actually launches), plus the imports anchor.

test_that("pr_run_app validates a supplied trial", {
  testthat::local_mocked_bindings(
    runApp = function(appDir, ...) "launched",
    .package = "shiny"
  )
  expect_error(pr_run_app(trial = list()))  # not a pr_trial
})

test_that("pr_run_app launches with a preloaded trial (mocked)", {
  launched <- new.env()
  testthat::local_mocked_bindings(
    runApp = function(appDir, ...) {
      launched$dir <- appDir
      launched$opt <- getOption("pressR.preloaded_trial")
      invisible(NULL)
    },
    .package = "shiny"
  )
  pr_run_app(pr_example_trial("custom"))
  expect_true(nzchar(launched$dir))
  expect_s3_class(launched$opt, "pr_trial")
  # option is cleared on exit
  expect_null(getOption("pressR.preloaded_trial"))
})

test_that("pr_run_app launches empty (mocked)", {
  testthat::local_mocked_bindings(
    runApp = function(appDir, ...) "ok",
    .package = "shiny"
  )
  expect_silent(pr_run_app())
})

test_that("shiny imports anchor is callable", {
  res <- pressR:::.shiny_imports_anchor()
  expect_type(res, "list")
  expect_length(res, 5L)
})
