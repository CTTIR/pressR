# Cohort Design Table

Reduces a
[pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md) to
one row per trial: the chosen metadata fields plus `n_frames` and
`duration_s`. This is the study design as a table — the object you
count, cross-tabulate, and assert against with
[`pr_assert_cohort()`](https://cttir.github.io/pressR/reference/pr_assert_cohort.md).

## Usage

``` r
pr_design_table(dataset, fields = NULL)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- fields:

  Character vector of metadata field names to include, in the order
  given. `NULL` (default) auto-detects: every metadata field that holds
  a single value in every trial, dropping fields that are missing (`NA`)
  throughout — which removes the empty `pr_trial` defaults such as
  `notes`. Fields named `n_frames` or `duration_s` are dropped in auto
  mode and rejected when named explicitly, because both columns are
  recomputed from the trial itself.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per trial and columns `fields`, `n_frames` (integer) and
`duration_s` (numeric).

## Details

`duration_s` is the trial's `duration` field, i.e. `diff(range(time))`,
so a 23432-frame recording at 50 Hz gives 468.62 s (not 468.64 s).

## See also

Other cohort functions:
[`pr_assert_cohort()`](https://cttir.github.io/pressR/reference/pr_assert_cohort.md),
[`pr_dataset_filter()`](https://cttir.github.io/pressR/reference/pr_dataset_filter.md),
[`pr_validate_dataset()`](https://cttir.github.io/pressR/reference/pr_validate_dataset.md)

## Examples

``` r
layout <- pr_layout_mat("16")
mk <- function(id, mode, n) {
  pr_trial(
    matrix(1, n, layout$n_sensors),
    time = seq(0, (n - 1) / 50, by = 1 / 50),
    layout = layout,
    metadata = list(ID = id, Mode = mode)
  )
}
ds <- pr_dataset(list(mk("ID001", "MS", 4), mk("ID002", "MH", 6)))
pr_design_table(ds, fields = c("ID", "Mode"))
#> # A tibble: 2 × 4
#>   ID    Mode  n_frames duration_s
#>   <chr> <chr>    <int>      <dbl>
#> 1 ID001 MS           4       0.06
#> 2 ID002 MH           6       0.1 
```
