# ---------------------------------------------------------------------------
# ASCII parser for tab/space-delimited pressure data exports.
# ---------------------------------------------------------------------------

# Internal: extract a single value from a header line matching a key.
.header_value <- function(lines, key) {
  pat <- sprintf("^%s[[:space:]]*:[[:space:]]*(.+)$", key)
  for (ln in lines) {
    m <- regmatches(ln, regexec(pat, ln, ignore.case = TRUE))
    if (length(m[[1]]) >= 2) {
      return(trimws(m[[1]][2]))
    }
  }
  NA_character_
}

# Internal: detect the first numeric-data line.
.detect_data_start <- function(lines, sep_char) {
  for (i in seq_along(lines)) {
    ln <- trimws(lines[i])
    if (!nzchar(ln)) next
    parts <- strsplit(ln, sep_char, fixed = FALSE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) < 5L) next
    nums <- suppressWarnings(as.numeric(parts))
    if (sum(!is.na(nums)) / length(nums) > 0.8) {
      return(i)
    }
  }
  NA_integer_
}

#' Read ASCII Pressure Data Export
#'
#' Parses ASCII data files containing pressure sensor data. Automatically
#' detects header format and extracts metadata, the pressure matrix, and
#' timing.
#'
#' @inheritSection pr_read_csv Numeric text
#'
#' @param path Character. Path to the ASCII file (`.asc`, `.txt`).
#' @param layout A [pr_layout] object. If `NULL`, inferred from the
#'   header or sensor count.
#' @param sampling_hz Numeric. Sampling rate (Hz). If `NULL`, taken from
#'   the header or defaulted to 50.
#' @param separator Character. Column separator. `"auto"` (default)
#'   detects tab/space/comma/semicolon.
#' @param skip Integer. Header lines to skip. If `NULL`, auto-detected.
#' @param verbose Logical. Default `TRUE`.
#'
#' @return A [pr_trial] object.
#' @export
#' @examples
#' path <- pr_example_files("insole")
#' trial <- pr_read_ascii(path, verbose = FALSE)
#' trial$n_frames
pr_read_ascii <- function(path, layout = NULL, sampling_hz = NULL,
                          separator = "auto", skip = NULL,
                          verbose = TRUE) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}.")
  }
  if (.is_pliance(path)) {
    return(pr_read_pliance(path, layout = layout, sampling_hz = sampling_hz))
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (any(!validUTF8(lines))) lines <- iconv(lines, from = "latin1", to = "UTF-8")
  if (length(lines) == 0L) {
    cli::cli_abort("File {.path {path}} is empty.")
  }

  # Determine separator
  sep_regex <- if (identical(separator, "auto")) {
    "[[:space:],;]+"
  } else {
    separator
  }

  # Detect skip
  if (is.null(skip)) {
    skip <- .detect_data_start(lines, sep_regex)
    if (is.na(skip)) {
      cli::cli_abort("Could not auto-detect the start of numeric data in {.path {path}}.")
    }
    skip <- skip - 1L
  }

  header_lines <- lines[seq_len(skip)]

  # Metadata
  sys_label <- .header_value(header_lines, "System")
  subject <- .header_value(header_lines, "Patient")
  date_str <- .header_value(header_lines, "Date")
  size_str <- .header_value(header_lines, "Insole Size")
  hz_str <- .header_value(header_lines, "Sampling Rate")
  n_sens_str <- .header_value(header_lines, "Sensors")

  if (is.null(sampling_hz) && !is.na(hz_str)) {
    hz_num <- suppressWarnings(as.numeric(gsub("[^0-9.]", "", hz_str)))
    if (is.finite(hz_num) && hz_num > 0) sampling_hz <- hz_num
  }
  if (is.null(sampling_hz)) sampling_hz <- 50

  # Parse data
  data_text <- lines[(skip + 1L):length(lines)]
  data_text <- data_text[nzchar(trimws(data_text))]
  split <- strsplit(data_text, sep_regex)
  split <- lapply(split, function(x) x[nzchar(x)])
  ncols <- vapply(split, length, integer(1))
  if (length(unique(ncols)) > 1L) {
    cli::cli_abort("Inconsistent row widths in ASCII data; no padding or truncation is performed.")
  }
  invisible(lapply(split, .check_decimal_tokens))
  mat <- suppressWarnings(do.call(
    rbind,
    lapply(split, function(x) as.numeric(x))
  ))
  if (any(!is.finite(mat))) cli::cli_abort("ASCII data contain missing or non-numeric measurements.")

  n_sensors <- ncol(mat)
  n_frames <- nrow(mat)

  if (is.null(layout)) {
    if (!is.na(sys_label)) {
      # Use system label to infer
      layout <- switch(tolower(sys_label),
        insole = pr_layout_insole(),
        platform = pr_layout_platform("st"),
        mat = .layout_from_n_sensors(n_sensors) %||% pr_layout_mat("16"),
        .layout_from_n_sensors(n_sensors)
      )
    }
    if (is.null(layout)) layout <- .layout_from_n_sensors(n_sensors)
    if (is.null(layout)) {
      cli::cli_abort(
        paste0(
          "Could not infer layout for {n_sensors}-sensor data. ",
          "Please pass {.arg layout} explicitly."
        )
      )
    }
  }

  if (ncol(mat) != layout$n_sensors) {
    cli::cli_abort("Pressure matrix has {ncol(mat)} columns but layout has {layout$n_sensors}; supply the correct layout.")
  }

  t <- seq(0, by = 1 / sampling_hz, length.out = n_frames)

  metadata <- list(
    subject_id = subject %||% NA_character_,
    trial_id = tools::file_path_sans_ext(basename(path)),
    date = date_str %||% NA_character_,
    condition = NA_character_,
    system = sys_label %||% layout$model,
    notes = sprintf("Imported from %s", basename(path))
  )
  metadata <- c(metadata, .reader_source_metadata(path))

  if (verbose) {
    cli::cli_inform(
      "Read {n_frames} frame(s) with {layout$n_sensors} sensor(s)
       from {.path {basename(path)}} at {sampling_hz} Hz."
    )
  }

  pr_trial(
    pressure = mat, time = t, layout = layout,
    metadata = metadata, sampling_hz = sampling_hz
  )
}
