# ---------------------------------------------------------------------------
# Ingest layer. The fixture is the first 200 data frames of a real
# Novel/Pliance saddle recording (ID052_K_K_KG00_MS.asc): latin-1, 7 header
# lines, 257 named columns plus a phantom column from the trailing tab.
#
# The reference values below were computed from the same 200 frames with an
# independent parser and, for the full 869-frame recording, agree to the last
# printed digit with the study's own `file_summary.rds`.
# ---------------------------------------------------------------------------

fixture <- function() test_path("fixtures", "ID052_K_K_KG00_MS.asc")

# The study's per-frame definitions, on whole-grid terms.
study_metrics <- function(p) {
  n_cells <- ncol(p)
  side <- sqrt(n_cells)
  grid_row <- rep(seq_len(side), times = side)   # column-major
  grid_col <- rep(seq_len(side), each = side)
  total <- rowSums(p)
  den <- total + 1e-12
  list(
    mean_kPa_avg  = mean(total / n_cells),
    mean_kPa_sd   = stats::sd(total / n_cells),
    peak_kPa_max  = max(p),
    peak_kPa_avg  = mean(apply(p, 1L, max)),
    total_kPa_avg = mean(total),
    loaded_avg    = mean(rowSums(p > 0)),
    cop_row_mean  = mean(as.vector(p %*% grid_row) / den),
    cop_col_mean  = mean(as.vector(p %*% grid_col) / den)
  )
}

# Write a minimal but format-faithful Pliance export (trailing tab included).
write_pliance <- function(path, mat, time = seq_len(nrow(mat)) / 50) {
  hdr <- c(
    "Dateiname:  synth.mat\tDatum/Zeit: 03.04.24 11.07",
    "Kalibrationsdatei:  synth_cal",
    paste0("gesamte Messzeit [Sek.]: ", sprintf("%.3f", max(time)),
           "\tZeit pro Bild [Sek.]:  0.02000\tMessfrequenz [Hz]:   50"),
    "Druckwerte in  kPa",
    "",
    "elektrisch:",
    paste(c("Zeit [Sek.]", seq_len(ncol(mat))), collapse = "\t")
  )
  body <- vapply(seq_len(nrow(mat)), function(i) {
    paste0(paste(c(sprintf("%.5f", time[i]), mat[i, ]), collapse = "\t"), "\t")
  }, character(1))
  writeLines(c(hdr, body), path)
  path
}

square_layout <- function() {
  pr_layout(
    2, 2, matrix(TRUE, 2, 2),
    data.frame(
      sensor_id = 1:4, row = c(1L, 2L, 1L, 2L), col = c(1L, 1L, 2L, 2L),
      x_mm = c(0, 0, 1, 1), y_mm = c(0, 1, 0, 1)
    ),
    name = "square2"
  )
}


# ---- pr_meta_from_filename ------------------------------------------------

test_that("pr_meta_from_filename splits a study file name into its cells", {
  fields <- c("ID", "Saddle", "Pad", "Weight", "Mode")
  out <- pr_meta_from_filename("raw/52_Bea/ID052_K_K_KG00_MS.asc", fields)

  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_equal(names(out), fields)
  expect_equal(out$ID, "ID052")
  expect_equal(out$Saddle, "K")
  expect_equal(out$Pad, "K")
  expect_equal(out$Weight, "KG00")
  expect_equal(out$Mode, "MS")
})

test_that("pr_meta_from_filename rejects names with the wrong part count", {
  fields <- c("ID", "Saddle", "Pad", "Weight", "Mode")

  # A repeat take carries a sixth part; the study excludes exactly these.
  expect_null(pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields))
  # Too few parts.
  expect_null(pr_meta_from_filename("ID003_K_K.asc", fields))
  # An empty part ("__") is not a field.
  expect_null(pr_meta_from_filename("ID003_K__KG60_MH.asc", fields))
})

test_that("pr_meta_from_filename honours on_fail", {
  fields <- c("ID", "Saddle", "Pad", "Weight", "Mode")

  na_row <- pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields,
                                  on_fail = "na")
  expect_equal(nrow(na_row), 1L)
  expect_equal(names(na_row), fields)
  expect_true(all(vapply(na_row, is.na, logical(1))))
  expect_type(na_row$ID, "character")

  expect_error(
    pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields,
                          on_fail = "error"),
    "does not split"
  )
})

test_that("pr_meta_from_filename honours a custom separator", {
  out <- pr_meta_from_filename("2024-05-01-walk.txt", c("y", "m", "d", "task"),
                               sep = "-")
  expect_equal(out$y, "2024")
  expect_equal(out$task, "walk")
  # The default separator does not split this name at all.
  expect_null(pr_meta_from_filename("2024-05-01-walk.txt",
                                    c("y", "m", "d", "task")))
})

