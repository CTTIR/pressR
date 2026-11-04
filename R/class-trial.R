#' Create a Pressure Trial Object
#'
#' Represents a single pressure measurement recording: a time series of
#' pressure frames measured across a sensor layout.
#'
#' @param pressure Numeric matrix of dimensions `n_frames x n_sensors`.
#'   Each row is one time frame, each column is one active sensor.
#' @param time Numeric vector of length `n_frames`. Timestamps in seconds
#'   from recording start.
#' @param layout A [pr_layout] object defining the sensor arrangement.
#' @param metadata Named list of trial metadata. Expected (optional) fields:
#'   `subject_id`, `trial_id`, `date`, `condition`, `system`, `notes`.
#'   Entries must have unique nonempty names; malformed metadata is rejected
#'   rather than silently discarded. Stored trials are revalidated before
#'   scientific calculations, including their layout and timestamp extent.
#' @param sampling_hz Numeric. Sampling rate in Hz. If `NULL`, computed
#'   from `time`.
#'
#' @return A `pr_trial` S3 object.
#' @export
#' @examples
#' trial <- pr_example_trial("insole")
#' print(trial)
pr_trial <- function(pressure, time, layout, metadata = list(),
                     sampling_hz = NULL) {
  pr_validate_layout(layout)
  if (!is.matrix(pressure) || !is.numeric(pressure)) {
    cli::cli_abort("{.arg pressure} must be a numeric matrix.")
  }
  if (ncol(pressure) != layout$n_sensors) {
    cli::cli_abort(
      "{.arg pressure} has {ncol(pressure)} column(s) but layout has
       {layout$n_sensors} active sensor(s)."
    )
  }
  if (!is.numeric(time) || length(time) != nrow(pressure)) {
    cli::cli_abort(
      "{.arg time} length ({length(time)}) must equal number of frames
       ({nrow(pressure)})."
    )
  }
  .require_fields(metadata, character(), "Metadata")
  allow_gaps <- isTRUE(metadata[["n_frames_dropped"]] > 0) || identical(metadata[["sampling_policy"]], "gapped")
  .validate_measurements(pressure, time, sampling_hz, allow_gaps = allow_gaps)
  if (is.null(sampling_hz)) {
    if (nrow(pressure) >= 2L) {
      dt <- diff(time)
      sampling_hz <- 1 / stats::median(dt)
    } else {
      sampling_hz <- NA_real_
    }
  }
  # Finite negative sensor offsets are retained, never silently clipped.
  # Dataset validation rejects them for a non-negative analysis cohort.
  metadata$negative_values <- sum(pressure < 0)

  default_meta <- list(
    subject_id = NA_character_,
    trial_id = NA_character_,
    date = NA_character_,
    condition = NA_character_,
    system = layout$model,
    notes = NA_character_
  )
  for (nm in names(default_meta)) {
    if (is.null(metadata[[nm]])) metadata[[nm]] <- default_meta[[nm]]
  }

  result <- structure(
    list(
      pressure = pressure,
      time = as.numeric(time),
      layout = layout,
      metadata = metadata,
      sampling_hz = as.numeric(sampling_hz),
      n_frames = nrow(pressure),
      n_sensors = ncol(pressure),
      duration = if (length(time) > 0L) diff(range(time)) else 0
    ),
    class = "pr_trial"
  )
  .validate_trial(result)
  result
}

#' @export
print.pr_trial <- function(x, ...) {
  md <- x$metadata
  cli::cli_h1("pr_trial")
  cli::cli_ul(c(
    "System: {.val {md$system %||% x$layout$model}}",
    "Layout: {.val {x$layout$name}}",
    "Frames: {.val {x$n_frames}}",
    "Duration: {.val {round(x$duration, 3)}} s",
    "Sampling: {.val {round(x$sampling_hz, 1)}} Hz",
    "Sensors: {.val {x$n_sensors}}",
    "Subject: {.val {md$subject_id}}",
    "Date: {.val {md$date}}",
    "Condition: {.val {md$condition}}"
  ))
  invisible(x)
}

