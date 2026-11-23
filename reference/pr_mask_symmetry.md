# Split Layout into Left/Right Halves

Produces a two-element named list of
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
dividing the layout along the specified axis.

## Usage

``` r
pr_mask_symmetry(layout, axis = c("vertical", "horizontal"))
```

## Arguments

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object.

- axis:

  Character. `"vertical"` (default, split columns into left/right) or
  `"horizontal"` (split rows into anterior/posterior).

## Value

A named list of two
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects.

## Details

When the split axis has an odd number of grid lines, the centre line is
assigned to the second half (`right` or `posterior`), which then covers
one line more than the first. Every predefined layout has an even number
of rows and columns, so this only concerns custom layouts; use
[`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md)
for halves that are exact mirror images. Grids with a single line along
the split axis cannot be divided and are refused.

## Examples

``` r
pr_mask_symmetry(pr_layout_saddle("horse"))
#> $left
#> 
#> ── pr_mask: left ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 124
#> 
#> $right
#> 
#> ── pr_mask: right ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 124
#> 
```
