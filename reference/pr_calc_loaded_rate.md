# Calculate Fraction of Loaded Sensors Per Frame

Calculate Fraction of Loaded Sensors Per Frame

## Usage

``` r
pr_calc_loaded_rate(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Default `0`.

## Value

Numeric vector in `[0, 1]` of length `n_frames`.
