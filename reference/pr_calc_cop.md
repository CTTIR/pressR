# Calculate Center of Pressure

Computes the pressure-weighted centroid of active sensors for each
frame. Frames with no loaded sensors return `NA` for x and y.
Overflowing weighted sums are evaluated with bounded weights and
coordinates.

## Usage

``` r
pr_calc_cop(trial, threshold = 0)
```

## Arguments

- trial:

  A [pr_trial](https://cttir.github.io/pressR/reference/pr_trial.md)
  object.

- threshold:

  Numeric. Sensors at or below are treated as unloaded. Default `0`.

## Value

A [pr_cop](https://cttir.github.io/pressR/reference/pr_cop.md) object
containing x, y, the layout coordinate unit, time (s), and derived
metrics.

## Examples

``` r
cop <- pr_calc_cop(pr_example_trial("saddle_horse"))
print(cop)
#> 
#> ── pr_cop ──
#> 
#> • Frames: 500
#> • Path length: 4446.35 mm
#> • Mean velocity: 445.53 mm/s
#> • Max velocity: 1109.73 mm/s
#> • Range (x): 135.1 mm
#> • Range (y): 17.33 mm
#> • Sway area (95% ellipse): 2411.38 mm^2
```
