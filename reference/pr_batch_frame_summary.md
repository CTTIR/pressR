# Per-Recording Frame Summary for a Whole Cohort

Runs
[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
over every trial in a dataset and reduces each frame table to a single
row: the nine summary statistics a cohort analysis reports per
recording, plus the trial's metadata.

## Usage

``` r
pr_batch_frame_summary(
  dataset,
  threshold = 0,
  meta_fields = NULL,
  .progress = FALSE
)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- threshold:

  Numeric. Cells at or below this value count as unloaded; passed to
  [`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md),
  where it affects `loaded` and the COP weighting only. Default `0`.

- meta_fields:

  Character vector of metadata field names to prepend, in the order
  given. `NULL` (default) auto-detects: every field that holds a single
  value in every trial, dropping those that are `NA` throughout. Pass
  `character(0)` for the nine statistics alone.

- .progress:

  Logical. Show a progress bar over trials. Default `FALSE`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per trial.

## Details

Columns, in order: the requested metadata fields, then

- `mean_kPa_avg` — mean over frames of the whole-grid frame mean.

- `mean_kPa_sd` — standard deviation over frames of that same quantity,
  i.e. how much overall load varied during the recording (`NA` for a
  single-frame trial).

- `peak_kPa_max` — the largest single-sensor reading anywhere in the
  recording. On a saturating device this pins to the hardware ceiling.

- `peak_kPa_avg` — mean over frames of the frame maximum. Together with
  `mean_kPa_avg` this gives the concentration index
  `peak_kPa_avg / mean_kPa_avg` (see
  [`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md)).

- `total_kPa_avg` — mean over frames of the frame sum. Exactly
  `mean_kPa_avg * n_sensors`; a sum of pressures, never a force.

- `loaded_avg` — mean over frames of the loaded cell count.

- `cop_row_mean`, `cop_col_mean` — mean over frames of the centre of
  pressure, in grid index units.

- `n_frames` — frames in the recording, after any the reader dropped.

These names and definitions are the cohort contract, chosen so the
result can be compared column-for-column against a study's own summary
table. Note that `mean_kPa_avg` is the *whole-grid* mean including
unloaded cells (see
[`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md)),
which is a different quantity from
[`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md).

## Memory

The frame tables are built and discarded one at a time, so peak memory
is one recording's frames, not the cohort's. That matters: 431
recordings of 5.5 M frames total would need several gigabytes if every
frame table were materialised first, to produce nine numbers each.

## See also

[`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
for the per-frame table this summarises,
[`pr_design_table()`](https://cttir.github.io/pressR/reference/pr_design_table.md)
for the metadata side alone.

Other sensor aggregation functions:
[`pr_profile_matrix()`](https://cttir.github.io/pressR/reference/pr_profile_matrix.md),
[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)

## Examples

``` r
ds <- pr_dataset(list(
  pr_example_trial("saddle_horse", seed = 1),
  pr_example_trial("saddle_horse", seed = 2)
))
fs <- pr_batch_frame_summary(ds, meta_fields = character(0))
names(fs)
#> [1] "mean_kPa_avg"  "mean_kPa_sd"   "peak_kPa_max"  "peak_kPa_avg" 
#> [5] "total_kPa_avg" "loaded_avg"    "cop_row_mean"  "cop_col_mean" 
#> [9] "n_frames"     
round(fs$mean_kPa_avg, 3)
#> [1] 1.391 1.392

# total_kPa_avg is mean_kPa_avg scaled by the sensor count:
n_sensors <- ds$trials[[1]]$layout$n_sensors
all.equal(fs$total_kPa_avg, fs$mean_kPa_avg * n_sensors)
#> [1] TRUE
```