test_that("pr_meta_from_filename validates its arguments", {
  expect_error(pr_meta_from_filename(c("a_b", "c_d"), c("x", "y")),
               "single, non-missing")
  expect_error(pr_meta_from_filename("a_b", character(0)), "character vector")
  expect_error(pr_meta_from_filename("a_b_c", c("x", "x", "y")), "unique")
  expect_error(pr_meta_from_filename("a_b", c("x", "y"), sep = ""),
               "non-empty")
})


# ---- pr_read_pliance: the real fixture ------------------------------------

test_that("pr_read_pliance reads the real export into a 200x256 trial", {
  trial <- pr_read_pliance(fixture())

  expect_s3_class(trial, "pr_trial")
  expect_equal(trial$n_frames, 200L)
  # 257 named columns minus the time column; the phantom column produced by
  # the trailing tab must be gone.
  expect_equal(trial$n_sensors, 256L)
  expect_equal(dim(trial$pressure), c(200L, 256L))
  expect_equal(trial$layout$n_sensors, 256L)
  expect_false(anyNA(trial$pressure))
  expect_true(all(trial$pressure >= 0))
  # Real hardware ceiling is 255 * 0.25 kPa.
  expect_lte(max(trial$pressure), 63.75)
})

test_that("pr_read_pliance uses the recorded time column", {
  trial <- pr_read_pliance(fixture())

  # The device stamps the first frame at one frame period, not at zero.
  expect_equal(trial$time[1], 0.02)
  expect_equal(trial$time[2], 0.04)
  expect_equal(trial$time[200], 4.00)
  expect_equal(trial$duration, 3.98)
  expect_equal(trial$sampling_hz, 50)
  # A synthesised 0-based sequence would have started at 0.
  expect_false(isTRUE(all.equal(trial$time[1], 0)))
})

test_that("pr_read_pliance reproduces the study's frame statistics", {
  trial <- pr_read_pliance(fixture())
  got <- study_metrics(trial$pressure)

  expect_equal(got$mean_kPa_avg,  1.6354980469, tolerance = 1e-9)
  expect_equal(got$mean_kPa_sd,   0.0272013729, tolerance = 1e-8)
  expect_equal(got$peak_kPa_max,  7)
  expect_equal(got$peak_kPa_avg,  6.8275, tolerance = 1e-9)
  expect_equal(got$total_kPa_avg, 418.6875, tolerance = 1e-9)
  expect_equal(got$loaded_avg,    93.305, tolerance = 1e-9)

  # PCI, as the study defines it.
  expect_equal(got$peak_kPa_avg / got$mean_kPa_avg, 4.1745693, tolerance = 1e-6)
})

test_that("pr_read_pliance places channels so the grid COP is correct", {
  trial <- pr_read_pliance(fixture())
  got <- study_metrics(trial$pressure)

  # These two depend on nothing but the channel permutation: read the raw
  # columns in device order and they come out as 4.94 / 7.46 instead.
  expect_equal(got$cop_row_mean, 7.4563498472, tolerance = 1e-8)
  expect_equal(got$cop_col_mean, 9.9747067535, tolerance = 1e-8)
  expect_equal(trial$metadata$channel_order_from, "layout")

  # pr_calc_cop() reads layout coords positionally against pressure columns;
  # on a unit-pitch grid layout it must agree with the grid centroid.
  cop <- pr_calc_cop(trial)
  expect_equal(mean(cop$y) + 1, got$cop_row_mean, tolerance = 1e-8)
  expect_equal(mean(cop$x) + 1, got$cop_col_mean, tolerance = 1e-8)
})

test_that("pr_read_pliance extracts the Pliance header block", {
  md <- pr_read_pliance(fixture())$metadata

  expect_equal(md$pressure_unit, "kPa")
  expect_equal(md$sampling_hz_header, 50)
  expect_equal(md$frame_period_s, 0.02)
  expect_equal(md$date, "16.02.23 13.22")
  expect_equal(md$source_name, "gelb_S2155_024_60kPa_PXF542_10.mat")
  expect_equal(md$calibration, "s2155_024_60kpa_t013")
  expect_equal(md$trial_id, "ID052_K_K_KG00_MS")
  expect_equal(md$n_frames_raw, 200L)
  expect_equal(md$n_frames_dropped, 0L)
})

