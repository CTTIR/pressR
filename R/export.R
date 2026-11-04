# ---------------------------------------------------------------------------
# Export / reporting.
# ---------------------------------------------------------------------------

#' Export Analysis Results to CSV
#'
#' @param trial A [pr_trial] object.
#' @param path Character. Output file path.
#' @param what Character. `"summary"` (default), `"regional"`,
#'   `"pressure"`, or `"cop"`.
#' @param masks Named list of masks. Required for `what = "regional"`.
#' @details Existing outputs are replaced only after writing succeeds. Reported
#' replacement failures restore the old output or report a retained backup path.
#' Source recordings, directories and symbolic-link destinations are refused.
#' This does not provide a transaction against process termination or concurrent
#' writers. Use [pr_write_bundle()] for exact numeric preservation; decimal CSV
#' is an exchange format and may change the last bits of floating-point values.
#'
#' @return Invisibly returns the written file path.
#' @export
#' @examples
#' tmp <- tempfile(fileext = ".csv")
#' pr_export_csv(pr_example_trial("insole"), tmp, what = "summary")
pr_export_csv <- function(trial, path,
                          what = c("summary", "regional", "pressure", "cop"),
                          masks = NULL) {
  .validate_trial(trial)
  .validate_output_path(path)
  .protect_recording(trial, path)
  what <- match.arg(what)

  out <- switch(what,
    summary = pr_summary(trial),
    regional = pr_calc_regional(trial, masks %||% NULL),
    pressure = {
      coords <- trial$layout$coords_mm
      df <- as.data.frame(trial$pressure)
      names(df) <- sprintf("s%d", coords$sensor_id)
      df$frame <- seq_len(trial$n_frames)
      df$time <- trial$time
      df[, c("frame", "time", setdiff(names(df), c("frame", "time")))]
    },
    cop = {
      cop <- pr_calc_cop(trial)
      tibble::tibble(
        frame = seq_len(trial$n_frames), time = trial$time,
        x = cop$x, y = cop$y, coordinate_unit = cop$coordinate_unit
      )
    }
  )
  if (what %in% c("summary", "regional")) {
    out$measurement_unit <- .measurement_unit(trial)
    out$coordinate_unit <- .coordinate_unit(trial$layout)
    out$sensor_area_cm2 <- trial$layout$sensor_area_cm2
  }
  .atomic_output(path, function(tmp) readr::write_csv(out, tmp, na = "NA"))
  invisible(path)
}

#' Generate an Analysis Report
#'
#' Renders a parameterized R Markdown template into an HTML or PDF report
#' for a trial.
#'
#' @param trial A [pr_trial] object.
#' @param output_file Character. Output file path.
#' @param format Character. `"html"` (default) or `"pdf"`.
#' @param template Character. `"generic"` (default), `"saddle"`, or
#'   `"foot"`.
#' @param masks Named list of masks. `NULL` uses the layout defaults.
#' @param thresholds Optional reference threshold tibble.
#' @details Source recordings and symbolic-link destinations are refused.
#' Completed reports replace existing outputs with recovery on reported failures;
#' process termination or concurrent writers are outside this guarantee.
#'
#' @return Invisibly returns the generated file path.
#' @export
#' @examples
#' \dontrun{
#' tmp <- tempfile(fileext = ".html")
#' pr_export_report(pr_example_trial("insole"), tmp, template = "foot")
#' }
pr_export_report <- function(trial, output_file,
                             format = c("html", "pdf"),
                             template = c("generic", "saddle", "foot"),
                             masks = NULL, thresholds = NULL) {
  .validate_trial(trial)
  .validate_output_path(output_file)
  .protect_recording(trial, output_file)
  format <- match.arg(format)
  template <- match.arg(template)
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg rmarkdown} is required to generate reports."
    )
  }
  rmd <- system.file("templates",
    sprintf("report_%s.Rmd", template),
    package = "pressR"
  )
  if (!nzchar(rmd)) {
    cli::cli_abort("Template not found: {.val {template}}.")
  }
  out_fmt <- if (format == "html") "html_document" else "pdf_document"
  work <- tempfile("pressr-report-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  input <- file.path(work, basename(rmd))
  file.copy(rmd, input)
  .atomic_output(output_file, function(tmp) {
    rendered <- rmarkdown::render(input,
      output_file = paste0("report.", format),
      output_dir = work, intermediates_dir = work, knit_root_dir = work,
      output_format = out_fmt, params = list(trial = trial, masks = masks, thresholds = thresholds),
      envir = new.env(parent = asNamespace("pressR")), quiet = TRUE
    )
    if (!file.exists(rendered) || !file.copy(rendered, tmp, overwrite = TRUE)) cli::cli_abort("Report rendering did not produce a complete output.")
  })
  invisible(output_file)
}

.protect_recording <- function(trial, path) {
  source <- trial$metadata[["source_file"]]
  if (is.null(source)) return(invisible(path))
  if (!is.character(source) || length(source) != 1L || is.na(source) || !nzchar(source)) {
    cli::cli_abort("Source recording metadata must contain one valid path.")
  }
  if (identical(normalizePath(path, mustWork = FALSE), normalizePath(source, mustWork = FALSE))) {
    cli::cli_abort("Export would overwrite the source recording.")
  }
  invisible(path)
}
