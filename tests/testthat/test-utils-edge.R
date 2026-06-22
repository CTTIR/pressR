# Edge branches in R/utils.R and R/calc-summary.R.

test_that("pr_filter_time errors when window is empty", {
  tr <- pr_example_trial("insole")
  expect_error(pr_filter_time(tr, from = 100, to = 200))
})

test_that("pr_downsample factor 1 returns the trial unchanged", {
  tr <- pr_example_trial("custom")
  expect_identical(pr_downsample(tr, 1), tr)
})

test_that("pr_downsample rejects factor < 1", {
  expect_error(pr_downsample(pr_example_trial("custom"), 0))
})

test_that("pr_interpolate factor 1 returns the raw grid", {
  out <- pr_interpolate(pr_example_trial("custom"), factor = 1)
  layout <- pr_layout_mat("16")
  expect_equal(dim(out$pressure_interp), c(layout$grid_rows, layout$grid_cols))
})

test_that("pr_interpolate rejects factor < 1", {
  expect_error(pr_interpolate(pr_example_trial("custom"), 0))
})

test_that("pr_interpolate factor 3 expands both dimensions", {
  tr <- pr_example_trial("custom")
  out <- pr_interpolate(tr, factor = 3)
  expect_true(nrow(out$pressure_interp) > tr$layout$grid_rows)
  expect_true(ncol(out$pressure_interp) > tr$layout$grid_cols)
})

test_that("pr_calc_symmetry_index returns 0 when both sides empty", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(0, 3, layout$n_sensors),
                 time = c(0, 1, 2), layout = layout)
  expect_equal(pr_calc_symmetry_index(tr), 0)
})

test_that("pr_summary works on a zero-load trial without error", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(0, 3, layout$n_sensors),
                 time = c(0, 1, 2), layout = layout)
  s <- pr_summary(tr)
  expect_s3_class(s, "tbl_df")
  expect_equal(s$mpp, 0)
})
