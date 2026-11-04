# ---------------------------------------------------------------------------
# Heatmap visualization functions.
# ---------------------------------------------------------------------------

# Internal: build a tile-plot tibble from a pressure vector over a layout.
.heatmap_tibble <- function(layout, values) {
  coords <- layout$coords_mm
  tibble::tibble(
    sensor_id = coords$sensor_id,
    row = coords$row,
    col = coords$col,
    x_mm = coords$x_mm,
    y_mm = coords$y_mm,
    value = values
  )
}

# Internal: colour palette dispatch.
.palette_fill <- function(palette, range = NULL, name = "Pressure (kPa)") {
  switch(palette,
    viridis = ggplot2::scale_fill_viridis_c(
      option = "viridis", limits = range, name = name, na.value = "white"
    ),
    inferno = ggplot2::scale_fill_viridis_c(
      option = "inferno", limits = range, name = name, na.value = "white"
    ),
    plasma = ggplot2::scale_fill_viridis_c(
      option = "plasma", limits = range, name = name, na.value = "white"
    ),
    magma = ggplot2::scale_fill_viridis_c(
      option = "magma", limits = range, name = name, na.value = "white"
    ),
    jet = ggplot2::scale_fill_gradientn(
      colours = c("#000080", "#0000FF", "#00FFFF", "#FFFF00", "#FF0000", "#800000"),
      limits = range, name = name, na.value = "white"
    ),
    classic = ggplot2::scale_fill_gradientn(
      colours = c("#002A5A", "#006EB9", "#33AD5C", "#F2E300", "#EC6C1D", "#C21D1D"),
      limits = range, name = name, na.value = "white"
    ),
    cli::cli_abort("Unknown palette {.val {palette}}.")
  )
}

#' Plot Pressure Heatmap
#'
#' Displays a 2D heatmap for a single frame or a summary image
#' (MPP, MVP, PTI, contact frequency).
#'
#' @param trial A [pr_trial] object.
#' @param frame Integer. Frame number to display. If `NULL` (default),
#'   shows the summary picture specified by `type`.
#' @param type Character. Summary type when `frame` is `NULL`:
#'   `"mpp"` (max), `"mvp"` (mean), `"pti"` (pressure-time integral),
#'   `"contact"` (contact frequency).
#' @param show_regions Logical. Overlay region boundaries. Default `FALSE`.
#' @param palette Character. One of `"viridis"` (default), `"inferno"`,
#'   `"plasma"`, `"magma"`, `"jet"`, `"classic"`.
#' @param range Numeric vector of length 2. Colour range. `NULL` auto-scales.
#' @param interpolate Logical. Reserved for spatial interpolation (currently
#'   draws the raw sensor grid). Default `FALSE`.
#' @param title Character. Plot title. `NULL` auto-generates.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' trial <- pr_example_trial("insole")
#' pr_plot_heatmap(trial)
pr_plot_heatmap <- function(trial, frame = NULL,
                            type = c("mpp", "mvp", "pti", "contact"),
                            show_regions = FALSE,
                            palette = "viridis",
                            range = NULL, interpolate = FALSE,
                            title = NULL) {
  .validate_trial(trial)
  type <- match.arg(type)

  if (!is.null(frame)) {
    if (!is.numeric(frame) || length(frame) != 1L ||
      frame < 1 || frame > trial$n_frames) {
      cli::cli_abort(
        "{.arg frame} must be an integer in 1..{trial$n_frames}."
      )
    }
    values <- trial$pressure[frame, ]
    label <- sprintf("Frame %d (t = %.3f s)", frame, trial$time[frame])
    legend_title <- sprintf("Pressure (%s)", trial$layout$pressure_unit)
  } else {
    values <- switch(type,
      mpp = apply(trial$pressure, 2, max),
      mvp = apply(trial$pressure, 2, function(c) {
        ld <- c[c > 0]
        if (length(ld) == 0L) 0 else mean(ld)
      }),
      pti = pr_calc_pti(trial),
      contact = colMeans(trial$pressure > 0)
    )
    label <- switch(type,
      mpp = "Maximum Pressure Picture (MPP)",
      mvp = "Mean Pressure (loaded sensors)",
      pti = "Pressure-Time Integral (PTI)",
      contact = "Contact frequency"
    )
    legend_title <- switch(type,
      mpp = sprintf("Peak (%s)", trial$layout$pressure_unit),
      mvp = sprintf("Mean (%s)", trial$layout$pressure_unit),
      pti = sprintf("PTI (%s\u00b7s)", trial$layout$pressure_unit),
      contact = "Fraction"
    )
  }

  df <- .heatmap_tibble(trial$layout, values)

  tile_w <- .tile_size(trial$layout)
  tile_h <- tile_w

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x_mm, y = .data$y_mm)) +
    ggplot2::geom_tile(
      ggplot2::aes(fill = .data$value),
      width = tile_w, height = tile_h
    ) +
    .palette_fill(palette, range, legend_title) +
    ggplot2::coord_fixed() +
    ggplot2::labs(
      title = title %||% label,
      subtitle = sprintf("Layout: %s", trial$layout$name),
      x = sprintf("x (%s)", .coordinate_label(trial$layout)), y = sprintf("y (%s)", .coordinate_label(trial$layout))
    ) +
    ggplot2::theme_minimal(base_size = 11)

  if (show_regions && length(trial$layout$regions) > 0L) {
    reg_df <- .regions_to_df(trial$layout)
    p <- p + ggplot2::geom_tile(
      data = reg_df,
      ggplot2::aes(x = .data$x_mm, y = .data$y_mm, colour = .data$region),
      width = tile_w, height = tile_h,
      fill = NA, linewidth = 0.4, alpha = 0.8,
      inherit.aes = FALSE
    ) + ggplot2::guides(colour = ggplot2::guide_legend(title = "Region"))
  }
  p
}

