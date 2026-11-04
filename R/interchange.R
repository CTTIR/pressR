#' Export a Versioned Trial Bundle
#'
#' Writes a version 2 bundle with pressure.csv for inspection, measurements.rds
#' for exact numeric preservation, typed metadata.rds, and a JSON manifest with
#' SHA-256 checksums. Metadata preserves the complete layout and factor levels.
#' The destination must not already exist. Checksums detect corruption; they do
#' not authenticate a sender. Only read bundles from trusted sources, because
#' they contain serialized R objects.
#' The RDS measurements are authoritative. The CSV is a nonbinding preview;
#' reading verifies its checksum, columns and frame identifiers, but does not
#' use its decimal measurements. Recreate the bundle to change its contents.
#' @param trial A [pr_trial] object.
#' @param path New bundle directory.
#' @return Invisibly the bundle directory.
#' @export
pr_write_bundle <- function(trial, path) {
  .validate_trial(trial)
  .validate_output_path(path, new = TRUE)
  stage <- tempfile(".pressr-", tmpdir = dirname(path))
  if (!dir.create(stage)) cli::cli_abort("Could not create bundle staging directory.")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  pr_export_csv(trial, file.path(stage, "pressure.csv"), what = "pressure")
  meta <- trial[setdiff(names(trial), c("pressure", "time"))]
  saveRDS(meta, file.path(stage, "metadata.rds"), version = 3)
  saveRDS(list(pressure = trial$pressure, time = trial$time),
    file.path(stage, "measurements.rds"), version = 3)
  files <- c("pressure.csv", "metadata.rds", "measurements.rds")
  hashes <- stats::setNames(vapply(file.path(stage, files), digest::digest, character(1), algo = "sha256", file = TRUE), files)
  manifest <- list(
    schema = "pressR-trial", version = 2L, package_version = as.character(utils::packageVersion("pressR")),
    frames = trial$n_frames, sensors = trial$n_sensors,
    measurement_unit = .measurement_unit(trial), coordinate_unit = .coordinate_unit(trial$layout),
    sensor_ids = trial$layout$coords_mm$sensor_id, sha256 = as.list(hashes)
  )
  jsonlite::write_json(manifest, file.path(stage, "manifest.json"), auto_unbox = TRUE, pretty = TRUE)
  .validate_output_path(path, new = TRUE)
  if (!.rename_output(stage, path)) cli::cli_abort("Could not finalize bundle: {.path {path}}.")
  invisible(path)
}

