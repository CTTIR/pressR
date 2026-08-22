# Novel/Pliance 16x16 Saddle Mat Layout

The ready-made layout for the two-panel 16 x 16 (256 sensor) capacitive
saddle mat exported by Novel/Pliance systems. All 256 sensors are
active.

## Usage

``` r
pr_layout_saddle_novel(
  pressure_range = c(0, 63.75),
  sensor_area_cm2 = NA_real_,
  ...
)
```

## Arguments

- pressure_range:

  Numeric vector of length 2. Default `c(0, 63.75)` kPa, the hardware
  ceiling (255 x 0.25 kPa).

- sensor_area_cm2:

  Numeric. Cell area in cm²; `NA_real_` by default because the
  manufacturer never published one.

- ...:

  Further arguments passed to
  [`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md),
  e.g. `name`, `spacing_mm`, `description`, `regions`.

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
with 256 active sensors and a `channel_map` field.

## Details

The mat is built from two 16 x 8 panels. Device channel 1 sits at grid
(row 1, column 9) — the first cell of the *right* panel — and channel 9
at (row 1, column 8), with each grid row advancing the channel number by
16 and the left panel running right-to-left. Applying
`pressure[, pr_channel_order(layout)]` to a raw export therefore places
every channel at its true anatomical position, which is what makes
[`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md),
[`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md),
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
and the heatmaps simultaneously correct. Without the permutation the
aggregate statistics (mean, peak, total) are unchanged, so a wrong map
is invisible in every summary and wrong in every map.

No sensor pitch or cell area is published for this mat, so both default
to `NA` and the coordinates are grid indices — see the *Missing physical
scale* section of
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md).

## See also

Other channel map functions:
[`pr_channel_order()`](https://cttir.github.io/pressR/reference/pr_channel_order.md),
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md)

## Examples

``` r
layout <- pr_layout_saddle_novel()
layout$n_sensors
#> [1] 256
layout$channel_map[1, 1:10]
#>  [1] 16 15 14 13 12 11 10  9  1  2

# Device channel 1 lands at grid (row 1, col 9):
pos <- match(1L, pr_channel_order(layout))
layout$coords_mm[pos, c("row", "col")]
#> # A tibble: 1 × 2
#>     row   col
#>   <int> <int>
#> 1     1     9
```
