# Plot Pressure Heatmap with Region Overlay

Convenience wrapper for
[`pr_plot_heatmap()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap.md)
that always overlays region boundaries.

## Usage

``` r
pr_plot_heatmap_masked(
  trial,
  masks = NULL,
  frame = NULL,
  type = c("mpp", "mvp", "pti", "contact"),
  palette = "viridis",
  range = NULL,
  title = NULL
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  Named list of
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
  or logical matrices. If `NULL`, uses layout regions.

- frame:

  Integer. Frame number to display. If `NULL` (default), shows the
  summary picture specified by `type`.

- type:

  Character. Summary type when `frame` is `NULL`: `"mpp"` (max), `"mvp"`
  (mean), `"pti"` (pressure-time integral), `"contact"` (contact
  frequency).

- palette:

  Character. One of `"viridis"` (default), `"inferno"`, `"plasma"`,
  `"magma"`, `"jet"`, `"classic"`.

- range:

  Numeric vector of length 2. Colour range. `NULL` auto-scales.

- title:

  Character. Plot title. `NULL` auto-generates.

## Value

A `ggplot2` object.

## Examples

``` r
pr_plot_heatmap_masked(pr_example_trial("saddle_horse"))
```
