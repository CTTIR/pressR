# Batch Summary Across Multiple Trials

Runs
[`pr_summary()`](https://cttir.github.io/pressR/reference/pr_summary.md)
on each trial in a dataset and row-binds the results, prepending trial
metadata columns.

## Usage

``` r
pr_batch_summary(dataset)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per trial.

## Examples

``` r
ds <- pr_dataset(list(
  pr_example_trial("insole", seed = 1),
  pr_example_trial("insole", seed = 2)
))
pr_batch_summary(ds)
#> # A tibble: 2 × 20
#>   subject_id trial_id   condition system n_frames duration   mpp   mvp max_force
#>   <chr>      <chr>      <chr>     <chr>     <int>    <dbl> <dbl> <dbl>     <dbl>
#> 1 EX01       insole_ga… walking   insole      250        5  656.  43.4     1451.
#> 2 EX01       insole_ga… walking   insole      250        5  651.  43.2     1451.
#> # ℹ 11 more variables: mean_force <dbl>, max_contact_area <dbl>,
#> #   mean_contact_area <dbl>, contact_time <dbl>, pti_max <dbl>, pti_mean <dbl>,
#> #   impulse <dbl>, cop_path_length <dbl>, cop_velocity_mean <dbl>,
#> #   cop_range_ap <dbl>, cop_range_ml <dbl>
```
