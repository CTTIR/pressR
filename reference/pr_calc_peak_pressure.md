# Calculate Peak Pressure Per Frame

Returns the maximum pressure across all active sensors for each frame.

## Usage

``` r
pr_calc_peak_pressure(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Sensors at or below this value are treated as unloaded and
  excluded. Default `0`.

## Value

Numeric vector of length `n_frames`.

## Examples

``` r
trial <- pr_example_trial("insole")
pp <- pr_calc_peak_pressure(trial)
length(pp) == trial$n_frames
#> [1] TRUE
```
