# Extract Selected Archive Members Without Overwriting Files

Extract Selected Archive Members Without Overwriting Files

## Usage

``` r
pr_extract_archive(path, members, destination, max_bytes = 1024^3)
```

## Arguments

- path:

  Archive path.

- members:

  Character vector of exact member names to extract.

- destination:

  A new directory; existing destinations are rejected.

- max_bytes:

  Maximum total uncompressed bytes, default 1 GiB.

## Value

An inventory of extracted files with computed SHA-256 identifiers.

## Details

Selected names must be portable relative file paths. Traversal, Windows
device names and stream syntax, control characters and trailing spaces
or periods are refused. Aliases cannot overwrite an earlier member.

## Examples

``` r
src <- tempfile("pressr-src-")
dir.create(src)
writeLines(c("time,s1", "0,1", "0.02,3"), file.path(src, "trial.csv"))
zip <- tempfile(fileext = ".zip")
archive::archive_write_dir(zip, src)
dest <- tempfile("pressr-extract-")
pr_extract_archive(zip, members = "trial.csv", destination = dest)
#> # A tibble: 1 × 6
#>   path                        relative_path bytes role  sha256 duplicate_content
#>   <chr>                       <chr>         <dbl> <chr> <chr>  <lgl>            
#> 1 /tmp/Rtmp09YCmM/pressr-ext… trial.csv        19 meas… 8f54c… FALSE            
unlink(c(src, dest, zip), recursive = TRUE)
```
