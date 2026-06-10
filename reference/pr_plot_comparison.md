# Compare Two Trials

Produces a side-by-side heatmap comparison, a difference map, or a
parameter-table plot for two trials.

## Usage

``` r
pr_plot_comparison(
  trial_a,
  trial_b,
  type = c("heatmap", "difference", "parameters"),
  labels = c("A", "B")
)
```

## Arguments

- trial_a:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object. Reference.

- trial_b:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object. Comparison.

- type:

  Character. `"heatmap"` (default), `"difference"`, or `"parameters"`.

- labels:

  Character vector of length 2. Default `c("A", "B")`.

## Value

A `ggplot2` (or patchwork) object.

## Examples

``` r
a <- pr_example_trial("insole", seed = 1)
b <- pr_example_trial("insole", seed = 2)
pr_plot_comparison(a, b, type = "difference")
```
