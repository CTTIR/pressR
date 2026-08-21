# ---------------------------------------------------------------------------
# Per-sensor and cohort aggregation layer.
#
# Two reductions of a pressure recording are missing from the rest of the
# package, and almost everything a cohort analysis wants is built from them:
#
#   over time, per sensor  -> pr_sensor_map()      (n_sensors values)
#   over sensors, per frame -> pr_frame_metrics()  (R/frame-metrics.R)
#
# pr_sensor_map() is the first of those: the maximum pressure picture, the
# per-sensor mean map, the per-sensor pressure-time integral and the
# per-sensor duty cycle are all one call with a different `statistic`, and
# they all come back in the same tidy shape with grid coordinates attached,
# so a heatmap, a difference map and a feature vector are the same object.
#
# pr_profile_matrix() stacks that vector across a cohort into the
# n_trials x n_sensors design matrix that prcomp(), dist() or any classifier
# expects, and pr_batch_frame_summary() reduces the *frame* side to one row
# per recording.
#
# Memory contract: pr_batch_frame_summary() is the only function here that
# sees a whole cohort, and it never holds more than one trial's frame table
# at a time. The real study is 431 recordings and 5.5 M frames; materialising
# every frame table first would cost several gigabytes for nine numbers per
# recording.
#
# Unit conventions follow R/frame-metrics.R exactly: pressure in the device's
# own unit (kPa), COP in grid index units, no area conversion anywhere.
# ---------------------------------------------------------------------------

# The statistics pr_sensor_map() knows, in signature order.
.sm_statistics <- c("mean", "max", "sd", "pti", "pct_zero")

# Internal: resolve the `statistic` argument, tolerating the full default
# vector that match.arg() would normally handle.
.sm_match_statistic <- function(statistic, call = rlang::caller_env()) {
  # Bound locally: cli would read a `{.sm_statistics}` substitution as a
  # style name, because it starts with a dot.
  known <- .sm_statistics
  if (!is.character(statistic) || length(statistic) < 1L || anyNA(statistic)) {
    cli::cli_abort(
      "{.arg statistic} must be one of {.val {known}}.",
      call = call
    )
  }
  if (length(statistic) > 1L) {
    if (!identical(statistic, .sm_statistics)) {
      cli::cli_abort(
        "{.arg statistic} must be a single string, not {length(statistic)}.",
        call = call
      )
    }
    return(.sm_statistics[1])
  }
  if (!statistic %in% known) {
    cli::cli_abort(
      c("{.arg statistic} must be one of {.val {known}}.",
        "x" = "Got {.val {statistic}}."),
      call = call
    )
  }
  statistic
}

# Internal: a single finite number.
.sm_check_scalar <- function(x, arg, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    cli::cli_abort("{.arg {arg}} must be a single finite number.", call = call)
  }
  invisible(x)
}

# Internal: a single TRUE/FALSE.
.sm_check_flag <- function(x, arg, call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
                   call = call)
  }
  invisible(x)
}

# Internal: coerce a pr_dataset / list of trials to a plain list of trials.
.sm_trials <- function(dataset, arg = "dataset", call = rlang::caller_env()) {
  trials <- if (inherits(dataset, "pr_dataset")) dataset$trials else dataset
  ok <- is.list(trials) && !is.data.frame(trials) &&
    all(vapply(trials, inherits, logical(1), "pr_trial"))
  if (!ok) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls pr_dataset} or a list of
       {.cls pr_trial} objects.",
      call = call
    )
  }
  trials
}

# Internal: identifying label for one trial, used for matrix row names and
# for error messages. Mirrors the order used elsewhere in the cohort layer.
.sm_trial_label <- function(trial, i) {
  md <- trial$metadata
  for (nm in c("trial_id", "file_label", "subject_id")) {
    v <- md[[nm]]
    if (!is.null(v) && length(v) == 1L && !is.na(v) &&
        nzchar(as.character(v))) {
      return(as.character(v))
    }
  }
  paste0("trial_", i)
}

.sm_trial_labels <- function(trials) {
  make.unique(
    vapply(seq_along(trials), function(i) .sm_trial_label(trials[[i]], i),
           character(1)),
    sep = "_"
  )
}

# Internal: TRUE when zeroing sub-threshold cells can change a value. With
# the default threshold of 0 on a non-negative matrix it cannot, and the
# copy of a cohort-sized matrix is skipped.
.sm_needs_mask <- function(P, threshold) {
  length(P) > 0L && (threshold > 0 || any(P < 0, na.rm = TRUE))
}

