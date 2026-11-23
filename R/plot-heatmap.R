# ---------------------------------------------------------------------------
# Heatmap visualisation functions.
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

# Internal: outline segments of named regions.
#
# Each region is drawn as the boundary of its cells: a cell edge is kept only
# where the neighbouring grid cell does not belong to the same region. Drawing
# one outlined tile per sensor instead hides the pressure picture on
# high-resolution layouts, where the outlines fill the whole tile.
# `regions` is a named list of active-sensor column indices.
.region_outline_df <- function(layout, regions) {
  coords <- layout$coords_mm
  tile <- .tile_size(layout)
  # Direction of increasing grid column and row in plot coordinates. Grids
  # are axis-aligned, so columns run along one plot axis and rows along the
  # other; a single grid line has no direction (slope 0).
  slope <- function(v, g) {
    if (length(unique(g)) < 2L) return(0)
    unname(stats::coef(stats::lm(v ~ g))[2])
  }
  col_dx <- slope(coords$x_mm, coords$col)
  col_dy <- slope(coords$y_mm, coords$col)
  row_dx <- slope(coords$x_mm, coords$row)
  row_dy <- slope(coords$y_mm, coords$row)
  col_on_x <- abs(col_dx) + abs(row_dy) >= abs(col_dy) + abs(row_dx)
  row_on_x <- !col_on_x
  sgn <- function(v) if (v < 0) -1 else 1
  col_step <- if (col_on_x) col_dx else col_dy
  row_step <- if (row_on_x) row_dx else row_dy
  col_sign <- sgn(col_step)
  row_sign <- sgn(row_step)
  # Edges lie halfway between neighbouring cell centres (half the grid pitch);
  # a single line along an axis falls back to half the drawn tile.
  pitch <- function(step) if (abs(step) > 0) abs(step) else tile
  half_x <- pitch(if (col_on_x) col_step else row_step) / 2
  half_y <- pitch(if (col_on_x) row_step else col_step) / 2
  out <- lapply(names(regions), function(nm) {
    cols <- regions[[nm]]
    if (!length(cols)) return(NULL)
    d <- coords[cols, , drop = FALSE]
    key <- paste(d$row, d$col)
    pieces <- list(
      list(dr = 0L, dc = 1L), list(dr = 0L, dc = -1L),
      list(dr = 1L, dc = 0L), list(dr = -1L, dc = 0L)
    )
    # Every finite region has at least one open edge in each direction.
    segs <- lapply(pieces, function(step) {
      open <- !paste(d$row + step$dr, d$col + step$dc) %in% key
      e <- d[open, , drop = FALSE]
      on_x <- if (step$dc != 0L) col_on_x else row_on_x
      dir <- if (step$dc != 0L) step$dc * col_sign else step$dr * row_sign
      if (on_x) {
        x <- e$x_mm + dir * half_x
        data.frame(x = x, xend = x, y = e$y_mm - half_y, yend = e$y_mm + half_y)
      } else {
        y <- e$y_mm + dir * half_y
        data.frame(x = e$x_mm - half_x, xend = e$x_mm + half_x, y = y, yend = y)
      }
    })
    segs <- do.call(rbind, segs)
    segs$region <- nm
    segs
  })
  out <- do.call(rbind, out)
  if (is.null(out)) {
    out <- data.frame(
      x = numeric(), xend = numeric(), y = numeric(), yend = numeric(),
      region = character()
    )
  }
  out
}

# Internal: add region outlines to a heatmap.
.add_region_outlines <- function(p, layout, regions) {
  segs <- .region_outline_df(layout, regions)
  if (!nrow(segs)) return(p)
  segs$region <- factor(segs$region, levels = names(regions))
  p + ggplot2::geom_segment(
    data = segs,
    ggplot2::aes(
      x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend,
      colour = .data$region
    ),
    linewidth = 0.7, lineend = "square", inherit.aes = FALSE
  ) + ggplot2::guides(colour = ggplot2::guide_legend(title = "Region"))
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
    regions <- lapply(trial$layout$regions, .mask_to_cols,
      layout = trial$layout
    )
    p <- .add_region_outlines(p, trial$layout, regions)
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
  if (is.null(names(masks)) || any(!nzchar(names(masks)))) {
    cli::cli_abort("{.arg masks} must be a named list.")
  }
  regions <- lapply(masks, .mask_to_cols, layout = trial$layout)
  .add_region_outlines(p, trial$layout, regions)
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
