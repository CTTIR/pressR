# Generate an Analysis Report

Renders a parameterized R Markdown template into an HTML or PDF report
for a trial.

## Usage

``` r
pr_export_report(
  trial,
  output_file,
  format = c("html", "pdf"),
  template = c("generic", "saddle", "foot"),
  masks = NULL,
  thresholds = NULL
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- output_file:

  Character. Output file path.

- format:

  Character. `"html"` (default) or `"pdf"`.

- template:

  Character. `"generic"` (default), `"saddle"`, or `"foot"`.

- masks:

  Named list of masks. `NULL` uses the layout defaults.

- thresholds:

  Optional reference threshold tibble.

## Value

Invisibly returns the generated file path.

## Examples

``` r
if (FALSE) { # \dontrun{
tmp <- tempfile(fileext = ".html")
pr_export_report(pr_example_trial("insole"), tmp, template = "foot")
} # }
```
