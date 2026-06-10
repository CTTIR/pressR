# Detect Saddle Slip / Asymmetric Loading

Analyzes left/right pressure asymmetry over time to detect saddle slip
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

  Numeric. SI% above which asymmetry is flagged. Default `15`.

## Value

A list with class `pr_saddle_slip`.

## Examples

``` r
pr_calc_saddle_slip(pr_example_trial("saddle_horse"))
#> 
#> ── Saddle Slip / Asymmetry Analysis ──
#> 
#> • Mean symmetry index: 10.97%
#> • Max |SI|: 121.4%
#> • Dominant side: "balanced"
#> • Asymmetric: FALSE
```
