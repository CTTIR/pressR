# Bind Historical Cycles to Their Exact Measurements

Bind Historical Cycles to Their Exact Measurements

## Usage

``` r
pr_lock_cycles(trial, cycles)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- cycles:

  Historical cycle table with frame indices and timing.

## Value

A reference object for
[`pr_temporal_profile()`](https://cttir.github.io/pressR/reference/pr_temporal_profile.md).

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
cycles <- pr_calc_stride_cycles(trial)
locked <- pr_lock_cycles(trial, cycles)
locked$schema
#> [1] "pressR-reference-cycles"
nrow(locked$cycles)
#> [1] 13
```
