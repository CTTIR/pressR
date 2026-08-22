# Helpers -------------------------------------------------------------------

# A rectangular layout built exactly the way .layout_build_coords() builds
# one: column-major over which(active).
tp_layout <- function(rows = 4L, cols = 4L) {
  active <- matrix(TRUE, rows, cols)
  idx <- which(active, arr.ind = TRUE)
  coords <- data.frame(
    sensor_id = seq_len(nrow(idx)),
    row = as.integer(idx[, 1]),
    col = as.integer(idx[, 2]),
    x_mm = (idx[, 2] - 1) * 10,
    y_mm = (idx[, 1] - 1) * 10
  )
  pr_layout(
    grid_rows = rows, grid_cols = cols, active = active, coords_mm = coords,
    sensor_area_cm2 = 1, pressure_range = c(0, 63.75),
    name = "tp_test", model = "tp_test"
  )
}

# A trial whose frame TOTAL is exactly `x`: the whole load sits on sensor 1,
# so total == x and every other frame-level signal is a known function of it.
tp_trial <- function(x, fs = 50, layout = tp_layout()) {
  P <- matrix(0, length(x), layout$n_sensors)
  P[, 1] <- x
  pr_trial(P, time = (seq_along(x) - 1) / fs, layout = layout,
           sampling_hz = fs)
}

# A trial whose per-sensor values are supplied directly.
tp_trial_mat <- function(P, fs = 50, layout = tp_layout()) {
  pr_trial(P, time = (seq_len(nrow(P)) - 1) / fs, layout = layout,
           sampling_hz = fs)
}

tp_fixture <- function() {
  pr_read_pliance(test_path("fixtures", "ID052_K_K_KG00_MS.asc"),
                  layout = pr_layout_saddle_novel())
}

# pr_calc_spectrum -----------------------------------------------------------

test_that("pr_calc_spectrum recovers the amplitude of a known sinusoid", {
  fs <- 50
  n <- 100L
  amp <- 2
  f0 <- 5                       # exactly bin k = f0 * n / fs = 10
  tt <- (seq_len(n) - 1) / fs
  trial <- tp_trial(10 + amp * sin(2 * pi * f0 * tt), fs = fs)

  spec <- pr_calc_spectrum(trial, window = "none")

  expect_equal(nrow(spec), n %/% 2 + 1)
  expect_equal(spec$freq_Hz[11], f0)
  expect_equal(which.max(spec$power), 11L)
  # A real sinusoid of amplitude A puts A^2 * n / 4 into its bin.
  expect_equal(spec$power[11], amp^2 * n / 4)
  # Detrending removed the offset of 10 entirely.
  expect_equal(spec$power[1], 0)
  # Every other bin is empty.
  expect_equal(sum(spec$power[-11]), 0)
})

test_that("pr_calc_spectrum without detrending puts the offset at DC", {
  n <- 64L
  trial <- tp_trial(rep(3, n))
  spec <- pr_calc_spectrum(trial, window = "none", detrend = FALSE)

  expect_equal(spec$power[1], n * 3^2)     # (n * c)^2 / n
  expect_equal(spec$power[-1], rep(0, n %/% 2))
})

test_that("pr_calc_spectrum builds the exact frequency axis for odd n", {
  fs <- 50
  n <- 101L
  trial <- tp_trial(seq_len(n) / n, fs = fs)
  spec <- pr_calc_spectrum(trial)

  expect_equal(spec$freq_Hz, (0:50) * fs / n)
  # The highest bin sits just below Nyquist, not on it.
  expect_equal(spec$freq_Hz[51], 50 * fs / n)
  expect_lt(spec$freq_Hz[51], fs / 2)
  # The study's axis, seq(0, fs/2, length.out = length(power)), is a uniform
  # n / (n - 1) stretch of this one and lands on fs / 2.
  study_axis <- seq(0, fs / 2, length.out = nrow(spec))
  expect_equal(study_axis, spec$freq_Hz * n / (n - 1))
  expect_false(isTRUE(all.equal(study_axis, spec$freq_Hz)))
})

test_that("pr_calc_spectrum axes agree with the study's for even n", {
  fs <- 50
  n <- 100L
  trial <- tp_trial(seq_len(n) / n, fs = fs)
  spec <- pr_calc_spectrum(trial)

  expect_equal(spec$freq_Hz, seq(0, fs / 2, length.out = nrow(spec)))
  expect_equal(spec$freq_Hz[nrow(spec)], fs / 2)
})

