# Detect Saddle Slip / Asymmetric Loading

Analyses left/right pressure asymmetry over time to detect saddle slip
or systematic asymmetric loading.

## Usage

``` r
pr_calc_saddle_slip(trial, masks = NULL, slip_threshold = 15)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  Named list of region masks. If `NULL`, auto-generated via
  [`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md).

- slip_threshold:

  Numeric. Non-negative SI% above which asymmetry is flagged. Default
  `15`.

## Value

A list with class `pr_saddle_slip`:

- `symmetry_index_mean`: mean per-frame symmetry index (%),
  `(L - R) / (0.5 * (L + R)) * 100`; positive values mean left
  dominance. Frames without load on either side contribute `0`.

- `symmetry_index_max`: largest absolute per-frame symmetry index (%).

- `dominant_side`: `"left"` or `"right"` when the recording is flagged
  as asymmetric, otherwise `"balanced"`.

- `is_asymmetric`: `TRUE` when `abs(symmetry_index_mean)` exceeds
  `slip_threshold`.

- `si_timeseries`: the per-frame symmetry index (%).

## Examples

``` r
pr_calc_saddle_slip(pr_example_trial("saddle_horse"))
#> 
#> ── Saddle Slip / Asymmetry Analysis ──
#> 
#> • Mean symmetry index: 10.97%
#> • Max |SI|: 122.54%
#> • Dominant side: "balanced"
#> • Asymmetric: FALSE
```
