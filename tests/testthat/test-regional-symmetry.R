# ---------------------------------------------------------------------------
# Zones, symmetry and masked COP.
#
# Reference values are derived from the definitions in the test itself, never
# by calling the function under test a second way. The real-data values come
# from the committed 200-frame fixture; the same code run on the full
# 869-frame recording reproduces the study's own zone_pressure table for
# ID052_K_K_KG00_MS to ten decimal places (Cranial-Right 2.3169303797 /
# 6.817894131 / 21, Middle-Left 0.2723017357 / 2.533371692 / 9, and so on).
# ---------------------------------------------------------------------------

fixture <- function() test_path("fixtures", "ID052_K_K_KG00_MS.asc")

# A 4x4 identity-mapped layout: pressure column k is grid cell k in
# column-major order.
rs_layout4 <- function(spacing_mm = NA_real_) {
  pr_layout_from_index_map(
    matrix(1:16, nrow = 4, ncol = 4), name = "rs_4x4",
    spacing_mm = spacing_mm
  )
}

# The per-sensor mean map the tests reason about, as a 4x4 grid. Chosen so
# that no band, no side and no mirror pair is accidentally equal.
rs_map <- function() {
  matrix(
    c(1, 2, 0, 4,
      0, 3, 1, 0,
      2, 0, 0, 6,
      0, 0, 5, 1),
    nrow = 4, byrow = TRUE
  )
}

# Two frames whose column means are exactly rs_map(): all the load in frame
# one, nothing in frame two. The maximum map is then 2 * rs_map() and every
# loaded sensor has a duty cycle of exactly 0.5.
rs_trial4 <- function(spacing_mm = NA_real_) {
  v <- as.vector(rs_map())
  pr_trial(rbind(2 * v, 0 * v), time = c(0, 1),
           layout = rs_layout4(spacing_mm))
}

# Bands 1:1 / 2:3 / 4:4 on the 4-row grid, sides split at column 2.
rs_masks4 <- function(layout = rs_layout4()) {
  pr_mask_rowbands(layout, breaks = c(1, 3))
}

# ---- pr_mask_rowbands ------------------------------------------------------

test_that("pr_mask_rowbands breaks = c(5, 10) reproduces pr_mask_saddle_6", {
  layout <- pr_layout_saddle("horse")
  got <- pr_mask_rowbands(layout, breaks = c(5, 10))
  want <- pr_mask_saddle_6(layout)

  expect_identical(names(got), names(want))
  for (nm in names(want)) {
    expect_identical(got[[nm]]$matrix, want[[nm]]$matrix, info = nm)
    expect_identical(got[[nm]]$sensor_cols, want[[nm]]$sensor_cols, info = nm)
  }
  # That convention puts the deep band at the back: 5 / 5 / 6 rows.
  expect_identical(
    vapply(got, function(m) m$n_sensors, integer(1)),
    c(cranial_left = 36L, cranial_right = 36L,
      middle_left = 40L, middle_right = 40L,
      caudal_left = 48L, caudal_right = 48L)
  )
})

test_that("pr_mask_rowbands breaks = c(5, 11) reproduces the layout regions", {
  layout <- pr_layout_saddle("horse")
  got <- pr_mask_rowbands(layout, breaks = c(5, 11))

  expect_identical(names(got), names(layout$regions))
  for (nm in names(got)) {
    expect_identical(got[[nm]]$matrix, layout$regions[[nm]], info = nm)
  }
  # The study's convention puts the deep band in the middle: 5 / 6 / 5 rows.
  expect_identical(
    vapply(got, function(m) m$n_sensors, integer(1)),
    c(cranial_left = 36L, cranial_right = 36L,
      middle_left = 48L, middle_right = 48L,
      caudal_left = 40L, caudal_right = 40L)
  )
  # The one-row difference between the two conventions moves exactly the
  # eight sensors of row 11 from caudal to middle.
  other <- pr_mask_rowbands(layout, breaks = c(5, 10))
  moved <- got$middle_left$matrix & !other$middle_left$matrix
  expect_identical(which(moved, arr.ind = TRUE)[, "row"], rep(11L, 8L))
})

