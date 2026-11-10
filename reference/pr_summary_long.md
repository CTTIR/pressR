# Summarize Measurements With Explicit Units and Availability

Summarize Measurements With Explicit Units and Availability

## Usage

``` r
pr_summary_long(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

## Value

A long table with parameter, value, unit and status.

## Examples

``` r
pr_summary_long(pr_example_trial("insole"))
#> # A tibble: 14 × 4
#>    parameter           value unit  status   
#>    <chr>               <dbl> <chr> <chr>    
#>  1 mpp                643.   kPa   available
#>  2 mvp                 43.0  kPa   available
#>  3 max_force         1442.   N     available
#>  4 mean_force         290.   N     available
#>  5 max_contact_area   128.   cm2   available
#>  6 mean_contact_area   61.1  cm2   available
#>  7 contact_time         2.94 s     available
#>  8 pti_max            511.   kPa*s available
#>  9 pti_mean            97.5  kPa*s available
#> 10 impulse           1447.   N*s   available
#> 11 cop_path_length   1028.   mm    available
#> 12 cop_velocity_mean  350.   mm/s  available
#> 13 cop_range_ap       115.   mm    available
#> 14 cop_range_ml        10.8  mm    available
```
