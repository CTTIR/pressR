test_that("reports explain calibration and units without rendering dependencies", {
  tr <- pr_example_trial("saddle_horse")
  info <- pr_report_info(tr)
  expect_identical(info$value[info$field == "measurement_unit"], "kPa")
  expect_identical(info$value[info$field == "sensor_area_cm2"], as.character(tr$layout$sensor_area_cm2))
  reg <- pressR:::.report_regional_table(tr)
  expect_true("max_force (N)" %in% names(reg))
  tr$layout$sensor_area_cm2 <- NA_real_
  tr$layout$coords_units <- "grid_index"
  expect_identical(pr_report_info(tr)$value[pr_report_info(tr)$field == "sensor_area_cm2"], "unknown")
  expect_true(all(is.na(pr_summary_long(tr)$value[pr_summary_long(tr)$parameter == "max_force"])))
})

test_that("pressure tables convert actual pressure units and reject force labels", {
  tr <- pr_example_trial("saddle_horse")
  pa <- tr
  pa$pressure <- tr$pressure * 1000
  pa$layout$pressure_unit <- "Pa"
  expect_equal(pr_frame_metrics(pa), pr_frame_metrics(tr), tolerance = 1e-8)
  expect_equal(pr_calc_regional_map(pa), pr_calc_regional_map(tr), tolerance = 1e-8)
  expect_equal(pr_calc_force(pa), pr_calc_force(tr), tolerance = 1e-8)
  pa$layout$pressure_unit <- "N"
  expect_error(pr_frame_metrics(pa), "force measurements")
  expect_equal(pr_calc_force(pa), rowSums(pa$pressure))
  expect_equal(pr_interpolate(tr)$coordinate_unit, "grid_index")
  expect_error(pr_interpolate(tr, 1.5), "integer")
  expect_error(pr_downsample(tr, NA_real_), "integer")
})

test_that("CSV timing, sensor identities, and source errors are explicit", {
  root <- withr::local_tempdir()
  p <- file.path(root, "data.csv")
  lay <- pr_layout_from_index_map(matrix(1:4, 2))
  expect_error(pr_read_csv(p), "not found")
  write.csv(data.frame(s4 = c(40, 41), s3 = c(30, 31), s2 = c(20, 21), s1 = c(10, 11), time = c(0, .1)), p, row.names = FALSE)
  tr <- pr_read_csv(p, layout = lay, verbose = FALSE)
  expect_equal(tr$pressure[1, ], c(10, 20, 30, 40))
  expect_error(pr_read_csv(p, layout = lay, time_col = "missing"), "not found")
  expect_error(pr_read_csv(p, layout = lay, sampling_hz = 50), "conflicts")
  d <- read.csv(p)
  d$s4 <- NULL
  write.csv(d, p, row.names = FALSE)
  expect_error(pr_read_csv(p, layout = lay), "identifiers")
  write.csv(data.frame(a = "invalid", b = 1, time = 0), p, row.names = FALSE)
  expect_error(pr_read_csv(p, layout = lay), "numeric")
  write.csv(data.frame(frame = 1, sensor_id = NA, pressure = 1), p, row.names = FALSE)
  expect_error(pr_read_csv(p, format = "long"), "missing")
  write.csv(data.frame(frame = c(1, 1), sensor_id = c(1, 2), pressure = 1, time = c(0, 1)), p, row.names = FALSE)
  expect_error(pr_read_csv(p, format = "long", layout = pr_layout_from_index_map(matrix(1:2, 1))), "exactly one")
  expect_error(pr_read_csv(p, format = "long", layout = lay), "identifiers")
  write.csv(data.frame(frame = 1, sensor_id = 1, pressure = "bad"), p, row.names = FALSE)
  expect_error(pr_read_csv(p, format = "long"), "numeric")
  write.csv(data.frame(a = 1, b = 2), p, row.names = FALSE)
  expect_error(pr_read_csv(p, format = "long"), "must contain")
  expect_error(pr_read_csv(p), "infer layout")
})

