#' Compute Parameters by Region
#'
#' Applies region masks to a trial and computes summary parameters
#' independently for each region. Returns one row per region.
#'
#' @param trial A [pr_trial] object.
#' @param masks Named list of [pr_mask] objects or logical matrices. If
#'   `NULL` (default), uses the layout's default regions.
#' @param parameters Character vector. Parameters to compute. Supported
#'   values: `"mpp"`, `"mvp"`, `"max_force"`, `"mean_force"`,
#'   `"contact_area"`, `"pti_max"`, `"pti_mean"`.
#'   Default `c("mpp", "mvp", "max_force", "contact_area", "pti_mean")`.
#' @param threshold Numeric. Default `0`.
#'
#' @return A [tibble::tibble] with one column `region` plus one column
#'   per requested parameter.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' pr_calc_regional(trial)
pr_calc_regional <- function(trial, masks = NULL,
                             parameters = c(
                               "mpp", "mvp", "max_force",
                               "contact_area", "pti_mean"
                             ),
                             threshold = 0) {
  .validate_trial(trial)
  valid <- c(
    "mpp", "mvp", "max_force", "mean_force", "contact_area",
    "pti_max", "pti_mean"
  )
  bad <- setdiff(parameters, valid)
  if (length(bad) > 0L) {
    cli::cli_abort("Unknown parameter(s): {.val {bad}}")
  }
  if (is.null(masks)) {
    masks <- pr_mask_default(trial$layout)
  }
  if (length(masks) == 0L) {
    cli::cli_abort("No region masks available for this trial.")
  }
  if (is.null(names(masks))) {
    cli::cli_abort("{.arg masks} must be a named list.")
  }

  a <- trial$layout$sensor_area_cm2
  t <- trial$time
  n_frames <- trial$n_frames

  rows <- lapply(names(masks), function(nm) {
    cols <- .mask_to_cols(masks[[nm]], trial$layout)
    if (length(cols) == 0L) {
      # Empty region
      return(tibble::tibble(
        region = nm,
        mpp = 0, mvp = 0, max_force = 0, mean_force = 0,
        contact_area = 0, pti_max = 0, pti_mean = 0
      ))
    }
    M <- trial$pressure[, cols, drop = FALSE]

    # Per-frame metrics over the region
    per_frame_peak <- apply(M, 1, function(r) {
      loaded <- r[r > threshold]
      if (length(loaded) == 0L) 0 else max(loaded)
    })
    per_frame_mean <- apply(M, 1, function(r) {
      loaded <- r[r > threshold]
      if (length(loaded) == 0L) 0 else mean(loaded)
    })
    per_frame_force <- if (any(c("max_force", "mean_force") %in% parameters)) {
      .force_rows(M, trial)
    } else numeric()
    per_frame_area <- rowSums(M > threshold) * a

    # PTI per sensor in this region
    pti_sensor <- if (any(c("pti_max", "pti_mean") %in% parameters)) {
      .integrate_pressure(M, t)
    } else {
      rep(0, ncol(M))
    }

    tibble::tibble(
      region = nm,
      mpp = max(per_frame_peak, na.rm = TRUE),
      mvp = {
        v <- per_frame_mean[per_frame_mean > 0]
        if (length(v) > 0L) mean(v) else 0
      },
      max_force = .safe_max(per_frame_force),
      mean_force = mean(per_frame_force),
      contact_area = .safe_max(per_frame_area),
      pti_max = if (length(pti_sensor)) max(pti_sensor) else NA_real_,
      pti_mean = {
        v <- pti_sensor[pti_sensor > 0]
        if (length(v) > 0L) mean(v) else 0
      }
    )
  })
  out <- do.call(rbind, rows)
  out <- out[, c("region", parameters), drop = FALSE]
  attr(out, "units") <- .metric_units(trial)[parameters]
  attr(out, "reference_context") <- trial$metadata$reference_context
  out
}
