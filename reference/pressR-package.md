# pressR: Pressure Distribution Analysis for Capacitive Sensor Systems

Parse, analyze, and visualize pressure distribution data from capacitive
sensor systems. Provides predefined sensor coordinate layouts for
in-shoe pressure measurement, saddle pressure mapping (equine and
bicycle), seating assessment, and barefoot pedography.

## Main function families

- Parsers:
  [`pr_read_ascii()`](https://cttir.github.io/pressR/reference/pr_read_ascii.md),
  [`pr_read_csv()`](https://cttir.github.io/pressR/reference/pr_read_csv.md),
  [`pr_read_auto()`](https://cttir.github.io/pressR/reference/pr_read_auto.md)

- Layouts:
  [`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md),
  [`pr_layout_insole()`](https://cttir.github.io/pressR/reference/pr_layout_insole.md),
  [`pr_layout_saddle()`](https://cttir.github.io/pressR/reference/pr_layout_saddle.md),
  ...

- Analysis:
  [`pr_summary()`](https://cttir.github.io/pressR/reference/pr_summary.md),
  [`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md),
  [`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md)

- Visualization:
  [`pr_plot_heatmap()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap.md),
  [`pr_plot_force_time()`](https://cttir.github.io/pressR/reference/pr_plot_force_time.md)

- Shiny app:
  [`pr_run_app()`](https://cttir.github.io/pressR/reference/pr_run_app.md)

## See also

Useful links:

- <https://github.com/r-heller/pressR>

- <https://r-heller.github.io/pressR/>

- Report bugs at <https://github.com/r-heller/pressR/issues>

## Author

**Maintainer**: Raban Heller <raban.heller@charite.de>
([ORCID](https://orcid.org/0000-0001-8006-9742))
