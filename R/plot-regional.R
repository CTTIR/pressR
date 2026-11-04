#' Regional Parameter Comparison Bar Chart
#'
#' @param regional_data Output of [pr_calc_regional()].
#' @param parameter Character. Parameter column to plot. Default `"mpp"`.
#' @param thresholds A [tibble::tibble] from `pr_ref_*()` functions.
#'   If non-`NULL`, draws horizontal threshold lines where `parameter`
#'   matches.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' trial <- pr_example_trial("saddle_horse")
#' reg <- pr_calc_regional(trial)
#' pr_plot_regional_bar(reg, "mpp")
pr_plot_regional_bar <- function(regional_data, parameter = "mpp",
                                 thresholds = NULL) {
  if (!is.data.frame(regional_data)) {
    cli::cli_abort("{.arg regional_data} must be a data frame.")
  }
  if (!parameter %in% names(regional_data)) {
    cli::cli_abort("Parameter {.val {parameter}} not found in {.arg regional_data}.")
  }

  df <- regional_data
  df$value <- df[[parameter]]

  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = stats::reorder(.data$region, -.data$value),
      y = .data$value
    )
  ) +
    ggplot2::geom_col(
      fill = "#00897B", colour = "#1A2332",
      linewidth = 0.3
    ) +
    ggplot2::labs(
      x = "Region", y = paste0(parameter, " (", attr(regional_data, "units")[[parameter]] %||% "unspecified unit", ")"),
      title = sprintf("Regional %s", parameter)
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))

  if (!is.null(thresholds)) {
    required <- c("region", "parameter", "threshold", "unit")
    if (!is.data.frame(thresholds) || !all(required %in% names(thresholds))) cli::cli_abort("Reference overlays require region, parameter, threshold and unit.")
    ts <- thresholds[thresholds$parameter == parameter & is.finite(thresholds$threshold), , drop = FALSE]
    if ("status" %in% names(ts)) ts <- ts[ts$status == "verified_source", , drop = FALSE]
    unit <- attr(regional_data, "units")[[parameter]]
    if (nrow(ts) && is.null(unit)) cli::cli_abort("Regional measurement units are required for reference overlays.")
    context <- attr(regional_data, "reference_context")
    for (field in intersect(c("species", "gait", "region_scheme"), names(ts))) {
      if (nrow(ts) && (is.null(context[[field]]) || any(is.na(ts[[field]]) | ts[[field]] != context[[field]]))) {
        cli::cli_abort("Reference {.val {field}} does not match the explicitly supplied measurement context.")
      }
    }
    rows <- lapply(seq_len(nrow(ts)), function(i) {
      row <- ts[i, , drop = FALSE]
      hit <- regional_data$region == row$region | sub("_(left|right)$", "", regional_data$region) == row$region
      if (!any(hit)) {
        return(NULL)
      }
      value <- row$threshold
      if (!identical(row$unit, unit)) {
        from <- .pressure_to_kpa(row$unit)
        to <- .pressure_to_kpa(unit)
        if (!is.finite(from) || !is.finite(to)) cli::cli_abort("Incompatible threshold units.")
        value <- value * from / to
      }
      tibble::tibble(region = regional_data$region[hit], reference_value = value)
    })
    overlay <- dplyr::bind_rows(rows)
    if (nrow(overlay)) {
      p <- p + ggplot2::geom_point(
        data = overlay,
        ggplot2::aes(x = .data$region, y = .data$reference_value), shape = 95, size = 8,
        colour = "#C21D1D", inherit.aes = FALSE
      )
    }
  }
  p
}