test_that("pr_mask_rowbands places each band's rows exactly", {
  layout <- rs_layout4()
  bands <- pr_mask_rowbands(layout, breaks = c(1, 3), sides = FALSE)

  expect_identical(names(bands), c("cranial", "middle", "caudal"))
  rows_of <- function(m) sort(unique(which(m$matrix, arr.ind = TRUE)[, "row"]))
  expect_identical(rows_of(bands$cranial), 1L)
  expect_identical(rows_of(bands$middle), c(2L, 3L))
  expect_identical(rows_of(bands$caudal), 4L)
  expect_identical(
    vapply(bands, function(m) m$n_sensors, integer(1)),
    c(cranial = 4L, middle = 8L, caudal = 4L)
  )

  # Bands partition the mat: every active cell in exactly one of them.
  covered <- Reduce(`+`, lapply(bands, function(m) m$matrix))
  expect_true(all(covered == 1L))
})

test_that("pr_mask_rowbands honours custom band names and inactive cells", {
  layout <- pr_layout_saddle("horse")   # rows 1-2, cols 7-10 are cut out
  bands <- pr_mask_rowbands(layout, breaks = 8, sides = FALSE,
                            band_names = c("front", "back"))
  expect_identical(names(bands), c("front", "back"))
  expect_identical(bands$front$n_sensors, 8L * 16L - 8L)
  expect_identical(bands$back$n_sensors, 8L * 16L)
  expect_false(any(bands$front$matrix & !layout$active))
})

test_that("pr_mask_rowbands rejects a split it cannot honour", {
  layout <- pr_layout_saddle("horse")
  expect_error(pr_mask_rowbands(layout, breaks = 5), "2 whole numbers")
  expect_error(pr_mask_rowbands(layout, breaks = c(11, 5)),
               "strictly increasing")
  expect_error(pr_mask_rowbands(layout, breaks = c(5, 16)), "whole numbers in")
  expect_error(pr_mask_rowbands(layout, breaks = c(5, 11.5)),
               "whole numbers in")
  expect_error(pr_mask_rowbands(layout, band_names = c("a", "a", "b")),
               "must be unique")
  expect_error(pr_mask_rowbands(layout, sides = NA), "TRUE")
  expect_error(pr_mask_rowbands("not a layout"), "pr_layout")
})

# ---- pr_mask_mirror_balance ------------------------------------------------

test_that("pr_mask_mirror_balance returns the largest mirror-symmetric subset", {
  layout <- rs_layout4()
  m <- rs_map() > 0        # 4 cells left, 5 right: unbalanced by construction
  expect_identical(c(sum(m[, 1:2]), sum(m[, 3:4])), c(4L, 5L))

  bal <- pr_mask_mirror_balance(m, layout)
  expect_s3_class(bal, "pr_mask")
  expect_identical(bal$halves, c(left = 3L, right = 3L))
  expect_identical(bal$axis, "vertical")

  # The survivors are exactly the pairs present on both sides.
  expect_identical(
    which(bal$matrix, arr.ind = TRUE, useNames = FALSE),
    cbind(c(1L, 3L, 2L, 2L, 1L, 3L), c(1L, 1L, 2L, 3L, 4L, 4L))
  )
  # Symmetric by construction, and a subset of the input.
  expect_identical(bal$matrix, bal$matrix[, 4:1])
  expect_true(all(bal$matrix <= m))
})

test_that("pr_mask_mirror_balance balances an unbalanced real-mat mask", {
  layout <- pr_layout_saddle_novel()
  # Every cell except three columns of the right panel: 128 left, 24 right.
  m <- matrix(FALSE, 16, 16)
  m[, 1:8] <- TRUE
  m[, 9:11] <- TRUE
  expect_identical(c(sum(m[, 1:8]), sum(m[, 9:16])), c(128L, 48L))

  bal <- pr_mask_mirror_balance(m, layout)
  expect_identical(bal$halves, c(left = 48L, right = 48L))
  expect_identical(which(apply(bal$matrix, 2, any)), 6:11)
  expect_identical(bal$n_sensors, 96L)
})

