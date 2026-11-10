# ---------------------------------------------------------------------------
# Predefined sensor layouts.
#
# Each public factory function constructs a pr_layout with realistic
# geometry for a specific application. Layouts are generated
# programmatically (not loaded from external JSON) so they are always
# self-consistent and do not bloat the package source.
# ---------------------------------------------------------------------------

.layout_build_coords <- function(active, spacing_mm = 10) {
  idx <- which(active, arr.ind = TRUE)
  if (nrow(idx) == 0L) {
    return(tibble::tibble(
      sensor_id = integer(), row = integer(), col = integer(),
      x_mm = numeric(), y_mm = numeric()
    ))
  }
  tibble::tibble(
    sensor_id = seq_len(nrow(idx)),
    row = as.integer(idx[, 1]),
    col = as.integer(idx[, 2]),
    x_mm = (idx[, 2] - 1) * spacing_mm,
    y_mm = (idx[, 1] - 1) * spacing_mm
  )
}

# ---------- insole (99-sensor foot-shaped insole) --------------------------

# Build a 99-sensor foot-shaped active mask on an 18x8 grid.
# Rows are ordered with row 1 at the toes (top) and row 18 at the heel
# (bottom) in data-space.
.insole_active_mask <- function() {
  m <- matrix(FALSE, nrow = 18, ncol = 8)

  # Target total = 99 sensors across an 18 x 8 grid.
  m[1, 2:7] <- TRUE   # 6
  m[2, 2:7] <- TRUE   # 6
  m[3, 1:8] <- TRUE   # 8
  m[4, 1:8] <- TRUE   # 8
  m[5, 1:7] <- TRUE   # 7
  m[6, 2:7] <- TRUE   # 6
  m[7, 3:7] <- TRUE   # 5
  m[8, 3:7] <- TRUE   # 5
  m[9, 3:7] <- TRUE   # 5
  m[10, 3:7] <- TRUE  # 5
  m[11, 3:7] <- TRUE  # 5
  m[12, 3:7] <- TRUE  # 5
  m[13, 2:6] <- TRUE  # 5
  m[14, 1:7] <- TRUE  # 7
  m[15, 1:7] <- TRUE  # 7
  m[16, 3:6] <- TRUE  # 4
  m[17, 3:5] <- TRUE  # 3
  m[18, 3:4] <- TRUE  # 2

  # Sum: 6+6+8+8+7+6+5+5+5+5+5+5+5+7+7+4+3+2 = 99
  stopifnot(sum(m) == 99)
  m
}

.insole_regions <- function(active) {
  reg <- list()
  m <- matrix(FALSE, 18, 8); m[13:18, ] <- TRUE; m <- m & active
  reg$heel <- m
  m <- matrix(FALSE, 18, 8); m[5:12, ] <- TRUE; m <- m & active
  reg$midfoot <- m
  m <- matrix(FALSE, 18, 8); m[3:4, 1:2] <- TRUE; m <- m & active
  reg$metatarsal_1 <- m
  m <- matrix(FALSE, 18, 8); m[3:4, 3:5] <- TRUE; m <- m & active
  reg$metatarsal_2_3 <- m
  m <- matrix(FALSE, 18, 8); m[3:4, 6:8] <- TRUE; m <- m & active
  reg$metatarsal_4_5 <- m
  m <- matrix(FALSE, 18, 8); m[1:2, 2:3] <- TRUE; m <- m & active
  reg$hallux <- m
  m <- matrix(FALSE, 18, 8); m[1:2, 4:7] <- TRUE; m <- m & active
  reg$lesser_toes <- m
  reg
}

#' Get In-Shoe Pressure Insole Layout
#'
#' Returns a [pr_layout] representing a typical in-shoe pressure
#' measurement insole. The insole contains 99 capacitive sensors
#' arranged in an anatomically shaped grid.
#'
#' @param size Character. Insole size variant: `"standard"` (default) or
#'   `"wide"` (wider shoe insole with broader sensor spacing).
#'
#' @return A [pr_layout] object with predefined foot region masks.
#' @export
#' @examples
#' layout <- pr_layout_insole()
#' print(layout)
pr_layout_insole <- function(size = c("standard", "wide")) {
  size <- match.arg(size)
  active <- .insole_active_mask()
  spacing <- if (size == "wide") 12 else 10
  coords <- .layout_build_coords(active, spacing_mm = spacing)

  # Reposition y so toes have the highest y_mm (row 1 at top).
  coords$y_mm <- (max(coords$row) - coords$row) * spacing

  regions <- .insole_regions(active)

  pr_layout(
    grid_rows = 18, grid_cols = 8,
    active = active,
    coords_mm = coords,
    regions = regions,
    sensor_area_cm2 = 1.5,
    pressure_range = c(0, 1200),
    pressure_unit = "kPa",
    name = sprintf("insole_%s", size),
    description = sprintf(
      "In-shoe pressure insole (99 sensors, %s).", size
    ),
    manufacturer = "",
    model = "insole"
  )
}

