# Row-Band Region Masks With an Explicit Split

Builds cranial / middle / caudal row bands (optionally crossed with the
left and right halves of the mat) from **stated** split rows rather than
from a derived `floor(grid_rows / 3)`. The split is the argument, so a
study's own band definition survives into the code instead of being
approximated by a division.

## Usage

``` r
pr_mask_rowbands(
  layout,
  breaks = c(5, 11),
  sides = TRUE,
  band_names = c("cranial", "middle", "caudal")
)
```

## Arguments

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object.

- breaks:

  Numeric vector of `length(band_names) - 1` strictly increasing whole
  numbers in `1:(grid_rows - 1)`. Each is the last row of its band.
  Default `c(5, 11)`.

- sides:

  Logical. Cross each band with the left and right halves of the mat.
  Default `TRUE`.

- band_names:

  Character vector of band names, cranial to caudal. Default
  `c("cranial", "middle", "caudal")`.

## Value

A named list of
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects:
`length(band_names)` of them when `sides = FALSE`, twice that when
`sides = TRUE`.

## Details

`breaks` gives the **last row of each band except the last**. With the
default `c(5, 11)` on a 16-row mat the bands are rows 1:5, 6:11 and
12:16 — the split used by
[`pr_layout_saddle()`](https://cttir.github.io/pressR/reference/pr_layout_saddle.md)'s
`regions`, in which the middle band is one row deeper than the outer
two.

[`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md)
uses `third <- floor(16 / 3)`, which gives 1:5, 6:10, 11:16 instead: the
*caudal* band is the deep one. Passing `breaks = c(5, 10)` reproduces
those cells exactly, with the same names in the same order, so the two
conventions can be compared rather than confused. Because that one-row
difference moves eight sensors between two zones, it is worth stating
which convention a number came from.

Left and right are split at `floor(grid_cols / 2)`, matching
[`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md)
and
[`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md).
With `sides = TRUE` the masks come back in band-major order
(`cranial_left`, `cranial_right`, `middle_left`, ...); with
`sides = FALSE` there is one full-width mask per band. Every mask is
intersected with `layout$active`, so inactive cells (a withers cutout,
say) never enter a band.

## See also

[`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md)
for the derived-thirds convention,
[`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md)
which consumes these masks.

Other regional symmetry functions:
[`pr_calc_cop_masked()`](https://cttir.github.io/pressR/reference/pr_calc_cop_masked.md),
[`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md),
[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md),
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md),
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)

## Examples

``` r
layout <- pr_layout_saddle("horse")
masks <- pr_mask_rowbands(layout)
names(masks)
#> [1] "cranial_left"  "cranial_right" "middle_left"   "middle_right" 
#> [5] "caudal_left"   "caudal_right" 
vapply(masks, function(m) m$n_sensors, integer(1))
#>  cranial_left cranial_right   middle_left  middle_right   caudal_left 
#>            36            36            48            48            40 
#>  caudal_right 
#>            40 

# breaks = c(5, 10) is the pr_mask_saddle_6() convention:
same <- pr_mask_rowbands(layout, breaks = c(5, 10))
identical(same$middle_left$matrix, pr_mask_saddle_6(layout)$middle_left$matrix)
#> [1] TRUE

# Full-width bands, no left/right split:
names(pr_mask_rowbands(layout, sides = FALSE))
#> [1] "cranial" "middle"  "caudal" 
```
