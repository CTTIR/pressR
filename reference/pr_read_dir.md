# Read a Directory of Pressure Exports

Walks a directory, reads every matching file with `reader`, and collects
the results into a
[pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md).
Files that cannot be read - or whose names do not match `meta_fields` -
are reported and skipped rather than aborting the whole batch.

## Usage

``` r
pr_read_dir(
  dir,
  pattern = "\\.asc$",
  reader = pr_read_pliance,
  layout = NULL,
  meta_fields = NULL,
  recursive = TRUE,
  on_error = c("skip", "abort"),
  quiet = FALSE,
  ...,
  sep = "_",
  name = NULL
)
```

## Arguments

- dir:

  Character scalar. Directory to walk.

- pattern:

  Regular expression matching file names to read. Default `"\\.asc$"`.

- reader:

  Function called as `reader(path, layout = layout, ...)`. Default
  [`pr_read_pliance()`](https://cttir.github.io/pressR/reference/pr_read_pliance.md).

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  passed to `reader`. Default `NULL`.

- meta_fields:

  Character vector of file-name fields, or `NULL` (default) to read
  every matching file and parse no names.

- recursive:

  Logical. Descend into sub-directories. Default `TRUE`.

- on_error:

  `"skip"` (default) records a failure and continues; `"abort"`
  re-throws the first one.

- quiet:

  Logical. Suppress the progress and summary messages and the readers'
  warnings. Default `FALSE`.

- ...:

  Further arguments passed to `reader`.

- sep:

  Character scalar. Separator passed to
  [`pr_meta_from_filename()`](https://cttir.github.io/pressR/reference/pr_meta_from_filename.md).
  Default `"_"`.

- name:

  Character scalar. Dataset name. `NULL` (default) uses the directory's
  base name.

## Value

A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md).
Attribute `"read_report"` holds a tibble with one row per candidate file
(`file`, `path`, `status`, `reason`).

## Details

When `meta_fields` is supplied, each file name is split with
[`pr_meta_from_filename()`](https://cttir.github.io/pressR/reference/pr_meta_from_filename.md)
and the parts are stored in the trial's metadata under those names. The
first part additionally fills `subject_id` and the remaining parts,
rejoined with `sep`, fill `condition` - the field
[`pr_dataset()`](https://cttir.github.io/pressR/reference/pr_dataset.md)
groups by - unless the reader already set them. A name that does not
split into exactly `length(meta_fields)` parts is skipped, which is the
intended way to exclude repeat takes and stray exports from a cohort.

## See also

Other Pliance ingest functions:
[`pr_meta_from_filename()`](https://cttir.github.io/pressR/reference/pr_meta_from_filename.md),
[`pr_read_pliance()`](https://cttir.github.io/pressR/reference/pr_read_pliance.md)

## Examples

``` r
dir <- tempfile()
dir.create(dir)
hdr <- c(
  "Dateiname:  demo.mat\tDatum/Zeit: 01.01.25 09.00",
  "Kalibrationsdatei:  demo_cal",
  "gesamte Messzeit [Sek.]: 0.040\tZeit pro Bild [Sek.]:  0.02000\tMessfrequenz [Hz]:   50",
  "Druckwerte in  kPa", "", "elektrisch:",
  "Zeit [Sek.]\t1\t2\t3\t4",
  "0.02000\t10\t0\t0\t0",
  "0.04000\t0\t20\t0\t0"
)
writeLines(hdr, file.path(dir, "ID001_K_KG00.asc"))
writeLines(hdr, file.path(dir, "ID002_K_KG40.asc"))
writeLines(hdr, file.path(dir, "ID002_K_KG40_R01.asc"))  # repeat take

lay <- pr_layout(
  2, 2, matrix(TRUE, 2, 2),
  data.frame(sensor_id = 1:4, row = c(1L, 2L, 1L, 2L),
             col = c(1L, 1L, 2L, 2L),
             x_mm = c(0, 0, 1, 1), y_mm = c(0, 1, 0, 1))
)
ds <- pr_read_dir(dir, layout = lay,
                  meta_fields = c("ID", "Saddle", "Weight"), quiet = TRUE)
length(ds)
#> [1] 2
attr(ds, "read_report")$status
#> [1] "ok"      "ok"      "skipped"
unlink(dir, recursive = TRUE)
```
