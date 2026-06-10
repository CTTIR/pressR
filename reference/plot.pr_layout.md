# Plot a Sensor Layout

Visualizes a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
showing active sensor positions and colored region masks (if any).

## Usage

``` r
# S3 method for class 'pr_layout'
plot(x, show_regions = TRUE, show_ids = FALSE, ...)
```

## Arguments

- x:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object.

- show_regions:

  Logical. If `TRUE` (default), draws region masks in colors. If
  `FALSE`, shows only sensor positions.

- show_ids:

  Logical. If `TRUE`, labels each sensor with its id. Default `FALSE`.

- ...:

  Not used.

## Value

A `ggplot2` object.

## Examples

``` r
plot(pr_layout_saddle("horse"))
```