test_that("pr_read_pliance lets the caller override header values", {
  trial <- pr_read_pliance(fixture(), sampling_hz = 10,
                           metadata = list(subject_id = "ID052",
                                           condition = "K_K_KG00_MS"))
  expect_equal(trial$sampling_hz, 10)
  expect_equal(trial$metadata$subject_id, "ID052")
  expect_equal(trial$metadata$condition, "K_K_KG00_MS")
  # The recorded timestamps are untouched by the override.
  expect_equal(trial$time[1], 0.02)
})


# ---- the channel permutation: single-hot negative controls ----------------

test_that("a single hot device channel lands on the right grid cell", {
  path <- withr::local_tempfile(fileext = ".asc")

  # One frame per device channel of interest; in frame i only channel
  # hot[i] carries pressure.
  hot <- c(1L, 8L, 9L, 16L, 17L, 256L)
  mat <- matrix(0, nrow = length(hot), ncol = 256)
  for (i in seq_along(hot)) mat[i, hot[i]] <- 10
  write_pliance(path, mat)

  trial <- pr_read_pliance(path)
  coords <- trial$layout$coords_mm

  cell_of <- function(i) {
    k <- which(trial$pressure[i, ] > 0)
    expect_length(k, 1L)
    c(coords$row[k], coords$col[k])
  }

  # This is the whole channel map in six assertions. Channel 1 is on the
  # RIGHT panel at grid (1, 9); channel 9 starts the LEFT panel, which runs
  # right-to-left, at (1, 8); each further 16 channels advance one grid row.
  expect_equal(cell_of(1), c(1L, 9L))    # channel 1
  expect_equal(cell_of(2), c(1L, 16L))   # channel 8  - end of right panel
  expect_equal(cell_of(3), c(1L, 8L))    # channel 9  - start of left panel
  expect_equal(cell_of(4), c(1L, 1L))    # channel 16 - end of left panel
  expect_equal(cell_of(5), c(2L, 9L))    # channel 17 - next row
  expect_equal(cell_of(6), c(16L, 1L))   # channel 256
})

test_that("without a channel map the columns stay in device order", {
  path <- withr::local_tempfile(fileext = ".asc")
  mat <- matrix(0, nrow = 1, ncol = 256)
  mat[1, 1] <- 10
  write_pliance(path, mat)

  # mat_16 is a plain 16x16 layout and carries no channel map.
  trial <- pr_read_pliance(path, layout = pr_layout_mat("16"))
  expect_equal(trial$metadata$channel_order_from, "device")
  expect_equal(which(trial$pressure[1, ] > 0), 1L)
  # Column 1 of a column-major grid is grid cell (1, 1) - the WRONG cell for
  # this device, which is exactly why a channel map is needed.
  expect_equal(trial$layout$coords_mm$col[1], 1L)
})

test_that("an explicit channel_map permutes the columns", {
  path <- withr::local_tempfile(fileext = ".asc")
  write_pliance(path, rbind(c(1, 2, 3, 4), c(5, 6, 7, 8)))

  # Entry [r, c] is the device channel sitting at grid cell (r, c).
  cmap <- rbind(c(2L, 1L), c(4L, 3L))
  trial <- pr_read_pliance(path, layout = square_layout(), channel_map = cmap)

  expect_equal(trial$metadata$channel_order_from, "channel_map")
  # as.vector(cmap) is column-major: c(2, 4, 1, 3).
  expect_equal(trial$pressure[1, ], c(2, 4, 1, 3))
  expect_equal(trial$pressure[2, ], c(6, 8, 5, 7))

  # A bare permutation vector is equivalent to the matrix form.
  trial2 <- pr_read_pliance(path, layout = square_layout(),
                            channel_map = as.vector(cmap))
  expect_equal(trial2$pressure, trial$pressure)

  # The identity map is a no-op.
  trial3 <- pr_read_pliance(path, layout = square_layout(),
                            channel_map = 1:4)
  expect_equal(trial3$pressure[1, ], c(1, 2, 3, 4))
})

test_that("pr_read_pliance rejects a malformed channel map", {
  path <- withr::local_tempfile(fileext = ".asc")
  write_pliance(path, rbind(c(1, 2, 3, 4)))
  lay <- square_layout()

  # Not a permutation.
  expect_error(pr_read_pliance(path, layout = lay, channel_map = c(1, 1, 2, 3)),
               "permutation")
  # Right values, wrong length.
  expect_error(pr_read_pliance(path, layout = lay, channel_map = 1:3),
               "sensor column")
  # Fractional channel numbers.
  expect_error(pr_read_pliance(path, layout = lay,
                               channel_map = c(1.5, 2, 3, 4)),
               "whole")
  # Matrix shape disagrees with the grid.
  expect_error(
    pr_read_pliance(path, layout = lay, channel_map = matrix(1:4, nrow = 1)),
    "grid"
  )
})


