# Launch the Interactive Pressure Data Explorer

Opens a Shiny application for importing, analyzing, and visualizing
pressure measurement data. The app has seven tabs: Import, Heatmap,
Regions, Dynamics, Temporal, Compare, and Report.

## Usage

``` r
pr_run_app(trial = NULL, ...)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
  object to pre-load. If `NULL` (default), the app starts empty and the
  user can load data from the Import tab.

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Invisible `NULL`. Called for side effects: launches the Shiny
application.

## Details

Examples are synthetic. Uploads retain the original filename; a failed
replacement clears the affected recording and its derived results.
Reports and regional CSV exports use the masks selected in Regions. HTML
reports require the optional package rmarkdown and Pandoc. PDF reports
additionally require a working LaTeX installation. Pressure CSV
preserves measurements and timestamps as decimal text, but not the
layout or calibration. Use
[`pr_write_bundle()`](https://cttir.github.io/pressR/dev/reference/pr_write_bundle.md)
from R for an exact, self-contained trial roundtrip. Launch options are
restored when the app exits.

## Examples

``` r
# \donttest{
if (interactive()) {
  pr_run_app(pr_example_trial("saddle_horse"))
}
# }
```
