# Calculate Total Force Per Frame

Force in Newtons equals sum(pressure \* sensor_area). With pressure in
kPa and area in cm^2, force\[N\] = sum(p_kPa \* a_cm2) \* 0.1.

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
