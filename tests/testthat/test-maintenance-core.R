maintenance_layout <- function() {
  pr_layout(1, 2, matrix(TRUE, 1, 2),
    data.frame(sensor_id = 1:2, row = 1L, col = 1:2,
      x_mm = c(0, 10), y_mm = 0), sensor_area_cm2 = 1)
}

test_that("scientific entry points reject corrupted stored layout and trial fields", {
  trial <- pr_trial(matrix(c(10, 20, 30, 40), 2, byrow = TRUE),
    0:1, maintenance_layout())
  expect_equal(pr_calc_force(trial), c(3, 7))
  bad <- trial
  bad$layout$sensor_area_cm2 <- -1
  expect_error(pr_calc_force(bad), "sensor_area_cm2")
  bad <- trial
  bad$layout$active[1, 1] <- FALSE
  expect_error(pr_calc_cop(bad), "inactive|count")
  bad <- trial
  names(bad)[names(bad) == "pressure"] <- "pressure_backup"
  expect_error(pr_calc_force(bad), "required fields")
  bad <- trial
  bad$layout <- structure(c(bad$layout, list(sensor_area_cm2 = 1)), class = "pr_layout")
  expect_error(pr_calc_force(bad), "unique nonempty names")
  bad <- trial
  bad$duration <- 10
  expect_error(pr_calc_pti(bad), "duration")
  expect_identical(trial$pressure, matrix(c(10, 20, 30, 40), 2, byrow = TRUE))
})

test_that("layout identity and named metadata cannot silently change representation", {
  layout <- maintenance_layout()
  co <- layout$coords_mm
  co$sensor_id <- c(1.5, 2.5)
  expect_error(pr_layout(1, 2, layout$active, co), "identifiers")
  co$sensor_id <- c(20, 10)
  reordered <- pr_layout(1, 2, layout$active, co)
  expect_identical(reordered$coords_mm$sensor_id, c(20, 10))
  expect_error(pr_trial(matrix(1, 2, 2), 0:1, layout,
    metadata = list("unlabelled")), "Metadata")
  expect_error(pr_trial(matrix(1, 2, 2), 0:1, layout,
    metadata = list(trial_id = "a", trial_id = "b")), "Metadata")
  metadata <- list(subject_id = "001", acquisition = list(raw = TRUE))
  trial <- pr_trial(matrix(1, 2, 2), 0:1, layout, metadata)
  expect_identical(trial$metadata$acquisition, metadata$acquisition)
  expect_identical(trial$metadata$subject_id, "001")
})

test_that("measurement contracts retain supported empty and unknown calibration cases", {
  layout <- maintenance_layout()
  expect_error(pr_trial(matrix(1 + 1i, 2, 2), 0:1, layout), "numeric")
  expect_error(pr_trial(matrix(TRUE, 2, 2), 0:1, layout), "numeric")
  expect_error(pr_trial(matrix(1, 2, 2), matrix(0:1, 2), layout), "Timestamps")
  trial <- pr_trial(matrix(1L, 2, 2), 0:1, layout)
  trial$sampling_hz <- NA_real_
  expect_equal(pr_calc_force(trial), c(.2, .2))
  layout$sensor_area_cm2 <- NA_real_
  unknown <- pr_trial(matrix(1, 2, 2), 0:1, layout)
  expect_true(all(is.na(pr_calc_force(unknown))))
  empty <- pr_trial(matrix(numeric(), 0, 2), numeric(), layout)
  expect_identical(empty$n_frames, 0L)
  expect_identical(pr_calc_force(empty), numeric())
})

