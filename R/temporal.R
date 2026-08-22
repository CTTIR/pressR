# ---------------------------------------------------------------------------
# Temporal structure of a whole-mat recording.
#
# pr_calc_gait_cycles() segments a recording by pairing threshold crossings
# of the force curve: contact, then no contact. That works for an insole or
# a pedography platform, where the foot genuinely leaves the sensor. A
# saddle mat never unloads -- the rider's mass sits on it from the first
# frame to the last -- so the "loaded" run is the entire recording and the
# frozen function reports exactly one cycle spanning it. The failure is
# structural, not a matter of tuning `force_threshold`.
#
# What a saddle recording carries instead is an *oscillation*: the total
# load rises and falls once per stride around a slowly drifting baseline.
# The functions here read that oscillation rather than a contact/no-contact
# pattern:
#
#   pr_calc_spectrum()       frequency content of a frame-level signal
#   pr_calc_dominant_freq()  the strongest oscillation in a stride band
#   pr_calc_stride_cycles()  peak-to-peak segmentation of the band-passed
#                            signal, the time-domain counterpart
#   pr_calc_phase_map()      the whole sensor map over percent of cycle
#   pr_cop_shape()           loop geometry of a COP trajectory
#
# Unit conventions follow R/frame-metrics.R: pressure in the device's own
# unit (kPa), COP in whatever units the caller's trajectory already uses,
# frequency in Hz, time in seconds. No area conversion happens anywhere, so
# nothing here is ever a force or a cm^2.
# ---------------------------------------------------------------------------

# The frame-level signals every function in this file accepts.
.tp_signals <- c("total", "mean", "peak")

# Internal: match a single string against a set of choices, tolerating the
# full default vector that match.arg() would normally absorb.
.tp_match_arg <- function(x, choices, arg, call = rlang::caller_env()) {
  if (identical(x, choices)) return(choices[1])
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single string, one of {.val {choices}}.",
      call = call
    )
  }
  if (!x %in% choices) {
    cli::cli_abort(
      c("{.arg {arg}} must be one of {.val {choices}}.",
        "x" = "Got {.val {x}}."),
      call = call
    )
  }
  x
}

# Internal: a single finite number.
.tp_check_scalar <- function(x, arg, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    cli::cli_abort("{.arg {arg}} must be a single finite number.", call = call)
  }
  invisible(x)
}

# Internal: a single TRUE/FALSE.
.tp_check_flag <- function(x, arg, call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
      call = call
    )
  }
  invisible(x)
}

# Internal: a single whole number at least `min`, returned as integer.
.tp_check_count <- function(x, arg, min = 1L, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
      x != as.integer(x) || x < min) {
    cli::cli_abort(
      "{.arg {arg}} must be a single whole number of at least {min}.",
      call = call
    )
  }
  as.integer(x)
}

