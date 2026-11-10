# List a Study Archive

List a Study Archive

## Usage

``` r
pr_list_archive(path)
```

## Arguments

- path:

  Archive path supported by libarchive, including 7z.

## Value

A tibble containing archive member names, sizes and dates.

## Examples

``` r
src <- tempfile("pressr-src-")
dir.create(src)
writeLines(c("time,s1", "0,1", "0.02,3"), file.path(src, "trial.csv"))
zip <- tempfile(fileext = ".zip")
archive::archive_write_dir(zip, src)
pr_list_archive(zip)
#> # A tibble: 1 × 3
#>   path       size date               
#>   <chr>     <int> <dttm>             
#> 1 trial.csv    19 2026-11-10 17:47:13
unlink(c(src, zip), recursive = TRUE)
```
