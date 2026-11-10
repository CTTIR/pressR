# Saddle Pressure Reference Observations

Source-specific observations, not universal diagnostic cut-offs. The six
values formerly attributed to von Peinen are from Nyikos (2005),
abstract, p.187: 26 horses measured at trot with six bilateral Novel
saddle masks. Unverified legacy entries have withdrawn numeric
thresholds (NA). No reference is enabled automatically in reports.

## Usage

``` r
pr_ref_saddle(
  source = c("nyikos2005", "vonpeinen2010", "monkemoller2005", "werner2002")
)
```

## Arguments

- source:

  Reference identifier. Default 'nyikos2005'.

## Value

A tibble with region, parameter, threshold, unit, interpretation,
source, source_url, status, species, gait and region_scheme.

## Examples

``` r
pr_ref_saddle()
#> # A tibble: 6 × 11
#>   region  parameter threshold unit  interpretation      source source_url status
#>   <chr>   <chr>         <dbl> <chr> <chr>               <chr>  <chr>      <chr> 
#> 1 cranial mpp            34.5 kPa   Association observ… Nyiko… https://p… verif…
#> 2 middle  mpp            30.3 kPa   Association observ… Nyiko… https://p… verif…
#> 3 caudal  mpp            31   kPa   Association observ… Nyiko… https://p… verif…
#> 4 cranial mvp            13.2 kPa   Association observ… Nyiko… https://p… verif…
#> 5 middle  mvp            11.4 kPa   Association observ… Nyiko… https://p… verif…
#> 6 caudal  mvp            10   kPa   Association observ… Nyiko… https://p… verif…
#> # ℹ 3 more variables: species <chr>, gait <chr>, region_scheme <chr>
# Withdrawn legacy entries carry no numeric threshold:
pr_ref_saddle("werner2002")$threshold
#> [1] NA NA NA
```
