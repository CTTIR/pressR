# Summarize Trial Pressure Parameters

Computes a comprehensive set of pressure distribution parameters for an
entire trial. Returns a single-row tibble suitable for row-binding
across trials in batch analysis.

## Usage

``` r
pr_summary(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Threshold for "loaded" sensors. Default `0`.

## Value

A one-row
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns:

- `mpp`: maximum peak pressure (kPa)

- `mvp`: mean of per-frame mean pressures (kPa)

- `max_force`: maximum total force (N)

- `mean_force`: mean total force (N)

- `max_contact_area`: maximum contact area (cm^2)

- `mean_contact_area`: mean contact area (cm^2)

- `contact_time`: total contact duration (s)

- `pti_max`: maximum PTI across sensors (kPa\*s)

- `pti_mean`: mean PTI across loaded sensors (kPa\*s)

- `impulse`: force-time integral (N\*s)

- `cop_path_length`: total COP trajectory length (mm)

- `cop_velocity_mean`: mean COP velocity (mm/s)

- `cop_range_ap`: anterior-posterior COP range (mm)

- `cop_range_ml`: medial-lateral COP range (mm)

## Examples

``` r
trial <- pr_example_trial("insole")
pr_summary(trial)
#> # A tibble: 1 × 14
#>     mpp   mvp max_force mean_force max_contact_area mean_contact_area
#>   <dbl> <dbl>     <dbl>      <dbl>            <dbl>             <dbl>
#> 1  646.  43.0     1466.       289.             128.              60.9
#> # ℹ 8 more variables: contact_time <dbl>, pti_max <dbl>, pti_mean <dbl>,
#> #   impulse <dbl>, cop_path_length <dbl>, cop_velocity_mean <dbl>,
#> #   cop_range_ap <dbl>, cop_range_ml <dbl>
```
