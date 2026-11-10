# Center of Pressure Object

Construct a `pr_cop` object from x/y coordinates and time. Normally
created by
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
rather than called directly.

## Usage

``` r
pr_cop(x, y, time)
```

## Arguments

- x:

  Numeric vector of COP x-coordinates (mm).

- y:

  Numeric vector of COP y-coordinates (mm).

- time:

  Numeric vector of timestamps (s).

## Value

A `pr_cop` S3 object with fields `x`, `y`, `time`, `path_length`,
`velocity_mean`, `velocity_max`, `range_x`, `range_y`, `sway_area`.
Trajectory segments require adjacent valid frames; the mean velocity is
total distance divided by observed segment duration.

## Examples

``` r
t <- seq(0, 1, by = 0.1)
cop <- pr_cop(x = 10 * sin(2 * pi * t), y = 50 * t, time = t)
cop
#> 
#> ── pr_cop ──
#> 
#> • Frames: 11
#> • Path length: 65.59 mm
#> • Mean velocity: 65.59 mm/s
#> • Max velocity: 77.17 mm/s
#> • Range (x): 19.02 mm
#> • Range (y): 50 mm
#> • Sway area (95% ellipse): 1665.5 mm^2
cop$path_length
#> [1] 65.5886
```
