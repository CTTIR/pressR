# Tests for R/export.R report path and pr_export_csv wide-pressure shape,
# using a mocked rmarkdown to exercise the render branch without pandoc.

test_that("pr_export_report errors without rmarkdown", {
  skip_if_not_installed("withr")
  trial <- pr_example_trial("insole")
  testthat::local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(
    pr_export_report(trial, tempfile(fileext = ".html")),
    "rmarkdown"
  )
})

test_that("pr_export_report dispatches templates and renders (mocked)", {
  trial <- pr_example_trial("insole")
  rendered <- new.env()
  testthat::local_mocked_bindings(
    render = function(input, output_file, output_format, ...) {
      rendered$input <- input
      rendered$format <- output_format
      output_file
    },
    .package = "rmarkdown"
  )
  out <- withr::local_tempfile(fileext = ".html")
  res <- pr_export_report(trial, out, template = "foot")
  expect_equal(res, out)
  expect_true(grepl("report_foot", rendered$input))
  expect_equal(rendered$format, "html_document")
})

test_that("pr_export_report pdf format maps to pdf_document (mocked)", {
  trial <- pr_example_trial("saddle_horse")
  seen <- new.env()
  testthat::local_mocked_bindings(
    render = function(input, output_file, output_format, ...) {
      seen$format <- output_format
      output_file
    },
    .package = "rmarkdown"
  )
  out <- withr::local_tempfile(fileext = ".pdf")
  pr_export_report(trial, out, format = "pdf", template = "saddle")
  expect_equal(seen$format, "pdf_document")
})

test_that("pr_export_csv pressure layout includes frame/time columns", {
  trial <- pr_example_trial("custom")
  tmp <- withr::local_tempfile(fileext = ".csv")
  pr_export_csv(trial, tmp, what = "pressure")
  re <- readr::read_csv(tmp, show_col_types = FALSE, progress = FALSE)
  expect_true(all(c("frame", "time") %in% names(re)))
  expect_equal(nrow(re), trial$n_frames)
})

test_that("pr_export_csv rejects non-trial", {
  expect_error(pr_export_csv(list(), tempfile()))
})
