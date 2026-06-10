# Get Pressure Platform Layout

Returns a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md) for a
barefoot pressure platform. Provides high-resolution plantar pressure
distribution during static and dynamic conditions.

## Usage

``` r
pr_layout_platform(model = c("st", "xl", "cl"))
```

## Arguments

- model:

  Character. Platform model: `"st"` (standard, default), `"xl"`
  (extended length), or `"cl"` (clinical/compact).

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
object. Region masks are not predefined — use
[`pr_mask_foot_auto()`](https://cttir.github.io/pressR/reference/pr_mask_foot_auto.md)
to auto-segment footprints from the data.

## Examples

``` r
layout <- pr_layout_platform()
layout$grid_rows
#> [1] 64
layout$grid_cols
#> [1] 40
```