test_that("pr_calc_spectrum scales 'mean' by n_sensors and 'peak' is its own", {
  tt <- (seq_len(128) - 1) / 50
  trial <- tp_trial(10 + sin(2 * pi * 3 * tt))
  n_sensors <- trial$layout$n_sensors

  total <- pr_calc_spectrum(trial)
  mean_sig <- pr_calc_spectrum(trial, signal = "mean")
  peak_sig <- pr_calc_spectrum(trial, signal = "peak")

  expect_equal(mean_sig$power * n_sensors^2, total$power)
  # All the load is on one sensor here, so the frame peak IS the frame total.
  expect_equal(peak_sig$power, total$power)
  expect_equal(which.max(mean_sig$power), which.max(total$power))
})

test_that("pr_calc_spectrum hann window cuts leakage from an off-bin tone", {
  fs <- 50
  n <- 128L
  tt <- (seq_len(n) - 1) / fs
  # 5.5 bins: deliberately between two bins, so a rectangular window leaks.
  trial <- tp_trial(10 + sin(2 * pi * (5.5 * fs / n) * tt), fs = fs)

  rect <- pr_calc_spectrum(trial, window = "none")
  hann <- pr_calc_spectrum(trial, window = "hann")

  far <- seq(30L, nrow(rect))
  expect_lt(sum(hann$power[far]), sum(rect$power[far]) / 100)
})

test_that("pr_calc_spectrum rejects bad arguments", {
  trial <- tp_trial(sin(seq_len(64)))
  expect_error(pr_calc_spectrum(trial, signal = "median"), "must be one of")
  expect_error(pr_calc_spectrum(trial, window = "hamming"), "must be one of")
  expect_error(pr_calc_spectrum(trial, detrend = NA), "TRUE")
  expect_error(pr_calc_spectrum(tp_trial(1)), "at least two frames")
  expect_error(pr_calc_spectrum(list(pressure = 1)), class = "rlang_error")
})

# pr_calc_dominant_freq ------------------------------------------------------

test_that("pr_calc_dominant_freq ignores a louder out-of-band component", {
  fs <- 50
  n <- 500L
  tt <- (seq_len(n) - 1) / fs
  # 10 Hz at amplitude 5 dwarfs 1 Hz at amplitude 1, but sits out of band.
  trial <- tp_trial(20 + 5 * sin(2 * pi * 10 * tt) + sin(2 * pi * 1 * tt),
                    fs = fs)

  dom <- pr_calc_dominant_freq(trial, band = c(0.3, 5))
  expect_equal(nrow(dom), 1L)
  expect_equal(dom$stride_freq_Hz, 1)

  # Widening the band lets the loud component win.
  wide <- pr_calc_dominant_freq(trial, band = c(0.3, 20))
  expect_equal(wide$stride_freq_Hz, 10)
})

test_that("pr_calc_dominant_freq returns the spectrum's value at that bin", {
  fs <- 50
  tt <- (seq_len(400L) - 1) / fs
  trial <- tp_trial(20 + sin(2 * pi * 1.5 * tt), fs = fs)

  spec <- pr_calc_spectrum(trial)
  dom <- pr_calc_dominant_freq(trial)
  i <- which(spec$freq_Hz == dom$stride_freq_Hz)

  expect_equal(dom$peak_power, spec$power[i])
  expect_equal(dom$peak_power, max(spec$power[spec$freq_Hz >= 0.3 &
                                                spec$freq_Hz <= 5]))
})

test_that("pr_calc_dominant_freq warns and returns NA for an empty band", {
  trial <- tp_trial(sin(seq_len(100L)))     # bin spacing 0.5 Hz
  expect_warning(dom <- pr_calc_dominant_freq(trial, band = c(0.01, 0.02)),
                 "No frequency bin")
  expect_equal(nrow(dom), 1L)
  expect_true(is.na(dom$stride_freq_Hz))
  expect_true(is.na(dom$peak_power))
})

