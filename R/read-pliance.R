# ---------------------------------------------------------------------------
# Ingest layer for Novel/Pliance ASCII exports and for whole directories of
# them.
#
# A Pliance `.asc` export is a latin-1, tab-delimited text file with a fixed
# seven-line header. Line 1 carries the source `.mat` name and the recording
# timestamp, line 3 the frame period and the sampling frequency, line 4 the
# pressure unit, and line 7 the column names (`Zeit [Sek.]` followed by one
# column per device channel). Data starts on line 8. Every data line ends in
# a trailing delimiter, so a naive reader sees one phantom all-empty column.
#
# The important subtlety is channel order. A device export is in *device
# channel* order, which for a multi-panel mat is not the grid order that
# `.layout_build_coords()`, `pr_mask()` and `pr_calc_cop()` all assume
# (column-major over `which(active)`). `pr_read_pliance()` therefore applies
# a single permutation - `pressure[, channel_order, drop = FALSE]` - and
# after it masks, COP, regional statistics and heatmaps are simultaneously
# correct. Get that permutation wrong and every one of them is wrong.
# ---------------------------------------------------------------------------

# Internal: read and re-encode the header block of a delimited export.
.pliance_header <- function(path, skip, encoding) {
  if (skip < 1L) return(character())
  lines <- readLines(path, n = skip, warn = FALSE)
  if (!identical(toupper(encoding), "UTF-8")) {
    conv <- iconv(lines, from = encoding, to = "UTF-8", sub = "?")
    lines[!is.na(conv)] <- conv[!is.na(conv)]
  }
  lines
}

# Internal: first capture group of `pattern` across a block of header lines.
.pliance_field <- function(lines, pattern) {
  for (ln in lines) {
    m <- regmatches(ln, regexec(pattern, ln, ignore.case = TRUE))[[1]]
    if (length(m) >= 2L && nzchar(trimws(m[2]))) return(trimws(m[2]))
  }
  NA_character_
}

# Internal: same, coerced to a positive number (NA when absent or <= 0).
.pliance_field_num <- function(lines, pattern) {
  v <- suppressWarnings(as.numeric(.pliance_field(lines, pattern)))
  if (length(v) != 1L || !is.finite(v) || v <= 0) return(NA_real_)
  v
}

# Internal: number of *named* columns on the column-header line. Used to
# discard the phantom column produced by the trailing delimiter without
# discarding a genuinely all-missing sensor channel.
.pliance_n_named <- function(header, skip, sep) {
  if (skip < 1L || length(header) < skip) return(NA_integer_)
  toks <- trimws(strsplit(header[[skip]], sep, fixed = TRUE)[[1]])
  n <- sum(nzchar(toks))
  if (n < 2L) return(NA_integer_)
  as.integer(n)
}

# Internal: normalise a channel map to a raw-to-grid column permutation.
#
# Accepts a grid-shaped matrix (entry = device channel at that grid cell,
# read column-major) or a plain integer permutation. Mirrors what
# `pr_channel_order()` returns for layouts that carry a map.
.pliance_channel_order <- function(channel_map, n_expected,
                                   arg = "channel_map") {
  ord <- as.vector(channel_map)
  if (!is.numeric(ord) || length(ord) == 0L) {
    cli::cli_abort(
      "{.arg {arg}} must be a numeric matrix or vector of device channels."
    )
  }
  if (anyNA(ord) || any(ord != round(ord))) {
    cli::cli_abort("{.arg {arg}} must contain whole, non-missing channel numbers.")
  }
  ord <- as.integer(ord)
  if (!setequal(ord, seq_along(ord))) {
    cli::cli_abort(c(
      "{.arg {arg}} must be a permutation of {.code 1:{length(ord)}}.",
      "x" = "It has {length(unique(ord))} distinct value{?s} in
             {.val {min(ord)}}-{.val {max(ord)}}."
    ))
  }
  if (length(ord) != n_expected) {
    cli::cli_abort(c(
      "{.arg {arg}} has {length(ord)} entr{?y/ies} but the file has
       {n_expected} sensor column{?s}.",
      "i" = "The map must name every device channel exactly once."
    ))
  }
  ord
}

