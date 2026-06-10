# Identify Pressure Hotspots

Finds sensors exceeding a clinical pressure threshold — relevant for
pressure ulcer risk assessment in wheelchair seating.

## Usage

``` r
pr_calc_seat_hotspot(trial, threshold = 4.7, duration_s = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  from a seating recording.

- threshold:

  Numeric. Pressure threshold (kPa) above which a sensor is considered a
  hotspot. Default `4.7` (equivalent to 32 mmHg, the capillary closing
  pressure).

- duration_s:

  Numeric. Minimum sustained duration (s) above threshold for a hotspot
  to be flagged. Default `0`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `sensor_id`, `row`, `col`, `x_mm`, `y_mm`, `max_pressure`,
`mean_pressure`, `duration_above_s`.

## Examples

``` r
pr_calc_seat_hotspot(pr_example_trial("wheelchair"))
#> # A tibble: 559 × 8
#>    sensor_id   row   col  x_mm  y_mm max_pressure mean_pressure duration_above_s
#>        <int> <int> <int> <dbl> <dbl>        <dbl>         <dbl>            <dbl>
#>  1        17    17     1     0   240         5.13         0.483                0
#>  2        75    11     3    30   150         5.12         0.729                0
#>  3        84    20     3    30   285         4.81         0.448                0
#>  4       104     8     4    45   105         4.82         1.24                 0
#>  5       105     9     4    45   120         5.23         1.29                 0
#>  6       107    11     4    45   150         4.70         0.999                0
#>  7       132     4     5    60    45         4.77         0.909                0
#>  8       133     5     5    60    60         4.86         1.15                 0
#>  9       134     6     5    60    75         4.85         1.47                 0
#> 10       135     7     5    60    90         5.04         1.94                 0
#> # ℹ 549 more rows
```
