#' Read Pressure Data from CSV
#'
#' Reads pressure data from a CSV file in either wide (one column per
#' sensor) or long (tidy) format.
#'
#' @section Numeric text:
#' Numeric text is qualified for nonzero magnitudes from `1e-290` to `1e290`.
#' Values outside this range, or inconsistent decimal conversions, are refused.
#' CSV does not carry layout calibration or promise bit-exact doubles; provide
#' the original layout, or use [pr_write_bundle()] for a self-contained round trip.
#' The actual source path, basename and SHA-256 are retained in trial metadata.
#'
#' @param path Character. Path to CSV file.
#' @param format Character. `"wide"` (default, columns are sensors) or
#'   `"long"` (a tidy format with `frame`, `sensor_id`, `pressure`).
#' @param layout A [pr_layout] object. Required for wide format when the
#'   sensor count cannot be inferred. Declared long-format sensor IDs or wide
#'   `s<number>` column names must match the supplied or inferred layout;
#'   measurements are aligned to its sensor order. Other wide column names
#'   retain positional order.
#' @param time_col Character. Name of the time column. If `NULL`, the exported `time` column is recognized automatically;
#'   otherwise timestamps are generated from `sampling_hz`.
#' @param sampling_hz Numeric. Used when timestamps are absent (default `100`).
#'   With timestamps, the rate is inferred unless explicitly supplied; conflicts
#'   with measured timing are rejected.
#' @param verbose Logical. Default `TRUE`.
#'
#' @return A [pr_trial] object.
#' @export
#' @examples
#' tmp <- tempfile(fileext = ".csv")
#' m <- matrix(runif(10 * 99, 0, 100), nrow = 10, ncol = 99)
#' utils::write.csv(m, tmp, row.names = FALSE)
#' trial <- pr_read_csv(tmp,
#'   format = "wide", layout = pr_layout_insole(),
#'   verbose = FALSE
#' )
#' trial$n_frames
pr_read_csv <- function(path, format = c("wide", "long"), layout = NULL,
                        time_col = NULL, sampling_hz = 100,
                        verbose = TRUE) {
  if (!file.exists(path)) cli::cli_abort("File not found: {.path {path}}.")
  rate_given <- !missing(sampling_hz)
  format_given <- !missing(format)
  format <- match.arg(format)
  df <- .read_measurement_delim(path,
    name_repair = "check_unique"
  )
  if (nrow(readr::problems(df))) cli::cli_abort("CSV contains malformed rows or values.")
  if (!nrow(df)) cli::cli_abort("CSV contains no measurements.")
  if (!format_given && all(c("frame", "sensor_id", "pressure") %in% names(df))) format <- "long"
  if (is.null(time_col) && "time" %in% names(df)) time_col <- "time"
  if (!is.null(time_col) && !time_col %in% names(df)) cli::cli_abort("Time column {.val {time_col}} not found.")
  if (format == "wide") {
    t <- if (!is.null(time_col)) df[[time_col]] else NULL
    sensors <- setdiff(names(df), c("frame", time_col))
    if (!is.null(layout) && all(grepl("^s[0-9]+$", sensors))) {
      expected <- paste0("s", layout$coords_mm$sensor_id)
      if (!setequal(sensors, expected)) cli::cli_abort("CSV sensor identifiers do not match the layout.")
      sensors <- expected
    }
    if (!all(vapply(df[sensors], is.numeric, logical(1)))) cli::cli_abort("Sensor columns must be numeric; identify metadata columns explicitly.")
    mat <- as.matrix(df[sensors])
  } else {
    required <- c("frame", "sensor_id", "pressure")
    if (!all(required %in% names(df))) cli::cli_abort("Long CSV must contain frame, sensor_id and pressure columns.")
    if (anyNA(df$frame) || anyNA(df$sensor_id)) cli::cli_abort("Frame and sensor identifiers cannot be missing.")
    if (anyDuplicated(df[c("frame", "sensor_id")])) cli::cli_abort("Duplicate frame/sensor observations in long CSV.")
    frames <- sort(unique(df$frame))
    sensors <- if (is.null(layout)) sort(unique(df$sensor_id)) else layout$coords_mm$sensor_id
    if (!setequal(sensors, df$sensor_id)) cli::cli_abort("CSV sensor identifiers do not match the layout.")
    if (!is.numeric(df$pressure)) cli::cli_abort("Pressure must be numeric.")
    mat <- matrix(NA_real_, length(frames), length(sensors))
    mat[cbind(match(df$frame, frames), match(df$sensor_id, sensors))] <- df$pressure
    if (anyNA(mat)) cli::cli_abort("Incomplete frame/sensor grid; missing observations are not zero pressure.")
    t <- if (!is.null(time_col)) {
      vapply(frames, function(f) {
        v <- unique(df[[time_col]][df$frame == f])
        if (length(v) != 1L || !is.numeric(v)) cli::cli_abort("Each frame must have exactly one numeric timestamp.")
        v
      }, numeric(1))
    } else {
      NULL
    }
  }
  if (is.null(layout)) layout <- .layout_from_n_sensors(ncol(mat))
  if (is.null(layout)) cli::cli_abort("Could not infer layout for {ncol(mat)} sensors; pass {.arg layout}.")
  if (ncol(mat) != layout$n_sensors) cli::cli_abort("CSV has {ncol(mat)} columns but layout has {layout$n_sensors} sensors.")
  if (format == "long" || all(grepl("^s[0-9]+$", sensors))) {
    expected <- if (format == "long") layout$coords_mm$sensor_id else paste0("s", layout$coords_mm$sensor_id)
    if (!setequal(sensors, expected)) cli::cli_abort("CSV sensor identifiers do not match the supplied or inferred layout; pass the original layout explicitly.")
    mat <- mat[, match(expected, sensors), drop = FALSE]
  }
  if (is.null(t)) {
    .tp_check_scalar(sampling_hz, "sampling_hz")
    if (sampling_hz <= 0) cli::cli_abort("Sampling rate must be positive.")
    t <- seq(0, by = 1 / sampling_hz, length.out = nrow(mat))
  } else if (!rate_given) sampling_hz <- NULL
  dimnames(mat) <- NULL
  if (verbose) cli::cli_inform("Read {nrow(mat)} frame(s) from {.path {basename(path)}}.")
  pr_trial(mat, t, layout,
    metadata = c(list(trial_id = tools::file_path_sans_ext(basename(path))),
      .reader_source_metadata(path)),
    sampling_hz = sampling_hz
  )
}
