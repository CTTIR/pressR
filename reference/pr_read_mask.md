# Read Mask File

Parses `.msa` / `.msr` / `.msp` mask files or any text file containing a
binary region matrix. The expected format is a text matrix of 0/1 (or
non-zero) values, optionally preceded by a short header.

## Usage

``` r
pr_read_mask(path, layout = NULL, name = "imported", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the mask file.

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object. Required if the mask dimensions must be validated against a
  specific layout; otherwise, the mask is returned as-is.

- name:

  Character. Name for the resulting
  [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) object.
  Default `"imported"`.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) object
(if a layout is supplied) or a logical matrix.

## Examples

``` r
tmp <- tempfile(fileext = ".msa")
writeLines(c(
  "1 1 0 0",
  "1 1 0 0",
  "0 0 1 1",
  "0 0 1 1"
), tmp)
m <- pr_read_mask(tmp, verbose = FALSE)
dim(m)
#> [1] 4 4
```
