test_that("pr_mask constructs valid mask", {
  layout <- pr_layout_saddle("horse")
  m <- pr_mask(layout$regions$cranial_left, "cranial_left", layout)
  expect_s3_class(m, "pr_mask")
  expect_true(m$n_sensors > 0L)
})

test_that("pr_mask_default returns layout's regions", {
  masks <- pr_mask_default(pr_layout_saddle("horse"))
  expect_length(masks, 6L)
})

test_that("pr_mask_apply extracts correct column counts", {
  trial <- pr_example_trial("saddle_horse")
  parts <- pr_mask_apply(trial)
  expect_length(parts, 6L)
  expect_true(all(vapply(parts, ncol, integer(1)) > 0L))
})

test_that("pr_mask_symmetry returns two named masks", {
  sym <- pr_mask_symmetry(pr_layout_saddle("horse"), "vertical")
  expect_named(sym, c("left", "right"))
  expect_s3_class(sym$left, "pr_mask")
})

test_that("pr_mask_saddle_6 returns six named masks", {
  m <- pr_mask_saddle_6(pr_layout_saddle("horse"))
  expect_named(m, c("cranial_left", "cranial_right",
                    "middle_left", "middle_right",
                    "caudal_left", "caudal_right"))
})

test_that("pr_mask_foot_auto handles empty pressure gracefully", {
  layout <- pr_layout_platform("cl")
  trial <- pr_trial(
    pressure = matrix(0, nrow = 5, ncol = layout$n_sensors),
    time = seq(0, 0.1, length.out = 5), layout = layout
  )
  expect_warning(res <- pr_mask_foot_auto(trial))
  expect_length(res, 0L)
})

# A full rectangular layout with grid-index coordinates, for small-grid edges.
mask_grid_layout <- function(nr, nc) {
  co <- data.frame(
    sensor_id = seq_len(nr * nc),
    row = rep(seq_len(nr), times = nc),
    col = rep(seq_len(nc), each = nr)
  )
  co$x_mm <- co$col - 1
  co$y_mm <- co$row - 1
  pr_layout(nr, nc, matrix(TRUE, nr, nc), co, name = "grid")
}

test_that("pr_mask_saddle_6 regions never overlap and refuse undividable grids", {
  six <- pr_mask_saddle_6(pr_layout_saddle("horse"))
  cols <- unlist(lapply(six, `[[`, "sensor_cols"))
  expect_false(anyDuplicated(cols) > 0L)
  # 16 rows split 5 / 5 / 6, as documented.
  rows <- vapply(six[c("cranial_left", "middle_left", "caudal_left")],
    function(m) sum(rowSums(m$matrix) > 0), numeric(1))
  expect_equal(unname(rows), c(5, 5, 6))
  # Two rows used to put row 1 into both the middle and the caudal region.
  expect_error(pr_mask_saddle_6(mask_grid_layout(2, 4)), "at least 3 grid rows")
  expect_error(pr_mask_saddle_6(mask_grid_layout(6, 1)), "2 grid columns")
  three <- pr_mask_saddle_6(mask_grid_layout(3, 2))
  expect_true(all(vapply(three, `[[`, integer(1), "n_sensors") == 1L))
})

test_that("pr_mask_symmetry refuses a single line and keeps the odd-centre rule", {
  expect_error(pr_mask_symmetry(mask_grid_layout(3, 1)), "at least two grid columns")
  expect_error(pr_mask_symmetry(mask_grid_layout(1, 4), "horizontal"), "at least two grid rows")
  odd <- pr_mask_symmetry(mask_grid_layout(4, 3))
  expect_equal(c(odd$left$n_sensors, odd$right$n_sensors), c(4L, 8L))
})
