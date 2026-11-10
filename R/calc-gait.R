#' Detect Gait Cycles from Foot Pressure Data
#'
#' Identifies heel-strike and toe-off events from the total force curve
#' of in-shoe or platform pressure data, segmenting the trial into
#' individual stance phases.
#'
#' @param trial A [pr_trial] object from an insole or platform recording.
#' @param force_threshold Numeric. Force threshold (N) for foot contact
#'   detection. Default `20`.
#' @param min_stance_ms Numeric. Minimum stance duration (ms). Shorter
#'   contacts are rejected. Default `200`.
#' @param min_swing_ms Numeric. Minimum swing duration (ms). Default `100`.
#'
#' @return A [tibble::tibble] with one row per detected cycle.
#' @export
#' @examples
#' cycles <- pr_calc_gait_cycles(pr_example_trial("insole"))
#' cycles
pr_calc_gait_cycles <- function(trial, force_threshold = 20,
                                min_stance_ms = 200, min_swing_ms = 100) {
  .validate_trial(trial)
  f <- pr_calc_force(trial)
  if (length(f) && !any(is.finite(f))) cli::cli_abort("Force-based gait detection requires a calibrated force measurement; use pressure stride analysis for an uncalibrated saddle mat.")
  t <- trial$time
  n <- length(f)

  if (n < 3L) {
    return(tibble::tibble(
      cycle = integer(0), heel_strike_frame = integer(0),
      toe_off_frame = integer(0),
      heel_strike_time = numeric(0), toe_off_time = numeric(0),
      stance_duration = numeric(0),
      start_frame = integer(0), end_frame = integer(0)
    ))
  }

  is_loaded <- f > force_threshold
  # Find transitions
  onsets <- which(!is_loaded[-n] & is_loaded[-1]) + 1L
  offsets <- which(is_loaded[-n] & !is_loaded[-1])

  # If trial starts loaded, add an onset at 1
  if (is_loaded[1]) onsets <- c(1L, onsets)
  # If trial ends loaded, add an offset at n
  if (is_loaded[n]) offsets <- c(offsets, n)

  # Pair onsets with next offset
  cycles <- list()
  for (i in seq_along(onsets)) {
    if (i > length(offsets)) break
    onset <- onsets[i]
    off <- offsets[offsets >= onset][1]
    if (is.na(off)) next
    dur_ms <- (t[off] - t[onset]) * 1000
    if (dur_ms < min_stance_ms) next
    cycles[[length(cycles) + 1L]] <- c(onset = onset, off = off)
  }

  if (length(cycles) == 0L) {
    return(tibble::tibble(
      cycle = integer(0), heel_strike_frame = integer(0),
      toe_off_frame = integer(0),
      heel_strike_time = numeric(0), toe_off_time = numeric(0),
      stance_duration = numeric(0),
      start_frame = integer(0), end_frame = integer(0)
    ))
  }

  # Enforce min swing between cycles
  filtered <- cycles[1]
  for (i in seq_along(cycles)[-1]) {
    prev_off <- filtered[[length(filtered)]][["off"]]
    cur_on <- cycles[[i]][["onset"]]
    swing_ms <- (t[cur_on] - t[prev_off]) * 1000
    if (swing_ms >= min_swing_ms) {
      filtered[[length(filtered) + 1L]] <- cycles[[i]]
    }
  }

  tibble::tibble(
    cycle             = seq_along(filtered),
    heel_strike_frame = vapply(filtered, function(x) as.integer(x[["onset"]]), integer(1)),
    toe_off_frame     = vapply(filtered, function(x) as.integer(x[["off"]]), integer(1)),
    heel_strike_time  = vapply(filtered, function(x) t[x[["onset"]]], numeric(1)),
    toe_off_time      = vapply(filtered, function(x) t[x[["off"]]], numeric(1)),
    stance_duration   = vapply(filtered, function(x) t[x[["off"]]] - t[x[["onset"]]], numeric(1)),
    start_frame       = vapply(filtered, function(x) as.integer(x[["onset"]]), integer(1)),
    end_frame         = vapply(filtered, function(x) as.integer(x[["off"]]), integer(1))
  )
}

#' Analyze COP Rollover Pattern
#'
#' Computes the center of pressure progression during the stance phase
#' of each gait cycle, resampled to percent of stance (0-100).
#'
#' @param trial A [pr_trial] object.
#' @param cycles Output of [pr_calc_gait_cycles()]. If `NULL`, cycles are
#'   detected automatically.
#' @param n_points Integer. Number of points to sample along each stance
#'   phase. Default `51`.
#'
#' @return A [tibble::tibble] with columns `cycle`, `percent_stance`,
#'   `cop_x`, `cop_y`, `cop_velocity` and `coordinate_unit`. Velocity uses
#'   the stated coordinate unit per second.
#' @export
#' @examples
#' trial <- pr_example_trial("insole")
#' rollover <- pr_calc_rollover(trial, n_points = 11)
#' head(rollover)
pr_calc_rollover <- function(trial, cycles = NULL, n_points = 51L) {
  .validate_trial(trial)
  .tp_check_scalar(n_points,"n_points")
  if(n_points<2 || n_points!=round(n_points)) cli::cli_abort("n_points must be an integer of at least two.")
  if (is.null(cycles)) cycles <- pr_calc_gait_cycles(trial)
  if (nrow(cycles) == 0L) {
    return(tibble::tibble(
      cycle = integer(0), percent_stance = numeric(0),
      cop_x = numeric(0), cop_y = numeric(0),
      cop_velocity = numeric(0), coordinate_unit=character()
    ))
  }

  cop <- pr_calc_cop(trial)
  t <- trial$time

  rows <- lapply(seq_len(nrow(cycles)), function(i) {
    idx <- cycles$start_frame[i]:cycles$end_frame[i]
    if (length(idx) < 2L) {
      return(NULL)
    }
    xs <- cop$x[idx]
    ys <- cop$y[idx]
    ts <- t[idx]
    if (all(is.na(xs))) {
      return(NULL)
    }
    pct <- (ts - ts[1]) / (ts[length(ts)] - ts[1]) * 100
    pts <- seq(0, 100, length.out = n_points)
    # Linear interpolation
    xi <- stats::approx(pct, xs, pts, rule = 2)$y
    yi <- stats::approx(pct, ys, pts, rule = 2)$y
    # Velocity
    vi <- c(0, sqrt(diff(xi)^2 + diff(yi)^2) /
      (diff(seq(0, 1, length.out = n_points) *
        (ts[length(ts)] - ts[1]))))
    tibble::tibble(
      cycle = rep(as.integer(i), n_points),
      percent_stance = pts,
      cop_x = xi,
      cop_y = yi,
      cop_velocity = vi, coordinate_unit=cop$coordinate_unit
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    return(tibble::tibble(
      cycle = integer(0), percent_stance = numeric(0),
      cop_x = numeric(0), cop_y = numeric(0),
      cop_velocity = numeric(0), coordinate_unit=character()
    ))
  }
  do.call(rbind, rows)
}
