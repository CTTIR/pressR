# Export a Versioned Trial Bundle

Writes a version 2 bundle with pressure.csv for inspection,
measurements.rds for exact numeric preservation, typed metadata.rds, and
a JSON manifest with SHA-256 checksums. Metadata preserves the complete
layout and factor levels. The destination must not already exist.
Checksums detect corruption; they do not authenticate a sender. Only
read bundles from trusted sources, because they contain serialized R
objects. The RDS measurements are authoritative. The CSV is a nonbinding
preview; reading verifies its checksum, columns and frame identifiers,
but does not use its decimal measurements. Recreate the bundle to change
its contents.

## Usage

``` r
pr_write_bundle(trial, path)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- path:

  New bundle directory.

## Value

Invisibly the bundle directory.

## Examples

``` r
trial <- pr_example_trial("custom")
path <- tempfile("pressr-bundle-")
pr_write_bundle(trial, path)
list.files(path)
#> [1] "manifest.json"    "measurements.rds" "metadata.rds"     "pressure.csv"    
unlink(path, recursive = TRUE)
```