# Internal: sampling rate in Hz, from the trial or from its timestamps.
.tp_fs <- function(trial, call = rlang::caller_env()) {
  fs <- trial$sampling_hz
  if (!is.numeric(fs) || length(fs) != 1L || !is.finite(fs) || fs <= 0) {
    tv <- trial$time
    fs <- if (length(tv) >= 2L) {
      dt <- mean(diff(tv))
      if (is.finite(dt) && dt > 0) 1 / dt else NA_real_
    } else {
      NA_real_
    }
  }
  if (!is.finite(fs) || fs <= 0) {
    cli::cli_abort(
      c("{.arg trial} has no usable sampling rate.",
        "i" = "Set {.field sampling_hz} or give the trial increasing
               timestamps."),
      call = call
    )
  }
  as.numeric(fs)
}

# Internal: one frame-level signal from the pressure matrix.
#
# `total` and `mean` differ by the constant `n_sensors`, so their spectra
# differ by `n_sensors^2` and their stride segmentation is identical; see
# the notes in pr_calc_spectrum().
.tp_frame_signal <- function(trial, signal, call = rlang::caller_env()) {
  P <- trial$pressure
  if (identical(signal, "peak")) return(.fm_row_max(P))
  total <- rowSums(P)
  if (identical(signal, "total")) return(total)
  n <- trial$layout$n_sensors
  if (n == 0L) {
    cli::cli_abort(
      "Layout {.val {trial$layout$name}} has no active sensors.",
      call = call
    )
  }
  total / n
}

# Internal: symmetric (periodic-endpoint) Hann window of length n, the
# `hanning` definition whose first and last weights are exactly 0.
.tp_hann <- function(n) {
  if (n < 2L) return(rep(1, n))
  0.5 - 0.5 * cos(2 * pi * seq.int(0L, n - 1L) / (n - 1))
}

#' Power Spectrum of a Frame-Level Signal
#'
#' Frequency content of a whole-mat time series: how much of the recording's
#' variation sits at each frequency. On a saddle mat the stride shows up as
#' a peak somewhere between 0.5 and 2 Hz.
#'
#' @details
#' The signal is taken from the pressure matrix directly:
#' * `"total"` — the frame sum, [pr_calc_total_pressure()].
#' * `"mean"` — the whole-grid frame mean, [pr_calc_mean_pressure_grid()].
#'   This is `"total"` divided by the constant `n_sensors`, so its spectrum
#'   is the `"total"` spectrum scaled by `1 / n_sensors^2` and the peak sits
#'   at exactly the same frequency.
#' * `"peak"` — the frame maximum, which is *not* a scaled copy of the other
#'   two and saturates flat on a device that clips at its ceiling.
#'
#' `detrend = TRUE` subtracts the mean before transforming, which removes
#' the DC term that would otherwise dominate a signal sitting on a large
#' constant offset. It does not remove a linear ramp. `window = "hann"`
#' then tapers the ends, trading a little frequency resolution for far less
#' leakage from the strong low-frequency components a drifting baseline
#' produces; `window = "none"` leaves the segment rectangular.
#'
#' Power is `Mod(fft(x))^2 / n`, kept for the non-negative frequencies only
#' (`n %/% 2 + 1` values, including DC and — for even `n` — Nyquist). It is
#' a squared pressure quantity in the device's own unit, not a density: it
#' is not divided by the frequency bin width, and it is not corrected for
#' the window's power loss, so absolute values are comparable only between
#' recordings of the same length analysed the same way.
#'
#' @section Frequency axis:
#' The axis is built as `(0:(n %/% 2)) * fs / n`, which is the exact centre
#' frequency of FFT bin `k` for both odd and even `n`.
#'
#' The study this function reproduces built it as
#' `seq(0, fs / 2, length.out = length(power))` instead. For even `n` the
#' two agree exactly. For odd `n` they do not: that sequence has spacing
#' `fs / (n - 1)` rather than `fs / n`, and it places its last value at
#' `fs / 2`, which for odd `n` is not an FFT bin at all — the highest real
#' bin is at `((n - 1) / 2) * fs / n`, just below Nyquist. On the 869-frame
#' reference recording the error is a uniform stretch of `n / (n - 1)`,
#' about 0.12%: the study reports a stride at 0.7488 Hz where the exact
#' axis puts it at 0.7480 Hz. `power` is unaffected — only the labels move.
#' **This function implements the exact axis.**
#'
#' @param trial A [pr_trial] object.
#' @param signal Character. Which frame-level signal to transform: `"total"`
#'   (default), `"mean"` or `"peak"`. See *Details*.
#' @param window Character. `"hann"` (default) or `"none"`.
#' @param detrend Logical. Subtract the signal mean first. Default `TRUE`.
#'
#' @return A [tibble::tibble] with `n %/% 2 + 1` rows and columns `freq_Hz`
#'   (ascending, starting at 0) and `power`.
#' @family temporal structure functions
#' @seealso [pr_calc_dominant_freq()] for the peak of this spectrum,
#'   [pr_calc_stride_cycles()] for the time-domain counterpart.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' spec <- pr_calc_spectrum(trial)
#' nrow(spec) == trial$n_frames %/% 2 + 1
#'
#' # The strongest non-DC component is the stride:
#' round(spec$freq_Hz[which.max(spec$power[-1]) + 1], 3)
#'
#' # "mean" is "total" scaled by n_sensors, so power scales by its square:
#' m <- pr_calc_spectrum(trial, signal = "mean")
#' all.equal(m$power * trial$layout$n_sensors^2, spec$power)
pr_calc_spectrum <- function(trial, signal = c("total", "mean", "peak"),
                             window = c("hann", "none"), detrend = TRUE) {
  .validate_trial(trial)
  signal <- .tp_match_arg(signal, .tp_signals, "signal")
  window <- .tp_match_arg(window, c("hann", "none"), "window")
  .tp_check_flag(detrend, "detrend")
  fs <- .tp_fs(trial)

  x <- .tp_frame_signal(trial, signal)
  n <- length(x)
  if (n < 2L) {
    cli::cli_abort(
      c("{.arg trial} has {n} frame{?s}.",
        "i" = "A spectrum needs at least two frames.")
    )
  }
  if (anyNA(x)) {
    cli::cli_abort(
      c("The {.val {signal}} signal contains missing values.",
        "i" = "{.fun stats::fft} has no missing-value handling.")
    )
  }

  if (detrend) x <- x - mean(x)
  if (identical(window, "hann")) x <- x * .tp_hann(n)

  half <- n %/% 2L
  power <- (Mod(stats::fft(x))^2 / n)[seq_len(half + 1L)]

  tibble::tibble(
    freq_Hz = seq.int(0L, half) * fs / n,
    power = power
  )
}

#' Dominant Oscillation Frequency in a Band
#'
#' The strongest frequency of [pr_calc_spectrum()] inside a search band —
#' on a saddle recording, the stride frequency.
#'
#' @details
#' The default band of 0.3-5 Hz brackets equine stride rates from a slow
#' walk to a fast canter while excluding both the baseline drift below it
#' and sensor noise above it. Band edges are inclusive, and the search
#' happens on the exact frequency axis documented in [pr_calc_spectrum()].
#'
#' The result is the single largest bin, with no interpolation between
#' bins, so its resolution is `fs / n_frames` — 0.058 Hz for a 869-frame
#' recording at 50 Hz. A recording with no oscillation still returns its
#' largest in-band bin; read `peak_power` before trusting the frequency,
#' and compare against [pr_calc_stride_cycles()], which measures the same
#' rhythm in the time domain and disagrees when there is nothing periodic
#' to find.
#'
#' @inheritParams pr_calc_spectrum
#' @param band Numeric vector of length 2. Inclusive search band in Hz.
#'   Default `c(0.3, 5)`.
#' @param signal Character. Frame-level signal to transform. Default
#'   `"total"`.
#' @param window Character. Window to taper with. Default `"hann"`.
#'
#' @return A one-row [tibble::tibble] with columns `stride_freq_Hz` and
#'   `peak_power`. Both are `NA` (with a warning) when the band contains no
#'   frequency bin.
#' @family temporal structure functions
#' @seealso [pr_calc_spectrum()] for the full spectrum.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' pr_calc_dominant_freq(trial)
#'
#' # A stride frequency and a mean stride duration are reciprocals:
#' f <- pr_calc_dominant_freq(trial)$stride_freq_Hz
#' cycles <- pr_calc_stride_cycles(trial)
#' round(c(from_spectrum = 1 / f, from_cycles = mean(cycles$duration_s)), 2)
pr_calc_dominant_freq <- function(trial, band = c(0.3, 5), signal = "total",
                                  window = "hann") {
  if (!is.numeric(band) || length(band) != 2L || !all(is.finite(band))) {
    cli::cli_abort("{.arg band} must be two finite numbers, {.code c(lo, hi)}.")
  }
  if (band[1] < 0) {
    cli::cli_abort("{.arg band} must not start below {.val {0}} Hz.")
  }
  if (band[1] >= band[2]) {
    cli::cli_abort(
      c("{.arg band} must be increasing.",
        "x" = "Got {.val {band[1]}} to {.val {band[2]}} Hz.")
    )
  }

  spec <- pr_calc_spectrum(trial, signal = signal, window = window)
  keep <- which(spec$freq_Hz >= band[1] & spec$freq_Hz <= band[2])

  if (length(keep) == 0L) {
    cli::cli_warn(c(
      "No frequency bin falls inside {.val {band[1]}}-{.val {band[2]}} Hz.",
      "i" = "Bin spacing is {.val {round(spec$freq_Hz[2], 4)}} Hz; a wider
             band or a longer recording is needed."
    ))
    return(tibble::tibble(stride_freq_Hz = NA_real_, peak_power = NA_real_))
  }

  i <- keep[which.max(spec$power[keep])]
  tibble::tibble(
    stride_freq_Hz = spec$freq_Hz[i],
    peak_power = spec$power[i]
  )
}

# Internal: band-pass a frame-level signal.
#
# Low pass: an `lp_window`-sample centred moving average. stats::filter()
# leaves NA at both ends where the window overhangs; those are back-filled
# from the raw signal, so the series keeps its full length and its edges
# stay usable (unsmoothed, but present) rather than becoming NA.
#
# High pass: subtract a running median over `hp_window_s` seconds. A median
# is used rather than a mean because it steps over the stride peaks instead
# of being dragged up by them, so the residual keeps its full amplitude.
# runmed() needs an odd width no longer than the series, so the width is
# rounded up to odd and clamped.
.tp_bandpass <- function(x, fs, lp_window, hp_window_s) {
  n <- length(x)
  lp <- if (lp_window <= 1L || n < lp_window) {
    x
  } else {
    z <- as.numeric(stats::filter(x, rep(1 / lp_window, lp_window), sides = 2))
    na <- is.na(z)
    z[na] <- x[na]
    z
  }
  k <- as.integer(round(hp_window_s * fs))
  if (k %% 2L == 0L) k <- k + 1L
  k_max <- if (n %% 2L == 0L) n - 1L else n
  k <- max(1L, min(k, k_max))
  if (k <= 1L) return(lp - lp)
  lp - as.numeric(stats::runmed(lp, k, endrule = "median"))
}

# Internal: local maxima of `x` at least `height` high, thinned so that no
# two survivors sit closer than `min_dist` samples.
#
# A peak is a strict local maximum: greater than both neighbours. Thinning
# is greedy from the tallest peak down, which is what a "minimum peak
# distance" conventionally means -- the tallest peak in a crowded run wins
# and suppresses its neighbours, rather than whichever happened to come
# first. Written in base R; no external peak-finding dependency.
.tp_find_peaks <- function(x, min_dist, height) {
  n <- length(x)
  if (n < 3L) return(integer(0))
  is_pk <- c(FALSE, x[-1] > x[-n]) & c(x[-n] > x[-1], FALSE)
  cand <- which(is_pk & x >= height)
  if (length(cand) < 2L || min_dist <= 1L) return(cand)
  keep <- integer(0)
  for (p in cand[order(x[cand], decreasing = TRUE)]) {
    if (all(abs(p - keep) >= min_dist)) keep <- c(keep, p)
  }
  sort(keep)
}

# Internal: the empty stride table, so every early return has one shape.
.tp_empty_cycles <- function() {
  tibble::tibble(
    cycle = integer(0), start_idx = integer(0), end_idx = integer(0),
    start_s = numeric(0), end_s = numeric(0), duration_s = numeric(0),
    peak_total = numeric(0), stride_freq = numeric(0)
  )
}

#' Segment a Recording into Stride Cycles
#'
#' Peak-to-peak segmentation of a never-unloading recording. The frame-level
#' signal is band-passed to isolate the stride oscillation from the baseline
#' the rider's mass sets, and each interval between two successive peaks of
#' that oscillation is one cycle.
#'
#' @details
#' This is the replacement for [pr_calc_gait_cycles()] on mats that stay
#' loaded. That function pairs a threshold crossing up with the next
#' crossing down; a saddle mat never crosses back down, so it returns a
#' single "cycle" spanning the whole recording no matter how
#' `force_threshold` is set. The problem is the segmentation model, not its
#' tuning, so nothing about `pr_calc_gait_cycles()` is changed here.
#'
#' The pipeline, in order:
#' 1. **Signal.** `signal` selects the frame-level series exactly as in
#'    [pr_calc_spectrum()]. `"total"` and `"mean"` differ by the constant
#'    `n_sensors`, so they give identical segmentation; only `peak_total`
#'    changes scale.
#' 2. **Low pass.** An `lp_window`-sample centred moving average. Frames at
#'    the two ends, where the window overhangs the recording, keep their raw
#'    value rather than becoming `NA`, so the first and last strides are
#'    still detectable.
#' 3. **High pass.** Subtract a running median over `hp_window_s` seconds.
#'    The median steps over the stride peaks instead of being pulled up by
#'    them, so the residual keeps its amplitude while the baseline drift —
#'    the rider settling, the horse changing gait — is removed.
#' 4. **Peaks.** Strict local maxima of the residual at or above
#'    `stats::quantile(residual[residual > 0], height_quantile)`, thinned
#'    tallest-first so no two peaks sit closer than
#'    `round(min_period_s * fs)` samples.
#' 5. **Cycles.** Every consecutive pair of peaks, keeping those whose
#'    duration lies in `[min_period_s, max_period_s]`.
#'
#' `cycle` numbers the peak pairs **before** the duration filter, so a gap
#' in the sequence marks an interval that was rejected as too short or too
#' long — information a renumbered column would hide.
#'
#' `peak_total` is the band-passed amplitude at the cycle's opening peak, in
#' the device's pressure unit. It is an excursion above the local baseline,
#' not a raw frame total: on the reference recording the frame totals run
#' 383-434 kPa while `peak_total` runs 2.5-13.8 kPa.
#'
#' @section Agreement with the source study:
#' On the 869-frame reference recording `ID052_K_K_KG00_MS`, the defaults
#' reproduce the study's own segmentation exactly: 14 cycles, identical
#' `cycle`, `start_idx`, `end_idx`, `duration_s`, `peak_total` and
#' `stride_freq` to machine precision. Rerun over the study's whole cohort,
#' all 323 of its 50 Hz recordings match cycle for cycle — 137,761 cycles,
#' no differences.
#'
#' The remaining 108 recordings were sampled at 10 Hz, and there the two
#' disagree. The study hard-coded its running-median width at 251 samples
#' and its minimum peak separation at 15 samples, which are 5 s and 0.3 s
#' only at 50 Hz; the parameters here are in seconds and scale with the
#' trial's own sampling rate. Passing `hp_window_s = 25.1` and
#' `min_period_s = 1.5` reproduces the study's fixed sample counts on a
#' 10 Hz recording.
#'
#' That difference shows up in the published cohort means. All 34,095 of
#' the study's slow-gait (`MG`) cycles come from 50 Hz recordings, and this
#' function returns their published mean duration of 0.719 s exactly. The
#' `MH` and `MS` means, 0.748 s and 0.773 s, mix in 10 Hz recordings; on
#' the 50 Hz half alone both this function and the study give 0.650 s and
#' 0.726 s.
#'
#' @inheritParams pr_calc_spectrum
#' @param signal Character. Frame-level signal to segment. Default
#'   `"total"`.
#' @param lp_window Integer. Width in samples of the centred moving average.
#'   Default `11L`. An odd width keeps the average centred; `1L` disables
#'   the low pass.
#' @param hp_window_s Numeric. Width in seconds of the running-median
#'   baseline. Default `5`.
#' @param min_period_s Numeric. Shortest acceptable cycle, in seconds, and
#'   the minimum peak separation. Default `0.3`.
#' @param height_quantile Numeric in `[0, 1)`. Peak height threshold, as a
#'   quantile of the positive part of the band-passed signal. Default `0.3`.
#' @param max_period_s Numeric. Longest acceptable cycle, in seconds.
#'   Default `3`; an interval longer than this is a detection gap rather
#'   than a stride.
#'
#' @return A [tibble::tibble] with one row per accepted cycle and columns
#'   `cycle` (integer, gapped — see *Details*), `start_idx`, `end_idx`
#'   (integer frame indices of the bounding peaks), `start_s`, `end_s`,
#'   `duration_s` (seconds), `peak_total` (band-passed amplitude at
#'   `start_idx`) and `stride_freq` (`1 / duration_s`, Hz). Zero rows when
#'   fewer than two peaks survive.
#' @family temporal structure functions
#' @seealso [pr_calc_dominant_freq()] for the frequency-domain estimate of
#'   the same rhythm, [pr_calc_phase_map()] to average the sensor map over
#'   these cycles.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' cycles <- pr_calc_stride_cycles(trial)
#' nrow(cycles)
#' round(range(cycles$duration_s), 2)
#'
#' # stride_freq is the reciprocal of duration_s, cycle by cycle:
#' all.equal(cycles$stride_freq, 1 / cycles$duration_s)
#'
#' # Cycles tile the recording end to end: each one starts where the
#' # previous accepted one stopped, unless an interval was rejected.
#' head(cbind(cycles$start_idx, cycles$end_idx), 3)
pr_calc_stride_cycles <- function(trial, signal = "total", lp_window = 11L,
                                  hp_window_s = 5, min_period_s = 0.3,
                                  height_quantile = 0.3, max_period_s = 3) {
  .validate_trial(trial)
  signal <- .tp_match_arg(signal, .tp_signals, "signal")
  lp_window <- .tp_check_count(lp_window, "lp_window")
  .tp_check_scalar(hp_window_s, "hp_window_s")
  .tp_check_scalar(min_period_s, "min_period_s")
  .tp_check_scalar(max_period_s, "max_period_s")
  .tp_check_scalar(height_quantile, "height_quantile")
  if (hp_window_s <= 0) {
    cli::cli_abort(
      "{.arg hp_window_s} must be positive, not {.val {hp_window_s}}."
    )
  }
  if (min_period_s <= 0) {
    cli::cli_abort(
      "{.arg min_period_s} must be positive, not {.val {min_period_s}}."
    )
  }
  if (max_period_s <= min_period_s) {
    cli::cli_abort(
      c("{.arg max_period_s} must exceed {.arg min_period_s}.",
        "x" = "Got {.val {max_period_s}} and {.val {min_period_s}} seconds.")
    )
  }
  if (height_quantile < 0 || height_quantile >= 1) {
    cli::cli_abort(
      "{.arg height_quantile} must be in {.code [0, 1)}, not
       {.val {height_quantile}}."
    )
  }

  fs <- .tp_fs(trial)
  x <- .tp_frame_signal(trial, signal)
  if (length(x) < 3L || anyNA(x)) return(.tp_empty_cycles())

  sig <- .tp_bandpass(x, fs, lp_window, hp_window_s)
  pos <- sig[sig > 0]
  # With nothing above the local baseline there is no oscillation to cut
  # into cycles; an infinite threshold rejects every candidate.
  height <- if (length(pos) == 0L) {
    Inf
  } else {
    unname(stats::quantile(pos, height_quantile))
  }

  peaks <- .tp_find_peaks(sig, max(1L, as.integer(round(min_period_s * fs))),
                          height)
  if (length(peaks) < 2L) return(.tp_empty_cycles())

  from <- peaks[-length(peaks)]
  to <- peaks[-1]
  tv <- as.numeric(trial$time)
  duration <- tv[to] - tv[from]
  # A plain floating-point comparison on the timestamp difference, which is
  # what makes an interval of nominally exactly min_period_s fall either
  # side depending on how the timestamps round. That is the study's
  # behaviour and is what reproduces its cycle numbering.
  keep <- !is.na(duration) & duration >= min_period_s &
    duration <= max_period_s

  # Everything is subset once, before the tibble is built: tibble()
  # evaluates its arguments in order and lets a later column see an earlier
  # one, so re-indexing a column by `keep` inside the call would filter
  # twice.
  from <- from[keep]
  to <- to[keep]
  duration <- duration[keep]

  tibble::tibble(
    cycle = seq_along(peaks)[-length(peaks)][keep],
    start_idx = as.integer(from),
    end_idx = as.integer(to),
    start_s = tv[from],
    end_s = tv[to],
    duration_s = duration,
    peak_total = sig[from],
    stride_freq = 1 / duration
  )
}

# Internal: validate a cycle table supplied by the caller.
.tp_check_cycles <- function(cycles, n_frames, call = rlang::caller_env()) {
  if (!is.data.frame(cycles)) {
    cli::cli_abort(
      "{.arg cycles} must be a data frame from {.fun pr_calc_stride_cycles},
       or {.code NULL}.",
      call = call
    )
  }
  missing <- setdiff(c("start_idx", "end_idx"), names(cycles))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c("{.arg cycles} is missing column{?s} {.val {missing}}.",
        "i" = "{.fun pr_calc_stride_cycles} supplies them."),
      call = call
    )
  }
  if (nrow(cycles) == 0L) return(invisible(cycles))
  s <- cycles$start_idx
  e <- cycles$end_idx
  if (!is.numeric(s) || !is.numeric(e) || anyNA(s) || anyNA(e)) {
    cli::cli_abort(
      "{.arg cycles} must have numeric, non-missing {.field start_idx} and
       {.field end_idx}.",
      call = call
    )
  }
  if (any(s < 1) || any(e > n_frames)) {
    cli::cli_abort(
      c("{.arg cycles} indexes frames outside the trial.",
        "x" = "The trial has {n_frames} frame{?s}; got
               {.val {min(s)}}-{.val {max(e)}}."),
      call = call
    )
  }
  if (any(e <= s)) {
    cli::cli_abort(
      "{.arg cycles} must have {.field end_idx} greater than
       {.field start_idx} in every row.",
      call = call
    )
  }
  invisible(cycles)
}

