# Loop Geometry of a COP Trajectory

Describes a centre-of-pressure trajectory as a loop: how far its end
lands from its start, and whether the path crosses itself on the way.

## Usage

``` r
pr_cop_shape(cop, close = TRUE)
```

## Arguments

- cop:

  A `pr_cop` object from
  [`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md),
  or a data frame with `x`/`y` columns, or one with `cop_row`/`cop_col`
  columns as returned by
  [`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md)
  and
  [`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
  (`cop_col` is treated as x, `cop_row` as y).

- close:

  Logical. Append the first point to the end before looking for
  crossings. Default `TRUE`.

## Value

A one-row
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `n_points` (integer, after dropping missing coordinates),
`path_length`, `closure_dist`, `closure_ratio`
(`closure_dist / path_length`, `NA` for a stationary trajectory),
`self_intersects` (logical) and `n_crossings` (integer).

## Details

A stride that returns the rider to where they began traces a closed
loop, and how that loop is shaped separates a clean, repeatable seat
from a wandering one. Two numbers capture most of it:

- `closure_dist` — the straight-line distance from the last point back
  to the first, in whatever units the trajectory carries. Small relative
  to the path travelled means the trajectory came home.

- `n_crossings` — how many times the path cuts through itself. A simple
  oval crosses zero times; a figure-of-eight crosses once; a trajectory
  that scribbles crosses many times. `self_intersects` is
  `n_crossings > 0`.

With `close = TRUE` (default) the first point is appended to the end
before the crossing sweep, so the closing chord counts as part of the
loop — the right question for a cycle that should repeat. With
`close = FALSE` only the path as travelled is examined. Either way
`closure_dist` and `path_length` describe the open trajectory.

Crossings are counted with orientation tests on every pair of
non-adjacent segments, an exact predicate with no tolerance to tune. Two
segments that merely touch end to end, or that overlap along a line, are
not counted; only a genuine transverse crossing is. The sweep is
quadratic in the number of points, which is immaterial for one stride
and worth remembering before feeding it a whole recording.

Units are the input's own and nothing is converted: a `pr_cop` from
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
is in millimetres, while `cop_row`/`cop_col` from
[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md)
or
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
are in grid index units, so `path_length` and `closure_dist` follow
suit. `closure_ratio` is dimensionless and comparable across both.

Missing coordinates are dropped pairwise before anything is measured —
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
returns `NA` for unloaded frames.

## See also

[`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md)
and
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
for trajectories in grid units,
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
for millimetres.

Other temporal structure functions:
[`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md),
[`pr_calc_phase_map()`](https://cttir.github.io/pressR/reference/pr_calc_phase_map.md),
[`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md),
[`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md)

## Examples

``` r
# A clean rectangle: comes home, never crosses itself.
square <- data.frame(x = c(0, 1, 1, 0), y = c(0, 0, 1, 1))
pr_cop_shape(square)
#> # A tibble: 1 × 6
#>   n_points path_length closure_dist closure_ratio self_intersects n_crossings
#>      <int>       <dbl>        <dbl>         <dbl> <lgl>                 <int>
#> 1        4           3            1         0.333 FALSE                     0

# A bow tie crosses once.
bow <- data.frame(x = c(0, 1, 0, 1), y = c(0, 0, 1, 1))
pr_cop_shape(bow)$n_crossings
#> [1] 1

# One stride of a real trajectory, in grid index units:
trial <- pr_example_trial("saddle_horse")
cycles <- pr_calc_stride_cycles(trial)
cop <- pr_calc_cop_grid(trial)
pr_cop_shape(cop[cycles$start_idx[1]:cycles$end_idx[1], ])
#> # A tibble: 1 × 6
#>   n_points path_length closure_dist closure_ratio self_intersects n_crossings
#>      <int>       <dbl>        <dbl>         <dbl> <lgl>                 <int>
#> 1       33        8.77        0.375        0.0427 TRUE                      9
```
