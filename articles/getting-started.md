# Getting Started with pressR

[![R-CMD-check](https://github.com/CTTIR/pressR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/CTTIR/pressR/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/CTTIR/pressR/actions/workflows/pkgdown.yaml/badge.svg)](https://cttir.github.io/pressR/)
[![CRAN
status](https://www.r-pkg.org/badges/version/pressR)](https://CRAN.R-project.org/package=pressR)
[![Codecov test
coverage](https://codecov.io/gh/CTTIR/pressR/branch/main/graph/badge.svg)](https://app.codecov.io/gh/CTTIR/pressR?branch=main)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/pressR)](https://cran.r-project.org/package=pressR)
[![CRAN downloads
total](https://cranlogs.r-pkg.org/badges/grand-total/pressR)](https://cran.r-project.org/package=pressR)
[![License:
MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

``` r

library(pressR)
```

### What pressR does

**pressR** parses, analyzes, and visualizes pressure distribution data
from capacitive sensor systems. It provides:

- Predefined sensor layouts (in-shoe insoles, pressure platforms, saddle
  mats, seating mats, glove sensors),
- Parsers for ASCII and CSV pressure data files,
- A full analysis pipeline (per-frame metrics, trial summaries, regional
  analysis, gait-cycle detection, saddle-fit checks),
- `ggplot2`-based visualization and composite reports,
- An interactive Shiny application for data exploration.

### Load a layout

Every trial is tied to a `pr_layout` object that describes the sensor
geometry. For example, a 99-sensor in-shoe pressure insole:

``` r

layout <- pr_layout_insole()
print(layout)
#> 
#> ── pr_layout: insole_standard ──────────────────────────────────────────────────
#> In-shoe pressure insole (99 sensors, standard).
#> • Manufacturer: ""
#> • Model: "insole"
#> • Grid: 18 x 8
#> • Active sensors: 99
#> • Sensor area: 1.5 cm²
#> • Pressure range: 0 - 1200 kPa
#> • Regions: 7
#> Region names: "heel", "midfoot", "metatarsal_1", "metatarsal_2_3",
#> "metatarsal_4_5", "hallux", and "lesser_toes"
```

### Generate a synthetic example trial

[`pr_example_trial()`](https://cttir.github.io/pressR/reference/pr_example_trial.md)
produces realistic synthetic data for each supported application. This
is useful for quick demos, tests, and vignettes.

``` r

trial <- pr_example_trial("insole")
trial
#> 
#> ── pr_trial ────────────────────────────────────────────────────────────────────
#> • System: "insole"
#> • Layout: "insole_standard"
#> • Frames: 250
#> • Duration: 5 s
#> • Sampling: 50 Hz
#> • Sensors: 99
#> • Subject: "EX01"
#> • Date: "2026-06-22"
#> • Condition: "walking"
```

### Visualize

The default plot method draws a maximum-pressure picture (MPP):

``` r

pr_plot_heatmap(trial)
```

![MPP heatmap of the synthetic insole
trial](getting-started_files/figure-html/unnamed-chunk-4-1.png)

Time-domain curves are equally straightforward:

``` r

pr_plot_force_time(trial, show_cycles = TRUE)
```

![Force vs time with gait cycles
shaded](getting-started_files/figure-html/unnamed-chunk-5-1.png)

### Summarize

[`pr_summary()`](https://cttir.github.io/pressR/reference/pr_summary.md)
returns a single-row tibble containing the common biomechanical
parameters:

``` r

pr_summary(trial)
#> # A tibble: 1 × 14
#>     mpp   mvp max_force mean_force max_contact_area mean_contact_area
#>   <dbl> <dbl>     <dbl>      <dbl>            <dbl>             <dbl>
#> 1  646.  43.0     1466.       289.             128.              60.9
#> # ℹ 8 more variables: contact_time <dbl>, pti_max <dbl>, pti_mean <dbl>,
#> #   impulse <dbl>, cop_path_length <dbl>, cop_velocity_mean <dbl>,
#> #   cop_range_ap <dbl>, cop_range_ml <dbl>
```

### Regional analysis

With the insole layout’s default region masks you get one row per
anatomical region:

``` r

pr_calc_regional(trial)
#> # A tibble: 7 × 6
#>   region           mpp   mvp max_force contact_area pti_mean
#>   <chr>          <dbl> <dbl>     <dbl>        <dbl>    <dbl>
#> 1 heel            220.  15.0     357.          42       40.2
#> 2 midfoot         646.  59.6    1248.          61.5    155. 
#> 3 metatarsal_1    130.  23.0      41.9          6       65.4
#> 4 metatarsal_2_3  224.  43.3     116.           9      127. 
#> 5 metatarsal_4_5  137.  15.9      49.1          9       43.8
#> 6 hallux          265.  29.9     120.           6       83.8
#> 7 lesser_toes     190.  12.9      73.1         12       30.0
```

### Export

Results can be exported as CSV:

``` r

tmp <- tempfile(fileext = ".csv")
pr_export_csv(trial, tmp, what = "summary")
```

### Launch the Shiny app

``` r

pr_run_app(trial)
```

## Use of LLM tools

Portions of this package were prepared with assistance from large
language model tooling for narrowly defined, non-authorial tasks:
copyediting, prose smoothing, Markdown/LaTeX formatting, scaffolding of
boilerplate files (CI configs, build scripts), code refactoring. The
tools used were [Chat
AI](https://kisski.gwdg.de/leistungen/2-02-llm-service/), the LLM
service of KISSKI (GWDG), and a self-hosted **Mistral Small (24B,
Apache-2.0)** run locally via [Ollama](https://ollama.com/) and the
`ollamar` R package — local inference only, with no data sent to third
parties for the self-hosted model.

All scientific claims, methodological choices, analyses,
interpretations, and conclusions are the author’s own. No LLM-generated
text was incorporated without review and revision, and every reference
was verified against its DOI, arXiv ID, or ISBN.
