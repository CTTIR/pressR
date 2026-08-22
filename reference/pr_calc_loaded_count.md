# Loaded Cell Count Per Frame

Number of sensors reading strictly above `threshold` in each frame.

## Usage

``` r
pr_calc_loaded_count(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Cells at or below this value count as unloaded. Default `0`.

## Value

Integer vector of length `n_frames`.

## Details

The count that
[`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md)
divides by, exposed on its own.
[`pr_calc_loaded_rate()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_rate.md)
returns the same information as a fraction of the grid and
[`pr_calc_contact_area()`](https://cttir.github.io/pressR/reference/pr_calc_contact_area.md)
scales it by the cell area; this function keeps it as a plain cell
count, which is the form the cohort summaries report because the
device's cell area is unknown.

## See also

Other whole-grid frame metrics:
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md),
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
[`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md),
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
[`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
loaded <- pr_calc_loaded_count(trial)
max(loaded) <= trial$layout$n_sensors
#> [1] TRUE
```
