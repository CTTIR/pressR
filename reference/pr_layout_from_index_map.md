# Build a Layout From an Explicit Channel Map

Creates a
[pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md) from
a matrix that states, for every grid cell, which *device channel* is
wired to it. This is the general answer to the problem that a sensor
mat's channel numbering rarely matches the order in which the grid is
read. The resulting layout carries the map with it, so
[`pr_channel_order()`](https://cttir.github.io/pressR/reference/pr_channel_order.md)
can hand a reader the one permutation that puts raw device columns into
the column-major grid order that
[`pr_mask()`](https://cttir.github.io/pressR/reference/pr_mask.md),
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
and the plotting functions already assume.

## Usage

``` r
pr_layout_from_index_map(
  index_matrix,
  name = "custom",
  sensor_area_cm2 = NA_real_,
  spacing_mm = NA_real_,
  pressure_range = NULL,
  ...
)
```

## Arguments

- index_matrix:

  Numeric matrix. `index_matrix[r, c]` is the device channel number
  sitting at grid cell (`r`, `c`). Channel numbers must be whole,
  positive and unique. `NA` or `0` marks a grid cell with no sensor
  behind it (that cell becomes inactive). If every cell is active the
  channel numbers must be exactly `1:length(index_matrix)`.

- name:

  Character. Short layout identifier. Default `"custom"`.

- sensor_area_cm2:

  Numeric. Area of one sensor cell in cm², or `NA_real_` (the default)
  when the manufacturer never published one. See *Missing physical
  scale* below.

- spacing_mm:

  Numeric. Centre-to-centre sensor pitch in mm, or `NA_real_` (the
  default) when it is unknown. See *Missing physical scale* below.

- pressure_range:

  Numeric vector of length 2, or `NULL` (default) for `c(0, NA_real_)` —
  a device whose ceiling is not known.

- ...:

  Further arguments passed to
  [`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md),
  e.g. `regions`, `description`, `manufacturer`, `model`,
  `pressure_unit`.

## Value

A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
object with three extra fields: `channel_map` (the validated integer
map, `NA` for empty cells), `channel_order` (the permutation returned by
[`pr_channel_order()`](https://cttir.github.io/pressR/reference/pr_channel_order.md))
and `coords_units`.

## Missing physical scale

[`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md)
requires a positive `sensor_area_cm2` and physical `x_mm` / `y_mm`
coordinates. Many real datasets have neither: the cell area and the
sensor pitch were simply never recorded. Rather than invent a number,
this function

- builds the object through
  [`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md)
  with a placeholder area and then writes `NA_real_` into
  `sensor_area_cm2`, so the layout stays a valid `pr_layout` and
  [`pr_validate_layout()`](https://cttir.github.io/pressR/reference/pr_validate_layout.md)
  still passes, while anything derived from area (force in N, contact
  area in cm²) honestly returns `NA`; and

- when `spacing_mm` is `NA`, lays the coordinates out on a unit grid
  (`x_mm = col - 1`, `y_mm = row - 1`). Ordering, masks and centre of
  pressure are then all correct, but **the `x_mm` / `y_mm` columns are
  grid-index offsets, not millimetres** — a COP of `x_mm = 8` means
  column 9, not 8 mm. The layout records this in `$coords_units`
  (`"grid_index"` or `"mm"`) and keeps the requested pitch in
  `$spacing_mm`.

Supply a real `sensor_area_cm2` / `spacing_mm` and the layout behaves as
a fully physical one. Note that
[`plot.pr_layout()`](https://cttir.github.io/pressR/reference/plot.pr_layout.md)
sizes region tiles from `sensor_area_cm2`, so pass `regions` only
alongside a real area.

## See also

Other channel map functions:
[`pr_channel_order()`](https://cttir.github.io/pressR/reference/pr_channel_order.md),
[`pr_layout_saddle_novel()`](https://cttir.github.io/pressR/reference/pr_layout_saddle_novel.md)

## Examples

``` r
# A 2x2 mat whose channels are wired right-to-left within each row.
m <- rbind(c(2L, 1L), c(4L, 3L))
lay <- pr_layout_from_index_map(m, name = "toy_2x2")
lay$n_sensors
#> [1] 4
pr_channel_order(lay)
#> [1] 2 4 1 3

# Raw device frame: only channel 1 is loaded.
raw <- matrix(c(10, 0, 0, 0), nrow = 1)
grid_cols <- raw[, pr_channel_order(lay), drop = FALSE]
# Channel 1 is at grid (1, 2), i.e. the 3rd cell in column-major order.
which(grid_cols[1, ] > 0)
#> [1] 3
```
