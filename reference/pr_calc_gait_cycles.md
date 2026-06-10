# Detect Gait Cycles from Foot Pressure Data

Identifies heel-strike and toe-off events from the total force curve of
in-shoe or platform pressure data, segmenting the trial into individual
stance phases.

## Usage

``` r
pr_calc_gait_cycles(
  trial,
  force_threshold = 20,
  min_stance_ms = 200,
  min_swing_ms = 100
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object from an insole or platform recording.

- force_threshold:

  Numeric. Force threshold (N) for foot contact detection. Default `20`.

- min_stance_ms:

  Numeric. Minimum stance duration (ms). Shorter contacts are rejected.
  Default `200`.

- min_swing_ms:

  Numeric. Minimum swing duration (ms). Default `100`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per detected cycle.

## Examples

``` r
cycles <- pr_calc_gait_cycles(pr_example_trial("insole"))
cycles
#> # A tibble: 5 × 8
#>   cycle heel_strike_frame toe_off_frame heel_strike_time toe_off_time
#>   <int>             <int>         <int>            <dbl>        <dbl>
#> 1     1                 1            30             0           0.582
#> 2     2                51            80             1.00        1.59 
#> 3     3               101           130             2.01        2.59 
#> 4     4               151           180             3.01        3.59 
#> 5     5               201           230             4.02        4.60 
#> # ℹ 3 more variables: stance_duration <dbl>, start_frame <int>, end_frame <int>
```
