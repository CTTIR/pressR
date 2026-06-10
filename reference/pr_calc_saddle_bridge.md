# Detect Saddle Bridge Formation

Identifies "bridging" — a saddle fit problem where the middle region is
unloaded while cranial and caudal regions carry excessive pressure.
Bridging is quantified as the ratio of middle-region pressure to the
mean of cranial and caudal pressures.

## Usage

``` r
pr_calc_saddle_bridge(trial, masks = NULL, bridge_threshold = 0.5)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  from a horse saddle recording.

- masks:

  Named list of 6 region masks (from
  [`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md)).
  If `NULL`, generated from the trial's layout.

- bridge_threshold:

  Numeric. Middle/ends ratio below this value indicates bridging.
  Default `0.5`.

## Value

A list with class `pr_saddle_bridge`:

- `bridge_ratio`: middle / mean(cranial, caudal) MVP ratio.

- `is_bridged`: logical.

- `regional_pressures`: tibble with MVP per region.

- `recommendation`: character.

## Examples

``` r
pr_calc_saddle_bridge(pr_example_trial("saddle_horse"))
#> 
#> ── Saddle Bridge Analysis ──
#> 
#> • Bridge ratio: 0.773
#> • Bridging: FALSE
#> Pressure distribution appears continuous across the saddle (ratio = 0.77).
```
