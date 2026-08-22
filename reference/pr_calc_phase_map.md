# Sensor Map Averaged Over the Stride Cycle

Resamples the whole sensor map — all 256 cells on a saddle mat — onto
percent-of-cycle: for each phase bin, the mean pressure every sensor
carried while the stride was in that part of its cycle. This is the
ensemble average an animation or a phase-by-phase heatmap series is
drawn from.

## Usage

``` r
pr_calc_phase_map(
  trial,
  cycles = NULL,
  n_bins = 10L,
  trim = 0.1,
  min_frames = 10L
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- cycles:

  A cycle table from
  [`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md),
  or `NULL` (default) to detect cycles with that function's defaults.
  Any data frame with `start_idx` and `end_idx` columns is accepted.

- n_bins:

  Integer. Number of phase bins spanning 0-100% of the cycle. Default
  `10L`.

- trim:

  Numeric in `[0, 0.5)`. Fraction trimmed from each end when averaging
  across cycles. Default `0.1`.

- min_frames:

  Integer. Cycles with fewer frames than this are skipped. Default
  `10L`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with `n_bins * n_sensors` rows, ordered by `phase_bin` then sensor, and
columns `phase_bin` (integer, 1 to `n_bins`), `sensor`, `row`, `col`
(integer, as in
[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md))
and `mean_kPa`. Zero rows, with a warning, when no cycle qualifies.

## Details

Each cycle from
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md)
is stretched onto 0-100% of itself — frame `i` of a cycle spanning `m`
frames sits at `(i - 1) / (m - 1) * 100` percent — and its frames are
dropped into `n_bins` equal-width bins, with 100% falling in the last
bin. Every sensor is averaged within a bin, giving one map per bin per
cycle, and those per-cycle maps are then averaged across cycles.

Averaging per cycle first, rather than pooling all frames, weights every
stride equally. Pooling would let a long stride, which contributes more
frames, dominate the ensemble; strides in a recording vary in length by
a factor of three or more, so the difference is real.

`trim` is passed to [`mean()`](https://rdrr.io/r/base/mean.html) as it
averages across cycles within a bin, so `trim = 0.1` discards the
highest and lowest 10% of cycles in each bin and each cell before
averaging. That protects the ensemble from a single stride where the
horse stumbled or the rider shifted, at the cost of ignoring genuine
extremes. `trim = 0` gives the plain mean.

Cycles shorter than `min_frames` frames are skipped: too few frames make
the phase bins mostly empty, and an empty bin contributes nothing rather
than a zero. A bin no cycle ever reached comes back `NA`.

## Agreement with the source study

The study's phase maps used the plain mean across cycles (`trim = 0`).
On the reference recording `ID052_K_K_KG00_MS`, and on the same 14
cycles, this function at `trim = 0` reproduces all 2,560 of its values
with a correlation of 0.99998, a mean absolute difference of 0.007 kPa
and a maximum of 0.12 kPa, on values ranging up to 6.9 kPa. Close, but
not exact: the residual difference has not been traced to any documented
step, so treat the two as equivalent in aggregate rather than
interchangeable cell by cell. At the default `trim = 0.1` the same
comparison gives 0.011 kPa mean and 0.18 kPa maximum, the extra
difference being the trimming itself.

## See also

[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
for the same map reduced over the whole recording instead of over the
cycle.

Other temporal structure functions:
[`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md),
[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md),
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md),
[`pr_cop_shape()`](https://cttir.github.io/pressR/reference/pr_cop_shape.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
pm <- pr_calc_phase_map(trial)
nrow(pm) == 10 * trial$n_sensors
#> [1] TRUE

# Where the load sits at the start of the cycle versus its middle:
first <- pm$mean_kPa[pm$phase_bin == 1]
mid <- pm$mean_kPa[pm$phase_bin == 5]
round(c(bin1 = max(first), bin5 = max(mid)), 2)
#>  bin1  bin5 
#> 16.27 14.34 

# Averaged over all bins, the phase map returns the recording's own
# per-sensor mean to within the trimming:
avg <- tapply(pm$mean_kPa, pm$sensor, mean)
round(stats::cor(as.numeric(avg), pr_sensor_map(trial, "mean")$value), 3)
#> [1] 1
```
