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
with columns `cycle`, `percent_stance`, `cop_x`, `cop_y`, `cop_velocity`
and `coordinate_unit`. Velocity uses the stated coordinate unit per
second.

## Examples

``` r
trial <- pr_example_trial("insole")
rollover <- pr_calc_rollover(trial, n_points = 11)
head(rollover)
#> # A tibble: 6 × 6
#>   cycle percent_stance cop_x cop_y cop_velocity coordinate_unit
#>   <int>          <dbl> <dbl> <dbl>        <dbl> <chr>          
#> 1     1              0  32.1  78.0          0   mm             
#> 2     1             10  31.0  27.4        842.  mm             
#> 3     1             20  30.3  28.0         16.5 mm             
#> 4     1             30  36.9  87.7       1000.  mm             
#> 5     1             40  33.8  96.0        148.  mm             
#> 6     1             50  33.8 112.         274.  mm             
```
