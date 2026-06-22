# Edge-case branches in R/calc-frame.R: zero-load returns, thresholds,
# single-frame PTI/impulse, contact-time, and COP path/excursion.

zero_trial <- function(frames = 3) {
  layout <- pr_layout_mat("16")
  pr_trial(matrix(0, frames, layout$n_sensors),
           time = seq(0, by = 0.01, length.out = frames), layout = layout)
}

test_that("peak/mean pressure return 0 for fully unloaded frames", {
  tr <- zero_trial()
  expect_equal(pr_calc_peak_pressure(tr), rep(0, 3))
  expect_equal(pr_calc_mean_pressure(tr), rep(0, 3))
})

test_that("threshold excludes low-pressure sensors from peak", {
  layout <- pr_layout_mat("16")
  P <- matrix(0, 1, layout$n_sensors)
  P[1, 1] <- 10; P[1, 2] <- 100
  tr <- pr_trial(P, time = 0, layout = layout)
  expect_equal(pr_calc_peak_pressure(tr, threshold = 50), 100)
})

test_that("loaded rate is a fraction in [0,1]", {
  tr <- pr_example_trial("insole")
  lr <- pr_calc_loaded_rate(tr)
  expect_true(all(lr >= 0 & lr <= 1))
})

test_that("pr_calc_pti returns zeros for a single frame", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(5, 1, layout$n_sensors), time = 0, layout = layout)
  expect_equal(pr_calc_pti(tr), rep(0, layout$n_sensors))
})

test_that("pr_calc_impulse returns 0 for a single frame", {
  layout <- pr_layout_mat("16")
  tr <- pr_trial(matrix(5, 1, layout$n_sensors), time = 0, layout = layout)
  expect_equal(pr_calc_impulse(tr), 0)
})

test_that("pr_calc_contact_time is 0 with no load", {
  expect_equal(pr_calc_contact_time(zero_trial()), 0)
})

test_that("pr_calc_contact_time accumulates loaded duration", {
  layout <- pr_layout_mat("16")
  P <- matrix(0, 4, layout$n_sensors)
  P[2:3, 1] <- 50
  tr <- pr_trial(P, time = c(0, 1, 2, 3), layout = layout)
  expect_true(pr_calc_contact_time(tr) > 0)
})

test_that("pr_calc_cop_path matches the pr_cop path_length", {
  tr <- pr_example_trial("saddle_horse")
  expect_equal(pr_calc_cop_path(tr), pr_calc_cop(tr)$path_length)
})

test_that("pr_calc_cop_excursion returns named ap/ml", {
  tr <- pr_example_trial("saddle_horse")
  exc <- pr_calc_cop_excursion(tr)
  expect_named(exc, c("ap", "ml"))
  expect_true(all(exc >= 0))
})

test_that("pr_calc_cop applies threshold", {
  layout <- pr_layout_mat("16")
  P <- matrix(0, 1, layout$n_sensors)
  P[1, 1] <- 5
  tr <- pr_trial(P, time = 0, layout = layout)
  cop <- pr_calc_cop(tr, threshold = 10)  # 5 < 10 -> no load -> NA
  expect_true(is.na(cop$x[1]))
})
