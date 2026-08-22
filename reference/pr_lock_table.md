# Lock a Table's Content and Shape

Writes a sidecar lock file recording a data frame's row count, column
count, column names, column types and a content hash. Committed next to
the analysis, it turns "the input has not changed" from an assumption
into something
[`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)
can check.

## Usage

``` r
pr_lock_table(x, path, algo = "md5")
```

## Arguments

- x:

  A data frame (or
  [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html))
  to lock.

- path:

  Path to the lock file to write. The parent directory must exist. A
  `.lock` extension is conventional but not required.

- algo:

  Hash algorithm. Only `"md5"` is available, because
  [`tools::md5sum()`](https://rdrr.io/r/tools/md5sum.html) is the only
  hash in base R and this package takes no extra dependencies. Anything
  else is an error.

## Value

Invisibly, a one-row
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `path`, `algo`, `nrow`, `ncol`, `columns` (list of
character), `types` (list of character) and `content` (the hash).

## Details

The hash is md5 —
[`tools::md5sum()`](https://rdrr.io/r/tools/md5sum.html) is the only
hash function in base R — computed over a byte stream this function
writes itself: a fixed magic string, then for each column an `NA` mask
of one byte per row followed by the values as big-endian IEEE-754
doubles, 4-byte big-endian integers, or NUL-terminated UTF-8 strings.

That stream is used in preference to the two obvious alternatives
because both are unstable in ways that would make a lock fail for the
wrong reason:

- [`utils::write.csv()`](https://rdrr.io/r/utils/write.table.html)
  renders doubles as decimal text. R 4.3.0 changed how
  [`as.character()`](https://rdrr.io/r/base/character.html) formats
  doubles, so identical numbers can produce different bytes under
  different R versions, and decimal text does not round-trip a double in
  any case.

- [`serialize()`](https://rdrr.io/r/base/serialize.html) writes the R
  version that produced the stream into its own header, so the same
  object hashes differently under R 4.3 and R 4.6.

Pinning the byte order makes x86 and ARM agree; writing doubles as bits
removes every formatting decision; carrying `NA` in a side mask means no
real value can impersonate a missing one. Before hashing, each column is
reduced to a bare vector — factors to their labels, `Date`/`POSIXct` to
seconds, all other attributes dropped — so a
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html) and
a `data.frame` holding the same numbers hash alike, and a class change
is reported through the `types` line rather than as a content change.

Column names and types are recorded but are deliberately *not* part of
the content hash. That is what lets
[`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)
distinguish a pure rename ("columns changed, content unchanged") from an
edit to the data.

No timestamp is written. Re-locking an unchanged table leaves the file
byte-identical, so a lock file under version control produces a diff
only when the table really moved.

List columns cannot be hashed and are rejected with an error rather than
skipped, because a silently unhashed column is worse than no lock at
all.

## See also

[`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)
to check a table against a lock file.

Other provenance functions:
[`pr_design_gaps()`](https://cttir.github.io/pressR/reference/pr_design_gaps.md),
[`pr_factor_contract()`](https://cttir.github.io/pressR/reference/pr_factor_contract.md),
[`pr_validate_summary()`](https://cttir.github.io/pressR/reference/pr_validate_summary.md),
[`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)

## Examples

``` r
design <- data.frame(
  ID = c("ID001", "ID001", "ID003"),
  Mode = c("MH", "MS", "MG"),
  n_frames = c(23432L, 10662L, 8000L)
)
path <- tempfile(fileext = ".lock")
lock <- pr_lock_table(design, path)
lock$content
#> [1] "1efdd17da2a4f8741ab4a22ba9696da3"

# Locking is deterministic: the same table gives the same file.
path2 <- tempfile(fileext = ".lock")
pr_lock_table(design, path2)
identical(readLines(path), readLines(path2))
#> [1] TRUE

unlink(c(path, path2))
```