test_that("bundle manifest inconsistencies cannot override the actual trial", {
  root <- withr::local_tempdir()
  p <- file.path(root, "bundle")
  tr <- pr_example_trial("custom")
  expect_error(pr_read_bundle(p), "missing")
  expect_error(pr_write_bundle(tr, file.path(root, "missing", "bundle")), "parent")
  pr_write_bundle(tr, p)
  mf <- file.path(p, "manifest.json")
  m <- jsonlite::read_json(mf, simplifyVector = TRUE)
  write_manifest <- function(value) jsonlite::write_json(value, mf, auto_unbox = TRUE)
  bad <- m
  bad$version <- 99L
  write_manifest(bad)
  expect_error(pr_read_bundle(p), "Unsupported")
  bad <- m
  bad$sensor_ids <- rev(m$sensor_ids)
  write_manifest(bad)
  expect_error(pr_read_bundle(p), "disagrees")
  write_manifest(m)
  data <- readr::read_csv(file.path(p, "pressure.csv"), show_col_types = FALSE)
  data$frame[1] <- 1.5
  readr::write_csv(data, file.path(p, "pressure.csv"))
  m$sha256[["pressure.csv"]] <- digest::digest(file.path(p, "pressure.csv"), algo = "sha256", file = TRUE)
  write_manifest(m)
  expect_error(pr_read_bundle(p), "frame identifiers")
  expect_error(pressR:::.atomic_output(file.path(root, "missing", "out"), function(p) NULL), "does not exist")
  expect_error(pressR:::.atomic_output(file.path(root, "out"), function(p) NULL), "finalize")
})

test_that("temporal profiles state distinct assumptions on measured data", {
  tr <- pr_example_trial("saddle_horse")
  legacy <- pr_temporal_profile(tr, "legacy_method")
  expect_identical(legacy$settings$profile, "legacy_method")
  expect_equal(legacy$settings$spectrum_hz, 50)
  expect_equal(legacy$settings$phase_trim, 0)
  corrected <- pr_temporal_profile(tr)
  expect_equal(corrected$settings$phase_trim, .1)
  expect_false(corrected$settings$exact_reference_replay)
  short <- pr_filter_time(tr, 0, .5)
  expect_equal(nrow(pr_temporal_profile(short, "legacy_method")$cycles), 0)
  cy <- pr_calc_stride_cycles(tr)
  expect_error(pr_lock_cycles(tr, cy[setdiff(names(cy), "duration_s")]), "durations")
  if (nrow(cy) > 1) {
    cy$cycle[2] <- cy$cycle[1]
    expect_error(pr_lock_cycles(tr, cy), "uniquely")
  }
  expect_length(pressR:::.tp_find_peaks(1:2, 1, 0), 0)
})

test_that("workbook time assumptions and empty schemas are explicit", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  p <- withr::local_tempfile(fileext = ".xlsx")
  expect_error(pr_read_workbook(p), "does not exist")
  writexl::write_xlsx(data.frame(Time = c(.5, .75), `HR (bpm)` = c(60, 0), check.names = FALSE), p)
  x <- pr_read_workbook(p)
  expect_true(all(is.na(x$heart_rate$time_s)))
  expect_equal(pr_read_workbook(p, "excel_days")$heart_rate$time_s, c(43200, 64800))
  expect_equal(pr_read_workbook(p, "seconds")$heart_rate$time_s, c(.5, .75))
  expect_error(pr_read_workbook(p, "unknown"), "numeric_time_unit")
  expect_identical(x$heart_rate$valid_measurement, c(TRUE, FALSE))
  expect_error(pr_inventory(p), "directory")
  expect_error(pr_read_asset(paste0(p, "missing")), "existing file")
  expect_error(pr_link_assets(data.frame(), data.frame(), character()), "explicit")
  rec <- data.frame(recording_id = "r", id = "1")
  ass <- data.frame(asset_id = "a", id = "1")
  expect_false(pr_link_assets(rec, ass, "id")$duplicate_content)
  expect_error(pr_link_assets(rec, ass, "absent"), "missing")
  expect_error(pr_link_assets(rec, transform(ass, asset_id = NA), "id"), "unique")
})

