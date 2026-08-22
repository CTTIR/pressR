# Total Pressure Per Frame

Sum of all sensor readings in each frame.

## Usage

``` r
pr_calc_total_pressure(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

## Value

Numeric vector of length `n_frames`, summed pressure per frame.

## Details

The result is a sum of pressures (kPa), not a force. Converting it to
Newtons requires a per-cell area;
[`pr_calc_force()`](https://cttir.github.io/pressR/reference/pr_calc_force.md)
does that using `layout$sensor_area_cm2`. For devices whose cell pitch
was never published, `sensor_area_cm2` is `NA` and no force value is
defensible — hence this raw kPa sum, which is what the cohort analyses
use. It is the unscaled counterpart of
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md)
(`total / n_sensors`).

## See also

Other whole-grid frame metrics:
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md),
[`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md),
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md),
[`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
[`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
tot <- pr_calc_total_pressure(trial)
round(max(tot), 1)
#> [1] 376.1
```
