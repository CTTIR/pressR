# Pressure-Time Integral Per Sensor

Integrates pressure over time for each sensor using the trapezoidal
rule. Result is in the measurement unit multiplied by seconds.
Overflowing endpoint sums use a finite midpoint calculation.
Unrepresentable interval areas or totals raise an error instead of
returning infinity.

## Usage

``` r
pr_calc_pti(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

## Value

Numeric vector of length `n_sensors`.
