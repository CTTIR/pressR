# Report Source and Analysis Provenance

Report Source and Analysis Provenance

## Usage

``` r
pr_report_info(trial)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

## Value

A field/value tibble suitable for reports.

## Examples

``` r
pr_report_info(pr_example_trial("insole"))
#> # A tibble: 11 × 2
#>    field                  value       
#>    <chr>                  <chr>       
#>  1 package_version        0.3.0       
#>  2 recording              insole_gait 
#>  3 source_sha256          not recorded
#>  4 frames                 250         
#>  5 sampling_hz            50          
#>  6 measurement_unit       kPa         
#>  7 coordinate_unit        mm          
#>  8 sensor_area_cm2        1.5         
#>  9 temporal_profile       not applied 
#> 10 missing_frames_removed 0           
#> 11 negative_observations  0           
```
