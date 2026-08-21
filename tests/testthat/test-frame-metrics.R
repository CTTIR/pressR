# Helpers -------------------------------------------------------------------

# A rectangular layout whose coords are built exactly the way
# .layout_build_coords() builds them: column-major over which(active).
fm_layout <- function(rows = 4L, cols = 4L, active = NULL) {
  if (is.null(active)) active <- matrix(TRUE, rows, cols)
  idx <- which(active, arr.ind = TRUE)
  coords <- data.frame(
    sensor_id = seq_len(nrow(idx)),
    row = as.integer(idx[, 1]),
    col = as.integer(idx[, 2]),
    x_mm = (idx[, 2] - 1) * 10,
    y_mm = (idx[, 1] - 1) * 10
  )
  pr_layout(
    grid_rows = nrow(active), grid_cols = ncol(active),
    active = active, coords_mm = coords,
    sensor_area_cm2 = 1, pressure_range = c(0, 63.75),
    name = "fm_test", model = "fm_test"
  )
}

fm_trial <- function(P, layout = NULL) {
  if (is.null(layout)) layout <- fm_layout()
  pr_trial(P, time = seq_len(nrow(P)) / 50, layout = layout)
}

# The Novel/Pliance two-panel channel map: channel 1 sits at grid (1, 9).
fm_novel_map <- function() {
  left <- matrix(0L, 16, 16)
  id <- 9L
  for (i in 1:16) {
    left[i, 1:8] <- seq.int(id + 7L, id, by = -1L)
    id <- id + 16L
  }
  id <- 1L
  for (i in 1:16) {
    left[i, 9:16] <- seq.int(id, id + 7L)
    id <- id + 16L
  }
  left
}

# pr_calc_mean_pressure_grid -------------------------------------------------

test_that("pr_calc_mean_pressure_grid divides by the whole grid", {
  P <- matrix(0, 3, 16)
  P[1, 1] <- 16      # one cell at 16 kPa
  P[2, 1:4] <- 8     # four cells at 8 kPa
  # frame 3 stays empty
  trial <- fm_trial(P)

  expect_equal(pr_calc_mean_pressure_grid(trial), c(1, 2, 0))
  # The frozen loaded-cells-only function is a different quantity:
  expect_equal(pr_calc_mean_pressure(trial), c(16, 8, 0))
})

test_that("pr_calc_mean_pressure_grid is ~25x smaller on a sparse mat", {
  set.seed(11)
  P <- matrix(0, 20, 256)
  hot <- sample(256, 10)                       # 10 of 256 cells loaded
  P[, hot] <- 25
  trial <- fm_trial(P, fm_layout(16L, 16L))

  expect_equal(mean(pr_calc_mean_pressure_grid(trial)), 25 * 10 / 256)
  expect_equal(
    mean(pr_calc_mean_pressure(trial)) / mean(pr_calc_mean_pressure_grid(trial)),
    256 / 10
  )
})

test_that("pr_calc_mean_pressure_grid rejects non-trials", {
  expect_error(pr_calc_mean_pressure_grid(matrix(1, 2, 16)), "pr_trial")
  expect_error(pr_calc_mean_pressure_grid("not a trial"), "pr_trial")
})

# pr_calc_total_pressure -----------------------------------------------------

test_that("pr_calc_total_pressure sums each frame without scaling", {
  P <- rbind(c(1, 2, 3, 4), c(0, 0, 0, 0), c(10, 0, 0, 0.5))
  trial <- fm_trial(P, fm_layout(2L, 2L))

  expect_equal(pr_calc_total_pressure(trial), c(10, 0, 10.5))
  # No area conversion: the value is NOT the force in Newtons.
  expect_false(isTRUE(all.equal(
    pr_calc_total_pressure(trial), pr_calc_force(trial)
  )))
})

test_that("pr_calc_total_pressure rejects non-trials", {
  expect_error(pr_calc_total_pressure(list(pressure = matrix(1))), "pr_trial")
})

# pr_calc_loaded_count -------------------------------------------------------

test_that("pr_calc_loaded_count counts cells strictly above threshold", {
  P <- rbind(c(0, 1, 2, 3), c(0, 0, 0, 0), c(5, 5, 5, 5))
  trial <- fm_trial(P, fm_layout(2L, 2L))

  expect_identical(pr_calc_loaded_count(trial), c(3L, 0L, 4L))
  expect_identical(pr_calc_loaded_count(trial, threshold = 2), c(1L, 0L, 4L))
  expect_identical(pr_calc_loaded_count(trial, threshold = 5), c(0L, 0L, 0L))
  expect_type(pr_calc_loaded_count(trial), "integer")
})

