# ---------------------------------------------------------------------------
# Mask / region system.
#
# Masks are pr_mask S3 objects (see R/class-mask.R) or plain logical matrices
# of the same dimensions as layout$active. Internal helper .mask_to_cols()
# converts either form to pressure-matrix column indices.
# ---------------------------------------------------------------------------

#' Get Default Region Masks for a Layout
#'
#' Returns a named list of [pr_mask] objects built from the `regions`
#' field of a [pr_layout].
#'
#' @param layout A [pr_layout] object.
#'
#' @return Named list of [pr_mask] objects (possibly empty).
#' @export
#' @examples
#' masks <- pr_mask_default(pr_layout_saddle("horse"))
#' names(masks)
pr_mask_default <- function(layout) {
  .validate_layout(layout)
  if (length(layout$regions) == 0L) return(list())
  out <- lapply(names(layout$regions), function(nm) {
    pr_mask(layout$regions[[nm]], nm, layout)
  })
  stats::setNames(out, names(layout$regions))
}

#' Apply Masks to Extract Regional Pressure Data
#'
#' Returns a named list of numeric matrices. Each entry has dimensions
#' `n_frames x n_sensors_in_region` and contains the pressure values of
#' that region's sensors for each frame.
#'
#' @param trial A [pr_trial] object.
#' @param masks Named list of [pr_mask] objects or logical matrices. If
#'   `NULL` (default), the trial's layout regions are used.
#'
#' @return Named list of numeric matrices.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' reg <- pr_mask_apply(trial)
#' vapply(reg, ncol, integer(1))
pr_mask_apply <- function(trial, masks = NULL) {
  .validate_trial(trial)
  layout <- trial$layout
  if (is.null(masks)) {
    masks <- pr_mask_default(layout)
  }
  if (length(masks) == 0L) return(list())
  if (is.null(names(masks))) {
    cli::cli_abort("{.arg masks} must be a named list.")
  }
  out <- lapply(masks, function(m) {
    cols <- .mask_to_cols(m, layout)
    if (length(cols) == 0L) {
      return(matrix(numeric(0), nrow = trial$n_frames, ncol = 0))
    }
    trial$pressure[, cols, drop = FALSE]
  })
  out
}

#' Split Layout into Left/Right Halves
#'
#' Produces a two-element named list of [pr_mask] objects dividing the
#' layout along the specified axis.
#'
#' @param layout A [pr_layout] object.
#' @param axis Character. `"vertical"` (default, split columns into
#'   left/right) or `"horizontal"` (split rows into anterior/posterior).
#'
#' @return A named list of two [pr_mask] objects.
#' @export
#' @examples
#' pr_mask_symmetry(pr_layout_saddle("horse"))
pr_mask_symmetry <- function(layout, axis = c("vertical", "horizontal")) {
  .validate_layout(layout)
  axis <- match.arg(axis)
  m1 <- matrix(FALSE, layout$grid_rows, layout$grid_cols)
  m2 <- matrix(FALSE, layout$grid_rows, layout$grid_cols)

  if (axis == "vertical") {
    split <- floor(layout$grid_cols / 2)
    m1[, seq_len(split)] <- TRUE
    m2[, (split + 1):layout$grid_cols] <- TRUE
    names_ <- c("left", "right")
  } else {
    split <- floor(layout$grid_rows / 2)
    m1[seq_len(split), ] <- TRUE
    m2[(split + 1):layout$grid_rows, ] <- TRUE
    names_ <- c("anterior", "posterior")
  }
  m1 <- m1 & layout$active
  m2 <- m2 & layout$active

  out <- list(pr_mask(m1, names_[1], layout),
              pr_mask(m2, names_[2], layout))
  stats::setNames(out, names_)
}

#' Standard 6-Region Saddle Mask
#'
#' Creates the 6-region saddle pressure analysis mask dividing the sensor
#' mat into cranial / middle / caudal thirds crossed with left / right
#' halves, as established by Werner et al. (2002) and used in subsequent
#' equine back-pressure studies.
#'
#' @param layout A [pr_layout] object (typically one returned by
#'   [pr_layout_saddle()] with `type = "horse"`).
#'
#' @return Named list of 6 [pr_mask] objects.
#' @export
#' @examples
#' pr_mask_saddle_6(pr_layout_saddle("horse"))
pr_mask_saddle_6 <- function(layout) {
  .validate_layout(layout)
  nr <- layout$grid_rows
  nc <- layout$grid_cols

  third <- floor(nr / 3)
  half  <- floor(nc / 2)

  cranial <- matrix(FALSE, nr, nc); cranial[seq_len(third), ] <- TRUE
  middle  <- matrix(FALSE, nr, nc); middle[(third + 1):(2 * third), ] <- TRUE
  caudal  <- matrix(FALSE, nr, nc); caudal[(2 * third + 1):nr, ] <- TRUE

  left  <- matrix(FALSE, nr, nc); left[, seq_len(half)] <- TRUE
  right <- matrix(FALSE, nr, nc); right[, (half + 1):nc] <- TRUE

  build <- function(m, nm) pr_mask(m & layout$active, nm, layout)

  list(
    cranial_left  = build(cranial & left,  "cranial_left"),
    cranial_right = build(cranial & right, "cranial_right"),
    middle_left   = build(middle  & left,  "middle_left"),
    middle_right  = build(middle  & right, "middle_right"),
    caudal_left   = build(caudal  & left,  "caudal_left"),
    caudal_right  = build(caudal  & right, "caudal_right")
  )
}

