# The Shiny application (inst/shiny/pressR/app.R) uses DT::datatable and
# bslib::page_navbar. They are declared in Imports and referenced here so
# that R CMD check does not flag them as unused.
.shiny_imports_anchor <- function() {
  invisible(list(
    DT::datatable,
    DT::renderDT,
    bslib::page_navbar,
    bslib::bs_theme,
    bslib::nav_panel
  ))
}

#' Launch the Interactive Pressure Data Explorer
#'
#' Opens a Shiny application for importing, analyzing, and visualizing
#' pressure measurement data. The app has seven tabs: Import, Heatmap,
#' Regions, Dynamics, Temporal, Compare, and Report.
#'
#' @details Examples are synthetic. Uploads retain the original filename;
#' a failed replacement clears the affected recording and its derived results.
#' Reports and regional CSV exports use the masks selected in Regions.
#' HTML reports require the optional package \pkg{rmarkdown} and Pandoc.
#' PDF reports additionally require a working LaTeX installation.
#' Pressure CSV preserves measurements and timestamps as decimal text, but not
#' the layout or calibration. Use [pr_write_bundle()] from R for an exact,
#' self-contained trial roundtrip. Launch options are restored when the app exits.
#'
#' @param trial A [pr_trial] object to pre-load. If `NULL` (default),
#'   the app starts empty and the user can load data from the Import tab.
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return Invisible `NULL`. Called for side effects: launches the
#'   Shiny application.
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   pr_run_app(pr_example_trial("saddle_horse"))
#' }
#' }
pr_run_app <- function(trial = NULL, ...) {
  previous_options <- options()[intersect(names(options()), c("pressR.preloaded_trial", "shiny.maxRequestSize"))]
  on.exit(
    {
      options(pressR.preloaded_trial = NULL, shiny.maxRequestSize = NULL)
      options(previous_options)
    },
    add = TRUE
  )
  app_dir <- system.file("shiny", "pressR", package = "pressR")
  if (!nzchar(app_dir)) {
    cli::cli_abort(
      "Could not find the Shiny app directory. Try reinstalling {.pkg pressR}."
    )
  }
  if (!is.null(trial)) .validate_trial(trial)
  options(pressR.preloaded_trial = trial)
  shiny::runApp(app_dir, ...)
}