test_that("pr_calc_loaded_count rejects a bad threshold", {
  trial <- fm_trial(matrix(1, 2, 16))
  expect_error(pr_calc_loaded_count(trial, threshold = c(1, 2)), "threshold")
  expect_error(pr_calc_loaded_count(trial, threshold = NA_real_), "threshold")
  expect_error(pr_calc_loaded_count(trial, threshold = "0"), "threshold")
})

# pr_calc_cop_grid -----------------------------------------------------------

test_that("pr_calc_cop_grid returns the centroid in grid indices", {
  P <- matrix(0, 4, 16)
  P[1, 11] <- 5                 # column-major cell 11 = grid (row 3, col 3)
  P[2, c(1, 16)] <- 1           # (1,1) and (16,16) of a 4x4 -> (2.5, 2.5)
  P[3, 1] <- 3                  # grid (1, 1)
  # frame 4 unloaded
  trial <- fm_trial(P)
  cop <- pr_calc_cop_grid(trial)

  expect_s3_class(cop, "tbl_df")
  expect_identical(names(cop), c("frame", "time_s", "cop_row", "cop_col"))
  expect_equal(cop$cop_row, c(3, 2.5, 1, 0))
  expect_equal(cop$cop_col, c(3, 2.5, 1, 0))
  expect_identical(cop$frame, 1:4)
  expect_equal(cop$time_s, trial$time)
})

test_that("pr_calc_cop_grid gives ~0 rather than NA for an unloaded frame", {
  trial <- fm_trial(matrix(0, 2, 16))
  cop <- pr_calc_cop_grid(trial)

  expect_false(anyNA(cop$cop_row))
  expect_false(anyNA(cop$cop_col))
  expect_equal(cop$cop_row, c(0, 0))
  # pr_calc_cop(), the millimetre version, returns NA for the same frames.
  expect_true(all(is.na(pr_calc_cop(trial)$x)))
})

test_that("pr_calc_cop_grid honours threshold in the weighting", {
  P <- matrix(0, 1, 16)
  P[1, 1] <- 10     # grid (1, 1)
  P[1, 16] <- 2     # grid (4, 4)
  trial <- fm_trial(P)

  expect_equal(pr_calc_cop_grid(trial)$cop_row, (10 * 1 + 2 * 4) / 12)
  # Dropping the light cell moves the centroid onto the heavy one:
  expect_equal(pr_calc_cop_grid(trial, threshold = 5)$cop_row, 1)
})

test_that("pr_calc_cop_grid follows the layout under a sparse active mask", {
  active <- matrix(FALSE, 4, 4)
  active[2, 3] <- TRUE
  active[4, 1] <- TRUE
  layout <- fm_layout(active = active)
  # which(active) is column-major: (4,1) comes first, then (2,3).
  expect_equal(layout$coords_mm$row, c(4L, 2L))
  expect_equal(layout$coords_mm$col, c(1L, 3L))

  P <- rbind(c(1, 0), c(0, 1))
  cop <- pr_calc_cop_grid(fm_trial(P, layout))
  expect_equal(cop$cop_row, c(4, 2))
  expect_equal(cop$cop_col, c(1, 3))
})

test_that("pr_calc_cop_grid is correct under the Novel channel permutation", {
  # Negative control: exactly one raw device channel is hot. After the
  # documented permutation the centroid must land on that channel's grid cell.
  cmap <- fm_novel_map()
  layout <- fm_layout(16L, 16L)
  perm <- as.vector(cmap)

  # Channel 1 is specified to sit at grid (row 1, col 9).
  raw <- matrix(0, 1, 256)
  raw[1, 1] <- 40
  cop <- pr_calc_cop_grid(fm_trial(raw[, perm, drop = FALSE], layout))
  expect_equal(cop$cop_row, 1)
  expect_equal(cop$cop_col, 9)

  # Channel 9 is specified to sit at grid (row 1, col 8).
  raw9 <- matrix(0, 1, 256)
  raw9[1, 9] <- 40
  cop9 <- pr_calc_cop_grid(fm_trial(raw9[, perm, drop = FALSE], layout))
  expect_equal(cop9$cop_row, 1)
  expect_equal(cop9$cop_col, 8)

  # And every single-hot channel lands where the map says it does.
  hits <- vapply(seq_len(256), function(ch) {
    r <- matrix(0, 1, 256)
    r[1, ch] <- 1
    cg <- pr_calc_cop_grid(fm_trial(r[, perm, drop = FALSE], layout))
    cell <- which(cmap == ch, arr.ind = TRUE)
    isTRUE(all.equal(
      c(cg$cop_row, cg$cop_col), c(cell[1, 1], cell[1, 2]),
      check.attributes = FALSE
    ))
  }, logical(1))
  expect_true(all(hits))

  # Without the permutation the same channel lands somewhere else, so this
  # test would not pass by accident.
  wrong <- pr_calc_cop_grid(fm_trial(raw, layout))
  expect_false(isTRUE(all.equal(c(wrong$cop_row, wrong$cop_col), c(1, 9))))
})

