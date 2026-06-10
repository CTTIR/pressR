# Plot Force vs Time

Plot Force vs Time

## Usage

``` r
pr_plot_force_time(trial, show_cycles = FALSE)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- show_cycles:

  Logical. If `TRUE`, shade detected stance phases. Default `FALSE`.

## Value

A `ggplot2` object.

## Examples

``` r
pr_plot_force_time(pr_example_trial("insole"))
```
