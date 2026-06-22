# Generate a Synthetic Pressure Trial

Creates a
[pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md) with
realistic synthetic pressure data for demonstration, testing, and
vignette purposes.

## Usage

``` r
pr_example_trial(
  type = c("insole", "platform", "saddle_horse", "saddle_bicycle", "wheelchair",
    "custom"),
  duration_s = NULL,
  sampling_hz = 50,
  seed = 42
)
```

## Arguments

- type:

  Character. Type of trial to generate: `"insole"`, `"platform"`,
  `"saddle_horse"`, `"saddle_bicycle"`, `"wheelchair"`, or `"custom"`
  (small uniform grid).

- duration_s:

  Numeric. Trial duration in seconds. `NULL` (default) uses a
  type-specific default.

- sampling_hz:

  Numeric. Sampling rate. Default `50`.

- seed:

  Integer. Random seed for reproducibility. Default `42`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object.

## Examples

``` r
trial <- pr_example_trial("insole")
print(trial)
#> 
#> ── pr_trial ────────────────────────────────────────────────────────────────────
#> • System: "insole"
#> • Layout: "insole_standard"
#> • Frames: 250
#> • Duration: 5 s
#> • Sampling: 50 Hz
#> • Sensors: 99
#> • Subject: "EX01"
#> • Date: "2026-06-22"
#> • Condition: "walking"
```
