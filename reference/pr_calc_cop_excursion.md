# COP Excursion (Anterior-Posterior and Medial-Lateral Range)

COP Excursion (Anterior-Posterior and Medial-Lateral Range)

## Usage

``` r
pr_calc_cop_excursion(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Default `0`.

## Value

Named numeric vector with `ap` (y-range) and `ml` (x-range), both in the
layout coordinate unit.

## Examples

``` r
pr_calc_cop_excursion(pr_example_trial("platform"))
#>        ap        ml 
#> 55.682236  4.426538 
```
