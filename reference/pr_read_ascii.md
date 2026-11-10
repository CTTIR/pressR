# Read ASCII Pressure Data Export

Parses ASCII data files containing pressure sensor data. Automatically
detects header format and extracts metadata, the pressure matrix, and
timing.

## Usage

``` r
pr_read_ascii(
  path,
  layout = NULL,
  sampling_hz = NULL,
  separator = "auto",
  skip = NULL,
  verbose = TRUE
)
```

## Arguments

- path:

  Character. Path to the ASCII file (`.asc`, `.txt`).

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object. If `NULL`, inferred from the header or sensor count.

- sampling_hz:

  Numeric. Sampling rate (Hz). If `NULL`, taken from the header or
  defaulted to 50.

- separator:

  Character. Column separator. `"auto"` (default) detects
  tab/space/comma/semicolon.

- skip:

  Integer. Header lines to skip. If `NULL`, auto-detected.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object.

## Numeric text

Numeric text is qualified for nonzero magnitudes from `1e-290` to
`1e290`. Values outside this range, or inconsistent decimal conversions,
are refused. CSV does not carry layout calibration or promise bit-exact
doubles; provide the original layout, or use
[`pr_write_bundle()`](https://cttir.github.io/pressR/reference/pr_write_bundle.md)
for a self-contained round trip. The actual source path, basename and
SHA-256 are retained in trial metadata.

## Examples

``` r
path <- pr_example_files("insole")
trial <- pr_read_ascii(path, verbose = FALSE)
trial$n_frames
#> [1] 250
```
