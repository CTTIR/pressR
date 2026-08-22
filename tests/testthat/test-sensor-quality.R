# Hardware quality control and spatial gradients.
#
# Every expected value here is written out from the definition -- by hand,
# or by an explicit loop over the definition -- never by calling the
# function under test a second way.

# ---- fixtures --------------------------------------------------------------

# A 2x2 identity-mapped layout with a declared 10 kPa ceiling, so the
# saturation flag has something to derive from. Pressure column k is grid
# cell k in column-major order: (1,1), (2,1), (1,2), (2,2).
sq_layout2 <- function(pressure_range = c(0, 10)) {
  pr_layout_from_index_map(matrix(1:4, nrow = 2, ncol = 2),
                           name = "sq_2x2", pressure_range = pressure_range)
}

# Two four-frame recordings on that mat, chosen so no sensor has the same
# value for any two of the four cohort statistics.
sq_pressure_a <- function() {
  cbind(c(0, 0, 0, 0), c(2, 4, 6, 8), c(0, 0, 0, 10), c(1, 1, 1, 1))
}
sq_pressure_b <- function() {
  cbind(c(0, 0, 0, 1), c(4, 4, 4, 4), c(0, 0, 0, 0), c(3, 3, 3, 9))
}

sq_trial <- function(P, id = "a") {
  pr_trial(P, time = seq_len(nrow(P)) - 1, layout = sq_layout2(),
           metadata = list(trial_id = id))
}

sq_cohort <- function() {
  pr_dataset(list(sq_trial(sq_pressure_a(), "a"),
                  sq_trial(sq_pressure_b(), "b")))
}

# An n x n identity-mapped layout: grid cell k in column-major order is
# channel k, so a pressure matrix is already in grid order.
sq_layout_n <- function(n, index = matrix(seq_len(n * n), n, n)) {
  pr_layout_from_index_map(index, name = paste0("sq_", n, "x", n),
                           pressure_range = c(0, 100))
}

# A two-frame trial whose per-sensor mean map is the field f(row, col).
sq_field_trial <- function(layout, f) {
  coords <- layout$coords_mm
  v <- f(coords$row, coords$col)
  P <- rbind(v, v)
  pr_trial(P, time = c(0, 1), layout = layout)
}

# Central-difference gradient magnitude, straight from the definition, with
# an explicit loop. The reference the vectorised implementation must match.
sq_ref_gradient <- function(M, edge = NA_real_) {
  nr <- nrow(M)
  nc <- ncol(M)
  G <- matrix(edge, nr, nc)
  if (nr >= 3L && nc >= 3L) {
    for (r in 2:(nr - 1L)) {
      for (cc in 2:(nc - 1L)) {
        dr <- (M[r + 1L, cc] - M[r - 1L, cc]) / 2
        dc <- (M[r, cc + 1L] - M[r, cc - 1L]) / 2
        G[r, cc] <- sqrt(dr^2 + dc^2)
      }
    }
  }
  G
}

sq_fixture_trial <- function() {
  pr_read_pliance(test_path("fixtures", "ID052_K_K_KG00_MS.asc"),
                  layout = pr_layout_saddle_novel())
}

# ---- pr_sensor_quality: values ---------------------------------------------

test_that("pr_sensor_quality computes each cohort column exactly", {
  q <- pr_sensor_quality(sq_cohort())

  expect_identical(
    names(q),
    c("sensor", "row", "col", "mean_across_files", "sd_across_files",
      "max_across_files", "pct_zero_mean", "n_files", "flag")
  )
  expect_identical(nrow(q), 4L)

  # mean over files of the per-file per-sensor mean.
  expect_equal(q$mean_across_files, c(0.125, 4.5, 1.25, 2.75))

  # mean over files of the WITHIN-file sd. Written out per file:
  #   sensor 1: sd(0,0,0,0) = 0        and sd(0,0,0,1) = 0.5
  #   sensor 2: sd(2,4,6,8) = 2.581989 and sd(4,4,4,4) = 0
  #   sensor 3: sd(0,0,0,10) = 5       and sd(0,0,0,0) = 0
  #   sensor 4: sd(1,1,1,1) = 0        and sd(3,3,3,9) = 3
  expect_equal(
    q$sd_across_files,
    c((0 + 0.5) / 2,
      (stats::sd(c(2, 4, 6, 8)) + 0) / 2,
      (5 + 0) / 2,
      (0 + 3) / 2)
  )

  expect_equal(q$max_across_files, c(1, 8, 10, 9))
  # Percentage, not a fraction: sensor 1 is zero in 4/4 then 3/4 frames.
  expect_equal(q$pct_zero_mean, c(87.5, 0, 87.5, 0))
  expect_identical(q$n_files, rep(2L, 4))
})

