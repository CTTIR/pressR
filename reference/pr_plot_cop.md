# Plot Center of Pressure Trajectory

Plot Center of Pressure Trajectory

## Usage

``` r
pr_plot_cop(trial, show_layout = TRUE, color_by = c("time", "velocity"))
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- show_layout:

  Logical. Draw sensor grid in background. Default `TRUE`.

- color_by:

  Character. `"time"` (default) or `"velocity"`.

## Value

A `ggplot2` object.

## Examples

``` r
pr_plot_cop(pr_example_trial("saddle_horse"))
```
