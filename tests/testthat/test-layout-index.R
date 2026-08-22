# Tests for R/layout-index.R — channel-map layouts and the raw-to-grid
# permutation.
#
# The permutation is the one thing in the pipeline that no aggregate statistic
# can catch: mean, peak, total and loaded-count are all invariant under a
# column permutation, so a wrong map produces perfectly plausible summaries
# and completely wrong maps. The tests below therefore check *positions*.

# Independent closed-form of the Novel saddle wiring, derived from the device
# description rather than from the cbind() construction in the source:
# channel c sits in grid row ((c - 1) %/% 16) + 1; within that row the first
# eight channels fill the right panel left-to-right (grid cols 9..16) and the
# next eight fill the left panel right-to-left (grid cols 8..1).
expected_novel_cell <- function(channel) {
  row <- ((channel - 1L) %/% 16L) + 1L
  j <- ((channel - 1L) %% 16L) + 1L
  col <- ifelse(j <= 8L, 8L + j, 17L - j)
  data.frame(sensor = as.integer(channel), row = as.integer(row),
             col = as.integer(col))
}

# Where does device channel `ch` end up after permutation?
grid_cell_of_channel <- function(layout, ch) {
  pos <- match(as.integer(ch), pr_channel_order(layout))
  cell <- which(layout$active)[pos]
  c(row = ((cell - 1L) %% layout$grid_rows) + 1L,
    col = ((cell - 1L) %/% layout$grid_rows) + 1L)
}

# ---- pr_layout_from_index_map --------------------------------------------

test_that("a full index map yields one sensor per cell, all active", {
  m <- rbind(c(2L, 1L), c(4L, 3L))
  lay <- pr_layout_from_index_map(m, name = "toy_2x2")

  expect_s3_class(lay, "pr_layout")
  expect_equal(lay$n_sensors, length(m))
  expect_true(all(lay$active))
  expect_equal(dim(lay$active), c(2L, 2L))
  expect_true(pr_validate_layout(lay))
  expect_equal(lay$name, "toy_2x2")
})

test_that("the permutation is column-major and moves channels to their cells", {
  # channel 2 at (1,1), 4 at (2,1), 1 at (1,2), 3 at (2,2)
  m <- rbind(c(2L, 1L), c(4L, 3L))
  lay <- pr_layout_from_index_map(m)

  expect_identical(pr_channel_order(lay), c(2L, 4L, 1L, 3L))

  raw <- matrix(c(10, 20, 30, 40), nrow = 1)  # channels 1..4
  press <- raw[, pr_channel_order(lay), drop = FALSE]
  expect_equal(as.numeric(press), c(20, 40, 10, 30))

  grid <- matrix(0, 2, 2)
  grid[which(lay$active)] <- press[1, ]
  expect_equal(grid[1, 1], 20)  # channel 2
  expect_equal(grid[1, 2], 10)  # channel 1
  expect_equal(grid[2, 2], 30)  # channel 3
})

test_that("an identity map is the identity permutation", {
  lay <- pr_layout_from_index_map(matrix(1:6, nrow = 2))
  expect_identical(pr_channel_order(lay), 1:6)
})

test_that("NA and 0 cells become inactive and drop out of the permutation", {
  m <- rbind(c(1L, NA_integer_), c(3L, 0L))
  lay <- pr_layout_from_index_map(m)

  expect_equal(lay$n_sensors, 2L)
  expect_equal(lay$active, matrix(c(TRUE, TRUE, FALSE, FALSE), 2, 2))
  expect_identical(pr_channel_order(lay), c(1L, 3L))
  expect_equal(lay$coords_mm$row, c(1L, 2L))
  expect_equal(lay$coords_mm$col, c(1L, 1L))
  # A raw frame has 3 device channels here; only 1 and 3 are wired.
  raw <- matrix(c(5, 6, 7), nrow = 1)
  expect_equal(as.numeric(raw[, pr_channel_order(lay)]), c(5, 7))
})

test_that("missing physical scale is representable and honest", {
  lay <- pr_layout_from_index_map(matrix(1:4, 2, 2))

  expect_true(is.na(lay$sensor_area_cm2))
  expect_true(is.na(lay$spacing_mm))
  expect_equal(lay$coords_units, "grid_index")
  # Unit grid: coordinates are index offsets, not millimetres.
  expect_equal(lay$coords_mm$x_mm, c(0, 0, 1, 1))
  expect_equal(lay$coords_mm$y_mm, c(0, 1, 0, 1))
  # Still a valid layout despite the NA area.
  expect_true(pr_validate_layout(lay))
  # Anything area-derived is NA rather than invented.
  trial <- pr_trial(matrix(c(1, 2, 3, 4), nrow = 1), 0, lay)
  expect_true(is.na(pr_calc_force(trial)))
  expect_equal(unname(pr_calc_peak_pressure(trial)), 4)
})

