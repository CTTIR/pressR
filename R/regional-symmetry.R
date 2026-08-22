# ---------------------------------------------------------------------------
# Zones, symmetry and masked centre of pressure.
#
# The frozen regional layer (R/calc-regional.R, R/masks.R) reduces a recording
# in one order: over the *sensors* of a region within each frame, then over
# frames. That is the right order for a peak-pressure or contact-area report,
# where the question is "what did the worst frame look like".
#
# A cohort map asks the opposite question -- "which cells carry load, on
# average, over the whole recording" -- and needs the other order: average a
# sensor over its own frames first, then reduce over the sensors of a zone.
# The two are not interchangeable. On a saddle recording the frame-first peak
# is the largest single reading anywhere; the sensor-first peak is the largest
# *time-averaged* cell, and it is several times smaller because no cell holds
# its maximum for the whole ride.
#
# Everything in this file is built on that sensor-first map, which is exactly
# pr_sensor_map():
#
#   pr_calc_regional_map()   zone statistics of the map
#   pr_calc_symmetry_map()   left/right asymmetry of the map
#   pr_symmetry_sensitivity()  the same index across a family of masks
#   pr_calc_cop_masked()     one COP series per region
#
# plus two mask constructors that make the zone boundaries explicit rather
# than derived from floor(nrow/3):
#
#   pr_mask_rowbands()       row bands at stated split points
#   pr_mask_mirror_balance() the largest mirror-symmetric subset of a mask
#
# Unit conventions follow R/frame-metrics.R: pressure in the device's own
# unit (kPa), COP in grid index units unless the layout carries a real sensor
# pitch. No area conversion happens anywhere in this file.
# ---------------------------------------------------------------------------

# The per-sensor reductions the zone and symmetry functions accept.
.rs_statistics <- c("mean", "max", "loaded")

# Internal: resolve the `statistic` argument, tolerating the full default
# vector that match.arg() would normally handle.
.rs_match_statistic <- function(statistic, call = rlang::caller_env()) {
  known <- .rs_statistics
  if (!is.character(statistic) || length(statistic) < 1L || anyNA(statistic)) {
    cli::cli_abort("{.arg statistic} must be one of {.val {known}}.",
                   call = call)
  }
  if (length(statistic) > 1L) {
    if (!identical(statistic, .rs_statistics)) {
      cli::cli_abort(
        "{.arg statistic} must be a single string, not {length(statistic)}.",
        call = call
      )
    }
    return(.rs_statistics[1])
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
.rs_check_scalar <- function(x, arg, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    cli::cli_abort("{.arg {arg}} must be a single finite number.", call = call)
  }
  invisible(x)
}

# Internal: a single TRUE/FALSE.
.rs_check_flag <- function(x, arg, call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
                   call = call)
  }
  invisible(x)
}

# Internal: the per-sensor map every function in this file reduces.
#
# Delegated to pr_sensor_map() rather than recomputed, so "the time-averaged
# map" means precisely one thing in the package. "loaded" is the per-sensor
# duty cycle, i.e. the fraction of frames strictly above `threshold`.
.rs_sensor_values <- function(trial, statistic, threshold) {
  if (identical(statistic, "loaded")) {
    return(1 - pr_sensor_map(trial, "pct_zero", threshold = threshold)$value)
  }
  pr_sensor_map(trial, statistic, threshold = threshold)$value
}

# Internal: coerce a pr_mask or logical matrix to a logical grid matrix,
# already intersected with the layout's active cells. NA counts as FALSE.
.rs_mask_matrix <- function(mask, layout, arg = "mask",
                            call = rlang::caller_env()) {
  m <- if (inherits(mask, "pr_mask")) mask$matrix else mask
  if (!is.logical(m) || !is.matrix(m)) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls pr_mask} object or a logical matrix, not
       {.obj_type_friendly {mask}}.",
      call = call
    )
  }
  if (nrow(m) != layout$grid_rows || ncol(m) != layout$grid_cols) {
    cli::cli_abort(
      "{.arg {arg}} is {nrow(m)} x {ncol(m)} but layout
       {.val {layout$name}} is {layout$grid_rows} x {layout$grid_cols}.",
      call = call
    )
  }
  m[is.na(m)] <- FALSE
  m & layout$active
}

# Internal: reflect a grid matrix across the mat's midline.
.rs_flip <- function(m, axis) {
  if (identical(axis, "vertical")) m[, rev(seq_len(ncol(m))), drop = FALSE]
  else m[rev(seq_len(nrow(m))), , drop = FALSE]
}