test_that("pr_sensor_quality's sd column is not the sd of the file means", {
  # The distinction the documentation makes, pinned. Sensor 2 reads
  # 2,4,6,8 in one file and a flat 4 in the other: its within-file spread
  # averages 1.29, while the spread of its two file means is only 0.71.
  q <- pr_sensor_quality(sq_cohort())
  between <- stats::sd(c(5, 4))

  expect_equal(q$sd_across_files[2], stats::sd(c(2, 4, 6, 8)) / 2)
  expect_false(isTRUE(all.equal(q$sd_across_files[2], between)))
  expect_gt(q$sd_across_files[2], between)
})

test_that("pr_sensor_quality places sensors in layout grid order", {
  q <- pr_sensor_quality(sq_cohort())
  expect_identical(q$sensor, 1:4)
  expect_identical(q$row, c(1L, 2L, 1L, 2L))
  expect_identical(q$col, c(1L, 1L, 2L, 2L))
})

test_that("pr_sensor_quality flags each failure mode", {
  q <- pr_sensor_quality(sq_cohort())
  # Sensor 3 reaches the layout's declared 10 kPa ceiling exactly.
  expect_identical(q$flag, c("OK", "OK", "Saturated (>60 kPa)", "OK"))

  # Raising the cut-off above the ceiling clears it.
  expect_identical(
    pr_sensor_quality(sq_cohort(), saturation_kpa = 10.5)$flag,
    rep("OK", 4)
  )
  # Lowering it catches sensor 4 (max 9) as well.
  expect_identical(
    pr_sensor_quality(sq_cohort(), saturation_kpa = 9)$flag,
    c("OK", "OK", "Saturated (>60 kPa)", "Saturated (>60 kPa)")
  )
  # Low variance: sensors 1 (0.25) and 2 (1.29) fall under 1.5.
  expect_identical(
    pr_sensor_quality(sq_cohort(), low_var_sd = 1.5)$flag,
    c("Low variance", "Low variance", "Saturated (>60 kPa)", "OK")
  )
})

test_that("pr_sensor_quality applies flags in precedence order", {
  # Sensors 1 and 3 are zero in 87.5% of frames; sensor 3 is also
  # saturated and both are under a 3 kPa low-variance bound. Dead wins
  # over saturated, saturated wins over low variance.
  q <- pr_sensor_quality(sq_cohort(), dead_pct_zero = 80, low_var_sd = 3)
  expect_identical(
    q$flag,
    c("Dead (>95% zero)", "Low variance", "Dead (>95% zero)",
      "Low variance")
  )

  q2 <- pr_sensor_quality(sq_cohort(), low_var_sd = 3)
  expect_identical(
    q2$flag,
    c("Low variance", "Low variance", "Saturated (>60 kPa)",
      "Low variance")
  )
})

