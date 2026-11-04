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
