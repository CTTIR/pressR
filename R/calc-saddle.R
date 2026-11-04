#' Detect Saddle Bridge Formation
#'
#' Identifies "bridging" — a saddle fit problem where the middle region is
#' unloaded while cranial and caudal regions carry excessive pressure.
#' Bridging is quantified as the ratio of middle-region pressure to the
#' mean of cranial and caudal pressures.
#'
#' @param trial A [pr_trial] from a horse saddle recording.
#' @param masks Named list of 6 region masks (from [pr_mask_saddle_6()]).
#'   If `NULL`, generated from the trial's layout.
#' @param bridge_threshold Numeric. Middle/ends ratio below this value
#'   indicates bridging. Default `0.5`.
#'
#' @return A list with class `pr_saddle_bridge`:
#'   - `bridge_ratio`: middle / mean(cranial, caudal) MVP ratio.
#'   - `is_bridged`: logical, or `NA` when any required region is absent,
#'     contains no active sensors, or the end pressure is not positive.
#'   - `regional_pressures`: tibble with MVP per region.
#'   - `recommendation`: character.
#' @export
#' @examples
#' pr_calc_saddle_bridge(pr_example_trial("saddle_horse"))
pr_calc_saddle_bridge <- function(trial, masks = NULL,
                                  bridge_threshold = 0.5) {
  .validate_trial(trial)
  .tp_check_scalar(bridge_threshold, "bridge_threshold")
  if (is.null(masks)) masks <- pr_mask_saddle_6(trial$layout)

  reg <- pr_calc_regional(trial, masks, parameters = "mvp")

  get_mvp <- function(prefix) {
    idx <- grepl(paste0("^", prefix), reg$region)
    if (!any(idx) || any(vapply(masks[reg$region[idx]], function(mask) {
      length(.mask_to_cols(mask, trial$layout)) == 0L
    }, logical(1)))) return(NA_real_)
    mean(reg$mvp[idx])
  }
  cranial <- get_mvp("cranial")
  middle  <- get_mvp("middle")
  caudal  <- get_mvp("caudal")

  end_mean <- mean(c(cranial, caudal))
  ratio <- if (is.finite(end_mean) && end_mean > 0 && is.finite(middle)) middle / end_mean else NA_real_
  is_bridged <- if (is.finite(ratio)) ratio < bridge_threshold else NA

  rec <- if (is.na(ratio)) {
    "Insufficient data to assess bridging."
  } else if (is_bridged) {
    sprintf(
      paste0("Bridging detected (ratio = %.2f; threshold = %.2f). ",
             "Saddle may not make contact with the middle of the back."),
      ratio, bridge_threshold
    )
  } else {
    sprintf(
      "Pressure distribution appears continuous across the saddle (ratio = %.2f).",
      ratio
    )
  }

  structure(
    list(
      bridge_ratio = ratio,
      is_bridged = is_bridged,
      regional_pressures = reg,
      recommendation = rec
    ),
    class = "pr_saddle_bridge"
  )
}

#' @export
print.pr_saddle_bridge <- function(x, ...) {
  cli::cli_h2("Saddle Bridge Analysis")
  cli::cli_ul(c(
    "Bridge ratio: {.val {round(x$bridge_ratio, 3)}}",
    "Bridging: {.val {x$is_bridged}}"
  ))
  cli::cli_text(x$recommendation)
  invisible(x)
}

#' Detect Saddle Slip / Asymmetric Loading
#'
#' Analyzes left/right pressure asymmetry over time to detect saddle slip
#' or systematic asymmetric loading.
#'
#' @param trial A [pr_trial] object.
#' @param masks Named list of region masks. If `NULL`, auto-generated via
#'   [pr_mask_symmetry()].
#' @param slip_threshold Numeric. SI% above which asymmetry is flagged.
#'   Default `15`.
#'
#' @return A list with class `pr_saddle_slip`.
#' @export
#' @examples
#' pr_calc_saddle_slip(pr_example_trial("saddle_horse"))
pr_calc_saddle_slip <- function(trial, masks = NULL,
                                slip_threshold = 15) {
  .validate_trial(trial)
  if (is.null(masks)) masks <- pr_mask_symmetry(trial$layout, "vertical")
  reg <- pr_mask_apply(trial, masks)

  left_mat  <- reg$left
  right_mat <- reg$right
  if (is.null(left_mat) || is.null(right_mat)) {
    cli::cli_abort("Symmetry masks must be named 'left' and 'right'.")
  }

  left_force  <- rowSums(left_mat)
  right_force <- rowSums(right_mat)
  si <- ifelse(
    (left_force + right_force) > 0,
    (left_force - right_force) /
      (0.5 * (left_force + right_force)) * 100,
    0
  )
  si_mean <- mean(si, na.rm = TRUE)
  si_max  <- max(abs(si), na.rm = TRUE)

  dominant <- if (abs(si_mean) < slip_threshold) "balanced"
              else if (si_mean > 0) "left" else "right"

  structure(
    list(
      symmetry_index_mean = si_mean,
      symmetry_index_max  = si_max,
      dominant_side = dominant,
      is_asymmetric = abs(si_mean) > slip_threshold,
      si_timeseries = si
    ),
    class = "pr_saddle_slip"
  )
}

#' @export
print.pr_saddle_slip <- function(x, ...) {
  cli::cli_h2("Saddle Slip / Asymmetry Analysis")
  cli::cli_ul(c(
    "Mean symmetry index: {.val {round(x$symmetry_index_mean, 2)}}%",
    "Max |SI|: {.val {round(x$symmetry_index_max, 2)}}%",
    "Dominant side: {.val {x$dominant_side}}",
    "Asymmetric: {.val {x$is_asymmetric}}"
  ))
  invisible(x)
}
