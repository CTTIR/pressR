# Power Spectrum of a Frame-Level Signal

Frequency content of a whole-mat time series: how much of the
recording's variation sits at each frequency. On a saddle mat the stride
shows up as a peak somewhere between 0.5 and 2 Hz.

## Usage

``` r
pr_calc_spectrum(
  trial,
  signal = c("total", "mean", "peak"),
  window = c("hann", "none"),
  detrend = TRUE
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- signal:

  Character. Which frame-level signal to transform: `"total"` (default),
  `"mean"` or `"peak"`. See *Details*.

- window:

  Character. `"hann"` (default) or `"none"`.

- detrend:

  Logical. Subtract the signal mean first. Default `TRUE`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with `n %/% 2 + 1` rows and columns `freq_Hz` (ascending, starting at 0)
and `power`.

## Details

The signal is taken from the pressure matrix directly:

- `"total"` — the frame sum,
  [`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md).

- `"mean"` — the whole-grid frame mean,
  [`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md).
  This is `"total"` divided by the constant `n_sensors`, so its spectrum
  is the `"total"` spectrum scaled by `1 / n_sensors^2` and the peak
  sits at exactly the same frequency.

- `"peak"` — the frame maximum, which is *not* a scaled copy of the
  other two and saturates flat on a device that clips at its ceiling.

`detrend = TRUE` subtracts the mean before transforming, which removes
the DC term that would otherwise dominate a signal sitting on a large
constant offset. It does not remove a linear ramp. `window = "hann"`
then tapers the ends, trading a little frequency resolution for far less
leakage from the strong low-frequency components a drifting baseline
produces; `window = "none"` leaves the segment rectangular.

Power is `Mod(fft(x))^2 / n`, kept for the non-negative frequencies only
(`n %/% 2 + 1` values, including DC and — for even `n` — Nyquist). It is
a squared pressure quantity in the device's own unit, not a density: it
is not divided by the frequency bin width, and it is not corrected for
the window's power loss, so absolute values are comparable only between
recordings of the same length analysed the same way.

## Frequency axis

The axis is built as `(0:(n %/% 2)) * fs / n`, which is the exact centre
frequency of FFT bin `k` for both odd and even `n`.

The study this function reproduces built it as
`seq(0, fs / 2, length.out = length(power))` instead. For even `n` the
two agree exactly. For odd `n` they do not: that sequence has spacing
`fs / (n - 1)` rather than `fs / n`, and it places its last value at
`fs / 2`, which for odd `n` is not an FFT bin at all — the highest real
bin is at `((n - 1) / 2) * fs / n`, just below Nyquist. On the 869-frame
reference recording the error is a uniform stretch of `n / (n - 1)`,
about 0.12%: the study reports a stride at 0.7488 Hz where the exact
axis puts it at 0.7480 Hz. `power` is unaffected — only the labels move.
**This function implements the exact axis.**

## See also

[`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md)
for the peak of this spectrum,
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md)
for the time-domain counterpart.

Other temporal structure functions:
[`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md),
[`pr_calc_phase_map()`](https://cttir.github.io/pressR/reference/pr_calc_phase_map.md),
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md),
[`pr_cop_shape()`](https://cttir.github.io/pressR/reference/pr_cop_shape.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
spec <- pr_calc_spectrum(trial)
nrow(spec) == trial$n_frames %/% 2 + 1
#> [1] TRUE

# The strongest non-DC component is the stride:
round(spec$freq_Hz[which.max(spec$power[-1]) + 1], 3)
#> [1] 1.4

# "mean" is "total" scaled by n_sensors, so power scales by its square:
m <- pr_calc_spectrum(trial, signal = "mean")
all.equal(m$power * trial$layout$n_sensors^2, spec$power)
#> [1] TRUE
```