# ---- missing values -------------------------------------------------------

test_that("on_na drops or zeroes frames containing the '___' token", {
  path <- withr::local_tempfile(fileext = ".asc")
  mat <- matrix(as.character(c(1, 2, 3, 4,
                               5, 6, 7, 8,
                               9, 10, 11, 12)), nrow = 3, byrow = TRUE)
  mat[2, 3] <- "___"                     # one unread cell in frame 2
  write_pliance(path, mat, time = c(0.02, 0.04, 0.06))

  expect_warning(
    dropped <- pr_read_pliance(path, layout = square_layout()),
    "Dropped 1"
  )
  expect_equal(dropped$n_frames, 2L)
  expect_equal(dropped$time, c(0.02, 0.06))
  expect_equal(dropped$pressure[2, ], c(9, 10, 11, 12))
  expect_equal(dropped$metadata$n_frames_raw, 3L)
  expect_equal(dropped$metadata$n_frames_dropped, 1L)
  # The gap is preserved: timestamps are recorded, not renumbered.
  expect_equal(diff(dropped$time), 0.04)

  zeroed <- pr_read_pliance(path, layout = square_layout(), on_na = "zero")
  expect_equal(zeroed$n_frames, 3L)
  expect_equal(zeroed$pressure[2, ], c(5, 6, 0, 8))
  expect_equal(zeroed$metadata$n_frames_dropped, 0L)
})

test_that("pr_read_pliance aborts when every frame is missing", {
  path <- withr::local_tempfile(fileext = ".asc")
  mat <- matrix("___", nrow = 2, ncol = 4)
  write_pliance(path, mat, time = c(0.02, 0.04))
  expect_error(pr_read_pliance(path, layout = square_layout()),
               "Every frame")
})


# ---- pr_read_pliance: negative paths --------------------------------------

test_that("pr_read_pliance aborts on a missing file", {
  expect_error(pr_read_pliance(tempfile(fileext = ".asc")), "File not found")
})

test_that("pr_read_pliance aborts when the column count contradicts layout", {
  expect_error(
    pr_read_pliance(fixture(), layout = pr_layout_insole()),
    "256 sensor columns but layout"
  )
})

test_that("pr_read_pliance aborts when skip lands past the data", {
  # 207 lines in the fixture; skipping all of them leaves nothing to read.
  expect_error(pr_read_pliance(fixture(), skip = 400L), "No data rows")
})

test_that("pr_read_pliance validates its scalar arguments", {
  expect_error(pr_read_pliance(fixture(), skip = -1L), "non-negative")
  expect_error(pr_read_pliance(fixture(), sep = ""), "non-empty")
  expect_error(pr_read_pliance(fixture(), sampling_hz = 0), "positive")
  expect_error(pr_read_pliance(fixture(), time_col = 900), "column position")
  expect_error(pr_read_pliance(fixture(), metadata = "nope"), "named list")
  expect_error(pr_read_pliance(c(fixture(), fixture())), "single file path")
})

test_that("pr_read_pliance can synthesise time when told to", {
  path <- withr::local_tempfile(fileext = ".asc")
  write_pliance(path, rbind(c(1, 2, 3, 4), c(5, 6, 7, 8)))

  # time_col = NULL treats every column as a sensor, so use a 5-cell layout.
  lay <- pr_layout(
    1, 5, matrix(TRUE, 1, 5),
    data.frame(sensor_id = 1:5, row = rep(1L, 5), col = 1:5,
               x_mm = 0:4, y_mm = rep(0, 5)),
    name = "strip5"
  )
  trial <- pr_read_pliance(path, layout = lay, time_col = NULL)
  expect_equal(trial$time, c(0.02, 0.04))
  expect_equal(trial$n_sensors, 5L)
})


# ---- pr_read_dir ----------------------------------------------------------

make_dir <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  mat <- rbind(c(1, 2, 3, 4), c(5, 6, 7, 8))
  write_pliance(file.path(dir, "ID001_K_KG00.asc"), mat)
  write_pliance(file.path(dir, "ID002_W_KG40.asc"), mat)
  write_pliance(file.path(dir, "ID002_W_KG40_R01.asc"), mat)  # repeat take
  writeLines("not a pressure file", file.path(dir, "notes.txt"))
  dir
}