test_that("pr_mask_mirror_balance mirrors rows on the horizontal axis", {
  layout <- rs_layout4()
  m <- matrix(FALSE, 4, 4)
  m[1:3, ] <- TRUE                       # 2 rows anterior, 1 posterior
  bal <- pr_mask_mirror_balance(m, layout, axis = "horizontal")
  # Rows 2:3 survive: row 1's mirror is row 4, which was never in the mask.
  expect_identical(bal$halves, c(anterior = 4L, posterior = 4L))
  expect_identical(which(apply(bal$matrix, 1, any)), 2:3)
})

test_that("pr_mask_mirror_balance drops a self-mirroring centre line", {
  layout <- pr_layout_from_index_map(matrix(1:9, 3, 3), name = "rs_3x3")
  bal <- pr_mask_mirror_balance(matrix(TRUE, 3, 3), layout)
  expect_identical(bal$halves, c(left = 3L, right = 3L))
  expect_false(any(bal$matrix[, 2]))     # column 2 reflects onto itself
})

test_that("pr_mask_mirror_balance rejects a mask that is not the layout's", {
  layout <- rs_layout4()
  expect_error(pr_mask_mirror_balance(matrix(TRUE, 3, 3), layout), "4 x 4")
  expect_error(pr_mask_mirror_balance(matrix(1, 4, 4), layout),
               "logical matrix")
  expect_error(pr_mask_mirror_balance(matrix(TRUE, 4, 4), layout,
                                      axis = "diagonal"),
               "'arg' should be one of")
})

# ---- pr_calc_regional_map --------------------------------------------------

test_that("pr_calc_regional_map reduces frames first, then sensors", {
  trial <- rs_trial4()
  z <- pr_calc_regional_map(trial, rs_masks4())

  expect_identical(z$zone, names(rs_masks4()))
  expect_equal(z$zone_mean_kPa, c(1.5, 2, 1.25, 1.75, 0, 3))
  expect_equal(z$zone_peak_kPa, c(2, 4, 3, 6, 0, 5))
  expect_identical(z$zone_loaded, c(2L, 1L, 2L, 2L, 0L, 2L))
})

test_that("pr_calc_regional_map's statistics are the three sensor maps", {
  trial <- rs_trial4()
  # All the load is in frame one, so the peak map is twice the mean map and
  # every loaded sensor is loaded in exactly half the frames.
  mx <- pr_calc_regional_map(trial, rs_masks4(), statistic = "max")
  expect_equal(mx$zone_mean_kPa, c(1.5, 2, 1.25, 1.75, 0, 3) * 2)
  expect_equal(mx$zone_peak_kPa, c(2, 4, 3, 6, 0, 5) * 2)

  ld <- pr_calc_regional_map(trial, rs_masks4(), statistic = "loaded")
  # Loaded sensors per zone, over the zone's sensor count, times a duty of
  # one half. The middle band is twice as deep as the outer two.
  expect_equal(ld$zone_mean_kPa,
               c(2, 1, 2, 2, 0, 2) / c(2, 2, 4, 4, 2, 2) * 0.5)
  expect_equal(ld$zone_peak_kPa, c(0.5, 0.5, 0.5, 0.5, 0, 0.5))
  expect_identical(ld$zone_loaded, c(2L, 1L, 2L, 2L, 0L, 2L))
})

test_that("pr_calc_regional_map's threshold removes cells from the map", {
  trial <- rs_trial4()
  # Frame one holds 2 * rs_map(), so a threshold of 4 drops every sensor
  # whose mean was 2 or less; the survivors keep their own mean untouched.
  z <- pr_calc_regional_map(trial, rs_masks4(), threshold = 4)
  expect_equal(z$zone_mean_kPa, c(0, 4 / 2, 3 / 4, 6 / 4, 0, 5 / 2))
  expect_identical(z$zone_loaded, c(0L, 1L, 1L, 1L, 0L, 1L))
})

