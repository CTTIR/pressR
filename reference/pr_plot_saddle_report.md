# Saddle Fit Report Panel

Composite figure for equine saddle analysis: MPP heatmap, 6-region bar
chart, COP trajectory, and left/right symmetry summary.

## Usage

``` r
pr_plot_saddle_report(trial, thresholds = NULL)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  from a saddle recording.

- thresholds:

  A reference threshold tibble (typically from
  [`pr_ref_saddle()`](https://cttir.github.io/pressR/reference/pr_ref_saddle.md)).
  If `NULL`, uses the von Peinen 2010 defaults.

## Value

A `patchwork` object (4-panel composite).

## Examples

``` r
pr_plot_saddle_report(pr_example_trial("saddle_horse"))
```