test_that("pr_read_dir reads matching files and reports the skips", {
  dir <- make_dir()
  ds <- pr_read_dir(dir, layout = square_layout(),
                    meta_fields = c("ID", "Saddle", "Weight"), quiet = TRUE)

  expect_s3_class(ds, "pr_dataset")
  expect_equal(length(ds), 2L)

  rep_tbl <- attr(ds, "read_report")
  expect_s3_class(rep_tbl, "tbl_df")
  # notes.txt does not match the pattern, so it is not a candidate at all.
  expect_equal(nrow(rep_tbl), 3L)
  expect_equal(sum(rep_tbl$status == "ok"), 2L)
  expect_equal(rep_tbl$file[rep_tbl$status == "skipped"],
               "ID002_W_KG40_R01.asc")
  expect_match(rep_tbl$reason[rep_tbl$status == "skipped"], "3 field")
})

test_that("pr_read_dir writes the name fields into trial metadata", {
  dir <- make_dir()
  ds <- pr_read_dir(dir, layout = square_layout(),
                    meta_fields = c("ID", "Saddle", "Weight"), quiet = TRUE)

  md <- ds$trials[[2]]$metadata
  expect_equal(md$ID, "ID002")
  expect_equal(md$Saddle, "W")
  expect_equal(md$Weight, "KG40")
  expect_equal(md$subject_id, "ID002")
  expect_equal(md$condition, "W_KG40")
  expect_equal(md$trial_id, "ID002_W_KG40")
})

test_that("pr_read_dir without meta_fields reads every matching file", {
  dir <- make_dir()
  ds <- pr_read_dir(dir, layout = square_layout(), quiet = TRUE)
  expect_equal(length(ds), 3L)
  expect_true(all(attr(ds, "read_report")$status == "ok"))
})

test_that("pr_read_dir skips unreadable files but keeps the rest", {
  dir <- make_dir()
  writeLines(c("junk", "junk"), file.path(dir, "ID003_K_KG60.asc"))

  ds <- pr_read_dir(dir, layout = square_layout(),
                    meta_fields = c("ID", "Saddle", "Weight"), quiet = TRUE)
  expect_equal(length(ds), 2L)
  rep_tbl <- attr(ds, "read_report")
  bad <- rep_tbl[rep_tbl$file == "ID003_K_KG60.asc", ]
  expect_equal(bad$status, "skipped")
  expect_true(nzchar(bad$reason))
})

test_that("pr_read_dir with on_error = 'abort' re-throws the first failure", {
  dir <- make_dir()
  writeLines(c("junk", "junk"), file.path(dir, "ID003_K_KG60.asc"))
  expect_error(
    pr_read_dir(dir, layout = square_layout(),
                meta_fields = c("ID", "Saddle", "Weight"),
                on_error = "abort", quiet = TRUE),
    "Failed to read"
  )
})

test_that("pr_read_dir reports counts unless quiet", {
  dir <- make_dir()
  expect_message(
    pr_read_dir(dir, layout = square_layout(),
                meta_fields = c("ID", "Saddle", "Weight")),
    "Read 2 files"
  )
  expect_silent(
    pr_read_dir(dir, layout = square_layout(),
                meta_fields = c("ID", "Saddle", "Weight"), quiet = TRUE)
  )
})

test_that("pr_read_dir warns when nothing matches", {
  dir <- withr::local_tempdir()
  expect_warning(ds <- pr_read_dir(dir, quiet = TRUE), "No files matching")
  expect_equal(length(ds), 0L)
  expect_equal(nrow(attr(ds, "read_report")), 0L)
})

test_that("pr_read_dir validates its arguments", {
  expect_error(pr_read_dir(tempfile()), "Directory not found")
  dir <- withr::local_tempdir()
  expect_error(pr_read_dir(dir, reader = "nope"), "must be a function")
  expect_error(pr_read_dir(dir, meta_fields = 1:3), "character vector")
  expect_error(pr_read_dir(dir, quiet = NA), "TRUE")
})

test_that("pr_read_dir reads the real export end to end", {
  dir <- withr::local_tempdir()
  file.copy(fixture(), file.path(dir, "ID052_K_K_KG00_MS.asc"))

  ds <- pr_read_dir(dir, meta_fields = c("ID", "Saddle", "Pad", "Weight", "Mode"),
                    quiet = TRUE)
  expect_equal(length(ds), 1L)

  trial <- ds$trials[[1]]
  expect_equal(trial$n_frames, 200L)
  expect_equal(trial$n_sensors, 256L)
  expect_equal(trial$metadata$Mode, "MS")
  expect_equal(trial$metadata$subject_id, "ID052")
  expect_equal(trial$metadata$condition, "K_K_KG00_MS")
  expect_equal(study_metrics(trial$pressure)$cop_col_mean, 9.9747067535,
               tolerance = 1e-8)
})
