# Left/Right Asymmetry of the Time-Averaged Sensor Map

The classic asymmetry index `(L - R) / (0.5 * (L + R)) * 100`, computed
on the per-sensor map rather than frame by frame. Negative values are
right-biased, positive values left-biased, and zero is symmetric.

## Usage

``` r
pr_calc_symmetry_map(
  trial,
  masks = NULL,
  statistic = "mean",
  denominator = c("grid", "loaded")
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  What to compare. `NULL` (default) uses the whole active grid, split at
  `floor(grid_cols / 2)` exactly as
  [`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md)
  does. A single
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) or
  logical matrix restricts that comparison to a region of interest,
  split at the same midline. A list of exactly two masks gives the two
  sides explicitly, left first.

- statistic:

  Character. `"mean"` (default), `"max"` or `"loaded"`; see
  [`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md).

- denominator:

  Character. `"grid"` (default) or `"loaded"`; see *Details*.

## Value

A one-row
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `statistic`, `denominator`, `n_left`, `n_right`,
`left_value`, `right_value` and `asymmetry_pct`.

## Details

`L` and `R` are the mean of the per-sensor map over the left and right
sensors of the region of interest. Because the map is taken first, the
index describes where load sat *over the whole recording*, not where the
loudest frame happened to be; it is the counterpart of the frozen
[`pr_calc_symmetry_index()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_index.md),
which averages within frames.

`denominator` chooses what goes into each side's mean:

- `"grid"` (default) averages over **every** sensor of the side,
  counting never-loaded ones as zeros. This is the cohort definition: on
  a mat that *is* the region of interest, an unloaded cell is a real
  measurement.

- `"loaded"` averages only the sensors whose map value is above zero.
  That answers a different question — how hard the loaded cells were
  pressed, ignoring how many there were — and is usually much closer to
  zero, because a side that loses contact area keeps its intensity.

The index is undefined when both sides are zero; that case returns `0`,
as
[`pr_calc_symmetry_index()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_index.md)
does.

Nothing here forces the two sides to hold the same number of sensors.
When they do not, part of the index is a property of the mask — see
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md)
and
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md).

## See also

[`pr_calc_symmetry_index()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_index.md)
for the frame-first version,
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)
to vary the mask.

Other regional symmetry functions:
[`pr_calc_cop_masked()`](https://cttir.github.io/pressR/reference/pr_calc_cop_masked.md),
[`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md),
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md),
[`pr_mask_rowbands()`](https://cttir.github.io/pressR/reference/pr_mask_rowbands.md),
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
pr_calc_symmetry_map(trial)
#> # A tibble: 1 × 7
#>   statistic denominator n_left n_right left_value right_value asymmetry_pct
#>   <chr>     <chr>        <int>   <int>      <dbl>       <dbl>         <dbl>
#> 1 mean      grid           124     124       1.48        1.30          13.1

# Restricted to the cranial band only:
bands <- pr_mask_rowbands(trial$layout, sides = FALSE)
pr_calc_symmetry_map(trial, bands$cranial)
#> # A tibble: 1 × 7
#>   statistic denominator n_left n_right left_value right_value asymmetry_pct
#>   <chr>     <chr>        <int>   <int>      <dbl>       <dbl>         <dbl>
#> 1 mean      grid            36      36       1.77        1.55          13.4

# Intensity-only comparison, ignoring how much area each side loaded:
pr_calc_symmetry_map(trial, denominator = "loaded")$asymmetry_pct
#> [1] 13.07347
```
