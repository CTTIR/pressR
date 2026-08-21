# Per-sensor and cohort aggregation layer.
#
# Reference values are computed from the definitions by hand in the test
# itself, never by calling the function under test a second way.

# A 2x2 identity-mapped layout: pressure column k is grid cell k in
# column-major order, i.e. (1,1), (2,1), (1,2), (2,2).
sm_layout2 <- function() {
  pr_layout_from_index_map(matrix(1:4, nrow = 2, ncol = 2), name = "sm_2x2")
}

# Four frames, four sensors, one second apart. Chosen so every statistic
# differs between sensors and none of them is symmetric.
sm_pressure <- function() {
  matrix(
    c(
      0, 4, 2, 10,   # frame 1
      0, 4, 6, 10,   # frame 2
      0, 0, 4, 20,   # frame 3
      8, 4, 0, 20    # frame 4
    ),
    nrow = 4, byrow = TRUE
  )
}

sm_trial <- function(P = sm_pressure(), metadata = list()) {
  pr_trial(P, time = seq_len(nrow(P)) - 1, layout = sm_layout2(),
           metadata = metadata)
}

# ---- pr_sensor_map: values -------------------------------------------------

test_that("pr_sensor_map computes each statistic exactly", {
  trial <- sm_trial()
  P <- sm_pressure()

  expect_equal(pr_sensor_map(trial, "mean")$value, c(2, 3, 3, 15))
  expect_equal(pr_sensor_map(trial, "max")$value, c(8, 4, 6, 20))
  expect_equal(
    pr_sensor_map(trial, "sd")$value,
    c(stats::sd(P[, 1]), stats::sd(P[, 2]), stats::sd(P[, 3]),
      stats::sd(P[, 4]))
  )
  # Trapezoid over dt = 1: sum of the three midpoints per sensor.
  expect_equal(pr_sensor_map(trial, "pti")$value, c(4, 8, 11, 45))
  expect_equal(pr_sensor_map(trial, "pct_zero")$value,
               c(0.75, 0.25, 0.25, 0))
})

test_that("pr_sensor_map's max is the maximum pressure picture", {
  trial <- pr_example_trial("saddle_horse", seed = 3)
  expect_equal(
    pr_sensor_map(trial, "max")$value,
    apply(trial$pressure, 2, max)
  )
})

test_that("pr_sensor_map's pti agrees with pr_calc_pti", {
  trial <- pr_example_trial("saddle_horse", seed = 4)
  expect_equal(pr_sensor_map(trial, "pti")$value, pr_calc_pti(trial))
})

test_that("pr_sensor_map returns sensors in layout column-major order", {
  trial <- sm_trial()
  map <- pr_sensor_map(trial, "mean")
  coords <- trial$layout$coords_mm

  expect_identical(map$sensor, as.integer(coords$sensor_id))
  expect_identical(map$row, c(1L, 2L, 1L, 2L))
  expect_identical(map$col, c(1L, 1L, 2L, 2L))
  expect_identical(names(map), c("sensor", "row", "col", "value"))
})

test_that("pr_sensor_map honours threshold", {
  trial <- sm_trial()

  # threshold 4 zeroes every reading at or below 4 before averaging.
  expect_equal(pr_sensor_map(trial, "mean", threshold = 4)$value,
               c(2, 0, 6 / 4, 15))
  # ... and cannot raise a max: sensor 2 tops out at 4, which is masked.
  expect_equal(pr_sensor_map(trial, "max", threshold = 4)$value,
               c(8, 0, 6, 20))
  # pct_zero counts frames at or below the threshold.
  expect_equal(pr_sensor_map(trial, "pct_zero", threshold = 4)$value,
               c(0.75, 1, 0.75, 0))
  # A threshold below every reading changes nothing.
  expect_equal(pr_sensor_map(trial, "mean", threshold = 0)$value,
               pr_sensor_map(trial, "mean")$value)
})

test_that("pr_sensor_map gives NA sd for a single-frame trial", {
  trial <- pr_trial(matrix(c(1, 2, 3, 4), nrow = 1), time = 0,
                    layout = sm_layout2())
  expect_equal(pr_sensor_map(trial, "sd")$value, rep(NA_real_, 4))
  expect_equal(pr_sensor_map(trial, "mean")$value, c(1, 2, 3, 4))
  # A single frame spans no time, so the integral is zero.
  expect_equal(pr_sensor_map(trial, "pti")$value, rep(0, 4))
})

