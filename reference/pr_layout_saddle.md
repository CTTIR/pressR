# Get Saddle Pressure Mat Layout

Returns a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md) for
saddle pressure measurement using a capacitive sensor mat. Includes
predefined region masks based on published research protocols.

## Usage

``` r
pr_layout_saddle(type = c("horse", "bicycle"))
```

## Arguments

- type:

  Character. `"horse"` (default) for equine saddle fitting with 6-region
  mask (cranial / middle / caudal x left / right per Werner et al.
  2002), or `"bicycle"` for bicycle saddle with ischial/perineal
  regions.

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
with application-specific region masks.

## Examples

``` r
layout <- pr_layout_saddle("horse")
names(layout$regions)
#> [1] "cranial_left"  "cranial_right" "middle_left"   "middle_right" 
#> [5] "caudal_left"   "caudal_right" 
```
