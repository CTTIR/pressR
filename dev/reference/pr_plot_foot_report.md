# Foot Pressure Report Panel

Composite figure for foot pressure analysis: MPP map, regional bar
chart, force-time curve, COP trajectory.

## Usage

``` r
pr_plot_foot_report(trial, masks = NULL)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
  object from an insole or platform recording.

- masks:

  Optional explicit region masks.

## Value

A `patchwork` object.

## Examples

``` r
pr_plot_foot_report(pr_example_trial("insole"))
```
