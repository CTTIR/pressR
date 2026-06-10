# COP Butterfly Plot Across Gait Cycles

Overlays COP trajectories from each detected stance phase, centered on
heel strike.

## Usage

``` r
pr_plot_cop_butterfly(trial, cycles = NULL)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- cycles:

  Output of
  [`pr_calc_gait_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_gait_cycles.md).
  If `NULL`, auto-detected.

## Value

A `ggplot2` object.

## Examples

``` r
pr_plot_cop_butterfly(pr_example_trial("insole"))
```