# Internal: per-column standard deviation, computed on the centred matrix
# rather than from the sum of squares so it does not lose precision on the
# large-mean/small-variance columns a loaded sensor produces.
.sm_col_sd <- function(P) {
  n <- nrow(P)
  if (n < 2L) return(rep(NA_real_, ncol(P)))
  d <- P - rep(colMeans(P), each = n)
  sqrt(colSums(d * d) / (n - 1))
}

# Internal: the per-sensor reduction itself, on a validated trial.
#
# Everything is a whole-matrix operation except `max`, which uses apply()
# over the (few hundred) columns; the alternative, max.col() on t(P),
# transposes the whole recording and is slower.
.sm_sensor_stat <- function(trial, statistic, threshold) {
  P <- trial$pressure
  if (identical(statistic, "pct_zero")) {
    return(colMeans(P <= threshold))
  }
  if (.sm_needs_mask(P, threshold)) P[P <= threshold] <- 0

  switch(
    statistic,
    mean = colMeans(P),
    max  = if (ncol(P) == 0L) numeric(0) else apply(P, 2L, max),
    sd   = .sm_col_sd(P),
    pti  = {
      # Same trapezoidal rule as pr_calc_pti(), reused rather than
      # reimplemented; the masked matrix is swapped in so `threshold` is
      # honoured without a second definition of the integral.
      trial$pressure <- P
      pr_calc_pti(trial)
    }
  )
}

#' Per-Sensor Statistics Over Time
#'
#' Reduces a recording along the time axis: one number per sensor, with the
#' sensor's grid coordinates attached. This is the counterpart of
#' [pr_frame_metrics()], which reduces along the sensor axis instead.
#'
#' @details
#' The available statistics, for a sensor read at every frame:
#' * `"mean"` — mean pressure, unloaded frames included in the denominator.
#' * `"max"` — the maximum pressure picture (MPP): the peak this sensor ever
#'   saw. `pr_sensor_map(trial, "max")$value` is the map
#'   [pr_plot_heatmap()] draws.
#' * `"sd"` — standard deviation over frames (`NA` for a single-frame
#'   trial), i.e. how much this sensor's load fluctuated.
#' * `"pti"` — pressure-time integral, trapezoidal over the trial's own
#'   timestamps; identical to [pr_calc_pti()] at the default threshold.
#' * `"pct_zero"` — fraction of frames in which the sensor was at or below
#'   `threshold`. `1` means never loaded, `0` means always loaded; it is the
#'   per-sensor duty cycle, and `1 - pct_zero` is the fraction of the
#'   recording the sensor was in contact.
#'
#' `threshold` treats cells at or below it as unloaded, exactly as in
#' [pr_frame_metrics()]: they are zeroed before `mean`, `sd` and `pti` are
#' taken, they cannot raise `max`, and they are what `pct_zero` counts. At
#' the default `threshold = 0` on non-negative data no masking is needed and
#' none is done.
#'
#' The `sensor` column is the *pressure column index*, taken positionally
#' from `trial$layout$coords_mm`, not the device channel number. For a
#' layout built by [pr_layout_from_index_map()] the two differ, and
#' `pr_channel_order(trial$layout)[sensor]` recovers the device channel.
#' Rows come back in that same column-major grid order, so `$value` can be
#' used as a feature vector directly.
#'
#' @param trial A [pr_trial] object.
#' @param statistic Character. One of `"mean"`, `"max"`, `"sd"`, `"pti"` or
#'   `"pct_zero"`. See *Details*.
#' @param threshold Numeric. Cells at or below this value count as unloaded.
#'   Default `0`.
#'
#' @return A [tibble::tibble] with one row per sensor and columns `sensor`
#'   (integer), `row`, `col` (integer grid indices) and `value` (numeric).
#' @family sensor aggregation functions
#' @seealso [pr_frame_metrics()] for the per-frame reduction,
#'   [pr_profile_matrix()] to stack this across a dataset.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' mpp <- pr_sensor_map(trial, "max")
#' mpp[which.max(mpp$value), ]
#'
#' # The mean map is never above the peak map, sensor for sensor:
#' avg <- pr_sensor_map(trial, "mean")
#' all(avg$value <= mpp$value + 1e-9)
#'
#' # Fraction of the recording each sensor spent in contact:
#' duty <- 1 - pr_sensor_map(trial, "pct_zero")$value
#' round(range(duty), 3)
pr_sensor_map <- function(trial,
                          statistic = c("mean", "max", "sd", "pti",
                                        "pct_zero"),
                          threshold = 0) {
  .validate_trial(trial)
  statistic <- .sm_match_statistic(statistic)
  .sm_check_scalar(threshold, "threshold")

  P <- trial$pressure
  if (nrow(P) == 0L) {
    cli::cli_abort(
      c("{.arg trial} has no frames.",
        "i" = "A per-sensor statistic over zero frames is undefined.")
    )
  }
  coords <- trial$layout$coords_mm
  if (nrow(coords) != ncol(P)) {
    cli::cli_abort(
      "Layout has {nrow(coords)} coordinate row{?s} but {.arg trial} has
       {ncol(P)} pressure column{?s}."
    )
  }

  tibble::tibble(
    sensor = as.integer(coords$sensor_id),
    row = as.integer(coords$row),
    col = as.integer(coords$col),
    value = as.numeric(.sm_sensor_stat(trial, statistic, threshold))
  )
}

