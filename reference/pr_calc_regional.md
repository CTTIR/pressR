# Compute Parameters by Region

Applies region masks to a trial and computes summary parameters
independently for each region. Returns one row per region.

## Usage

``` r
pr_calc_regional(
  trial,
  masks = NULL,
  parameters = c("mpp", "mvp", "max_force", "contact_area", "pti_mean"),
  threshold = 0
)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  Named list of
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
  or logical matrices. If `NULL` (default), uses the layout's default
  regions.

- parameters:

  Character vector. Parameters to compute. Supported values: `"mpp"`,
  `"mvp"`, `"max_force"`, `"mean_force"`, `"contact_area"`, `"pti_max"`,
  `"pti_mean"`. Default
  `c("mpp", "mvp", "max_force", "contact_area", "pti_mean")`.

- threshold:

  Numeric. Default `0`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one column `region` plus one column per requested parameter.

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
pr_calc_regional(trial)
#> # A tibble: 6 × 6
#>   region          mpp   mvp max_force contact_area pti_mean
#>   <chr>         <dbl> <dbl>     <dbl>        <dbl>    <dbl>
#> 1 cranial_left   18.4  2.41     105.           330     17.7
#> 2 cranial_right  16.5  2.13      94.7          320     15.5
#> 3 middle_left    12.0  1.57      91.4          440     11.5
#> 4 middle_right   10.4  1.41      79.5          420     10.2
#> 5 caudal_left    18.3  2.27     106.           350     16.1
#> 6 caudal_right   15.6  2.00      91.9          360     14.2
```
