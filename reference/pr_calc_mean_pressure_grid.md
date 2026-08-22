# Whole-Grid Mean Pressure Per Frame

Mean pressure across the entire sensor grid for each frame: the frame
sum divided by the number of sensors, with unloaded cells counted as
zeros.

## Usage

``` r
pr_calc_mean_pressure_grid(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

## Value

Numeric vector of length `n_frames`, in the trial's pressure unit.

## Details

This is deliberately *not* the same quantity as
[`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md),
which averages only the cells above `threshold` (loaded-cells-only, by
definition) and is left untouched. On a saddle mat where a typical frame
loads roughly 4% of the 256 cells, the loaded-cells-only mean is around
25 times the whole-grid mean, so the two are never interchangeable. Use
this one when the mat itself is the region of interest and an unloaded
cell is a real "no pressure here" measurement; use
[`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md)
when the sensor sheet is larger than the loaded object and only the
contact patch is meaningful.

The denominator is `trial$layout$n_sensors`, i.e. the number of *active*
sensors, which equals `ncol(trial$pressure)`. Inactive grid cells are
not measurements and never enter the average.

## See also

Other whole-grid frame metrics:
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md),
[`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md),
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
[`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md),
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
[`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
grid_mean <- pr_calc_mean_pressure_grid(trial)
loaded_mean <- pr_calc_mean_pressure(trial)
# The whole-grid mean is the smaller of the two by construction:
all(grid_mean <= loaded_mean + 1e-9)
#> [1] TRUE
```
