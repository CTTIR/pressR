# Filter a Dataset by Trial Metadata, With Count Assertions

Keeps the trials whose metadata satisfy a predicate, records the filter
label on the returned dataset, and — when `n_units` or `n_subjects` are
given — asserts that the surviving cohort has exactly the expected size.
The assertion is the point: a cohort step that cannot fail cannot
protect a result.

## Usage

``` r
pr_dataset_filter(
  dataset,
  f,
  label = NULL,
  n_units = NULL,
  n_subjects = NULL,
  subject_field = "ID"
)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- f:

  A predicate applied to each trial's `metadata` list. Either a function
  of one argument, or a one-sided formula such as `~ .x$Mode == "MS"`.
  It must return a single `TRUE`/`FALSE` per trial; `NA` is treated as
  `FALSE` with a warning.

- label:

  Character. Short name for this filter, stored on the result as
  `filter_label` and appended to `filter_history`, and used in assertion
  messages. Default `NULL` uses `"filter"`.

- n_units:

  Integer. Expected number of trials after filtering, or `NULL`
  (default) for no assertion.

- n_subjects:

  Integer. Expected number of distinct subjects after filtering, or
  `NULL` (default) for no assertion.

- subject_field:

  Character. Metadata field identifying the subject. Default `"ID"`.

## Value

A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
containing the surviving trials, with extra elements `filter_label` and
`filter_history`.

## See also

Other cohort functions:
[`pr_assert_cohort()`](https://cttir.github.io/pressR/reference/pr_assert_cohort.md),
[`pr_design_table()`](https://cttir.github.io/pressR/reference/pr_design_table.md),
[`pr_validate_dataset()`](https://cttir.github.io/pressR/reference/pr_validate_dataset.md)

## Examples

``` r
layout <- pr_layout_mat("16")
mk <- function(id, mode) {
  pr_trial(matrix(1, 3, layout$n_sensors), time = c(0, 0.02, 0.04),
           layout = layout, metadata = list(ID = id, Mode = mode))
}
ds <- pr_dataset(list(mk("ID001", "MS"), mk("ID001", "MH"),
                      mk("ID002", "MS")))
walk <- pr_dataset_filter(ds, ~ .x$Mode == "MS", label = "walk",
                          n_units = 2, n_subjects = 2)
walk$filter_label
#> [1] "walk"
```
