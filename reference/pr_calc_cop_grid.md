# Center of Pressure in Grid Index Units

Pressure-weighted centroid of each frame expressed in grid indices: a
`cop_row` of 1 is the first sensor row, a `cop_col` of 16 the sixteenth
sensor column. Row and col are read from the layout's coordinate table
positionally, so the result stays correct under any device channel
permutation applied by the reader.

## Usage

``` r
pr_calc_cop_grid(trial, threshold = 0, eps = 1e-12)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Cells at or below this value count as unloaded. Default `0`.

- eps:

  Numeric. Added to the weight sum to keep unloaded frames finite.
  Default `1e-12`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per frame and columns `frame` (integer), `time_s`,
`cop_row`, `cop_col` (grid index units).

## Details

[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
returns the same centroid in millimetres and gives `NA` for frames with
no load. This function is the index-unit counterpart used when a
device's physical sensor pitch was never published, so millimetre
coordinates would be fabricated. Instead of `NA`, an unloaded frame gets
a centroid of approximately `0` for both axes: `eps` is added to the
weight sum, so the quotient is `0 / eps` rather than `0 / 0`. That keeps
the output a complete, non-`NA` time series, and `cop_row == 0` is
unambiguous because a real centroid is always at least 1.

Note also that the whole-grid metrics here differ from
[`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md),
which is loaded-cells-only by definition.

## See also

Other whole-grid frame metrics:
[`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md),
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
[`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md),
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
[`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
cop <- pr_calc_cop_grid(trial)
range(cop$cop_row)
#> [1] 8.220827 8.769230
```
