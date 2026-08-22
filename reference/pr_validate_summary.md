# Two-Tier Data Frame Validation

Runs a set of named predicates over a data frame and returns them as a
tibble of results. Rules passed as `hard` abort on failure; rules passed
as `soft` warn. Everything is evaluated before anything is signalled, so
one failing rule never hides the others.

## Usage

``` r
pr_validate_summary(x, hard = list(), soft = list(), label = NULL)
```

## Arguments

- x:

  A data frame to validate.

- hard:

  Named list of predicates whose failure aborts. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- soft:

  Named list of predicates whose failure warns. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- label:

  Character. Name of the table, used in the warning and error headers.
  `NULL` (default) uses `"data"`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per rule and columns `rule`, `level` (`"hard"` or
`"soft"`), `passed` (logical) and `message` (`NA` for a passing rule),
hard rules first. When a hard rule fails, aborts with condition class
`pr_validate_failed`, carrying that same tibble in the condition's
`results` field. Soft failures warn with condition class
`pr_validate_soft_failed`.

## Details

The two tiers encode a distinction most validation code loses: some
properties are structural (a duplicated key, a negative duration, an
unknown condition code) and make every downstream number wrong, while
others are worth knowing about but not worth stopping for (an unbalanced
cell, an unusually short recording). Collapsing both into
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) means either the
pipeline halts for cosmetic reasons or the structural checks get
commented out.

A rule is a function of the data frame returning either:

- a logical vector — `TRUE` throughout passes; any `FALSE` or `NA`
  fails, and the message counts the failing elements. This lets a rule
  be written per row (`function(d) d$n_frames > 0`) or as a single claim
  (`function(d) anyDuplicated(d$ID) == 0L`).

- a character vector — an empty one passes, and any strings are taken as
  the problem description. Use this when the rule can say *what* is
  wrong, not merely that something is.

A rule that throws is recorded as a failure carrying its error message
rather than propagated: a validation run should report on a broken rule,
not die inside it.

## See also

[`pr_validate_dataset()`](https://cttir.github.io/pressR/reference/pr_validate_dataset.md)
for the trial-level homogeneity checks.

Other provenance functions:
[`pr_design_gaps()`](https://cttir.github.io/pressR/reference/pr_design_gaps.md),
[`pr_factor_contract()`](https://cttir.github.io/pressR/reference/pr_factor_contract.md),
[`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md),
[`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)

## Examples

``` r
design <- data.frame(
  ID = c("ID001", "ID001", "ID003"),
  Mode = c("MH", "MS", "MG"),
  n_frames = c(23432L, 10662L, 8000L)
)

res <- pr_validate_summary(
  design,
  hard = list(
    positive_frames = function(d) d$n_frames > 0,
    mode_known = function(d) all(d$Mode %in% c("MG", "MH", "MS"))
  ),
  label = "design"
)
res
#> # A tibble: 2 × 4
#>   rule            level passed message
#>   <chr>           <chr> <lgl>  <chr>  
#> 1 positive_frames hard  TRUE   NA     
#> 2 mode_known      hard  TRUE   NA     

# A soft rule warns and is still reported. The real cohort is unbalanced
# across Mode (92 / 169 / 170 recordings), which is worth knowing but is
# not a reason to stop.
unbalanced <- rbind(design, design[2, ])
res2 <- suppressWarnings(pr_validate_summary(
  unbalanced,
  soft = list(balanced = function(d) {
    tab <- table(d$Mode)
    if (length(unique(as.integer(tab))) == 1L) {
      character(0)
    } else {
      paste0("Mode counts differ: ",
             paste(names(tab), as.integer(tab), sep = "=",
                   collapse = ", "))
    }
  }),
  label = "design"
))
res2$message
#> [1] "Mode counts differ: MG=1, MH=1, MS=2"

# A hard failure aborts:
try(pr_validate_summary(
  design,
  hard = list(unique_id = function(d) anyDuplicated(d$ID) == 0L)
))
#> Error in pr_validate_summary(design, hard = list(unique_id = function(d) anyDuplicated(d$ID) ==  : 
#>   1 hard validation rule failed for "data".
#> ✖ unique_id: rule returned FALSE
#> ℹ A hard rule guards a structural property; fix the data rather than the rule.
```