# Internal: mean of one bin across cycles, ignoring cycles that never
# reached the bin. NaN (no cycle contributed) becomes NA, not 0.
.tp_bin_mean <- function(v, trim) {
  v <- v[!is.na(v)]
  if (length(v) == 0L) return(NA_real_)
  mean(v, trim = trim)
}

#' Sensor Map Averaged Over the Stride Cycle
#'
#' Resamples the whole sensor map — all 256 cells on a saddle mat — onto
#' percent-of-cycle: for each phase bin, the mean pressure every sensor
#' carried while the stride was in that part of its cycle. This is the
#' ensemble average an animation or a phase-by-phase heatmap series is
#' drawn from.
#'
#' @details
#' Each cycle from [pr_calc_stride_cycles()] is stretched onto 0-100% of
#' itself — frame `i` of a cycle spanning `m` frames sits at
#' `(i - 1) / (m - 1) * 100` percent — and its frames are dropped into
#' `n_bins` equal-width bins, with 100% falling in the last bin. Every
#' sensor is averaged within a bin, giving one map per bin per cycle, and
#' those per-cycle maps are then averaged across cycles.
#'
#' Averaging per cycle first, rather than pooling all frames, weights every
#' stride equally. Pooling would let a long stride, which contributes more
#' frames, dominate the ensemble; strides in a recording vary in length by
#' a factor of three or more, so the difference is real.
#'
#' `trim` is passed to [mean()] as it averages across cycles within a bin,
#' so `trim = 0.1` discards the highest and lowest 10% of cycles in each
#' bin and each cell before averaging. That protects the ensemble from a
#' single stride where the horse stumbled or the rider shifted, at the cost
#' of ignoring genuine extremes. `trim = 0` gives the plain mean.
#'
#' Cycles shorter than `min_frames` frames are skipped: too few frames make
#' the phase bins mostly empty, and an empty bin contributes nothing rather
#' than a zero. A bin no cycle ever reached comes back `NA`.
#'
#' @section Agreement with the source study:
#' The study's phase maps used the plain mean across cycles (`trim = 0`).
#' On the reference recording `ID052_K_K_KG00_MS`, and on the same 14
#' cycles, this function at `trim = 0` reproduces all 2,560 of its values
#' with a correlation of 0.99998, a mean absolute difference of 0.007 kPa
#' and a maximum of 0.12 kPa, on values ranging up to 6.9 kPa. Close, but
#' not exact: the residual difference has not been traced to any documented
#' step, so treat the two as equivalent in aggregate rather than
#' interchangeable cell by cell. At the default `trim = 0.1` the same
#' comparison gives 0.011 kPa mean and 0.18 kPa maximum, the extra
#' difference being the trimming itself.
#'
#' @inheritParams pr_calc_spectrum
#' @param cycles A cycle table from [pr_calc_stride_cycles()], or `NULL`
#'   (default) to detect cycles with that function's defaults. Any data
#'   frame with `start_idx` and `end_idx` columns is accepted.
#' @param n_bins Integer. Number of phase bins spanning 0-100% of the
#'   cycle. Default `10L`.
#' @param trim Numeric in `[0, 0.5)`. Fraction trimmed from each end when
#'   averaging across cycles. Default `0.1`.
#' @param min_frames Integer. Cycles with fewer frames than this are
#'   skipped. Default `10L`.
#'
#' @return A [tibble::tibble] with `n_bins * n_sensors` rows, ordered by
#'   `phase_bin` then sensor, and columns `phase_bin` (integer, 1 to
#'   `n_bins`), `sensor`, `row`, `col` (integer, as in [pr_sensor_map()])
#'   and `mean_kPa`. Zero rows, with a warning, when no cycle qualifies.
#' @family temporal structure functions
#' @seealso [pr_sensor_map()] for the same map reduced over the whole
#'   recording instead of over the cycle.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' pm <- pr_calc_phase_map(trial)
#' nrow(pm) == 10 * trial$n_sensors
#'
#' # Where the load sits at the start of the cycle versus its middle:
#' first <- pm$mean_kPa[pm$phase_bin == 1]
#' mid <- pm$mean_kPa[pm$phase_bin == 5]
#' round(c(bin1 = max(first), bin5 = max(mid)), 2)
#'
#' # Averaged over all bins, the phase map returns the recording's own
#' # per-sensor mean to within the trimming:
#' avg <- tapply(pm$mean_kPa, pm$sensor, mean)
#' round(stats::cor(as.numeric(avg), pr_sensor_map(trial, "mean")$value), 3)
pr_calc_phase_map <- function(trial, cycles = NULL, n_bins = 10L, trim = 0.1,
                              min_frames = 10L) {
  .validate_trial(trial)
  n_bins <- .tp_check_count(n_bins, "n_bins")
  min_frames <- .tp_check_count(min_frames, "min_frames", min = 2L)
  .tp_check_scalar(trim, "trim")
  if (trim < 0 || trim >= 0.5) {
    cli::cli_abort(
      "{.arg trim} must be in {.code [0, 0.5)}, not {.val {trim}}."
    )
  }

  P <- trial$pressure
  coords <- trial$layout$coords_mm
  if (nrow(coords) != ncol(P)) {
    cli::cli_abort(
      "Layout has {nrow(coords)} coordinate row{?s} but {.arg trial} has
       {ncol(P)} pressure column{?s}."
    )
  }
  if (is.null(cycles)) cycles <- pr_calc_stride_cycles(trial)
  .tp_check_cycles(cycles, nrow(P))

  n_sensors <- ncol(P)
  span <- as.integer(cycles$end_idx) - as.integer(cycles$start_idx) + 1L
  use <- which(span >= min_frames)

  if (length(use) == 0L) {
    cli::cli_warn(c(
      "No cycle has at least {min_frames} frame{?s}.",
      "i" = "{nrow(cycles)} cycle{?s} were offered; returning no rows."
    ))
    return(tibble::tibble(
      phase_bin = integer(0), sensor = integer(0), row = integer(0),
      col = integer(0), mean_kPa = numeric(0)
    ))
  }

  # One n_bins x n_sensors map per cycle, then averaged across cycles.
  per_cycle <- array(NA_real_, c(length(use), n_bins, n_sensors))
  width <- 100 / n_bins
  for (k in seq_along(use)) {
    i <- use[k]
    idx <- as.integer(cycles$start_idx[i]):as.integer(cycles$end_idx[i])
    m <- length(idx)
    pct <- (seq_len(m) - 1) / (m - 1) * 100
    bin <- pmin(n_bins, as.integer(floor(pct / width)) + 1L)
    # rowsum() gives every bin's sensor sums in a single pass over the
    # cycle's frames; dividing by the bin counts turns them into means.
    sums <- rowsum(P[idx, , drop = FALSE], bin, reorder = TRUE)
    hit <- as.integer(rownames(sums))
    per_cycle[k, hit, ] <- sums / tabulate(bin, n_bins)[hit]
  }

  mval <- apply(per_cycle, c(2L, 3L), .tp_bin_mean, trim = trim)
  if (n_bins == 1L) mval <- matrix(mval, nrow = 1L)

  tibble::tibble(
    phase_bin = rep(seq_len(n_bins), each = n_sensors),
    sensor = rep(as.integer(coords$sensor_id), times = n_bins),
    row = rep(as.integer(coords$row), times = n_bins),
    col = rep(as.integer(coords$col), times = n_bins),
    mean_kPa = as.numeric(t(mval))
  )
}

