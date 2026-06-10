# Left/Right Symmetry Plot

Left/Right Symmetry Plot

## Usage

``` r
pr_plot_symmetry(
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
  `"contact_area"`.

## Value

A `ggplot2` object with a mirrored bar chart.

## Examples

``` r
pr_plot_symmetry(pr_example_trial("saddle_horse"))
```
