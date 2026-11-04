# Read Pressure Data from CSV

Reads pressure data from a CSV file in either wide (one column per
sensor) or long (tidy) format.

## Usage

``` r
pr_read_csv(
  path,
  format = c("wide", "long"),
  layout = NULL,
  time_col = NULL,
  sampling_hz = 100,
  verbose = TRUE
)
```

## Arguments

- path:

  Character. Path to CSV file.

- format:

  Character. `"wide"` (default, columns are sensors) or `"long"` (a tidy
  format with `frame`, `sensor_id`, `pressure`).

- layout:

  A
  [pr_layout](https://cttir.github.io/pressR/dev/reference/pr_layout.md)
  object. Required for wide format when the sensor count cannot be
  inferred. Declared long-format sensor IDs or wide `s<number>` column
  names must match the supplied or inferred layout; measurements are
  aligned to its sensor order. Other wide column names retain positional
  order.

- time_col:

  Character. Name of the time column. If `NULL`, the exported `time`
  column is recognized automatically; otherwise timestamps are generated
  from `sampling_hz`.

- sampling_hz:

  Numeric. Used when timestamps are absent (default `100`). With
  timestamps, the rate is inferred unless explicitly supplied; conflicts
  with measured timing are rejected.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
object.

## Numeric text

Numeric text is qualified for nonzero magnitudes from `1e-290` to
`1e290`. Values outside this range, or inconsistent decimal conversions,
are refused. CSV does not carry layout calibration or promise bit-exact
doubles; provide the original layout, or use
[`pr_write_bundle()`](https://cttir.github.io/pressR/dev/reference/pr_write_bundle.md)
for a self-contained round trip. The actual source path, basename and
SHA-256 are retained in trial metadata.

## Examples

``` r
tmp <- tempfile(fileext = ".csv")
m <- matrix(runif(10 * 99, 0, 100), nrow = 10, ncol = 99)
utils::write.csv(m, tmp, row.names = FALSE)
trial <- pr_read_csv(tmp,
  format = "wide", layout = pr_layout_insole(),
  verbose = FALSE
)
trial$n_frames
#> [1] 10
```
