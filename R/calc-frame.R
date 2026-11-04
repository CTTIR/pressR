# ---------------------------------------------------------------------------
# Per-frame analysis functions.
#
# Each function operates on a pr_trial and returns a numeric vector of
# length n_frames (or a list / pr_cop object for center-of-pressure).
#
# Unit conventions:
#   pressure:  kPa (= 1000 N/m^2)
#   area:      cm^2
#   force:     N     (pressure_kPa * area_cm2 * 0.1 because
#                     1 kPa * 1 cm^2 = 1000 N/m^2 * 1e-4 m^2 = 0.1 N)
# ---------------------------------------------------------------------------

#' Calculate Peak Pressure Per Frame
#'
#' Returns the maximum pressure across all active sensors for each frame.
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Sensors at or below this value are treated
#'   as unloaded and excluded. Default `0`.
#'
#' @return Numeric vector of length `n_frames`.
#' @export
#' @examples
#' trial <- pr_example_trial("insole")
#' pp <- pr_calc_peak_pressure(trial)
#' length(pp) == trial$n_frames
pr_calc_peak_pressure <- function(trial, threshold = 0) {
  .validate_trial(trial)
  P <- trial$pressure
  vapply(seq_len(nrow(P)), function(i) {
    row <- P[i, ]
    loaded <- row[row > threshold]
    if (length(loaded) == 0L) 0 else max(loaded)
  }, numeric(1))
}

#' Calculate Mean Pressure Per Frame
#'
#' Mean of loaded sensors per frame (sensors at or below `threshold`
#' are excluded).
#'
#' @inheritParams pr_calc_peak_pressure
#' @return Numeric vector of length `n_frames`.
#' @export
pr_calc_mean_pressure <- function(trial, threshold = 0) {
  .validate_trial(trial)
  P <- trial$pressure
  vapply(seq_len(nrow(P)), function(i) {
    row <- P[i, ]
    loaded <- row[row > threshold]
    if (length(loaded) == 0L) 0 else mean(loaded)
  }, numeric(1))
}

#' Calculate Total Force Per Frame
#'
#' Force in Newtons equals sum(pressure * sensor_area). With pressure in
#' kPa and area in cm^2, force\[N\] = sum(p_kPa * a_cm2) * 0.1.
#' When the unscaled sum overflows, conversion is applied before summation.
#' Results outside the finite numeric range are refused; unknown calibration
#' continues to produce `NA`.
#'
#' @param trial A [pr_trial] object.
#' @return Numeric vector of length `n_frames`.
#' @export
pr_calc_force <- function(trial) {
  .validate_trial(trial)
  .force_rows(trial$pressure, trial)
}

#' Calculate Contact Area Per Frame
#'
#' Number of sensors above `threshold` times the per-sensor area (cm^2).
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Default `0`.
#'
#' @return Numeric vector of contact area (cm^2) per frame.
#' @export
pr_calc_contact_area <- function(trial, threshold = 0) {
  .validate_trial(trial)
  a <- trial$layout$sensor_area_cm2
  rowSums(trial$pressure > threshold) * a
}

#' Calculate Fraction of Loaded Sensors Per Frame
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Default `0`.
#'
#' @return Numeric vector in `[0, 1]` of length `n_frames`.
#' @export
pr_calc_loaded_rate <- function(trial, threshold = 0) {
  .validate_trial(trial)
  n <- trial$layout$n_sensors
  rowSums(trial$pressure > threshold) / n
}

#' Calculate Center of Pressure
#'
#' Computes the pressure-weighted centroid of active sensors for each
#' frame. Frames with no loaded sensors return `NA` for x and y.
#' Overflowing weighted sums are evaluated with bounded weights and coordinates.
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Sensors at or below are treated as unloaded.
#'   Default `0`.
#'
#' @return A [pr_cop] object containing x, y, the layout coordinate unit, time (s), and
#'   derived metrics.
#' @export
#' @examples
#' cop <- pr_calc_cop(pr_example_trial("saddle_horse"))
#' print(cop)
pr_calc_cop <- function(trial, threshold = 0) {
  .validate_trial(trial)
  coords <- trial$layout$coords_mm
  P <- trial$pressure
  x <- rep(NA_real_, nrow(P))
  y <- rep(NA_real_, nrow(P))

  xs <- coords$x_mm
  ys <- coords$y_mm

  for (i in seq_len(nrow(P))) {
    row <- P[i, ]
    row[row <= threshold] <- 0
    s <- sum(row)
    if (s > 0) {
      x[i] <- .weighted_coordinate(row, xs, s)
      y[i] <- .weighted_coordinate(row, ys, s)
    }
  }
  out <- pr_cop(x, y, trial$time)
  out$coordinate_unit <- .coordinate_unit(trial$layout)
  out
}

#' Pressure-Time Integral Per Sensor
#'
#' Integrates pressure over time for each sensor using the trapezoidal
#' rule. Result is in the measurement unit multiplied by seconds.
#' Overflowing endpoint sums use a finite midpoint calculation. Unrepresentable
#' interval areas or totals raise an error instead of returning infinity.
#'
#' @param trial A [pr_trial] object.
#'
#' @return Numeric vector of length `n_sensors`.
#' @export
pr_calc_pti <- function(trial) {
  .validate_trial(trial)
  t <- trial$time
  P <- trial$pressure
  if (nrow(P) < 2L) {
    return(rep(0, ncol(P)))
  }

  .integrate_pressure(P, t)
}

#' Force-Time Integral (Impulse)
#'
#' Integrates total force over time. Result is in N*s.
#'
#' @param trial A [pr_trial] object.
#'
#' @return Numeric scalar.
#' @export
pr_calc_impulse <- function(trial) {
  .validate_trial(trial)
  f <- pr_calc_force(trial)
  t <- trial$time
  if (length(t) < 2L) {
    return(0)
  }
  if (anyNA(f)) return(NA_real_)
  area <- .finite_midpoint(f[-length(f)], f[-1]) * diff(t)
  .finite_metric(sum(.finite_metric(area, "Impulse interval")), "Impulse")
}

#' Total Contact Time
#'
#' Duration for which at least one sensor exceeds `threshold`.
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Default `0`.
#'
#' @return Numeric scalar (s).
#' @export
pr_calc_contact_time <- function(trial, threshold = 0) {
  .validate_trial(trial)
  any_load <- rowSums(trial$pressure > threshold) > 0
  if (!any(any_load) || length(trial$time) < 2L) {
    return(0)
  }
  # Use bin widths (dt) to estimate contact duration
  dt <- diff(trial$time)
  mid_loaded <- any_load[-1] & any_load[-length(any_load)]
  sum(dt[mid_loaded]) +
    sum(dt[any_load[-length(any_load)] & !mid_loaded]) * 0 # keep simple
}

#' Total COP Path Length
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Default `0`.
#'
#' @return Numeric scalar in the layout coordinate unit.
#' @export
pr_calc_cop_path <- function(trial, threshold = 0) {
  pr_calc_cop(trial, threshold)$path_length
}

#' COP Excursion (Anterior-Posterior and Medial-Lateral Range)
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Default `0`.
#'
#' @return Named numeric vector with `ap` (y-range) and `ml` (x-range),
#'   both in the layout coordinate unit.
#' @export
pr_calc_cop_excursion <- function(trial, threshold = 0) {
  cop <- pr_calc_cop(trial, threshold)
  c(ap = cop$range_y, ml = cop$range_x)
}
