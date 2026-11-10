# Calculate Total Force Per Frame

Force in Newtons equals sum(pressure \* sensor_area). With pressure in
kPa and area in cm^2, force\[N\] = sum(p_kPa \* a_cm2) \* 0.1. When the
unscaled sum overflows, conversion is applied before summation. Results
outside the finite numeric range are refused; unknown calibration
continues to produce `NA`.

## Usage

``` r
pr_calc_force(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

## Value

Numeric vector of length `n_frames`.

## Examples

``` r
trial <- pr_example_trial("insole")
force <- pr_calc_force(trial)
max(force)
#> [1] 1442.449
```
