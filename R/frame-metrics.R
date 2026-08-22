# ---------------------------------------------------------------------------
# Whole-grid per-frame metric vocabulary.
#
# The functions in calc-frame.R summarise the *loaded* cells of a frame
# (cells at or below `threshold` are dropped before averaging). That is the
# right convention for in-shoe and pedography work, where the sensor sheet is
# much larger than the foot.
#
# Saddle-mat cohorts use the opposite convention: the mat *is* the region of
# interest, so an unloaded cell is a real measurement of "no pressure here"
# and belongs in the denominator. This file provides those whole-grid
# counterparts, plus a single-pass frame table and the peak/mean
# concentration index built on them.
#
# Unit conventions:
#   pressure:  kPa, exactly as the device reports it
#   COP:       grid index units (row/col, 1-based), never millimetres
#
# No area conversion happens anywhere in this file: a cohort whose device
# never published a cell pitch has no defensible cm^2 or Newton value.
# ---------------------------------------------------------------------------

# Internal: TRUE when zeroing sub-threshold cells can change a value. With
# the default threshold of 0 on a non-negative matrix it cannot, and the
# copy is skipped -- worth doing on cohort-sized matrices.
.fm_needs_mask <- function(P, threshold) {
  length(P) > 0L && (threshold > 0 || any(P < 0, na.rm = TRUE))
}

# Internal: pressure matrix with sub-threshold cells zeroed.
.fm_weights <- function(P, threshold) {
  if (!.fm_needs_mask(P, threshold)) return(P)
  P[P <= threshold] <- 0
  P
}

# Internal: grid row/col of every pressure column, positionally.
.fm_grid_coords <- function(trial) {
  coords <- trial$layout$coords_mm
  if (nrow(coords) != ncol(trial$pressure)) {
    cli::cli_abort(
      "Layout has {nrow(coords)} coordinate row(s) but {.arg trial} has
       {ncol(trial$pressure)} pressure column(s)."
    )
  }
  # One n_sensors x 2 matrix so both COP axes come from a single matrix
  # product rather than two. Column 1 is the grid row, column 2 the grid
  # column; dimnames are dropped so a single-frame trial does not come back
  # with named COP values.
  unname(cbind(as.numeric(coords$row), as.numeric(coords$col)))
}

# Internal: row-wise maximum without an R-level loop.
.fm_row_max <- function(P) {
  n <- nrow(P)
  if (n == 0L) return(numeric(0))
  if (ncol(P) == 0L) return(rep(0, n))
  P[cbind(seq_len(n), max.col(P, ties.method = "first"))]
}

# Internal: validate a single finite numeric scalar argument.
.fm_check_scalar <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    cli::cli_abort("{.arg {arg}} must be a single finite number.")
  }
  invisible(x)
}

#' Whole-Grid Mean Pressure Per Frame
#'
#' Mean pressure across the entire sensor grid for each frame: the frame sum
#' divided by the number of sensors, with unloaded cells counted as zeros.
#'
#' @details
#' This is deliberately *not* the same quantity as [pr_calc_mean_pressure()],
#' which averages only the cells above `threshold` (loaded-cells-only, by
#' definition) and is left untouched. On a saddle mat where a typical frame
#' loads roughly 4% of the 256 cells, the loaded-cells-only mean is around
#' 25 times the whole-grid mean, so the two are never interchangeable. Use
#' this one when the mat itself is the region of interest and an unloaded
#' cell is a real "no pressure here" measurement; use
#' [pr_calc_mean_pressure()] when the sensor sheet is larger than the loaded
#' object and only the contact patch is meaningful.
#'
#' The denominator is `trial$layout$n_sensors`, i.e. the number of *active*
#' sensors, which equals `ncol(trial$pressure)`. Inactive grid cells are not
#' measurements and never enter the average.
#'
#' @param trial A [pr_trial] object.
#'
#' @return Numeric vector of length `n_frames`, in the trial's pressure unit.
#' @family whole-grid frame metrics
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' grid_mean <- pr_calc_mean_pressure_grid(trial)
#' loaded_mean <- pr_calc_mean_pressure(trial)
#' # The whole-grid mean is the smaller of the two by construction:
#' all(grid_mean <= loaded_mean + 1e-9)
pr_calc_mean_pressure_grid <- function(trial) {
  .validate_trial(trial)
  n <- trial$layout$n_sensors
  if (n == 0L) {
    cli::cli_abort("Layout {.val {trial$layout$name}} has no active sensors.")
  }
  rowSums(trial$pressure) / n
}