# Internal: pick a layout when the caller supplied none.
#
# A 256-channel export is the two-panel Novel/Pliance saddle mat, whose
# layout carries its own channel map; fall back to the generic
# `n`-sensor layouts otherwise. Looked up by name so this file stays
# independent of which other file defines the layout.
.pliance_default_layout <- function(n) {
  if (identical(as.integer(n), 256L)) {
    fn <- tryCatch(match.fun("pr_layout_saddle_novel"), error = function(e) NULL)
    if (is.function(fn)) {
      lay <- tryCatch(fn(), error = function(e) NULL)
      if (inherits(lay, "pr_layout")) return(lay)
    }
  }
  .layout_from_n_sensors(n)
}

#' Split Metadata Fields Out of a File Name
#'
#' Many measurement archives encode a recording's design cells in its file
#' name, e.g. `ID052_K_K_KG00_MS.asc` for subject `ID052`, saddle `K`,
#' pad `K`, weight `KG00`, mode `MS`. This splits such a base name into a
#' one-row tibble of named fields.
#'
#' A name matches only when it splits into *exactly* `length(fields)`
#' non-empty parts. That strictness is the point: it is what lets a
#' directory read reject stray files (repeat takes such as
#' `ID003_K_K_KG60_MH_R01`, notes, exports) instead of silently mislabelling
#' them.
#'
#' @param path Character scalar. A file path or bare name. The directory and
#'   the extension are removed before splitting.
#' @param fields Character vector of output column names, in the order the
#'   parts appear in the name.
#' @param sep Character scalar. Literal separator between parts.
#'   Default `"_"`.
#' @param on_fail What to do when the name does not split into exactly
#'   `length(fields)` non-empty parts: `"skip"` (default) returns `NULL`,
#'   `"error"` throws, `"na"` returns a one-row tibble of `NA_character_`.
#'
#' @return A one-row tibble with one character column per entry of `fields`,
#'   or `NULL` (see `on_fail`).
#' @family Pliance ingest functions
#' @export
#' @examples
#' fields <- c("ID", "Saddle", "Pad", "Weight", "Mode")
#' pr_meta_from_filename("ID052_K_K_KG00_MS.asc", fields)
#'
#' # A repeat take carries a sixth part, so it does not match:
#' pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields)
#'
#' pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields, on_fail = "na")
pr_meta_from_filename <- function(path, fields, sep = "_",
                                  on_fail = c("skip", "error", "na")) {
  on_fail <- match.arg(on_fail)

  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort("{.arg path} must be a single, non-missing file name.")
  }
  if (!is.character(fields) || length(fields) == 0L || anyNA(fields) ||
      !all(nzchar(fields))) {
    cli::cli_abort("{.arg fields} must be a character vector of column names.")
  }
  if (anyDuplicated(fields) > 0L) {
    dup <- unique(fields[duplicated(fields)])
    cli::cli_abort("{.arg fields} must be unique; duplicated: {.val {dup}}.")
  }
  if (!is.character(sep) || length(sep) != 1L || !nzchar(sep)) {
    cli::cli_abort("{.arg sep} must be a single non-empty string.")
  }

  stem <- tools::file_path_sans_ext(basename(path))
  parts <- strsplit(stem, sep, fixed = TRUE)[[1]]
  parts <- trimws(parts)
  ok <- length(parts) == length(fields) && all(nzchar(parts))

  if (!ok) {
    if (identical(on_fail, "error")) {
      cli::cli_abort(c(
        "{.val {stem}} does not split into {length(fields)} field{?s} on
         {.val {sep}}.",
        "x" = "Got {length(parts)} part{?s}: {.val {parts}}.",
        "i" = "Expected field{?s}: {.val {fields}}."
      ))
    }
    if (identical(on_fail, "skip")) return(NULL)
    parts <- rep(NA_character_, length(fields))
  }

  out <- as.list(as.character(parts))
  names(out) <- fields
  tibble::as_tibble(out)
}

