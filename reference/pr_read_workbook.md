# Import a Study Workbook and Its HR/RR Series

Keeps every sheet as source cells and records row numbers for normalized
observations. Recognizes Polar-style HR headers, including headers below
session metadata, and duration/offline RR exports. Unknown sheets remain
available as attachments. No observations are silently removed or
aligned.

## Usage

``` r
pr_read_workbook(path, numeric_time_unit = NULL)
```

## Arguments

- path:

  Excel workbook path.

- numeric_time_unit:

  NULL by default: ambiguous numeric times remain unavailable. Set
  'seconds' or 'excel_days' only with source evidence.

## Value

A list with sheets, heart_rate, rr_intervals and a sheet manifest.

## Examples

``` r
hr <- data.frame(Time = c("00:00:01", "00:00:02", "00:00:03"), HR = c(92, 95, 97))
names(hr)[2] <- "HR (bpm)"
path <- tempfile(fileext = ".xlsx")
writexl::write_xlsx(list(session = hr), path)
workbook <- pr_read_workbook(path)
workbook$manifest
#> # A tibble: 1 × 5
#>   sheet   role       source_rows source_columns header_row
#>   <chr>   <chr>            <int>          <int>      <int>
#> 1 session heart_rate           4              2          1
workbook$heart_rate[c("time_s", "hr_bpm")]
#> # A tibble: 3 × 2
#>   time_s hr_bpm
#>    <dbl>  <dbl>
#> 1      1     92
#> 2      2     95
#> 3      3     97
unlink(path)
```