test_that("representable force, centroid and trapezoids survive large intermediates", {
  layout <- maintenance_layout()
  trial <- pr_trial(matrix(1e308, 2, 2), 0:1, layout)
  expect_equal(pr_calc_force(trial), rep(2e307, 2), tolerance = 1e-14)
  expect_equal(pr_calc_cop(trial)$x, rep(5, 2))
  expect_equal(pr_calc_cop(trial)$y, rep(0, 2))
  expect_equal(pr_calc_pti(trial), rep(1e308, 2), tolerance = 1e-14)
  expect_equal(pr_calc_impulse(trial), 2e307, tolerance = 1e-14)
  reg <- pr_calc_regional(trial, list(all = matrix(TRUE, 1, 2)),
    parameters = c("max_force", "pti_max"))
  expect_equal(reg$max_force, 2e307, tolerance = 1e-14)
  expect_equal(reg$pti_max, 1e308, tolerance = 1e-14)
  trial$layout$pressure_unit <- "N"
  expect_error(pr_calc_force(trial), "finite numeric range")
  ordinary <- pr_trial(matrix(c(1, 3, 2, 4, 5, 9), 3, 2), 0:2, layout)
  expect_identical(pr_calc_force(ordinary), rowSums(ordinary$pressure) * .1)
  expect_identical(pr_calc_pti(ordinary),
    colSums(.5 * (ordinary$pressure[-3, ] + ordinary$pressure[-1, ])))
  layout$coords_mm$x_mm <- c(1e-308, 2e-308)
  for (pressure in c(1e308, 1e-308)) {
    tiny_position <- pr_trial(matrix(pressure, 2, 2), 0:1, layout)
    # Scale before comparing: an absolute tolerance would accept zero here.
    expect_equal(pr_calc_cop(tiny_position)$x / 1e-308, c(1.5, 1.5), tolerance = 1e-14)
  }
  layout$sensor_area_cm2 <- 2^-1074
  layout$pressure_unit <- "Pa"
  tiny_area <- pr_trial(matrix(1e308, 2, 2), 0:1, layout)
  expect_error(pr_calc_force(tiny_area), "conversion underflows")
})

test_that("saddle bridge cannot infer a negative or positive result from missing masks", {
  trial <- pr_example_trial("saddle_horse")
  symmetry <- pr_calc_saddle_bridge(trial, pr_mask_symmetry(trial$layout))
  expect_true(is.na(symmetry$bridge_ratio))
  expect_true(is.na(symmetry$is_bridged))
  masks <- pr_mask_saddle_6(trial$layout)
  without_middle <- masks[!grepl("^middle", names(masks))]
  unavailable <- pr_calc_saddle_bridge(trial, without_middle)
  expect_true(is.na(unavailable$bridge_ratio))
  expect_true(is.na(unavailable$is_bridged))
  masks$middle_left <- matrix(FALSE, trial$layout$grid_rows, trial$layout$grid_cols)
  expect_true(is.na(pr_calc_saddle_bridge(trial, masks)$is_bridged))
})

