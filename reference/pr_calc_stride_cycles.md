# Segment a Recording into Stride Cycles

Peak-to-peak segmentation of a never-unloading recording. The
frame-level signal is band-passed to isolate the stride oscillation from
the baseline the rider's mass sets, and each interval between two
successive peaks of that oscillation is one cycle.

## Usage

``` r
pr_calc_stride_cycles(
  trial,
  signal = "total",
  lp_window = 11L,
  hp_window_s = 5,
  min_period_s = 0.3,
  height_quantile = 0.3,
  max_period_s = 3
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- signal:

  Character. Frame-level signal to segment. Default `"total"`.

- lp_window:

  Integer. Width in samples of the centred moving average. Default
  `11L`. An odd width keeps the average centred; `1L` disables the low
  pass.

- hp_window_s:

  Numeric. Width in seconds of the running-median baseline. Default `5`.

- min_period_s:

  Numeric. Shortest acceptable cycle, in seconds, and the minimum peak
  separation. Default `0.3`.

- height_quantile:

  Numeric in `[0, 1)`. Peak height threshold, as a quantile of the
  positive part of the band-passed signal. Default `0.3`.

- max_period_s:

  Numeric. Longest acceptable cycle, in seconds. Default `3`; an
  interval longer than this is a detection gap rather than a stride.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per accepted cycle and columns `cycle` (integer, gapped —
see *Details*), `start_idx`, `end_idx` (integer frame indices of the
bounding peaks), `start_s`, `end_s`, `duration_s` (seconds),
`peak_total` (band-passed amplitude at `start_idx`) and `stride_freq`
(`1 / duration_s`, Hz). Zero rows when fewer than two peaks survive.

## Details

This is the replacement for
[`pr_calc_gait_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_gait_cycles.md)
on mats that stay loaded. That function pairs a threshold crossing up
with the next crossing down; a saddle mat never crosses back down, so it
returns a single "cycle" spanning the whole recording no matter how
`force_threshold` is set. The problem is the segmentation model, not its
tuning, so nothing about
[`pr_calc_gait_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_gait_cycles.md)
is changed here.

The pipeline, in order:

1.  **Signal.** `signal` selects the frame-level series exactly as in
    [`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md).
    `"total"` and `"mean"` differ by the constant `n_sensors`, so they
    give identical segmentation; only `peak_total` changes scale.

2.  **Low pass.** An `lp_window`-sample centred moving average. Frames
    at the two ends, where the window overhangs the recording, keep
    their raw value rather than becoming `NA`, so the first and last
    strides are still detectable.

3.  **High pass.** Subtract a running median over `hp_window_s` seconds.
    The median steps over the stride peaks instead of being pulled up by
    them, so the residual keeps its amplitude while the baseline drift —
    the rider settling, the horse changing gait — is removed.

4.  **Peaks.** Strict local maxima of the residual at or above
    `stats::quantile(residual[residual > 0], height_quantile)`, thinned
    tallest-first so no two peaks sit closer than
    `round(min_period_s * fs)` samples.

5.  **Cycles.** Every consecutive pair of peaks, keeping those whose
    duration lies in `[min_period_s, max_period_s]`.

`cycle` numbers the peak pairs **before** the duration filter, so a gap
in the sequence marks an interval that was rejected as too short or too
long — information a renumbered column would hide.

`peak_total` is the band-passed amplitude at the cycle's opening peak,
in the device's pressure unit. It is an excursion above the local
baseline, not a raw frame total: on the reference recording the frame
totals run 383-434 kPa while `peak_total` runs 2.5-13.8 kPa.

## Agreement with the source study

On the 869-frame reference recording `ID052_K_K_KG00_MS`, the defaults
reproduce the study's own segmentation exactly: 14 cycles, identical
`cycle`, `start_idx`, `end_idx`, `duration_s`, `peak_total` and
`stride_freq` to machine precision. Rerun over the study's whole cohort,
all 323 of its 50 Hz recordings match cycle for cycle — 137,761 cycles,
no differences.

The remaining 108 recordings were sampled at 10 Hz, and there the two
disagree. The study hard-coded its running-median width at 251 samples
and its minimum peak separation at 15 samples, which are 5 s and 0.3 s
only at 50 Hz; the parameters here are in seconds and scale with the
trial's own sampling rate. Passing `hp_window_s = 25.1` and
`min_period_s = 1.5` reproduces the study's fixed sample counts on a 10
Hz recording.

That difference shows up in the published cohort means. All 34,095 of
the study's slow-gait (`MG`) cycles come from 50 Hz recordings, and this
function returns their published mean duration of 0.719 s exactly. The
`MH` and `MS` means, 0.748 s and 0.773 s, mix in 10 Hz recordings; on
the 50 Hz half alone both this function and the study give 0.650 s and
0.726 s.

## See also

[`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md)
for the frequency-domain estimate of the same rhythm,
[`pr_calc_phase_map()`](https://cttir.github.io/pressR/reference/pr_calc_phase_map.md)
to average the sensor map over these cycles.

Other temporal structure functions:
[`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md),
[`pr_calc_phase_map()`](https://cttir.github.io/pressR/reference/pr_calc_phase_map.md),
[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md),
[`pr_cop_shape()`](https://cttir.github.io/pressR/reference/pr_cop_shape.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
cycles <- pr_calc_stride_cycles(trial)
nrow(cycles)
#> [1] 13
round(range(cycles$duration_s), 2)
#> [1] 0.64 0.78

# stride_freq is the reciprocal of duration_s, cycle by cycle:
all.equal(cycles$stride_freq, 1 / cycles$duration_s)
#> [1] TRUE

# Cycles tile the recording end to end: each one starts where the
# previous accepted one stopped, unless an interval was rejected.
head(cbind(cycles$start_idx, cycles$end_idx), 3)
#>      [,1] [,2]
#> [1,]   14   46
#> [2,]   46   82
#> [3,]   82  118
```