test_that("pr_calc_regional_map's peak sits below pr_calc_regional's mpp", {
  trial <- pr_example_trial("saddle_horse", seed = 11)
  masks <- pr_mask_rowbands(trial$layout, breaks = c(5, 11))
  sensor_first <- pr_calc_regional_map(trial, masks)
  frame_first <- pr_calc_regional(trial, masks, parameters = "mpp")

  # The largest time-averaged cell can never exceed the largest single
  # reading, and on real data it is strictly smaller everywhere.
  expect_true(all(sensor_first$zone_peak_kPa <= frame_first$mpp + 1e-9))
  expect_true(all(sensor_first$zone_peak_kPa < frame_first$mpp))
})

test_that("pr_calc_regional_map reproduces the study's zone table", {
  trial <- pr_read_pliance(fixture())
  masks <- pr_mask_rowbands(trial$layout, breaks = c(5, 11))
  z <- pr_calc_regional_map(trial, masks)

  expect_equal(
    z$zone_mean_kPa,
    c(1.79965625, 2.34828125, 0.258177083333333, 3.10752604166667,
      0, 2.280406250),
    tolerance = 1e-9
  )
  expect_equal(
    z$zone_peak_kPa,
    c(6.31875, 6.82750, 2.43500, 6.41625, 0, 6.35375),
    tolerance = 1e-9
  )
  expect_identical(z$zone_loaded, c(19L, 19L, 7L, 31L, 0L, 23L))

  # Independent recomputation straight from the pressure matrix.
  v <- colMeans(trial$pressure)
  co <- trial$layout$coords_mm
  left <- co$col <= 8
  band <- cut(co$row, c(0, 5, 11, 16), labels = FALSE)
  want <- unlist(lapply(1:3, function(b) {
    c(mean(v[band == b & left]), mean(v[band == b & !left]))
  }))
  expect_equal(z$zone_mean_kPa, unname(want))
})

test_that("pr_calc_regional_map rejects unusable arguments", {
  trial <- rs_trial4()
  expect_error(pr_calc_regional_map(trial, rs_masks4(), statistic = "pti"),
               "Got \"pti\"")
  expect_error(pr_calc_regional_map(trial, unname(rs_masks4())),
               "named list")
  expect_error(pr_calc_regional_map(trial, list()), "non-empty named list")
  expect_error(pr_calc_regional_map(trial, rs_masks4(), threshold = NA),
               "single finite number")
  # The Novel saddle layout ships without regions, so masks are mandatory.
  expect_error(
    pr_calc_regional_map(pr_read_pliance(fixture())),
    "carries no regions"
  )
})

# ---- pr_calc_symmetry_map --------------------------------------------------

test_that("pr_calc_symmetry_map computes the index on the sensor map", {
  trial <- rs_trial4()
  s <- pr_calc_symmetry_map(trial)

  # Left = mean(1,0,2,0, 2,3,0,0) = 1; right = mean(0,1,0,5, 4,0,6,1) = 2.125
  expect_identical(c(s$n_left, s$n_right), c(8L, 8L))
  expect_equal(s$left_value, 1)
  expect_equal(s$right_value, 2.125)
  expect_equal(s$asymmetry_pct, -72)
  expect_identical(s$statistic, "mean")
  expect_identical(s$denominator, "grid")
  expect_identical(nrow(s), 1L)
})

test_that("pr_calc_symmetry_map's sign says which side carries load", {
  layout <- rs_layout4()
  mirrored <- as.vector(rs_map()[, 4:1])
  flipped <- pr_trial(rbind(2 * mirrored, 0 * mirrored), time = c(0, 1),
                      layout = layout)
  # The same recording reflected left-to-right flips the sign exactly.
  expect_equal(pr_calc_symmetry_map(flipped)$asymmetry_pct, 72)

  even <- as.vector(matrix(3, 4, 4))
  balanced <- pr_trial(rbind(even, even), time = c(0, 1), layout = layout)
  expect_equal(pr_calc_symmetry_map(balanced)$asymmetry_pct, 0)

  # No load at all is 0, not NaN.
  empty <- pr_trial(matrix(0, 2, 16), time = c(0, 1), layout = layout)
  expect_equal(pr_calc_symmetry_map(empty)$asymmetry_pct, 0)
})

