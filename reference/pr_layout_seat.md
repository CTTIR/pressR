# Get Seating Pressure Mat Layout

Returns a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md) for
seating pressure assessment. Uses a 32x32 grid (1024 sensors) with
application-specific regions.

## Usage

``` r
pr_layout_seat(type = c("wheelchair", "car", "office"))
```

## Arguments

- type:

  Character. `"wheelchair"` (default), `"car"`, or `"office"`.

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
object.
