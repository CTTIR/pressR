# Peak/Mean Pressure Concentration Index

Ratio of a recording's average frame peak to its average frame mean. A
PCI of 1 would mean a perfectly uniform mat; the larger the value, the
more of the load sits under a single hotspot.

## Usage

``` r
pr_calc_pci(trial, denominator = c("grid", "loaded"), eps = 1e-12)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- denominator:

  Character. `"grid"` (default) or `"loaded"`; see Details.

- eps:

  Numeric. Added to the mean-pressure denominator. Default `1e-12`.

## Value

A single numeric value (dimensionless ratio).

## Details

`PCI = mean(peak_kPa) / mean(mean_kPa)` — a ratio of two per-recording
averages, not the average of a per-frame ratio; the two differ whenever
load varies over time, and the cohort summaries use the former.

`denominator` selects which mean goes underneath:

- `"grid"` (default) uses
  [`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
  the whole-grid mean including unloaded cells. This is the cohort
  definition and the one whose interpretation bands
  [`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)
  documents.

- `"loaded"` uses the loaded-cells-only mean of
  [`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md),
  which is a different quantity — that function is loaded-cells-only by
  definition and is untouched here. Values come out roughly an order of
  magnitude smaller on a sparsely loaded mat, and
  [`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)
  does **not** apply to them.

`eps` guards the denominator so a recording with no load at all returns
`0` instead of `NaN`.

## See also

Other whole-grid frame metrics:
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md),
[`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md),
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
[`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md),
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
[`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
pr_calc_pci(trial)
#> [1] 10.11783
# The loaded-cells-only denominator is larger, so the index is smaller:
pr_calc_pci(trial, denominator = "loaded") < pr_calc_pci(trial)
#> [1] TRUE
```