test_that("pr_calc_symmetry_map's denominator changes the question asked", {
  trial <- rs_trial4()
  # Loaded-cells-only: mean(1,2,2,3) = 2 against mean(1,5,4,6,1) = 3.4
  s <- pr_calc_symmetry_map(trial, denominator = "loaded")
  expect_equal(s$left_value, 2)
  expect_equal(s$right_value, 3.4)
  expect_equal(s$asymmetry_pct, (2 - 3.4) / (0.5 * 5.4) * 100)
})

test_that("pr_calc_symmetry_map accepts a region of interest or two sides", {
  trial <- rs_trial4()
  bands <- pr_mask_rowbands(rs_layout4(), breaks = c(1, 3), sides = FALSE)

  # One mask: split at the midline. Cranial row: left mean 1.5, right 2.
  roi <- pr_calc_symmetry_map(trial, bands$cranial)
  expect_identical(c(roi$n_left, roi$n_right), c(2L, 2L))
  expect_equal(roi$asymmetry_pct, (1.5 - 2) / (0.5 * 3.5) * 100)

  # Two masks: the sides given explicitly, in the order supplied.
  halves <- pr_mask_symmetry(rs_layout4())
  expect_equal(pr_calc_symmetry_map(trial, halves)$asymmetry_pct, -72)
  expect_equal(pr_calc_symmetry_map(trial, rev(halves))$asymmetry_pct, 72)
})

test_that("pr_calc_symmetry_map matches the fixture recording", {
  trial <- pr_read_pliance(fixture())
  s <- pr_calc_symmetry_map(trial)
  expect_equal(s$left_value, 0.659208984375, tolerance = 1e-12)
  expect_equal(s$right_value, 2.611787109375, tolerance = 1e-12)
  expect_equal(s$asymmetry_pct, -119.38737124944, tolerance = 1e-10)

  # Restricting to the loaded cells only is a far milder number: the left
  # side of this mat loses contact area, not intensity.
  expect_equal(pr_calc_symmetry_map(trial, denominator = "loaded")$asymmetry_pct,
               -34.1022616891, tolerance = 1e-9)
})

test_that("pr_calc_symmetry_map rejects unusable masks", {
  trial <- rs_trial4()
  expect_error(pr_calc_symmetry_map(trial, list(1, 2, 3)), "exactly two")
  expect_error(pr_calc_symmetry_map(trial, matrix(TRUE, 2, 2)), "4 x 4")
  expect_error(pr_calc_symmetry_map(trial, denominator = "loaded_only"),
               "should be one of")
  expect_error(pr_calc_symmetry_map(trial, statistic = "sd"), "Got \"sd\"")
  expect_error(pr_calc_symmetry_map("not a trial"), "pr_trial")
})

# ---- pr_symmetry_sensitivity -----------------------------------------------

test_that("pr_symmetry_sensitivity returns one row per scheme", {
  trial <- rs_trial4()
  layout <- rs_layout4()
  bands <- pr_mask_rowbands(layout, breaks = c(1, 3), sides = FALSE)
  schemes <- list(whole = layout$active, cranial = bands$cranial,
                  middle = bands$middle)

  out <- pr_symmetry_sensitivity(trial, schemes)
  expect_identical(out$scheme, c("whole", "cranial", "middle"))
  expect_identical(nrow(out), 3L)
  expect_true(all(out$balanced))
  expect_true(all(out$n_left == out$n_right))
  # A full rectangular mask is already symmetric, so balancing is a no-op.
  expect_equal(out$asymmetry_pct[1], -72)
  expect_equal(out$asymmetry_pct[2], (1.5 - 2) / (0.5 * 3.5) * 100)
})

