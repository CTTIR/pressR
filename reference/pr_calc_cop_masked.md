# Centre of Pressure Per Region

Computes one centre-of-pressure trajectory for each region mask,
weighted only by that region's sensors. Returns a list of
[pr_cop](https://cttir.github.io/pressR/reference/pr_cop.md) objects, so
the existing trajectory vocabulary — path length, mean and maximum
velocity, the x/y ranges
[`pr_calc_cop_excursion()`](https://cttir.github.io/pressR/reference/pr_calc_cop_excursion.md)
reports, and the 95% ellipse sway area — is available per region with no
further work.

## Usage

``` r
pr_calc_cop_masked(trial, masks = NULL, threshold = 0, units = c("grid", "mm"))
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  Named list of
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
  or logical matrices. `NULL` (default) uses the layout's own regions.

- threshold:

  Numeric. Cells at or below this value are given zero weight. Default
  `0`.

- units:

  Character. `"grid"` (default) or `"mm"`; see *Units*.

## Value

A named list of
[pr_cop](https://cttir.github.io/pressR/reference/pr_cop.md) objects,
one per mask, in the order the masks were given.

## Details

A whole-mat COP is a single point that can sit in an unloaded gap
between two loaded zones, and it moves whenever load shifts *between*
zones. A per-region COP cannot: it stays inside its own region and
reports how load migrated within it, which is what separates a saddle
that rocks fore-and-aft from one that slides sideways.

Frames in which a region carries no load at all get `NA` for both axes,
exactly as
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
does for the whole mat.
[`pr_cop()`](https://cttir.github.io/pressR/reference/pr_cop.md)
excludes those frames from the trajectory metrics, so a region that is
loaded only intermittently still reports a meaningful path length —
though one measured across the gaps, not through them.

## Units

`units = "grid"` (the default) returns grid index units: `x` is the
fractional sensor column, `y` the fractional sensor row, both 1-based,
in the convention of
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md).
This is always available.

`units = "mm"` returns the layout's physical `x_mm` / `y_mm`
coordinates, as
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
does. It is refused for a layout whose coordinates are grid indices
because no sensor pitch was ever published (see the *Missing physical
scale* section of
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md))
— millimetres would be fabricated, and a path length in fabricated
millimetres is worse than none.

Note that a `pr_cop` object labels its fields `mm` regardless; under
`units = "grid"` they are grid indices, and the derived path length and
velocity are in index units and index units per second.

## See also

[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
and
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md)
for the whole mat,
[`pr_calc_cop_excursion()`](https://cttir.github.io/pressR/reference/pr_calc_cop_excursion.md)
for the range summary.

Other regional symmetry functions:
[`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md),
[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md),
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md),
[`pr_mask_rowbands()`](https://cttir.github.io/pressR/reference/pr_mask_rowbands.md),
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
cops <- pr_calc_cop_masked(trial)
names(cops)
#> [1] "cranial_left"  "cranial_right" "middle_left"   "middle_right" 
#> [5] "caudal_left"   "caudal_right" 

# Each region's COP stays inside its own rows:
round(vapply(cops, function(c) mean(c$y, na.rm = TRUE), numeric(1)), 2)
#>  cranial_left cranial_right   middle_left  middle_right   caudal_left 
#>          3.80          3.79          8.50          8.49         13.25 
#>  caudal_right 
#>         13.26 

# The full pr_cop vocabulary works unchanged:
round(vapply(cops, function(c) c$path_length, numeric(1)), 3)
#>  cranial_left cranial_right   middle_left  middle_right   caudal_left 
#>        72.419        84.384       104.211       119.473        75.375 
#>  caudal_right 
#>        90.145 

# This layout has a real sensor pitch, so millimetres are honest:
round(pr_calc_cop_masked(trial, units = "mm")$cranial_left$range_x, 1)
#> [1] 26.8
```
