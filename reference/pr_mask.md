# Create a Region Mask

Wraps a logical matrix describing a named region over a sensor layout.

## Usage

``` r
pr_mask(mask_matrix, name, layout)
```

## Arguments

- mask_matrix:

  Logical matrix matching the dimensions of `layout$active`.

- name:

  Character. Region name.

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object this mask applies to.

## Value

A `pr_mask` S3 object.

## Examples

``` r
layout <- pr_layout_saddle("horse")
m <- layout$regions$cranial_left
pr_mask(m, "cranial_left", layout)
#> 
#> ── pr_mask: cranial_left ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 36
```