#' Read a Novel/Pliance ASCII Export
#'
#' Reads one Novel/Pliance `.asc` pressure export into a [pr_trial]. The
#' recorded time column is used as-is rather than a synthesised sequence, so
#' a trial whose frames were dropped keeps honest timestamps.
#'
#' @section Channel order:
#' A device export lists columns in *device channel* order. Every other
#' `pressR` function - [pr_mask()], [pr_calc_cop()], the heatmaps - indexes
#' pressure columns in column-major grid order, the order
#' `which(layout$active)` produces. For a single-panel device the two agree;
#' for a multi-panel mat they do not. Supplying `channel_map` (or a layout
#' that carries one, such as `pr_layout_saddle_novel()`) applies the single
#' permutation `pressure[, order, drop = FALSE]` that reconciles them.
#'
#' `channel_map` may be a grid-shaped matrix whose entry at `[row, col]` is
#' the device channel sitting at that grid cell, or the equivalent bare
#' integer permutation. When `channel_map` is `NULL` and `layout` carries a
#' `channel_order`, that order is used; otherwise the columns are left in
#' device order.
#'
#' @section Missing values:
#' Pliance writes an unread cell as the literal token `___`. With
#' `on_na = "drop_frame"` (the default) any frame containing one is removed
#' whole, which is what keeps per-frame statistics comparable across a
#' recording; `on_na = "zero"` keeps the frame and reads the cell as `0`.
#' A frame whose *timestamp* is missing is always dropped, since it cannot be
#' placed on the time axis. The counts land in
#' `metadata$n_frames_raw` and `metadata$n_frames_dropped`.
#'
#' @param path Character scalar. Path to the `.asc` export.
#' @param layout A [pr_layout] object. `NULL` (default) picks a layout from
#'   the channel count.
#' @param skip Integer. Header lines before the first data line. Default
#'   `7L`, the Pliance export format.
#' @param sep Character scalar. Literal column delimiter. Default `"\t"`.
#' @param time_col Integer. Position of the timestamp column, default `1L`.
#'   `NULL` synthesises time from `sampling_hz` instead.
#' @param channel_map Device-channel map: a grid-shaped matrix, a bare
#'   integer permutation, or `NULL` (default). See *Channel order*.
#' @param na_strings Character vector of tokens read as missing. Default
#'   `c("", "NA", "___")`.
#' @param encoding Character. File encoding, default `"latin1"`.
#' @param on_na `"drop_frame"` (default) or `"zero"`. See *Missing values*.
#' @param sampling_hz Numeric. Overrides the rate recorded in the header.
#'   `NULL` (default) uses the header, or the timestamps when the header is
#'   silent.
#' @param metadata Named list merged over the parsed metadata, so callers can
#'   override any field.
#'
#' @return A [pr_trial] object.
#' @family Pliance ingest functions
#' @export
#' @examples
#' # A miniature export in the Pliance layout: 7 header lines, then data.
#' tmp <- tempfile(fileext = ".asc")
#' writeLines(c(
#'   "Dateiname:  demo.mat\tDatum/Zeit: 01.01.25 09.00",
#'   "Kalibrationsdatei:  demo_cal",
#'   "gesamte Messzeit [Sek.]: 0.040\tZeit pro Bild [Sek.]:  0.02000\tMessfrequenz [Hz]:   50",
#'   "Druckwerte in  kPa",
#'   "",
#'   "elektrisch:",
#'   "Zeit [Sek.]\t1\t2\t3\t4",
#'   "0.02000\t10\t0\t0\t0",
#'   "0.04000\t0\t20\t0\t0"
#' ), tmp)
#'
#' lay <- pr_layout(
#'   2, 2, matrix(TRUE, 2, 2),
#'   data.frame(sensor_id = 1:4, row = c(1L, 2L, 1L, 2L),
#'              col = c(1L, 1L, 2L, 2L),
#'              x_mm = c(0, 0, 1, 1), y_mm = c(0, 1, 0, 1))
#' )
#'
#' # Device channel 1 sits at grid (row 1, col 2), channel 2 at (1, 1).
#' cmap <- rbind(c(2L, 1L), c(4L, 3L))
#' trial <- pr_read_pliance(tmp, layout = lay, channel_map = cmap)
#' trial$time
#' trial$pressure
#' unlink(tmp)
pr_read_pliance <- function(path, layout = NULL, skip = 7L, sep = "\t",
                            time_col = 1L, channel_map = NULL,
                            na_strings = c("", "NA", "___"),
                            encoding = "latin1",
                            on_na = c("drop_frame", "zero"),
                            sampling_hz = NULL, metadata = list()) {
  on_na <- match.arg(on_na)

  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}.")
  }
  if (!is.numeric(skip) || length(skip) != 1L || is.na(skip) || skip < 0) {
    cli::cli_abort("{.arg skip} must be a single non-negative integer.")
  }
  skip <- as.integer(skip)
  if (!is.character(sep) || length(sep) != 1L || !nzchar(sep)) {
    cli::cli_abort("{.arg sep} must be a single non-empty string.")
  }
  if (!is.character(encoding) || length(encoding) != 1L) {
    cli::cli_abort("{.arg encoding} must be a single string.")
  }
  if (!is.null(layout)) .validate_layout(layout)
  if (!is.list(metadata)) {
    cli::cli_abort("{.arg metadata} must be a named list.")
  }
  if (!is.null(sampling_hz) &&
      (!is.numeric(sampling_hz) || length(sampling_hz) != 1L ||
       !is.finite(sampling_hz) || sampling_hz <= 0)) {
    cli::cli_abort("{.arg sampling_hz} must be a single positive number.")
  }

  header <- .pliance_header(path, skip, encoding)

  hz_header    <- .pliance_field_num(header, "\\[[[:space:]]*Hz[[:space:]]*\\][^0-9-]*([0-9]+(?:\\.[0-9]+)?)")
  frame_period <- .pliance_field_num(header, "Zeit pro Bild[^0-9-]*([0-9]+(?:\\.[0-9]+)?)")
  unit         <- .pliance_field(header, "Druckwerte in[[:space:]]+([^[:space:]]+)")
  date_str     <- .pliance_field(header, "Datum/Zeit:[[:space:]]*(.+?)[[:space:]]*$")
  source_name  <- .pliance_field(header, "Dateiname:[[:space:]]*([^[:space:]]+)")
  calibration  <- .pliance_field(header, "Kalibrationsdatei:[[:space:]]*([^[:space:]]+)")

  dat <- readr::read_delim(
    file = path,
    delim = sep,
    skip = skip,
    col_names = FALSE,
    na = na_strings,
    trim_ws = TRUE,
    locale = readr::locale(encoding = encoding),
    col_types = readr::cols(.default = readr::col_double()),
    progress = FALSE
  )

  if (nrow(dat) == 0L || ncol(dat) == 0L) {
    cli::cli_abort(c(
      "No data rows found in {.path {basename(path)}}.",
      "i" = "{.arg skip} is {skip}; is the header really that long?"
    ))
  }

  # Discard the phantom column created by a trailing delimiter, but only
  # when the column-header line agrees it is not a real channel.
  n_named <- .pliance_n_named(header, skip, sep)
  if (!is.na(n_named) && ncol(dat) > n_named) {
    extra <- seq.int(n_named + 1L, ncol(dat))
    if (all(vapply(extra, function(j) all(is.na(dat[[j]])), logical(1)))) {
      dat <- dat[, seq_len(n_named), drop = FALSE]
    }
  }

  n_col <- ncol(dat)
  if (!is.null(time_col)) {
    if (!is.numeric(time_col) || length(time_col) != 1L || is.na(time_col) ||
        time_col < 1 || time_col > n_col) {
      cli::cli_abort(
        "{.arg time_col} must be a column position in {.code 1:{n_col}}."
      )
    }
    time_col <- as.integer(time_col)
    time_raw <- as.numeric(dat[[time_col]])
    press <- as.matrix(dat[, -time_col, drop = FALSE])
  } else {
    time_raw <- rep(NA_real_, nrow(dat))
    press <- as.matrix(dat)
  }
  storage.mode(press) <- "double"
  dimnames(press) <- NULL

  if (ncol(press) == 0L) {
    cli::cli_abort("{.path {basename(path)}} has no sensor columns.")
  }

  n_frames_raw <- nrow(press)

  # ---- missing values -----------------------------------------------------
  if (identical(on_na, "zero")) {
    press[is.na(press)] <- 0
    keep <- if (is.null(time_col)) rep(TRUE, n_frames_raw) else !is.na(time_raw)
  } else {
    keep <- !apply(is.na(press), 1L, any)
    if (!is.null(time_col)) keep <- keep & !is.na(time_raw)
  }
  n_dropped <- sum(!keep)
  if (n_dropped > 0L) {
    if (!any(keep)) {
      cli::cli_abort(
        "Every frame in {.path {basename(path)}} contains a missing value."
      )
    }
    cli::cli_warn(
      "Dropped {n_dropped} of {n_frames_raw} frame{?s} containing missing
       values in {.path {basename(path)}}."
    )
    press <- press[keep, , drop = FALSE]
    time_raw <- time_raw[keep]
  }

  # ---- layout -------------------------------------------------------------
  if (is.null(layout)) {
    layout <- .pliance_default_layout(ncol(press))
    if (is.null(layout)) {
      cli::cli_abort(c(
        "No built-in layout has {ncol(press)} sensor{?s}.",
        "i" = "Pass {.arg layout} explicitly."
      ))
    }
  }
  if (ncol(press) != layout$n_sensors) {
    cli::cli_abort(c(
      "{.path {basename(path)}} has {ncol(press)} sensor column{?s} but layout
       {.val {layout$name}} has {layout$n_sensors} active sensor{?s}.",
      "i" = "The file has {n_col} column{?s} in total with {.arg skip} =
             {skip} and {.arg time_col} =
             {if (is.null(time_col)) 'NULL' else time_col}.",
      "i" = "Pass a matching {.arg layout}, or adjust {.arg skip}/{.arg sep}."
    ))
  }

  # ---- channel order ------------------------------------------------------
  order_src <- "device"
  if (is.null(channel_map) && !is.null(layout) &&
      !is.null(layout$channel_order)) {
    channel_map <- layout$channel_order
    order_src <- "layout"
  } else if (!is.null(channel_map)) {
    order_src <- "channel_map"
  }
  if (!is.null(channel_map)) {
    arg <- if (identical(order_src, "layout")) "layout$channel_order"
           else "channel_map"
    if (is.matrix(channel_map) && !is.null(layout) &&
        !identical(dim(channel_map),
                   c(layout$grid_rows, layout$grid_cols))) {
      cli::cli_abort(c(
        "{.arg {arg}} is {nrow(channel_map)}x{ncol(channel_map)} but layout
         {.val {layout$name}} is a {layout$grid_rows}x{layout$grid_cols} grid.",
        "i" = "A matrix map must have one entry per grid cell."
      ))
    }
    ord <- .pliance_channel_order(channel_map, ncol(press), arg)
    press <- press[, ord, drop = FALSE]
  }

  # ---- time and rate ------------------------------------------------------
  if (is.null(sampling_hz) && is.finite(hz_header)) sampling_hz <- hz_header
  if (is.null(time_col)) {
    step <- if (!is.null(sampling_hz)) 1 / sampling_hz else
            if (is.finite(frame_period)) frame_period else NULL
    if (is.null(step)) {
      cli::cli_abort(c(
        "{.arg time_col} is {.code NULL} and no sampling rate is available.",
        "i" = "Pass {.arg sampling_hz}, or point {.arg time_col} at the
               recorded timestamps."
      ))
    }
    time_raw <- seq(from = step, by = step, length.out = nrow(press))
  }

  # ---- metadata -----------------------------------------------------------
  meta <- list(
    subject_id = NA_character_,
    trial_id = tools::file_path_sans_ext(basename(path)),
    date = date_str,
    condition = NA_character_,
    system = if (nzchar(layout$manufacturer)) layout$manufacturer else "Pliance",
    notes = sprintf("Imported from %s", basename(path)),
    source_file = path,
    source_name = source_name,
    calibration = calibration,
    pressure_unit = unit,
    sampling_hz_header = hz_header,
    frame_period_s = frame_period,
    n_frames_raw = n_frames_raw,
    n_frames_dropped = as.integer(n_dropped),
    channel_order_from = order_src
  )
  for (nm in names(metadata)) meta[[nm]] <- metadata[[nm]]

  pr_trial(
    pressure = press,
    time = time_raw,
    layout = layout,
    metadata = meta,
    sampling_hz = sampling_hz
  )
}

