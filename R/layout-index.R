# ---------------------------------------------------------------------------
# Layout / channel-map layer.
#
# Capacitive mats seldom number their channels in the order a human reads the
# grid. This file builds pr_layout objects from an explicit channel -> grid
# index matrix, and exposes the permutation a reader must apply to the raw
# device columns so that coordinates, masks, COP and heatmaps all agree.
#
# Ordering contract (inherited from R/layouts.R and R/class-mask.R):
#   * .layout_build_coords() numbers sensors in which(active) order, which is
#     column-major over the grid.
#   * pr_mask() resolves sensor columns with match(which(mask & active),
#     which(active)) -- the same column-major order.
#   * pr_calc_cop() reads coords_mm positionally against pressure columns.
# So the pressure matrix must arrive in column-major grid order, and
# pr_channel_order() is exactly the permutation that puts it there:
#   pressure_grid <- pressure_raw[, pr_channel_order(layout)]
# ---------------------------------------------------------------------------

# Internal: validate a channel -> grid index matrix and return its parts.
#
# `index_matrix[r, c]` is the *device channel number* that sits at grid cell
# (r, c). NA or 0 marks a grid cell with no sensor behind it.
.index_map_check <- function(index_matrix, arg = "index_matrix") {
  if (!is.matrix(index_matrix) || !is.numeric(index_matrix)) {
    cli::cli_abort(
      "{.arg {arg}} must be a numeric matrix giving the device channel at
       each grid cell."
    )
  }
  if (length(index_matrix) == 0L) {
    cli::cli_abort("{.arg {arg}} must have at least one cell.")
  }

  vals <- as.numeric(index_matrix)
  is_off <- is.na(vals) | vals == 0
  live <- vals[!is_off]

  if (length(live) == 0L) {
    cli::cli_abort(
      "{.arg {arg}} marks every grid cell as empty ({.code NA} or {.val 0});
       at least one device channel is required."
    )
  }
  if (any(live < 0) || any(live != round(live)) || any(is.infinite(live))) {
    cli::cli_abort(
      "{.arg {arg}} must contain whole positive channel numbers
       ({.code NA} or {.val 0} for empty cells)."
    )
  }

  live <- as.integer(round(live))
  if (anyDuplicated(live) > 0L) {
    dup <- sort(unique(live[duplicated(live)]))
    cli::cli_abort(c(
      "{.arg {arg}} assigns the same device channel to more than one grid cell.",
      "x" = "Duplicated channel{?s}: {.val {dup}}."
    ))
  }

  active <- matrix(!is_off, nrow(index_matrix), ncol(index_matrix))

  # For a full map (every cell active) the channels must be exactly
  # 1..n_sensors, otherwise pressure[, order] would index out of bounds.
  if (all(active) && !setequal(live, seq_along(live))) {
    n_cells <- length(live)
    wanted <- paste0("1:", n_cells)
    cli::cli_abort(c(
      "{.arg {arg}} covers all {n_cells} grid cells but its channel numbers
       are not {.code {wanted}}.",
      "x" = "Highest channel is {.val {max(live)}}."
    ))
  }

  # Column-major over the grid, matching which(active) in
  # .layout_build_coords() and pr_mask().
  order <- as.integer(index_matrix[active])

  list(
    map = matrix(
      as.integer(ifelse(is_off, NA_integer_, vals)),
      nrow(index_matrix), ncol(index_matrix)
    ),
    active = active,
    order = order,
    n_channels = max(live)
  )
}

# Internal: single numeric that may be NA, but must be positive if it is not.
.check_optional_positive <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L) {
    cli::cli_abort("{.arg {arg}} must be a single number or {.code NA}.")
  }
  if (!is.na(x) && (x <= 0 || is.infinite(x))) {
    cli::cli_abort("{.arg {arg}} must be a positive number or {.code NA}.")
  }
  invisible(x)
}

