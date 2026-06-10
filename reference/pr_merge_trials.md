# Merge Trials into a Dataset

Merge Trials into a Dataset

## Usage

``` r
pr_merge_trials(..., group_var = "condition")
```

## Arguments

- ...:

  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects or lists of them.

- group_var:

  Character. Name of a metadata field to use as the grouping variable.

## Value

A [pr_dataset](https://cttir.github.io/pressR/reference/pr_dataset.md)
object.

## Examples

``` r
pr_merge_trials(
  pr_example_trial("insole", seed = 1),
  pr_example_trial("insole", seed = 2)
)
#> 
#> ── pr_dataset: dataset ─────────────────────────────────────────────────────────
#> • Trials: 2
#> • Subjects: "EX01"
#> • Conditions: "walking"
#> • Layouts: "insole_standard"
```