# Internal: the two half-plane matrices used by pr_mask_symmetry(), so that
# "left" here and "left" there are the same cells.
.rs_half_planes <- function(layout, axis) {
  nr <- layout$grid_rows
  nc <- layout$grid_cols
  a <- matrix(FALSE, nr, nc)
  b <- matrix(FALSE, nr, nc)
  if (identical(axis, "vertical")) {
    split <- floor(nc / 2)
    a[, seq_len(split)] <- TRUE
    b[, (split + 1):nc] <- TRUE
    stats::setNames(list(a, b), c("left", "right"))
  } else {
    split <- floor(nr / 2)
    a[seq_len(split), ] <- TRUE
    b[(split + 1):nr, ] <- TRUE
    stats::setNames(list(a, b), c("anterior", "posterior"))
  }
}

# Internal: the centre line of an odd-length axis, which reflects onto
# itself and therefore cannot be shared between the two halves.
.rs_drop_centre <- function(m, axis) {
  if (identical(axis, "vertical")) {
    nc <- ncol(m)
    if (nc %% 2L == 1L) m[, (nc + 1L) %/% 2L] <- FALSE
  } else {
    nr <- nrow(m)
    if (nr %% 2L == 1L) m[(nr + 1L) %/% 2L, ] <- FALSE
  }
  m
}

# Internal: balance a pair of half-masks against each other.
#
# Keeping only the cells whose reflection is also kept makes the two halves
# exact mirror images: flip(a_out) == b_out by construction, so their sensor
# counts are equal whatever the input looked like.
.rs_balance_pair <- function(a, b, axis) {
  a_out <- a & .rs_flip(b, axis)
  b_out <- b & .rs_flip(a, axis)
  list(.rs_drop_centre(a_out, axis), .rs_drop_centre(b_out, axis))
}

# Internal: resolve the `masks` argument of the symmetry functions to a pair
# of half-masks plus their labels.
#
# Accepted forms, in order:
#   NULL                  -- the whole active grid, split at the midline
#   pr_mask / matrix      -- that region of interest, split at the midline
#   list of two           -- the two sides given explicitly
.rs_side_masks <- function(masks, layout, axis = "vertical",
                           arg = "masks", call = rlang::caller_env()) {
  halves <- .rs_half_planes(layout, axis)
  if (is.null(masks)) {
    roi <- layout$active
  } else if (inherits(masks, "pr_mask") ||
             (is.logical(masks) && is.matrix(masks))) {
    roi <- .rs_mask_matrix(masks, layout, arg = arg, call = call)
  } else if (is.list(masks) && length(masks) == 2L) {
    nms <- names(masks)
    if (is.null(nms) || !all(nzchar(nms)) || anyDuplicated(nms) > 0L) {
      nms <- names(halves)
    }
    return(list(
      a = .rs_mask_matrix(masks[[1]], layout, arg = arg, call = call),
      b = .rs_mask_matrix(masks[[2]], layout, arg = arg, call = call),
      names = nms
    ))
  } else {
    cli::cli_abort(c(
      "{.arg {arg}} must be {.code NULL}, one {.cls pr_mask} or logical
       matrix, or a list of exactly two of them.",
      "x" = "Got {.obj_type_friendly {masks}} of length {length(masks)}."
    ), call = call)
  }
  list(a = roi & halves[[1]], b = roi & halves[[2]], names = names(halves))
}

# Internal: pressure-column indices of a logical grid matrix, in the
# column-major order every other pressR function uses.
.rs_cols <- function(m, layout) {
  match(which(m & layout$active), which(layout$active))
}

# Internal: the asymmetry index itself, on two already-resolved half-masks.
.rs_asymmetry <- function(v, layout, a, b, denominator) {
  ca <- .rs_cols(a, layout)
  cb <- .rs_cols(b, layout)
  reduce <- function(cols) {
    x <- v[cols]
    if (identical(denominator, "loaded")) x <- x[x > 0]
    if (length(x) == 0L) return(0)
    mean(x)
  }
  va <- reduce(ca)
  vb <- reduce(cb)
  idx <- if ((va + vb) == 0) 0 else (va - vb) / (0.5 * (va + vb)) * 100
  list(n_a = length(ca), n_b = length(cb), a = va, b = vb, index = idx)
}