test_that("provenance locks preserve dates, elapsed time and complex observations", {
  root <- withr::local_tempdir()
  path <- file.path(root, "typed.lock")
  x <- data.frame(
    date = as.Date(c("2026-01-01", "2026-01-02")),
    instant = as.POSIXct(c("2026-01-01 12:00:00", "2026-01-01 12:00:01"), tz = "UTC"),
    elapsed = as.difftime(c(1, 2), units = "hours"), z = c(1 + 2i, NA_complex_)
  )
  lock <- pr_lock_table(x, path)
  expect_true(as.logical(pr_verify_lock(x, path)))
  y <- x
  y$z[1] <- 1 + 3i
  expect_false(as.logical(suppressMessages(pr_verify_lock(y, path))))
  y <- x
  y$date[1] <- y$date[1] + 1
  expect_false(as.logical(suppressMessages(pr_verify_lock(y, path))))
  original <- readLines(path)
  writeLines(c(original, "nrow: 2"), path)
  expect_error(pr_verify_lock(x, path), "exactly one")
  writeLines(sub("nrow: 2", "nrow: 1.5", original, fixed = TRUE), path)
  expect_error(pr_verify_lock(x, path), "whole numbers")
  writeLines(sub("column: date\tDate", "column: date", original, fixed = TRUE), path)
  expect_error(pr_verify_lock(x, path), "column")
  names(x)[1] <- "bad\nname"
  expect_error(pr_lock_table(x, path), "newline")
  names(x)[1] <- ""
  expect_error(pr_lock_table(x, path), "name")
  expect_error(pr_lock_table(data.frame(x = 1), ""), "non-empty")
  expect_error(pr_validate_summary(data.frame(x = 1), hard = list(empty = function(x) logical())), "empty")
  expect_error(pr_validate_summary(data.frame(x = 1), hard = function(x) TRUE), "must be named")
  expect_error(pr_factor_contract(data.frame(x = "a"), list(x = NA_character_)), "all")
  expect_true(all(pr_factor_contract(data.frame(x = c("a", "b")), list(x = factor("a", levels = c("a", "b"))))$passed))
  expect_error(pr_factor_contract(data.frame(x = "a"), list(x = "a"), id_cols = 1), "character")
  expect_error(pr_design_gaps(data.frame(x = character()), "x"), "no levels")
  gaps <- pr_design_gaps(data.frame(x = factor(character(), levels = c("a", "b"))), "x")
  expect_equal(gaps$n, c(0L, 0L))
})

test_that("time analysis handles missing rates and explicit boundary cycles", {
  tr <- pr_example_trial("saddle_horse")
  inferred <- tr
  inferred$sampling_hz <- NA_real_
  expect_equal(pr_calc_spectrum(inferred), pr_calc_spectrum(tr), tolerance = 1e-8)
  inferred$time[3] <- inferred$time[3] + .001
  expect_error(pr_calc_spectrum(inferred), "regularly sampled")
  expect_error(pr_calc_spectrum(tr, signal = NA_character_), "single string")
  expect_error(pr_calc_stride_cycles(tr, hp_window_s = NA_real_), "finite")
  one <- pr_filter_time(tr, 0, 0)
  one$sampling_hz <- NA_real_
  expect_error(pressR:::.tp_fs(one), "usable sampling rate")
  p <- pr_trial(matrix(10, 10, tr$n_sensors), (0:9) / 50, tr$layout)
  cycles <- data.frame(start_idx = 1, end_idx = 10)
  expect_equal(pr_calc_phase_map(p, cycles = cycles, n_bins = 1)$mean_kPa, rep(10, p$n_sensors))
  expect_error(pr_calc_phase_map(p, cycles = data.frame(start_idx = "a", end_idx = 10)), "numeric")
  expect_length(pressR:::.tp_strict_peaks(c(1, 2), 1, 0), 0)
  expect_equal(pressR:::.tp_strict_peaks(c(0, 1, 0), 1, 0), 2L)
  expect_equal(pressR:::.tp_bandpass(c(1, 2), 50, 1, .001), c(0, 0))
})

