# Verify a Table Against Its Lock File

Re-derives the properties
[`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md)
recorded and reports exactly which of them changed: row count, column
names, column types, or content.

## Usage

``` r
pr_verify_lock(x, path)
```

## Arguments

- x:

  A data frame to check.

- path:

  Path to a lock file written by
  [`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md).

## Value

Invisibly, a single `TRUE`/`FALSE`. The result carries a `"report"`
attribute: a four-row
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `property` (`"rows"`, `"columns"`, `"types"`, `"content"`),
`expected`, `actual` and `passed`.

## Details

The four properties are checked independently, so the report separates
failures that a shape check would conflate. A renamed column shows as
`columns` changed with `content` unchanged. A row filtered out shows as
`rows` changed. An [`as.integer()`](https://rdrr.io/r/base/integer.html)
slipped into a pipeline shows as both `types` and `content`, because the
storage type is part of the hashed byte stream. Same shape, same names,
different numbers shows as `content` alone — the case a
[`dim()`](https://rdrr.io/r/base/dim.html) check misses entirely.

This function never aborts and never warns on a mismatch: it returns the
verdict and prints the report, leaving the caller to decide. Wrap it in
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) to make a script
fail, or add it as a rule to
[`pr_validate_summary()`](https://cttir.github.io/pressR/reference/pr_validate_summary.md).
Errors *are* raised for the caller's own mistakes — a missing,
malformed, or wrong-version lock file — because those are not evidence
that the data changed.

## See also

[`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md)
to write the lock file.

Other provenance functions:
[`pr_design_gaps()`](https://cttir.github.io/pressR/reference/pr_design_gaps.md),
[`pr_factor_contract()`](https://cttir.github.io/pressR/reference/pr_factor_contract.md),
[`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md),
[`pr_validate_summary()`](https://cttir.github.io/pressR/reference/pr_validate_summary.md)

## Examples

``` r
design <- data.frame(
  ID = c("ID001", "ID001", "ID003"),
  Mode = c("MH", "MS", "MG"),
  n_frames = c(23432L, 10662L, 8000L)
)
path <- tempfile(fileext = ".lock")
pr_lock_table(design, path)

pr_verify_lock(design, path)
#> ✔ Lock verified: /tmp/RtmpnJ9Dph/file24f45c76d1dc.lock matches `x` (3 rows x 3
#>   columns, md5 "1efdd17d").

# One edited value: same shape, same names, different content.
edited <- design
edited$n_frames[1] <- 23431L
ok <- pr_verify_lock(edited, path)
#> ✖ Lock mismatch for /tmp/RtmpnJ9Dph/file24f45c76d1dc.lock.
#> • Content: same shape and names, different values (md5 1efdd17d -> 76247d72).
#> ℹ Unchanged: rows, columns, and types.
ok
#> [1] FALSE
#> attr(,"report")
#> # A tibble: 4 × 4
#>   property expected                         actual                        passed
#>   <chr>    <chr>                            <chr>                         <lgl> 
#> 1 rows     3                                3                             TRUE  
#> 2 columns  ID, Mode, n_frames               ID, Mode, n_frames            TRUE  
#> 3 types    character, character, integer    character, character, integer TRUE  
#> 4 content  1efdd17da2a4f8741ab4a22ba9696da3 76247d720c7bb59cf880e663c2d6… FALSE 
attr(ok, "report")
#> # A tibble: 4 × 4
#>   property expected                         actual                        passed
#>   <chr>    <chr>                            <chr>                         <lgl> 
#> 1 rows     3                                3                             TRUE  
#> 2 columns  ID, Mode, n_frames               ID, Mode, n_frames            TRUE  
#> 3 types    character, character, integer    character, character, integer TRUE  
#> 4 content  1efdd17da2a4f8741ab4a22ba9696da3 76247d720c7bb59cf880e663c2d6… FALSE 

unlink(path)
```
