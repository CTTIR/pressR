# Tests for R/class-mask.R: pr_mask validation branches and .mask_to_cols.

test_that("pr_mask rejects non-logical / non-matrix input", {
  layout <- pr_layout_saddle("horse")
  expect_error(pr_mask(matrix(1, 16, 16), "x", layout))   # numeric, not logical
  expect_error(pr_mask(c(TRUE, FALSE), "x", layout))       # not a matrix
})

test_that("pr_mask rejects dimension mismatch", {
  layout <- pr_layout_saddle("horse")
  expect_error(pr_mask(matrix(TRUE, 4, 4), "x", layout))
})

test_that("pr_mask rejects non-scalar name", {
  layout <- pr_layout_saddle("horse")
  m <- layout$regions$cranial_left
  expect_error(pr_mask(m, c("a", "b"), layout))
  expect_error(pr_mask(m, 1, layout))
})

test_that("pr_mask maps to active-sensor columns", {
  layout <- pr_layout_saddle("horse")
  m <- pr_mask(layout$regions$middle_left, "middle_left", layout)
  expect_true(all(m$sensor_cols >= 1L))
  expect_true(all(m$sensor_cols <= layout$n_sensors))
  expect_equal(m$n_sensors, length(m$sensor_cols))
})

test_that("print.pr_mask is invisible", {
  layout <- pr_layout_saddle("horse")
  m <- pr_mask(layout$regions$caudal_right, "caudal_right", layout)
  expect_invisible(print(m))
})

test_that(".mask_to_cols accepts a bare logical matrix", {
  layout <- pr_layout_saddle("horse")
  parts <- pr_mask_apply(trial = pr_example_trial("saddle_horse"),
                         masks = list(custom = layout$regions$cranial_left))
  expect_true(ncol(parts$custom) > 0L)
})

test_that(".mask_to_cols errors on invalid mask input", {
  trial <- pr_example_trial("saddle_horse")
  expect_error(
    pr_mask_apply(trial, masks = list(bad = "not a mask"))
  )
})
