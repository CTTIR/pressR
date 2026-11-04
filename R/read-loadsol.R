#' Read Force Sensor Data
#'
#' Parses a CSV file containing force data from a portable force-sensing
#' insole or similar device. These systems typically record a small number
#' of force zones (not a full pressure matrix); this parser returns a
#' simplified [pr_trial] where each "sensor" represents a force zone.
#' Pressure values are reported in Newtons.
#'
#' @inheritSection pr_read_csv Numeric text
#'
#' @param path Character. Path to the CSV file.
#' @param force_cols Character vector. Names of force columns. If `NULL`,
#'   all columns other than the time column are used and must be numeric.
#' @param time_col Character. Name of the time column. Default `"time"`.
#' @param verbose Logical. Default `TRUE`.
#'
#' @return A [pr_trial] object with a minimal single-row layout
#'   (one sensor per force zone).
#' @export
#' @examples
#' tmp <- tempfile(fileext = ".csv")
#' df <- data.frame(
#'   time = seq(0, 1, by = 0.01),
#'   heel = runif(101, 0, 200),
#'   mid = runif(101, 0, 150),
#'   fore = runif(101, 0, 300)
#' )
#' utils::write.csv(df, tmp, row.names = FALSE)
#' trial <- pr_read_forcesensor(tmp, verbose = FALSE)
#' trial$n_sensors
pr_read_forcesensor <- function(path, force_cols = NULL, time_col = "time",
                                verbose = TRUE) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}.")
  }
  df <- .read_measurement_delim(path, name_repair = "check_unique")
  if (nrow(readr::problems(df))) cli::cli_abort("Malformed force measurements.")
  if (!nrow(df)) cli::cli_abort("Force CSV contains no measurements.")

  if (!time_col %in% names(df)) {
    cli::cli_abort("Time column {.val {time_col}} not found.")
  }
  if (!.real_vector(df[[time_col]])) cli::cli_abort("Force timestamps must be numeric.")
  t <- df[[time_col]]

  if (is.null(force_cols)) {
    force_cols <- setdiff(names(df), time_col)
  }
  missing <- setdiff(force_cols, names(df))
  if (length(missing) > 0L) {
    cli::cli_abort("Force column(s) not found: {.val {missing}}.")
  }
  if (!length(force_cols) || !all(vapply(df[force_cols], .real_vector, logical(1)))) {
    cli::cli_abort("Force columns must contain numeric measurements, not logical or text values.")
  }
  mat <- as.matrix(df[, force_cols, drop = FALSE])
  storage.mode(mat) <- "double"

  n_zones <- ncol(mat)
  active <- matrix(TRUE, 1L, n_zones)
  coords <- tibble::tibble(
    sensor_id = seq_len(n_zones),
    row = rep(1L, n_zones),
    col = seq_len(n_zones),
    x_mm = seq_len(n_zones) - 1,
    y_mm = rep(0, n_zones)
  )
  layout <- pr_layout(
    grid_rows = 1L, grid_cols = n_zones,
    active = active, coords_mm = coords,
    sensor_area_cm2 = 1,
    pressure_range = c(0, max(mat, na.rm = TRUE)),
    pressure_unit = "N",
    name = "force_sensor",
    description = "Force sensor zones (one sensor per zone).",
    manufacturer = "",
    model = "force_sensor"
  )
  layout$sensor_area_cm2 <- NA_real_
  layout$coords_units <- "grid_index"

  dt <- if (length(t) >= 2L) stats::median(diff(t)) else NA_real_
  hz <- 1 / dt

  if (verbose) {
    cli::cli_inform("Read force sensor file with {n_zones} zone(s), {nrow(mat)} frame(s).")
  }
  pr_trial(
    pressure = mat, time = t, layout = layout,
    metadata = c(list(
      trial_id = tools::file_path_sans_ext(basename(path)),
      system = "force_sensor",
      zones = paste(force_cols, collapse = ",")
    ), .reader_source_metadata(path)),
    sampling_hz = hz
  )
}