#' Row-Band Region Masks With an Explicit Split
#'
#' Builds cranial / middle / caudal row bands (optionally crossed with the
#' left and right halves of the mat) from **stated** split rows rather than
#' from a derived `floor(grid_rows / 3)`. The split is the argument, so a
#' study's own band definition survives into the code instead of being
#' approximated by a division.
#'
#' @details
#' `breaks` gives the **last row of each band except the last**. With the
#' default `c(5, 11)` on a 16-row mat the bands are rows 1:5, 6:11 and 12:16
#' — the split used by [pr_layout_saddle()]'s `regions`, in which the middle
#' band is one row deeper than the outer two.
#'
#' [pr_mask_saddle_6()] uses `third <- floor(16 / 3)`, which gives 1:5, 6:10,
#' 11:16 instead: the *caudal* band is the deep one. Passing
#' `breaks = c(5, 10)` reproduces those cells exactly, with the same names in
#' the same order, so the two conventions can be compared rather than
#' confused. Because that one-row difference moves eight sensors between two
#' zones, it is worth stating which convention a number came from.
#'
#' Left and right are split at `floor(grid_cols / 2)`, matching
#' [pr_mask_symmetry()] and [pr_mask_saddle_6()]. With `sides = TRUE` the
#' masks come back in band-major order (`cranial_left`, `cranial_right`,
#' `middle_left`, ...); with `sides = FALSE` there is one full-width mask per
#' band. Every mask is intersected with `layout$active`, so inactive cells
#' (a withers cutout, say) never enter a band.
#'
#' @param layout A [pr_layout] object.
#' @param breaks Numeric vector of `length(band_names) - 1` strictly
#'   increasing whole numbers in `1:(grid_rows - 1)`. Each is the last row of
#'   its band. Default `c(5, 11)`.
#' @param sides Logical. Cross each band with the left and right halves of
#'   the mat. Default `TRUE`.
#' @param band_names Character vector of band names, cranial to caudal.
#'   Default `c("cranial", "middle", "caudal")`.
#'
#' @return A named list of [pr_mask] objects: `length(band_names)` of them
#'   when `sides = FALSE`, twice that when `sides = TRUE`.
#' @family regional symmetry functions
#' @seealso [pr_mask_saddle_6()] for the derived-thirds convention,
#'   [pr_calc_regional_map()] which consumes these masks.
#' @export
#' @examples
#' layout <- pr_layout_saddle("horse")
#' masks <- pr_mask_rowbands(layout)
#' names(masks)
#' vapply(masks, function(m) m$n_sensors, integer(1))
#'
#' # breaks = c(5, 10) is the pr_mask_saddle_6() convention:
#' same <- pr_mask_rowbands(layout, breaks = c(5, 10))
#' identical(same$middle_left$matrix, pr_mask_saddle_6(layout)$middle_left$matrix)
#'
#' # Full-width bands, no left/right split:
#' names(pr_mask_rowbands(layout, sides = FALSE))
pr_mask_rowbands <- function(layout, breaks = c(5, 11), sides = TRUE,
                             band_names = c("cranial", "middle", "caudal")) {
  .validate_layout(layout)
  .rs_check_flag(sides, "sides")

  if (!is.character(band_names) || length(band_names) == 0L ||
      anyNA(band_names) || !all(nzchar(band_names))) {
    cli::cli_abort("{.arg band_names} must be a character vector of names.")
  }
  if (anyDuplicated(band_names) > 0L) {
    dup <- unique(band_names[duplicated(band_names)])
    cli::cli_abort(
      "{.arg band_names} must be unique; duplicated: {.val {dup}}."
    )
  }

  n_breaks <- length(band_names) - 1L
  if (!is.numeric(breaks) || anyNA(breaks) || length(breaks) != n_breaks) {
    cli::cli_abort(c(
      "{.arg breaks} must be {n_breaks} whole number{?s} for
       {length(band_names)} band{?s}.",
      "x" = "Got {length(breaks)}.",
      "i" = "Each break is the last row of its band."
    ))
  }
  nr <- layout$grid_rows
  if (n_breaks > 0L) {
    if (any(breaks != round(breaks)) || any(breaks < 1) ||
        any(breaks > nr - 1L)) {
      cli::cli_abort(
        "{.arg breaks} must be whole numbers in {.code 1:{nr - 1L}}, not
         {.val {breaks}}."
      )
    }
    if (is.unsorted(breaks, strictly = TRUE)) {
      cli::cli_abort(
        "{.arg breaks} must be strictly increasing, not {.val {breaks}}."
      )
    }
  }
  breaks <- as.integer(breaks)

  starts <- c(1L, breaks + 1L)
  ends <- c(breaks, nr)
  half <- floor(layout$grid_cols / 2)

  out <- list()
  for (i in seq_along(band_names)) {
    band <- matrix(FALSE, nr, layout$grid_cols)
    band[starts[i]:ends[i], ] <- TRUE
    if (!sides) {
      nm <- band_names[i]
      out[[nm]] <- pr_mask(band & layout$active, nm, layout)
      next
    }
    for (side in c("left", "right")) {
      cols <- if (identical(side, "left")) {
        seq_len(half)
      } else {
        (half + 1L):layout$grid_cols
      }
      half_plane <- matrix(FALSE, nr, layout$grid_cols)
      half_plane[, cols] <- TRUE
      nm <- paste0(band_names[i], "_", side)
      out[[nm]] <- pr_mask(band & half_plane & layout$active, nm, layout)
    }
  }
  out
}