test_that("pr_sensor_quality honours threshold", {
  # threshold = 1 zeroes every reading at or below 1 before averaging, and
  # counts those frames as unloaded.
  q <- pr_sensor_quality(sq_cohort(), threshold = 1)

  # Sensor 1: file A is all zeros, file B's single 1 is masked away.
  expect_equal(q$mean_across_files[1], 0)
  expect_equal(q$sd_across_files[1], 0)
  expect_equal(q$max_across_files[1], 0)
  expect_equal(q$pct_zero_mean[1], 100)
  # Sensor 4: file A's flat 1 is masked, file B's 3,3,3,9 survives.
  expect_equal(q$mean_across_files[4], (0 + 4.5) / 2)
  expect_equal(q$sd_across_files[4], (0 + 3) / 2)
  expect_equal(q$max_across_files[4], 9)
  expect_equal(q$pct_zero_mean[4], 50)
  # A fully masked sensor is now dead.
  expect_identical(q$flag[1], "Dead (>95% zero)")
})

test_that("pr_sensor_quality accepts a bare list of trials", {
  ds <- pr_sensor_quality(sq_cohort())
  ls <- pr_sensor_quality(list(sq_trial(sq_pressure_a()),
                               sq_trial(sq_pressure_b())))
  expect_equal(ls, ds)
})

test_that("pr_sensor_quality leaves single-frame recordings out of the sd", {
  one <- pr_trial(matrix(c(0, 6, 0, 2), nrow = 1), time = 0,
                  layout = sq_layout2())
  q <- pr_sensor_quality(list(sq_trial(sq_pressure_a()), one))

  # Means and maxima still see both recordings ...
  expect_equal(q$mean_across_files, c(0, (5 + 6) / 2, 1.25, 1.5))
  expect_equal(q$max_across_files, c(0, 8, 10, 2))
  # ... but the single frame contributes no within-file spread, so the
  # column is file A's sd alone, not half of it.
  expect_equal(q$sd_across_files,
               c(0, stats::sd(c(2, 4, 6, 8)), 5, 0))

  # With nothing but single-frame recordings there is no sd at all.
  q1 <- pr_sensor_quality(list(one))
  expect_identical(q1$sd_across_files, rep(NA_real_, 4))
  # An NA spread must not become a low-variance flag; sensors 1 and 3 read
  # zero in the only frame there is, which is all that can be said.
  expect_identical(q1$flag,
                   c("Dead (>95% zero)", "OK", "Dead (>95% zero)", "OK"))
})

test_that("pr_sensor_quality reproduces the fixture recording's own stats", {
  trial <- sq_fixture_trial()
  q <- pr_sensor_quality(list(trial))
  P <- trial$pressure

  # A one-recording cohort is that recording's per-sensor statistics.
  expect_identical(q$n_files, rep(1L, 256L))
  expect_equal(q$mean_across_files, unname(colMeans(P)))
  expect_equal(q$sd_across_files, unname(apply(P, 2, stats::sd)))
  expect_equal(q$max_across_files, unname(apply(P, 2, max)))
  expect_equal(q$pct_zero_mean, unname(100 * colMeans(P == 0)))

  # The mat's true ceiling is 63.75 kPa and pr_layout_saddle_novel()
  # declares it, so the derived cut-off needs no override.
  expect_equal(trial$layout$pressure_range[2], 63.75)
  expect_identical(
    q$flag,
    pr_sensor_quality(list(trial), saturation_kpa = 63.75)$flag
  )

  # This fixture is the first 200 frames of the recording -- the mat is
  # still being loaded, nothing anywhere reaches 8 kPa, and most of the
  # grid has never been touched.
  expect_equal(max(q$max_across_files), 7)
  expect_identical(sum(q$flag == "Saturated (>60 kPa)"), 0L)
  expect_identical(
    as.integer(table(q$flag)[c("Dead (>95% zero)", "Low variance", "OK")]),
    c(158L, 16L, 82L)
  )

  # Drop the cut-off into the range the excerpt does reach and exactly the
  # cells at or above it are flagged, minus those already called dead.
  q6 <- pr_sensor_quality(list(trial), saturation_kpa = 6)
  expect_identical(
    which(q6$flag == "Saturated (>60 kPa)"),
    which(q$max_across_files >= 6 & q$pct_zero_mean <= 95)
  )
  expect_gt(length(which(q6$flag == "Saturated (>60 kPa)")), 0L)
})