test_that("pr_calc_dominant_freq rejects bad bands", {
  trial <- tp_trial(sin(seq_len(100L)))
  expect_error(pr_calc_dominant_freq(trial, band = 1), "two finite numbers")
  expect_error(pr_calc_dominant_freq(trial, band = c(5, 1)), "increasing")
  expect_error(pr_calc_dominant_freq(trial, band = c(-1, 5)), "below")
  expect_error(pr_calc_dominant_freq(trial, band = c(1, NA)), "finite")
})

# pr_calc_stride_cycles ------------------------------------------------------

test_that("pr_calc_stride_cycles segments a clean 1 Hz oscillation", {
  fs <- 50
  tt <- (seq_len(500L) - 1) / fs        # 10 s
  # A 1 Hz stride riding on a rising baseline the running median removes.
  trial <- tp_trial(30 + 0.5 * tt + 4 * sin(2 * pi * 1 * tt), fs = fs)

  cycles <- pr_calc_stride_cycles(trial)

  expect_equal(nrow(cycles), 9L)
  expect_equal(cycles$cycle, 1:9)
  # Away from the ends, where the moving average runs off the recording,
  # every cycle is exactly one sampling period long.
  expect_equal(cycles$duration_s[4:7], rep(1, 4))
  # The first and last cycles are pulled off by at most one sampling
  # interval on each side, i.e. 0.06 s at 50 Hz.
  expect_true(all(abs(cycles$duration_s - 1) < 0.07))
  expect_equal(cycles$stride_freq, 1 / cycles$duration_s)
  # Cycles tile end to end: each starts where the previous stopped.
  expect_equal(cycles$start_idx[-1], cycles$end_idx[-9])
  expect_equal(cycles$start_s, (cycles$start_idx - 1) / fs)
})

test_that("pr_calc_stride_cycles reproduces the study on the reference file", {
  cycles <- pr_calc_stride_cycles(tp_fixture())

  # Ground truth for ID052_K_K_KG00_MS, first cycle, from the study's
  # strides.rds. The fixture is the first 200 frames of that recording, so
  # only the first cycle is unaffected by the truncated baseline window.
  expect_equal(cycles$cycle[1], 1L)
  expect_equal(cycles$start_idx[1], 3L)
  expect_equal(cycles$end_idx[1], 38L)
  expect_equal(cycles$start_s[1], 0.06)
  expect_equal(cycles$end_s[1], 0.76)
  expect_equal(cycles$duration_s[1], 0.70)
  expect_equal(cycles$peak_total[1], 4.25)
  expect_equal(cycles$stride_freq[1], 1 / 0.70)
})

test_that("pr_calc_stride_cycles gives 'mean' the same cuts as 'total'", {
  fs <- 50
  tt <- (seq_len(400L) - 1) / fs
  trial <- tp_trial(30 + 3 * sin(2 * pi * 1.25 * tt), fs = fs)
  n_sensors <- trial$layout$n_sensors

  total <- pr_calc_stride_cycles(trial)
  avg <- pr_calc_stride_cycles(trial, signal = "mean")

  expect_equal(avg$start_idx, total$start_idx)
  expect_equal(avg$end_idx, total$end_idx)
  expect_equal(avg$peak_total * n_sensors, total$peak_total)
})

test_that("pr_calc_stride_cycles numbers rejected intervals as gaps", {
  fs <- 50
  tt <- (seq_len(700L) - 1) / fs      # 14 s
  # A 1 Hz stride with a 4 s quiet stretch in the middle. The interval that
  # straddles the quiet stretch is longer than max_period_s, so it is
  # dropped -- and its number is left as a hole in the sequence.
  osc <- 4 * sin(2 * pi * tt)
  osc[tt > 4 & tt < 8] <- 0
  trial <- tp_trial(30 + 0.5 * tt + osc, fs = fs)

  cycles <- pr_calc_stride_cycles(trial)

  expect_false(3L %in% cycles$cycle)
  expect_true(all(c(2L, 4L) %in% cycles$cycle))
  expect_equal(max(diff(cycles$cycle)), 2L)
  expect_true(all(cycles$duration_s <= 3))
  # The dropped interval spans the quiet stretch.
  before <- cycles$end_idx[cycles$cycle == 2L]
  after <- cycles$start_idx[cycles$cycle == 4L]
  expect_gt((after - before) / fs, 3)

  # Every 1 s interval is too long for this ceiling, so nothing survives.
  expect_equal(nrow(pr_calc_stride_cycles(trial, max_period_s = 0.4)), 0L)
})

