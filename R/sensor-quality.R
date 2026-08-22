# ---------------------------------------------------------------------------
# Hardware quality control and spatial gradients.
#
# Everything above this file treats a reading as a measurement. This file
# asks the prior question: is the sensor that produced it working?
#
# A capacitive mat that has been rolled, washed and sat on for a few hundred
# recordings does not fail all at once. It fails one cell at a time, and the
# two failure modes look nothing alike in a summary statistic:
#
#   * a DEAD cell reads zero almost always, which drags the whole-grid mean
#     down and is invisible in any loaded-cells-only metric;
#   * a SATURATED cell pins to the hardware ceiling, which caps the frame
#     peak and therefore caps `peak_kPa_max`, `pr_calc_pci()` and every
#     peak-derived number in the cohort.
#
# Neither is detectable from one recording -- a cell that reads zero for ten
# minutes may simply have had nothing on it. It takes the whole cohort:
# a cell that is zero in 97% of frames across 431 independent recordings,
# with 431 different horses, saddles and riders on the mat, is broken.
# pr_sensor_quality() is that cohort-wide verdict, one row per sensor.
#
# pr_calc_gradient() is the spatial counterpart of the same idea: how
# sharply pressure changes from one cell to its neighbours. A high gradient
# is a pressure edge -- the rim of a saddle panel, the boundary of a bridge
# -- and a lone high-gradient cell in an otherwise smooth field is usually a
# miscalibrated sensor rather than anatomy.
#
# Unit conventions follow R/frame-metrics.R and R/sensor-map.R: pressure in
# the device's own unit (kPa), distance in grid cells. A gradient here is
# therefore kPa per sensor spacing, never kPa/mm -- this device published no
# pitch, so kPa/mm would be fabricated. See the 'Missing physical scale'
# section of pr_layout_from_index_map().
# ---------------------------------------------------------------------------

# The cohort's fixed flag vocabulary, in precedence order: a sensor that
# qualifies for more than one flag gets the earliest. The strings are the
# study's own labels and are reported verbatim, so a result table can be
# compared row-for-row against the published one.
.sq_flags <- c(
  dead      = "Dead (>95% zero)",
  saturated = "Saturated (>60 kPa)",
  low_var   = "Low variance",
  ok        = "OK"
)

# The differencing schemes pr_calc_gradient() knows.
.sq_gradient_methods <- c("central", "forward")

# Internal: a single finite number inside [lo, hi].
.sq_check_range <- function(x, arg, lo, hi, call = rlang::caller_env()) {
  .sm_check_scalar(x, arg, call = call)
  if (x < lo || x > hi) {
    cli::cli_abort(
      "{.arg {arg}} must be between {.val {lo}} and {.val {hi}}, not
       {.val {x}}.",
      call = call
    )
  }
  invisible(x)
}

# Internal: resolve the saturation cut-off.
#
# When the caller gives nothing we fall back to the layout's declared upper
# pressure bound, which is only as trustworthy as the layout -- see the
# 'Trusting the ceiling' section of pr_sensor_quality(). A layout built by
# pr_layout_from_index_map() without an explicit `pressure_range` declares
# `NA` rather than guessing, and that has to be an error here: silently
# picking a number would invent the very quantity the flag is testing.
.sq_saturation <- function(saturation_kpa, layout,
                           call = rlang::caller_env()) {
  if (!is.null(saturation_kpa)) {
    .sm_check_scalar(saturation_kpa, "saturation_kpa", call = call)
    if (saturation_kpa <= 0) {
      cli::cli_abort(
        "{.arg saturation_kpa} must be positive, not {.val {saturation_kpa}}.",
        call = call
      )
    }
    return(as.numeric(saturation_kpa))
  }

  ceiling_kpa <- suppressWarnings(as.numeric(layout$pressure_range[2]))
  if (length(ceiling_kpa) != 1L || !is.finite(ceiling_kpa) ||
      ceiling_kpa <= 0) {
    declared <- layout$pressure_range[2]
    cli::cli_abort(c(
      "Layout {.val {layout$name}} declares no usable upper pressure bound.",
      "x" = "{.code layout$pressure_range[2]} is {.val {declared}}.",
      "i" = "Pass {.arg saturation_kpa} explicitly, e.g. {.code 63.75} for
             the Novel/Pliance saddle mat."
    ), call = call)
  }
  ceiling_kpa
}