#' Per-Sensor Feature Matrix for a Dataset
#'
#' Stacks [pr_sensor_map()] across every trial in a dataset: a
#' `n_trials x n_sensors` numeric matrix whose rows are recordings and whose
#' columns are sensors, in layout (column-major grid) order. This is the
#' input `stats::prcomp()`, `stats::dist()`, `stats::cmdscale()` or a
#' classifier expects, with no further reshaping.
#'
#' @details
#' Row names are the trials' identifying metadata (`trial_id`, else
#' `file_label`, else `subject_id`, else `trial_<i>`), made unique with
#' [make.unique()]. Column names are `sensor_<id>` taken from the first
#' trial's layout.
#'
#' Every trial must expose the same number of sensors, since column `k` has
#' to mean the same grid cell in every row; a mismatch is an error rather
#' than a recycled row. Differing *layout names* at the same sensor count
#' are only a warning: two layouts may legitimately share a grid, but if
#' they do not, the matrix silently compares different anatomy, so the
#' warning is worth reading.
#'
#' @param dataset A [pr_dataset] object, or a list of [pr_trial] objects.
#' @param statistic Character. Any statistic accepted by [pr_sensor_map()].
#'   Default `"mean"`.
#' @inheritParams pr_sensor_map
#'
#' @return A numeric matrix with `length(dataset)` rows and `n_sensors`
#'   columns, with row and column names as described above.
#' @family sensor aggregation functions
#' @seealso [pr_sensor_map()] for a single trial.
#' @export
#' @examples
#' ds <- pr_dataset(lapply(1:3, function(s) {
#'   pr_example_trial("saddle_horse", seed = s)
#' }))
#' X <- pr_profile_matrix(ds, "mean")
#' dim(X)
#' X[, 1:4]
#'
#' # Straight into a PCA of pressure distribution shape:
#' pc <- stats::prcomp(X)
#' round(pc$sdev[1:2], 3)
pr_profile_matrix <- function(dataset, statistic = "mean", threshold = 0) {
  trials <- .sm_trials(dataset)
  statistic <- .sm_match_statistic(statistic)
  .sm_check_scalar(threshold, "threshold")

  n <- length(trials)
  if (n == 0L) {
    cli::cli_abort(
      c("{.arg dataset} contains no trials.",
        "i" = "A feature matrix needs at least one recording.")
    )
  }

  n_sensors <- vapply(trials, function(t) ncol(t$pressure), integer(1))
  if (length(unique(n_sensors)) > 1L) {
    tab <- sort(unique(n_sensors))
    cli::cli_abort(c(
      "Every trial must have the same number of sensors.",
      "x" = "Found {.val {tab}}.",
      "i" = "Column {.val k} of the matrix must mean the same grid cell in
             every row."
    ))
  }

  lay_names <- unique(vapply(trials, function(t) t$layout$name, character(1)))
  if (length(lay_names) > 1L) {
    cli::cli_warn(c(
      "Trials use {length(lay_names)} different layouts: {.val {lay_names}}.",
      "i" = "Sensor columns are only comparable if those layouts share a
             grid."
    ))
  }

  out <- matrix(NA_real_, nrow = n, ncol = n_sensors[1])
  for (i in seq_len(n)) {
    tr <- trials[[i]]
    label <- .sm_trial_label(tr, i)
    if (nrow(tr$pressure) == 0L) {
      cli::cli_abort("Trial {.val {label}} has no frames.")
    }
    if (nrow(tr$layout$coords_mm) != ncol(tr$pressure)) {
      cli::cli_abort(
        "Trial {.val {label}} has {nrow(tr$layout$coords_mm)} coordinate
         row{?s} but {ncol(tr$pressure)} pressure column{?s}."
      )
    }
    out[i, ] <- as.numeric(.sm_sensor_stat(tr, statistic, threshold))
  }

  rownames(out) <- .sm_trial_labels(trials)
  colnames(out) <- paste0("sensor_",
                          as.integer(trials[[1]]$layout$coords_mm$sensor_id))
  out
}

