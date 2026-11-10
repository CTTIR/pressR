# Create a Pressure Trial Object

Represents a single pressure measurement recording: a time series of
pressure frames measured across a sensor layout.

## Usage

``` r
pr_trial(pressure, time, layout, metadata = list(), sampling_hz = NULL)
```

## Arguments

- pressure:

  Numeric matrix of dimensions `n_frames x n_sensors`. Each row is one
  time frame, each column is one active sensor.

- time:

  Numeric vector of length `n_frames`. Timestamps in seconds from
  recording start.

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object defining the sensor arrangement.

- metadata:

  Named list of trial metadata. Expected (optional) fields:
  `subject_id`, `trial_id`, `date`, `condition`, `system`, `notes`.
  Entries must have unique nonempty names; malformed metadata is
  rejected rather than silently discarded. Stored trials are revalidated
  before scientific calculations, including their layout and timestamp
  extent.

- sampling_hz:

  Numeric. Sampling rate in Hz. If `NULL`, computed from `time`.

## Value

A `pr_trial` S3 object.

## Examples

``` r
trial <- pr_example_trial("insole")
print(trial)
#> 
#> ── pr_trial ────────────────────────────────────────────────────────────────────
#> • System: "insole"
#> • Layout: "insole_standard"
#> • Frames: 250
#> • Duration: 4.98 s
#> • Sampling: 50 Hz
#> • Sensors: 99
#> • Subject: "EX01"
#> • Date: "2026-11-10"
#> • Condition: "walking"
```