test_that("pr_sensor_map places a single hot device channel correctly", {
  # The negative control for the whole channel map: with only device
  # channel 1 loaded, the peak must land at grid (row 1, col 9) -- the
  # first cell of the right-hand panel -- and nowhere else.
  layout <- pr_layout_saddle_novel()
  raw <- matrix(0, nrow = 3, ncol = 256)
  raw[, 1] <- 42

  trial <- pr_trial(raw[, pr_channel_order(layout), drop = FALSE],
                    time = c(0, 0.02, 0.04), layout = layout)
  map <- pr_sensor_map(trial, "max")

  hot <- map[map$value > 0, ]
  expect_equal(nrow(hot), 1L)
  expect_equal(hot$row, 1L)
  expect_equal(hot$col, 9L)
  expect_equal(hot$value, 42)

  # Channel 9 is its mirror at (row 1, col 8).
  raw9 <- matrix(0, nrow = 3, ncol = 256)
  raw9[, 9] <- 7
  trial9 <- pr_trial(raw9[, pr_channel_order(layout), drop = FALSE],
                     time = c(0, 0.02, 0.04), layout = layout)
  hot9 <- pr_sensor_map(trial9, "max")
  hot9 <- hot9[hot9$value > 0, ]
  expect_equal(c(hot9$row, hot9$col), c(1L, 8L))
})

test_that("pr_sensor_map rejects bad input", {
  trial <- sm_trial()

  expect_error(pr_sensor_map(trial$pressure), class = "rlang_error")
  expect_error(pr_sensor_map(trial, "median"), "must be one of")
  expect_error(pr_sensor_map(trial, c("mean", "max")), "single string")
  expect_error(pr_sensor_map(trial, "mean", threshold = NA),
               "single finite number")
  expect_error(pr_sensor_map(trial, "mean", threshold = c(1, 2)),
               "single finite number")

  empty <- pr_trial(matrix(numeric(0), nrow = 0, ncol = 4),
                    time = numeric(0), layout = sm_layout2())
  expect_error(pr_sensor_map(empty, "mean"), "no frames")
})

# ---- pr_profile_matrix -----------------------------------------------------

test_that("pr_profile_matrix stacks per-sensor statistics", {
  t1 <- sm_trial(metadata = list(trial_id = "a"))
  t2 <- sm_trial(sm_pressure() * 2, metadata = list(trial_id = "b"))
  X <- pr_profile_matrix(pr_dataset(list(t1, t2)), "mean")

  expect_equal(dim(X), c(2L, 4L))
  expect_equal(X[1, ], c(2, 3, 3, 15), ignore_attr = TRUE)
  expect_equal(X[2, ], c(4, 6, 6, 30), ignore_attr = TRUE)
  expect_identical(rownames(X), c("a", "b"))
  expect_identical(colnames(X),
                   c("sensor_1", "sensor_2", "sensor_3", "sensor_4"))
  # Each row is exactly the single-trial map.
  expect_equal(X[2, ], pr_sensor_map(t2, "mean")$value, ignore_attr = TRUE)
})

test_that("pr_profile_matrix passes statistic and threshold through", {
  t1 <- sm_trial(metadata = list(trial_id = "a"))
  ds <- list(t1)

  expect_equal(pr_profile_matrix(ds, "max")[1, ], c(8, 4, 6, 20),
               ignore_attr = TRUE)
  expect_equal(pr_profile_matrix(ds, "pct_zero", threshold = 4)[1, ],
               c(0.75, 1, 0.75, 0), ignore_attr = TRUE)
})

test_that("pr_profile_matrix makes duplicate trial labels unique", {
  t1 <- sm_trial(metadata = list(trial_id = "dup"))
  t2 <- sm_trial(metadata = list(trial_id = "dup"))
  X <- pr_profile_matrix(list(t1, t2))
  expect_identical(rownames(X), c("dup", "dup_1"))

  # With no identifying metadata at all, positional labels are used.
  bare <- pr_trial(sm_pressure(), time = 0:3, layout = sm_layout2())
  expect_identical(rownames(pr_profile_matrix(list(bare))), "trial_1")
})

