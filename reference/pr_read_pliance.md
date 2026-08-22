# Read a Novel/Pliance ASCII Export

Reads one Novel/Pliance `.asc` pressure export into a
[pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md). The
recorded time column is used as-is rather than a synthesised sequence,
so a trial whose frames were dropped keeps honest timestamps.

## Usage

``` r
pr_read_pliance(
  path,
  layout = NULL,
  skip = 7L,
  sep = "\t",
  time_col = 1L,
  channel_map = NULL,
  na_strings = c("", "NA", "___"),
  encoding = "latin1",
  on_na = c("drop_frame", "zero"),
  sampling_hz = NULL,
  metadata = list()
)
```

## Arguments

- path:

  Character scalar. Path to the `.asc` export.

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object. `NULL` (default) picks a layout from the channel count.

- skip:

  Integer. Header lines before the first data line. Default `7L`, the
  Pliance export format.

- sep:

  Character scalar. Literal column delimiter. Default `"\t"`.

- time_col:

  Integer. Position of the timestamp column, default `1L`. `NULL`
  synthesises time from `sampling_hz` instead.

- channel_map:

  Device-channel map: a grid-shaped matrix, a bare integer permutation,
  or `NULL` (default). See *Channel order*.

- na_strings:

  Character vector of tokens read as missing. Default
  `c("", "NA", "___")`.

- encoding:

  Character. File encoding, default `"latin1"`.

- on_na:

  `"drop_frame"` (default) or `"zero"`. See *Missing values*.

- sampling_hz:

  Numeric. Overrides the rate recorded in the header. `NULL` (default)
  uses the header, or the timestamps when the header is silent.

- metadata:

  Named list merged over the parsed metadata, so callers can override
  any field.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object.

## Channel order

A device export lists columns in *device channel* order. Every other
`pressR` function -
[`pr_mask()`](https://cttir.github.io/pressR/reference/pr_mask.md),
[`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md),
the heatmaps - indexes pressure columns in column-major grid order, the
order `which(layout$active)` produces. For a single-panel device the two
agree; for a multi-panel mat they do not. Supplying `channel_map` (or a
layout that carries one, such as
[`pr_layout_saddle_novel()`](https://cttir.github.io/pressR/reference/pr_layout_saddle_novel.md))
applies the single permutation `pressure[, order, drop = FALSE]` that
reconciles them.

`channel_map` may be a grid-shaped matrix whose entry at `[row, col]` is
the device channel sitting at that grid cell, or the equivalent bare
integer permutation. When `channel_map` is `NULL` and `layout` carries a
`channel_order`, that order is used; otherwise the columns are left in
device order.

## Missing values

Pliance writes an unread cell as the literal token `___`. With
`on_na = "drop_frame"` (the default) any frame containing one is removed
whole, which is what keeps per-frame statistics comparable across a
recording; `on_na = "zero"` keeps the frame and reads the cell as `0`. A
frame whose *timestamp* is missing is always dropped, since it cannot be
placed on the time axis. The counts land in `metadata$n_frames_raw` and
`metadata$n_frames_dropped`.

## See also

Other Pliance ingest functions:
[`pr_meta_from_filename()`](https://cttir.github.io/pressR/reference/pr_meta_from_filename.md),
[`pr_read_dir()`](https://cttir.github.io/pressR/reference/pr_read_dir.md)

## Examples

``` r
# A miniature export in the Pliance layout: 7 header lines, then data.
tmp <- tempfile(fileext = ".asc")
writeLines(c(
  "Dateiname:  demo.mat\tDatum/Zeit: 01.01.25 09.00",
  "Kalibrationsdatei:  demo_cal",
  "gesamte Messzeit [Sek.]: 0.040\tZeit pro Bild [Sek.]:  0.02000\tMessfrequenz [Hz]:   50",
  "Druckwerte in  kPa",
  "",
  "elektrisch:",
  "Zeit [Sek.]\t1\t2\t3\t4",
  "0.02000\t10\t0\t0\t0",
  "0.04000\t0\t20\t0\t0"
), tmp)

lay <- pr_layout(
  2, 2, matrix(TRUE, 2, 2),
  data.frame(sensor_id = 1:4, row = c(1L, 2L, 1L, 2L),
             col = c(1L, 1L, 2L, 2L),
             x_mm = c(0, 0, 1, 1), y_mm = c(0, 1, 0, 1))
)

# Device channel 1 sits at grid (row 1, col 2), channel 2 at (1, 1).
cmap <- rbind(c(2L, 1L), c(4L, 3L))
trial <- pr_read_pliance(tmp, layout = lay, channel_map = cmap)
trial$time
#> [1] 0.02 0.04
trial$pressure
#>      [,1] [,2] [,3] [,4]
#> [1,]    0    0   10    0
#> [2,]   20    0    0    0
unlink(tmp)
```
