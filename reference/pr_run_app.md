# Launch the Interactive Pressure Data Explorer

Opens a Shiny application for importing, analyzing, and visualizing
pressure measurement data. The app has six tabs: Import, Heatmap,
Regions, Dynamics, Comparison, and Report.

## Usage

``` r
pr_run_app(trial = NULL, ...)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object to pre-load. If `NULL` (default), the app starts empty and the
  user can load data from the Import tab.

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Invisible `NULL`. Called for side effects: launches the Shiny
application.

## Examples

``` r
# \donttest{
if (interactive()) {
  pr_run_app(pr_example_trial("saddle_horse"))
}
# }
```