#' Read a Directory of Pressure Exports
#'
#' Walks a directory, reads every matching file with `reader`, and collects
#' the results into a [pr_dataset]. Files that cannot be read - or whose
#' names do not match `meta_fields` - are reported and skipped rather than
#' aborting the whole batch.
#'
#' When `meta_fields` is supplied, each file name is split with
#' [pr_meta_from_filename()] and the parts are stored in the trial's
#' metadata under those names. The first part additionally fills
#' `subject_id` and the remaining parts, rejoined with `sep`, fill
#' `condition` - the field [pr_dataset()] groups by - unless the reader
#' already set them. A name that does not split into exactly
#' `length(meta_fields)` parts is skipped, which is the intended way to
#' exclude repeat takes and stray exports from a cohort.
#'
#' @param dir Character scalar. Directory to walk.
#' @param pattern Regular expression matching file names to read. Default
#'   `"\\.asc$"`.
#' @param reader Function called as `reader(path, layout = layout, ...)`.
#'   Default [pr_read_pliance()].
#' @param layout A [pr_layout] passed to `reader`. Default `NULL`.
#' @param meta_fields Character vector of file-name fields, or `NULL`
#'   (default) to read every matching file and parse no names.
#' @param recursive Logical. Descend into sub-directories. Default `TRUE`.
#' @param on_error `"skip"` (default) records a failure and continues;
#'   `"abort"` re-throws the first one.
#' @param quiet Logical. Suppress the progress and summary messages and the
#'   readers' warnings. Default `FALSE`.
#' @param ... Further arguments passed to `reader`.
#' @param sep Character scalar. Separator passed to
#'   [pr_meta_from_filename()]. Default `"_"`.
#' @param name Character scalar. Dataset name. `NULL` (default) uses the
#'   directory's base name.
#'
#' @return A [pr_dataset]. Attribute `"read_report"` holds a tibble with one
#'   row per candidate file (`file`, `path`, `status`, `reason`).
#' @family Pliance ingest functions
#' @export
#' @examples
#' dir <- tempfile()
#' dir.create(dir)
#' hdr <- c(
#'   "Dateiname:  demo.mat\tDatum/Zeit: 01.01.25 09.00",
#'   "Kalibrationsdatei:  demo_cal",
#'   "gesamte Messzeit [Sek.]: 0.040\tZeit pro Bild [Sek.]:  0.02000\tMessfrequenz [Hz]:   50",
#'   "Druckwerte in  kPa", "", "elektrisch:",
#'   "Zeit [Sek.]\t1\t2\t3\t4",
#'   "0.02000\t10\t0\t0\t0",
#'   "0.04000\t0\t20\t0\t0"
#' )
#' writeLines(hdr, file.path(dir, "ID001_K_KG00.asc"))
#' writeLines(hdr, file.path(dir, "ID002_K_KG40.asc"))
#' writeLines(hdr, file.path(dir, "ID002_K_KG40_R01.asc"))  # repeat take
#'
#' lay <- pr_layout(
#'   2, 2, matrix(TRUE, 2, 2),
#'   data.frame(sensor_id = 1:4, row = c(1L, 2L, 1L, 2L),
#'              col = c(1L, 1L, 2L, 2L),
#'              x_mm = c(0, 0, 1, 1), y_mm = c(0, 1, 0, 1))
#' )
#' ds <- pr_read_dir(dir, layout = lay,
#'                   meta_fields = c("ID", "Saddle", "Weight"), quiet = TRUE)
#' length(ds)
#' attr(ds, "read_report")$status
#' unlink(dir, recursive = TRUE)
pr_read_dir <- function(dir, pattern = "\\.asc$", reader = pr_read_pliance,
                        layout = NULL, meta_fields = NULL, recursive = TRUE,
                        on_error = c("skip", "abort"), quiet = FALSE, ...,
                        sep = "_", name = NULL) {
  on_error <- match.arg(on_error)

  if (!is.character(dir) || length(dir) != 1L || is.na(dir)) {
    cli::cli_abort("{.arg dir} must be a single directory path.")
  }
  if (!dir.exists(dir)) {
    cli::cli_abort("Directory not found: {.path {dir}}.")
  }
  if (!is.function(reader)) {
    cli::cli_abort("{.arg reader} must be a function.")
  }
  if (!is.null(meta_fields) &&
      (!is.character(meta_fields) || length(meta_fields) == 0L)) {
    cli::cli_abort("{.arg meta_fields} must be a character vector or NULL.")
  }
  if (!is.logical(quiet) || length(quiet) != 1L || is.na(quiet)) {
    cli::cli_abort("{.arg quiet} must be {.code TRUE} or {.code FALSE}.")
  }
  if (!is.null(layout)) .validate_layout(layout)

  paths <- sort(list.files(dir, pattern = pattern, full.names = TRUE,
                           recursive = recursive))
  paths <- paths[!dir.exists(paths)]
  if (length(paths) == 0L) {
    cli::cli_warn(
      "No files matching {.val {pattern}} found in {.path {dir}}."
    )
  }

  trials <- vector("list", length(paths))
  status <- character(length(paths))
  reason <- rep(NA_character_, length(paths))

  for (i in seq_along(paths)) {
    p <- paths[[i]]
    fields <- NULL

    if (!is.null(meta_fields)) {
      fields <- pr_meta_from_filename(p, meta_fields, sep = sep,
                                      on_fail = "skip")
      if (is.null(fields)) {
        status[i] <- "skipped"
        reason[i] <- sprintf("name does not split into %d field(s) on '%s'",
                             length(meta_fields), sep)
        next
      }
    }

    tr <- tryCatch(
      if (quiet) {
        suppressWarnings(reader(p, layout = layout, ...))
      } else {
        reader(p, layout = layout, ...)
      },
      error = function(e) e
    )

    if (inherits(tr, "error")) {
      if (identical(on_error, "abort")) {
        cli::cli_abort(
          "Failed to read {.path {basename(p)}}.",
          parent = tr
        )
      }
      status[i] <- "skipped"
      reason[i] <- conditionMessage(tr)
      next
    }
    if (!inherits(tr, "pr_trial")) {
      if (identical(on_error, "abort")) {
        cli::cli_abort(
          "{.arg reader} returned a {.cls {class(tr)[1]}} for
           {.path {basename(p)}}, not a {.cls pr_trial}."
        )
      }
      status[i] <- "skipped"
      reason[i] <- sprintf("reader returned a %s, not a pr_trial",
                           class(tr)[1])
      next
    }

    if (!is.null(fields)) {
      vals <- as.character(unlist(fields, use.names = FALSE))
      for (j in seq_along(meta_fields)) tr$metadata[[meta_fields[j]]] <- vals[j]
      if (is.null(tr$metadata$subject_id) || is.na(tr$metadata$subject_id)) {
        tr$metadata$subject_id <- vals[1]
      }
      if ((is.null(tr$metadata$condition) || is.na(tr$metadata$condition)) &&
          length(vals) > 1L) {
        tr$metadata$condition <- paste(vals[-1], collapse = sep)
      }
    }

    trials[[i]] <- tr
    status[i] <- "ok"
  }

  ok <- status == "ok"
  n_ok <- sum(ok)
  n_skip <- sum(!ok)

  if (!quiet) {
    cli::cli_inform(c(
      "v" = "Read {n_ok} file{?s} from {.path {dir}}.",
      if (n_skip > 0L) c("!" = "Skipped {n_skip} file{?s}.") else NULL
    ))
  }
  if (n_skip > 0L && n_ok == 0L && length(paths) > 0L) {
    cli::cli_warn(
      "No file in {.path {dir}} could be read; see the
       {.field read_report} attribute."
    )
  }

  ds <- pr_dataset(
    trials[ok],
    group_var = "condition",
    name = name %||% basename(normalizePath(dir, mustWork = FALSE))
  )
  attr(ds, "read_report") <- tibble::tibble(
    file = basename(paths),
    path = paths,
    status = status,
    reason = reason
  )
  ds
}