# Internal: the four per-sensor statistics one recording contributes, in a
# single masking pass over the pressure matrix.
#
# `pct_zero` is taken before masking, exactly as .sm_sensor_stat() does, so
# a negative `threshold` still counts the frames the caller asked about
# rather than the zeros masking just created.
.sq_file_stats <- function(P, threshold) {
  pct_zero <- colMeans(P <= threshold)
  if (.sm_needs_mask(P, threshold)) P[P <= threshold] <- 0
  list(
    mean = colMeans(P),
    sd = .sm_col_sd(P),
    max = if (ncol(P) == 0L) numeric(0) else apply(P, 2L, max),
    pct_zero = pct_zero
  )
}

# Internal: assign flags in reverse precedence order, so the earlier entries
# of .sq_flags overwrite the later ones. which() rather than a logical index
# because sd_across_files is NA for a cohort of single-frame recordings and
# NA subscripts are an error in `[<-`.
.sq_assign_flags <- function(pct_zero_mean, max_across_files, sd_across_files,
                             dead_pct_zero, saturation_kpa, low_var_sd) {
  flag <- rep(unname(.sq_flags["ok"]), length(pct_zero_mean))
  flag[which(sd_across_files < low_var_sd)] <- unname(.sq_flags["low_var"])
  flag[which(max_across_files >= saturation_kpa)] <-
    unname(.sq_flags["saturated"])
  flag[which(pct_zero_mean > dead_pct_zero)] <- unname(.sq_flags["dead"])
  flag
}

