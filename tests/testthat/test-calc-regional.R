# Tests for R/calc-regional.R: parameter validation, empty regions,
# single-frame PTI branch, mask sourcing, and the seat hotspot edge cases.

test_that("pr_calc_regional rejects unknown parameters", {
  trial <- pr_example_trial("saddle_horse")
  expect_error(pr_calc_regional(trial, parameters = "bogus"))
})

test_that("pr_calc_regional errors when no masks available", {
  trial <- pr_example_trial("platform")  # platform has no layout regions
  expect_error(pr_calc_regional(trial))
})

test_that("pr_calc_regional requires named masks", {
  trial <- pr_example_trial("saddle_horse")
  m <- pr_mask_saddle_6(trial$layout)
  names(m) <- NULL
  expect_error(pr_calc_regional(trial, masks = m))
})

test_that("pr_calc_regional selects requested parameter columns", {
  trial <- pr_example_trial("saddle_horse")
  out <- pr_calc_regional(trial, parameters = c("mpp", "pti_max"))
  expect_named(out, c("region", "mpp", "pti_max"))
})

test_that("pr_calc_regional returns zeros for an empty region", {
  trial <- pr_example_trial("saddle_horse")
  empty <- matrix(FALSE, trial$layout$grid_rows, trial$layout$grid_cols)
  out <- pr_calc_regional(trial, masks = list(empty = empty),
                          parameters = c("mpp", "contact_area"))
  expect_equal(out$mpp, 0)
  expect_equal(out$contact_area, 0)
})

test_that("pr_calc_regional handles single-frame trials (no PTI)", {
  layout <- pr_layout_saddle("horse")
  P <- matrix(50, nrow = 1, ncol = layout$n_sensors)
  trial <- pr_trial(P, time = 0, layout = layout)
  out <- pr_calc_regional(trial, parameters = c("mpp", "pti_max", "pti_mean"))
  expect_equal(out$pti_max, rep(0, 6))
  expect_equal(out$pti_mean, rep(0, 6))
})

test_that("pr_calc_seat_hotspot returns empty tibble when none exceed", {
  trial <- pr_example_trial("wheelchair")
  hs <- pr_calc_seat_hotspot(trial, threshold = 1e6)
  expect_s3_class(hs, "tbl_df")
  expect_equal(nrow(hs), 0L)
})

test_that("pr_calc_seat_hotspot honors duration filter", {
  trial <- pr_example_trial("wheelchair")
  hs_all  <- pr_calc_seat_hotspot(trial, threshold = 1, duration_s = 0)
  hs_long <- pr_calc_seat_hotspot(trial, threshold = 1, duration_s = 1e6)
  expect_true(nrow(hs_long) <= nrow(hs_all))
})

test_that("pr_calc_seat_hotspot single-frame uses zero duration", {
  layout <- pr_layout_seat("wheelchair")
  P <- matrix(10, nrow = 1, ncol = layout$n_sensors)
  trial <- pr_trial(P, time = 0, layout = layout)
  hs <- pr_calc_seat_hotspot(trial, threshold = 1)
  expect_true(all(hs$duration_above_s == 0))
})
