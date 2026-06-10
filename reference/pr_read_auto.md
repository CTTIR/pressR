# Auto-Detect and Read a Pressure Data File

Inspects the file extension and header, then dispatches to the correct
parser.

## Usage

``` r
pr_read_auto(path, layout = NULL, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to any supported pressure data file.

- layout:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  object. If `NULL`, inferred by the dispatched parser.

- verbose:

  Logical. Default `TRUE`.

## Value

A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
object (for `.asc` / `.txt` / `.csv`), or a logical mask matrix /
[pr_mask](https://cttir.github.io/pressR/reference/pr_mask.md) object
(for `.msa`/`.msr`/`.msp`).

## Examples

``` r
path <- pr_example_files("insole")
tr <- pr_read_auto(path, verbose = FALSE)
inherits(tr, "pr_trial")
#> [1] TRUE
```