#' Per-Sensor Hardware Quality Across a Cohort
#'
#' Cohort-wide quality control for a sensor mat: one row per sensor,
#' summarising how that cell behaved across every recording in the dataset,
#' and a flag naming the failure mode if it has one.
#'
#' @details
#' Each recording contributes four per-sensor numbers — its mean, its
#' standard deviation over frames, its maximum, and the fraction of frames
#' in which it read at or below `threshold` — and the cohort columns are
#' built from those:
#'
#' * `mean_across_files` — mean over recordings of the per-recording mean.
#' * `sd_across_files` — mean over recordings of the *within-recording*
#'   standard deviation, i.e. how much this cell typically moves during a
#'   trial. Despite the name (which is the cohort's own, kept so the table
#'   can be compared column-for-column with the published one) this is
#'   **not** the standard deviation of the per-recording means. The two are
#'   different quantities and they disagree substantially: the
#'   between-recording spread mostly measures how differently the mat was
#'   loaded from horse to horse, whereas the within-recording spread
#'   measures whether the cell responds to load at all — which is what the
#'   `"Low variance"` flag is asking. Recordings of fewer than two frames
#'   contribute no standard deviation and are left out of this average.
#' * `max_across_files` — the largest reading this cell ever produced,
#'   anywhere in the cohort.
#' * `pct_zero_mean` — mean over recordings of the percentage of frames at
#'   or below `threshold`. This column is a **percentage** (0–100), matching
#'   `dead_pct_zero`, not the 0–1 fraction that
#'   `pr_sensor_map(trial, "pct_zero")` returns.
#' * `n_files` — recordings summarised, the same on every row.
#'
#' @section Flags:
#' `flag` takes one of four fixed strings, assigned in this precedence order
#' so a cell that qualifies for more than one gets the most serious:
#'
#' 1. `"Dead (>95% zero)"` — `pct_zero_mean > dead_pct_zero`. A cell that is
#'    unloaded in almost every frame of every recording is not measuring
#'    zero pressure, it is not measuring. Dead cells depress the whole-grid
#'    mean ([pr_calc_mean_pressure_grid()]) and are invisible to the
#'    loaded-cells-only [pr_calc_mean_pressure()].
#' 2. `"Saturated (>60 kPa)"` — `max_across_files >= saturation_kpa`. The
#'    cell reached the hardware ceiling, so its true peak is unknown and
#'    censored from above. Any peak-derived cohort number
#'    ([pr_calc_pci()], `peak_kPa_max`) is a lower bound wherever these
#'    cells carry the hotspot.
#' 3. `"Low variance"` — `sd_across_files < low_var_sd`. The cell responds,
#'    but barely: a plausible stuck or half-detached cell that is not zero
#'    often enough to read as dead.
#' 4. `"OK"` — none of the above.
#'
#' The label text is fixed cohort vocabulary and names the study's nominal
#' 60 kPa cut; the comparison actually performed uses `saturation_kpa`.
#'
#' @section Trusting the ceiling:
#' With `saturation_kpa = NULL` the cut-off is taken from
#' `layout$pressure_range[2]`. **Check that number before relying on it.**
#' Several built-in layouts carry a nominal range rather than a measured
#' one: [pr_layout_saddle()] declares `c(0, 120)` for `"horse"` and
#' [pr_layout()] defaults to `c(0, 600)`, while the Novel/Pliance saddle mat
#' this cohort was recorded on saturates at **63.75 kPa** (255 x 0.25 kPa).
#' [pr_layout_saddle_novel()] declares that correctly; the others do not,
#' and a ceiling that is too high flags nothing at all. Pass
#' `saturation_kpa` explicitly whenever the layout's own bound is not the
#' device's measured one. A layout that declares `NA` — which
#' [pr_layout_from_index_map()] does unless told otherwise — is an error
#' rather than a guess.
#'
#' @section Memory:
#' Recordings are summarised one at a time into fixed-size accumulators, so
#' peak memory is one recording's pressure matrix plus a handful of
#' `n_sensors`-length vectors, not the cohort's. The study cohort is 431
#' recordings and about 5.5 M frames; holding them all to produce nine
#' columns of 256 rows would cost several gigabytes.
#'
#' @param dataset A [pr_dataset] object, or a list of [pr_trial] objects.
#' @param dead_pct_zero Numeric. Percentage (0–100) of frames at or below
#'   `threshold`, above which a sensor is called dead. Default `95`.
#' @param saturation_kpa Numeric, or `NULL` (default) to take the layout's
#'   declared ceiling `layout$pressure_range[2]`. See *Trusting the
#'   ceiling*.
#' @param low_var_sd Numeric. Lower bound on `sd_across_files`; below it a
#'   sensor is called low-variance. Default `0.1`, in the trial's pressure
#'   unit.
#' @param threshold Numeric. Cells at or below this value count as unloaded.
#'   Default `0`.
#'
#' @return A [tibble::tibble] with one row per sensor, in the layout's
#'   column-major grid order, and columns `sensor` (integer), `row`, `col`
#'   (integer grid indices), `mean_across_files`, `sd_across_files`,
#'   `max_across_files`, `pct_zero_mean` (percent), `n_files` (integer) and
#'   `flag` (character).
#' @family sensor quality functions
#' @seealso [pr_sensor_map()] for the single-recording per-sensor statistics
#'   these are built from, [pr_batch_frame_summary()] for the per-recording
#'   side of the same cohort.
#' @export
#' @examples
#' ds <- pr_dataset(lapply(1:4, function(s) {
#'   pr_example_trial("saddle_horse", seed = s)
#' }))
#'
#' # The layout declares 0-120 kPa, which this simulated mat never reaches,
#' # so nothing is flagged as saturated:
#' q <- pr_sensor_quality(ds)
#' table(q$flag)
#'
#' # Lower the cut-off to the cohort's own 99th percentile and the busiest
#' # cells show up:
#' cut <- unname(stats::quantile(q$max_across_files, 0.99))
#' table(pr_sensor_quality(ds, saturation_kpa = cut)$flag)
#'
#' # The declared ceiling and the pressure this mat actually reached --
#' # the comparison the *Trusting the ceiling* section asks you to make:
#' c(declared = ds$trials[[1]]$layout$pressure_range[2],
#'   observed = max(q$max_across_files))
pr_sensor_quality <- function(dataset, dead_pct_zero = 95,
                              saturation_kpa = NULL, low_var_sd = 0.1,
                              threshold = 0) {
  trials <- .sm_trials(dataset)
  .sq_check_range(dead_pct_zero, "dead_pct_zero", 0, 100)
  .sm_check_scalar(low_var_sd, "low_var_sd")
  .sm_check_scalar(threshold, "threshold")
  if (low_var_sd < 0) {
    cli::cli_abort(
      "{.arg low_var_sd} must be non-negative, not {.val {low_var_sd}}."
    )
  }

  n <- length(trials)
  if (n == 0L) {
    cli::cli_abort(c(
      "{.arg dataset} contains no trials.",
      "i" = "A cohort quality verdict needs at least one recording."
    ))
  }

  layout <- trials[[1]]$layout
  saturation_kpa <- .sq_saturation(saturation_kpa, layout)

  coords <- layout$coords_mm
  k <- nrow(coords)

  # Shape is checked for the whole cohort before a single recording is
  # summarised: a mismatch found on trial 400 of 431 has already cost
  # twenty minutes of parsing.
  labels <- .sm_trial_labels(trials)
  n_frames <- vapply(trials, function(t) nrow(t$pressure), integer(1))
  if (any(n_frames == 0L)) {
    bad <- labels[n_frames == 0L]
    cli::cli_abort(c(
      "{length(bad)} trial{?s} ha{?s/ve} no frames: {.val {bad}}.",
      "i" = "A per-sensor summary over zero frames is undefined."
    ))
  }
  n_sensors <- vapply(trials, function(t) ncol(t$pressure), integer(1))
  if (any(n_sensors != k)) {
    bad <- labels[n_sensors != k]
    cli::cli_abort(c(
      "Every trial must have the {k} sensor{?s} the layout describes.",
      "x" = "{length(bad)} trial{?s} do{?es/} not: {.val {bad}}.",
      "i" = "Row {.val s} of the result must mean the same physical cell
             in every recording."
    ))
  }

  lay_names <- unique(vapply(trials, function(t) t$layout$name, character(1)))
  if (length(lay_names) > 1L) {
    cli::cli_warn(c(
      "Trials use {length(lay_names)} different layouts: {.val {lay_names}}.",
      "i" = "Sensor {.val k} is only one physical cell if those layouts
             share a grid."
    ))
  }

  sum_mean <- numeric(k)
  sum_sd <- numeric(k)
  sum_pct_zero <- numeric(k)
  max_across <- rep(-Inf, k)
  n_sd <- 0L

  for (i in seq_len(n)) {
    # One recording at a time: summarised into the accumulators, dropped.
    P <- trials[[i]]$pressure
    st <- .sq_file_stats(P, threshold)
    sum_mean <- sum_mean + st$mean
    sum_pct_zero <- sum_pct_zero + st$pct_zero
    max_across <- pmax(max_across, st$max)
    if (n_frames[i] >= 2L) {
      sum_sd <- sum_sd + st$sd
      n_sd <- n_sd + 1L
    }
    rm(st)
  }

  sd_across <- if (n_sd > 0L) sum_sd / n_sd else rep(NA_real_, k)
  pct_zero_mean <- 100 * sum_pct_zero / n

  tibble::tibble(
    sensor = as.integer(coords$sensor_id),
    row = as.integer(coords$row),
    col = as.integer(coords$col),
    mean_across_files = sum_mean / n,
    sd_across_files = sd_across,
    max_across_files = max_across,
    pct_zero_mean = pct_zero_mean,
    n_files = rep(as.integer(n), k),
    flag = .sq_assign_flags(pct_zero_mean, max_across, sd_across,
                            dead_pct_zero, saturation_kpa, low_var_sd)
  )
}