# ---------- platform (high-resolution pressure plate) ----------------------

.platform_active_mask <- function() {
  m <- matrix(FALSE, 64, 40)
  m[5:60, 5:36] <- TRUE
  m
}

#' Get Pressure Platform Layout
#'
#' Returns a [pr_layout] for a barefoot pressure platform. Provides
#' high-resolution plantar pressure distribution during static and
#' dynamic conditions.
#'
#' @param model Character. Platform model: `"st"` (standard, default),
#'   `"xl"` (extended length), or `"cl"` (clinical/compact).
#'
#' @return A [pr_layout] object. Region masks are not predefined — use
#'   [pr_mask_foot_auto()] to auto-segment footprints from the data.
#' @export
#' @examples
#' layout <- pr_layout_platform()
#' layout$grid_rows
#' layout$grid_cols
pr_layout_platform <- function(model = c("st", "xl", "cl")) {
  model <- match.arg(model)
  active <- switch(
    model,
    st = .platform_active_mask(),
    xl = {
      m <- matrix(FALSE, 96, 40)
      m[5:92, 5:36] <- TRUE
      m
    },
    cl = {
      m <- matrix(FALSE, 48, 32)
      m[5:44, 3:30] <- TRUE
      m
    }
  )
  coords <- .layout_build_coords(active, spacing_mm = 5)

  pr_layout(
    grid_rows = nrow(active), grid_cols = ncol(active),
    active = active,
    coords_mm = coords,
    regions = list(),
    sensor_area_cm2 = 0.25,
    pressure_range = c(0, 1270),
    pressure_unit = "kPa",
    name = sprintf("platform_%s", model),
    description = sprintf(
      "Barefoot pressure platform (%s).", toupper(model)
    ),
    manufacturer = "",
    model = "platform"
  )
}

# ---------- mat (generic sensor mat) ---------------------------------------

#' Get Generic Sensor Mat Layout
#'
#' Returns a [pr_layout] for a generic capacitive pressure sensor mat.
#' These general-purpose sensor arrays are used in research, seating,
#' sports, and ergonomics applications.
#'
#' @param size Character. `"16"` (default) for 16x16 = 256 sensors or
#'   `"32"` for 32x32 = 1024 sensors.
#'
#' @return A [pr_layout] with no predefined regions.
#' @export
#' @examples
#' mat <- pr_layout_mat("16")
#' mat$n_sensors
#' pr_layout_mat("32")$n_sensors
pr_layout_mat <- function(size = c("16", "32")) {
  size <- match.arg(size)
  n <- as.integer(size)
  active <- matrix(TRUE, n, n)
  coords <- .layout_build_coords(active, spacing_mm = 25.4)

  pr_layout(
    grid_rows = n, grid_cols = n,
    active = active,
    coords_mm = coords,
    regions = list(),
    sensor_area_cm2 = 6.25,
    pressure_range = c(0, 600),
    pressure_unit = "kPa",
    name = sprintf("mat_%s", size),
    description = sprintf("Pressure sensor mat (%sx%s).", n, n),
    manufacturer = "",
    model = "mat"
  )
}

# ---------- saddle: horse / bicycle ----------------------------------------

.saddle_horse_active <- function() {
  m <- matrix(TRUE, 16, 16)
  # Withers cutout: rows 1-2, cols 7-10
  m[1:2, 7:10] <- FALSE
  m
}

.saddle_horse_regions <- function(active) {
  reg <- list()
  cranial <- matrix(FALSE, 16, 16); cranial[1:5, ] <- TRUE
  middle  <- matrix(FALSE, 16, 16); middle[6:11, ] <- TRUE
  caudal  <- matrix(FALSE, 16, 16); caudal[12:16, ] <- TRUE
  left    <- matrix(FALSE, 16, 16); left[, 1:8] <- TRUE
  right   <- matrix(FALSE, 16, 16); right[, 9:16] <- TRUE

  reg$cranial_left  <- cranial & left  & active
  reg$cranial_right <- cranial & right & active
  reg$middle_left   <- middle  & left  & active
  reg$middle_right  <- middle  & right & active
  reg$caudal_left   <- caudal  & left  & active
  reg$caudal_right  <- caudal  & right & active
  reg
}

.saddle_bicycle_active <- function() {
  matrix(TRUE, 12, 16)
}