# Internal: the nine per-recording frame statistics, in the cohort's own
# column order. Named here once so the summary table and its validation
# cannot drift apart.
.sm_frame_summary_cols <- c(
  "mean_kPa_avg", "mean_kPa_sd", "peak_kPa_max", "peak_kPa_avg",
  "total_kPa_avg", "loaded_avg", "cop_row_mean", "cop_col_mean", "n_frames"
)

# Internal: reduce one trial's frame table to those nine numbers.
.sm_frame_summary_row <- function(fm) {
  c(
    mean_kPa_avg  = mean(fm$mean_kPa),
    mean_kPa_sd   = stats::sd(fm$mean_kPa),
    peak_kPa_max  = max(fm$peak_kPa),
    peak_kPa_avg  = mean(fm$peak_kPa),
    total_kPa_avg = mean(fm$total_kPa),
    loaded_avg    = mean(fm$loaded),
    cop_row_mean  = mean(fm$cop_row),
    cop_col_mean  = mean(fm$cop_col),
    n_frames      = nrow(fm)
  )
}

# Internal: one metadata field across trials as a single column, or NULL
# when the field is unusable. Length-1 atomic values only; classes that
# unlist() would flatten (Date, POSIXct) are preserved, factors are not.
.sm_meta_column <- function(trials, field, strict,
                            call = rlang::caller_env()) {
  vals <- lapply(trials, function(t) t$metadata[[field]])
  usable <- vapply(
    vals,
    function(v) !is.null(v) && is.atomic(v) && length(v) == 1L,
    logical(1)
  )
  if (!all(usable)) {
    if (strict) {
      cli::cli_abort(c(
        "Metadata field {.val {field}} is not a single value in every trial.",
        "x" = "{sum(!usable)} trial{?s} {?is/are} missing it, or hold
               more than one value."
      ), call = call)
    }
    return(NULL)
  }

  cls <- unique(vapply(vals, function(v) class(v)[1], character(1)))
  if (length(cls) > 1L || identical(cls, "factor")) {
    vals <- lapply(vals, as.character)
  }
  # c() dispatches on the first value's class, so Date/POSIXct survive where
  # unlist() would flatten them to numbers; names never belong on a column.
  unname(do.call(c, vals))
}

# Internal: resolve the metadata columns of the batch summary.
.sm_meta_columns <- function(trials, meta_fields,
                             call = rlang::caller_env()) {
  auto <- is.null(meta_fields)
  if (auto) {
    meta_fields <- unique(unlist(lapply(trials, function(t) {
      names(t$metadata)
    })))
    meta_fields <- setdiff(meta_fields, .sm_frame_summary_cols)
  } else {
    if (!is.character(meta_fields) || anyNA(meta_fields)) {
      cli::cli_abort(
        "{.arg meta_fields} must be a character vector of metadata field
         names, or {.code NULL}.",
        call = call
      )
    }
    clash <- intersect(meta_fields, .sm_frame_summary_cols)
    if (length(clash) > 0L) {
      cli::cli_abort(c(
        "{.arg meta_fields} must not name {.val {clash}}.",
        "i" = "Those columns are computed from the frames themselves."
      ), call = call)
    }
    known <- unique(unlist(lapply(trials, function(t) names(t$metadata))))
    unknown <- setdiff(meta_fields, known)
    if (length(unknown) > 0L) {
      cli::cli_abort(c(
        "{.arg meta_fields} names {length(unknown)} metadata field{?s} that
         no trial carries: {.val {unknown}}.",
        "i" = "Available fields: {.val {known}}."
      ), call = call)
    }
  }

  cols <- list()
  for (f in meta_fields) {
    v <- .sm_meta_column(trials, f, strict = !auto, call = call)
    if (is.null(v)) next
    if (auto && all(is.na(v))) next
    cols[[f]] <- v
  }
  cols
}