#' Spatial Pressure Gradient Magnitude
#'
#' How sharply pressure changes from one sensor to its neighbours. The
#' per-sensor map produced by [pr_sensor_map()] is arranged back onto the
#' device grid, differenced in both directions, and returned as one gradient
#' magnitude per sensor.
#'
#' @details
#' For a grid `M` of per-sensor values, `method = "central"` computes
#' \deqn{g_{r,c} = \sqrt{\left(\frac{M_{r+1,c}-M_{r-1,c}}{2}\right)^2 +
#'   \left(\frac{M_{r,c+1}-M_{r,c-1}}{2}\right)^2}}
#' and `method = "forward"` uses the one-sided differences
#' `M[r+1, c] - M[r, c]` and `M[r, c+1] - M[r, c]` instead. Central
#' differences are symmetric and less noisy; forward differences reach one
#' cell further into the edge, which matters on a small grid.
#'
#' The result is in the trial's pressure unit **per sensor spacing** — kPa
#' per cell step, not kPa/mm. Converting to kPa/mm needs a published cell
#' pitch, and the saddle mat has none (see the *Missing physical scale*
#' section of [pr_layout_from_index_map()]), so no distance scaling is done
#' anywhere in this function. Gradients are therefore comparable across
#' recordings on the same device and not across devices with different
#' pitches.
#'
#' @section The edge ring:
#' A central difference needs a neighbour on both sides, so it is undefined
#' on the outermost row and column. The two `edges` settings differ only
#' there, and the interior is bit-for-bit identical either way:
#'
#' * `edges = "na"` (default) leaves the ring `NA`. This is the honest
#'   answer: no gradient was computed for those cells.
#' * `edges = "zero"` fills the ring with `0`. This reproduces the cohort
#'   analysis, which wrote central differences for rows and columns
#'   `2:(n-1)` into a zero-initialised matrix and never revisited the
#'   border. On a 16x16 mat that makes 60 of 256 cells — nearly a quarter —
#'   a **structural zero** rather than a measurement. Use it to reproduce
#'   published numbers, but never average, rank or threshold over the whole
#'   grid with it: the mean gradient is biased down by a factor of roughly
#'   `196/256`, and "the lowest-gradient cells" will be the border, every
#'   time. `edges = "na"` with `na.rm = TRUE` gives the interior mean the
#'   zero-filled version was probably meant to be.
#'
#' Cells the layout marks inactive are `NA` in the grid, so a gradient that
#' would have had to read one comes back `NA` under either setting.
#'
#' @param trial A [pr_trial] object.
#' @param statistic Character. The per-sensor map to differentiate; any
#'   statistic accepted by [pr_sensor_map()]. Default `"mean"`, which is the
#'   cohort definition.
#' @param method Character. `"central"` (default) or `"forward"`; see
#'   *Details*.
#' @param edges Character. `"na"` (default) or `"zero"`; see *The edge
#'   ring*.
#' @param threshold Numeric. Cells at or below this value count as unloaded;
#'   passed to [pr_sensor_map()]. Default `0`.
#'
#' @return A [tibble::tibble] with one row per sensor, in the same
#'   column-major grid order as [pr_sensor_map()], and columns `sensor`
#'   (integer), `row`, `col` (integer grid indices) and `gradient`
#'   (numeric).
#' @family sensor quality functions
#' @seealso [pr_sensor_map()] for the map being differentiated.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' g <- pr_calc_gradient(trial)
#' g[which.max(g$gradient), ]
#'
#' # The default leaves the border -- and the layout's inactive gullet
#' # cells -- missing ...
#' sum(is.na(g$gradient))
#' # ... while the cohort's zero-filled convention hides the border:
#' gz <- pr_calc_gradient(trial, edges = "zero")
#' sum(gz$gradient == 0, na.rm = TRUE)
#'
#' # Same interior, different whole-grid mean:
#' c(interior = mean(g$gradient, na.rm = TRUE),
#'   filled = mean(gz$gradient, na.rm = TRUE))
pr_calc_gradient <- function(trial, statistic = "mean", method = "central",
                             edges = c("na", "zero"), threshold = 0) {
  .validate_trial(trial)
  statistic <- .sm_match_statistic(statistic)
  edges <- match.arg(edges)
  known <- .sq_gradient_methods
  if (!is.character(method) || length(method) != 1L || is.na(method)) {
    cli::cli_abort("{.arg method} must be one of {.val {known}}.")
  }
  if (!method %in% known) {
    cli::cli_abort(c(
      "{.arg method} must be one of {.val {known}}.",
      "x" = "Got {.val {method}}."
    ))
  }

  map <- pr_sensor_map(trial, statistic, threshold = threshold)
  layout <- trial$layout
  nr <- as.integer(layout$grid_rows)
  nc <- as.integer(layout$grid_cols)

  # Inactive cells stay NA: they are not measurements, and a difference
  # taken across one would be an interpolation nobody asked for.
  M <- matrix(NA_real_, nrow = nr, ncol = nc)
  M[cbind(map$row, map$col)] <- map$value

  G <- matrix(if (identical(edges, "zero")) 0 else NA_real_,
              nrow = nr, ncol = nc)

  span <- if (identical(method, "central")) 3L else 2L
  if (nr < span || nc < span) {
    fill <- if (identical(edges, "zero")) "0" else "NA"
    cli::cli_warn(c(
      "A {nr}x{nc} grid has no cell where a {.val {method}} difference is
       defined.",
      "i" = "Every gradient is {.code {fill}}."
    ))
  } else if (identical(method, "central")) {
    ri <- seq.int(2L, nr - 1L)
    ci <- seq.int(2L, nc - 1L)
    d_row <- (M[ri + 1L, ci, drop = FALSE] - M[ri - 1L, ci, drop = FALSE]) / 2
    d_col <- (M[ri, ci + 1L, drop = FALSE] - M[ri, ci - 1L, drop = FALSE]) / 2
    G[ri, ci] <- sqrt(d_row^2 + d_col^2)
  } else {
    ri <- seq_len(nr - 1L)
    ci <- seq_len(nc - 1L)
    d_row <- M[ri + 1L, ci, drop = FALSE] - M[ri, ci, drop = FALSE]
    d_col <- M[ri, ci + 1L, drop = FALSE] - M[ri, ci, drop = FALSE]
    G[ri, ci] <- sqrt(d_row^2 + d_col^2)
  }

  tibble::tibble(
    sensor = map$sensor,
    row = map$row,
    col = map$col,
    gradient = as.numeric(G[cbind(map$row, map$col)])
  )
}
