# Calculate Contact Area Per Frame

Number of sensors above `threshold` times the per-sensor area (cm^2).

## Usage

``` r
pr_calc_contact_area(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Default `0`.

## Value

Numeric vector of contact area (cm^2) per frame.
