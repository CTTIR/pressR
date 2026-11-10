# A tolerance defines numerical ties, not a physiologic peak threshold.
.tp_find_peaks <- function(x, min_dist, height) {
  if (length(x) < 3L) {
    return(integer())
  }
  tol <- 64 * .Machine$double.eps * max(1, max(abs(x)))
  d <- diff(x)
  direction <- sign(d)
  direction[abs(d) <= tol] <- 0
  starts <- which(direction > 0) + 1L
  cand <- integer()
  for (p in starts) {
    q <- p
    while (q < length(x) && direction[q] == 0) q <- q + 1L
    if (q < length(x) && direction[q] < 0 && x[p] >= height - tol) cand <- c(cand, p)
  }
  if (length(cand) < 2L) {
    return(cand)
  }
  rank_height <- round(x[cand] / tol)
  keep <- integer()
  for (p in cand[order(-rank_height, cand)]) if (all(abs(p - keep) >= min_dist)) keep <- c(keep, p)
  sort(keep)
}

.trial_measurement_hash <- function(trial) {
  digest::digest(
    list(
      pressure = unname(trial$pressure), time = as.numeric(trial$time),
      sensor_id = trial$layout$coords_mm$sensor_id,
      cells = as.matrix(trial$layout$coords_mm[c("row", "col")]),
      unit = .measurement_unit(trial)
    ),
    algo = "sha256", serializeVersion = 2
  )
}

#' Bind Historical Cycles to Their Exact Measurements
#' @param trial A [pr_trial] object.
#' @param cycles Historical cycle table with frame indices and timing.
#' @return A reference object for [pr_temporal_profile()].
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' cycles <- pr_calc_stride_cycles(trial)
#' locked <- pr_lock_cycles(trial, cycles)
#' locked$schema
#' nrow(locked$cycles)
pr_lock_cycles <- function(trial, cycles) {
  .validate_trial(trial)
  .tp_check_cycles(cycles, trial$n_frames)
  if (!all(c("cycle", "start_idx", "end_idx", "duration_s") %in% names(cycles))) cli::cli_abort("Reference cycles require identities, boundaries and durations.")
  if (anyDuplicated(cycles$cycle) || any(diff(cycles$start_idx) <= 0)) cli::cli_abort("Reference cycles must be uniquely identified and ordered.")
  dt <- trial$time[cycles$end_idx] - trial$time[cycles$start_idx]
  if (any(!is.finite(cycles$duration_s)) || any(abs(dt - cycles$duration_s) > 1e-8)) cli::cli_abort("Reference cycle timing disagrees with the measurement.")
  list(
    schema = "pressR-reference-cycles", version = 1L, measurement_sha256 = .trial_measurement_hash(trial),
    trial_id = trial$metadata$trial_id, cycles = cycles,
    source_file_sha256 = if (!is.null(trial$metadata$source_file) && file.exists(trial$metadata$source_file)) digest::digest(trial$metadata$source_file, algo = "sha256", file = TRUE) else NULL
  )
}

#' Analyze Temporal Structure With an Explicit Reproducibility Profile
#'
#' corrected uses measured sampling rate and deterministic plateau handling.
#' legacy_method re-executes the historical fixed-50-Hz method; numerical
#' differences across platforms mean it is not an exact replay guarantee.
#' reference replays cycles bound to the measurements by [pr_lock_cycles()].
#' Its phase map uses the source workflow's central 80 percent of cycles and
#' an untrimmed mean. No historical analysis is silently substituted.
#' @param trial A [pr_trial] object.
#' @param profile One of corrected, legacy_method or reference.
#' @param reference Locked historical cycles, required for reference replay.
#' @return A list with cycles, spectrum, dominant frequency, phase map and
#'   explicit analysis settings.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' profile <- pr_temporal_profile(trial, "corrected")
#' profile$dominant_frequency
#'
#' # Replay cycles that are bound to this exact recording:
#' locked <- pr_lock_cycles(trial, profile$cycles)
#' replay <- pr_temporal_profile(trial, "reference", reference = locked)
#' identical(replay$cycles, profile$cycles)
pr_temporal_profile <- function(trial, profile = c("corrected", "legacy_method", "reference"), reference = NULL) {
  .validate_trial(trial)
  profile <- match.arg(profile)
  if (profile == "reference") {
    if (!is.list(reference) || !identical(reference$schema, "pressR-reference-cycles") ||
      !identical(reference$version, 1L) || !identical(reference$measurement_sha256, .trial_measurement_hash(trial)) ||
      !identical(reference$trial_id, trial$metadata$trial_id)) {
      cli::cli_abort("Historical reference is not bound to this exact trial.")
    }
    checked <- pr_lock_cycles(trial, reference$cycles)
    cycles <- checked$cycles
  } else if (profile == "legacy_method") {
    cycles <- if (trial$n_frames < 100L) {
      .tp_empty_cycles()
    } else {
      .tp_stride_engine(trial, peak_finder = .tp_strict_peaks, sample_rate = 50)
    }
    if (nrow(cycles) < 2L) cycles <- .tp_empty_cycles()
  } else {
    cycles <- pr_calc_stride_cycles(trial)
  }
  spec <- pr_calc_spectrum(trial)
  legacy <- profile != "corrected"
  if (legacy) spec$freq_Hz <- seq(0, 25, length.out = nrow(spec))
  use <- if (legacy) which(spec$freq_Hz > .3 & spec$freq_Hz < 5) else which(spec$freq_Hz >= .3 & spec$freq_Hz <= 5)
  j <- if (length(use)) use[which.max(spec$power[use])] else NA_integer_
  dominant <- tibble::tibble(stride_freq_Hz = spec$freq_Hz[j], peak_power = spec$power[j])
  phase_cycles <- cycles
  if (legacy && nrow(cycles)) phase_cycles <- cycles[max(1, round(nrow(cycles) * .1)):min(nrow(cycles), round(nrow(cycles) * .9)), , drop = FALSE]
  phase <- if (nrow(phase_cycles)) pr_calc_phase_map(trial, cycles = phase_cycles, trim = if (legacy) 0 else .1) else tibble::tibble()
  list(
    cycles = cycles, spectrum = spec, dominant_frequency = dominant, phase_map = phase,
    settings = list(
      profile = profile, nominal_hz = trial$sampling_hz, spectrum_hz = if (legacy) 50 else trial$sampling_hz,
      phase_trim = if (legacy) 0 else .1, phase_cycle_fraction = if (legacy) c(.1, .9) else c(0, 1),
      exact_reference_replay = profile == "reference"
    )
  )
}