test_that("pr_calc_stride_cycles finds nothing in a flat recording", {
  cycles <- pr_calc_stride_cycles(tp_trial(rep(25, 400L)))

  expect_equal(nrow(cycles), 0L)
  expect_named(cycles, c("cycle", "start_idx", "end_idx", "start_s", "end_s",
                         "duration_s", "peak_total", "stride_freq"))
  expect_type(cycles$start_idx, "integer")
})

test_that("pr_calc_stride_cycles peak_total is an excursion, not a total", {
  fs <- 50
  tt <- (seq_len(500L) - 1) / fs
  trial <- tp_trial(300 + 0.5 * tt + 4 * sin(2 * pi * 1 * tt), fs = fs)

  cycles <- pr_calc_stride_cycles(trial)
  # Frame totals sit near 300; the band-passed excursion is bounded by the
  # 4 kPa oscillation amplitude and nowhere near the total.
  expect_gt(min(pr_calc_total_pressure(trial)), 290)
  expect_true(all(cycles$peak_total < 5))
  expect_gt(max(cycles$peak_total), 3)
})

test_that("pr_calc_stride_cycles rejects bad arguments", {
  trial <- tp_trial(sin(seq_len(200L)))
  expect_error(pr_calc_stride_cycles(trial, lp_window = 0), "whole number")
  expect_error(pr_calc_stride_cycles(trial, lp_window = 2.5), "whole number")
  expect_error(pr_calc_stride_cycles(trial, hp_window_s = 0), "positive")
  expect_error(pr_calc_stride_cycles(trial, min_period_s = -1), "positive")
  expect_error(pr_calc_stride_cycles(trial, max_period_s = 0.1), "must exceed")
  expect_error(pr_calc_stride_cycles(trial, height_quantile = 1), "\\[0, 1\\)")
  expect_error(pr_calc_stride_cycles(trial, signal = "rms"), "must be one of")
  expect_error(pr_calc_stride_cycles("not a trial"), class = "rlang_error")
})

# pr_calc_phase_map ----------------------------------------------------------

test_that("pr_calc_phase_map bins a single cycle by percent of cycle", {
  # 21 frames: percent runs 0, 5, ..., 100, so bin j holds two frames and
  # bin 10 holds three (100% is folded into the last bin).
  P <- matrix(0, 21, 16)
  P[, 1] <- seq_len(21)
  trial <- tp_trial_mat(P)
  cycles <- data.frame(start_idx = 1L, end_idx = 21L)

  pm <- pr_calc_phase_map(trial, cycles = cycles, trim = 0, min_frames = 2L)

  expect_equal(nrow(pm), 10L * 16L)
  s1 <- pm$mean_kPa[pm$sensor == 1L]
  expect_equal(s1[1], mean(c(1, 2)))
  expect_equal(s1[2], mean(c(3, 4)))
  expect_equal(s1[10], mean(c(19, 20, 21)))
  # Sensors carrying nothing stay at zero, not NA.
  expect_equal(pm$mean_kPa[pm$sensor == 2L], rep(0, 10))
})

test_that("pr_calc_phase_map weights every cycle equally", {
  # Cycle A is 11 frames at 1 kPa; cycle B is 101 frames at 3 kPa. Pooling
  # frames would give ~2.8; per-cycle averaging gives exactly 2.
  P <- matrix(0, 112, 16)
  P[1:11, 1] <- 1
  P[12:112, 1] <- 3
  trial <- tp_trial_mat(P)
  cycles <- data.frame(start_idx = c(1L, 12L), end_idx = c(11L, 112L))

  pm <- pr_calc_phase_map(trial, cycles = cycles, trim = 0, min_frames = 2L)
  expect_equal(pm$mean_kPa[pm$sensor == 1L], rep(2, 10))
})

