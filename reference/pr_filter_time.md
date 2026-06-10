# Subset a Trial to a Time Window

Subset a Trial to a Time Window

## Usage

``` r
pr_filter_time(trial, from = 0, to = Inf)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- from:

  Numeric. Start time (s). Default `0`.

- to:

  Numeric. End time (s). Default `Inf`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
containing only frames with `time` in `[from, to]`.

## Examples

``` r
tr <- pr_filter_time(pr_example_trial("insole"), from = 1, to = 3)
tr$duration
#> [1] 1.987952
```
