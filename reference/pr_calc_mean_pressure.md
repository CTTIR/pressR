# Calculate Mean Pressure Per Frame

Mean of loaded sensors per frame (sensors at or below `threshold` are
excluded).

## Usage

``` r
pr_calc_mean_pressure(trial, threshold = 0)
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