#' Build a Layout From an Explicit Channel Map
#'
#' Creates a [pr_layout] from a matrix that states, for every grid cell,
#' which *device channel* is wired to it. This is the general answer to the
#' problem that a sensor mat's channel numbering rarely matches the order in
#' which the grid is read. The resulting layout carries the map with it, so
#' [pr_channel_order()] can hand a reader the one permutation that puts raw
#' device columns into the column-major grid order that [pr_mask()],
#' [pr_calc_cop()] and the plotting functions already assume.
#'
#' @param index_matrix Numeric matrix. `index_matrix[r, c]` is the device
#'   channel number sitting at grid cell (`r`, `c`). Channel numbers must be
#'   whole, positive and unique. `NA` or `0` marks a grid cell with no sensor
#'   behind it (that cell becomes inactive). If every cell is active the
#'   channel numbers must be exactly `1:length(index_matrix)`.
#' @param name Character. Short layout identifier. Default `"custom"`.
#' @param sensor_area_cm2 Numeric. Area of one sensor cell in cm², or
#'   `NA_real_` (the default) when the manufacturer never published one.
#'   See *Missing physical scale* below.
#' @param spacing_mm Numeric. Centre-to-centre sensor pitch in mm, or
#'   `NA_real_` (the default) when it is unknown. See *Missing physical
#'   scale* below.
#' @param pressure_range Numeric vector of length 2, or `NULL` (default) for
#'   `c(0, NA_real_)` — a device whose ceiling is not known.
#' @param ... Further arguments passed to [pr_layout()], e.g. `regions`,
#'   `description`, `manufacturer`, `model`, `pressure_unit`.
#'
#' @section Missing physical scale:
#' `pr_layout()` requires a positive `sensor_area_cm2` and physical
#' `x_mm` / `y_mm` coordinates. Many real datasets have neither: the cell
#' area and the sensor pitch were simply never recorded. Rather than invent
#' a number, this function
#' * builds the object through [pr_layout()] with a placeholder area and then
#'   writes `NA_real_` into `sensor_area_cm2`, so the layout stays a valid
#'   `pr_layout` and [pr_validate_layout()] still passes, while anything
#'   derived from area (force in N, contact area in cm²) honestly returns
#'   `NA`; and
#' * when `spacing_mm` is `NA`, lays the coordinates out on a unit grid
#'   (`x_mm = col - 1`, `y_mm = row - 1`). Ordering, masks and centre of
#'   pressure are then all correct, but **the `x_mm` / `y_mm` columns are
#'   grid-index offsets, not millimetres** — a COP of `x_mm = 8` means
#'   column 9, not 8 mm. The layout records this in `$coords_units`
#'   (`"grid_index"` or `"mm"`) and keeps the requested pitch in
#'   `$spacing_mm`.
#'
#' Supply a real `sensor_area_cm2` / `spacing_mm` and the layout behaves as
#' a fully physical one. Note that [plot.pr_layout()] sizes region tiles from
#' `sensor_area_cm2`, so pass `regions` only alongside a real area.
#'
#' @return A [pr_layout] object with three extra fields: `channel_map` (the
#'   validated integer map, `NA` for empty cells), `channel_order` (the
#'   permutation returned by [pr_channel_order()]) and `coords_units`.
#' @family channel map functions
#' @export
#' @examples
#' # A 2x2 mat whose channels are wired right-to-left within each row.
#' m <- rbind(c(2L, 1L), c(4L, 3L))
#' lay <- pr_layout_from_index_map(m, name = "toy_2x2")
#' lay$n_sensors
#' pr_channel_order(lay)
#'
#' # Raw device frame: only channel 1 is loaded.
#' raw <- matrix(c(10, 0, 0, 0), nrow = 1)
#' grid_cols <- raw[, pr_channel_order(lay), drop = FALSE]
#' # Channel 1 is at grid (1, 2), i.e. the 3rd cell in column-major order.
#' which(grid_cols[1, ] > 0)
pr_layout_from_index_map <- function(index_matrix, name = "custom",
                                     sensor_area_cm2 = NA_real_,
                                     spacing_mm = NA_real_,
                                     pressure_range = NULL, ...) {
  chk <- .index_map_check(index_matrix)
  .check_optional_positive(sensor_area_cm2, "sensor_area_cm2")
  .check_optional_positive(spacing_mm, "spacing_mm")

  if (!is.character(name) || length(name) != 1L || is.na(name)) {
    cli::cli_abort("{.arg name} must be a single string.")
  }
  if (is.null(pressure_range)) {
    pressure_range <- c(0, NA_real_)
  }

  dots <- list(...)
  clash <- intersect(
    names(dots),
    c("grid_rows", "grid_cols", "active", "coords_mm",
      "sensor_area_cm2", "pressure_range", "name")
  )
  if (length(clash) > 0L) {
    cli::cli_abort(
      "{.arg {clash}} {?is/are} set by {.fn pr_layout_from_index_map} and
       must not be passed through {.arg ...}."
    )
  }

  # Unit grid when the true pitch is unknown; see 'Missing physical scale'.
  eff_spacing <- if (is.na(spacing_mm)) 1 else spacing_mm
  coords <- .layout_build_coords(chk$active, spacing_mm = eff_spacing)

  layout <- do.call(
    pr_layout,
    c(
      list(
        grid_rows = nrow(chk$active),
        grid_cols = ncol(chk$active),
        active = chk$active,
        coords_mm = coords,
        # Placeholder: overwritten below when the true area is unknown.
        sensor_area_cm2 = if (is.na(sensor_area_cm2)) 1 else sensor_area_cm2,
        pressure_range = pressure_range,
        name = name
      ),
      dots
    )
  )

  layout$sensor_area_cm2 <- as.numeric(sensor_area_cm2)
  layout$spacing_mm <- as.numeric(spacing_mm)
  layout$coords_units <- if (is.na(spacing_mm)) "grid_index" else "mm"
  layout$channel_map <- chk$map
  layout$channel_order <- chk$order
  layout$n_channels <- chk$n_channels
  layout
}

