# Branch coverage for R/calc-saddle.R: print methods, bridge edge cases,
# slip dominance arms, and the symmetry-mask error.

test_that("print methods for saddle results are invisible", {
  tr <- pr_example_trial("saddle_horse")
  expect_invisible(print(pr_calc_saddle_bridge(tr)))
  expect_invisible(print(pr_calc_saddle_slip(tr)))
})

test_that("pr_calc_saddle_bridge flags bridging on a hollow-middle trial", {
  layout <- pr_layout_saddle("horse")
  masks <- pr_mask_saddle_6(layout)
  P <- matrix(0, 5, layout$n_sensors)
  # load cranial and caudal columns heavily, leave middle empty
  cranial <- c(masks$cranial_left$sensor_cols, masks$cranial_right$sensor_cols)
  caudal  <- c(masks$caudal_left$sensor_cols, masks$caudal_right$sensor_cols)
  P[, cranial] <- 80
  P[, caudal]  <- 80
  tr <- pr_trial(P, time = seq(0, by = 0.02, length.out = 5), layout = layout)
  res <- pr_calc_saddle_bridge(tr, masks)
  expect_true(res$is_bridged)
  expect_match(res$recommendation, "Bridging")
})

test_that("pr_calc_saddle_bridge reports continuous when not bridged", {
  tr <- pr_example_trial("saddle_horse")
  res <- pr_calc_saddle_bridge(tr, bridge_threshold = 0)  # never bridged
  expect_false(res$is_bridged)
  expect_match(res$recommendation, "continuous")
})

test_that("pr_calc_saddle_slip detects a left-dominant trial", {
  layout <- pr_layout_saddle("horse")
  sym <- pr_mask_symmetry(layout, "vertical")
  P <- matrix(0, 5, layout$n_sensors)
  P[, sym$left$sensor_cols]  <- 80
  P[, sym$right$sensor_cols] <- 5
  tr <- pr_trial(P, time = seq(0, by = 0.02, length.out = 5), layout = layout)
  res <- pr_calc_saddle_slip(tr, sym, slip_threshold = 10)
  expect_equal(res$dominant_side, "left")
  expect_true(res$is_asymmetric)
})

test_that("pr_calc_saddle_slip errors on non-left/right masks", {
  tr <- pr_example_trial("saddle_horse")
  bad <- pr_mask_saddle_6(tr$layout)  # named cranial_left etc, no 'left'
  expect_error(pr_calc_saddle_slip(tr, masks = bad))
})