#' Read a Verified Trial Bundle
#'
#' Only use bundles from trusted sources: the checksums establish integrity, not
#' authenticity, and the metadata and measurements contain serialized R objects.
#' Version 2 preserves measurements exactly. Legacy version 1 bundles remain
#' readable, but their decimal CSV cannot guarantee exact numeric/reference replay.
#' Version 2 uses authoritative RDS measurements; the CSV is a nonbinding preview
#' checked for integrity and structure, not used as a second measurement source.
#' @param path Bundle directory written by [pr_write_bundle()].
#' @return A validated [pr_trial] object.
#' @export
pr_read_bundle <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("Bundle path must be one nonempty character string.")
  }
  mf <- file.path(path, "manifest.json")
  if (!file.exists(mf)) cli::cli_abort("Bundle manifest is missing.")
  if (.is_output_link(mf) || !isTRUE(fs::is_file(mf))) cli::cli_abort("Bundle manifest must be a regular file.")
  m <- jsonlite::read_json(mf, simplifyVector = TRUE)
  if (!is.list(m) || anyDuplicated(names(m)) ||
    !all(c("schema", "version") %in% names(m)) || !identical(m$schema, "pressR-trial") ||
    !any(vapply(list(1L, 2L), identical, logical(1), m$version))) {
    cli::cli_abort("Unsupported bundle schema or version.")
  }
  count <- function(x, minimum = 1) is.numeric(x) && length(x) == 1L &&
    !is.na(x) && is.finite(x) && x >= minimum && x == floor(x)
  text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (!all(c("frames", "sensors", "measurement_unit", "coordinate_unit", "sensor_ids", "sha256") %in% names(m)) ||
    !count(m$frames, 0) || !count(m$sensors) || !text(m$measurement_unit) ||
    !text(m$coordinate_unit) || !is.numeric(m$sensor_ids) ||
    length(m$sensor_ids) != m$sensors || anyNA(m$sensor_ids) ||
    any(!is.finite(m$sensor_ids)) || anyDuplicated(m$sensor_ids)) {
    cli::cli_abort("Bundle manifest has invalid dimensions, units or sensor identifiers.")
  }
  files <- c("pressure.csv", "metadata.rds", if (m$version == 2L) "measurements.rds")
  if (!is.list(m$sha256) || anyDuplicated(names(m$sha256)) ||
    !setequal(names(m$sha256), files) ||
    !all(vapply(m$sha256, function(x) text(x) && grepl("^[a-f0-9]{64}$", x), logical(1)))) {
    cli::cli_abort("Bundle manifest has invalid checksums.")
  }
  for (name in files) {
    f <- file.path(path, name)
    if (!file.exists(f) || .is_output_link(f) || !isTRUE(fs::is_file(f)) ||
      !identical(digest::digest(f, algo = "sha256", file = TRUE), m$sha256[[name]])) {
      cli::cli_abort("Bundle checksum mismatch for {.val {name}}.")
    }
  }
  meta <- readRDS(file.path(path, "metadata.rds"))
  if (!is.list(meta) || !all(c("layout", "metadata", "sampling_hz") %in% names(meta))) {
    cli::cli_abort("Bundle metadata is incomplete.")
  }
  pr_validate_layout(meta$layout)
  csv_path <- file.path(path, "pressure.csv")
  cols <- paste0("s", meta$layout$coords_mm$sensor_id)
  df <- readr::read_csv(csv_path,
    col_types = readr::cols(.default = readr::col_character()), progress = FALSE)
  if (nrow(readr::problems(df))) cli::cli_abort("Malformed bundle pressure CSV.")
  if (!identical(names(df), c("frame", "time", cols)) || nrow(df) != m$frames ||
    !identical(df$frame, as.character(seq_len(nrow(df))))) {
    cli::cli_abort("Bundle columns or frame identifiers are inconsistent.")
  }
  # Decimal CSV remains readable for version 1; new bundles use exact R values.
  if (m$version == 2L) {
    values <- readRDS(file.path(path, "measurements.rds"))
    if (!is.list(values) || !identical(names(values), c("pressure", "time"))) {
      cli::cli_abort("Bundle measurements are incomplete.")
    }
    p <- values$pressure
    time <- values$time
  } else {
    df <- .read_measurement_delim(csv_path,
      col_types = readr::cols(.default = readr::col_double()))
    if (nrow(readr::problems(df))) cli::cli_abort("Malformed bundle pressure CSV.")
    p <- as.matrix(df[cols])
    dimnames(p) <- NULL
    time <- df$time
  }
  # Restore the stored contract, including an explicitly unknown nominal rate.
  # Reconstructing through pr_trial() would infer or replace stored metadata.
  out <- structure(c(list(pressure = p, time = time), unclass(meta)), class = "pr_trial")
  .validate_trial(out)
  if (!identical(as.numeric(m$sensor_ids), as.numeric(out$layout$coords_mm$sensor_id)) ||
    out$n_frames != m$frames || out$n_sensors != m$sensors ||
    !identical(.measurement_unit(out), m$measurement_unit) ||
    !identical(.coordinate_unit(out$layout), m$coordinate_unit)) {
    cli::cli_abort("Bundle manifest disagrees with its contents.")
  }
  out
}

.is_output_link <- function(path) {
  isTRUE(fs::is_link(path))
}

.validate_output_path <- function(path, new = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("Output path must be one nonempty character string.")
  }
  if (.is_output_link(path)) cli::cli_abort("Output destination must not be a symbolic link.")
  if (new && file.exists(path)) cli::cli_abort("Output destination already exists: {.path {path}}.")
  if (dir.exists(path)) cli::cli_abort("Output destination is a directory.")
  if (file.exists(path) && !isTRUE(fs::is_file(path))) cli::cli_abort("Output destination must be a regular file.")
  if (!dir.exists(dirname(path))) cli::cli_abort("Output parent directory does not exist: {.path {dirname(path)}}.")
  invisible(path)
}

.rename_output <- function(from, to) file.rename(from, to)

.atomic_output <- function(path, writer) {
  .validate_output_path(path)
  tmp <- tempfile(".pressr-", tmpdir = dirname(path), fileext = paste0(".", tools::file_ext(path)))
  on.exit(unlink(tmp), add = TRUE)
  writer(tmp)
  if (!file.exists(tmp) || dir.exists(tmp) || .is_output_link(tmp)) cli::cli_abort("Could not finalize output: writer did not produce a file.")
  if (!isTRUE(file.info(tmp)$size > 0)) cli::cli_abort("Could not finalize output: writer produced an empty file.")
  .validate_output_path(path)
  backup <- NULL
  if (file.exists(path)) {
    backup <- tempfile(".pressr-backup-", tmpdir = dirname(path))
    if (!.rename_output(path, backup)) cli::cli_abort("Could not preserve the existing output: {.path {path}}.")
  }
  promoted <- tryCatch(.rename_output(tmp, path), error = function(e) FALSE)
  if (!isTRUE(promoted)) {
    if (!is.null(backup) && !isTRUE(tryCatch(.rename_output(backup, path), error = function(e) FALSE))) {
      cli::cli_abort("Could not finalize output. The original is preserved at {.path {backup}}.")
    }
    cli::cli_abort("Could not finalize output: {.path {path}}.")
  }
  if (!is.null(backup)) unlink(backup)
  invisible(path)
}
