# Per-Sensor Hardware Quality Across a Cohort

Cohort-wide quality control for a sensor mat: one row per sensor,
summarising how that cell behaved across every recording in the dataset,
and a flag naming the failure mode if it has one.

## Usage

``` r
pr_sensor_quality(
  dataset,
  dead_pct_zero = 95,
  saturation_kpa = NULL,
  low_var_sd = 0.1,
  threshold = 0
)
```

## Arguments

- dataset:

  A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
  object, or a list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- dead_pct_zero:

  Numeric. Percentage (0–100) of frames at or below `threshold`, above
  which a sensor is called dead. Default `95`.

- saturation_kpa:

  Numeric, or `NULL` (default) to take the layout's declared ceiling
  `layout$pressure_range[2]`. See *Trusting the ceiling*.

- low_var_sd:

  Numeric. Lower bound on `sd_across_files`; below it a sensor is called
  low-variance. Default `0.1`, in the trial's pressure unit.

- threshold:

  Numeric. Cells at or below this value count as unloaded. Default `0`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per sensor, in the layout's column-major grid order, and
columns `sensor` (integer), `row`, `col` (integer grid indices),
`mean_across_files`, `sd_across_files`, `max_across_files`,
`pct_zero_mean` (percent), `n_files` (integer) and `flag` (character).

## Details

Each recording contributes four per-sensor numbers — its mean, its
standard deviation over frames, its maximum, and the fraction of frames
in which it read at or below `threshold` — and the cohort columns are
built from those:

- `mean_across_files` — mean over recordings of the per-recording mean.

- `sd_across_files` — mean over recordings of the *within-recording*
  standard deviation, i.e. how much this cell typically moves during a
  trial. Despite the name (which is the cohort's own, kept so the table
  can be compared column-for-column with the published one) this is
  **not** the standard deviation of the per-recording means. The two are
  different quantities and they disagree substantially: the
  between-recording spread mostly measures how differently the mat was
  loaded from horse to horse, whereas the within-recording spread
  measures whether the cell responds to load at all — which is what the
  `"Low variance"` flag is asking. Recordings of fewer than two frames
  contribute no standard deviation and are left out of this average.

- `max_across_files` — the largest reading this cell ever produced,
  anywhere in the cohort.

- `pct_zero_mean` — mean over recordings of the percentage of frames at
  or below `threshold`. This column is a **percentage** (0–100),
  matching `dead_pct_zero`, not the 0–1 fraction that
  `pr_sensor_map(trial, "pct_zero")` returns.

- `n_files` — recordings summarised, the same on every row.

## Flags

`flag` takes one of four fixed strings, assigned in this precedence
order so a cell that qualifies for more than one gets the most serious:

1.  `"Dead (>95% zero)"` — `pct_zero_mean > dead_pct_zero`. A cell that
    is unloaded in almost every frame of every recording is not
    measuring zero pressure, it is not measuring. Dead cells depress the
    whole-grid mean
    ([`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md))
    and are invisible to the loaded-cells-only
    [`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md).

2.  `"Saturated (>60 kPa)"` — `max_across_files >= saturation_kpa`. The
    cell reached the hardware ceiling, so its true peak is unknown and
    censored from above. Any peak-derived cohort number
    ([`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md),
    `peak_kPa_max`) is a lower bound wherever these cells carry the
    hotspot.

3.  `"Low variance"` — `sd_across_files < low_var_sd`. The cell
    responds, but barely: a plausible stuck or half-detached cell that
    is not zero often enough to read as dead.

4.  `"OK"` — none of the above.

The label text is fixed cohort vocabulary and names the study's nominal
60 kPa cut; the comparison actually performed uses `saturation_kpa`.

## Trusting the ceiling

With `saturation_kpa = NULL` the cut-off is taken from
`layout$pressure_range[2]`. **Check that number before relying on it.**
Several built-in layouts carry a nominal range rather than a measured
one:
[`pr_layout_saddle()`](https://cttir.github.io/pressR/reference/pr_layout_saddle.md)
declares `c(0, 120)` for `"horse"` and
[`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md)
defaults to `c(0, 600)`, while the Novel/Pliance saddle mat this cohort
was recorded on saturates at **63.75 kPa** (255 x 0.25 kPa).
[`pr_layout_saddle_novel()`](https://cttir.github.io/pressR/reference/pr_layout_saddle_novel.md)
declares that correctly; the others do not, and a ceiling that is too
high flags nothing at all. Pass `saturation_kpa` explicitly whenever the
layout's own bound is not the device's measured one. A layout that
declares `NA` — which
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md)
does unless told otherwise — is an error rather than a guess.

## Memory

Recordings are summarised one at a time into fixed-size accumulators, so
peak memory is one recording's pressure matrix plus a handful of
`n_sensors`-length vectors, not the cohort's. The study cohort is 431
recordings and about 5.5 M frames; holding them all to produce nine
columns of 256 rows would cost several gigabytes.

## See also

[`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
for the single-recording per-sensor statistics these are built from,
[`pr_batch_frame_summary()`](https://cttir.github.io/pressR/reference/pr_batch_frame_summary.md)
for the per-recording side of the same cohort.

Other sensor quality functions:
[`pr_calc_gradient()`](https://cttir.github.io/pressR/reference/pr_calc_gradient.md)

## Examples

``` r
ds <- pr_dataset(lapply(1:4, function(s) {
  pr_example_trial("saddle_horse", seed = s)
}))

# The layout declares 0-120 kPa, which this simulated mat never reaches,
# so nothing is flagged as saturated:
q <- pr_sensor_quality(ds)
table(q$flag)
#> 
#>  OK 
#> 248 

# Lower the cut-off to the cohort's own 99th percentile and the busiest
# cells show up:
cut <- unname(stats::quantile(q$max_across_files, 0.99))
table(pr_sensor_quality(ds, saturation_kpa = cut)$flag)
#> 
#>                  OK Saturated (>60 kPa) 
#>                 245                   3 

# The declared ceiling and the pressure this mat actually reached --
# the comparison the *Trusting the ceiling* section asks you to make:
c(declared = ds$trials[[1]]$layout$pressure_range[2],
  observed = max(q$max_across_files))
#>  declared  observed 
#> 120.00000  18.94237 
```
