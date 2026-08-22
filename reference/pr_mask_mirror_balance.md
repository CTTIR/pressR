# Largest Mirror-Symmetric Subset of a Mask

Trims a region mask down to the cells whose mirror image across the
mat's midline is also in the mask. The result is symmetric by
construction, so a left/right comparison made on it cannot be an
artefact of one side simply owning more sensors than the other.

## Usage

``` r
pr_mask_mirror_balance(mask, layout, axis = c("vertical", "horizontal"))
```

## Arguments

- mask:

  A [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md)
  object or a logical matrix matching the layout grid.

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object.

- axis:

  Character. `"vertical"` (default) mirrors columns, i.e. left against
  right; `"horizontal"` mirrors rows, i.e. anterior against posterior.

## Value

A [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) object
carrying two extra fields: `axis`, and `halves`, a named integer vector
of the two sides' sensor counts, which are equal by construction.

## Details

This is the largest mirror-symmetric subset of the input: a cell
survives if and only if both it and its reflection were present, and no
mirror-symmetric superset of that set exists inside the mask. The two
halves of the result are exact reflections of each other, which is a
stronger guarantee than equal counts.

The reason to want it is that an asymmetry index divides by the mean of
the two sides. If the region of interest happens to contain more cells
on one side — because a sensor died, or because a data-driven mask was
built from a load pattern that is itself lopsided — then part of the
resulting index measures the mask, not the horse. In the study cohort,
dropping sensors that were flat for more than 95% of every recording
left 106 live cells on the left and 117 on the right; balancing to
106/106 moved the cohort median asymmetry from -30.5% to -39.0%, the
second of which agrees with the whole-grid figure and the first of which
does not.

Cells outside `layout$active` are never kept. When the axis has an odd
number of lines the centre line reflects onto itself and belongs to
neither half, so it is dropped; on an even grid (such as the 16 x 16
saddle mat) nothing is lost to this.

## See also

[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md),
which applies this across a family of masks.

Other regional symmetry functions:
[`pr_calc_cop_masked()`](https://cttir.github.io/pressR/reference/pr_calc_cop_masked.md),
[`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md),
[`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md),
[`pr_mask_rowbands()`](https://cttir.github.io/pressR/reference/pr_mask_rowbands.md),
[`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)

## Examples

``` r
layout <- pr_layout_saddle("horse")

# A deliberately lopsided region: all of the left half, but only three
# columns of the right.
m <- matrix(FALSE, 16, 16)
m[, 1:8] <- TRUE
m[, 9:11] <- TRUE
bal <- pr_mask_mirror_balance(m, layout)
bal$halves
#>  left right 
#>    44    44 

# The surviving columns are 6:11 -- the ones with a partner on both sides.
which(apply(bal$matrix, 2, any))
#> [1]  6  7  8  9 10 11
```
