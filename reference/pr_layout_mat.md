# Get Generic Sensor Mat Layout

Returns a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md) for a
generic capacitive pressure sensor mat. These general-purpose sensor
arrays are used in research, seating, sports, and ergonomics
applications.

## Usage

``` r
pr_layout_mat(size = c("16", "32"))
```

## Arguments

- size:

  Character. `"16"` (default) for 16x16 = 256 sensors or `"32"` for
  32x32 = 1024 sensors.

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
with no predefined regions.
