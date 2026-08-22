# Per-Frame Metric Table

Computes the whole-grid frame vocabulary — mean, peak, total, loaded
cell count and grid-index centre of pressure — in a single vectorised
pass over the pressure matrix.

## Usage

``` r
pr_frame_metrics(trial, threshold = 0, eps = 1e-12)
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
with `n_frames` rows and columns `frame`, `time_s`, `mean_kPa`,
`peak_kPa`, `total_kPa`, `loaded`, `cop_row`, `cop_col`. Pressure
columns carry the trial's own unit; the `kPa` suffixes follow the cohort
naming convention.

## Details

Every column is computed with whole-matrix operations — two
[`rowSums()`](https://rdrr.io/r/base/colSums.html), one
[`max.col()`](https://rdrr.io/r/base/maxCol.html), and a single matrix
product carrying both COP axes. There is no per-frame R loop, because
cohort-scale inputs run to millions of frames. Measured on a 200,000 x
256 matrix (R 4.6.1, one core): about 145,000 frames per second, i.e.
roughly 70 s for a 5.5 M-frame cohort, against 73-83 s for the
equivalent [`vapply()`](https://rdrr.io/r/base/lapply.html) over rows.
The default `threshold = 0` also skips masking the matrix entirely when
no reading is negative, which saves a full copy of the pressure data.

Column definitions:

- `mean_kPa` — `total_kPa / n_sensors`, whole grid, zeros included. This
  is **not**
  [`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md),
  which is loaded-cells-only by definition and is left unchanged; see
  [`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md).

- `peak_kPa` — the plain row maximum, not filtered by `threshold`.

- `total_kPa` — the plain row sum, not filtered by `threshold`.

- `loaded` — count of cells strictly above `threshold`.

- `cop_row`, `cop_col` — grid index units, `eps` on the denominator so
  an unloaded frame gives approximately `0` rather than `NA`.

`threshold` therefore affects `loaded` and the COP weighting only; peak
and total always describe the frame as recorded.

## See also

Other whole-grid frame metrics:
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md),
[`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md),
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
[`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md),
[`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
fm <- pr_frame_metrics(trial)
names(fm)
#> [1] "frame"     "time_s"    "mean_kPa"  "peak_kPa"  "total_kPa" "loaded"   
#> [7] "cop_row"   "cop_col"  
all.equal(fm$mean_kPa, fm$total_kPa / trial$layout$n_sensors)
#> [1] TRUE
```
