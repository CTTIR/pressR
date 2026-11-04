# ---------------------------------------------------------------------------
# Synthetic data generators for examples, tests, and vignettes.
#
# The generated data mimics typical pressure patterns for each application
# (gait cycles for insole, horse-walk kinematics for saddle, etc.) and is
# intended to be visually plausible, not biomechanically accurate.
# ---------------------------------------------------------------------------

#' Generate a Synthetic Pressure Trial
#'
#' Creates a [pr_trial] with realistic synthetic pressure data for
#' demonstration, testing, and vignette purposes.
#'
#' @param type Character. Type of trial to generate:
#'   `"insole"`, `"platform"`, `"saddle_horse"`, `"saddle_bicycle"`,
#'   `"wheelchair"`, or `"custom"` (small uniform grid).
#' @param duration_s Numeric. Trial duration in seconds. `NULL` (default)
#'   uses a type-specific default.
#' @param sampling_hz Numeric. Sampling rate. Default `50`.
#' @param seed Integer. Random seed for reproducibility. Default `42`.
#'
#' @return A [pr_trial] object.
#' @export
#' @examples
#' trial <- pr_example_trial("insole")
#' print(trial)
pr_example_trial <- function(type = c(
                               "insole", "platform", "saddle_horse",
                               "saddle_bicycle", "wheelchair",
                               "custom"
                             ),
                             duration_s = NULL, sampling_hz = 50,
                             seed = 42) {
  type <- match.arg(type)
  set.seed(seed)

  switch(type,
    insole         = .example_insole(duration_s %||% 5, sampling_hz),
    platform       = .example_platform(duration_s %||% 2, sampling_hz),
    saddle_horse   = .example_saddle_horse(duration_s %||% 10, sampling_hz),
    saddle_bicycle = .example_saddle_bicycle(duration_s %||% 10, sampling_hz),
    wheelchair     = .example_wheelchair(duration_s %||% 10, sampling_hz),
    custom         = .example_custom(duration_s %||% 2, sampling_hz)
  )
}

# Shared helper: Gaussian blob at (cx, cy) with amplitude and width sigma.
.blob <- function(coords, cx, cy, amp, sigma) {
  d2 <- (coords$x_mm - cx)^2 + (coords$y_mm - cy)^2
  amp * exp(-d2 / (2 * sigma^2))
}

# ---- insole (foot gait) ---------------------------------------------------
.example_insole <- function(duration_s, hz) {
  layout <- pr_layout_insole("standard")
  coords <- layout$coords_mm
  n_frames <- ceiling(duration_s * hz)
  t <- (seq_len(n_frames) - 1) / hz

  stride <- duration_s / 5
  stance_frac <- 0.6

  y_range <- range(coords$y_mm)
  y_heel <- y_range[1]
  y_met <- y_range[1] + 0.70 * diff(y_range)
  y_hal <- y_range[1] + 0.95 * diff(y_range)
  x_med <- stats::quantile(coords$x_mm, 0.30)
  x_lat <- stats::quantile(coords$x_mm, 0.70)
  x_mid <- stats::median(coords$x_mm)

  P <- matrix(0, nrow = n_frames, ncol = layout$n_sensors)
  for (i in seq_len(n_frames)) {
    tt <- t[i] %% stride
    phase <- tt / stride
    if (phase > stance_frac) next

    sp <- phase / stance_frac
    heel_amp <- 220 * exp(-((sp - 0.15) / 0.08)^2)
    met_amp <- 330 * exp(-((sp - 0.75) / 0.15)^2)
    hal_amp <- 260 * exp(-((sp - 0.92) / 0.08)^2)

    vals <- .blob(coords, x_mid, y_heel + 10, heel_amp, 18) +
      .blob(coords, x_med, y_met, met_amp * 1.0, 14) +
      .blob(coords, x_mid, y_met, met_amp * 0.9, 14) +
      .blob(coords, x_lat, y_met, met_amp * 0.8, 14) +
      .blob(coords, x_med, y_hal, hal_amp, 12)

    noise <- stats::rnorm(layout$n_sensors, 0, 5)
    vals <- vals + noise
    vals[vals < 0] <- 0
    P[i, ] <- vals
  }

  pr_trial(
    pressure = P,
    time = t,
    layout = layout,
    metadata = list(
      subject_id = "EX01",
      trial_id = "insole_gait",
      date = format(Sys.Date()),
      condition = "walking",
      system = "insole",
      notes = "Synthetic 5-step gait trial"
    ),
    sampling_hz = hz
  )
}

