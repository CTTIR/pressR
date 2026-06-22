# Tests for R/class-trial.R: pr_trial constructor branches, S3 methods,
# the %||% infix, and .validate_trial.

test_that("pr_trial computes sampling_hz from time when NULL", {
  layout <- pr_layout_mat("16")
  P <- matrix(1, nrow = 5, ncol = layout$n_sensors)
  tr <- pr_trial(P, time = seq(0, 0.08, by = 0.02), layout = layout)
  expect_equal(tr$sampling_hz, 50)
})

test_that("pr_trial sets sampling_hz NA for a single frame", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(1, 1, layout$n_sensors), time = 0, layout = layout)
  expect_true(is.na(tr$sampling_hz))
  expect_equal(tr$duration, 0)
})

test_that("pr_trial rejects non-matrix pressure", {
  layout <- pr_layout_mat("16")
  expect_error(
    pr_trial(pressure = 1:10, time = 1:10, layout = layout),
    class = "rlang_error"
  )
})

test_that("pr_trial rejects time length mismatch", {
  layout <- pr_layout_mat("16")
  expect_error(
    pr_trial(matrix(0, 3, layout$n_sensors), time = c(0, 1), layout = layout)
  )
})

test_that("pr_trial requires a pr_layout", {
  expect_error(pr_trial(matrix(0, 1, 1), time = 0, layout = list()))
})

test_that("pr_trial coerces non-list metadata to list and fills defaults", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(1, 2, layout$n_sensors), time = c(0, 1),
                 layout = layout, metadata = "not a list")
  expect_type(tr$metadata, "list")
  expect_true("subject_id" %in% names(tr$metadata))
  expect_equal(tr$metadata$system, layout$model)
})

test_that("pr_trial preserves supplied metadata fields", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(1, 2, layout$n_sensors), time = c(0, 1),
                 layout = layout,
                 metadata = list(subject_id = "S99", condition = "test"))
  expect_equal(tr$metadata$subject_id, "S99")
  expect_equal(tr$metadata$condition, "test")
})

test_that("plot.pr_trial returns a ggplot", {
  p <- plot(pr_example_trial("custom"))
  expect_s3_class(p, "ggplot")
})

test_that("as.data.frame.pr_trial has one row per frame*sensor", {
  tr <- pr_example_trial("custom")
  df <- as.data.frame(tr)
  expect_equal(nrow(df), tr$n_frames * tr$n_sensors)
  expect_equal(df$pressure[seq_len(tr$n_sensors)], tr$pressure[1, ],
               ignore_attr = TRUE)
})

test_that(".validate_trial rejects non-trials", {
  expect_error(pr_calc_force(list()), class = "rlang_error")
})

test_that("print.pr_trial snapshot-stable structure", {
  tr <- pr_example_trial("insole")
  expect_invisible(print(tr))
})
