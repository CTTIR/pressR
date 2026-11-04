test_that("pr_trial() constructs a valid object", {
  trial <- pr_example_trial("insole")
  expect_s3_class(trial, "pr_trial")
  expect_equal(trial$n_frames, 250L)
  expect_equal(trial$n_sensors, 99L)
  expect_true(inherits(trial$layout, "pr_layout"))
})

test_that("pr_trial() rejects mismatched dimensions", {
  layout <- pr_layout_insole()
  expect_error(
    pr_trial(
      pressure = matrix(0, nrow = 10, ncol = 5),
      time = seq(0, 1, length.out = 10),
      layout = layout
    )
  )
})

test_that("as.data.frame returns expected columns", {
  trial <- pr_example_trial("custom")
  df <- as.data.frame(trial)
  expect_true(all(c(
    "frame", "time", "sensor_id", "row", "col",
    "x", "y", "coordinate_unit", "measurement_unit", "pressure"
  ) %in% names(df)))
  expect_equal(nrow(df), trial$n_frames * trial$n_sensors)
})

test_that("print/summary for pr_trial do not error", {
  trial <- pr_example_trial("insole")
  expect_invisible(print(trial))
  s <- summary(trial)
  expect_s3_class(s, "tbl_df")
})
