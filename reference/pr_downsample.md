# Downsample a Trial

Keeps every `factor`-th frame.

## Usage

``` r
pr_downsample(trial, factor = 2L)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- factor:

  Integer. Downsample factor. Default `2`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object with reduced frame count.

## Examples

``` r
tr <- pr_downsample(pr_example_trial("insole"), factor = 2)
tr$n_frames
#> [1] 125
```
