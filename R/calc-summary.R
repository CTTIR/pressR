# ---------------------------------------------------------------------------
# Trial-level summary statistics.
# ---------------------------------------------------------------------------

#' Summarize Trial Pressure Parameters
#'
#' Computes a comprehensive set of pressure distribution parameters for
#' an entire trial. Returns a single-row tibble suitable for row-binding
#' across trials in batch analysis.
#'
#' @param trial A [pr_trial] object.
#' @param threshold Numeric. Threshold for "loaded" sensors. Default `0`.
#'
#' @return A one-row [tibble::tibble] with columns:
#'   - `mpp`: maximum peak pressure (measurement unit)
#'   - `mvp`: mean of per-frame mean pressures (measurement unit)
#'   - `max_force`: maximum total force (N)
#'   - `mean_force`: mean total force (N)
#'   - `max_contact_area`: maximum contact area (cm^2)
#'   - `mean_contact_area`: mean contact area (cm^2)
#'   - `contact_time`: total contact duration (s)
#'   - `pti_max`: maximum PTI across sensors (measurement unit*s)
#'   - `pti_mean`: mean PTI across loaded sensors (measurement unit*s)
#'   - `impulse`: force-time integral (N*s)
#'   - `cop_path_length`: total COP trajectory length (coordinate unit)
#'   - `cop_velocity_mean`: mean COP velocity (coordinate unit/s)
#'   - `cop_range_ap`: anterior-posterior COP range (coordinate unit)
#'   - `cop_range_ml`: medial-lateral COP range (coordinate unit)
#' @export
#' @examples
#' trial <- pr_example_trial("insole")
#' pr_summary(trial)
pr_summary <- function(trial, threshold = 0) {
  .validate_trial(trial)

  pp <- pr_calc_peak_pressure(trial, threshold)
  mp <- pr_calc_mean_pressure(trial, threshold)
  fr <- pr_calc_force(trial)
  ca <- pr_calc_contact_area(trial, threshold)
  pti <- pr_calc_pti(trial)
  cop <- pr_calc_cop(trial, threshold)

  out <- tibble::tibble(
    mpp = .safe_max(pp),
    mvp = if (any(mp > 0)) mean(mp[mp > 0]) else 0,
    max_force = .safe_max(fr),
    mean_force = .safe_mean(fr),
    max_contact_area = .safe_max(ca),
    mean_contact_area = .safe_mean(ca),
    contact_time = pr_calc_contact_time(trial, threshold),
    pti_max = max(pti, na.rm = TRUE),
    pti_mean = {
      loaded_pti <- pti[pti > 0]
      if (length(loaded_pti) > 0L) mean(loaded_pti) else 0
    },
    impulse = pr_calc_impulse(trial),
    cop_path_length = cop$path_length,
    cop_velocity_mean = cop$velocity_mean,
    cop_range_ap = cop$range_y,
    cop_range_ml = cop$range_x
  )
  attr(out, "units") <- .metric_units(trial)[names(out)]
  out
}

#' Symmetry Index
#'
#' Computes the symmetry index (SI%) between left and right sides of a
#' layout for a given parameter. `SI = (L - R) / (0.5 * (L + R)) * 100`.
#'
#' @param trial A [pr_trial] object.
#' @param parameter Character. One of `"peak_pressure"`, `"mean_pressure"`,
#'   `"force"`, `"contact_area"`. Default `"peak_pressure"`.
#'
#' @return Numeric scalar. Positive values indicate left dominance.
#' @export
#' @examples
#' pr_calc_symmetry_index(pr_example_trial("saddle_horse"))
pr_calc_symmetry_index <- function(trial,
                                   parameter = c(
                                     "peak_pressure",
                                     "mean_pressure",
                                     "force",
                                     "contact_area"
                                   )) {
  .validate_trial(trial)
  parameter <- match.arg(parameter)

  masks <- pr_mask_symmetry(trial$layout, axis = "vertical")
  reg <- pr_mask_apply(trial, masks)

  compute <- function(M) {
    if (ncol(M) == 0L) {
      return(0)
    }
    switch(parameter,
      peak_pressure = max(M, na.rm = TRUE),
      mean_pressure = mean(M[M > 0], na.rm = TRUE),
      force         = mean(rowSums(M)) * .force_scale(trial),
      contact_area  = mean(rowSums(M > 0)) * trial$layout$sensor_area_cm2
    )
  }
  L <- compute(reg$left)
  R <- compute(reg$right)
  if (is.na(L) || is.na(R)) {
    return(NA_real_)
  }
  if ((L + R) == 0) {
    return(0)
  }
  (L - R) / (0.5 * (L + R)) * 100
}
