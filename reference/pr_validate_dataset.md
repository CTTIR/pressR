# Validate Cohort Homogeneity

Checks that every trial in a dataset is analysable together: same sensor
count, same layout name, non-empty, and free of missing, infinite or
negative pressure values. Anything that would make a cohort-level
summary meaningless is reported per trial.

## Usage

``` r
pr_validate_dataset(dataset, strict = TRUE)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- strict:

  Logical. If `TRUE` (default), abort when any problem is found. If
  `FALSE`, warn and return the problem table.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per problem and columns `trial` (integer index),
`trial_label`, `check`, `expected`, `actual` and `problem`. Zero rows
means the cohort is homogeneous. When `strict = TRUE` and problems
exist, aborts with condition class `pr_dataset_invalid`, carrying the
same tibble in the condition's `problems` field.

## Details

The reference sensor count and layout name are the *modal* values across
the dataset (ties broken by first appearance), so a single odd recording
is flagged rather than the other 430.

## See also

Other cohort functions:
[`pr_assert_cohort()`](https://cttir.github.io/pressR/reference/pr_assert_cohort.md),
[`pr_dataset_filter()`](https://cttir.github.io/pressR/reference/pr_dataset_filter.md),
[`pr_design_table()`](https://cttir.github.io/pressR/reference/pr_design_table.md)

## Examples

``` r
layout <- pr_layout_mat("16")
mk <- function() {
  pr_trial(matrix(1, 3, layout$n_sensors), time = c(0, 0.02, 0.04),
           layout = layout)
}
pr_validate_dataset(pr_dataset(list(mk(), mk())))
#> # A tibble: 0 × 6
#> # ℹ 6 variables: trial <int>, trial_label <chr>, check <chr>, expected <chr>,
#> #   actual <chr>, problem <chr>

# A mixed-layout cohort is reported, not silently summarised:
odd <- pr_example_trial("insole")
problems <- pr_validate_dataset(pr_dataset(list(mk(), mk(), odd)),
                                strict = FALSE)
#> Warning: 2 cohort problems in 1 of 3 trials.
#> ✖ Trial 3 (insole_gait) - n_sensors: sensor count differs from the cohort (99
#>   vs 256)
#> ✖ Trial 3 (insole_gait) - layout_name: layout is 'insole_standard', cohort
#>   layout is 'mat_16'
problems$check
#> [1] "n_sensors"   "layout_name"
```
