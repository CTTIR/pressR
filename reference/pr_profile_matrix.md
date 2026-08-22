# Per-Sensor Feature Matrix for a Dataset

Stacks
[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
across every trial in a dataset: a `n_trials x n_sensors` numeric matrix
whose rows are recordings and whose columns are sensors, in layout
(column-major grid) order. This is the input
[`stats::prcomp()`](https://rdrr.io/r/stats/prcomp.html),
[`stats::dist()`](https://rdrr.io/r/stats/dist.html),
[`stats::cmdscale()`](https://rdrr.io/r/stats/cmdscale.html) or a
classifier expects, with no further reshaping.

## Usage

``` r
pr_profile_matrix(dataset, statistic = "mean", threshold = 0)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- statistic:

  Character. Any statistic accepted by
  [`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md).
  Default `"mean"`.

- threshold:

  Numeric. Cells at or below this value count as unloaded. Default `0`.

## Value

A numeric matrix with `length(dataset)` rows and `n_sensors` columns,
with row and column names as described above.

## Details

Row names are the trials' identifying metadata (`trial_id`, else
`file_label`, else `subject_id`, else `trial_<i>`), made unique with
[`make.unique()`](https://rdrr.io/r/base/make.unique.html). Column names
are `sensor_<id>` taken from the first trial's layout.

Every trial must expose the same number of sensors, since column `k` has
to mean the same grid cell in every row; a mismatch is an error rather
than a recycled row. Differing *layout names* at the same sensor count
are only a warning: two layouts may legitimately share a grid, but if
they do not, the matrix silently compares different anatomy, so the
warning is worth reading.

## See also

[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
for a single trial.

Other sensor aggregation functions:
[`pr_batch_frame_summary()`](https://cttir.github.io/pressR/reference/pr_batch_frame_summary.md),
[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)

## Examples

``` r
ds <- pr_dataset(lapply(1:3, function(s) {
  pr_example_trial("saddle_horse", seed = s)
}))
X <- pr_profile_matrix(ds, "mean")
dim(X)
#> [1]   3 248
X[, 1:4]
#>                sensor_1  sensor_2  sensor_3  sensor_4
#> saddle_walk   0.2571023 0.2493830 0.2095750 0.2118923
#> saddle_walk_1 0.2367435 0.2504103 0.2300383 0.2532296
#> saddle_walk_2 0.2356181 0.2478820 0.2221043 0.2501159

# Straight into a PCA of pressure distribution shape:
pc <- stats::prcomp(X)
round(pc$sdev[1:2], 3)
#> [1] 0.259 0.226
```