test_that("batch summaries reject ambiguous metadata and empty recordings", {
  a <- pr_example_trial("custom")
  b <- a
  a$metadata$extra <- c("a", "b")
  b$metadata$extra <- "c"
  expect_error(pr_batch_frame_summary(list(a, b), meta_fields = "extra"), "single value")
  expect_false("extra" %in% names(pr_batch_frame_summary(list(a, b))))
  a$metadata$extra <- factor("a")
  b$metadata$extra <- "b"
  expect_identical(pr_batch_frame_summary(list(a, b), meta_fields = "extra")$extra, c("a", "b"))
  expect_error(pr_batch_frame_summary(list(a), meta_fields = NA_character_), "character vector")
  empty <- pr_trial(matrix(numeric(), 0, a$n_sensors), numeric(), a$layout)
  expect_error(pr_batch_frame_summary(list(empty)), "no frames")
  expect_error(pr_sensor_map(a, statistic = NA_character_), "one of")
})

test_that("rollover and gait detection handle incomplete stance data honestly", {
  tr <- pr_example_trial("insole")
  expect_error(pr_calc_rollover(tr, n_points = 1), "at least two")
  tr$layout$sensor_area_cm2 <- NA_real_
  expect_error(pr_calc_gait_cycles(tr), "calibrated")
  zero <- pr_example_trial("custom")
  zero$pressure[, ] <- 0
  cycles <- data.frame(start_frame = 1, end_frame = 5)
  expect_equal(nrow(pr_calc_rollover(zero, cycles)), 0)
  cycles$end_frame <- 1
  expect_equal(nrow(pr_calc_rollover(zero, cycles)), 0)
  loaded <- pr_example_trial("custom")
  loaded$pressure[, ] <- 100
  expect_equal(tail(pr_calc_gait_cycles(loaded)$end_frame, 1), loaded$n_frames)
  expect_equal(nrow(pr_calc_gait_cycles(loaded, min_stance_ms = 1e6)), 0)
  expect_s3_class(pr_plot_foot_report(loaded, masks = pr_mask_symmetry(loaded$layout)), "patchwork")
})

test_that("radiometric tags describe capability without inventing temperatures", {
  p <- withr::local_tempfile()
  writeLines("attachment", p)
  testthat::local_mocked_bindings(system2 = function(...) '[{"RawThermalImageWidth":320,"RawThermalImageHeight":240,"PlanckR1":1,"PlanckR2":1,"PlanckB":1,"PlanckF":1,"PlanckO":1}]', .package = "base")
  x <- pr_read_asset(p, exiftool = "fixture-exiftool")
  expect_true(x$radiometric_payload)
  expect_true(x$calibration_present)
  expect_identical(x$temperature_status, "requires_environment_and_radiometric_decoder")
  expect_identical(x$metadata_status, "read")
})

test_that("archive selection requires exact members and new destinations", {
  skip_if_not_installed("archive")
  root <- withr::local_tempdir()
  writeLines("fixture", file.path(root, "a.txt"))
  withr::with_dir(root, utils::tar("a.tar", files = "a.txt", tar = "internal"))
  archive <- file.path(root, "a.tar")
  expect_error(pr_extract_archive(archive, character(), file.path(root, "out")), "unique")
  expect_error(pr_extract_archive(archive, "missing", file.path(root, "out")), "missing")
  expect_error(pr_extract_archive(archive, "a.txt", root), "new")
  expect_error(pr_extract_archive(archive, "a.txt", file.path(root, "missing", "out")), "parent")
})

test_that("display interpolation keeps narrow grids and coordinate ordering", {
  lay <- pr_layout_from_index_map(matrix(1:2, 2, 1))
  tr <- pr_trial(matrix(c(2, 4), 1), 0, lay)
  out <- pr_interpolate(tr, 3)
  expect_equal(dim(out$pressure_interp), c(4, 1))
  expect_equal(out$pressure_interp[, 1], seq(2, 4, length.out = 4))
  lay <- pr_layout_from_index_map(matrix(1:2, 1, 2))
  tr <- pr_trial(matrix(c(2, 4), 1), 0, lay)
  expect_equal(dim(pr_interpolate(tr, 3)$pressure_interp), c(1, 4))
})
