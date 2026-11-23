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

test_that("threshold arguments must be single finite numbers", {
  tr <- pr_example_trial("insole")
  fns <- list(
    pr_calc_peak_pressure, pr_calc_mean_pressure, pr_calc_contact_area,
    pr_calc_loaded_rate, pr_calc_cop, pr_calc_contact_time, pr_calc_cop_path,
    pr_calc_cop_excursion, pr_summary, pr_calc_regional
  )
  msg <- "single finite number"
  # A character threshold used to be compared as text and returned zeros.
  bad <- list("a", NA_real_, c(1, 2), Inf, NULL)
  for (fn in fns) {
    for (value in bad) expect_error(fn(tr, threshold = value), msg)
  }
  # The error names the function the user called.
  err <- tryCatch(pr_calc_peak_pressure(tr, threshold = NA_real_),
    error = identity
  )
  expect_match(deparse(conditionCall(err)), "pr_calc_peak_pressure")
  # Valid thresholds are unchanged, negative values included.
  expect_identical(
    pr_calc_peak_pressure(tr, threshold = 0L), pr_calc_peak_pressure(tr)
  )
  expect_length(pr_calc_contact_area(tr, threshold = -1), tr$n_frames)
})

test_that("gait, hotspot and slip arguments are validated", {
  msg <- "single finite number"
  ins <- pr_example_trial("insole")
  expect_error(pr_calc_gait_cycles(ins, force_threshold = "x"), msg)
  expect_error(pr_calc_gait_cycles(ins, force_threshold = NA_real_), msg)
  expect_error(pr_calc_gait_cycles(ins, min_stance_ms = -5), "non-negative")
  expect_error(pr_calc_gait_cycles(ins, min_swing_ms = c(1, 2)), msg)
  seat <- pr_example_trial("wheelchair")
  expect_error(pr_calc_seat_hotspot(seat, threshold = NA_real_), msg)
  expect_error(pr_calc_seat_hotspot(seat, duration_s = -1), "non-negative")
  sad <- pr_example_trial("saddle_horse")
  expect_error(pr_calc_saddle_slip(sad, slip_threshold = NA_real_), msg)
  expect_error(pr_calc_saddle_slip(sad, slip_threshold = c(1, 2)), msg)
  expect_error(pr_calc_saddle_slip(sad, slip_threshold = -1), "non-negative")
})

test_that("recordings without frames give no hotspots and a clear interpolation error", {
  layout <- pr_layout_seat("wheelchair")
  none <- matrix(numeric(0), 0, layout$n_sensors)
  empty <- pr_trial(none, numeric(0), layout)
  expect_no_warning(hot <- pr_calc_seat_hotspot(empty))
  expect_equal(nrow(hot), 0L)
  expect_error(pr_interpolate(empty), "no frames")
  expect_no_warning(reg <- pr_calc_regional(empty, pr_mask_symmetry(layout)))
  expect_true(all(is.na(reg$mpp)))
})

test_that("contact time sums intervals bounded by two loaded frames", {
  layout <- pr_layout_mat("16")
  pressure <- matrix(0, 6, layout$n_sensors)
  pressure[c(2, 3, 4, 6), 1] <- 10
  times <- c(0, 0.1, 0.2, 0.4, 0.5, 0.6)
  tr <- pr_trial(pressure, time = times, layout = layout)
  # Intervals 2-3 (0.1 s) and 3-4 (0.2 s); frame 6 is loaded alone.
  expect_equal(pr_calc_contact_time(tr), 0.3)
})