test_that("a real spacing produces real millimetre coordinates", {
  lay <- pr_layout_from_index_map(matrix(1:4, 2, 2), spacing_mm = 12.5,
                                  sensor_area_cm2 = 1.5)
  expect_equal(lay$coords_units, "mm")
  expect_equal(lay$spacing_mm, 12.5)
  expect_equal(lay$sensor_area_cm2, 1.5)
  expect_equal(lay$coords_mm$x_mm, c(0, 0, 12.5, 12.5))
})

test_that("pressure_range defaults to an unknown ceiling and can be set", {
  lay <- pr_layout_from_index_map(matrix(1:4, 2, 2))
  expect_equal(lay$pressure_range[1], 0)
  expect_true(is.na(lay$pressure_range[2]))

  lay2 <- pr_layout_from_index_map(matrix(1:4, 2, 2),
                                   pressure_range = c(0, 63.75))
  expect_equal(lay2$pressure_range, c(0, 63.75))
})

test_that("pr_layout_from_index_map rejects malformed maps", {
  expect_error(pr_layout_from_index_map(1:4), "numeric matrix")
  expect_error(pr_layout_from_index_map(matrix("a", 2, 2)), "numeric matrix")
  expect_error(pr_layout_from_index_map(matrix(numeric(0), 0, 0)),
               "at least one cell")
  expect_error(pr_layout_from_index_map(matrix(c(1L, 1L, 2L, 3L), 2, 2)),
               "same device channel")
  expect_error(pr_layout_from_index_map(matrix(NA_integer_, 2, 2)),
               "every grid cell as empty")
  expect_error(pr_layout_from_index_map(matrix(c(1.5, 2, 3, 4), 2, 2)),
               "whole positive")
  expect_error(pr_layout_from_index_map(matrix(c(-1, 2, 3, 4), 2, 2)),
               "whole positive")
  # A full map must be numbered 1..n or pressure[, order] would overrun.
  expect_error(pr_layout_from_index_map(matrix(c(1L, 2L, 3L, 9L), 2, 2)),
               "not.*1:4")
})

test_that("pr_layout_from_index_map rejects malformed scale and duplicate args", {
  m <- matrix(1:4, 2, 2)
  expect_error(pr_layout_from_index_map(m, sensor_area_cm2 = 0), "positive")
  expect_error(pr_layout_from_index_map(m, sensor_area_cm2 = c(1, 2)),
               "single number")
  expect_error(pr_layout_from_index_map(m, spacing_mm = -3), "positive")
  expect_error(pr_layout_from_index_map(m, name = 1), "single string")
  expect_error(pr_layout_from_index_map(m, active = matrix(TRUE, 2, 2)),
               "must not be passed")
})

# ---- pr_layout_saddle_novel ----------------------------------------------

test_that("the Novel saddle layout is a full 16x16 with 256 sensors", {
  lay <- pr_layout_saddle_novel()

  expect_equal(lay$grid_rows, 16L)
  expect_equal(lay$grid_cols, 16L)
  expect_equal(lay$n_sensors, 256L)
  expect_true(all(lay$active))
  expect_equal(lay$pressure_range, c(0, 63.75))
  expect_true(is.na(lay$sensor_area_cm2))
  expect_equal(lay$name, "saddle_novel")
  expect_true(pr_validate_layout(lay))
})

test_that("the Novel channel map matches the two-panel wiring", {
  map <- pr_layout_saddle_novel()$channel_map

  # The defining facts about this device.
  expect_equal(map[1, 9], 1L)
  expect_equal(map[1, 8], 9L)
  # Right panel row 1 runs 1..8 across cols 9..16.
  expect_equal(map[1, 9:16], 1:8)
  # Left panel row 1 runs 16..9 across cols 1..8.
  expect_equal(map[1, 1:8], 16:9)
  # Stride 16 down the rows.
  expect_equal(map[2, 9], 17L)
  expect_equal(map[16, 9], 241L)
  expect_equal(map[16, 1], 256L)
  # Every channel used exactly once.
  expect_setequal(as.vector(map), 1:256)
})

test_that("every channel lands where the closed-form wiring says it does", {
  lay <- pr_layout_saddle_novel()
  ord <- pr_channel_order(lay)

  expect_length(ord, 256L)
  expect_setequal(ord, 1:256)

  # Position of every channel after permutation, compared with an
  # independently derived formula (not the cbind() used to build the map).
  pos <- match(1:256, ord)
  cell <- which(lay$active)[pos]
  got <- data.frame(
    sensor = 1:256,
    row = ((cell - 1L) %% 16L) + 1L,
    col = ((cell - 1L) %/% 16L) + 1L
  )
  expect_equal(got, expected_novel_cell(1:256))

  # Same answer via the layout's own coordinate table.
  expect_equal(lay$coords_mm$row[pos], expected_novel_cell(1:256)$row)
  expect_equal(lay$coords_mm$col[pos], expected_novel_cell(1:256)$col)
})

test_that("saddle layout arguments pass through", {
  lay <- pr_layout_saddle_novel(name = "novel_alt", spacing_mm = 20,
                                sensor_area_cm2 = 4)
  expect_equal(lay$name, "novel_alt")
  expect_equal(lay$coords_units, "mm")
  expect_equal(lay$sensor_area_cm2, 4)
  expect_equal(lay$manufacturer, "Novel")

  expect_error(pr_layout_saddle_novel(pressure_range = 63.75),
               "length 2")
})