#' Total Pressure Per Frame
#'
#' Sum of all sensor readings in each frame.
#'
#' @details
#' The result is a sum of pressures (kPa), not a force. Converting it to
#' Newtons requires a per-cell area; [pr_calc_force()] does that using
#' `layout$sensor_area_cm2`. For devices whose cell pitch was never
#' published, `sensor_area_cm2` is `NA` and no force value is defensible —
#' hence this raw kPa sum, which is what the cohort analyses use. It is the
#' unscaled counterpart of [pr_calc_mean_pressure_grid()]
#' (`total / n_sensors`).
#'
#' @inheritParams pr_calc_mean_pressure_grid
#'
#' @return Numeric vector of length `n_frames`, summed pressure per frame.
#' @family whole-grid frame metrics
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' tot <- pr_calc_total_pressure(trial)
#' round(max(tot), 1)
pr_calc_total_pressure <- function(trial) {
  .validate_trial(trial)
  rowSums(trial$pressure)
}

#' Loaded Cell Count Per Frame
#'
#' Number of sensors reading strictly above `threshold` in each frame.
#'
#' @details
#' The count that [pr_calc_mean_pressure()] divides by, exposed on its own.
#' [pr_calc_loaded_rate()] returns the same information as a fraction of the
#' grid and [pr_calc_contact_area()] scales it by the cell area; this
#' function keeps it as a plain cell count, which is the form the cohort
#' summaries report because the device's cell area is unknown.
#'
#' @inheritParams pr_calc_mean_pressure_grid
#' @param threshold Numeric. Cells at or below this value count as unloaded.
#'   Default `0`.
#'
#' @return Integer vector of length `n_frames`.
#' @family whole-grid frame metrics
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' loaded <- pr_calc_loaded_count(trial)
#' max(loaded) <= trial$layout$n_sensors
pr_calc_loaded_count <- function(trial, threshold = 0) {
  .validate_trial(trial)
  .fm_check_scalar(threshold, "threshold")
  as.integer(rowSums(trial$pressure > threshold))
}

#' Center of Pressure in Grid Index Units
#'
#' Pressure-weighted centroid of each frame expressed in grid indices: a
#' `cop_row` of 1 is the first sensor row, a `cop_col` of 16 the sixteenth
#' sensor column. Row and col are read from the layout's coordinate table
#' positionally, so the result stays correct under any device channel
#' permutation applied by the reader.
#'
#' @details
#' [pr_calc_cop()] returns the same centroid in millimetres and gives `NA`
#' for frames with no load. This function is the index-unit counterpart used
#' when a device's physical sensor pitch was never published, so millimetre
#' coordinates would be fabricated. Instead of `NA`, an unloaded frame gets a
#' centroid of approximately `0` for both axes: `eps` is added to the weight
#' sum, so the quotient is `0 / eps` rather than `0 / 0`. That keeps the
#' output a complete, non-`NA` time series, and `cop_row == 0` is
#' unambiguous because a real centroid is always at least 1.
#'
#' Note also that the whole-grid metrics here differ from
#' [pr_calc_mean_pressure()], which is loaded-cells-only by definition.
#'
#' @inheritParams pr_calc_loaded_count
#' @param eps Numeric. Added to the weight sum to keep unloaded frames finite.
#'   Default `1e-12`.
#'
#' @return A [tibble::tibble] with one row per frame and columns `frame`
#'   (integer), `time_s`, `cop_row`, `cop_col` (grid index units).
#' @family whole-grid frame metrics
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' cop <- pr_calc_cop_grid(trial)
#' range(cop$cop_row)
pr_calc_cop_grid <- function(trial, threshold = 0, eps = 1e-12) {
  .validate_trial(trial)
  .fm_check_scalar(threshold, "threshold")
  .fm_check_scalar(eps, "eps")
  if (eps < 0) {
    cli::cli_abort("{.arg eps} must be non-negative, not {.val {eps}}.")
  }
  grid <- .fm_grid_coords(trial)
  W <- .fm_weights(trial$pressure, threshold)
  denom <- rowSums(W) + eps
  moment <- W %*% grid

  tibble::tibble(
    frame = seq_len(nrow(W)),
    time_s = as.numeric(trial$time),
    cop_row = moment[, 1L] / denom,
    cop_col = moment[, 2L] / denom
  )
}