# Internal: x/y coordinates from a pr_cop object or a coordinate table.
.tp_cop_xy <- function(cop, call = rlang::caller_env()) {
  if (inherits(cop, "pr_cop")) {
    return(list(x = as.numeric(cop$x), y = as.numeric(cop$y)))
  }
  nms <- names(cop)
  if (is.list(cop) && all(c("x", "y") %in% nms)) {
    return(list(x = as.numeric(cop$x), y = as.numeric(cop$y)))
  }
  if (is.list(cop) && all(c("cop_row", "cop_col") %in% nms)) {
    # Grid indices: the column axis runs left-right, so it is x.
    return(list(x = as.numeric(cop$cop_col), y = as.numeric(cop$cop_row)))
  }
  cli::cli_abort(
    c("{.arg cop} must be a {.cls pr_cop} object or a data frame of
       coordinates.",
      "i" = "Accepted column pairs: {.field x}/{.field y}, or
             {.field cop_row}/{.field cop_col}."),
    call = call
  )
}

# Internal: is c to the left of the directed line a -> b?
.tp_ccw <- function(ax, ay, bx, by, cx, cy) {
  (cy - ay) * (bx - ax) > (by - ay) * (cx - ax)
}

# Internal: number of self-intersections of the polyline (x, y).
#
# Segment i and segment j cross when each straddles the other's supporting
# line, which the four CCW orientation tests below decide without any
# division. Segments are compared only with those at least two apart:
# neighbours always share an endpoint, and on a closed loop so do the first
# and the last. Collinear overlaps are not counted as crossings.
.tp_crossings <- function(x, y, closed) {
  m <- length(x) - 1L
  if (m < 3L) return(0L)
  total <- 0L
  for (i in seq_len(m - 2L)) {
    j <- seq.int(i + 2L, m)
    if (closed && i == 1L) j <- j[j < m]
    if (length(j) == 0L) next
    ax <- x[i]; ay <- y[i]; bx <- x[i + 1L]; by <- y[i + 1L]
    cx <- x[j]; cy <- y[j]; dx <- x[j + 1L]; dy <- y[j + 1L]
    straddle_ab <- .tp_ccw(ax, ay, cx, cy, dx, dy) !=
      .tp_ccw(bx, by, cx, cy, dx, dy)
    straddle_cd <- .tp_ccw(ax, ay, bx, by, cx, cy) !=
      .tp_ccw(ax, ay, bx, by, dx, dy)
    total <- total + sum(straddle_ab & straddle_cd)
  }
  as.integer(total)
}

#' Loop Geometry of a COP Trajectory
#'
#' Describes a centre-of-pressure trajectory as a loop: how far its end
#' lands from its start, and whether the path crosses itself on the way.
#'
#' @details
#' A stride that returns the rider to where they began traces a closed
#' loop, and how that loop is shaped separates a clean, repeatable seat
#' from a wandering one. Two numbers capture most of it:
#'
#' * `closure_dist` — the straight-line distance from the last point back to
#'   the first, in whatever units the trajectory carries. Small relative to
#'   the path travelled means the trajectory came home.
#' * `n_crossings` — how many times the path cuts through itself. A simple
#'   oval crosses zero times; a figure-of-eight crosses once; a trajectory
#'   that scribbles crosses many times. `self_intersects` is
#'   `n_crossings > 0`.
#'
#' With `close = TRUE` (default) the first point is appended to the end
#' before the crossing sweep, so the closing chord counts as part of the
#' loop — the right question for a cycle that should repeat. With
#' `close = FALSE` only the path as travelled is examined. Either way
#' `closure_dist` and `path_length` describe the open trajectory.
#'
#' Crossings are counted with orientation tests on every pair of
#' non-adjacent segments, an exact predicate with no tolerance to tune.
#' Two segments that merely touch end to end, or that overlap along a line,
#' are not counted; only a genuine transverse crossing is. The sweep is
#' quadratic in the number of points, which is immaterial for one stride
#' and worth remembering before feeding it a whole recording.
#'
#' Units are the input's own and nothing is converted: a `pr_cop` from
#' [pr_calc_cop()] is in millimetres, while `cop_row`/`cop_col` from
#' [pr_calc_cop_grid()] or [pr_frame_metrics()] are in grid index units, so
#' `path_length` and `closure_dist` follow suit. `closure_ratio` is
#' dimensionless and comparable across both.
#'
#' Missing coordinates are dropped pairwise before anything is measured —
#' [pr_calc_cop()] returns `NA` for unloaded frames.
#'
#' @param cop A `pr_cop` object from [pr_calc_cop()], or a data frame with
#'   `x`/`y` columns, or one with `cop_row`/`cop_col` columns as returned by
#'   [pr_calc_cop_grid()] and [pr_frame_metrics()] (`cop_col` is treated as
#'   x, `cop_row` as y).
#' @param close Logical. Append the first point to the end before looking
#'   for crossings. Default `TRUE`.
#'
#' @return A one-row [tibble::tibble] with columns `n_points` (integer,
#'   after dropping missing coordinates), `path_length`, `closure_dist`,
#'   `closure_ratio` (`closure_dist / path_length`, `NA` for a stationary
#'   trajectory), `self_intersects` (logical) and `n_crossings` (integer).
#' @family temporal structure functions
#' @seealso [pr_calc_cop_grid()] and [pr_frame_metrics()] for trajectories
#'   in grid units, [pr_calc_cop()] for millimetres.
#' @export
#' @examples
#' # A clean rectangle: comes home, never crosses itself.
#' square <- data.frame(x = c(0, 1, 1, 0), y = c(0, 0, 1, 1))
#' pr_cop_shape(square)
#'
#' # A bow tie crosses once.
#' bow <- data.frame(x = c(0, 1, 0, 1), y = c(0, 0, 1, 1))
#' pr_cop_shape(bow)$n_crossings
#'
#' # One stride of a real trajectory, in grid index units:
#' trial <- pr_example_trial("saddle_horse")
#' cycles <- pr_calc_stride_cycles(trial)
#' cop <- pr_calc_cop_grid(trial)
#' pr_cop_shape(cop[cycles$start_idx[1]:cycles$end_idx[1], ])
pr_cop_shape <- function(cop, close = TRUE) {
  .tp_check_flag(close, "close")
  xy <- .tp_cop_xy(cop)
  x <- xy$x
  y <- xy$y
  if (length(x) != length(y)) {
    cli::cli_abort(
      "{.arg cop} has {length(x)} x-coordinate{?s} but {length(y)}
       y-coordinate{?s}."
    )
  }

  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]
  y <- y[ok]
  n <- length(x)
  if (n == 0L) {
    cli::cli_abort(
      c("{.arg cop} has no complete coordinate pairs.",
        "i" = "Every point had a missing x or y.")
    )
  }

  path_length <- if (n >= 2L) sum(sqrt(diff(x)^2 + diff(y)^2)) else 0
  closure_dist <- sqrt((x[n] - x[1])^2 + (y[n] - y[1])^2)

  if (close && n >= 2L && closure_dist > 0) {
    x <- c(x, x[1])
    y <- c(y, y[1])
  }
  # A trajectory that already ends where it started is closed as given.
  is_closed <- length(x) >= 2L &&
    x[length(x)] == x[1] && y[length(y)] == y[1]
  n_crossings <- .tp_crossings(x, y, is_closed)

  closure_ratio <- if (path_length > 0) closure_dist / path_length else NA_real_

  tibble::tibble(
    n_points = n,
    path_length = path_length,
    closure_dist = closure_dist,
    closure_ratio = closure_ratio,
    self_intersects = n_crossings > 0L,
    n_crossings = n_crossings
  )
}