# ---- platform (barefoot) --------------------------------------------------
.example_platform <- function(duration_s, hz) {
  layout <- pr_layout_platform("st")
  coords <- layout$coords_mm
  n_frames <- ceiling(duration_s * hz)
  t <- (seq_len(n_frames) - 1) / hz

  cx <- stats::median(coords$x_mm)
  cy <- stats::median(coords$y_mm)

  P <- matrix(0, nrow = n_frames, ncol = layout$n_sensors)
  for (i in seq_len(n_frames)) {
    phase <- t[i] / duration_s
    if (phase < 0.1 || phase > 0.9) next
    sp <- (phase - 0.1) / 0.8
    env <- sin(pi * sp)
    heel <- 180 * env * exp(-((sp - 0.2) / 0.15)^2)
    met <- 280 * env * exp(-((sp - 0.75) / 0.15)^2)
    hal <- 200 * env * exp(-((sp - 0.9) / 0.1)^2)
    vals <- .blob(coords, cx, cy - 40, heel, 15) +
      .blob(coords, cx - 10, cy + 30, met, 12) +
      .blob(coords, cx + 10, cy + 30, met * 0.8, 12) +
      .blob(coords, cx - 5, cy + 60, hal, 10)
    vals <- vals + stats::rnorm(layout$n_sensors, 0, 4)
    vals[vals < 0] <- 0
    P[i, ] <- vals
  }

  pr_trial(
    pressure = P, time = t, layout = layout,
    metadata = list(
      subject_id = "EX01", trial_id = "platform_rollover",
      date = format(Sys.Date()), condition = "barefoot",
      system = "platform", notes = "Synthetic rollover footfall"
    ),
    sampling_hz = hz
  )
}

# ---- saddle horse ---------------------------------------------------------
.example_saddle_horse <- function(duration_s, hz) {
  layout <- pr_layout_saddle("horse")
  coords <- layout$coords_mm
  n_frames <- ceiling(duration_s * hz)
  t <- (seq_len(n_frames) - 1) / hz

  freq <- 1.4
  x_range <- range(coords$x_mm)
  y_range <- range(coords$y_mm)
  xmid <- mean(x_range)
  y_cranial <- y_range[1] + 0.20 * diff(y_range)
  y_middle <- y_range[1] + 0.50 * diff(y_range)
  y_caudal <- y_range[1] + 0.80 * diff(y_range)

  P <- matrix(0, nrow = n_frames, ncol = layout$n_sensors)
  for (i in seq_len(n_frames)) {
    tt <- t[i]
    left_env <- 10 + 6 * sin(2 * pi * freq * tt)
    right_env <- 10 + 6 * sin(2 * pi * freq * tt + pi)

    left_env <- left_env * 1.10
    right_env <- right_env * 0.95

    x_left <- xmid - 0.25 * diff(x_range)
    x_right <- xmid + 0.25 * diff(x_range)

    vals <-
      .blob(coords, x_left, y_cranial, left_env, 30) +
      .blob(coords, x_right, y_cranial, right_env, 30) +
      .blob(coords, x_left, y_middle, left_env * 0.7, 30) +
      .blob(coords, x_right, y_middle, right_env * 0.7, 30) +
      .blob(coords, x_left, y_caudal, left_env, 30) +
      .blob(coords, x_right, y_caudal, right_env, 30)

    vals <- vals + stats::rnorm(layout$n_sensors, 0, 0.6)
    vals[vals < 0] <- 0
    P[i, ] <- vals
  }

  pr_trial(
    pressure = P, time = t, layout = layout,
    metadata = list(
      subject_id = "HORSE01", trial_id = "saddle_walk",
      date = format(Sys.Date()), condition = "walk",
      system = "saddle_mat", notes = "Synthetic saddle walk trial"
    ),
    sampling_hz = hz
  )
}

# ---- saddle bicycle -------------------------------------------------------
.example_saddle_bicycle <- function(duration_s, hz) {
  layout <- pr_layout_saddle("bicycle")
  coords <- layout$coords_mm
  n_frames <- ceiling(duration_s * hz)
  t <- (seq_len(n_frames) - 1) / hz

  xmid <- stats::median(coords$x_mm)
  y_ischial <- max(coords$y_mm) - 0.2 * diff(range(coords$y_mm))
  y_perineal <- max(coords$y_mm) - 0.35 * diff(range(coords$y_mm))

  P <- matrix(0, nrow = n_frames, ncol = layout$n_sensors)
  for (i in seq_len(n_frames)) {
    cadence <- 1.5
    osc <- 1 + 0.2 * sin(2 * pi * cadence * t[i])
    vals <-
      .blob(coords, xmid - 40, y_ischial, 40 * osc, 25) +
      .blob(coords, xmid + 40, y_ischial, 38 * osc, 25) +
      .blob(coords, xmid, y_perineal, 18 * osc, 18)
    vals <- vals + stats::rnorm(layout$n_sensors, 0, 1)
    vals[vals < 0] <- 0
    P[i, ] <- vals
  }

  pr_trial(
    pressure = P, time = t, layout = layout,
    metadata = list(
      subject_id = "CYC01", trial_id = "bicycle_ride",
      date = format(Sys.Date()), condition = "seated",
      system = "saddle_mat", notes = "Synthetic bicycle saddle"
    ),
    sampling_hz = hz
  )
}

