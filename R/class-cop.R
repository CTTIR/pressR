#' Center of Pressure Object
#'
#' Construct a `pr_cop` object from x/y coordinates and time. Normally
#' created by [pr_calc_cop()] rather than called directly.
#'
#' @param x Numeric vector of COP x-coordinates (mm).
#' @param y Numeric vector of COP y-coordinates (mm).
#' @param time Numeric vector of timestamps (s).
#'
#' @return A `pr_cop` S3 object with fields `x`, `y`, `time`,
#'   `path_length`, `velocity_mean`, `velocity_max`, `range_x`, `range_y`,
#'   `sway_area`. Trajectory segments require adjacent valid frames; the mean
#'   velocity is total distance divided by observed segment duration.
#' @export
#' @examples
#' t <- seq(0, 1, by = 0.1)
#' cop <- pr_cop(x = 10 * sin(2 * pi * t), y = 50 * t, time = t)
#' cop
#' cop$path_length
pr_cop <- function(x, y, time) {
  if (!is.numeric(x) || !is.numeric(y) || !is.numeric(time) ||
    length(x) != length(y) || length(x) != length(time)) {
    cli::cli_abort("COP coordinates and timestamps must be numeric vectors of equal length.")
  }

  if (any(!is.finite(time)) || any(diff(time) <= 0)) cli::cli_abort("COP timestamps must be finite and strictly increasing.")
  if (any(is.infinite(x)) || any(is.infinite(y))) cli::cli_abort("COP coordinates must be finite or missing.")
  valid <- is.finite(x) & is.finite(y)
  xv <- x[valid]
  yv <- y[valid]
  # Never join the trajectory across an unloaded or missing frame.
  adjacent <- if (length(x) > 1L) utils::head(valid, -1L) & utils::tail(valid, -1L) else logical()
  seg <- sqrt(diff(x)^2 + diff(y)^2)[adjacent]
  dt <- diff(time)[adjacent]
  path_length <- sum(seg)
  velocity_mean <- if (length(seg)) sum(seg) / sum(dt) else 0
  velocity_max <- if (length(seg)) max(seg / dt) else 0

  range_x <- if (length(xv) > 0L) diff(range(xv)) else 0
  range_y <- if (length(yv) > 0L) diff(range(yv)) else 0

  # Sway area: approximated as 95% confidence ellipse area
  sway_area <- 0
  if (length(xv) >= 3L) {
    cx <- mean(xv)
    cy <- mean(yv)
    vx <- stats::var(xv)
    vy <- stats::var(yv)
    cov_xy <- stats::cov(xv, yv)
    eig <- eigen(matrix(c(vx, cov_xy, cov_xy, vy), 2, 2), symmetric = TRUE)
    a <- sqrt(max(eig$values, 0)) * 2.4477
    b <- sqrt(max(eig$values[2], 0)) * 2.4477
    sway_area <- pi * a * b
  }

  structure(
    list(
      x = x, y = y, time = time, coordinate_unit = "mm",
      path_length = path_length,
      velocity_mean = velocity_mean,
      velocity_max = velocity_max,
      range_x = range_x,
      range_y = range_y,
      sway_area = sway_area
    ),
    class = "pr_cop"
  )
}

#' @export
print.pr_cop <- function(x, ...) {
  unit <- x$coordinate_unit %||% "mm"
  cli::cli_h2("pr_cop")
  cli::cli_ul(c(
    "Frames: {.val {length(x$x)}}",
    "Path length: {.val {round(x$path_length, 2)}} {unit}",
    "Mean velocity: {.val {round(x$velocity_mean, 2)}} {unit}/s",
    "Max velocity: {.val {round(x$velocity_max, 2)}} {unit}/s",
    "Range (x): {.val {round(x$range_x, 2)}} {unit}",
    "Range (y): {.val {round(x$range_y, 2)}} {unit}",
    "Sway area (95% ellipse): {.val {round(x$sway_area, 2)}} {unit}^2"
  ))
  invisible(x)
}
