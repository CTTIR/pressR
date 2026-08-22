# Dominant Oscillation Frequency in a Band

The strongest frequency of
[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md)
inside a search band — on a saddle recording, the stride frequency.

## Usage

``` r
pr_calc_dominant_freq(
  trial,
  band = c(0.3, 5),
  signal = "total",
  window = "hann"
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- band:

  Numeric vector of length 2. Inclusive search band in Hz. Default
  `c(0.3, 5)`.

- signal:

  Character. Frame-level signal to transform. Default `"total"`.

- window:

  Character. Window to taper with. Default `"hann"`.

## Value

A one-row
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `stride_freq_Hz` and `peak_power`. Both are `NA` (with a
warning) when the band contains no frequency bin.

## Details

The default band of 0.3-5 Hz brackets equine stride rates from a slow
walk to a fast canter while excluding both the baseline drift below it
and sensor noise above it. Band edges are inclusive, and the search
happens on the exact frequency axis documented in
[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md).

The result is the single largest bin, with no interpolation between
bins, so its resolution is `fs / n_frames` — 0.058 Hz for a 869-frame
recording at 50 Hz. A recording with no oscillation still returns its
largest in-band bin; read `peak_power` before trusting the frequency,
and compare against
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md),
which measures the same rhythm in the time domain and disagrees when
there is nothing periodic to find.

## See also

[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md)
for the full spectrum.

Other temporal structure functions:
[`pr_calc_phase_map()`](https://cttir.github.io/pressR/reference/pr_calc_phase_map.md),
[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md),
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md),
[`pr_cop_shape()`](https://cttir.github.io/pressR/reference/pr_cop_shape.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
pr_calc_dominant_freq(trial)
#> # A tibble: 1 × 2
#>   stride_freq_Hz peak_power
#>            <dbl>      <dbl>
#> 1            1.4      5881.

# A stride frequency and a mean stride duration are reciprocals:
f <- pr_calc_dominant_freq(trial)$stride_freq_Hz
cycles <- pr_calc_stride_cycles(trial)
round(c(from_spectrum = 1 / f, from_cycles = mean(cycles$duration_s)), 2)
#> from_spectrum   from_cycles 
#>          0.71          0.71 
```