test_that("pr_symmetry_sensitivity's balance step is what equalises the sides", {
  trial <- rs_trial4()
  scheme <- list(loaded = rs_map() > 0)

  raw <- pr_symmetry_sensitivity(trial, scheme, balance = FALSE)
  expect_identical(c(raw$n_left, raw$n_right), c(4L, 5L))
  expect_false(raw$balanced)
  # mean(1,2,2,3) = 2 against mean(1,5,4,6,1) = 3.4
  expect_equal(raw$asymmetry_pct, (2 - 3.4) / (0.5 * 5.4) * 100)

  bal <- pr_symmetry_sensitivity(trial, scheme)
  expect_identical(c(bal$n_left, bal$n_right), c(3L, 3L))
  # The surviving pairs are (1,1)/(1,4), (2,2)/(2,3) and (3,1)/(3,4):
  # mean(1,3,2) = 2 against mean(4,1,6) = 11/3.
  expect_equal(bal$left_value, 2)
  expect_equal(bal$right_value, 11 / 3)
  expect_equal(bal$asymmetry_pct, (2 - 11 / 3) / (0.5 * (2 + 11 / 3)) * 100)
})

test_that("pr_symmetry_sensitivity balances a real lopsided mask", {
  trial <- pr_read_pliance(fixture())
  layout <- trial$layout
  ever <- matrix(FALSE, 16, 16)
  co <- layout$coords_mm
  ever[cbind(co$row, co$col)] <- colMeans(trial$pressure) > 0

  raw <- pr_symmetry_sensitivity(trial, list(loaded = ever), balance = FALSE)
  expect_identical(c(raw$n_left, raw$n_right), c(26L, 73L))
  expect_equal(raw$asymmetry_pct, -34.1022616891, tolerance = 1e-9)

  bal <- pr_symmetry_sensitivity(trial, list(loaded = ever))
  expect_identical(c(bal$n_left, bal$n_right), c(19L, 19L))
  expect_equal(bal$asymmetry_pct, -43.5053834388, tolerance = 1e-9)

  # The whole-mat scheme is symmetric already and is unmoved by balancing.
  whole <- pr_symmetry_sensitivity(trial, list(mat = layout$active))
  expect_identical(c(whole$n_left, whole$n_right), c(128L, 128L))
  expect_equal(whole$asymmetry_pct, -119.38737124944, tolerance = 1e-10)
})

test_that("pr_symmetry_sensitivity rejects a family it cannot label", {
  trial <- rs_trial4()
  masks <- rs_masks4()
  expect_error(pr_symmetry_sensitivity(trial, unname(masks)), "named list")
  expect_error(pr_symmetry_sensitivity(trial, list()), "non-empty named list")
  expect_error(pr_symmetry_sensitivity(trial, masks$cranial_left),
               "non-empty named list")
  expect_error(pr_symmetry_sensitivity(trial, masks, balance = "yes"), "TRUE")
})

# ---- pr_calc_cop_masked ----------------------------------------------------

# One loaded sensor in frame 1, two in frame 2, a different one in frame 3;
# the right half is never loaded.
rs_cop_trial <- function(spacing_mm = NA_real_) {
  P <- matrix(0, 3, 16)
  idx <- function(r, c) (c - 1) * 4 + r
  P[1, idx(1, 1)] <- 1
  P[2, idx(1, 1)] <- 1
  P[2, idx(1, 2)] <- 1
  P[3, idx(3, 2)] <- 2
  pr_trial(P, time = c(0, 1, 2), layout = rs_layout4(spacing_mm))
}

test_that("pr_calc_cop_masked gives one pr_cop per region", {
  trial <- rs_cop_trial()
  halves <- pr_mask_symmetry(rs_layout4())
  cops <- pr_calc_cop_masked(trial, halves)

  expect_identical(names(cops), c("left", "right"))
  expect_true(all(vapply(cops, inherits, logical(1), "pr_cop")))

  # Grid units: x is the fractional column, y the fractional row.
  expect_equal(cops$left$x, c(1, 1.5, 2))
  expect_equal(cops$left$y, c(1, 1, 3))
  expect_identical(cops$left$time, c(0, 1, 2))

  # The pr_cop vocabulary follows from those coordinates.
  expect_equal(cops$left$path_length, 0.5 + sqrt(0.25 + 4))
  expect_equal(cops$left$range_x, 1)
  expect_equal(cops$left$range_y, 2)
  expect_equal(cops$left$velocity_mean, mean(c(0.5, sqrt(4.25))))
  expect_equal(cops$left$velocity_max, sqrt(4.25))
})

