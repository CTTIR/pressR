# Write Sample Pressure Data Files

Creates sample ASCII files in a temporary directory for demonstrating
the parser functions.

## Usage

``` r
pr_example_files(type = c("insole", "saddle", "platform", "all"))
```

## Arguments

- type:

  Character. `"insole"` (default), `"saddle"`, `"platform"`, or `"all"`.

## Value

Character. Path to the sample file (single type) or directory (`"all"`).

## Examples

``` r
path <- pr_example_files("insole")
file.exists(path)
#> [1] TRUE
```