.saddle_bicycle_regions <- function(active) {
  reg <- list()
  lisch <- matrix(FALSE, 12, 16); lisch[9:12, 1:7]   <- TRUE
  risch <- matrix(FALSE, 12, 16); risch[9:12, 10:16] <- TRUE
  per   <- matrix(FALSE, 12, 16); per[9:12, 8:9]     <- TRUE
  ant   <- matrix(FALSE, 12, 16); ant[1:8, ]         <- TRUE
  reg$left_ischial  <- lisch & active
  reg$right_ischial <- risch & active
  reg$perineal      <- per   & active
  reg$anterior      <- ant   & active
  reg
}

#' Get Saddle Pressure Mat Layout
#'
#' Returns a [pr_layout] for saddle pressure measurement using a
#' capacitive sensor mat. Includes predefined region masks based on
#' published research protocols.
#'
#' @param type Character. `"horse"` (default) for equine saddle fitting
#'   with 6-region mask (cranial / middle / caudal x left / right per
#'   Werner et al. 2002), or `"bicycle"` for bicycle saddle with
#'   ischial/perineal regions.
#'
#' @return A [pr_layout] with application-specific region masks.
#' @export
#' @examples
#' layout <- pr_layout_saddle("horse")
#' names(layout$regions)
pr_layout_saddle <- function(type = c("horse", "bicycle")) {
  type <- match.arg(type)
  if (type == "horse") {
    active <- .saddle_horse_active()
    coords <- .layout_build_coords(active, spacing_mm = 31.6)
    regions <- .saddle_horse_regions(active)
    return(pr_layout(
      grid_rows = 16, grid_cols = 16,
      active = active, coords_mm = coords, regions = regions,
      sensor_area_cm2 = 10,
      pressure_range = c(0, 120),
      pressure_unit = "kPa",
      name = "saddle_horse",
      description = "Equine saddle pressure mat (16x16) with 6-region mask.",
      manufacturer = "",
      model = "saddle_mat"
    ))
  }
  # bicycle
  active <- .saddle_bicycle_active()
  coords <- .layout_build_coords(active, spacing_mm = 18)
  regions <- .saddle_bicycle_regions(active)
  pr_layout(
    grid_rows = 12, grid_cols = 16,
    active = active, coords_mm = coords, regions = regions,
    sensor_area_cm2 = 3.2,
    pressure_range = c(0, 100),
    pressure_unit = "kPa",
    name = "saddle_bicycle",
    description = "Bicycle saddle pressure mat (12x16).",
    manufacturer = "",
    model = "saddle_mat"
  )
}

# ---------- seat -----------------------------------------------------------

.seat_wheelchair_regions <- function() {
  reg <- list()
  li <- matrix(FALSE, 32, 32); li[20:27, 8:14]  <- TRUE
  ri <- matrix(FALSE, 32, 32); ri[20:27, 19:25] <- TRUE
  sa <- matrix(FALSE, 32, 32); sa[25:32, 14:19] <- TRUE
  lt <- matrix(FALSE, 32, 32); lt[5:19, 6:15]   <- TRUE
  rt <- matrix(FALSE, 32, 32); rt[5:19, 18:27]  <- TRUE
  reg$left_ischial  <- li
  reg$right_ischial <- ri
  reg$sacral        <- sa
  reg$left_thigh    <- lt
  reg$right_thigh   <- rt
  reg
}

.seat_car_office_regions <- function() {
  reg <- list()
  ls <- matrix(FALSE, 32, 32); ls[17:32, 1:16]  <- TRUE
  rs <- matrix(FALSE, 32, 32); rs[17:32, 17:32] <- TRUE
  lb <- matrix(FALSE, 32, 32); lb[1:16, 1:16]   <- TRUE
  rb <- matrix(FALSE, 32, 32); rb[1:16, 17:32]  <- TRUE
  reg$left_seat_pan  <- ls
  reg$right_seat_pan <- rs
  reg$left_backrest  <- lb
  reg$right_backrest <- rb
  reg
}

#' Get Seating Pressure Mat Layout
#'
#' Returns a [pr_layout] for seating pressure assessment. Uses a 32x32
#' grid (1024 sensors) with application-specific regions.
#'
#' @param type Character. `"wheelchair"` (default), `"car"`, or `"office"`.
#'
#' @return A [pr_layout] object.
#' @export
#' @examples
#' seat <- pr_layout_seat("wheelchair")
#' names(seat$regions)
pr_layout_seat <- function(type = c("wheelchair", "car", "office")) {
  type <- match.arg(type)
  active <- matrix(TRUE, 32, 32)
  coords <- .layout_build_coords(active, spacing_mm = 15)
  regions <- switch(
    type,
    wheelchair = .seat_wheelchair_regions(),
    car        = .seat_car_office_regions(),
    office     = .seat_car_office_regions()
  )
  pr_layout(
    grid_rows = 32, grid_cols = 32,
    active = active, coords_mm = coords, regions = regions,
    sensor_area_cm2 = 2.25,
    pressure_range = c(0, 200),
    pressure_unit = "kPa",
    name = sprintf("seat_%s", type),
    description = sprintf("Seating pressure mat (32x32) for %s.", type),
    manufacturer = "",
    model = "seat_mat"
  )
}

