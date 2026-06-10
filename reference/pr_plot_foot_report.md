# Foot Pressure Report Panel

Composite figure for foot pressure analysis: MPP map, regional bar
chart, force-time curve, COP trajectory.

## Usage

``` r
pr_plot_foot_report(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object from an insole or platform recording.

## Value

A `patchwork` object.

## Examples

``` r
pr_plot_foot_report(pr_example_trial("insole"))
```
