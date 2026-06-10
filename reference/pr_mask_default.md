# Get Default Region Masks for a Layout

Returns a named list of
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
built from the `regions` field of a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md).

## Usage

``` r
pr_mask_default(layout)
```

## Arguments

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object.

## Value

Named list of
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
(possibly empty).

## Examples

``` r
masks <- pr_mask_default(pr_layout_saddle("horse"))
names(masks)
#> [1] "cranial_left"  "cranial_right" "middle_left"   "middle_right" 
#> [5] "caudal_left"   "caudal_right" 
```