test_that("pr_profile_matrix rejects incomparable or empty datasets", {
  t1 <- sm_trial()
  wide <- pr_trial(matrix(1, nrow = 2, ncol = 256),
                   time = c(0, 1), layout = pr_layout_saddle_novel())

  expect_error(pr_profile_matrix(list(t1, wide)),
               "same number of sensors")
  expect_error(pr_profile_matrix(list()), "no trials")
  expect_error(pr_profile_matrix(sm_pressure()), "pr_dataset")
  expect_error(pr_profile_matrix(list(t1), "median"), "must be one of")
})

test_that("pr_profile_matrix warns when layouts differ", {
  t1 <- sm_trial()
  other <- pr_trial(sm_pressure(), time = 0:3,
                    layout = pr_layout_from_index_map(
                      matrix(1:4, 2, 2), name = "sm_other"
                    ))
  expect_warning(X <- pr_profile_matrix(list(t1, other)),
                 "different layouts")
  expect_equal(dim(X), c(2L, 4L))
})

# ---- pr_batch_frame_summary ------------------------------------------------

test_that("pr_batch_frame_summary matches the metric definitions", {
  P <- sm_pressure()
  trial <- sm_trial(metadata = list(trial_id = "one"))
  n_sensors <- 4

  fs <- pr_batch_frame_summary(list(trial), meta_fields = character(0))

  frame_mean <- rowSums(P) / n_sensors
  frame_peak <- apply(P, 1, max)
  frame_total <- rowSums(P)
  frame_loaded <- rowSums(P > 0)
  rows <- c(1, 2, 1, 2)
  cols <- c(1, 1, 2, 2)
  cop_row <- as.vector(P %*% rows) / (rowSums(P) + 1e-12)
  cop_col <- as.vector(P %*% cols) / (rowSums(P) + 1e-12)

  expect_equal(nrow(fs), 1L)
  expect_identical(
    names(fs),
    c("mean_kPa_avg", "mean_kPa_sd", "peak_kPa_max", "peak_kPa_avg",
      "total_kPa_avg", "loaded_avg", "cop_row_mean", "cop_col_mean",
      "n_frames")
  )
  expect_equal(fs$mean_kPa_avg, mean(frame_mean))
  expect_equal(fs$mean_kPa_sd, stats::sd(frame_mean))
  expect_equal(fs$peak_kPa_max, max(frame_peak))
  expect_equal(fs$peak_kPa_avg, mean(frame_peak))
  expect_equal(fs$total_kPa_avg, mean(frame_total))
  expect_equal(fs$loaded_avg, mean(frame_loaded))
  expect_equal(fs$cop_row_mean, mean(cop_row))
  expect_equal(fs$cop_col_mean, mean(cop_col))
  expect_identical(fs$n_frames, 4L)

  # mean_kPa_avg is the whole-grid mean, so it scales to the total exactly.
  expect_equal(fs$total_kPa_avg, fs$mean_kPa_avg * n_sensors)
})

test_that("pr_batch_frame_summary keeps one row per trial in order", {
  t1 <- sm_trial(metadata = list(trial_id = "a"))
  t2 <- sm_trial(sm_pressure() * 3, metadata = list(trial_id = "b"))
  fs <- pr_batch_frame_summary(pr_dataset(list(t1, t2)),
                               meta_fields = "trial_id")

  expect_identical(fs$trial_id, c("a", "b"))
  expect_equal(fs$mean_kPa_avg[2], fs$mean_kPa_avg[1] * 3)
  expect_equal(fs$peak_kPa_max, c(20, 60))
  expect_identical(fs$n_frames, c(4L, 4L))
  # COP is scale invariant, so tripling every reading must not move it.
  expect_equal(fs$cop_row_mean[1], fs$cop_row_mean[2])
})

test_that("pr_batch_frame_summary places metadata before the statistics", {
  t1 <- sm_trial(metadata = list(ID = "ID001", Mode = "MS"))
  t2 <- sm_trial(metadata = list(ID = "ID002", Mode = "MH"))
  fs <- pr_batch_frame_summary(list(t1, t2), meta_fields = c("ID", "Mode"))

  expect_identical(names(fs)[1:2], c("ID", "Mode"))
  expect_identical(fs$ID, c("ID001", "ID002"))
  expect_identical(fs$Mode, c("MS", "MH"))
  expect_equal(ncol(fs), 11L)
})