test_that("pr_calc_cop_masked gives NA where a region carries no load", {
  trial <- rs_cop_trial()
  cops <- pr_calc_cop_masked(trial, pr_mask_symmetry(rs_layout4()))

  expect_true(all(is.na(cops$right$x)))
  expect_true(all(is.na(cops$right$y)))
  # pr_cop() drops those frames, so the metrics stay finite rather than NaN.
  expect_equal(cops$right$path_length, 0)
  expect_equal(cops$right$range_x, 0)
  expect_equal(cops$right$sway_area, 0)

  # A region loaded in only some frames keeps the frames it has.
  bands <- pr_mask_rowbands(rs_layout4(), breaks = c(1, 3), sides = FALSE)
  by_band <- pr_calc_cop_masked(trial, bands)
  expect_equal(by_band$cranial$x, c(1, 1.5, NA))
  expect_equal(by_band$middle$x, c(NA, NA, 2))
  expect_equal(by_band$middle$y, c(NA, NA, 3))
})

test_that("pr_calc_cop_masked's mm units use the layout's real pitch", {
  trial <- rs_cop_trial(spacing_mm = 10)
  halves <- pr_mask_symmetry(rs_layout4(spacing_mm = 10))
  cops <- pr_calc_cop_masked(trial, halves, units = "mm")

  # x_mm = (col - 1) * 10, y_mm = (row - 1) * 10
  expect_equal(cops$left$x, c(0, 5, 10))
  expect_equal(cops$left$y, c(0, 0, 20))
  expect_equal(cops$left$path_length, 10 * (0.5 + sqrt(0.25 + 4)))
})

test_that("pr_calc_cop_masked refuses to invent millimetres", {
  trial <- rs_cop_trial()
  halves <- pr_mask_symmetry(rs_layout4())
  expect_error(pr_calc_cop_masked(trial, halves, units = "mm"),
               "no physical sensor pitch")
  expect_error(pr_calc_cop_masked(trial, halves, units = "inches"),
               "should be one of")
})

test_that("pr_calc_cop_masked stays inside each region on real data", {
  trial <- pr_read_pliance(fixture())
  masks <- pr_mask_rowbands(trial$layout, breaks = c(5, 11))
  cops <- pr_calc_cop_masked(trial, masks)

  expect_identical(names(cops), names(masks))
  rows <- vapply(cops, function(c) mean(c$y, na.rm = TRUE), numeric(1))
  cols <- vapply(cops, function(c) mean(c$x, na.rm = TRUE), numeric(1))
  # Each band's COP sits within that band's rows, and each side's within
  # that side's columns.
  expect_true(rows[["cranial_right"]] >= 1 && rows[["cranial_right"]] <= 5)
  expect_true(rows[["middle_right"]] >= 6 && rows[["middle_right"]] <= 11)
  expect_true(rows[["caudal_right"]] >= 12 && rows[["caudal_right"]] <= 16)
  expect_true(all(cols[c("cranial_left", "middle_left")] <= 8))
  expect_true(all(cols[c("cranial_right", "middle_right",
                         "caudal_right")] >= 9))
  # The caudal left zone never loads in this recording.
  expect_true(all(is.na(cops$caudal_left$x)))

  expect_equal(cols[["cranial_left"]], 5.2304162309, tolerance = 1e-9)
  expect_equal(rows[["middle_right"]], 8.4653894730, tolerance = 1e-9)
})

test_that("pr_calc_cop_masked rejects unusable arguments", {
  trial <- rs_cop_trial()
  expect_error(pr_calc_cop_masked(trial), "carries no regions")
  expect_error(pr_calc_cop_masked(trial, unname(rs_masks4())), "named list")
  expect_error(pr_calc_cop_masked(trial, list(bad = matrix(TRUE, 2, 2))),
               "4 x 4")
  expect_error(pr_calc_cop_masked(trial, rs_masks4(), threshold = c(1, 2)),
               "single finite number")
})
