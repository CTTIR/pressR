# Tests for parser branches in R/read-*.R not exercised by test-read.R:
# auto-dispatch error/mask arms, layout inference, padding/truncation,
# verbose paths, long-format CSV, and force-sensor validation.

test_that("pr_read_auto errors on unknown extension", {
  tmp <- withr::local_tempfile(fileext = ".xyz")
  writeLines("1 2 3", tmp)
  expect_error(pr_read_auto(tmp, verbose = FALSE))
})

test_that("pr_read_auto errors on missing file", {
  expect_error(pr_read_auto("/no/such/file.asc"))
})

test_that("pr_read_auto dispatches mask extensions", {
  tmp <- withr::local_tempfile(fileext = ".msr")
  writeLines(c("1 0 1", "0 1 0"), tmp)
  m <- pr_read_auto(tmp, verbose = FALSE)
  expect_true(is.logical(m))
})

test_that("pr_read_ascii errors on empty file", {
  tmp <- withr::local_tempfile(fileext = ".asc")
  file.create(tmp)
  expect_error(pr_read_ascii(tmp))
})

test_that("pr_read_ascii errors when no numeric data detected", {
  tmp <- withr::local_tempfile(fileext = ".asc")
  writeLines(c("header only", "no numbers here"), tmp)
  expect_error(pr_read_ascii(tmp))
})

test_that("pr_read_ascii infers layout from sensor count and is verbose", {
  layout <- pr_layout_mat("16")  # 256 sensors -> mat_16
  P <- matrix(round(runif(3 * 256, 0, 50), 1), nrow = 3, ncol = 256)
  tmp <- withr::local_tempfile(fileext = ".asc")
  utils::write.table(P, tmp, sep = "\t", row.names = FALSE, col.names = FALSE)
  expect_message(
    trial <- pr_read_ascii(tmp, verbose = TRUE),
    "frame"
  )
  expect_equal(trial$layout$n_sensors, 256L)
})

test_that("pr_read_ascii pads short matrices to the layout width", {
  # 90 columns but insole layout has 99 -> padding path with warning
  P <- matrix(round(runif(3 * 90, 0, 10), 1), nrow = 3, ncol = 90)
  tmp <- withr::local_tempfile(fileext = ".asc")
  utils::write.table(P, tmp, sep = "\t", row.names = FALSE, col.names = FALSE)
  expect_warning(
    trial <- pr_read_ascii(tmp, layout = pr_layout_insole(), verbose = TRUE)
  )
  expect_equal(trial$n_sensors, 99L)
})

test_that("pr_read_ascii truncates wide matrices to the layout width", {
  P <- matrix(round(runif(3 * 40, 0, 10), 1), nrow = 3, ncol = 40)
  tmp <- withr::local_tempfile(fileext = ".asc")
  utils::write.table(P, tmp, sep = "\t", row.names = FALSE, col.names = FALSE)
  expect_warning(
    trial <- pr_read_ascii(tmp, layout = pr_layout_glove(), verbose = TRUE)
  )
  expect_equal(trial$n_sensors, 32L)
})

test_that("pr_read_ascii errors when layout cannot be inferred", {
  P <- matrix(round(runif(2 * 7, 0, 10), 1), nrow = 2, ncol = 7)
  tmp <- withr::local_tempfile(fileext = ".asc")
  utils::write.table(P, tmp, sep = "\t", row.names = FALSE, col.names = FALSE)
  expect_error(pr_read_ascii(tmp, verbose = FALSE))
})

test_that("pr_read_csv reads long format", {
  long <- data.frame(
    frame = rep(1:3, each = 4),
    sensor_id = rep(1:4, times = 3),
    pressure = round(runif(12, 0, 30), 2)
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(long, tmp, row.names = FALSE)
  layout <- pr_layout(2, 2, matrix(TRUE, 2, 2),
                      data.frame(sensor_id = 1:4, row = c(1, 1, 2, 2),
                                 col = c(1, 2, 1, 2),
                                 x_mm = c(0, 10, 0, 10),
                                 y_mm = c(0, 0, 10, 10)))
  trial <- pr_read_csv(tmp, format = "long", layout = layout, verbose = FALSE)
  expect_equal(trial$n_frames, 3L)
  expect_equal(trial$n_sensors, 4L)
})

test_that("pr_read_csv long format errors on missing columns", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(a = 1, b = 2), tmp, row.names = FALSE)
  expect_error(pr_read_csv(tmp, format = "long"))
})