test_that("pr_sensor_quality reports on the grid, not the device channel", {
  # The negative control for the whole channel map: device channel 1 is
  # the only cell ever loaded, so the one non-dead row must be grid
  # (row 1, col 9) -- the first cell of the right-hand panel.
  layout <- pr_layout_saddle_novel()
  raw <- matrix(0, nrow = 4, ncol = 256)
  raw[, 1] <- c(20, 30, 40, 30)
  trial <- pr_trial(raw[, pr_channel_order(layout), drop = FALSE],
                    time = 0:3, layout = layout)

  q <- pr_sensor_quality(list(trial))
  live <- q[q$max_across_files > 0, ]
  expect_identical(nrow(live), 1L)
  expect_identical(c(live$row, live$col), c(1L, 9L))
  expect_equal(live$mean_across_files, 30)
  expect_identical(live$flag, "OK")

  # Everything else read zero in every frame of every file.
  expect_identical(sum(q$flag == "Dead (>95% zero)"), 255L)
  # The device channel behind that grid cell is recoverable, and is 1.
  expect_identical(pr_channel_order(layout)[live$sensor], 1L)
})

# ---- pr_sensor_quality: errors ---------------------------------------------

test_that("pr_sensor_quality rejects bad input", {
  expect_error(pr_sensor_quality(sq_pressure_a()), "pr_dataset")
  expect_error(pr_sensor_quality(list()), "no trials")
  expect_error(pr_sensor_quality(sq_cohort(), dead_pct_zero = 150),
               "between")
  expect_error(pr_sensor_quality(sq_cohort(), dead_pct_zero = NA_real_),
               "single finite number")
  expect_error(pr_sensor_quality(sq_cohort(), low_var_sd = -1),
               "non-negative")
  expect_error(pr_sensor_quality(sq_cohort(), saturation_kpa = 0),
               "positive")
  expect_error(pr_sensor_quality(sq_cohort(), threshold = c(0, 1)),
               "single finite number")
})

test_that("pr_sensor_quality refuses to invent a saturation ceiling", {
  # pr_layout_from_index_map() declares NA rather than guessing a range;
  # guessing here would fabricate the very number the flag tests.
  bare <- pr_layout_from_index_map(matrix(1:4, 2, 2), name = "bare")
  trial <- pr_trial(sq_pressure_a(), time = 0:3, layout = bare)

  expect_error(pr_sensor_quality(list(trial)), "saturation_kpa")
  # ... and an explicit value works on the same layout.
  q <- pr_sensor_quality(list(trial), saturation_kpa = 10)
  expect_identical(q$flag[3], "Saturated (>60 kPa)")
})

test_that("pr_sensor_quality refuses to mix sensor counts", {
  wide <- pr_trial(matrix(1, nrow = 2, ncol = 9), time = 0:1,
                   layout = sq_layout_n(3))
  expect_error(
    pr_sensor_quality(list(sq_trial(sq_pressure_a()), wide)),
    "must have the 4 sensors"
  )
})

test_that("pr_sensor_quality rejects an empty recording", {
  empty <- pr_trial(matrix(numeric(0), nrow = 0, ncol = 4), time = numeric(0),
                    layout = sq_layout2())
  expect_error(pr_sensor_quality(list(empty)), "no frames")
})

test_that("pr_sensor_quality warns when layouts differ", {
  other <- pr_trial(sq_pressure_b(), time = 0:3,
                    layout = pr_layout_from_index_map(
                      matrix(1:4, 2, 2), name = "other",
                      pressure_range = c(0, 10)))
  expect_warning(
    pr_sensor_quality(list(sq_trial(sq_pressure_a()), other)),
    "different layouts"
  )
})

# ---- pr_calc_gradient: values ----------------------------------------------

