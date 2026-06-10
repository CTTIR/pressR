# Spatial Interpolation of Pressure Data (for Display)

Performs bilinear interpolation on the maximum pressure picture between
active sensor positions to produce a smoother image. The underlying
trial data is not modified.

## Usage

``` r
pr_interpolate(trial, factor = 2L)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- factor:

  Integer. Interpolation factor in each dimension. Default `2`.

## Value

A list with `pressure_interp` (interpolated matrix), `x_mm`, `y_mm`.

## Examples

``` r
out <- pr_interpolate(pr_example_trial("insole"), factor = 2)
dim(out$pressure_interp)
#> [1] 35 15
```
