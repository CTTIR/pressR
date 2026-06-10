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

## Examples

``` r
tmp <- tempfile(fileext = ".csv")
pr_export_csv(pr_example_trial("insole"), tmp, what = "summary")
```
