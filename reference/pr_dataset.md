# Create a Pressure Dataset

A `pr_dataset` is a collection of
[pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md) objects
with shared grouping metadata, intended for batch analysis.

## Usage

``` r
pr_dataset(trials, group_var = "condition", name = "dataset")
```

## Arguments

- trials:

  A list of
  [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  objects.

- group_var:

  Character. Name of the metadata field to use as the grouping variable.
  Default `"condition"`.

- name:

  Character. Name of the dataset. Default `"dataset"`.

## Value

A `pr_dataset` S3 object.

## Examples

``` r
t1 <- pr_example_trial("insole", seed = 1)
t2 <- pr_example_trial("insole", seed = 2)
ds <- pr_dataset(list(t1, t2))
print(ds)
#> 
#> ── pr_dataset: dataset ─────────────────────────────────────────────────────────
#> • Trials: 2
#> • Subjects: "EX01"
#> • Conditions: "walking"
#> • Layouts: "insole_standard"
```
