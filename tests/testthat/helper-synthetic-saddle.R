# ---------------------------------------------------------------------------
# Ground truth of the synthetic saddle recording that the fixtures folder
# holds as synthetic_saddle_MS.asc.
#
# The fixture is an invented Novel/Pliance export: the same latin-1 file
# format and seven-line header as a real 16 x 16 saddle-mat export, with
# invented header values and pressures built here from a few designed
# components. Every value is a multiple of 0.25 kPa, the mat's resolution,
# and every product below is a small dyadic fraction, so the file is
# reproduced byte for byte on any platform. data-raw/synthetic_saddle.R
# writes the committed file with write_synthetic_saddle().
#
# Grid rows run cranial (1) to caudal (16); columns 1-8 are the left panel
# and 9-16 the right panel. The design gives the tests their edge cases:
#
# * a stride every 45 frames (0.90 s at 50 Hz) whose load peaks at frames
#   3, 48, 93, 138 and 183;
# * the left panel loses contact area, not intensity: its contact patch is
#   smaller than the right panel's, and its caudal third (rows 12-16) never
#   carries load;
# * stuck cells with a constant reading (low variance), a cell loaded in
#   two frames only (dead despite a high maximum), and cells that settle in
#   over the recording, so no two strides are identical;
# * nothing reaches the 63.75 kPa ceiling; the largest reading is 7 kPa.
# ---------------------------------------------------------------------------

synthetic_saddle_frames <- 200L
synthetic_saddle_period <- 45L
synthetic_saddle_first_peak <- 3L

# Frames at which the stride load peaks.
synthetic_saddle_peaks <- function(n = synthetic_saddle_frames) {
  seq(synthetic_saddle_first_peak, n, by = synthetic_saddle_period)
}

# Distance of each frame to the nearest stride peak, in frames.
synthetic_saddle_distance <- function(n = synthetic_saddle_frames) {
  peaks <- synthetic_saddle_peaks(n)
  peaks <- c(peaks, max(peaks) + synthetic_saddle_period)
  vapply(seq_len(n), function(i) min(abs(i - peaks)), numeric(1))
}

# Pulse weight by distance to the peak; zero from the end of the table on.
synthetic_saddle_pulse <- function(d, weights) {
  out <- numeric(length(d))
  inside <- d < length(weights)
  out[inside] <- weights[d[inside] + 1]
  out
}

# Spatial pattern of one component: a named list of cells and peak loads.
synthetic_saddle_pattern <- function(cells) {
  m <- matrix(0, 16, 16)
  m[cbind(cells$row, cells$col)] <- cells$kpa
  m
}

synthetic_saddle_components <- function() {
  # Cranial pressure points under the tree, on both panels.
  cranial <- synthetic_saddle_pattern(data.frame(
    row = c(3, 3, 3, 4, 4, 4, 5, 5, 5, 3, 3, 3, 4, 4, 4, 5, 5, 5),
    col = c(5, 6, 7, 5, 6, 7, 5, 6, 7, 10, 11, 12, 10, 11, 12, 10, 11, 12),
    kpa = c(
      3.5, 4.75, 3.25, 4.5, 6.5, 4.25, 3, 4, 2.75,
      3.75, 5, 3.5, 4.75, 7, 4.5, 3.25, 4.25, 3
    )
  ))
  # Middle contact: a narrow strip on the left, a wide one on the right.
  middle <- matrix(0, 16, 16)
  middle[6:9, 5:7] <- 2.5
  middle[6:11, 10:14] <- 2.5
  middle[7:8, 6] <- 3.25
  middle[7:9, 12] <- 3.5
  # Caudal load, right panel only.
  caudal <- matrix(0, 16, 16)
  caudal[12:15, 10:14] <- 2
  caudal[13, 11:13] <- c(4, 5.5, 4.25)
  caudal[14, 12] <- 4.5
  list(cranial = cranial, middle = middle, caudal = caudal)
}

# Stuck cells: a constant reading in every frame.
synthetic_saddle_stuck <- function() {
  data.frame(row = c(2, 2, 7, 10), col = c(13, 14, 16, 3), kpa = 2.75)
}

# Frame-by-cell pressure in grid cell order (column-major over the 16 x 16
# grid), as pr_read_pliance() returns it for the Novel saddle layout.
synthetic_saddle_grid <- function() {
  n <- synthetic_saddle_frames
  d <- synthetic_saddle_distance(n)
  # Sharp cranial impact, broad middle and caudal loading, all symmetric
  # about the stride peak; a quarter of each load is always present.
  a_cranial <- 0.25 + 0.75 * synthetic_saddle_pulse(d, c(1, 0.5, 0.25, 0.125))
  a_broad <- 0.25 + 0.75 * synthetic_saddle_pulse(
    d, c(1, 0.875, 0.75, 0.625, 0.5, 0.375, 0.25, 0.125)
  )
  comp <- synthetic_saddle_components()
  quarter <- function(x) floor(x * 4 + 0.5) / 4
  out <- matrix(0, n, 256)
  for (i in seq_len(n)) {
    m <- quarter(comp$cranial * a_cranial[i]) +
      quarter(comp$middle * a_broad[i]) +
      quarter(comp$caudal * a_broad[i])
    # Settling: two right-panel cells take up load in 0.25 kPa steps.
    m[8:9, 15] <- (i %/% 25) * 0.25
    stuck <- synthetic_saddle_stuck()
    m[cbind(stuck$row, stuck$col)] <- stuck$kpa
    # A transient contact in two frames on an otherwise unloaded cell.
    if (i %in% c(90L, 91L)) m[14, 15] <- 6.5
    out[i, ] <- as.vector(m)
  }
  out
}

# Grid cell (row, col) of Novel/Pliance device channel k: the right panel's
# eight channels come first in each row, then the left panel's, which runs
# right to left.
synthetic_saddle_channel_cell <- function(k) {
  pos <- (k - 1L) %% 16L
  cbind(
    row = (k - 1L) %/% 16L + 1L,
    col = ifelse(pos < 8L, 9L + pos, 8L - (pos - 8L))
  )
}

# Write the fixture: latin-1, seven header lines, a tab after every field.
write_synthetic_saddle <- function(path) {
  grid <- synthetic_saddle_grid()
  cells <- synthetic_saddle_channel_cell(1:256)
  # Column of the column-major grid that holds each device channel.
  device <- grid[, (cells[, "col"] - 1L) * 16L + cells[, "row"], drop = FALSE]
  n <- nrow(device)
  times <- seq_len(n) * 0.02
  header <- c(
    "Dateiname:  synthetic_saddle_example.mat\tDatum/Zeit: 01.01.00 00.00",
    "Kalibrationsdatei:  synthetic_calibration ",
    paste0(
      "gesamte Meßzeit [Sek.]: ", sprintf("%.3f", n * 0.02),
      "\tZeit pro Bild [Sek.]:  0.02000\tMeßfrequenz [Hz]:   50"
    ),
    "Druckwerte in  kPa",
    "",
    paste0("elektrisch: \t", paste(rep("  ___", 256), collapse = "\t"), "\t"),
    paste0(
      "Zeit [Sek.]    \t", paste(sprintf("%5d", 1:256), collapse = "\t"),
      "\t"
    )
  )
  body <- vapply(seq_len(n), function(i) {
    paste0(
      sprintf("%12.5f", times[i]), "\t",
      paste(sprintf("%.3f", device[i, ]), collapse = "\t"), "\t"
    )
  }, character(1))
  lines <- iconv(c(header, body), from = "UTF-8", to = "latin1")
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(lines, con, sep = "\n", useBytes = TRUE)
  invisible(path)
}
