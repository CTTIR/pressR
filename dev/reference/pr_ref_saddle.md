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