# ---- wheelchair -----------------------------------------------------------
.example_wheelchair <- function(duration_s, hz) {
  layout <- pr_layout_seat("wheelchair")
  coords <- layout$coords_mm
  n_frames <- ceiling(duration_s * hz)
  t <- (seq_len(n_frames) - 1) / hz

  xmid <- stats::median(coords$x_mm)
  yq <- stats::quantile(coords$y_mm, c(0.25, 0.6, 0.85))
  y_thigh <- yq[1]
  y_ischial <- yq[2]
  y_sacral <- yq[3]

  P <- matrix(0, nrow = n_frames, ncol = layout$n_sensors)
  for (i in seq_len(n_frames)) {
    drift <- 1 + 0.05 * sin(2 * pi * 0.05 * t[i])
    asym <- 1.08
    vals <-
      .blob(coords, xmid - 60, y_ischial, 55 * drift * asym, 30) +
      .blob(coords, xmid + 60, y_ischial, 52 * drift, 30) +
      .blob(coords, xmid, y_sacral, 20 * drift, 40) +
      .blob(coords, xmid - 90, y_thigh, 12, 45) +
      .blob(coords, xmid + 90, y_thigh, 11, 45)
    vals <- vals + stats::rnorm(layout$n_sensors, 0, 1.2)
    vals[vals < 0] <- 0
    P[i, ] <- vals
  }

  pr_trial(
    pressure = P, time = t, layout = layout,
    metadata = list(
      subject_id = "WC01", trial_id = "wheelchair_static",
      date = format(Sys.Date()), condition = "seated",
      system = "seat_mat", notes = "Synthetic wheelchair static sitting"
    ),
    sampling_hz = hz
  )
}

# ---- custom (small uniform grid) -----------------------------------------
.example_custom <- function(duration_s, hz) {
  layout <- pr_layout_mat("16")
  coords <- layout$coords_mm
  n_frames <- ceiling(duration_s * hz)
  t <- (seq_len(n_frames) - 1) / hz
  xmid <- stats::median(coords$x_mm)
  ymid <- stats::median(coords$y_mm)

  P <- matrix(0, nrow = n_frames, ncol = layout$n_sensors)
  for (i in seq_len(n_frames)) {
    amp <- 30 + 10 * sin(2 * pi * t[i])
    vals <- .blob(coords, xmid, ymid, amp, 60)
    vals <- vals + stats::rnorm(layout$n_sensors, 0, 1)
    vals[vals < 0] <- 0
    P[i, ] <- vals
  }

  pr_trial(
    pressure = P, time = t, layout = layout,
    metadata = list(
      subject_id = "EX", trial_id = "custom",
      date = format(Sys.Date()), condition = "demo",
      system = "mat", notes = "Synthetic uniform 16x16 mat."
    ),
    sampling_hz = hz
  )
}

#' Write Sample Pressure Data Files
#'
#' Creates sample ASCII files in a temporary directory for demonstrating
#' the parser functions.
#'
#' @param type Character. `"insole"` (default), `"saddle"`, `"platform"`,
#'   or `"all"`.
#'
#' @return Character. Path to the sample file (single type) or directory
#'   (`"all"`).
#' @export
#' @examples
#' path <- pr_example_files("insole")
#' file.exists(path)
pr_example_files <- function(type = c(
                               "insole", "saddle", "platform",
                               "all"
                             )) {
  type <- match.arg(type)
  dir <- file.path(tempdir(), "pressR-samples")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  write_one <- function(nm, trial, system_label, size_label) {
    path <- file.path(dir, paste0(nm, ".asc"))
    header <- c(
      sprintf("Patient:        %s", trial$metadata$subject_id %||% "Example"),
      sprintf("Date:           %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      sprintf("System:         %s", system_label),
      sprintf("Size:           %s", size_label),
      sprintf("Sensors:        %d", trial$n_sensors),
      sprintf("Sampling Rate:  %d Hz", round(trial$sampling_hz)),
      sprintf("Duration:       %.2f s", trial$duration),
      sprintf("Frames:         %d", trial$n_frames),
      ""
    )
    writeLines(header, path)
    con <- file(path, open = "a")
    on.exit(close(con), add = TRUE)
    utils::write.table(
      round(trial$pressure, 2), con,
      sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE
    )
    path
  }

  paths <- character()
  if (type %in% c("insole", "all")) {
    paths["insole"] <- write_one(
      "insole_sample", pr_example_trial("insole"), "insole", "42"
    )
  }
  if (type %in% c("saddle", "all")) {
    paths["saddle"] <- write_one(
      "saddle_sample", pr_example_trial("saddle_horse"), "saddle_mat", "saddle"
    )
  }
  if (type %in% c("platform", "all")) {
    paths["platform"] <- write_one(
      "platform_sample", pr_example_trial("platform"), "platform", "st"
    )
  }

  if (type == "all") {
    return(dir)
  }
  as.character(paths[type])
}
