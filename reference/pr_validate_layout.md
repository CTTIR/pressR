# Validate a Pressure Sensor Layout

Checks internal consistency of a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
object.

## Usage

``` r
pr_validate_layout(layout)
```

## Arguments

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object.

## Value

Invisibly returns `TRUE` if valid; otherwise throws an informative
error.

## Examples

``` r
pr_validate_layout(pr_layout_insole())
```