test_that("pr_calc_gradient recovers an analytic linear field", {
  # On M[r, c] = 3r + 4c the central differences are exactly 3 and 4, so
  # every interior cell has gradient 5.
  layout <- sq_layout_n(4)
  trial <- sq_field_trial(layout, function(r, cc) 3 * r + 4 * cc)

  g <- pr_calc_gradient(trial)
  expect_identical(names(g), c("sensor", "row", "col", "gradient"))
  expect_identical(nrow(g), 16L)

  interior <- g$row %in% 2:3 & g$col %in% 2:3
  expect_equal(g$gradient[interior], rep(5, 4))
  expect_true(all(is.na(g$gradient[!interior])))
  expect_identical(sum(is.na(g$gradient)), 12L)
})

test_that("pr_calc_gradient matches a loop over the definition", {
  layout <- sq_layout_n(5)
  # A field with no symmetry, so no two interior cells agree by accident.
  f <- function(r, cc) r^2 + 3 * cc - r * cc
  trial <- sq_field_trial(layout, f)

  M <- outer(1:5, 1:5, f)
  ref <- sq_ref_gradient(M)
  g <- pr_calc_gradient(trial)

  expect_equal(g$gradient, as.numeric(ref[cbind(g$row, g$col)]))
  expect_false(all(is.na(g$gradient)))
})

test_that("pr_calc_gradient's edges argument changes only the border", {
  layout <- sq_layout_n(5)
  f <- function(r, cc) r^2 + 3 * cc - r * cc
  trial <- sq_field_trial(layout, f)

  gn <- pr_calc_gradient(trial, edges = "na")
  gz <- pr_calc_gradient(trial, edges = "zero")

  border <- gn$row %in% c(1L, 5L) | gn$col %in% c(1L, 5L)
  expect_true(all(is.na(gn$gradient[border])))
  expect_equal(gz$gradient[border], rep(0, sum(border)))
  # Interior is bit-for-bit identical.
  expect_identical(gn$gradient[!border], gz$gradient[!border])
  # 16 of 25 cells are a structural zero on a 5x5 grid.
  expect_identical(sum(gz$gradient == 0), 16L)
})

test_that("pr_calc_gradient forward differences reach one cell further", {
  # On M[r, c] = 3r + 4c the forward differences are also 3 and 4, but
  # they are defined on rows and columns 1:(n-1) instead of 2:(n-1).
  layout <- sq_layout_n(4)
  trial <- sq_field_trial(layout, function(r, cc) 3 * r + 4 * cc)

  g <- pr_calc_gradient(trial, method = "forward")
  defined <- g$row <= 3L & g$col <= 3L
  expect_equal(g$gradient[defined], rep(5, 9))
  expect_true(all(is.na(g$gradient[!defined])))
  expect_identical(sum(is.na(g$gradient)), 7L)
})

test_that("pr_calc_gradient differentiates the statistic it is given", {
  layout <- sq_layout_n(4)
  coords <- layout$coords_mm
  lo <- 3 * coords$row + 4 * coords$col
  hi <- 6 * coords$row + 8 * coords$col
  trial <- pr_trial(rbind(lo, hi), time = c(0, 1), layout = layout)

  interior <- coords$row %in% 2:3 & coords$col %in% 2:3
  # The mean map is (lo + hi)/2, i.e. 4.5r + 6c -> gradient 7.5.
  expect_equal(pr_calc_gradient(trial, "mean")$gradient[interior],
               rep(7.5, 4))
  # The max map is hi, i.e. 6r + 8c -> gradient 10.
  expect_equal(pr_calc_gradient(trial, "max")$gradient[interior],
               rep(10, 4))
})

test_that("pr_calc_gradient honours threshold", {
  layout <- sq_layout_n(4)
  coords <- layout$coords_mm
  v <- 3 * coords$row + 4 * coords$col
  trial <- pr_trial(rbind(v, v), time = c(0, 1), layout = layout)

  # A threshold above the whole field flattens it, so every gradient is 0.
  g <- pr_calc_gradient(trial, threshold = 100, edges = "zero")
  expect_equal(g$gradient, rep(0, 16))
  # A threshold below the whole field changes nothing.
  expect_equal(pr_calc_gradient(trial, threshold = 0)$gradient,
               pr_calc_gradient(trial)$gradient)
})

