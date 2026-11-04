# Create a Pressure Sensor Layout

Defines the physical arrangement of sensors in a pressure measurement
system, including grid dimensions, active sensor positions, physical
coordinates, and named region masks.

## Usage

``` r
pr_layout(
  grid_rows,
  grid_cols,
  active,
  coords_mm,
  regions = list(),
  sensor_area_cm2 = 1,
  pressure_range = c(0, 600),
  pressure_unit = "kPa",
  name = "custom",
  description = "",
  manufacturer = "",
  model = ""
)
```

## Arguments

- grid_rows:

  Integer. Number of rows in the sensor grid.

- grid_cols:

  Integer. Number of columns in the sensor grid.

- active:

  Logical matrix of dimensions `grid_rows x grid_cols`. `TRUE` for cells
  that contain active sensors.

- coords_mm:

  Data frame with columns `sensor_id` (integer), `row` (integer), `col`
  (integer), `x_mm` (numeric), `y_mm` (numeric). Physical coordinates of
  each active sensor in millimeters.

- regions:

  Named list of logical matrices (same dims as `active`). Each entry
  defines an anatomical or functional region.

- sensor_area_cm2:

  Numeric. Area of a single sensor cell in cm².

- pressure_range:

  Numeric vector of length 2. Min and max measurable pressure in kPa.

- pressure_unit:

  Character. Unit of pressure measurement. Default `"kPa"`.

- name:

  Character. Short identifier for this layout (e.g.,
  `"insole_standard"`).

- description:

  Character. Human-readable description.

- manufacturer:

  Character. Sensor manufacturer. Default `""`.

- model:

  Character. Sensor model/system name.

## Value

A `pr_layout` S3 object (list with class attribute).

## Examples

``` r
active <- matrix(TRUE, 4, 4)
coords <- data.frame(
  sensor_id = seq_len(16),
  row = rep(1:4, each = 4),
  col = rep(1:4, times = 4),
  x_mm = rep(seq(0, 30, 10), times = 4),
  y_mm = rep(seq(0, 30, 10), each = 4)
)
layout <- pr_layout(4, 4, active, coords, name = "example_4x4")
print(layout)
#> 
#> ── pr_layout: example_4x4 ──────────────────────────────────────────────────────
#> • Manufacturer: ""
#> • Model: ""
#> • Grid: 4 x 4
#> • Active sensors: 16
#> • Sensor area: 1 cm²
#> • Pressure range: 0 - 600 kPa
#> • Regions: 0
```
