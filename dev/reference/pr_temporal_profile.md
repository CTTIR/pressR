# Analyze Temporal Structure With an Explicit Reproducibility Profile

corrected uses measured sampling rate and deterministic plateau
handling. legacy_method re-executes the historical fixed-50-Hz method;
numerical differences across platforms mean it is not an exact replay
guarantee. reference replays cycles bound to the measurements by
[`pr_lock_cycles()`](https://cttir.github.io/pressR/dev/reference/pr_lock_cycles.md).
Its phase map uses the source workflow's central 80 percent of cycles
and an untrimmed mean. No historical analysis is silently substituted.

## Usage

``` r
pr_temporal_profile(
  trial,
  profile = c("corrected", "legacy_method", "reference"),
  reference = NULL
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
  object.

- profile:

  One of corrected, legacy_method or reference.

- reference:

  Locked historical cycles, required for reference replay.

## Value

A list with cycles, spectrum, dominant frequency, phase map and explicit
analysis settings.
