# Analyze COP Rollover Pattern

Computes the center of pressure progression during the stance phase of
each gait cycle, resampled to percent of stance (0-100).

## Usage

``` r
pr_calc_rollover(trial, cycles = NULL, n_points = 51L)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- cycles:

  Output of
  [`pr_calc_gait_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_gait_cycles.md).
  If `NULL`, cycles are detected automatically.

- n_points:

  Integer. Number of points to sample along each stance phase. Default
  `51`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `cycle`, `percent_stance`, `cop_x_mm`, `cop_y_mm`,
`cop_velocity`.
