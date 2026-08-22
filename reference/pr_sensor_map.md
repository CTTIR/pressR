# Per-Sensor Statistics Over Time

Reduces a recording along the time axis: one number per sensor, with the
sensor's grid coordinates attached. This is the counterpart of
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
which reduces along the sensor axis instead.

## Usage

``` r
pr_sensor_map(
  trial,
  statistic = c("mean", "max", "sd", "pti", "pct_zero"),
  threshold = 0
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- statistic:

  Character. One of `"mean"`, `"max"`, `"sd"`, `"pti"` or `"pct_zero"`.
  See *Details*.

- threshold:

  Numeric. Cells at or below this value count as unloaded. Default `0`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per sensor and columns `sensor` (integer), `row`, `col`
(integer grid indices) and `value` (numeric).

## Details

The available statistics, for a sensor read at every frame:

- `"mean"` — mean pressure, unloaded frames included in the denominator.

- `"max"` — the maximum pressure picture (MPP): the peak this sensor
  ever saw. `pr_sensor_map(trial, "max")$value` is the map
  [`pr_plot_heatmap()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap.md)
  draws.

- `"sd"` — standard deviation over frames (`NA` for a single-frame
  trial), i.e. how much this sensor's load fluctuated.

- `"pti"` — pressure-time integral, trapezoidal over the trial's own
  timestamps; identical to
  [`pr_calc_pti()`](https://cttir.github.io/pressR/reference/pr_calc_pti.md)
  at the default threshold.

- `"pct_zero"` — fraction of frames in which the sensor was at or below
  `threshold`. `1` means never loaded, `0` means always loaded; it is
  the per-sensor duty cycle, and `1 - pct_zero` is the fraction of the
  recording the sensor was in contact.

`threshold` treats cells at or below it as unloaded, exactly as in
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md):
they are zeroed before `mean`, `sd` and `pti` are taken, they cannot
raise `max`, and they are what `pct_zero` counts. At the default
`threshold = 0` on non-negative data no masking is needed and none is
done.

The `sensor` column is the *pressure column index*, taken positionally
from `trial$layout$coords_mm`, not the device channel number. For a
layout built by
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md)
the two differ, and `pr_channel_order(trial$layout)[sensor]` recovers
the device channel. Rows come back in that same column-major grid order,
so `$value` can be used as a feature vector directly.

## See also

[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
for the per-frame reduction,
[`pr_profile_matrix()`](https://cttir.github.io/pressR/reference/pr_profile_matrix.md)
to stack this across a dataset.

Other sensor aggregation functions:
[`pr_batch_frame_summary()`](https://cttir.github.io/pressR/reference/pr_batch_frame_summary.md),
[`pr_profile_matrix()`](https://cttir.github.io/pressR/reference/pr_profile_matrix.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
mpp <- pr_sensor_map(trial, "max")
mpp[which.max(mpp$value), ]
#> # A tibble: 1 × 4
#>   sensor   row   col value
#>    <int> <int> <int> <dbl>
#> 1     68     4     5  18.4

# The mean map is never above the peak map, sensor for sensor:
avg <- pr_sensor_map(trial, "mean")
all(avg$value <= mpp$value + 1e-9)
#> [1] TRUE

# Fraction of the recording each sensor spent in contact:
duty <- 1 - pr_sensor_map(trial, "pct_zero")$value
round(range(duty), 3)
#> [1] 0.462 1.000
```
