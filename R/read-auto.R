#' Auto-Detect and Read a Pressure Data File
#'
#' Inspects the file extension and header, then dispatches to the correct
#' parser.
#'
#' @param path Character. Path to any supported pressure data file.
#' @param layout A [pr_layout] object. If `NULL`, inferred by the
#'   dispatched parser.
#' @param verbose Logical. Default `TRUE`.
#' @param filename Original filename when path is an upload temporary file.
#'   Only the extension and recording identity are used; content is read from path.
#'
#' @return A [pr_trial] object (for `.asc` / `.txt` / `.csv`), or a
#'   logical mask matrix / [pr_mask] object (for `.msa`/`.msr`/`.msp`).
#' @export
#' @examples
#' path <- pr_example_files("insole")
#' tr <- pr_read_auto(path, verbose = FALSE)
#' inherits(tr, "pr_trial")
pr_read_auto <- function(path, layout = NULL, verbose = TRUE, filename = basename(path)) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}.")
  }
  if (dir.exists(path)) {
    return(pr_read_bundle(path))
  }
  if (!is.character(filename) || length(filename) != 1L || is.na(filename)) cli::cli_abort("filename must be one original filename.")
  finish <- function(x) {
    if (inherits(x, "pr_trial")) {
      x$metadata$trial_id <- tools::file_path_sans_ext(basename(filename))
      x$metadata$source_filename <- basename(filename)
      x$metadata$source_file <- normalizePath(path, winslash = "/", mustWork = TRUE)
      if (is.null(x$metadata$source_sha256)) x$metadata$source_sha256 <- digest::digest(path, algo = "sha256", file = TRUE)
    }
    x
  }
  ext <- tolower(tools::file_ext(filename))
  if (.is_pliance(path)) {
    return(finish(pr_read_pliance(path, layout = layout)))
  }
  finish(switch(ext,
    asc = pr_read_ascii(path, layout = layout, verbose = verbose),
    txt = pr_read_ascii(path, layout = layout, verbose = verbose),
    csv = pr_read_csv(path, layout = layout, verbose = verbose),
    msa = pr_read_mask(path, layout = layout, verbose = verbose),
    msr = pr_read_mask(path, layout = layout, verbose = verbose),
    msp = pr_read_mask(path, layout = layout, verbose = verbose),
    cli::cli_abort("Unsupported file extension: {.val {ext}}.")
  ))
}

# Detect the format from the bounded header, including extensionless uploads.
.is_pliance <- function(path) {
  h <- .pliance_header(path, 7L, "latin1")
  any(grepl("Druckwerte in", h, fixed = TRUE)) &&
    any(grepl("Zeit [Sek.]", h, fixed = TRUE))
}