test_that("pr_calc_phase_map trim discards outlying cycles", {
  # Three cycles at 1, 2 and 100 kPa. trim = 0.34 drops one value from each
  # end of the three, leaving the middle cycle alone.
  P <- matrix(0, 33, 16)
  P[1:11, 1] <- 1
  P[12:22, 1] <- 2
  P[23:33, 1] <- 100
  trial <- tp_trial_mat(P)
  cycles <- data.frame(start_idx = c(1L, 12L, 23L), end_idx = c(11L, 22L, 33L))

  plain <- pr_calc_phase_map(trial, cycles = cycles, trim = 0, min_frames = 2L)
  trimmed <- pr_calc_phase_map(trial, cycles = cycles, trim = 0.34,
                               min_frames = 2L)

  expect_equal(plain$mean_kPa[plain$sensor == 1L], rep(103 / 3, 10))
  expect_equal(trimmed$mean_kPa[trimmed$sensor == 1L], rep(2, 10))
})

test_that("pr_calc_phase_map skips cycles below min_frames", {
  P <- matrix(0, 40, 16)
  P[1:5, 1] <- 50        # a 5-frame cycle, too short
  P[6:40, 1] <- 2        # a 35-frame cycle
  trial <- tp_trial_mat(P)
  cycles <- data.frame(start_idx = c(1L, 6L), end_idx = c(5L, 40L))

  pm <- pr_calc_phase_map(trial, cycles = cycles, trim = 0, min_frames = 10L)
  expect_equal(pm$mean_kPa[pm$sensor == 1L], rep(2, 10))

  expect_warning(
    empty <- pr_calc_phase_map(trial, cycles = cycles, min_frames = 100L),
    "No cycle has at least"
  )
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c("phase_bin", "sensor", "row", "col", "mean_kPa"))
})

test_that("pr_calc_phase_map carries the layout's sensor coordinates", {
  trial <- tp_fixture()
  pm <- pr_calc_phase_map(trial, n_bins = 4L)
  coords <- trial$layout$coords_mm

  expect_equal(nrow(pm), 4L * trial$n_sensors)
  expect_equal(sort(unique(pm$phase_bin)), 1:4)
  expect_equal(pm$sensor[pm$phase_bin == 1L], as.integer(coords$sensor_id))
  expect_equal(pm$row[pm$phase_bin == 1L], as.integer(coords$row))
  expect_equal(pm$col[pm$phase_bin == 1L], as.integer(coords$col))
  # Channel 1 of this device sits at grid (1, 9); the layout is column-major,
  # so pressure column 129 is that cell.
  expect_equal(pm$row[129], 1L)
  expect_equal(pm$col[129], 9L)
  # Nothing may exceed the hardware ceiling.
  expect_lte(max(pm$mean_kPa, na.rm = TRUE), 63.75)
})

test_that("pr_calc_phase_map rejects bad arguments", {
  trial <- tp_trial_mat(matrix(1, 40, 16))
  good <- data.frame(start_idx = 1L, end_idx = 40L)

  expect_error(pr_calc_phase_map(trial, good, n_bins = 0), "whole number")
  expect_error(pr_calc_phase_map(trial, good, trim = 0.5), "\\[0, 0.5\\)")
  expect_error(pr_calc_phase_map(trial, good, trim = -0.1), "\\[0, 0.5\\)")
  expect_error(pr_calc_phase_map(trial, good, min_frames = 1L), "at least 2")
  expect_error(pr_calc_phase_map(trial, data.frame(a = 1)), "missing column")
  expect_error(
    pr_calc_phase_map(trial, data.frame(start_idx = 1, end_idx = 99)),
    "outside the trial"
  )
  expect_error(pr_calc_phase_map(trial, data.frame(start_idx = 9, end_idx = 9)),
               "greater than")
  expect_error(pr_calc_phase_map(trial, "cycles"), "must be a data frame")
})

# pr_cop_shape ---------------------------------------------------------------

test_that("pr_cop_shape measures an open square path", {
  square <- data.frame(x = c(0, 1, 1, 0), y = c(0, 0, 1, 1))
  shape <- pr_cop_shape(square)

  expect_equal(shape$n_points, 4L)
  expect_equal(shape$path_length, 3)
  expect_equal(shape$closure_dist, 1)
  expect_equal(shape$closure_ratio, 1 / 3)
  expect_false(shape$self_intersects)
  expect_equal(shape$n_crossings, 0L)
})

