#' Spatial Interpolation of Pressure Data (for Display)
#'
#' Performs bilinear interpolation on the maximum pressure picture
#' between active sensor positions to produce a smoother image. The
#' underlying trial data is not modified.
#'
#' @param trial A [pr_trial] object.
#' @param factor Integer. Interpolation factor in each dimension.
#'   Default `2`.
#'
#' @return A list with `pressure_interp` (interpolated matrix),
#'   `x_grid`, `y_grid` and `coordinate_unit = "grid_index"`. Interpolated
#'   positions are grid indices; no physical sensor pitch is inferred.
#' @export
#' @examples
#' out <- pr_interpolate(pr_example_trial("insole"), factor = 2)
#' dim(out$pressure_interp)
pr_interpolate <- function(trial, factor = 2L) {
  .validate_trial(trial)
  if (!is.numeric(factor) || length(factor)!=1L || !is.finite(factor) || factor!=round(factor)) cli::cli_abort("factor must be a positive integer.")
  factor <- as.integer(factor)
  if (factor < 1L) cli::cli_abort("{.arg factor} must be a positive integer.")

  layout <- trial$layout
  mpp <- apply(trial$pressure, 2, max)
  grid <- matrix(0, layout$grid_rows, layout$grid_cols)
  grid[cbind(layout$coords_mm$row,layout$coords_mm$col)] <- mpp

  # Bilinear interpolation using stats::approx on rows then cols
  if (factor == 1L) {
    return(list(
      pressure_interp = grid, coordinate_unit="grid_index",
      x_grid = seq_len(ncol(grid)),
      y_grid = seq_len(nrow(grid))
    ))
  }
  nr <- nrow(grid)
  nc <- ncol(grid)
  nr_new <- (nr - 1) * factor + 1
  nc_new <- (nc - 1) * factor + 1
  # Interpolate each row along columns
  mid <- matrix(NA_real_,nr,nc_new)
  for(i in seq_len(nr)) mid[i,] <- if(nc==1L) grid[i,] else stats::approx(seq_len(nc),grid[i,],n=nc_new)$y
  out <- matrix(NA_real_,nr_new,nc_new)
  for(j in seq_len(nc_new)) out[,j] <- if(nr==1L) mid[,j] else stats::approx(seq_len(nr),mid[,j],n=nr_new)$y

  list(
    pressure_interp = out, coordinate_unit="grid_index",
    x_grid = seq(1, nc, length.out = nc_new),
    y_grid = seq(1, nr, length.out = nr_new)
  )
}

#' Subset a Trial to a Time Window
#'
#' @param trial A [pr_trial] object.
#' @param from Numeric. Start time (s). Default `0`.
#' @param to Numeric. End time (s). Default `Inf`.
#'
#' @return A [pr_trial] containing only frames with `time` in `[from, to]`.
#' @export
#' @examples
#' tr <- pr_filter_time(pr_example_trial("insole"), from = 1, to = 3)
#' tr$duration
pr_filter_time <- function(trial, from = 0, to = Inf) {
  .validate_trial(trial)
  keep <- trial$time >= from & trial$time <= to
  if (!any(keep)) {
    cli::cli_abort("No frames in the requested time window.")
  }
  pr_trial(
    pressure = trial$pressure[keep, , drop = FALSE],
    time = trial$time[keep],
    layout = trial$layout,
    metadata = trial$metadata,
    sampling_hz = trial$sampling_hz
  )
}

#' Downsample a Trial
#'
#' Keeps every `factor`-th frame.
#'
#' @param trial A [pr_trial] object.
#' @param factor Integer. Downsample factor. Default `2`.
#'
#' @return A [pr_trial] object with reduced frame count.
#' @export
#' @examples
#' tr <- pr_downsample(pr_example_trial("insole"), factor = 2)
#' tr$n_frames
pr_downsample <- function(trial, factor = 2L) {
  .validate_trial(trial)
  if (!is.numeric(factor) || length(factor)!=1L || !is.finite(factor) || factor!=round(factor)) cli::cli_abort("factor must be a positive integer.")
  factor <- as.integer(factor)
  if (factor < 1L) cli::cli_abort("{.arg factor} must be a positive integer.")
  if (factor == 1L) return(trial)
  idx <- seq(1L, trial$n_frames, by = factor)
  pr_trial(
    pressure = trial$pressure[idx, , drop = FALSE],
    time = trial$time[idx],
    layout = trial$layout,
    metadata = trial$metadata,
    sampling_hz = trial$sampling_hz / factor
  )
}