#' Plot Pressure Heatmap with Region Overlay
#'
#' Convenience wrapper for [pr_plot_heatmap()] that always overlays
#' region boundaries.
#'
#' @inheritParams pr_plot_heatmap
#' @param masks Named list of [pr_mask] objects or logical matrices.
#'   If `NULL`, uses layout regions.
#' @return A `ggplot2` object.
#' @export
#' @examples
#' pr_plot_heatmap_masked(pr_example_trial("saddle_horse"))
pr_plot_heatmap_masked <- function(trial, masks = NULL, frame = NULL,
                                   type = c("mpp", "mvp", "pti", "contact"),
                                   palette = "viridis", range = NULL,
                                   title = NULL) {
  .validate_trial(trial)
  type <- match.arg(type)
  if (is.null(masks)) {
    return(pr_plot_heatmap(
      trial,
      frame = frame, type = type, show_regions = TRUE,
      palette = palette, range = range, title = title
    ))
  }
  # If user-supplied masks: just draw the regular heatmap plus geom_tile layers
  p <- pr_plot_heatmap(trial,
    frame = frame, type = type,
    palette = palette, range = range, title = title
  )
  tile_w <- .tile_size(trial$layout)
  coords <- trial$layout$coords_mm
  for (nm in names(masks)) {
    cols <- .mask_to_cols(masks[[nm]], trial$layout)
    if (length(cols) == 0L) next
    d <- coords[cols, , drop = FALSE]
    d$region <- nm
    p <- p + ggplot2::geom_tile(
      data = d, ggplot2::aes(x = .data$x_mm, y = .data$y_mm, colour = .data$region),
      width = tile_w, height = tile_w, fill = NA, linewidth = 0.4,
      inherit.aes = FALSE
    )
  }
  p
}

#' Interactive 3D Pressure Surface
#'
#' Renders a pressure frame as a 3D surface using `plotly`.
#'
#' @param trial A [pr_trial] object.
#' @param frame Integer. Frame to display. If `NULL`, uses the MPP.
#' @param palette Character. One of the heatmap palettes.
#'
#' @return A `plotly` object.
#' @export
#' @examples
#' \donttest{
#' pr_plot_3d(pr_example_trial("saddle_horse"))
#' }
pr_plot_3d <- function(trial, frame = NULL, palette = "viridis") {
  .validate_trial(trial)
  if (!is.null(frame)) {
    values <- trial$pressure[frame, ]
  } else {
    values <- apply(trial$pressure, 2, max)
  }
  layout <- trial$layout
  grid <- matrix(NA_real_, layout$grid_rows, layout$grid_cols)
  grid[cbind(layout$coords_mm$row, layout$coords_mm$col)] <- values

  pal <- switch(palette,
    viridis = "Viridis",
    inferno = "Inferno",
    plasma = "Plasma",
    magma = "Magma",
    jet = "Jet",
    classic = "Portland",
    "Viridis"
  )

  plotly::plot_ly(z = grid, type = "surface", colorscale = pal) |>
    plotly::layout(
      title = sprintf("Pressure surface (%s)", layout$name),
      scene = list(
        xaxis = list(title = "Col"),
        yaxis = list(title = "Row"),
        zaxis = list(title = sprintf("Pressure (%s)", layout$pressure_unit))
      )
    )
}
