# Read a Verified Trial Bundle

Only use bundles from trusted sources: the checksums establish
integrity, not authenticity, and the metadata and measurements contain
serialized R objects. Version 2 preserves measurements exactly. Legacy
version 1 bundles remain readable, but their decimal CSV cannot
guarantee exact numeric/reference replay. Version 2 uses authoritative
RDS measurements; the CSV is a nonbinding preview checked for integrity
and structure, not used as a second measurement source.

## Usage

``` r
pr_read_bundle(path)
```

## Arguments

- path:

  Bundle directory written by
  [`pr_write_bundle()`](https://cttir.github.io/pressR/dev/reference/pr_write_bundle.md).

## Value

A validated
[pr_trial](https://cttir.github.io/pressR/dev/reference/pr_trial.md)
object.
