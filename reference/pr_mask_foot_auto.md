# Auto-Segment Foot Regions from Pressure Data

For platform recordings where foot regions must be detected from the raw
pressure matrix. Uses the maximum pressure picture (MPP) to identify the
foot outline, then segments into anatomical regions based on
proportional geometry.

## Usage

``` r
pr_mask_foot_auto(trial, n_regions = 7L, threshold = 1)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object from a pressure platform recording.

- n_regions:

  Integer. `7` (default, full segmentation into heel, midfoot, met1,
  met2-3, met4-5, hallux, lesser toes) or `3` (heel/midfoot/forefoot).

- threshold:

  Numeric. Minimum pressure (kPa) to consider a sensor loaded. Default
  `1.0`.

## Value

Named list of
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects.