test_that("pr_cop_shape counts a bow tie only once it is closed", {
  bow <- data.frame(x = c(0, 1, 0, 1), y = c(0, 0, 1, 1))

  closed <- pr_cop_shape(bow, close = TRUE)
  expect_equal(closed$n_crossings, 1L)
  expect_true(closed$self_intersects)

  # As travelled the path has three segments; the two non-adjacent ones are
  # parallel, so nothing crosses until the closing chord is added.
  open <- pr_cop_shape(bow, close = FALSE)
  expect_equal(open$n_crossings, 0L)
  expect_false(open$self_intersects)
  # Closing changes only the crossings, never the measured path.
  expect_equal(open$path_length, closed$path_length)
  expect_equal(open$closure_dist, closed$closure_dist)
})

test_that("pr_cop_shape counts a figure eight and a pentagram", {
  # 61 intervals, so no sample lands exactly on the crossing at the origin:
  # the two lobes cross transversally, once.
  ang <- seq(0, 2 * pi, length.out = 62)[-62]
  eight <- data.frame(x = sin(2 * ang), y = sin(ang))
  expect_equal(pr_cop_shape(eight, close = FALSE)$n_crossings, 1L)

  # A pentagram: all five non-adjacent segment pairs cross once the loop is
  # closed, and three of them do before the closing chord is added.
  a <- (90 + c(0, 144, 288, 432, 576)) * pi / 180
  star <- data.frame(x = cos(a), y = sin(a))
  expect_equal(pr_cop_shape(star)$n_crossings, 5L)
  expect_equal(pr_cop_shape(star, close = FALSE)$n_crossings, 3L)
})

test_that("pr_cop_shape reports a trajectory that ends where it began", {
  loop <- data.frame(x = c(0, 1, 1, 0, 0), y = c(0, 0, 1, 1, 0))
  shape <- pr_cop_shape(loop)

  expect_equal(shape$n_points, 5L)
  expect_equal(shape$path_length, 4)
  expect_equal(shape$closure_dist, 0)
  expect_equal(shape$n_crossings, 0L)
  still <- pr_cop_shape(data.frame(x = c(1, 1), y = c(2, 2)))
  expect_true(is.na(still$closure_ratio))
})

test_that("pr_cop_shape accepts pr_cop objects and grid-index columns", {
  from_cop <- pr_cop(x = c(0, 3, 3), y = c(0, 0, 4), time = c(0, 1, 2))
  expect_equal(pr_cop_shape(from_cop)$path_length, 7)
  expect_equal(pr_cop_shape(from_cop)$closure_dist, 5)

  # cop_col is x, cop_row is y.
  grid <- data.frame(cop_row = c(0, 0), cop_col = c(0, 3))
  expect_equal(pr_cop_shape(grid)$path_length, 3)

  # Same trajectory, both spellings.
  xy <- data.frame(x = c(0, 3), y = c(0, 0))
  expect_equal(pr_cop_shape(grid), pr_cop_shape(xy))
})

test_that("pr_cop_shape drops incomplete coordinate pairs", {
  gappy <- data.frame(x = c(0, NA, 3, 3), y = c(0, 1, NA, 4))
  shape <- pr_cop_shape(gappy)

  expect_equal(shape$n_points, 2L)
  expect_equal(shape$path_length, 5)      # (0,0) -> (3,4)
  expect_equal(shape$closure_dist, 5)
})

test_that("pr_cop_shape works on a real stride's centre of pressure", {
  trial <- tp_fixture()
  cop <- pr_calc_cop_grid(trial)
  cycles <- pr_calc_stride_cycles(trial)
  seg <- cop[cycles$start_idx[1]:cycles$end_idx[1], ]

  shape <- pr_cop_shape(seg)
  expect_equal(shape$n_points, 36L)       # frames 3:38 inclusive
  # The COP stays inside the 16 x 16 grid, so no distance can exceed its
  # diagonal.
  expect_lt(shape$closure_dist, sqrt(2) * 15)
  expect_true(shape$closure_ratio > 0 && shape$closure_ratio < 1)
})

test_that("pr_cop_shape rejects unusable input", {
  expect_error(pr_cop_shape(data.frame(a = 1, b = 2)), "must be a")
  expect_error(pr_cop_shape(data.frame(x = NA_real_, y = NA_real_)),
               "no complete coordinate pairs")
  expect_error(pr_cop_shape(data.frame(x = 1, y = 1), close = "yes"), "TRUE")
  expect_error(pr_cop_shape(list(x = c(1, 2), y = 1)), "y-coordinate")
})