test_that("pr_calc_cop_grid rejects a bad eps", {
  trial <- fm_trial(matrix(1, 2, 16))
  expect_error(pr_calc_cop_grid(trial, eps = -1), "eps")
  expect_error(pr_calc_cop_grid(trial, eps = Inf), "eps")
  expect_error(pr_calc_cop_grid("trial"), "pr_trial")
})

# pr_frame_metrics -----------------------------------------------------------

test_that("pr_frame_metrics returns the documented columns and values", {
  P <- matrix(0, 3, 16)
  P[1, 1] <- 16
  P[2, c(1, 16)] <- c(6, 2)
  trial <- fm_trial(P)
  fm <- pr_frame_metrics(trial)

  expect_s3_class(fm, "tbl_df")
  expect_identical(
    names(fm),
    c("frame", "time_s", "mean_kPa", "peak_kPa", "total_kPa", "loaded",
      "cop_row", "cop_col")
  )
  expect_identical(nrow(fm), 3L)
  expect_identical(fm$frame, 1:3)
  expect_type(fm$loaded, "integer")

  expect_equal(fm$total_kPa, c(16, 8, 0))
  expect_equal(fm$mean_kPa, c(1, 0.5, 0))
  expect_equal(fm$peak_kPa, c(16, 6, 0))
  expect_identical(fm$loaded, c(1L, 2L, 0L))
  expect_equal(fm$cop_row, c(1, (6 * 1 + 2 * 4) / 8, 0))
  expect_equal(fm$cop_col, c(1, (6 * 1 + 2 * 4) / 8, 0))
})

test_that("pr_frame_metrics agrees with the single-metric functions", {
  trial <- pr_example_trial("saddle_horse")
  fm <- pr_frame_metrics(trial)
  cop <- pr_calc_cop_grid(trial)

  expect_equal(fm$mean_kPa, pr_calc_mean_pressure_grid(trial))
  expect_equal(fm$total_kPa, pr_calc_total_pressure(trial))
  expect_identical(fm$loaded, pr_calc_loaded_count(trial))
  expect_equal(fm$cop_row, cop$cop_row)
  expect_equal(fm$cop_col, cop$cop_col)
  # peak is the plain row maximum
  expect_equal(fm$peak_kPa, apply(trial$pressure, 1, max))
  expect_equal(fm$mean_kPa, fm$total_kPa / trial$layout$n_sensors)
})

test_that("pr_frame_metrics threshold touches loaded and COP only", {
  P <- matrix(0, 2, 16)
  P[1, 1] <- 10
  P[1, 16] <- 2
  P[2, ] <- 1
  trial <- fm_trial(P)
  a <- pr_frame_metrics(trial)
  b <- pr_frame_metrics(trial, threshold = 5)

  expect_equal(a$peak_kPa, b$peak_kPa)
  expect_equal(a$total_kPa, b$total_kPa)
  expect_equal(a$mean_kPa, b$mean_kPa)
  expect_identical(b$loaded, c(1L, 0L))
  expect_equal(b$cop_row, c(1, 0))
  expect_false(isTRUE(all.equal(a$cop_row, b$cop_row)))
})

test_that("pr_frame_metrics handles negative readings and empty trials", {
  P <- matrix(0, 1, 16)
  P[1, 1] <- 10
  P[1, 2] <- -4          # a negative reading must not pull the centroid
  trial <- fm_trial(P)
  fm <- pr_frame_metrics(trial)

  expect_equal(fm$cop_row, 1)
  expect_equal(fm$cop_col, 1)
  expect_equal(fm$total_kPa, 6)      # total is the frame as recorded
  expect_identical(fm$loaded, 1L)

  empty <- pr_trial(matrix(0, 0, 16), time = numeric(0), layout = fm_layout())
  fe <- pr_frame_metrics(empty)
  expect_identical(nrow(fe), 0L)
  expect_type(fe$peak_kPa, "double")
})

