# Standard 6-Region Saddle Mask

Creates the 6-region saddle pressure analysis mask dividing the sensor
mat into cranial / middle / caudal thirds crossed with left / right
halves, as established by Werner et al. (2002) and used in subsequent
equine back-pressure studies.

## Usage

``` r
pr_mask_saddle_6(layout)
```

## Arguments

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object (typically one returned by
  [`pr_layout_saddle()`](https://cttir.github.io/pressR/reference/pr_layout_saddle.md)
  with `type = "horse"`).

## Value

Named list of 6
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects.

## Examples

``` r
pr_mask_saddle_6(pr_layout_saddle("horse"))
#> $cranial_left
#> 
#> ── pr_mask: cranial_left ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 36
#> 
#> $cranial_right
#> 
#> ── pr_mask: cranial_right ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 36
#> 
#> $middle_left
#> 
#> ── pr_mask: middle_left ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 40
#> 
#> $middle_right
#> 
#> ── pr_mask: middle_right ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 40
#> 
#> $caudal_left
#> 
#> ── pr_mask: caudal_left ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 48
#> 
#> $caudal_right
#> 
#> ── pr_mask: caudal_right ──
#> 
#> • Layout: "saddle_horse"
#> • Grid: 16 x 16
#> • Sensors covered: 48
#> 
```
