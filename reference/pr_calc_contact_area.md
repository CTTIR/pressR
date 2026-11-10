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

## Examples

``` r
trial <- pr_example_trial("insole")
area <- pr_calc_contact_area(trial, threshold = 5)
range(area)
#> [1]  0.0 97.5
```