test_that("pr_frame_metrics rejects bad arguments", {
  trial <- fm_trial(matrix(1, 2, 16))
  expect_error(pr_frame_metrics(trial$pressure), "pr_trial")
  expect_error(pr_frame_metrics(trial, threshold = NULL), "threshold")
  expect_error(pr_frame_metrics(trial, eps = -1e-9), "eps")
})

# pr_calc_pci ----------------------------------------------------------------

test_that("pr_calc_pci is the ratio of the two per-recording averages", {
  P <- matrix(0, 2, 16)
  P[1, 1] <- 16          # grid mean 1, peak 16
  P[2, 1:2] <- 8         # grid mean 1, peak 8
  trial <- fm_trial(P)

  # mean(peak) = 12, mean(grid mean) = 1
  expect_equal(pr_calc_pci(trial), 12, tolerance = 1e-9)
  # loaded-cells-only denominator: mean(c(16, 8)) = 12 -> PCI 1
  expect_equal(pr_calc_pci(trial, denominator = "loaded"), 1, tolerance = 1e-9)
})

test_that("pr_calc_pci equals peak_kPa_avg / mean_kPa_avg from the frame table", {
  trial <- pr_example_trial("saddle_horse")
  fm <- pr_frame_metrics(trial)

  expect_equal(
    pr_calc_pci(trial),
    mean(fm$peak_kPa) / mean(fm$mean_kPa),
    tolerance = 1e-9
  )
  # It is a ratio of averages, not the average of the per-frame ratio.
  expect_false(isTRUE(all.equal(
    pr_calc_pci(trial), mean(fm$peak_kPa / fm$mean_kPa)
  )))
  # Sparse mat: the loaded-only denominator is larger, so PCI is smaller.
  expect_lt(pr_calc_pci(trial, denominator = "loaded"), pr_calc_pci(trial))
})

test_that("pr_calc_pci is 1 for a uniformly loaded mat and 0 for an empty one", {
  uniform <- fm_trial(matrix(7, 4, 16))
  expect_equal(pr_calc_pci(uniform), 1, tolerance = 1e-9)
  expect_equal(pr_calc_pci(uniform, denominator = "loaded"), 1, tolerance = 1e-9)

  empty <- fm_trial(matrix(0, 4, 16))
  expect_equal(pr_calc_pci(empty), 0)
})

test_that("pr_calc_pci rejects bad arguments", {
  trial <- fm_trial(matrix(1, 2, 16))
  expect_error(pr_calc_pci(trial, denominator = "whole"), "should be one of")
  expect_error(pr_calc_pci(trial, eps = -1), "eps")
  expect_error(pr_calc_pci(list()), "pr_trial")
  no_frames <- pr_trial(matrix(0, 0, 16), numeric(0), fm_layout())
  expect_error(pr_calc_pci(no_frames), "no frames")
})

# pr_ref_pci -----------------------------------------------------------------

test_that("pr_ref_pci documents four contiguous bands", {
  ref <- pr_ref_pci()

  expect_s3_class(ref, "tbl_df")
  expect_true(all(
    c("region", "parameter", "threshold", "unit", "interpretation", "source")
    %in% names(ref)
  ))
  # Same leading columns as the other reference tables.
  expect_identical(
    names(ref)[1:6], names(pr_ref_saddle())[1:6]
  )
  expect_identical(nrow(ref), 4L)
  expect_identical(ref$band, c("good", "moderate", "poor", "very poor"))
  expect_equal(ref$band_min, c(3, 6, 10, 20))
  expect_equal(ref$band_max, c(6, 10, 20, Inf))
  expect_equal(ref$threshold, ref$band_min)
  # Contiguous, non-overlapping, open-topped.
  expect_equal(ref$band_max[-4], ref$band_min[-1])
  expect_true(is.infinite(ref$band_max[4]))
  expect_true(all(ref$parameter == "pci"))
  expect_true(all(ref$unit == "ratio"))
})

test_that("pr_ref_pci classifies a value into exactly one band", {
  ref <- pr_ref_pci()
  band_of <- function(x) ref$band[x >= ref$band_min & x < ref$band_max]

  expect_identical(band_of(4), "good")
  expect_identical(band_of(6), "moderate")
  expect_identical(band_of(9.99), "moderate")
  expect_identical(band_of(15), "poor")
  expect_identical(band_of(1e6), "very poor")
  expect_length(band_of(2), 0L)     # below the documented range
})

test_that("pr_ref_pci takes no arguments", {
  expect_error(pr_ref_pci("grid"), "unused argument")
})
