# Traceable Plantar Pressure Reference Observations

Armstrong's 1998 case-control study reported a 70 N/cm2 (700 kPa)
forefoot cut-point with limited discrimination using EMED measurements.
Other previously supplied values are withdrawn pending exact provenance.

## Usage

``` r
pr_ref_diabetic_foot()
```

## Value

Reference table; only verified_source rows have usable values.

## Examples

``` r
ref <- pr_ref_diabetic_foot()
ref[ref$status == "verified_source", c("region", "parameter", "threshold", "unit")]
#> # A tibble: 1 × 4
#>   region   parameter threshold unit 
#>   <chr>    <chr>         <dbl> <chr>
#> 1 forefoot mpp             700 kPa  
```
