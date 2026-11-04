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