test_that("pr_calc_gradient refuses to interpolate across inactive cells", {
  # A 4x4 mat missing grid cell (2, 2). The two interior cells that would
  # have to read it come back NA even under the zero-filling convention;
  # the remaining interior cell is a real number.
  index <- matrix(1:16, 4, 4)
  index[2, 2] <- NA
  layout <- sq_layout_n(4, index)
  trial <- sq_field_trial(layout, function(r, cc) 3 * r + 4 * cc)

  g <- pr_calc_gradient(trial, edges = "zero")
  expect_identical(nrow(g), 15L)

  key <- paste(g$row, g$col)
  expect_true(all(is.na(g$gradient[key %in% c("3 2", "2 3")])))
  expect_equal(g$gradient[key == "3 3"], 5)
  expect_identical(sum(is.na(g$gradient)), 2L)
})

test_that("pr_calc_gradient reproduces the study's zero-filled convention", {
  trial <- sq_fixture_trial()

  gz <- pr_calc_gradient(trial, edges = "zero")
  expect_identical(nrow(gz), 256L)

  # The whole outer ring is a structural zero, not a measurement.
  ring <- gz$row %in% c(1L, 16L) | gz$col %in% c(1L, 16L)
  expect_identical(sum(ring), 60L)
  expect_equal(gz$gradient[ring], rep(0, 60))
  # 59 interior cells are flat in this excerpt, so a zero gradient is not
  # by itself evidence of an edge cell -- which is the whole objection to
  # the zero-filling convention.
  expect_identical(sum(gz$gradient[!ring] == 0), 59L)
  expect_equal(max(gz$gradient), 3.9382393, tolerance = 1e-7)
  expect_identical(c(gz$row[which.max(gz$gradient)],
                     gz$col[which.max(gz$gradient)]), c(4L, 7L))

  # Against an explicit loop over the mean map, cell for cell.
  mean_map <- pr_sensor_map(trial, "mean")
  M <- matrix(0, 16, 16)
  M[cbind(mean_map$row, mean_map$col)] <- mean_map$value
  ref <- sq_ref_gradient(M, edge = 0)
  expect_equal(gz$gradient, as.numeric(ref[cbind(gz$row, gz$col)]))

  # The default reports the ring honestly, and biases the whole-grid mean
  # of the zero-filled version down by exactly 196/256.
  gn <- pr_calc_gradient(trial)
  expect_identical(sum(is.na(gn$gradient)), 60L)
  expect_equal(mean(gz$gradient),
               mean(gn$gradient, na.rm = TRUE) * 196 / 256)
})

# ---- pr_calc_gradient: errors ----------------------------------------------

test_that("pr_calc_gradient rejects bad input", {
  layout <- sq_layout_n(4)
  trial <- sq_field_trial(layout, function(r, cc) r + cc)

  expect_error(pr_calc_gradient(trial$pressure), "pr_trial")
  expect_error(pr_calc_gradient(trial, statistic = "median"), "median")
  expect_error(pr_calc_gradient(trial, method = "sobel"), "sobel")
  expect_error(pr_calc_gradient(trial, method = 1), "method")
  expect_error(pr_calc_gradient(trial, edges = "drop"),
               "should be one of")
  expect_error(pr_calc_gradient(trial, threshold = "0"),
               "single finite number")
})

test_that("pr_calc_gradient warns when the grid has no interior", {
  trial <- sq_trial(sq_pressure_a())

  expect_warning(g <- pr_calc_gradient(trial), "no cell")
  expect_true(all(is.na(g$gradient)))
  expect_warning(gz <- pr_calc_gradient(trial, edges = "zero"), "no cell")
  expect_equal(gz$gradient, rep(0, 4))
  # A forward difference is defined on a 2x2 grid, so no warning.
  expect_silent(gf <- pr_calc_gradient(trial, method = "forward"))
  expect_identical(sum(is.na(gf$gradient)), 3L)
})
