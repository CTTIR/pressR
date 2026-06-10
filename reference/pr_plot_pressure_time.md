# Plot Peak and Mean Pressure vs Time

Plot Peak and Mean Pressure vs Time

## Usage

``` r
pr_plot_pressure_time(trial, show_cycles = FALSE)
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
pr_plot_pressure_time(pr_example_trial("insole"))
```
