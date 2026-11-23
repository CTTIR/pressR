#' Read Mask File
#'
#' Parses `.msa` / `.msr` / `.msp` mask files or any text file containing
#' a binary region matrix. The expected format is a text matrix of 0/1
#' (or non-zero) values, optionally preceded by a short header.
#'
#' Lines with fewer than two tokens, or in which at least a fifth of the
#' tokens are non-numeric (such as a header), are skipped. The remaining
#' matrix rows must consist of numbers only; a stray token inside the matrix
#' is an error rather than a missing cell. Rows shorter than the widest row
#' are padded with `0` (outside the region) at their end.
#'
#' @param path Character. Path to the mask file.
#' @param layout A [pr_layout] object. Required if the mask dimensions
#'   must be validated against a specific layout; otherwise, the mask is
#'   returned as-is.
#' @param name Character. Name for the resulting [pr_mask] object.
#'   Default `"imported"`.
#' @param verbose Logical. Default `TRUE`.
#'
#' @return A [pr_mask] object (if a layout is supplied) or a logical
#'   matrix.
#' @export
#' @examples
#' tmp <- tempfile(fileext = ".msa")
#' writeLines(c(
#'   "1 1 0 0",
#'   "1 1 0 0",
#'   "0 0 1 1",
#'   "0 0 1 1"
#' ), tmp)
#' m <- pr_read_mask(tmp, verbose = FALSE)
#' dim(m)
pr_read_mask <- function(path, layout = NULL, name = "imported",
                         verbose = TRUE) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}.")
  }
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]

  split_lines <- strsplit(lines, "[[:space:],;]+")
  split_lines <- lapply(split_lines, function(x) x[nzchar(x)])
  # Drop any leading non-numeric rows
  is_numeric <- vapply(split_lines, function(x) {
    nums <- suppressWarnings(as.numeric(x))
    length(nums) >= 2L && sum(!is.na(nums)) / length(nums) > 0.8
  }, logical(1))
  data_lines <- split_lines[is_numeric]
  if (length(data_lines) == 0L) {
    cli::cli_abort("No numeric data found in {.path {path}}.")
  }
  ncols <- vapply(data_lines, length, integer(1))
  if (length(unique(ncols)) > 1L) {
    maxc <- max(ncols)
    data_lines <- lapply(data_lines, function(x) {
      c(x, rep("0", maxc - length(x)))
    })
  }
  mat <- do.call(rbind, lapply(data_lines, function(x) suppressWarnings(as.numeric(x))))
  if (anyNA(mat)) {
    bad <- which(rowSums(is.na(mat)) > 0L)
    cli::cli_abort(c(
      "Mask rows must contain numbers only.",
      "x" = "Non-numeric value in matrix row(s) {paste(bad, collapse = ', ')} of {.path {path}}."
    ))
  }
  mask_mat <- mat != 0

  if (verbose) {
    cli::cli_inform(
      "Read mask with dimensions {nrow(mask_mat)} x {ncol(mask_mat)}."
    )
  }

  if (is.null(layout)) return(mask_mat)

  if (nrow(mask_mat) != layout$grid_rows ||
      ncol(mask_mat) != layout$grid_cols) {
    cli::cli_abort(
      "Mask dimensions ({nrow(mask_mat)} x {ncol(mask_mat)}) do not match
       layout ({layout$grid_rows} x {layout$grid_cols})."
    )
  }
  pr_mask(mask_mat, name, layout)
}