#' Largest Mirror-Symmetric Subset of a Mask
#'
#' Trims a region mask down to the cells whose mirror image across the mat's
#' midline is also in the mask. The result is symmetric by construction, so a
#' left/right comparison made on it cannot be an artefact of one side simply
#' owning more sensors than the other.
#'
#' @details
#' This is the largest mirror-symmetric subset of the input: a cell survives
#' if and only if both it and its reflection were present, and no
#' mirror-symmetric superset of that set exists inside the mask. The two
#' halves of the result are exact reflections of each other, which is a
#' stronger guarantee than equal counts.
#'
#' The reason to want it is that an asymmetry index divides by the mean of
#' the two sides. If the region of interest happens to contain more cells on
#' one side — because a sensor died, or because a data-driven mask was built
#' from a load pattern that is itself lopsided — then part of the resulting
#' index measures the mask, not the horse. In the study cohort, dropping
#' sensors that were flat for more than 95% of every recording left 106 live
#' cells on the left and 117 on the right; balancing to 106/106 moved the
#' cohort median asymmetry from -30.5% to -39.0%, the second of which agrees
#' with the whole-grid figure and the first of which does not.
#'
#' Cells outside `layout$active` are never kept. When the axis has an odd
#' number of lines the centre line reflects onto itself and belongs to
#' neither half, so it is dropped; on an even grid (such as the 16 x 16
#' saddle mat) nothing is lost to this.
#'
#' @param mask A [pr_mask] object or a logical matrix matching the layout
#'   grid.
#' @param layout A [pr_layout] object.
#' @param axis Character. `"vertical"` (default) mirrors columns, i.e.
#'   left against right; `"horizontal"` mirrors rows, i.e. anterior against
#'   posterior.
#'
#' @return A [pr_mask] object carrying two extra fields: `axis`, and
#'   `halves`, a named integer vector of the two sides' sensor counts, which
#'   are equal by construction.
#' @family regional symmetry functions
#' @seealso [pr_symmetry_sensitivity()], which applies this across a family
#'   of masks.
#' @export
#' @examples
#' layout <- pr_layout_saddle("horse")
#'
#' # A deliberately lopsided region: all of the left half, but only three
#' # columns of the right.
#' m <- matrix(FALSE, 16, 16)
#' m[, 1:8] <- TRUE
#' m[, 9:11] <- TRUE
#' bal <- pr_mask_mirror_balance(m, layout)
#' bal$halves
#'
#' # The surviving columns are 6:11 -- the ones with a partner on both sides.
#' which(apply(bal$matrix, 2, any))
pr_mask_mirror_balance <- function(mask, layout,
                                   axis = c("vertical", "horizontal")) {
  .validate_layout(layout)
  axis <- match.arg(axis)

  nm <- if (inherits(mask, "pr_mask")) paste0(mask$name, "_balanced") else
    "mirror_balanced"
  m <- .rs_mask_matrix(mask, layout, arg = "mask")

  bal <- .rs_drop_centre(m & .rs_flip(m, axis), axis)
  halves <- .rs_half_planes(layout, axis)

  out <- pr_mask(bal, nm, layout)
  out$axis <- axis
  out$halves <- stats::setNames(
    c(sum(bal & halves[[1]]), sum(bal & halves[[2]])),
    names(halves)
  )
  out
}

