# Symmetry Index

Computes the symmetry index (SI%) between left and right sides of a
layout for a given parameter. `SI = (L - R) / (0.5 * (L + R)) * 100`.

## Usage

``` r
pr_calc_symmetry_index(
  trial,
  parameter = c("peak_pressure", "mean_pressure", "force", "contact_area")
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- parameter:

  Character. One of `"peak_pressure"`, `"mean_pressure"`, `"force"`,
  `"contact_area"`. Default `"peak_pressure"`.

## Value

Numeric scalar. Positive values indicate left dominance.

## Examples

``` r
pr_calc_symmetry_index(pr_example_trial("saddle_horse"))
#> [1] 10.75746
```