#' Left/Right Symmetry Plot
#'
#' @param trial A [pr_trial] object.
#' @param parameter Character. One of `"peak_pressure"`, `"mean_pressure"`,
#'   `"force"`, `"contact_area"`.
#' @return A `ggplot2` object with a mirrored bar chart.
#' @export
#' @examples
#' pr_plot_symmetry(pr_example_trial("saddle_horse"))
pr_plot_symmetry <- function(trial,
                             parameter = c(
                               "peak_pressure",
                               "mean_pressure",
                               "force",
                               "contact_area"
                             )) {
  .validate_trial(trial)
  parameter <- match.arg(parameter)
  masks <- pr_mask_symmetry(trial$layout, axis = "vertical")
  reg <- pr_mask_apply(trial, masks)

  compute <- function(M) {
    if (ncol(M) == 0L) {
      return(0)
    }
    switch(parameter,
      peak_pressure = max(M, na.rm = TRUE),
      mean_pressure = mean(M[M > 0], na.rm = TRUE),
      force         = mean(rowSums(M)) * .force_scale(trial),
      contact_area  = mean(rowSums(M > 0)) * trial$layout$sensor_area_cm2
    )
  }
  L <- compute(reg$left)
  R <- compute(reg$right)
  df <- tibble::tibble(
    side = c("Left", "Right"),
    value = c(L, R)
  )
  si <- if (is.na(L) || is.na(R)) NA_real_ else if ((L + R) > 0) (L - R) / (0.5 * (L + R)) * 100 else 0

  ggplot2::ggplot(df, ggplot2::aes(.data$side, .data$value, fill = .data$side)) +
    ggplot2::geom_col(width = 0.5, colour = "#1A2332", linewidth = 0.3) +
    ggplot2::scale_fill_manual(
      values = c(Left = "#00897B", Right = "#26A69A"),
      guide = "none"
    ) +
    ggplot2::labs(
      title = sprintf("Symmetry (%s)", parameter),
      subtitle = sprintf("SI = %.2f%%", si),
      x = NULL, y = paste0(parameter, " (", .metric_units(trial)[[parameter]] %||% "unspecified unit", ")")
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Compare Two Trials
#'
#' Produces a side-by-side heatmap comparison, a difference map, or a
#' parameter-table plot for two trials.
#'
#' @param trial_a A [pr_trial] object. Reference.
#' @param trial_b A [pr_trial] object. Comparison.
#' @param type Character. `"heatmap"` (default), `"difference"`, or
#'   `"parameters"`.
#' @param labels Character vector of length 2. Default `c("A", "B")`.
#'
#' @return A `ggplot2` (or patchwork) object.
#' @export
#' @examples
#' a <- pr_example_trial("insole", seed = 1)
#' b <- pr_example_trial("insole", seed = 2)
#' pr_plot_comparison(a, b, type = "difference")
pr_plot_comparison <- function(trial_a, trial_b,
                               type = c(
                                 "heatmap", "difference",
                                 "parameters"
                               ),
                               labels = c("A", "B")) {
  .validate_trial(trial_a)
  .validate_trial(trial_b)
  type <- match.arg(type)
  if (type == "heatmap") {
    pa <- pr_plot_heatmap(trial_a, title = labels[1])
    pb <- pr_plot_heatmap(trial_b, title = labels[2])
    return(patchwork::wrap_plots(pa, pb, ncol = 2))
  }
  if (!identical(.measurement_unit(trial_a), .measurement_unit(trial_b)) ||
    !identical(.coordinate_unit(trial_a$layout), .coordinate_unit(trial_b$layout))) {
    cli::cli_abort("Comparisons require matching measurement and coordinate units.")
  }
  if (type == "difference") {
    if (trial_a$layout$name != trial_b$layout$name ||
      trial_a$n_sensors != trial_b$n_sensors ||
      !identical(trial_a$layout$coords_mm, trial_b$layout$coords_mm)) {
      cli::cli_abort(
        "Difference maps require trials with matching layouts."
      )
    }
    a_mpp <- apply(trial_a$pressure, 2, max)
    b_mpp <- apply(trial_b$pressure, 2, max)
    df <- .heatmap_tibble(trial_a$layout, b_mpp - a_mpp)
    tile_w <- .tile_size(trial_a$layout)
    return(
      ggplot2::ggplot(
        df,
        ggplot2::aes(.data$x_mm, .data$y_mm, fill = .data$value)
      ) +
        ggplot2::geom_tile(width = tile_w, height = tile_w) +
        ggplot2::scale_fill_gradient2(
          low = "#1F78B4", mid = "white", high = "#C21D1D", midpoint = 0,
          name = sprintf(
            "%s - %s (%s)", labels[2], labels[1],
            trial_a$layout$pressure_unit
          )
        ) +
        ggplot2::coord_fixed() +
        ggplot2::labs(
          title = "Difference map (MPP)",
          x = sprintf("x (%s)", .coordinate_label(trial_a$layout)), y = sprintf("y (%s)", .coordinate_label(trial_a$layout))
        ) +
        ggplot2::theme_minimal(base_size = 11)
    )
  }
  # parameters: side-by-side bar chart of trial summaries
  sa <- pr_summary_long(trial_a)
  sa$trial <- labels[1]
  sb <- pr_summary_long(trial_b)
  sb$trial <- labels[2]
  long <- rbind(sa, sb)
  long$parameter <- paste0(long$parameter, " (", long$unit, ")")
  ggplot2::ggplot(
    long,
    ggplot2::aes(.data$parameter, .data$value, fill = .data$trial)
  ) +
    ggplot2::geom_col(
      position = ggplot2::position_dodge(width = 0.8),
      width = 0.7, colour = "#1A2332", linewidth = 0.3
    ) +
    ggplot2::scale_fill_manual(
      values = stats::setNames(c("#00897B", "#26A69A"), labels)
    ) +
    ggplot2::labs(
      title = "Parameter comparison",
      x = NULL, y = "Value", fill = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
}
