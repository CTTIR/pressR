# Internal measurement contract. Unknown physical calibration stays unknown.
.coordinate_unit <- function(layout) layout[["coords_units"]] %||% "mm"
.coordinate_label <- function(layout) {
  if (identical(.coordinate_unit(layout), "grid_index")) "grid units" else "mm"
}
.measurement_unit <- function(trial) trial[["layout"]][["pressure_unit"]] %||% "kPa"

.real_vector <- function(x) {
  typeof(x) %in% c("integer", "double") && is.null(dim(x)) && !is.object(x)
}

.require_fields <- function(x, required, label) {
  nms <- names(x)
  if (!is.list(x) || (length(x) && (is.null(nms) || anyNA(nms) ||
      any(!nzchar(nms)) || anyDuplicated(nms)))) {
    cli::cli_abort("{label} must be a named list with unique nonempty names.")
  }
  if (!all(required %in% nms)) cli::cli_abort("{label} is missing required fields: {.val {setdiff(required, nms)}}.")
  invisible(x)
}
.pressure_to_kpa <- function(unit) {
  scale <- c(kPa = 1, Pa = 0.001, MPa = 1000, mmHg = 0.133322387415, `N/cm2` = 10)
  if (!unit %in% names(scale)) {
    return(NA_real_)
  }
  unname(scale[[unit]])
}
.force_scale <- function(trial) {
  if (identical(.measurement_unit(trial), "N")) {
    return(1)
  }
  a <- trial$layout$sensor_area_cm2
  if (length(a) != 1L || !is.finite(a)) {
    return(NA_real_)
  }
  .pressure_to_kpa(.measurement_unit(trial)) * a * 0.1
}
.safe_max <- function(x) if (length(x) && any(is.finite(x))) max(x[is.finite(x)]) else NA_real_
.safe_mean <- function(x) if (length(x) && any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_

.finite_metric <- function(x, label) {
  if (any(!is.finite(x))) cli::cli_abort("{label} exceeds the supported finite numeric range; rescale the measurement units explicitly.")
  x
}

.force_rows <- function(pressure, trial) {
  scale <- .force_scale(trial)
  if (is.na(scale)) return(rep(NA_real_, nrow(pressure)))
  .finite_metric(scale, "Force conversion")
  if (scale == 0) {
    if (!any(pressure != 0)) return(rep(0, nrow(pressure)))
    cli::cli_abort("Force conversion underflows the supported numeric range; rescale the measurement units explicitly.")
  }
  out <- rowSums(pressure) * scale
  bad <- !is.finite(out)
  if (any(bad)) out[bad] <- rowSums(pressure[bad, , drop = FALSE] * scale)
  .finite_metric(out, "Force")
}

.finite_midpoint <- function(left, right) {
  out <- .5 * (left + right)
  bad <- !is.finite(out)
  if (any(bad)) out[bad] <- left[bad] / 2 + right[bad] / 2
  .finite_metric(out, "Trapezoid midpoint")
}

.integrate_pressure <- function(pressure, time) {
  n <- nrow(pressure)
  if (n < 2L) return(rep(0, ncol(pressure)))
  midpoint <- .finite_midpoint(pressure[-n, , drop = FALSE],
    pressure[-1, , drop = FALSE])
  area <- .finite_metric(midpoint * diff(time), "Trapezoid area")
  .finite_metric(colSums(area), "Pressure-time integral")
}

.weighted_coordinate <- function(pressure, coordinate, total) {
  product <- pressure * coordinate
  lost <- pressure != 0 & coordinate != 0 & product == 0
  out <- sum(product) / total
  if (is.finite(total) && all(is.finite(product)) && !any(lost) && is.finite(out)) return(out)
  # Bound both factors; do not turn conditioning loss into a zero coordinate.
  use <- pressure != 0
  pressure <- pressure[use]
  coordinate <- coordinate[use]
  weights <- pressure / max(abs(pressure))
  scale <- max(abs(coordinate))
  if (scale == 0) return(0)
  positions <- coordinate / scale
  product <- weights * positions
  if (any((weights == 0 & coordinate != 0) |
          (positions == 0 & coordinate != 0) |
          (weights != 0 & positions != 0 & product == 0))) {
    cli::cli_abort("Centre-of-pressure conditioning loses nonzero contributions; rescale the input coordinates or measurements explicitly.")
  }
  numerator <- sum(product)
  ratio <- numerator / sum(weights)
  out <- ratio * scale
  if (is.finite(ratio) && ((numerator != 0 && ratio == 0) || (ratio != 0 && out == 0))) {
    cli::cli_abort("Centre-of-pressure calculation underflows the supported numeric range.")
  }
  .finite_metric(out, "Centre of pressure")
}
.tile_size <- function(layout) {
  if (identical(.coordinate_unit(layout), "grid_index")) {
    return(1)
  }
  a <- layout$sensor_area_cm2
  if (is.finite(a)) {
    return(sqrt(a) * 10)
  }
  steps <- unlist(lapply(layout$coords_mm[c("x_mm", "y_mm")], function(x) diff(sort(unique(x)))))
  if (any(steps > 0)) min(steps[steps > 0]) else 1
}
.metric_units <- function(trial) {
  u <- .measurement_unit(trial)
  c <- .coordinate_unit(trial$layout)
  c(
    mpp = u, mvp = u, peak_pressure = u, mean_pressure = u,
    max_force = "N", mean_force = "N", force = "N", max_contact_area = "cm2",
    mean_contact_area = "cm2", contact_area = "cm2", contact_time = "s",
    pti_max = paste0(u, "*s"), pti_mean = paste0(u, "*s"), impulse = "N*s",
    cop_path_length = c, cop_velocity_mean = paste0(c, "/s"), cop_range_ap = c, cop_range_ml = c
  )
}
.validate_measurements <- function(pressure, time, sampling_hz = NULL, allow_gaps = FALSE) {
  if (!is.matrix(pressure) || !typeof(pressure) %in% c("integer", "double") || !ncol(pressure)) {
    cli::cli_abort("Measurements must be a numeric matrix with sensor columns.")
  }
  if (any(!is.finite(pressure))) cli::cli_abort("Measurements must be finite; handle missing observations explicitly in the reader.")
  if (!.real_vector(time) || length(time) != nrow(pressure) || any(!is.finite(time))) {
    cli::cli_abort("Timestamps must be finite and match the number of frames.")
  }
  if (any(diff(time) <= 0)) cli::cli_abort("Timestamps must be strictly increasing.")
  if (any(!is.finite(diff(time)))) cli::cli_abort("Timestamp intervals exceed the finite numeric range.")
  if (!is.null(sampling_hz) && !(length(time) < 2L && length(sampling_hz) == 1L && is.na(sampling_hz))) {
    if (!is.numeric(sampling_hz) || length(sampling_hz) != 1L || !is.finite(sampling_hz) || sampling_hz <= 0) {
      cli::cli_abort("Sampling rate must be a single finite positive number.")
    }
    # Gaps are permitted, but the declared rate must match the acquisition
    # interval, not silently override measured time. Allow rounded timestamps.
    if (length(time) > 1L) {
      steps <- diff(time) * sampling_hz
      good <- if (allow_gaps) all(round(steps) >= 1 & abs(steps - round(steps)) <= 0.02) else abs(stats::median(steps) - 1) <= 0.02
      if (!good) cli::cli_abort("Declared sampling rate conflicts with the measured timestamps.")
    }
  }
  invisible(TRUE)
}

.kpa_scale <- function(trial) {
  scale <- .pressure_to_kpa(.measurement_unit(trial))
  if (!is.finite(scale)) cli::cli_abort("This pressure table requires convertible pressure units; force measurements are not kPa.")
  scale
}
