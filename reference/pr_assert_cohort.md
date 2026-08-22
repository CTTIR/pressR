# Assert Cohort Size

Checks that a cohort holds exactly the expected number of units (trials
or rows) and, optionally, of distinct subjects. Aborts with a message
naming the expectation, the actual count, and the shortfall or surplus.

## Usage

``` r
pr_assert_cohort(
  x,
  n_units = NULL,
  n_subjects = NULL,
  unit_col = NULL,
  subject_col = NULL,
  label = NULL
)
```

## Arguments

- x:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects, or a data frame (for example the output of
  [`pr_design_table()`](https://cttir.github.io/pressR/reference/pr_design_table.md)).

- n_units:

  Integer. Expected number of units, or `NULL` to skip. A unit is a
  trial (dataset) or a row (data frame) unless `unit_col` names a
  field/column, in which case units are its distinct values.

- n_subjects:

  Integer. Expected number of distinct subjects, or `NULL` to skip.

- unit_col:

  Character. Field/column whose distinct values are the units. `NULL`
  (default) counts trials or rows.

- subject_col:

  Character. Field/column identifying the subject. `NULL` (default) uses
  the first of `"subject_id"` or `"ID"` that exists, and aborts if
  neither does.

- label:

  Character. Name of the cohort, used in messages. `NULL` (default) uses
  the dataset's `filter_label` or `name`, else `"cohort"`.

## Value

Invisibly returns `x`, so the assertion can sit in a pipeline. Aborts
with condition class `pr_cohort_assert_failed` on mismatch.

## Details

Use it as a tripwire around every step that can silently drop data —
reading a directory, filtering, joining. A guard that has never fired
proves nothing, so give it the real numbers from your design.

## See also

Other cohort functions:
[`pr_dataset_filter()`](https://cttir.github.io/pressR/reference/pr_dataset_filter.md),
[`pr_design_table()`](https://cttir.github.io/pressR/reference/pr_design_table.md),
[`pr_validate_dataset()`](https://cttir.github.io/pressR/reference/pr_validate_dataset.md)

## Examples

``` r
design <- data.frame(
  ID = c("ID001", "ID001", "ID002"),
  Mode = c("MS", "MH", "MS")
)
pr_assert_cohort(design, n_units = 3, n_subjects = 2, subject_col = "ID")

# A wrong expectation fails loudly:
try(pr_assert_cohort(design, n_units = 431, label = "all recordings"))
#> Error in pr_assert_cohort(design, n_units = 431, label = "all recordings") : 
#>   Cohort assertion failed for "all recordings": expected 431 rows, found
#> 3.
#> ✖ 428 fewer than expected.
#> ℹ Either the expectation is stale or trials were dropped upstream; do not relax
#>   the expectation without finding out which.
```
