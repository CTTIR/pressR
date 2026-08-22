# Split Metadata Fields Out of a File Name

Many measurement archives encode a recording's design cells in its file
name, e.g. `ID052_K_K_KG00_MS.asc` for subject `ID052`, saddle `K`, pad
`K`, weight `KG00`, mode `MS`. This splits such a base name into a
one-row tibble of named fields.

## Usage

``` r
pr_meta_from_filename(
  path,
  fields,
  sep = "_",
  on_fail = c("skip", "error", "na")
)
```

## Arguments

- path:

  Character scalar. A file path or bare name. The directory and the
  extension are removed before splitting.

- fields:

  Character vector of output column names, in the order the parts appear
  in the name.

- sep:

  Character scalar. Literal separator between parts. Default `"_"`.

- on_fail:

  What to do when the name does not split into exactly `length(fields)`
  non-empty parts: `"skip"` (default) returns `NULL`, `"error"` throws,
  `"na"` returns a one-row tibble of `NA_character_`.

## Value

A one-row tibble with one character column per entry of `fields`, or
`NULL` (see `on_fail`).

## Details

A name matches only when it splits into *exactly* `length(fields)`
non-empty parts. That strictness is the point: it is what lets a
directory read reject stray files (repeat takes such as
`ID003_K_K_KG60_MH_R01`, notes, exports) instead of silently
mislabelling them.

## See also

Other Pliance ingest functions:
[`pr_read_dir()`](https://cttir.github.io/pressR/reference/pr_read_dir.md),
[`pr_read_pliance()`](https://cttir.github.io/pressR/reference/pr_read_pliance.md)

## Examples

``` r
fields <- c("ID", "Saddle", "Pad", "Weight", "Mode")
pr_meta_from_filename("ID052_K_K_KG00_MS.asc", fields)
#> # A tibble: 1 × 5
#>   ID    Saddle Pad   Weight Mode 
#>   <chr> <chr>  <chr> <chr>  <chr>
#> 1 ID052 K      K     KG00   MS   

# A repeat take carries a sixth part, so it does not match:
pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields)
#> NULL

pr_meta_from_filename("ID003_K_K_KG60_MH_R01.asc", fields, on_fail = "na")
#> # A tibble: 1 × 5
#>   ID    Saddle Pad   Weight Mode 
#>   <chr> <chr>  <chr> <chr>  <chr>
#> 1 NA    NA     NA    NA     NA   
```
