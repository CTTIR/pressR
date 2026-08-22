# Asymmetry Index Across a Family of Masks

Recomputes
[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md)
for every mask scheme in a list and returns one row per scheme, so that
a symmetry claim can be reported together with how much it depends on
where the region of interest was drawn.

## Usage

``` r
pr_symmetry_sensitivity(
  trial,
  masks,
  statistic = "mean",
  denominator = "grid",
  balance = TRUE
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  A **named** list of mask schemes. Each element is a
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md), a
  logical matrix, or a list of exactly two of those giving the two sides
  explicitly — the same forms
  [`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md)
  accepts for its own `masks`.

- statistic:

  Character. `"mean"` (default), `"max"` or `"loaded"`; see
  [`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md).

- denominator:

  Character. `"grid"` (default) or `"loaded"`; see *Details*.

- balance:

  Logical. Trim each scheme to its largest mirror-symmetric subset
  before computing the index. Default `TRUE`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per scheme and columns `scheme`, `balanced`, `statistic`,
`denominator`, `n_left`, `n_right`, `left_value`, `right_value`,
`asymmetry_pct`.

## Details

A left/right index is only as stable as its mask. Excluding dead
sensors, restricting to a band, or thresholding on contact frequency all
change which cells are compared, and each of those choices can move the
index by more than the effect being reported. Running the family and
printing the spread is cheap — the per-sensor map is computed once and
reused for every scheme — and it turns an unstated choice into a
reported one.

With `balance = TRUE` (the default) each scheme is passed through the
mirror trim of
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md)
first, so every row compares equal, mirror-image sets of sensors and
`n_left == n_right` throughout. Set it to `FALSE` to see what the raw
masks give; the difference between the two runs is the part of the index
that came from the mask rather than from the recording.

## See also

[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md)
for a single scheme.

Other regional symmetry functions:
[`pr_calc_cop_masked()`](https://cttir.github.io/pressR/reference/pr_calc_cop_masked.md),
[`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md),
[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md),
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md),
[`pr_mask_rowbands()`](https://cttir.github.io/pressR/reference/pr_mask_rowbands.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
layout <- trial$layout
bands <- pr_mask_rowbands(layout, sides = FALSE)

schemes <- list(
  whole_mat = layout$active,
  cranial = bands$cranial,
  middle = bands$middle,
  caudal = bands$caudal
)
pr_symmetry_sensitivity(trial, schemes)[, c("scheme", "asymmetry_pct")]
#> # A tibble: 4 × 2
#>   scheme    asymmetry_pct
#>   <chr>             <dbl>
#> 1 whole_mat          13.1
#> 2 cranial            13.4
#> 3 middle             12.7
#> 4 caudal             13.1

# A data-driven mask need not be even-handed. Here the hotspot cells are
# 18 left against 12 right, and the raw index is a quarter of what the
# balanced 12/12 comparison reports.
hot <- matrix(FALSE, layout$grid_rows, layout$grid_cols)
co <- layout$coords_mm
hot[cbind(co$row, co$col)] <- pr_sensor_map(trial, "max")$value > 8
rbind(
  pr_symmetry_sensitivity(trial, list(hotspots = hot), balance = FALSE),
  pr_symmetry_sensitivity(trial, list(hotspots = hot))
)[, c("balanced", "n_left", "n_right", "asymmetry_pct")]
#> # A tibble: 2 × 4
#>   balanced n_left n_right asymmetry_pct
#>   <lgl>     <int>   <int>         <dbl>
#> 1 FALSE        18      12          2.92
#> 2 TRUE         12      12         14.6 
```
