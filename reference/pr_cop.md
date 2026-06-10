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
