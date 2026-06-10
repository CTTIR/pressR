# Apply Masks to Extract Regional Pressure Data

Returns a named list of numeric matrices. Each entry has dimensions
`n_frames x n_sensors_in_region` and contains the pressure values of
that region's sensors for each frame.

## Usage

``` r
pr_mask_apply(trial, masks = NULL)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- masks:

  Named list of
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) objects
  or logical matrices. If `NULL` (default), the trial's layout regions
  are used.

## Value

Named list of numeric matrices.

## Examples

``` r
trial <- pr_example_trial("saddle_horse")
reg <- pr_mask_apply(trial)
vapply(reg, ncol, integer(1))
#>  cranial_left cranial_right   middle_left  middle_right   caudal_left 
#>            36            36            48            48            40 
#>  caudal_right 
#>            40 
```