test_that("text readers refuse unsafe conversions and preserve source identity", {
  layout <- maintenance_layout()
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  for (token in c("2.2250738585072014e-308", "4.9406564584124654e-324",
                  "1.7976931348623157e308", '" 1e-310 "')) {
    writeLines(c("time,s1,s2", paste0("0,", token, ",1"), "1,2,3"), path)
    expect_error(pr_read_csv(path, layout = layout, verbose = FALSE),
      "decimal range|conversion disagrees")
  }
  writeLines(c("time,s1,s2", "0,0.125,1e-27", "1,-2,3.5"), path)
  bytes <- readBin(path, "raw", file.info(path)$size)
  trial <- pr_read_csv(path, layout = layout, verbose = FALSE)
  expect_equal(trial$pressure, matrix(c(.125, 1e-27, -2, 3.5), 2, byrow = TRUE))
  expect_identical(trial$metadata$source_file, normalizePath(path, winslash = "/"))
  expect_identical(trial$metadata$source_filename, basename(path))
  expect_identical(trial$metadata$source_sha256, digest::digest(path, algo = "sha256", file = TRUE))
  expect_error(pr_export_csv(trial, path, "pressure"), "source")
  expect_identical(readBin(path, "raw", file.info(path)$size), bytes)
  writeLines(c("time,zone", "0,TRUE", "1,FALSE"), path)
  expect_error(pr_read_forcesensor(path, verbose = FALSE), "numeric measurements")
  writeLines(c("time,zone", "0,1", "1,2"), path)
  force <- pr_read_forcesensor(path, verbose = FALSE)
  expect_identical(force$metadata$source_file, normalizePath(path, winslash = "/"))
  expect_equal(pr_calc_force(force), c(1, 2))
  writeLines(c("1 2", "3 4"), path)
  ascii <- pr_read_ascii(path, layout = layout, skip = 0, verbose = FALSE)
  expect_identical(ascii$metadata$source_file, normalizePath(path, winslash = "/"))
  expect_equal(ascii$pressure, matrix(c(1, 2, 3, 4), 2, byrow = TRUE))
  writeLines(c("1e-310 2", "3 4"), path)
  expect_error(pr_read_ascii(path, layout = layout, skip = 0, verbose = FALSE), "decimal range")
  writeLines(c("0,000000000000000000000000001.5,1", "1,2,3"), path)
  expect_error(pr_read_pliance(path, layout = layout, skip = 0, sep = ","),
    "conversion disagrees")
  writeLines(c("0,broken,1", "1,2,3"), path)
  expect_error(pr_read_pliance(path, layout = layout, skip = 0, sep = ",", on_na = "zero"),
    "Malformed")
  writeLines(c("0,1,2", "1,2,3"), path)
  pliance <- pr_read_pliance(path, layout = layout, skip = 0, sep = ",",
    metadata = list(source_file = "unrelated.csv", source_sha256 = "incorrect"))
  expect_identical(pliance$metadata$source_file, normalizePath(path, winslash = "/"))
  expect_identical(pliance$metadata$source_sha256, digest::digest(path, algo = "sha256", file = TRUE))
  expect_error(pr_read_pliance(path, layout = layout, skip = .5, sep = ","), "integer")
  expect_error(pr_read_pliance(path, layout = layout, skip = 0, sep = ",", time_col = 1.5), "column position")
  layout$channel_order_backup <- 2:1
  retained <- pr_read_pliance(path, layout = layout, skip = 0, sep = ",")
  expect_equal(retained$pressure, matrix(c(1, 2, 2, 3), 2, byrow = TRUE))
  expect_identical(retained$metadata$channel_order_from, "device")
})

test_that("inferred CSV layouts retain declared sensor identity and geometry", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  ids <- 256:1
  wide <- as.data.frame(matrix(rep(ids, each = 2), 2))
  names(wide) <- paste0("s", ids)
  wide <- cbind(time = 0:1, wide)
  utils::write.csv(wide, path, row.names = FALSE)
  trial <- pr_read_csv(path, verbose = FALSE)
  expect_equal(unname(trial$pressure[1, ]), seq_len(256))
  expect_equal(pr_calc_cop(trial)$x,
    rep(sum(seq_len(256) * trial$layout$coords_mm$x_mm) / sum(seq_len(256)), 2))
  # Other wide labels deliberately retain the documented positional contract.
  names(wide)[-1] <- paste0("zone", ids)
  utils::write.csv(wide, path, row.names = FALSE)
  positional <- pr_read_csv(path, verbose = FALSE)
  expect_equal(unname(positional$pressure[1, ]), ids)
  long <- expand.grid(frame = 1:2, sensor_id = 1001:1099)
  long$pressure <- long$sensor_id
  utils::write.csv(long, path, row.names = FALSE)
  expect_error(pr_read_csv(path, verbose = FALSE), "sensor identifiers")
  long$sensor_id <- long$sensor_id - 1000
  utils::write.csv(long, path, row.names = FALSE)
  aligned <- pr_read_csv(path, verbose = FALSE)
  expect_equal(aligned$layout$coords_mm$sensor_id, seq_len(99))
  expect_equal(unname(aligned$pressure[1, ]), 1001:1099)
})