test_that("pr_batch_frame_summary auto-detects usable metadata fields", {
  t1 <- sm_trial(metadata = list(ID = "ID001"))
  t2 <- sm_trial(metadata = list(ID = "ID002"))
  fs <- pr_batch_frame_summary(list(t1, t2))

  expect_true("ID" %in% names(fs))
  # `notes` is NA in both trials (a pr_trial default), so it is dropped.
  expect_false("notes" %in% names(fs))
  # `system` is filled from the layout model, so it survives.
  expect_true("system" %in% names(fs))
})

test_that("pr_batch_frame_summary honours threshold", {
  trial <- sm_trial()
  fs0 <- pr_batch_frame_summary(list(trial), meta_fields = character(0))
  fs4 <- pr_batch_frame_summary(list(trial), threshold = 4,
                                meta_fields = character(0))

  # loaded counts cells strictly above the threshold: with threshold 4 the
  # per-frame counts fall from (3, 3, 2, 3) to (1, 2, 1, 2).
  expect_equal(fs0$loaded_avg, 11 / 4)
  expect_equal(fs4$loaded_avg, 6 / 4)
  # peak and total describe the frame as recorded, so they do not move.
  expect_equal(fs4$peak_kPa_max, fs0$peak_kPa_max)
  expect_equal(fs4$total_kPa_avg, fs0$total_kPa_avg)
})

test_that("pr_batch_frame_summary rejects bad input", {
  trial <- sm_trial(metadata = list(trial_id = "a"))

  expect_error(pr_batch_frame_summary(sm_pressure()), "pr_dataset")
  expect_error(pr_batch_frame_summary(list(trial), meta_fields = "nope"),
               "no trial carries")
  expect_error(
    pr_batch_frame_summary(list(trial), meta_fields = "n_frames"),
    "must not name"
  )
  expect_error(pr_batch_frame_summary(list(trial), threshold = "0"),
               "single finite number")
  expect_error(pr_batch_frame_summary(list(trial), .progress = NA),
               "TRUE")

  empty <- pr_trial(matrix(numeric(0), nrow = 0, ncol = 4),
                    time = numeric(0), layout = sm_layout2(),
                    metadata = list(trial_id = "empty"))
  expect_error(pr_batch_frame_summary(list(empty)), "no frames")
})

test_that("pr_batch_frame_summary agrees with pr_frame_metrics per trial", {
  trials <- list(
    pr_example_trial("saddle_horse", seed = 11),
    pr_example_trial("saddle_horse", seed = 12)
  )
  fs <- pr_batch_frame_summary(trials, meta_fields = character(0))

  for (i in seq_along(trials)) {
    fm <- pr_frame_metrics(trials[[i]])
    expect_equal(fs$mean_kPa_avg[i], mean(fm$mean_kPa))
    expect_equal(fs$peak_kPa_max[i], max(fm$peak_kPa))
    expect_equal(fs$cop_col_mean[i], mean(fm$cop_col))
    expect_identical(fs$n_frames[i], nrow(fm))
  }
})

test_that("pr_batch_frame_summary handles an empty cohort and a progress bar", {
  fs0 <- pr_batch_frame_summary(list())
  expect_equal(nrow(fs0), 0L)
  expect_identical(names(fs0), c(
    "mean_kPa_avg", "mean_kPa_sd", "peak_kPa_max", "peak_kPa_avg",
    "total_kPa_avg", "loaded_avg", "cop_row_mean", "cop_col_mean",
    "n_frames"
  ))
  expect_type(fs0$n_frames, "integer")

  trial <- sm_trial(metadata = list(trial_id = "a"))
  quiet <- pr_batch_frame_summary(list(trial, trial),
                                  meta_fields = character(0))
  noisy <- withr::with_options(
    list(cli.progress_show_after = 1e6),
    pr_batch_frame_summary(list(trial, trial), meta_fields = character(0),
                           .progress = TRUE)
  )
  expect_equal(noisy, quiet)
})
