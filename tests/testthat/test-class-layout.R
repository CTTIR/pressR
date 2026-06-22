# Tests for R/class-layout.R validation branches, summary/print, plotting,
# pr_validate_layout warning path, and .regions_to_df.

valid_coords <- function(n = 4) {
  data.frame(
    sensor_id = seq_len(n * n),
    row = rep(seq_len(n), each = n),
    col = rep(seq_len(n), times = n),
    x_mm = rep(seq_len(n) * 10, times = n),
    y_mm = rep(seq_len(n) * 10, each = n)
  )
}

test_that("pr_layout rejects bad grid dims", {
  expect_error(pr_layout(0, 4, matrix(TRUE, 4, 4), valid_coords()))
  expect_error(pr_layout(4, -1, matrix(TRUE, 4, 4), valid_coords()))
  expect_error(pr_layout(c(4, 5), 4, matrix(TRUE, 4, 4), valid_coords()))
})

test_that("pr_layout rejects non-logical active", {
  expect_error(pr_layout(4, 4, matrix(1, 4, 4), valid_coords()))
})

test_that("pr_layout rejects non-data-frame coords", {
  expect_error(pr_layout(4, 4, matrix(TRUE, 4, 4), coords_mm = list()))
})

test_that("pr_layout rejects missing coord columns", {
  bad <- valid_coords()[, c("sensor_id", "row")]
  expect_error(pr_layout(4, 4, matrix(TRUE, 4, 4), bad))
})

test_that("pr_layout rejects unnamed regions list", {
  expect_error(pr_layout(
    4, 4, matrix(TRUE, 4, 4), valid_coords(),
    regions = list(matrix(TRUE, 4, 4))
  ))
})

test_that("pr_layout rejects bad region dimensions", {
  expect_error(pr_layout(
    4, 4, matrix(TRUE, 4, 4), valid_coords(),
    regions = list(r1 = matrix(TRUE, 2, 2))
  ))
})

test_that("pr_layout rejects bad sensor_area and pressure_range", {
  expect_error(pr_layout(4, 4, matrix(TRUE, 4, 4), valid_coords(),
                         sensor_area_cm2 = -1))
  expect_error(pr_layout(4, 4, matrix(TRUE, 4, 4), valid_coords(),
                         pressure_range = 5))
})

test_that("pr_layout accepts a valid region and stores it", {
  reg <- list(zone = matrix(TRUE, 4, 4))
  lay <- pr_layout(4, 4, matrix(TRUE, 4, 4), valid_coords(), regions = reg)
  expect_equal(length(lay$regions), 1L)
})

test_that("summary.pr_layout reports area and regions", {
  s <- summary(pr_layout_saddle("horse"))
  expect_s3_class(s, "summary.pr_layout")
  expect_equal(s$n_regions, 6L)
  expect_invisible(print(s))
})

test_that("print.pr_layout handles a no-region layout", {
  expect_invisible(print(pr_layout_mat("16")))
})

test_that("plot.pr_layout draws regions and ids", {
  expect_s3_class(plot(pr_layout_saddle("horse")), "ggplot")
  expect_s3_class(plot(pr_layout_saddle("horse"), show_ids = TRUE), "ggplot")
  expect_s3_class(plot(pr_layout_mat("16"), show_regions = FALSE), "ggplot")
})

test_that("pr_validate_layout warns when a region covers inactive cells", {
  active <- matrix(c(TRUE, TRUE, TRUE, FALSE), 2, 2)
  coords <- data.frame(
    sensor_id = 1:3, row = c(1, 1, 2), col = c(1, 2, 1),
    x_mm = c(0, 10, 0), y_mm = c(0, 0, 10)
  )
  lay <- pr_layout(2, 2, active, coords,
                   regions = list(all = matrix(TRUE, 2, 2)))
  expect_warning(pr_validate_layout(lay))
})

test_that("pr_validate_layout rejects non-layout", {
  expect_error(pr_validate_layout(list()))
})