#' Zone Statistics of the Time-Averaged Sensor Map
#'
#' Summarises each region mask on the **per-sensor map**: every sensor is
#' first reduced over its own frames, and the zone statistics are then taken
#' across the sensors of the zone.
#'
#' @section Operator order:
#' This is the opposite order to [pr_calc_regional()], and the two give
#' different numbers on purpose.
#'
#' * [pr_calc_regional()] reduces **over sensors within a frame**, then over
#'   frames. Its `mpp` is the largest single reading the zone ever produced,
#'   in any frame.
#' * `pr_calc_regional_map()` reduces **over frames within a sensor**, then
#'   over sensors. Its `zone_peak_kPa` is the largest *time-averaged* cell,
#'   which is smaller — often several-fold — because no cell holds its
#'   maximum for a whole recording.
#'
#' Neither is more correct; they answer different questions. Use
#' [pr_calc_regional()] to report what the worst moment looked like, and this
#' function to report which cells carry load over the ride, which is the
#' quantity a cohort-level zone table compares between horses.
#'
#' @section Columns:
#' Writing `v` for the per-sensor map and `Z` for a zone's sensors:
#' * `zone_mean_kPa` — `mean(v[Z])`, over **all** the zone's sensors, with
#'   never-loaded ones contributing zeros. The mat is the region of interest,
#'   so an unloaded cell is a real measurement (compare
#'   [pr_calc_mean_pressure_grid()]).
#' * `zone_peak_kPa` — `max(v[Z])`.
#' * `zone_loaded` — `sum(v[Z] > 0)`, the number of the zone's sensors that
#'   ever carried load above `threshold`.
#'
#' A zone with no sensors at all returns three zeros rather than `NaN`.
#'
#' With `statistic = "loaded"` the map is a duty cycle in `[0, 1]`, not a
#' pressure, and the first two columns carry fractions; the column names are
#' kept fixed so a cohort table has one schema.
#'
#' @param trial A [pr_trial] object.
#' @param masks Named list of [pr_mask] objects or logical matrices. `NULL`
#'   (default) uses the layout's own regions; a layout without regions is an
#'   error, since a zone table has to say which zones.
#' @param statistic Character. The per-sensor reduction over time:
#'   `"mean"` (default) the time-average, `"max"` the maximum pressure
#'   picture, or `"loaded"` the fraction of frames above `threshold`.
#' @param threshold Numeric. Cells at or below this value count as unloaded.
#'   Default `0`.
#'
#' @return A [tibble::tibble] with one row per mask and columns `zone`,
#'   `zone_mean_kPa`, `zone_peak_kPa`, `zone_loaded`.
#' @family regional symmetry functions
#' @seealso [pr_sensor_map()] for the map being reduced,
#'   [pr_calc_regional()] for the frame-first counterpart.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' pr_calc_regional_map(trial)
#'
#' # The sensor-first peak is never above the frame-first peak:
#' zm <- pr_calc_regional_map(trial)
#' zf <- pr_calc_regional(trial, parameters = "mpp")
#' all(zm$zone_peak_kPa <= zf$mpp + 1e-9)
#'
#' # An explicit band split, rather than the layout's own regions:
#' pr_calc_regional_map(trial, pr_mask_rowbands(trial$layout, sides = FALSE))
pr_calc_regional_map <- function(trial, masks = NULL,
                                 statistic = c("mean", "max", "loaded"),
                                 threshold = 0) {
  .validate_trial(trial)
  statistic <- .rs_match_statistic(statistic)
  .rs_check_scalar(threshold, "threshold")

  layout <- trial$layout
  if (is.null(masks)) {
    masks <- pr_mask_default(layout)
    if (length(masks) == 0L) {
      cli::cli_abort(c(
        "Layout {.val {layout$name}} carries no regions.",
        "i" = "Pass {.arg masks}, e.g. {.code pr_mask_rowbands(trial$layout)}."
      ))
    }
  }
  if (!is.list(masks) || length(masks) == 0L) {
    cli::cli_abort("{.arg masks} must be a non-empty named list of masks.")
  }
  nms <- names(masks)
  if (is.null(nms) || !all(nzchar(nms))) {
    cli::cli_abort("{.arg masks} must be a named list.")
  }

  v <- .rs_sensor_values(trial, statistic, threshold)

  stat <- vapply(seq_along(masks), function(i) {
    m <- .rs_mask_matrix(masks[[i]], layout, arg = "masks")
    x <- v[.rs_cols(m, layout)]
    if (length(x) == 0L) return(c(0, 0, 0))
    c(mean(x), max(x), sum(x > 0))
  }, numeric(3))

  tibble::tibble(
    zone = nms,
    zone_mean_kPa = stat[1L, ],
    zone_peak_kPa = stat[2L, ],
    zone_loaded = as.integer(stat[3L, ])
  )
}

