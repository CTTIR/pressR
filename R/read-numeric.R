# Bound text conversion to the range qualified for the tabular readers.
# This is not an exact decimal parser: binary bundles preserve exact doubles.
.check_decimal_tokens <- function(x, trim = TRUE) {
  token <- if (trim) trimws(x) else x
  decimal <- !is.na(token) & grepl(
    "^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$", token)
  value <- rep(NA_real_, length(token))
  value[decimal] <- suppressWarnings(as.numeric(token[decimal]))
  outside <- decimal & (!is.finite(value) | abs(value) < 1e-290 | abs(value) > 1e290)
  # Only zero/out-of-range conversions need a mantissa check to distinguish
  # literal zero from underflow. All other numeric tokens still get compared.
  unsafe <- any(outside) && any(grepl("[1-9]", sub("[eE].*$", "", token[outside])))
  if (unsafe) {
    cli::cli_abort(paste0("Numeric text is outside the supported finite decimal range ",
      "[1e-290, 1e290] in absolute value (zero is supported). ",
      "Rescale acquisition units explicitly or use an exact pressR bundle."))
  }
  list(decimal = decimal, value = value)
}

.read_measurement_delim <- function(path, delim = ",", col_types = NULL,
                                    na = c("", "NA"), locale = readr::locale(),
                                    trim_ws = TRUE, ...) {
  raw <- readr::read_delim(path, delim = delim,
    col_types = readr::cols(.default = readr::col_character()),
    na = na, locale = locale, trim_ws = trim_ws,
    show_col_types = FALSE, progress = FALSE, ...)
  if (nrow(readr::problems(raw))) {
    cli::cli_abort("Malformed delimited measurement rows; no padding or truncation is performed.")
  }
  if (!ncol(raw)) return(raw)
  checks <- lapply(raw, .check_decimal_tokens, trim = !trim_ws)
  # type_convert emits a column specification message for inferred columns.
  # Its parse warnings are errors here, because it drops problem attributes.
  out <- withCallingHandlers(suppressMessages(readr::type_convert(raw,
    col_types = col_types, na = na, locale = locale, trim_ws = TRUE)),
    warning = function(w) cli::cli_abort("Malformed numeric measurement tokens.", parent = w))
  for (j in seq_along(out)) {
    if (!is.numeric(out[[j]])) next
    check <- checks[[j]]
    use <- check$decimal
    observed <- out[[j]][use]
    reference <- check$value[use]
    mismatch <- !is.finite(observed) | is.na(reference) |
      (reference == 0 & observed != 0) |
      (reference != 0 & abs(observed / reference - 1) > 1e-12)
    if (any(mismatch)) {
      cli::cli_abort(paste0("Numeric conversion disagrees with the source decimal in column ",
        "{.val {names(out)[j]}}. Use ordinary scientific notation or an exact pressR bundle."))
    }
  }
  out
}

.reader_source_metadata <- function(path) {
  list(source_file = normalizePath(path, winslash = "/", mustWork = TRUE),
    source_filename = basename(path),
    source_sha256 = digest::digest(path, algo = "sha256", file = TRUE))
}
