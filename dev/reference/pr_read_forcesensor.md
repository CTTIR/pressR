# Read Force Sensor Data

Parses a CSV file containing force data from a portable force-sensing
insole or similar device. These systems typically record a small number
of force zones (not a full pressure matrix); this parser returns a
simplified
[pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
where each "sensor" represents a force zone. Pressure values are
reported in Newtons.

## Usage

``` r
pr_read_forcesensor(path, force_cols = NULL, time_col = "time", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the CSV file.

- force_cols:

  Character vector. Names of force columns. If `NULL`, all columns other
  than the time column are used and must be numeric.

- time_col:

  Character. Name of the time column. Default `"time"`.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
object with a minimal single-row layout (one sensor per force zone).

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
df <- data.frame(
  time = seq(0, 1, by = 0.01),
  heel = runif(101, 0, 200),
  mid = runif(101, 0, 150),
  fore = runif(101, 0, 300)
)
utils::write.csv(df, tmp, row.names = FALSE)
trial <- pr_read_forcesensor(tmp, verbose = FALSE)
trial$n_sensors
#> [1] 3
```
