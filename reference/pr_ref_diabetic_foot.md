# Traceable Plantar Pressure Reference Observations

Armstrong et al. (1998), J Foot Ankle Surg 37:303-307,
[doi:10.1016/S1067-2516(98)80066-5](https://doi.org/10.1016/S1067-2516%2898%2980066-5)
, abstract, p.303, reported a 70 N/cm2 (700 kPa) peak plantar forefoot
cut-point (sensitivity 70.0%, specificity 65.1%) with limited
discrimination using EMED measurements. Other previously supplied values
are withdrawn pending exact provenance.

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
