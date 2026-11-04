# ---------------------------------------------------------------------------
# Time-series / dynamics plots.
# ---------------------------------------------------------------------------

.add_cycle_bands <- function(p, trial) {
  cycles <- pr_calc_gait_cycles(trial)
  if (nrow(cycles) == 0L) {
    return(p)
  }
  p + ggplot2::geom_rect(
    data = cycles,
    ggplot2::aes(
      xmin = .data$heel_strike_time, xmax = .data$toe_off_time,
      ymin = -Inf, ymax = Inf
    ),
    fill = "#00897B", alpha = 0.08, inherit.aes = FALSE
  )
}

#' Plot Force vs Time
#'
#' @param trial A [pr_trial] object.
#' @param show_cycles Logical. If `TRUE`, shade detected stance phases.
#'   Default `FALSE`.
#' @return A `ggplot2` object.
#' @export
#' @examples
#' pr_plot_force_time(pr_example_trial("insole"))
pr_plot_force_time <- function(trial, show_cycles = FALSE) {
  .validate_trial(trial)
  df <- tibble::tibble(
    time = trial$time,
    force = pr_calc_force(trial)
  )
  if (!any(is.finite(df$force))) {
    return(ggplot2::ggplot() +
      ggplot2::theme_void() +
      ggplot2::annotate("text", x = 0, y = 0, label = "Force unavailable: sensor area or pressure calibration is unknown.", size = 3.5) +
      ggplot2::labs(title = "Total force"))
  }
  p <- ggplot2::ggplot(df, ggplot2::aes(.data$time, .data$force))
  if (show_cycles) p <- .add_cycle_bands(p, trial)
  p +
    ggplot2::geom_line(colour = "#00897B", linewidth = 0.6) +
    ggplot2::labs(
      x = "Time (s)", y = "Force (N)",
      title = "Total force vs time"
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Plot Peak and Mean Pressure vs Time
#'
#' @inheritParams pr_plot_force_time
#' @return A `ggplot2` object.
#' @export
#' @examples
#' pr_plot_pressure_time(pr_example_trial("insole"))
pr_plot_pressure_time <- function(trial, show_cycles = FALSE) {
  .validate_trial(trial)
  df <- tibble::tibble(
    time = trial$time,
    peak = pr_calc_peak_pressure(trial),
    mean = pr_calc_mean_pressure(trial)
  )
  long <- tidyr::pivot_longer(
    df,
    cols = c("peak", "mean"), names_to = "metric",
    values_to = "pressure"
  )
  p <- ggplot2::ggplot(
    long,
    ggplot2::aes(.data$time, .data$pressure, colour = .data$metric)
  )
  if (show_cycles) p <- .add_cycle_bands(p, trial)
  p +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::scale_colour_manual(
      values = c(peak = "#C21D1D", mean = "#00897B"),
      labels = c(mean = "Mean", peak = "Peak")
    ) +
    ggplot2::labs(
      x = "Time (s)",
      y = sprintf("Pressure (%s)", trial$layout$pressure_unit),
      colour = NULL,
      title = "Peak and mean pressure vs time"
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Plot Center of Pressure Trajectory
#'
#' @param trial A [pr_trial] object.
#' @param show_layout Logical. Draw sensor grid in background. Default `TRUE`.
#' @param color_by Character. `"time"` (default) or `"velocity"`.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' pr_plot_cop(pr_example_trial("saddle_horse"))
pr_plot_cop <- function(trial, show_layout = TRUE,
                        color_by = c("time", "velocity")) {
  .validate_trial(trial)
  color_by <- match.arg(color_by)
  cop <- pr_calc_cop(trial)
  df <- tibble::tibble(
    t = trial$time, x = cop$x, y = cop$y
  )
  df <- df[!is.na(df$x), , drop = FALSE]

  if (color_by == "velocity" && nrow(df) >= 2L) {
    dx <- c(0, diff(df$x))
    dy <- c(0, diff(df$y))
    dt <- c(1, diff(df$t))
    df$velocity <- sqrt(dx^2 + dy^2) / dt
  }

  p <- ggplot2::ggplot()
  if (show_layout) {
    p <- p + ggplot2::geom_point(
      data = trial$layout$coords_mm,
      ggplot2::aes(x = .data$x_mm, y = .data$y_mm),
      colour = "grey85", size = 0.7
    )
  }
  if (color_by == "time") {
    p <- p +
      ggplot2::geom_path(
        data = df,
        ggplot2::aes(.data$x, .data$y, colour = .data$t),
        linewidth = 0.7
      ) +
      ggplot2::scale_colour_viridis_c(option = "viridis", name = "Time (s)")
  } else {
    p <- p +
      ggplot2::geom_path(
        data = df,
        ggplot2::aes(.data$x, .data$y, colour = .data$velocity),
        linewidth = 0.7
      ) +
      ggplot2::scale_colour_viridis_c(option = "magma", name = sprintf("Velocity (%s/s)", .coordinate_label(trial$layout)))
  }
  p +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = "Center of pressure",
      x = sprintf("x (%s)", .coordinate_label(trial$layout)), y = sprintf("y (%s)", .coordinate_label(trial$layout))
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

#' COP Butterfly Plot Across Gait Cycles
#'
#' Overlays COP trajectories from each detected stance phase, centered on
#' heel strike.
#'
#' @param trial A [pr_trial] object.
#' @param cycles Output of [pr_calc_gait_cycles()]. If `NULL`, auto-detected.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' pr_plot_cop_butterfly(pr_example_trial("insole"))
pr_plot_cop_butterfly <- function(trial, cycles = NULL) {
  .validate_trial(trial)
  if (is.null(cycles)) cycles <- pr_calc_gait_cycles(trial)
  cop <- pr_calc_cop(trial)

  if (nrow(cycles) == 0L) {
    return(pr_plot_cop(trial) +
      ggplot2::labs(subtitle = "(no gait cycles detected)"))
  }

  rows <- lapply(seq_len(nrow(cycles)), function(i) {
    idx <- cycles$start_frame[i]:cycles$end_frame[i]
    x <- cop$x[idx]
    y <- cop$y[idx]
    if (all(is.na(x))) {
      return(NULL)
    }
    x0 <- x[1]
    y0 <- y[1]
    tibble::tibble(
      cycle = as.integer(i),
      x = x - x0,
      y = y - y0
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    return(pr_plot_cop(trial) +
      ggplot2::labs(subtitle = "(no valid cycles)"))
  }
  df <- do.call(rbind, rows)

  ggplot2::ggplot(
    df,
    ggplot2::aes(.data$x, .data$y,
      group = .data$cycle, colour = as.factor(.data$cycle)
    )
  ) +
    ggplot2::geom_path(alpha = 0.7, linewidth = 0.6) +
    ggplot2::coord_fixed() +
    ggplot2::scale_colour_viridis_d(name = "Cycle") +
    ggplot2::labs(
      title = "COP butterfly across stance phases",
      x = sprintf("x offset (%s)", .coordinate_label(trial$layout)), y = sprintf("y offset (%s)", .coordinate_label(trial$layout))
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Plot Contact Area vs Time
#'
#' @inheritParams pr_plot_force_time
#' @return A `ggplot2` object.
#' @export
pr_plot_contact_area <- function(trial, show_cycles = FALSE) {
  .validate_trial(trial)
  df <- tibble::tibble(
    time = trial$time,
    contact_area = pr_calc_contact_area(trial)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(.data$time, .data$contact_area))
  if (show_cycles) p <- .add_cycle_bands(p, trial)
  p +
    ggplot2::geom_line(colour = "#26A69A", linewidth = 0.6) +
    ggplot2::labs(
      x = "Time (s)", y = "Contact area (cm\u00b2)",
      title = "Contact area vs time"
    ) +
    ggplot2::theme_minimal(base_size = 11)
}
