# Standard 6-Region Saddle Mask

Creates the 6-region saddle pressure analysis mask dividing the sensor
mat into cranial / middle / caudal thirds crossed with left / right
halves. This follows the six-mask scheme of Nyikos et al. (2005),
Pferdeheilkunde 21:187-198,
[doi:10.21836/PEM20050301](https://doi.org/10.21836/PEM20050301) ,
Methods and Fig. 1, p.189 (a cranial, middle and caudal third on each
half of the mat), the scheme behind the observations in
[`pr_ref_saddle()`](https://cttir.github.io/pressR/reference/pr_ref_saddle.md).

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

## Details

Rows are split with `floor(grid_rows / 3)` rows each for the cranial and
middle thirds; any remainder goes to the caudal third (5 / 5 / 6 on the
16-row saddle mat). As in
[`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md),
an odd centre column goes to the right half. Layouts with fewer than
three rows or two columns cannot be divided this way and are refused.

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
