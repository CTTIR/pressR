# Regional Parameter Comparison Bar Chart

Regional Parameter Comparison Bar Chart

## Usage

``` r
pr_plot_regional_bar(regional_data, parameter = "mpp", thresholds = NULL)
```

## Arguments

- regional_data:

  Output of
  [`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md).

- parameter:

  Character. Parameter column to plot. Default `"mpp"`.

- thresholds:

  A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
  from `pr_ref_*()` functions. If non-`NULL`, draws horizontal threshold
  lines where `parameter` matches.

## Value

A `ggplot2` object.

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
reg <- pr_calc_regional(trial)
pr_plot_regional_bar(reg, "mpp")
```
