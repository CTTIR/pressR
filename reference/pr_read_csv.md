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

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object. Required for wide format when the sensor count cannot be
  inferred.

- time_col:

  Character. Name of the time column. If `NULL`, timestamps are
  generated from `sampling_hz`.

- sampling_hz:

  Numeric. Sampling rate. Default `100`.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object.

## Examples

``` r
tmp <- tempfile(fileext = ".csv")
m <- matrix(runif(10 * 99, 0, 100), nrow = 10, ncol = 99)
utils::write.csv(m, tmp, row.names = FALSE)
trial <- pr_read_csv(tmp, format = "wide", layout = pr_layout_insole(),
                     verbose = FALSE)
trial$n_frames
#> [1] 10
```