#' Per-Recording Frame Summary for a Whole Cohort
#'
#' Runs [pr_frame_metrics()] over every trial in a dataset and reduces each
#' frame table to a single row: the nine summary statistics a cohort
#' analysis reports per recording, plus the trial's metadata.
#'
#' @details
#' Columns, in order: the requested metadata fields, then
#' * `mean_kPa_avg` — mean over frames of the whole-grid frame mean.
#' * `mean_kPa_sd` — standard deviation over frames of that same quantity,
#'   i.e. how much overall load varied during the recording (`NA` for a
#'   single-frame trial).
#' * `peak_kPa_max` — the largest single-sensor reading anywhere in the
#'   recording. On a saturating device this pins to the hardware ceiling.
#' * `peak_kPa_avg` — mean over frames of the frame maximum. Together with
#'   `mean_kPa_avg` this gives the concentration index
#'   `peak_kPa_avg / mean_kPa_avg` (see [pr_calc_pci()]).
#' * `total_kPa_avg` — mean over frames of the frame sum. Exactly
#'   `mean_kPa_avg * n_sensors`; a sum of pressures, never a force.
#' * `loaded_avg` — mean over frames of the loaded cell count.
#' * `cop_row_mean`, `cop_col_mean` — mean over frames of the centre of
#'   pressure, in grid index units.
#' * `n_frames` — frames in the recording, after any the reader dropped.
#'
#' These names and definitions are the cohort contract, chosen so the result
#' can be compared column-for-column against a study's own summary table.
#' Note that `mean_kPa_avg` is the *whole-grid* mean including unloaded
#' cells (see [pr_calc_mean_pressure_grid()]), which is a different quantity
#' from [pr_calc_mean_pressure()].
#'
#' @section Memory:
#' The frame tables are built and discarded one at a time, so peak memory is
#' one recording's frames, not the cohort's. That matters: 431 recordings of
#' 5.5 M frames total would need several gigabytes if every frame table were
#' materialised first, to produce nine numbers each.
#'
#' @param dataset A [pr_dataset] object, or a list of [pr_trial] objects.
#' @param threshold Numeric. Cells at or below this value count as unloaded;
#'   passed to [pr_frame_metrics()], where it affects `loaded` and the COP
#'   weighting only. Default `0`.
#' @param meta_fields Character vector of metadata field names to prepend,
#'   in the order given. `NULL` (default) auto-detects: every field that
#'   holds a single value in every trial, dropping those that are `NA`
#'   throughout. Pass `character(0)` for the nine statistics alone.
#' @param .progress Logical. Show a progress bar over trials. Default
#'   `FALSE`.
#'
#' @return A [tibble::tibble] with one row per trial.
#' @family sensor aggregation functions
#' @seealso [pr_frame_metrics()] for the per-frame table this summarises,
#'   [pr_design_table()] for the metadata side alone.
#' @export
#' @examples
#' ds <- pr_dataset(list(
#'   pr_example_trial("saddle_horse", seed = 1),
#'   pr_example_trial("saddle_horse", seed = 2)
#' ))
#' fs <- pr_batch_frame_summary(ds, meta_fields = character(0))
#' names(fs)
#' round(fs$mean_kPa_avg, 3)
#'
#' # total_kPa_avg is mean_kPa_avg scaled by the sensor count:
#' n_sensors <- ds$trials[[1]]$layout$n_sensors
#' all.equal(fs$total_kPa_avg, fs$mean_kPa_avg * n_sensors)
pr_batch_frame_summary <- function(dataset, threshold = 0,
                                   meta_fields = NULL, .progress = FALSE) {
  trials <- .sm_trials(dataset)
  .sm_check_scalar(threshold, "threshold")
  .sm_check_flag(.progress, ".progress")

  n <- length(trials)
  meta_cols <- .sm_meta_columns(trials, meta_fields)

  if (n == 0L) {
    empty <- lapply(.sm_frame_summary_cols, function(nm) numeric(0))
    names(empty) <- .sm_frame_summary_cols
    empty$n_frames <- integer(0)
    return(tibble::as_tibble(c(meta_cols, empty)))
  }

  stat <- matrix(
    NA_real_, nrow = n, ncol = length(.sm_frame_summary_cols),
    dimnames = list(NULL, .sm_frame_summary_cols)
  )

  if (.progress) {
    cli::cli_progress_bar(
      "Summarising trials", total = n, .envir = environment()
    )
  }
  for (i in seq_len(n)) {
    tr <- trials[[i]]
    if (nrow(tr$pressure) == 0L) {
      label <- .sm_trial_label(tr, i)
      cli::cli_abort(
        c("Trial {.val {label}} has no frames.",
          "i" = "A frame summary over zero frames is undefined.")
      )
    }
    # One frame table at a time: built, reduced to nine numbers, dropped.
    fm <- pr_frame_metrics(tr, threshold = threshold)
    stat[i, ] <- .sm_frame_summary_row(fm)
    rm(fm)
    if (.progress) cli::cli_progress_update(.envir = environment())
  }

  stat_cols <- as.list(as.data.frame(stat))
  stat_cols$n_frames <- as.integer(stat_cols$n_frames)

  tibble::as_tibble(c(meta_cols, stat_cols))
}