# ---- the negative control -------------------------------------------------

test_that("a single hot device channel 1 lands at grid (row 1, col 9)", {
  lay <- pr_layout_saddle_novel()

  raw <- matrix(0, nrow = 1, ncol = 256)
  raw[1, 1] <- 12.5
  press <- raw[, pr_channel_order(lay), drop = FALSE]
  trial <- pr_trial(press, time = 0, layout = lay)

  # 1. Reconstructed 16x16 grid: the only non-zero cell is [1, 9].
  grid <- matrix(0, 16, 16)
  grid[which(lay$active)] <- press[1, ]
  hot <- which(grid != 0, arr.ind = TRUE)
  expect_equal(nrow(hot), 1L)
  expect_equal(as.integer(hot[1, "row"]), 1L)
  expect_equal(as.integer(hot[1, "col"]), 9L)
  expect_equal(grid[1, 9], 12.5)

  # 2. Grid-index COP (pressure-weighted centroid of row/col) is (1, 9).
  w <- press[1, ]
  eps <- 1e-12
  cop_row <- sum(w * lay$coords_mm$row) / (sum(w) + eps)
  cop_col <- sum(w * lay$coords_mm$col) / (sum(w) + eps)
  expect_equal(cop_row, 1)
  expect_equal(cop_col, 9)

  # pressR's own COP, in this layout's grid-index coordinates.
  cop <- pr_calc_cop(trial)
  expect_equal(cop$x[1] + 1, 9)  # x_mm = col - 1
  expect_equal(cop$y[1] + 1, 1)  # y_mm = row - 1

  # 3. The loaded cell falls in the RIGHT half mask (cols 9-16).
  sym <- pr_mask_symmetry(lay, "vertical")
  loaded_col <- which(press[1, ] != 0)
  expect_length(loaded_col, 1L)
  expect_true(loaded_col %in% sym$right$sensor_cols)
  expect_false(loaded_col %in% sym$left$sensor_cols)

  reg <- pr_mask_apply(trial, sym)
  expect_equal(sum(reg$right), 12.5)
  expect_equal(sum(reg$left), 0)

  # And it is cranial (rows 1-5), not caudal.
  six <- pr_mask_saddle_6(lay)
  expect_true(loaded_col %in% six$cranial_right$sensor_cols)
  expect_false(loaded_col %in% six$caudal_right$sensor_cols)
  expect_false(loaded_col %in% six$cranial_left$sensor_cols)
})

test_that("single hot channel 9 lands at grid (row 1, col 8), the left panel", {
  lay <- pr_layout_saddle_novel()
  expect_equal(unname(grid_cell_of_channel(lay, 9L)), c(1L, 8L))

  raw <- matrix(0, nrow = 1, ncol = 256)
  raw[1, 9] <- 7
  press <- raw[, pr_channel_order(lay), drop = FALSE]
  loaded_col <- which(press[1, ] != 0)
  sym <- pr_mask_symmetry(lay, "vertical")
  expect_true(loaded_col %in% sym$left$sensor_cols)
  expect_false(loaded_col %in% sym$right$sensor_cols)
})

test_that("aggregate statistics are blind to the permutation", {
  # This is why the negative control above exists: every summary the study
  # reports is invariant under column permutation.
  lay <- pr_layout_saddle_novel()
  set.seed(11)
  raw <- matrix(stats::runif(3 * 256, 0, 60), nrow = 3)
  press <- raw[, pr_channel_order(lay), drop = FALSE]

  expect_equal(rowSums(press), rowSums(raw))
  expect_equal(apply(press, 1, max), apply(raw, 1, max))
  expect_equal(rowSums(press > 0), rowSums(raw > 0))
  # ...but the spatial picture is not.
  expect_false(isTRUE(all.equal(press[1, ], raw[1, ])))
})

# ---- pr_channel_order -----------------------------------------------------

test_that("pr_channel_order accepts a bare map or permutation vector", {
  expect_identical(pr_channel_order(rbind(c(2L, 1L), c(4L, 3L))),
                   c(2L, 4L, 1L, 3L))
  expect_identical(pr_channel_order(c(3L, 1L, 2L)), c(3L, 1L, 2L))
})

test_that("pr_channel_order rebuilds the order from a stored map", {
  lay <- pr_layout_saddle_novel()
  lay$channel_order <- NULL
  expect_identical(pr_channel_order(lay),
                   as.integer(as.vector(pr_layout_saddle_novel()$channel_map)))
})

test_that("pr_channel_order refuses layouts and objects with no map", {
  expect_error(pr_channel_order(pr_layout_saddle("horse")),
               "no channel map")
  expect_error(pr_channel_order("saddle"), "pr_layout")
  expect_error(pr_channel_order(c(1L, 3L)), "permutation")
  expect_error(pr_channel_order(list()), "pr_layout")
})
