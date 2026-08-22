# Assert the Level Sets of Design Factors

Checks that named columns of a data frame carry exactly the levels they
are contracted to carry — no unexpected value, no silently absent level,
and for `factor` columns the declared order as well. Aborts naming the
offending column, the offending values, and the rows they sit in.

## Usage

``` r
pr_factor_contract(x, levels_list, id_cols = NULL)
```

## Arguments

- x:

  A data frame.

- levels_list:

  Named list. Each name is a column of `x`; each element is the vector
  of levels that column must carry, in order. A `factor` may be supplied
  instead, in which case its
  [`levels()`](https://rdrr.io/r/base/levels.html) are used. Include
  `NA` to permit missing values in that column.

- id_cols:

  Character vector of column names identifying a row, used to point at
  the offending rows in the error message (for example `"ID"`). `NULL`
  (default) reports values without row identifiers.

## Value

Invisibly, `x` — so the contract can sit inside a pipeline. On
violation, aborts with condition class `pr_factor_contract_failed`,
carrying a `problems`
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
(columns `column`, `issue`, `value`, `n_rows`, `ids`) in the condition.

## Details

This is the check that catches a typo'd condition code, a level lost to
a filter, and a [`factor()`](https://rdrr.io/r/base/factor.html) call
whose `levels =` argument drifted out of step with the data — all of
which change a model's reference level or its contrast matrix without
changing anything visible in a
[`head()`](https://rdrr.io/r/utils/head.html).

Both directions are enforced, because "exactly" is the point: a value in
the data that the contract does not list is an `unexpected_level`, and a
level in the contract that never appears in the data is a
`missing_level`. The second half is the one that matters after a subset
— a design that lost a whole condition still looks perfectly well
formed.

Order is enforced only where order exists. A `factor` column stores its
levels, so `levels(x[[col]])` must equal the contract element by
element; a mismatch in order alone is reported as `wrong_order`. A
`character` column has no stored order, so only its level *set* is
contracted — convert with `factor(x, levels = ...)` first if the order
has to be pinned.

`NA` values are reported as `missing_value` unless `NA` appears in the
contract for that column, in which case they are accepted.

## See also

[`pr_design_gaps()`](https://cttir.github.io/pressR/reference/pr_design_gaps.md)
for the combinations those levels do and do not form.

Other provenance functions:
[`pr_design_gaps()`](https://cttir.github.io/pressR/reference/pr_design_gaps.md),
[`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md),
[`pr_validate_summary()`](https://cttir.github.io/pressR/reference/pr_validate_summary.md),
[`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)

## Examples

``` r
design <- data.frame(
  ID = c("ID001", "ID001", "ID003", "ID003"),
  Mode = c("MG", "MH", "MS", "MH"),
  Saddle = c("K", "S", "W", "K")
)

# Passes and returns the data invisibly:
out <- pr_factor_contract(
  design,
  list(Mode = c("MG", "MH", "MS"), Saddle = c("K", "S", "W")),
  id_cols = "ID"
)
identical(out, design)
#> [1] TRUE

# A wrong contract fails loudly, naming the column and the values:
try(pr_factor_contract(design, list(Mode = c("MG", "MH"))))
#> Error in pr_factor_contract(design, list(Mode = c("MG", "MH"))) : 
#>   Factor contract violated in 1 column.
#> ✖ Mode: unexpected level "MS" in 1 row(s).
#> ℹ Fix the data or the contract deliberately: a changed level set changes a
#>   model's reference level and its contrasts.
```
