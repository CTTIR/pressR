# ---------------------------------------------------------------------------
# Composite report-style plots.
# ---------------------------------------------------------------------------

# Internal: a map panel with its fill and region legends side by side, so the
# legend column stays within the panel height of a 2 x 2 composite.
.compact_map_legends <- function(p) {
  p + ggplot2::theme(
    legend.box = "horizontal",
    legend.key.size = ggplot2::unit(0.9, "lines"),
    legend.title = ggplot2::element_text(size = 9),
    legend.text = ggplot2::element_text(size = 8)
  )
}

#' Saddle Fit Report Panel
#'
#' Composite figure for equine saddle analysis: MPP heatmap, 6-region
#' bar chart, COP trajectory, and left/right symmetry summary.
#'
#' @param trial A [pr_trial] from a saddle recording.
#' @param thresholds A reference threshold tibble (typically from
#'   [pr_ref_saddle()]). If `NULL`, no reference overlay is drawn.
#' @param masks Explicit region masks. NULL uses the historical six-mask layout.
#'
#' @return A `patchwork` object (4-panel composite).
#' @export
#' @examples
#' pr_plot_saddle_report(pr_example_trial("saddle_horse"))
pr_plot_saddle_report <- function(trial, thresholds = NULL, masks = NULL) {
  .validate_trial(trial)
  if (is.null(masks)) masks <- pr_mask_saddle_6(trial$layout)
  reg <- pr_calc_regional(trial, masks)

  p_hm <- .compact_map_legends(pr_plot_heatmap_masked(trial,
    masks = masks,
    title = "MPP with selected regions"
  ))
  p_bar <- pr_plot_regional_bar(reg, "mpp", thresholds)
  p_cop <- pr_plot_cop(trial)
  p_sym <- pr_plot_symmetry(trial, "peak_pressure")

  patchwork::wrap_plots(p_hm, p_bar, p_cop, p_sym, ncol = 2) +
    patchwork::plot_annotation(
      title = "Saddle pressure report",
      subtitle = sprintf(
        "Subject: %s \u00b7 Condition: %s",
        trial$metadata$subject_id %||% "-",
        trial$metadata$condition %||% "-"
      )
    )
}

#' Foot Pressure Report Panel
#'
#' Composite figure for foot pressure analysis: MPP map, regional bar
#' chart, force-time curve, COP trajectory.
#'
#' @param trial A [pr_trial] object from an insole or platform recording.
#'
#' @param masks Optional explicit region masks.
#' @return A `patchwork` object.
#' @export
#' @examples
#' pr_plot_foot_report(pr_example_trial("insole"))
pr_plot_foot_report <- function(trial, masks = NULL) {
  .validate_trial(trial)
  # Pick default regions from the layout; if empty, auto-segment
  if (!is.null(masks)) {
    masks <- masks
  } else if (length(trial$layout$regions) == 0L) {
    masks <- tryCatch(pr_mask_foot_auto(trial), error = function(e) list())
  } else {
    masks <- pr_mask_default(trial$layout)
  }

  p_hm <- .compact_map_legends(if (length(masks) == 0L) {
    pr_plot_heatmap(trial)
  } else {
    pr_plot_heatmap_masked(trial, masks = masks)
  })
  p_bar <- if (length(masks) == 0L) {
    ggplot2::ggplot() +
      ggplot2::theme_void() +
      ggplot2::labs(title = "No regions available")
  } else {
    pr_plot_regional_bar(
      pr_calc_regional(trial, masks), "mpp"
    )
  }
  p_force <- pr_plot_force_time(trial, show_cycles = TRUE)
  p_cop <- pr_plot_cop(trial)

  # The two maps share the first row, where their fixed aspect ratio costs the
  # least width; the bar chart and the force curve each span the full width
  # below, so region names and time labels stay legible. The panels keep
  # their order (map, bars, force, COP) for `panels[[i]]`.
  patchwork::wrap_plots(p_hm, p_bar, p_force, p_cop,
    design = "AD\nBB\nCC", heights = c(2.2, 1, 1)
  ) +
    patchwork::plot_annotation(title = "Foot pressure report")
}
