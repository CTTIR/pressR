# Total Contact Time

Duration for which at least one sensor exceeds `threshold`: the sum of
the sampling intervals whose start and end frames are both loaded. An
isolated loaded frame therefore adds no duration.

## Usage

``` r
pr_calc_contact_time(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Default `0`.

## Value

Numeric scalar (s).

## Examples

``` r
trial <- pr_example_trial("platform")
pr_calc_contact_time(trial, threshold = 5)
#> [1] 1.6
```