# Internal: the 16x16 two-panel Novel/Pliance saddle channel map.
#
# The mat is two 16x8 panels read as one 16x16 grid. The RIGHT panel
# (grid cols 9-16) carries channels 1-8 in each row, the LEFT panel (grid
# cols 1-8) carries channels 9-16 running right-to-left, and each subsequent
# grid row advances the channel number by 16. Hence channel 1 sits at grid
# (row 1, col 9) and channel 9 at (row 1, col 8).
.novel_saddle_channel_map <- function() {
  left <- matrix(0L, 16, 16 / 2)
  id <- 9L
  for (i in seq_len(16)) {
    left[i, ] <- seq.int(id + 7L, id, by = -1L)
    id <- id + 16L
  }
  right <- matrix(0L, 16, 16 / 2)
  id <- 1L
  for (i in seq_len(16)) {
    right[i, ] <- seq.int(id, id + 7L)
    id <- id + 16L
  }
  cbind(left, right)
}

#' Novel/Pliance 16x16 Saddle Mat Layout
#'
#' The ready-made layout for the two-panel 16 x 16 (256 sensor) capacitive
#' saddle mat exported by Novel/Pliance systems. All 256 sensors are active.
#'
#' The mat is built from two 16 x 8 panels. Device channel 1 sits at grid
#' (row 1, column 9) — the first cell of the *right* panel — and channel 9
#' at (row 1, column 8), with each grid row advancing the channel number by
#' 16 and the left panel running right-to-left. Applying
#' `pressure[, pr_channel_order(layout)]` to a raw export therefore places
#' every channel at its true anatomical position, which is what makes
#' [pr_mask_saddle_6()], [pr_mask_symmetry()], [pr_calc_cop()] and the
#' heatmaps simultaneously correct. Without the permutation the aggregate
#' statistics (mean, peak, total) are unchanged, so a wrong map is invisible
#' in every summary and wrong in every map.
#'
#' No sensor pitch or cell area is published for this mat, so both default
#' to `NA` and the coordinates are grid indices — see the *Missing physical
#' scale* section of [pr_layout_from_index_map()].
#'
#' @param pressure_range Numeric vector of length 2. Default
#'   `c(0, 63.75)` kPa, the hardware ceiling (255 x 0.25 kPa).
#' @param sensor_area_cm2 Numeric. Cell area in cm²; `NA_real_` by default
#'   because the manufacturer never published one.
#' @param ... Further arguments passed to [pr_layout_from_index_map()], e.g.
#'   `name`, `spacing_mm`, `description`, `regions`.
#'
#' @return A [pr_layout] with 256 active sensors and a `channel_map` field.
#' @family channel map functions
#' @export
#' @examples
#' layout <- pr_layout_saddle_novel()
#' layout$n_sensors
#' layout$channel_map[1, 1:10]
#'
#' # Device channel 1 lands at grid (row 1, col 9):
#' pos <- match(1L, pr_channel_order(layout))
#' layout$coords_mm[pos, c("row", "col")]
pr_layout_saddle_novel <- function(pressure_range = c(0, 63.75),
                                   sensor_area_cm2 = NA_real_, ...) {
  if (!is.numeric(pressure_range) || length(pressure_range) != 2L) {
    cli::cli_abort("{.arg pressure_range} must be numeric of length 2.")
  }

  dots <- list(...)
  defaults <- list(
    name = "saddle_novel",
    spacing_mm = NA_real_,
    description = paste(
      "Novel/Pliance two-panel saddle pressure mat (16x16, 256 sensors).",
      "Channel 1 is at grid (row 1, col 9)."
    ),
    manufacturer = "Novel",
    model = "saddle_novel"
  )
  for (nm in names(defaults)) {
    if (is.null(dots[[nm]])) dots[[nm]] <- defaults[[nm]]
  }

  do.call(
    pr_layout_from_index_map,
    c(
      list(
        index_matrix = .novel_saddle_channel_map(),
        sensor_area_cm2 = sensor_area_cm2,
        pressure_range = pressure_range
      ),
      dots
    )
  )
}

