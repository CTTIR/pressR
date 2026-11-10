# Status of Legacy Seating Reference Values

Status of Legacy Seating Reference Values

## Usage

``` r
pr_ref_wheelchair()
```

## Value

A reference table with withdrawn numeric values. Physiological capillary
observations do not establish universal seat-interface limits.

## Examples

``` r
pr_ref_wheelchair()
#> # A tibble: 3 × 11
#>   region  parameter     threshold unit  interpretation  source source_url status
#>   <chr>   <chr>             <dbl> <chr> <chr>           <chr>  <chr>      <chr> 
#> 1 ischial mpp                  NA mmHg  Withdrawn: no … Sprig… NA         withd…
#> 2 ischial mean_pressure        NA mmHg  Withdrawn: no … Landi… NA         withd…
#> 3 any     mpp                  NA mmHg  Withdrawn: no … Stins… NA         withd…
#> # ℹ 3 more variables: species <chr>, gait <chr>, region_scheme <chr>
```
