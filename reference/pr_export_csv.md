# Export Analysis Results to CSV

Export Analysis Results to CSV

## Usage

``` r
pr_export_csv(
  trial,
  path,
  what = c("summary", "regional", "pressure", "cop"),
  masks = NULL
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- path:

  Character. Output file path.

- what:

  Character. `"summary"` (default), `"regional"`, `"pressure"`, or
  `"cop"`.

- masks:

  Named list of masks. Required for `what = "regional"`.

## Value

Invisibly returns the written file path.

## Details

Existing outputs are replaced only after writing succeeds. Reported
replacement failures restore the old output or report a retained backup
path. Source recordings, directories and symbolic-link destinations are
refused. This does not provide a transaction against process termination
or concurrent writers. Use
[`pr_write_bundle()`](https://cttir.github.io/pressR/reference/pr_write_bundle.md)
for exact numeric preservation; decimal CSV is an exchange format and
may change the last bits of floating-point values.

## Examples

``` r
tmp <- tempfile(fileext = ".csv")
pr_export_csv(pr_example_trial("insole"), tmp, what = "summary")
```
