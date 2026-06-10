# Read Force Sensor Data

Parses a CSV file containing force data from a portable force-sensing
insole or similar device. These systems typically record a small number
of force zones (not a full pressure matrix); this parser returns a
simplified
[pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md) where
each "sensor" represents a force zone. Pressure values are reported in
Newtons.

## Usage

``` r
pr_read_forcesensor(path, force_cols = NULL, time_col = "time", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the CSV file.

- force_cols:

  Character vector. Names of force columns. If `NULL`, all numeric
  columns other than the first (time) column are used.

- time_col:

  Character. Name of the time column. Default `"time"`.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object with a minimal single-row layout (one sensor per force zone).

## Examples

``` r
tmp <- tempfile(fileext = ".csv")
df <- data.frame(time = seq(0, 1, by = 0.01),
                 heel = runif(101, 0, 200),
                 mid  = runif(101, 0, 150),
                 fore = runif(101, 0, 300))
utils::write.csv(df, tmp, row.names = FALSE)
trial <- pr_read_forcesensor(tmp, verbose = FALSE)
trial$n_sensors
#> [1] 3
```