# ---------- glove ----------------------------------------------------------

.glove_active_mask <- function() {
  m <- matrix(FALSE, 12, 10)
  m[1, c(3, 5, 6, 7, 9)] <- TRUE
  m[2, c(5, 6, 7, 9)] <- TRUE
  m[3, c(3, 5, 6, 7, 9)] <- TRUE
  m[4, 4:9] <- TRUE
  m[5, 4:9] <- TRUE
  m[6, 4:9] <- TRUE
  # Total 5+4+5+6+6+6 = 32
  stopifnot(sum(m) == 32)
  m
}

#' Get Glove Sensor Layout
#'
#' Returns a [pr_layout] for a glove-style hand pressure sensor
#' (32 sensors across palm and fingertips).
#'
#' @return A [pr_layout] object.
#' @export
#' @examples
#' glove <- pr_layout_glove()
#' glove$n_sensors
pr_layout_glove <- function() {
  active <- .glove_active_mask()
  coords <- .layout_build_coords(active, spacing_mm = 20)
  pr_layout(
    grid_rows = 12, grid_cols = 10,
    active = active,
    coords_mm = coords,
    regions = list(),
    sensor_area_cm2 = 1.0,
    pressure_range = c(0, 400),
    pressure_unit = "kPa",
    name = "glove",
    description = "Glove sensor layout (32 sensors).",
    manufacturer = "",
    model = "glove"
  )
}

# ---------- catalog --------------------------------------------------------

#' List All Built-In Sensor Layouts
#'
#' @return A [tibble::tibble] with columns `name`, `system`, `grid_rows`,
#'   `grid_cols`, `n_sensors`, `n_regions`, `description`.
#' @export
#' @examples
#' pr_layout_list()
pr_layout_list <- function() {
  specs <- list(
    list(fn = function() pr_layout_insole("standard")),
    list(fn = function() pr_layout_insole("wide")),
    list(fn = function() pr_layout_platform("st")),
    list(fn = function() pr_layout_platform("xl")),
    list(fn = function() pr_layout_platform("cl")),
    list(fn = function() pr_layout_mat("16")),
    list(fn = function() pr_layout_mat("32")),
    list(fn = function() pr_layout_saddle("horse")),
    list(fn = function() pr_layout_saddle("bicycle")),
    list(fn = function() pr_layout_seat("wheelchair")),
    list(fn = function() pr_layout_seat("car")),
    list(fn = function() pr_layout_seat("office")),
    list(fn = function() pr_layout_glove())
  )
  rows <- lapply(specs, function(s) {
    l <- s$fn()
    tibble::tibble(
      name = l$name,
      system = l$model,
      grid_rows = l$grid_rows,
      grid_cols = l$grid_cols,
      n_sensors = l$n_sensors,
      n_regions = length(l$regions),
      description = l$description
    )
  })
  do.call(rbind, rows)
}

# Internal dispatcher used by parsers when a layout is not supplied.
.layout_by_name <- function(name) {
  switch(
    name,
    insole_standard = pr_layout_insole("standard"),
    insole_wide     = pr_layout_insole("wide"),
    platform_st     = pr_layout_platform("st"),
    platform_xl     = pr_layout_platform("xl"),
    platform_cl     = pr_layout_platform("cl"),
    mat_16          = pr_layout_mat("16"),
    mat_32          = pr_layout_mat("32"),
    saddle_horse    = pr_layout_saddle("horse"),
    saddle_bicycle  = pr_layout_saddle("bicycle"),
    seat_wheelchair = pr_layout_seat("wheelchair"),
    seat_car        = pr_layout_seat("car"),
    seat_office     = pr_layout_seat("office"),
    glove           = pr_layout_glove(),
    NULL
  )
}

# Internal: guess a layout from sensor count.
.layout_from_n_sensors <- function(n) {
  candidates <- list(
    c(99,   "insole_standard"),
    c(256,  "mat_16"),
    c(1024, "mat_32"),
    c(32,   "glove")
  )
  for (cand in candidates) {
    if (as.integer(cand[1]) == n) return(.layout_by_name(cand[2]))
  }
  NULL
}
