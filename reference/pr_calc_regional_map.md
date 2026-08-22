# Zone Statistics of the Time-Averaged Sensor Map

Summarises each region mask on the **per-sensor map**: every sensor is
first reduced over its own frames, and the zone statistics are then
taken across the sensors of the zone.

## Usage

``` r
pr_calc_regional_map(
  trial,
  masks = NULL,
  statistic = c("mean", "max", "loaded"),
  threshold = 0
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  Named list of
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
  or logical matrices. `NULL` (default) uses the layout's own regions; a
  layout without regions is an error, since a zone table has to say
  which zones.

- statistic:

  Character. The per-sensor reduction over time: `"mean"` (default) the
  time-average, `"max"` the maximum pressure picture, or `"loaded"` the
  fraction of frames above `threshold`.

- threshold:

  Numeric. Cells at or below this value count as unloaded. Default `0`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per mask and columns `zone`, `zone_mean_kPa`,
`zone_peak_kPa`, `zone_loaded`.

## Operator order

This is the opposite order to
[`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md),
and the two give different numbers on purpose.

- [`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md)
  reduces **over sensors within a frame**, then over frames. Its `mpp`
  is the largest single reading the zone ever produced, in any frame.

- `pr_calc_regional_map()` reduces **over frames within a sensor**, then
  over sensors. Its `zone_peak_kPa` is the largest *time-averaged* cell,
  which is smaller — often several-fold — because no cell holds its
  maximum for a whole recording.

Neither is more correct; they answer different questions. Use
[`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md)
to report what the worst moment looked like, and this function to report
which cells carry load over the ride, which is the quantity a
cohort-level zone table compares between horses.

## Columns

Writing `v` for the per-sensor map and `Z` for a zone's sensors:

- `zone_mean_kPa` — `mean(v[Z])`, over **all** the zone's sensors, with
  never-loaded ones contributing zeros. The mat is the region of
  interest, so an unloaded cell is a real measurement (compare
  [`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md)).

- `zone_peak_kPa` — `max(v[Z])`.

- `zone_loaded` — `sum(v[Z] > 0)`, the number of the zone's sensors that
  ever carried load above `threshold`.

A zone with no sensors at all returns three zeros rather than `NaN`.

With `statistic = "loaded"` the map is a duty cycle in `[0, 1]`, not a
pressure, and the first two columns carry fractions; the column names
are kept fixed so a cohort table has one schema.

## See also

[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
for the map being reduced,
[`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md)
for the frame-first counterpart.

Other regional symmetry functions:
[`pr_calc_cop_masked()`](https://cttir.github.io/pressR/reference/pr_calc_cop_masked.md),
[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md),
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md),
[`pr_mask_rowbands()`](https://cttir.github.io/pressR/reference/pr_mask_rowbands.md),
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
pr_calc_regional_map(trial)
#> # A tibble: 6 × 4
#>   zone          zone_mean_kPa zone_peak_kPa zone_loaded
#>   <chr>                 <dbl>         <dbl>       <int>
#> 1 cranial_left           1.77         10.7           36
#> 2 cranial_right          1.55          9.17          36
#> 3 middle_left            1.15          6.46          48
#> 4 middle_right           1.02          5.66          48
#> 5 caudal_left            1.61         10.6           40
#> 6 caudal_right           1.42          9.13          40

# The sensor-first peak is never above the frame-first peak:
zm <- pr_calc_regional_map(trial)
zf <- pr_calc_regional(trial, parameters = "mpp")
all(zm$zone_peak_kPa <= zf$mpp + 1e-9)
#> [1] TRUE

# An explicit band split, rather than the layout's own regions:
pr_calc_regional_map(trial, pr_mask_rowbands(trial$layout, sides = FALSE))
#> # A tibble: 3 × 4
#>   zone    zone_mean_kPa zone_peak_kPa zone_loaded
#>   <chr>           <dbl>         <dbl>       <int>
#> 1 cranial          1.66         10.7           72
#> 2 middle           1.09          6.46          96
#> 3 caudal           1.52         10.6           80
```