#' Per-Frame Metric Table
#'
#' Computes the whole-grid frame vocabulary — mean, peak, total, loaded cell
#' count and grid-index centre of pressure — in a single vectorised pass over
#' the pressure matrix.
#'
#' @details
#' Every column is computed with whole-matrix operations — two `rowSums()`,
#' one `max.col()`, and a single matrix product carrying both COP axes.
#' There is no per-frame R loop, because cohort-scale inputs run to millions
#' of frames. Measured on a 200,000 x 256 matrix (R 4.6.1, one core):
#' about 145,000 frames per second, i.e. roughly 70 s for a 5.5 M-frame
#' cohort, against 73-83 s for the equivalent `vapply()` over rows. The
#' default `threshold = 0` also skips masking the matrix entirely when no
#' reading is negative, which saves a full copy of the pressure data.
#'
#' Column definitions:
#' * `mean_kPa` — `total_kPa / n_sensors`, whole grid, zeros included. This
#'   is **not** [pr_calc_mean_pressure()], which is loaded-cells-only by
#'   definition and is left unchanged; see [pr_calc_mean_pressure_grid()].
#' * `peak_kPa` — the plain row maximum, not filtered by `threshold`.
#' * `total_kPa` — the plain row sum, not filtered by `threshold`.
#' * `loaded` — count of cells strictly above `threshold`.
#' * `cop_row`, `cop_col` — grid index units, `eps` on the denominator so an
#'   unloaded frame gives approximately `0` rather than `NA`.
#'
#' `threshold` therefore affects `loaded` and the COP weighting only; peak
#' and total always describe the frame as recorded.
#'
#' @inheritParams pr_calc_cop_grid
#'
#' @return A [tibble::tibble] with `n_frames` rows and columns `frame`,
#'   `time_s`, `mean_kPa`, `peak_kPa`, `total_kPa`, `loaded`, `cop_row`,
#'   `cop_col`. Pressure columns carry the trial's own unit; the `kPa`
#'   suffixes follow the cohort naming convention.
#' @family whole-grid frame metrics
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' fm <- pr_frame_metrics(trial)
#' names(fm)
#' all.equal(fm$mean_kPa, fm$total_kPa / trial$layout$n_sensors)
pr_frame_metrics <- function(trial, threshold = 0, eps = 1e-12) {
  .validate_trial(trial)
  .fm_check_scalar(threshold, "threshold")
  .fm_check_scalar(eps, "eps")
  if (eps < 0) {
    cli::cli_abort("{.arg eps} must be non-negative, not {.val {eps}}.")
  }
  n_sensors <- trial$layout$n_sensors
  if (n_sensors == 0L) {
    cli::cli_abort("Layout {.val {trial$layout$name}} has no active sensors.")
  }
  grid <- .fm_grid_coords(trial)

  P <- trial$pressure
  total <- rowSums(P)
  peak <- .fm_row_max(P)
  loaded <- as.integer(rowSums(P > threshold))

  if (.fm_needs_mask(P, threshold)) {
    W <- .fm_weights(P, threshold)
    denom <- rowSums(W) + eps
  } else {
    W <- P
    denom <- total + eps
  }
  moment <- W %*% grid

  tibble::tibble(
    frame = seq_len(nrow(P)),
    time_s = as.numeric(trial$time),
    mean_kPa = total / n_sensors,
    peak_kPa = peak,
    total_kPa = total,
    loaded = loaded,
    cop_row = moment[, 1L] / denom,
    cop_col = moment[, 2L] / denom
  )
}

