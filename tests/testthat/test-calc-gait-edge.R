# Edge branches in R/calc-gait.R: too-few frames, no-cycle data,
# and rollover empty returns.

test_that("pr_calc_gait_cycles returns empty for <3 frames", {
  layout <- pr_layout_insole()
  tr <- pr_trial(matrix(500, 2, layout$n_sensors), time = c(0, 0.02),
                 layout = layout)
  cyc <- pr_calc_gait_cycles(tr)
  expect_equal(nrow(cyc), 0L)
})

test_that("pr_calc_gait_cycles returns empty when never loaded", {
  layout <- pr_layout_insole()
  tr <- pr_trial(matrix(0, 50, layout$n_sensors),
                 time = seq(0, by = 0.02, length.out = 50), layout = layout)
  expect_equal(nrow(pr_calc_gait_cycles(tr)), 0L)
})

test_that("pr_calc_gait_cycles detects a sustained stance phase", {
  layout <- pr_layout_insole()
  P <- matrix(0, 50, layout$n_sensors)
  P[10:30, ] <- 800   # high force across the middle
  tr <- pr_trial(P, time = seq(0, by = 0.02, length.out = 50), layout = layout)
  cyc <- pr_calc_gait_cycles(tr, force_threshold = 20)
  expect_true(nrow(cyc) >= 1L)
  expect_true(all(cyc$stance_duration > 0))
})

test_that("pr_calc_rollover returns empty when no cycles", {
  layout <- pr_layout_insole()
  tr <- pr_trial(matrix(0, 50, layout$n_sensors),
                 time = seq(0, by = 0.02, length.out = 50), layout = layout)
  expect_equal(nrow(pr_calc_rollover(tr)), 0L)
})

test_that("pr_calc_rollover resamples each detected cycle", {
  tr <- pr_example_trial("insole")
  cyc <- pr_calc_gait_cycles(tr)
  skip_if(nrow(cyc) == 0L)
  roll <- pr_calc_rollover(tr, cycles = cyc, n_points = 21L)
  expect_equal(sort(unique(roll$percent_stance))[c(1, 21)], c(0, 100))
})