#' @export
summary.pr_trial <- function(object, ...) {
  pr_summary(object, ...)
}

#' Plot a Pressure Trial
#'
#' Default plot method for `pr_trial` — shows the maximum pressure picture
#' (MPP) as a heatmap.
#'
#' @param x A [pr_trial] object.
#' @param ... Passed to [pr_plot_heatmap()].
#'
#' @return A `ggplot2` object.
#' @export
plot.pr_trial <- function(x, ...) {
  pr_plot_heatmap(x, ...)
}

#' @export
as.data.frame.pr_trial <- function(x, row.names = NULL, optional = FALSE, ...) {
  coords <- x$layout$coords_mm
  n_frames <- x$n_frames
  n_sensors <- x$n_sensors

  out <- data.frame(
    frame = rep(seq_len(n_frames), each = n_sensors),
    time = rep(x$time, each = n_sensors),
    sensor_id = rep(coords$sensor_id, times = n_frames),
    row = rep(coords$row, times = n_frames),
    col = rep(coords$col, times = n_frames),
    x = rep(coords$x_mm, times = n_frames),
    y = rep(coords$y_mm, times = n_frames),
    coordinate_unit = rep(.coordinate_unit(x$layout), n_frames * n_sensors),
    measurement_unit = rep(.measurement_unit(x), n_frames * n_sensors),
    pressure = as.vector(t(x$pressure))
  )
  out
}

# Internal validator
.validate_trial <- function(trial) {
  if (!inherits(trial, "pr_trial") || !is.list(trial)) {
    cli::cli_abort("{.arg trial} must be a {.cls pr_trial} object.")
  }
  .require_fields(trial, c("pressure", "time", "layout", "metadata", "sampling_hz",
                           "n_frames", "n_sensors", "duration"), "Trial")
  .validate_layout(trial[["layout"]])
  .require_fields(trial[["metadata"]], character(), "Metadata")
  for (field in c("n_frames", "n_sensors")) {
    value <- trial[[field]]
    if (!.real_vector(value) || length(value) != 1L || !is.finite(value) ||
        value < 0 || value != floor(value)) cli::cli_abort("Trial dimensions are inconsistent.")
  }
  if (!is.matrix(trial$pressure) || ncol(trial$pressure) != trial$layout$n_sensors ||
    nrow(trial$pressure) != trial$n_frames || ncol(trial$pressure) != trial$n_sensors ||
    length(trial$time) != trial$n_frames) {
    cli::cli_abort("Trial dimensions are inconsistent.")
  }
  if (!typeof(trial$pressure) %in% c("integer", "double") || (length(trial$pressure) && any(!is.finite(range(trial$pressure))))) {
    cli::cli_abort("Trial measurements must be finite numeric values.")
  }
  if (!.real_vector(trial$time) || any(!is.finite(trial$time)) || any(diff(trial$time) <= 0)) {
    cli::cli_abort("Trial timestamps must be finite and strictly increasing.")
  }
  duration <- if (length(trial$time)) diff(range(trial$time)) else 0
  if (!.real_vector(trial$duration) || length(trial$duration) != 1L ||
      !is.finite(trial$duration) || trial$duration != duration) {
    cli::cli_abort("Trial duration is inconsistent with its timestamps.")
  }
  rate <- trial[["sampling_hz"]]
  if (!.real_vector(rate) || length(rate) != 1L || is.nan(rate) || (!is.na(rate) && (!is.finite(rate) || rate <= 0))) {
    cli::cli_abort("Trial sampling rate must be positive or unknown (NA).")
  }
  .validate_measurements(trial$pressure, trial$time, if (is.na(rate)) NULL else rate,
    allow_gaps = isTRUE(trial$metadata[["n_frames_dropped"]] > 0) ||
      identical(trial$metadata[["sampling_policy"]], "gapped"))
  invisible(trial)
}

# Local infix for default values
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