#' Auto-Segment Foot Regions from Pressure Data
#'
#' For platform recordings where foot regions must be detected from the
#' raw pressure matrix. Uses the maximum pressure picture (MPP) to
#' identify the foot outline, then segments into anatomical regions based
#' on proportional geometry.
#'
#' @param trial A [pr_trial] object from a pressure platform recording.
#' @param n_regions Integer. `7` (default, full segmentation into heel,
#'   midfoot, met1, met2-3, met4-5, hallux, lesser toes) or `3`
#'   (heel/midfoot/forefoot).
#' @param threshold Numeric. Minimum pressure (kPa) to consider a sensor
#'   loaded. Default `1.0`.
#'
#' @return Named list of [pr_mask] objects.
#' @export
#' @examples
#' trial <- pr_example_trial("platform")
#' masks <- pr_mask_foot_auto(trial, n_regions = 3)
#' names(masks)
#' names(pr_mask_foot_auto(trial))
pr_mask_foot_auto <- function(trial, n_regions = 7L, threshold = 1.0) {
  .validate_trial(trial)
  layout <- trial$layout
  n_regions <- as.integer(n_regions)
  if (!n_regions %in% c(3L, 7L)) {
    cli::cli_abort("{.arg n_regions} must be 3 or 7.")
  }

  # Compute MPP and map back to a full grid
  mpp_vec <- apply(trial$pressure, 2, max)
  grid <- matrix(0, layout$grid_rows, layout$grid_cols)
  active_idx <- which(layout$active)
  grid[active_idx] <- mpp_vec

  loaded <- grid > threshold
  if (!any(loaded)) {
    cli::cli_warn("No sensors exceed {.arg threshold} = {threshold}. Returning empty mask list.")
    return(list())
  }

  rr <- which(loaded, arr.ind = TRUE)
  r_min <- min(rr[, 1]); r_max <- max(rr[, 1])
  c_min <- min(rr[, 2]); c_max <- max(rr[, 2])

  height <- r_max - r_min + 1
  width  <- c_max - c_min + 1

  # Partition rows into thirds (heel/mid/forefoot).
  r_heel_end    <- r_min + floor(height / 3) - 1
  r_mid_end     <- r_min + floor(2 * height / 3) - 1

  mk <- function() matrix(FALSE, layout$grid_rows, layout$grid_cols)

  heel <- mk(); heel[r_min:r_heel_end, c_min:c_max] <- TRUE; heel <- heel & loaded
  midfoot <- mk(); midfoot[(r_heel_end + 1):r_mid_end, c_min:c_max] <- TRUE; midfoot <- midfoot & loaded

  if (n_regions == 3L) {
    forefoot <- mk(); forefoot[(r_mid_end + 1):r_max, c_min:c_max] <- TRUE; forefoot <- forefoot & loaded
    out <- list(
      heel     = pr_mask(heel & layout$active,     "heel",     layout),
      midfoot  = pr_mask(midfoot & layout$active,  "midfoot",  layout),
      forefoot = pr_mask(forefoot & layout$active, "forefoot", layout)
    )
    return(out)
  }

  # 7 regions:
  # Forefoot split rows into metatarsal rows (lower half) and toes (upper half).
  r_fore_start <- r_mid_end + 1
  fore_h <- r_max - r_fore_start + 1
  r_met_end <- r_fore_start + floor(fore_h / 2) - 1

  c_thirds <- c_min + floor((width) * c(1, 2) / 3) - 1
  c_third_1 <- c_thirds[1]
  c_third_2 <- c_thirds[2]
  c_halfway <- c_min + floor(width / 2) - 1

  met1 <- mk(); met1[r_fore_start:r_met_end, c_min:c_third_1] <- TRUE
  met23 <- mk(); met23[r_fore_start:r_met_end, (c_third_1 + 1):c_third_2] <- TRUE
  met45 <- mk(); met45[r_fore_start:r_met_end, (c_third_2 + 1):c_max] <- TRUE

  hallux <- mk(); hallux[(r_met_end + 1):r_max, c_min:c_halfway] <- TRUE
  lesser <- mk(); lesser[(r_met_end + 1):r_max, (c_halfway + 1):c_max] <- TRUE

  met1   <- met1   & loaded
  met23  <- met23  & loaded
  met45  <- met45  & loaded
  hallux <- hallux & loaded
  lesser <- lesser & loaded

  list(
    heel            = pr_mask(heel & layout$active, "heel", layout),
    midfoot         = pr_mask(midfoot & layout$active, "midfoot", layout),
    metatarsal_1    = pr_mask(met1 & layout$active, "metatarsal_1", layout),
    metatarsal_2_3  = pr_mask(met23 & layout$active, "metatarsal_2_3", layout),
    metatarsal_4_5  = pr_mask(met45 & layout$active, "metatarsal_4_5", layout),
    hallux          = pr_mask(hallux & layout$active, "hallux", layout),
    lesser_toes     = pr_mask(lesser & layout$active, "lesser_toes", layout)
  )
}
