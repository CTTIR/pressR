# Inventory Study Source Files Without Changing Them

Inventory Study Source Files Without Changing Them

## Usage

``` r
pr_inventory(path, hash = TRUE)
```

## Arguments

- path:

  Source directory.

- hash:

  Compute SHA-256 content identifiers (default TRUE).

## Value

A tibble with paths, sizes, roles, hashes and duplicate flags.

## Examples

``` r
src <- tempfile("pressr-study-")
dir.create(src)
writeLines(c("time,s1", "0,1"), file.path(src, "trial.csv"))
writeLines("Trial notes", file.path(src, "notes.txt"))
pr_inventory(src)
#> # A tibble: 2 × 6
#>   path                        relative_path bytes role  sha256 duplicate_content
#>   <chr>                       <chr>         <dbl> <chr> <chr>  <lgl>            
#> 1 /tmp/Rtmp09YCmM/pressr-stu… notes.txt        12 meas… 9d647… FALSE            
#> 2 /tmp/Rtmp09YCmM/pressr-stu… trial.csv        12 meas… 59b2d… FALSE            
unlink(src, recursive = TRUE)
```
