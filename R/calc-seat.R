#' Identify Pressure Hotspots
#'
#' Finds sensors exceeding an exploratory pressure level. This descriptive
#' calculation is not a clinical risk classifier.
#'
#' @param trial A [pr_trial] from a seating recording.
#' @param threshold Numeric. Pressure threshold (kPa) above which a
#'   sensor is flagged. The legacy default `4.7` is an exploratory setting,
#'   not a validated tissue-injury or capillary-closing threshold.
#' @param duration_s Numeric. Minimum sustained duration (s) above
#'   threshold for a hotspot to be flagged. Default `0`.
#'
#' @return A [tibble::tibble] with columns `sensor_id`, `row`, `col`,
#'   `x_mm`, `y_mm`, `max_pressure`, `mean_pressure`, `duration_above_s`.
#' @export
#' @examples
#' pr_calc_seat_hotspot(pr_example_trial("wheelchair"))
pr_calc_seat_hotspot <- function(trial, threshold = 4.7, duration_s = 0) {
  .validate_trial(trial)
  coords <- trial$layout$coords_mm
  P <- trial$pressure
  t <- trial$time
  n_frames <- nrow(P)

  max_p <- apply(P, 2, max)
  mean_p <- apply(P, 2, mean)

  above <- P > threshold
  dur <- if (n_frames >= 2L) {
    dt <- diff(t)
    apply(above, 2, function(col) {
      mid <- col[-n_frames] & col[-1]
      sum(dt[mid])
    })
  } else {
    rep(0, ncol(P))
  }

  hotspot_idx <- which(max_p > threshold & dur >= duration_s)
  if (length(hotspot_idx) == 0L) {
    return(tibble::tibble(
      sensor_id = integer(0), row = integer(0), col = integer(0),
      x_mm = numeric(0), y_mm = numeric(0),
      max_pressure = numeric(0), mean_pressure = numeric(0),
      duration_above_s = numeric(0)
    ))
  }

  tibble::tibble(
    sensor_id = coords$sensor_id[hotspot_idx],
    row = coords$row[hotspot_idx],
    col = coords$col[hotspot_idx],
    x_mm = coords$x_mm[hotspot_idx],
    y_mm = coords$y_mm[hotspot_idx],
    max_pressure = max_p[hotspot_idx],
    mean_pressure = mean_p[hotspot_idx],
    duration_above_s = dur[hotspot_idx]
  )
}