#' Peak/Mean Pressure Concentration Index
#'
#' Ratio of a recording's average frame peak to its average frame mean. A
#' PCI of 1 would mean a perfectly uniform mat; the larger the value, the
#' more of the load sits under a single hotspot.
#'
#' @details
#' `PCI = mean(peak_kPa) / mean(mean_kPa)` — a ratio of two per-recording
#' averages, not the average of a per-frame ratio; the two differ whenever
#' load varies over time, and the cohort summaries use the former.
#'
#' `denominator` selects which mean goes underneath:
#' * `"grid"` (default) uses [pr_calc_mean_pressure_grid()], the whole-grid
#'   mean including unloaded cells. This is the cohort definition and the
#'   one whose interpretation bands [pr_ref_pci()] documents.
#' * `"loaded"` uses the loaded-cells-only mean of [pr_calc_mean_pressure()],
#'   which is a different quantity — that function is loaded-cells-only by
#'   definition and is untouched here. Values come out roughly an order of
#'   magnitude smaller on a sparsely loaded mat, and [pr_ref_pci()] does
#'   **not** apply to them.
#'
#' `eps` guards the denominator so a recording with no load at all returns
#' `0` instead of `NaN`.
#'
#' @inheritParams pr_calc_mean_pressure_grid
#' @param denominator Character. `"grid"` (default) or `"loaded"`; see
#'   Details.
#' @param eps Numeric. Added to the mean-pressure denominator. Default
#'   `1e-12`.
#'
#' @return A single numeric value (dimensionless ratio).
#' @family whole-grid frame metrics
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' pr_calc_pci(trial)
#' # The loaded-cells-only denominator is larger, so the index is smaller:
#' pr_calc_pci(trial, denominator = "loaded") < pr_calc_pci(trial)
pr_calc_pci <- function(trial, denominator = c("grid", "loaded"),
                        eps = 1e-12) {
  .validate_trial(trial)
  denominator <- match.arg(denominator)
  .fm_check_scalar(eps, "eps")
  if (eps < 0) {
    cli::cli_abort("{.arg eps} must be non-negative, not {.val {eps}}.")
  }
  P <- trial$pressure
  if (nrow(P) == 0L) {
    cli::cli_abort("{.arg trial} has no frames.")
  }

  peak_avg <- mean(.fm_row_max(P))
  mean_avg <- if (denominator == "grid") {
    mean(pr_calc_mean_pressure_grid(trial))
  } else {
    cnt <- rowSums(P > 0)
    s <- .fm_weights(P, 0)
    mean(ifelse(cnt > 0L, rowSums(s) / pmax(cnt, 1L), 0))
  }
  peak_avg / (mean_avg + eps)
}

#' Pressure Concentration Index Interpretation Bands
#'
#' Working interpretation bands for the whole-grid PCI returned by
#' [pr_calc_pci()].
#'
#' @details
#' The first six columns match the other `pr_ref_*` tables
#' ([pr_ref_saddle()], [pr_ref_diabetic_foot()], [pr_ref_wheelchair()]), with
#' `threshold` holding the lower edge of each band; `band`, `band_min` and
#' `band_max` are appended so the interval can be used programmatically.
#' `band_max` is `Inf` for the open top band.
#'
#' Unlike the other reference tables, these bands are **not** taken from a
#' published clinical threshold study. They are the working ranges used to
#' describe whole-grid saddle-mat recordings, and they apply only to
#' `pr_calc_pci(trial, denominator = "grid")`. PCI is dimensionless and
#' scale-free in pressure, but it is *not* comparable across devices with
#' different grid sizes, because the whole-grid mean depends on how much
#' unloaded mat surrounds the contact patch.
#'
#' @return A [tibble::tibble] with columns `region`, `parameter`,
#'   `threshold`, `unit`, `interpretation`, `source`, `band`, `band_min`,
#'   `band_max`.
#' @family whole-grid frame metrics
#' @export
#' @examples
#' pr_ref_pci()
#' # Classify one recording:
#' pci <- pr_calc_pci(pr_example_trial("saddle_horse"))
#' ref <- pr_ref_pci()
#' ref$band[pci >= ref$band_min & pci < ref$band_max]
pr_ref_pci <- function() {
  tibble::tibble(
    region = "whole grid",
    parameter = "pci",
    threshold = c(3, 6, 10, 20),
    unit = "ratio",
    interpretation = c(
      "Good: 3-6, load spread broadly over the contact area.",
      "Moderate: 6-10, a distinct but tolerable concentration.",
      "Poor: 10-20, load concentrated on few cells.",
      "Very poor: above 20, load carried by an isolated hotspot."
    ),
    source = paste(
      "Working bands for whole-grid peak/mean concentration;",
      "not a published clinical threshold."
    ),
    band = c("good", "moderate", "poor", "very poor"),
    band_min = c(3, 6, 10, 20),
    band_max = c(6, 10, 20, Inf)
  )
}
