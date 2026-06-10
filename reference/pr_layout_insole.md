# Get In-Shoe Pressure Insole Layout

Returns a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
representing a typical in-shoe pressure measurement insole. The insole
contains 99 capacitive sensors arranged in an anatomically shaped grid.

## Usage

``` r
pr_layout_insole(size = c("standard", "wide"))
```

## Arguments

- size:

  Character. Insole size variant: `"standard"` (default) or `"wide"`
  (wider shoe insole with broader sensor spacing).

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
object with predefined foot region masks.

## Examples

``` r
layout <- pr_layout_insole()
print(layout)
#> 
#> ── pr_layout: insole_standard ──────────────────────────────────────────────────
#> In-shoe pressure insole (99 sensors, standard).
#> • Manufacturer: ""
#> • Model: "insole"
#> • Grid: 18 x 8
#> • Active sensors: 99
#> • Sensor area: 1.5 cm²
#> • Pressure range: 0 - 1200 kPa
#> • Regions: 7
#> Region names: "heel", "midfoot", "metatarsal_1", "metatarsal_2_3",
#> "metatarsal_4_5", "hallux", and "lesser_toes"
```