#' Left/Right Asymmetry of the Time-Averaged Sensor Map
#'
#' The classic asymmetry index `(L - R) / (0.5 * (L + R)) * 100`, computed on
#' the per-sensor map rather than frame by frame. Negative values are
#' right-biased, positive values left-biased, and zero is symmetric.
#'
#' @details
#' `L` and `R` are the mean of the per-sensor map over the left and right
#' sensors of the region of interest. Because the map is taken first, the
#' index describes where load sat *over the whole recording*, not where the
#' loudest frame happened to be; it is the counterpart of the frozen
#' [pr_calc_symmetry_index()], which averages within frames.
#'
#' `denominator` chooses what goes into each side's mean:
#' * `"grid"` (default) averages over **every** sensor of the side, counting
#'   never-loaded ones as zeros. This is the cohort definition: on a mat that
#'   *is* the region of interest, an unloaded cell is a real measurement.
#' * `"loaded"` averages only the sensors whose map value is above zero. That
#'   answers a different question — how hard the loaded cells were pressed,
#'   ignoring how many there were — and is usually much closer to zero,
#'   because a side that loses contact area keeps its intensity.
#'
#' The index is undefined when both sides are zero; that case returns `0`,
#' as [pr_calc_symmetry_index()] does.
#'
#' Nothing here forces the two sides to hold the same number of sensors. When
#' they do not, part of the index is a property of the mask — see
#' [pr_mask_mirror_balance()] and [pr_symmetry_sensitivity()].
#'
#' @inheritParams pr_calc_regional_map
#' @param masks What to compare. `NULL` (default) uses the whole active grid,
#'   split at `floor(grid_cols / 2)` exactly as [pr_mask_symmetry()] does. A
#'   single [pr_mask] or logical matrix restricts that comparison to a region
#'   of interest, split at the same midline. A list of exactly two masks
#'   gives the two sides explicitly, left first.
#' @param statistic Character. `"mean"` (default), `"max"` or `"loaded"`;
#'   see [pr_calc_regional_map()].
#' @param denominator Character. `"grid"` (default) or `"loaded"`; see
#'   *Details*.
#'
#' @return A one-row [tibble::tibble] with columns `statistic`,
#'   `denominator`, `n_left`, `n_right`, `left_value`, `right_value` and
#'   `asymmetry_pct`.
#' @family regional symmetry functions
#' @seealso [pr_calc_symmetry_index()] for the frame-first version,
#'   [pr_symmetry_sensitivity()] to vary the mask.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' pr_calc_symmetry_map(trial)
#'
#' # Restricted to the cranial band only:
#' bands <- pr_mask_rowbands(trial$layout, sides = FALSE)
#' pr_calc_symmetry_map(trial, bands$cranial)
#'
#' # Intensity-only comparison, ignoring how much area each side loaded:
#' pr_calc_symmetry_map(trial, denominator = "loaded")$asymmetry_pct
pr_calc_symmetry_map <- function(trial, masks = NULL, statistic = "mean",
                                 denominator = c("grid", "loaded")) {
  .validate_trial(trial)
  statistic <- .rs_match_statistic(statistic)
  denominator <- match.arg(denominator)

  layout <- trial$layout
  sides <- .rs_side_masks(masks, layout, axis = "vertical")
  v <- .rs_sensor_values(trial, statistic, threshold = 0)
  res <- .rs_asymmetry(v, layout, sides$a, sides$b, denominator)

  tibble::tibble(
    statistic = statistic,
    denominator = denominator,
    n_left = res$n_a,
    n_right = res$n_b,
    left_value = res$a,
    right_value = res$b,
    asymmetry_pct = res$index
  )
}