#' Raw Device Channel Order for a Layout
#'
#' Returns the integer permutation that reorders the columns of a raw device
#' export into the column-major grid order every other `pressR` function
#' assumes. A reader applies it once:
#' `pressure <- raw[, pr_channel_order(layout), drop = FALSE]`.
#'
#' Element `k` of the result is the *device channel* that belongs in pressure
#' column `k`, where column `k` corresponds to `which(layout$active)[k]` —
#' the same column-major ordering used by [pr_mask()] and
#' `.layout_build_coords()`.
#'
#' @param layout_or_map A [pr_layout] built by
#'   [pr_layout_from_index_map()] (or [pr_layout_saddle_novel()]), a channel
#'   index matrix as accepted by [pr_layout_from_index_map()], or an integer
#'   vector that already is such a permutation.
#'
#' @return An integer vector of length `layout$n_sensors`.
#' @family channel map functions
#' @export
#' @examples
#' pr_channel_order(rbind(c(2L, 1L), c(4L, 3L)))
#'
#' ord <- pr_channel_order(pr_layout_saddle_novel())
#' length(ord)
#' ord[1:8]
pr_channel_order <- function(layout_or_map) {
  if (inherits(layout_or_map, "pr_layout")) {
    ord <- layout_or_map$channel_order
    if (is.null(ord)) {
      if (is.null(layout_or_map$channel_map)) {
        cli::cli_abort(c(
          "Layout {.val {layout_or_map$name}} carries no channel map.",
          "i" = "Build it with {.fn pr_layout_from_index_map} (or use
                 {.fn pr_layout_saddle_novel}) so the raw-to-grid
                 permutation is known."
        ))
      }
      ord <- .index_map_check(layout_or_map$channel_map, "channel_map")$order
    }
    return(as.integer(ord))
  }

  if (is.matrix(layout_or_map)) {
    return(.index_map_check(layout_or_map, "layout_or_map")$order)
  }

  if (is.numeric(layout_or_map) && is.null(dim(layout_or_map))) {
    v <- as.numeric(layout_or_map)
    if (length(v) == 0L || anyNA(v) || any(v != round(v)) ||
        !setequal(as.integer(v), seq_along(v))) {
      cli::cli_abort(
        "A bare {.arg layout_or_map} vector must be a permutation of
         {.code 1:length(layout_or_map)}."
      )
    }
    return(as.integer(v))
  }

  cli::cli_abort(
    "{.arg layout_or_map} must be a {.cls pr_layout}, a channel index
     matrix, or a permutation vector, not {.obj_type_friendly {layout_or_map}}."
  )
}
