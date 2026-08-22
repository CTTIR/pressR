# Pressure Concentration Index Interpretation Bands

Working interpretation bands for the whole-grid PCI returned by
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md).

## Usage

``` r
pr_ref_pci()
```

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `region`, `parameter`, `threshold`, `unit`,
`interpretation`, `source`, `band`, `band_min`, `band_max`.

## Details

The first six columns match the other `pr_ref_*` tables
([`pr_ref_saddle()`](https://cttir.github.io/pressR/reference/pr_ref_saddle.md),
[`pr_ref_diabetic_foot()`](https://cttir.github.io/pressR/reference/pr_ref_diabetic_foot.md),
[`pr_ref_wheelchair()`](https://cttir.github.io/pressR/reference/pr_ref_wheelchair.md)),
with `threshold` holding the lower edge of each band; `band`, `band_min`
and `band_max` are appended so the interval can be used
programmatically. `band_max` is `Inf` for the open top band.

Unlike the other reference tables, these bands are **not** taken from a
published clinical threshold study. They are the working ranges used to
describe whole-grid saddle-mat recordings, and they apply only to
`pr_calc_pci(trial, denominator = "grid")`. PCI is dimensionless and
scale-free in pressure, but it is *not* comparable across devices with
different grid sizes, because the whole-grid mean depends on how much
unloaded mat surrounds the contact patch.

## See also

Other whole-grid frame metrics:
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md),
[`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md),
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
[`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md),
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)

## Examples

``` r
pr_ref_pci()
#> # A tibble: 4 × 9
#>   region parameter threshold unit  interpretation source band  band_min band_max
#>   <chr>  <chr>         <dbl> <chr> <chr>          <chr>  <chr>    <dbl>    <dbl>
#> 1 whole… pci               3 ratio Good: 3-6, lo… Worki… good         3        6
#> 2 whole… pci               6 ratio Moderate: 6-1… Worki… mode…        6       10
#> 3 whole… pci              10 ratio Poor: 10-20, … Worki… poor        10       20
#> 4 whole… pci              20 ratio Very poor: ab… Worki… very…       20      Inf
# Classify one recording:
pci <- pr_calc_pci(pr_example_trial("saddle_horse"))
ref <- pr_ref_pci()
ref$band[pci >= ref$band_min & pci < ref$band_max]
#> [1] "poor"
```