#' Asymmetry Index Across a Family of Masks
#'
#' Recomputes [pr_calc_symmetry_map()] for every mask scheme in a list and
#' returns one row per scheme, so that a symmetry claim can be reported
#' together with how much it depends on where the region of interest was
#' drawn.
#'
#' @details
#' A left/right index is only as stable as its mask. Excluding dead sensors,
#' restricting to a band, or thresholding on contact frequency all change
#' which cells are compared, and each of those choices can move the index by
#' more than the effect being reported. Running the family and printing the
#' spread is cheap — the per-sensor map is computed once and reused for every
#' scheme — and it turns an unstated choice into a reported one.
#'
#' With `balance = TRUE` (the default) each scheme is passed through the
#' mirror trim of [pr_mask_mirror_balance()] first, so every row compares
#' equal, mirror-image sets of sensors and `n_left == n_right` throughout.
#' Set it to `FALSE` to see what the raw masks give; the difference between
#' the two runs is the part of the index that came from the mask rather than
#' from the recording.
#'
#' @inheritParams pr_calc_symmetry_map
#' @param masks A **named** list of mask schemes. Each element is a
#'   [pr_mask], a logical matrix, or a list of exactly two of those giving
#'   the two sides explicitly — the same forms [pr_calc_symmetry_map()]
#'   accepts for its own `masks`.
#' @param balance Logical. Trim each scheme to its largest mirror-symmetric
#'   subset before computing the index. Default `TRUE`.
#'
#' @return A [tibble::tibble] with one row per scheme and columns `scheme`,
#'   `balanced`, `statistic`, `denominator`, `n_left`, `n_right`,
#'   `left_value`, `right_value`, `asymmetry_pct`.
#' @family regional symmetry functions
#' @seealso [pr_calc_symmetry_map()] for a single scheme.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' layout <- trial$layout
#' bands <- pr_mask_rowbands(layout, sides = FALSE)
#'
#' schemes <- list(
#'   whole_mat = layout$active,
#'   cranial = bands$cranial,
#'   middle = bands$middle,
#'   caudal = bands$caudal
#' )
#' pr_symmetry_sensitivity(trial, schemes)[, c("scheme", "asymmetry_pct")]
#'
#' # A data-driven mask need not be even-handed. Here the hotspot cells are
#' # 18 left against 12 right, and the raw index is a quarter of what the
#' # balanced 12/12 comparison reports.
#' hot <- matrix(FALSE, layout$grid_rows, layout$grid_cols)
#' co <- layout$coords_mm
#' hot[cbind(co$row, co$col)] <- pr_sensor_map(trial, "max")$value > 8
#' rbind(
#'   pr_symmetry_sensitivity(trial, list(hotspots = hot), balance = FALSE),
#'   pr_symmetry_sensitivity(trial, list(hotspots = hot))
#' )[, c("balanced", "n_left", "n_right", "asymmetry_pct")]
pr_symmetry_sensitivity <- function(trial, masks, statistic = "mean",
                                    denominator = "grid", balance = TRUE) {
  .validate_trial(trial)
  statistic <- .rs_match_statistic(statistic)
  denominator <- match.arg(denominator, c("grid", "loaded"))
  .rs_check_flag(balance, "balance")

  if (!is.list(masks) || inherits(masks, "pr_mask") || length(masks) == 0L) {
    cli::cli_abort(c(
      "{.arg masks} must be a non-empty named list of mask schemes.",
      "i" = "One scheme per row of the result; use
             {.fn pr_calc_symmetry_map} for a single one."
    ))
  }
  nms <- names(masks)
  if (is.null(nms) || !all(nzchar(nms)) || anyNA(nms)) {
    cli::cli_abort(c(
      "{.arg masks} must be a named list.",
      "i" = "The names become the {.field scheme} column."
    ))
  }

  layout <- trial$layout
  # One map for the whole family; only the masks differ between rows.
  v <- .rs_sensor_values(trial, statistic, threshold = 0)

  rows <- lapply(seq_along(masks), function(i) {
    sides <- .rs_side_masks(masks[[i]], layout, axis = "vertical",
                            arg = "masks")
    a <- sides$a
    b <- sides$b
    if (balance) {
      pair <- .rs_balance_pair(a, b, "vertical")
      a <- pair[[1]]
      b <- pair[[2]]
    }
    res <- .rs_asymmetry(v, layout, a, b, denominator)
    tibble::tibble(
      scheme = nms[i],
      balanced = balance,
      statistic = statistic,
      denominator = denominator,
      n_left = res$n_a,
      n_right = res$n_b,
      left_value = res$a,
      right_value = res$b,
      asymmetry_pct = res$index
    )
  })
  do.call(rbind, rows)
}