test_that("pr_read_csv wide format errors on column/layout mismatch", {
  m <- matrix(runif(2 * 5), nrow = 2)
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(m, tmp, row.names = FALSE)
  expect_error(pr_read_csv(tmp, format = "wide", layout = pr_layout_glove(),
                           verbose = FALSE))
})

test_that("pr_read_csv wide errors when layout cannot be inferred", {
  m <- matrix(runif(2 * 7), nrow = 2)
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(m, tmp, row.names = FALSE)
  expect_error(pr_read_csv(tmp, format = "wide", verbose = FALSE))
})

test_that("pr_read_csv generates time when no time_col", {
  m <- matrix(runif(4 * 99), nrow = 4)
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(m, tmp, row.names = FALSE)
  trial <- pr_read_csv(tmp, format = "wide", layout = pr_layout_insole(),
                       sampling_hz = 50, verbose = FALSE)
  expect_equal(trial$time, seq(0, by = 1 / 50, length.out = 4))
})

test_that("pr_read_forcesensor errors on missing time column", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(a = 1:3, b = 4:6), tmp, row.names = FALSE)
  expect_error(pr_read_forcesensor(tmp, verbose = FALSE))
})

test_that("pr_read_forcesensor errors on missing force columns", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(time = 1:3, heel = 4:6), tmp, row.names = FALSE)
  expect_error(
    pr_read_forcesensor(tmp, force_cols = c("heel", "toe"), verbose = FALSE)
  )
})

test_that("pr_read_forcesensor is verbose and uses N units", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(time = seq(0, 0.1, by = 0.02),
               heel = runif(6, 0, 100), fore = runif(6, 0, 100)),
    tmp, row.names = FALSE
  )
  expect_message(
    trial <- pr_read_forcesensor(tmp, verbose = TRUE),
    "zone"
  )
  expect_equal(trial$layout$pressure_unit, "N")
})

test_that("pr_read_mask errors on non-numeric content", {
  tmp <- withr::local_tempfile(fileext = ".msa")
  writeLines(c("alpha beta", "gamma delta"), tmp)
  expect_error(pr_read_mask(tmp, verbose = FALSE))
})

test_that("pr_read_mask errors on missing file", {
  expect_error(pr_read_mask("/no/such/mask.msa"))
})

test_that("pr_read_mask pads ragged rows and is verbose", {
  tmp <- withr::local_tempfile(fileext = ".msa")
  writeLines(c("1 1 0 0", "1 1", "0 0 1 1"), tmp)
  expect_message(m <- pr_read_mask(tmp, verbose = TRUE), "dimensions")
  expect_equal(dim(m), c(3L, 4L))
})

test_that("pr_read_mask returns pr_mask when layout supplied", {
  layout <- pr_layout(2, 2, matrix(TRUE, 2, 2),
                      data.frame(sensor_id = 1:4, row = c(1, 1, 2, 2),
                                 col = c(1, 2, 1, 2),
                                 x_mm = c(0, 10, 0, 10),
                                 y_mm = c(0, 0, 10, 10)))
  tmp <- withr::local_tempfile(fileext = ".msa")
  writeLines(c("1 0", "0 1"), tmp)
  m <- pr_read_mask(tmp, layout = layout, verbose = FALSE)
  expect_s3_class(m, "pr_mask")
})

test_that("pr_read_mask errors on layout dimension mismatch", {
  tmp <- withr::local_tempfile(fileext = ".msa")
  writeLines(c("1 0 1", "0 1 0"), tmp)
  expect_error(
    pr_read_mask(tmp, layout = pr_layout_saddle("horse"), verbose = FALSE)
  )
})
