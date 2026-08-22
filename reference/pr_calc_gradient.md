# Spatial Pressure Gradient Magnitude

How sharply pressure changes from one sensor to its neighbours. The
per-sensor map produced by
[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
is arranged back onto the device grid, differenced in both directions,
and returned as one gradient magnitude per sensor.

## Usage

``` r
pr_calc_gradient(
  trial,
  statistic = "mean",
  method = "central",
  edges = c("na", "zero"),
  threshold = 0
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- statistic:

  Character. The per-sensor map to differentiate; any statistic accepted
  by
  [`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md).
  Default `"mean"`, which is the cohort definition.

- method:

  Character. `"central"` (default) or `"forward"`; see *Details*.

- edges:

  Character. `"na"` (default) or `"zero"`; see *The edge ring*.

- threshold:

  Numeric. Cells at or below this value count as unloaded; passed to
  [`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md).
  Default `0`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per sensor, in the same column-major grid order as
[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md),
and columns `sensor` (integer), `row`, `col` (integer grid indices) and
`gradient` (numeric).

## Details

For a grid `M` of per-sensor values, `method = "central"` computes
\$\$g\_{r,c} = \sqrt{\left(\frac{M\_{r+1,c}-M\_{r-1,c}}{2}\right)^2 +
\left(\frac{M\_{r,c+1}-M\_{r,c-1}}{2}\right)^2}\$\$ and
`method = "forward"` uses the one-sided differences
`M[r+1, c] - M[r, c]` and `M[r, c+1] - M[r, c]` instead. Central
differences are symmetric and less noisy; forward differences reach one
cell further into the edge, which matters on a small grid.

The result is in the trial's pressure unit **per sensor spacing** — kPa
per cell step, not kPa/mm. Converting to kPa/mm needs a published cell
pitch, and the saddle mat has none (see the *Missing physical scale*
section of
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md)),
so no distance scaling is done anywhere in this function. Gradients are
therefore comparable across recordings on the same device and not across
devices with different pitches.

## The edge ring

A central difference needs a neighbour on both sides, so it is undefined
on the outermost row and column. The two `edges` settings differ only
there, and the interior is bit-for-bit identical either way:

- `edges = "na"` (default) leaves the ring `NA`. This is the honest
  answer: no gradient was computed for those cells.

- `edges = "zero"` fills the ring with `0`. This reproduces the cohort
  analysis, which wrote central differences for rows and columns
  `2:(n-1)` into a zero-initialised matrix and never revisited the
  border. On a 16x16 mat that makes 60 of 256 cells — nearly a quarter —
  a **structural zero** rather than a measurement. Use it to reproduce
  published numbers, but never average, rank or threshold over the whole
  grid with it: the mean gradient is biased down by a factor of roughly
  `196/256`, and "the lowest-gradient cells" will be the border, every
  time. `edges = "na"` with `na.rm = TRUE` gives the interior mean the
  zero-filled version was probably meant to be.

Cells the layout marks inactive are `NA` in the grid, so a gradient that
would have had to read one comes back `NA` under either setting.

## See also

[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
for the map being differentiated.

Other sensor quality functions:
[`pr_sensor_quality()`](https://cttir.github.io/pressR/reference/pr_sensor_quality.md)

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
g <- pr_calc_gradient(trial)
g[which.max(g$gradient), ]
#> # A tibble: 1 × 4
#>   sensor   row   col gradient
#>    <int> <int> <int>    <dbl>
#> 1     84     4     6     5.01

# The default leaves the border -- and the layout's inactive gullet
# cells -- missing ...
sum(is.na(g$gradient))
#> [1] 62
# ... while the cohort's zero-filled convention hides the border:
gz <- pr_calc_gradient(trial, edges = "zero")
sum(gz$gradient == 0, na.rm = TRUE)
#> [1] 56

# Same interior, different whole-grid mean:
c(interior = mean(g$gradient, na.rm = TRUE),
  filled = mean(gz$gradient, na.rm = TRUE))
#> interior   filled 
#> 1.660206 1.276026 
```