#' Centre of Pressure Per Region
#'
#' Computes one centre-of-pressure trajectory for each region mask, weighted
#' only by that region's sensors. Returns a list of [pr_cop] objects, so the
#' existing trajectory vocabulary — path length, mean and maximum velocity,
#' the x/y ranges [pr_calc_cop_excursion()] reports, and the 95% ellipse sway
#' area — is available per region with no further work.
#'
#' @details
#' A whole-mat COP is a single point that can sit in an unloaded gap between
#' two loaded zones, and it moves whenever load shifts *between* zones. A
#' per-region COP cannot: it stays inside its own region and reports how load
#' migrated within it, which is what separates a saddle that rocks
#' fore-and-aft from one that slides sideways.
#'
#' Frames in which a region carries no load at all get `NA` for both axes,
#' exactly as [pr_calc_cop()] does for the whole mat. [pr_cop()] excludes
#' those frames from the trajectory metrics, so a region that is loaded only
#' intermittently still reports a meaningful path length — though one
#' measured across the gaps, not through them.
#'
#' @section Units:
#' `units = "grid"` (the default) returns grid index units: `x` is the
#' fractional sensor column, `y` the fractional sensor row, both 1-based, in
#' the convention of [pr_calc_cop_grid()]. This is always available.
#'
#' `units = "mm"` returns the layout's physical `x_mm` / `y_mm` coordinates,
#' as [pr_calc_cop()] does. It is refused for a layout whose coordinates are
#' grid indices because no sensor pitch was ever published (see the *Missing
#' physical scale* section of [pr_layout_from_index_map()]) — millimetres
#' would be fabricated, and a path length in fabricated millimetres is worse
#' than none.
#'
#' Note that a `pr_cop` object labels its fields `mm` regardless; under
#' `units = "grid"` they are grid indices, and the derived path length and
#' velocity are in index units and index units per second.
#'
#' @inheritParams pr_calc_regional_map
#' @param masks Named list of [pr_mask] objects or logical matrices. `NULL`
#'   (default) uses the layout's own regions.
#' @param threshold Numeric. Cells at or below this value are given zero
#'   weight. Default `0`.
#' @param units Character. `"grid"` (default) or `"mm"`; see *Units*.
#'
#' @return A named list of [pr_cop] objects, one per mask, in the order the
#'   masks were given.
#' @family regional symmetry functions
#' @seealso [pr_calc_cop()] and [pr_calc_cop_grid()] for the whole mat,
#'   [pr_calc_cop_excursion()] for the range summary.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' cops <- pr_calc_cop_masked(trial)
#' names(cops)
#'
#' # Each region's COP stays inside its own rows:
#' round(vapply(cops, function(c) mean(c$y, na.rm = TRUE), numeric(1)), 2)
#'
#' # The full pr_cop vocabulary works unchanged:
#' round(vapply(cops, function(c) c$path_length, numeric(1)), 3)
#'
#' # This layout has a real sensor pitch, so millimetres are honest:
#' round(pr_calc_cop_masked(trial, units = "mm")$cranial_left$range_x, 1)
pr_calc_cop_masked <- function(trial, masks = NULL, threshold = 0,
                               units = c("grid", "mm")) {
  .validate_trial(trial)
  .rs_check_scalar(threshold, "threshold")
  units <- match.arg(units)

  layout <- trial$layout
  if (is.null(masks)) {
    masks <- pr_mask_default(layout)
    if (length(masks) == 0L) {
      cli::cli_abort(c(
        "Layout {.val {layout$name}} carries no regions.",
        "i" = "Pass {.arg masks}, e.g. {.code pr_mask_rowbands(trial$layout)}."
      ))
    }
  }
  if (!is.list(masks) || length(masks) == 0L) {
    cli::cli_abort("{.arg masks} must be a non-empty named list of masks.")
  }
  nms <- names(masks)
  if (is.null(nms) || !all(nzchar(nms))) {
    cli::cli_abort("{.arg masks} must be a named list.")
  }

  coords <- layout$coords_mm
  P <- trial$pressure
  if (nrow(coords) != ncol(P)) {
    cli::cli_abort(
      "Layout has {nrow(coords)} coordinate row{?s} but {.arg trial} has
       {ncol(P)} pressure column{?s}."
    )
  }
  if (identical(units, "mm") && identical(layout$coords_units, "grid_index")) {
    cli::cli_abort(c(
      "Layout {.val {layout$name}} has no physical sensor pitch, so its
       coordinates are grid indices.",
      "x" = "{.code units = \"mm\"} would report fabricated millimetres.",
      "i" = "Use {.code units = \"grid\"}, or rebuild the layout with
             {.arg spacing_mm}."
    ))
  }

  xs <- if (identical(units, "mm")) {
    as.numeric(coords$x_mm)
  } else {
    as.numeric(coords$col)
  }
  ys <- if (identical(units, "mm")) {
    as.numeric(coords$y_mm)
  } else {
    as.numeric(coords$row)
  }
  time <- as.numeric(trial$time)

  out <- lapply(seq_along(masks), function(i) {
    m <- .rs_mask_matrix(masks[[i]], layout, arg = "masks")
    cols <- .rs_cols(m, layout)
    W <- P[, cols, drop = FALSE]
    if (length(W) > 0L && (threshold > 0 || any(W < 0, na.rm = TRUE))) {
      W[W <= threshold] <- 0
    }
    s <- rowSums(W)
    # NA rather than 0/0: an unloaded region has no centroid, and pr_cop()
    # drops those frames from the trajectory metrics.
    den <- ifelse(s > 0, s, NA_real_)
    pr_cop(
      x = as.vector(W %*% xs[cols]) / den,
      y = as.vector(W %*% ys[cols]) / den,
      time = time
    )
  })
  stats::setNames(out, nms)
}
