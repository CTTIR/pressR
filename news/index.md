# Changelog

## pressR 0.3.0

This is the first release of the successor line developed as 0.2.0.9000;
version 0.2.0 itself was never released. It prepares the package for a
first CRAN submission:

- The maintainer address is now <raban.heller@uni-ulm.de>, the
  documentation is written in British English (`Language: en-GB`) and
  the repository URLs use the canonical `CTTIR` organisation name. The
  citation metadata (README, `CITATION.cff`, `.zenodo.json`) names the
  author as R. Heller and uses the title from `citation("pressR")`.

- The README and vignettes no longer show CRAN status and download
  badges, which pointed to pages that do not exist before acceptance.

- Unused suggested packages (‘gganimate’, ‘gifski’, ‘vdiffr’, ‘covr’,
  ‘pkgdown’) are no longer listed in Suggests.

- Standardise the named v5 package logo across README, documentation
  pages and available application headers, with matching light and dark
  artwork.

- Reference observations cite their DOI and page: Nyikos et al. (2005),
  <doi:10.21836/PEM20050301>, and Armstrong et al. (1998),
  <doi:10.1016/S1067-2516(98)80066-5>; the withdrawn legacy entries also
  carry their DOI. The six-region saddle mask follows the scheme of
  Nyikos et al. (2005, Fig. 1, p.189) and is no longer attributed to
  Werner et al. (2002).

- [`pr_calc_saddle_slip()`](https://cttir.github.io/pressR/reference/pr_calc_saddle_slip.md)
  decides `dominant_side` and `is_asymmetric` from the same comparison:
  a mean symmetry index exactly at `slip_threshold` is now `"balanced"`
  instead of naming a side while reporting no asymmetry. Its return
  value is documented field by field.

- Threshold and duration arguments of the per-frame, summary, regional,
  gait, hotspot and slip functions must be single finite numbers
  (durations and `slip_threshold` non-negative). A character threshold
  was previously compared as text and silently gave wrong results; `NA`
  returned missing values.

- [`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md)
  refuses grids with fewer than three rows or two columns, where its
  regions used to overlap, and
  [`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md)
  refuses an axis with a single grid line. Their handling of odd grid
  sizes is documented and unchanged.

- [`pr_read_mask()`](https://cttir.github.io/pressR/reference/pr_read_mask.md)
  rejects non-numeric tokens inside the mask matrix instead of returning
  missing cells.

- Recordings without frames no longer produce warnings in
  [`pr_calc_seat_hotspot()`](https://cttir.github.io/pressR/reference/pr_calc_seat_hotspot.md)
  and
  [`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md)
  (whose regional maxima are now `NA` instead of `-Inf`);
  [`pr_interpolate()`](https://cttir.github.io/pressR/reference/pr_interpolate.md)
  and
  [`pr_calc_saddle_slip()`](https://cttir.github.io/pressR/reference/pr_calc_saddle_slip.md)
  explain that there is nothing to interpolate or compare instead of
  failing with an internal error.

- Region overlays on pressure maps are drawn as region boundaries
  instead of one outlined tile per sensor, which hid the pressure
  picture on platforms and seat mats.
  [`pr_plot_foot_report()`](https://cttir.github.io/pressR/reference/pr_plot_foot_report.md)
  gives the regional bar chart and the force curve the full width (panel
  order unchanged), and the composite reports set compact, top-aligned
  legends side by side on their map and centre-of-pressure panels and
  drop overlapping map axis labels, so legends no longer overlap panel
  titles, also at the default figure size of the reference pages.
  [`pr_plot_heatmap_masked()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap_masked.md)
  refuses unnamed masks, which it used to skip without drawing them; an
  empty mask list still draws the plain heatmap.

- The synthetic insole example loads the forefoot in the layout’s
  metatarsal rows; its peak previously fell into the midfoot region.

- [`pr_read_ascii()`](https://cttir.github.io/pressR/reference/pr_read_ascii.md)
  and
  [`pr_read_auto()`](https://cttir.github.io/pressR/reference/pr_read_auto.md)
  infer the horse (248 sensors) and bicycle (192 sensors) saddle layouts
  from a `System: saddle_mat` header, so the file written by
  `pr_example_files("saddle")` reads back, including as an upload in the
  app.

- The app no longer prints a stray `NULL` before a recording is loaded,
  and its on-screen tables show six significant digits; downloads and
  reports keep full precision.

- The saddle report scales its composite figure to the text width; in
  PDF reports the right-hand panels were previously cut off at the page
  edge.

- The tests read a synthetic Novel/Pliance saddle export,
  `tests/testthat/fixtures/synthetic_saddle_MS.asc`, written by
  `data-raw/synthetic_saddle.R` with invented header values. Its
  pressures are designed in a test helper, which is the ground truth for
  the reader, stride, symmetry, regional and sensor-quality tests.

- The documentation of the cohort, provenance, symmetry, sensor-quality
  and temporal functions describes them in general terms instead of
  quoting figures from one data set, and the cohort and provenance tests
  use synthetic designs. The two design checks that needed a local
  design file now run on a synthetic cohort instead of being skipped.

This is an explicitly versioned successor. Version 0.1.0 and its
manuscript contract remain preserved at commit 5f5b370 and in the
baseline audit records.

- Recognise Novel Pliance content through automatic import and temporary
  upload filenames; reject malformed numeric fields and contradictory
  sampling rates.
- Make generic ASCII and CSV imports strict. Missing sensor values no
  longer become zero; mismatched widths are no longer padded or
  truncated. Exported timestamps and sensor IDs round-trip without
  default-rate substitution. Inferred layouts now align named wide
  columns and reject incompatible long-form sensor identities. Optional
  Pliance channel order uses exact field matching.
- Refuse numeric text outside the supported non-zero magnitude range
  `1e-290` to `1e290`, and conversions with gross disagreement or
  underflow. These checks prevent observed parser corruption at extreme
  values and cost additional import time; exact binary replay uses
  version 2 bundles.
- Validate stored layout and trial dimensions before analysis. Use
  scaled arithmetic when finite measurements would otherwise overflow or
  underflow, and report unrepresentable results explicitly. Missing
  saddle regions yield an unknown bridge result instead of a negative
  finding.
- Add checksum-verified bundles preserving typed metadata and full
  layout context. Version 2 additionally preserves exact binary
  measurements and timing; the CSV remains an inspection/exchange view.
  Version 1 reading retains its decimal precision limitations. Bundle
  input must come from a trusted source.
- Preserve existing CSV/report outputs after reported replacement
  failures, including on Windows; retain and report a backup if
  restoration fails. Refuse symbolic-link destinations using the
  portable `fs` dependency. Archive member aliases no longer silently
  overwrite an earlier selected member.
- Correct force-sensor units, unknown calibration, grid-coordinate
  plots, mask indexing, and all-zero summaries. Coordinate exports use
  `x`, `y` and an explicit unit; rollover uses `cop_x`, `cop_y` and
  `coordinate_unit`. Interpolation exposes `x_grid`/`y_grid`, not
  fictitious millimetres. COP paths use adjacent valid frames; mean
  velocity is weighted by observed time. Duplicate COP timestamps are
  rejected.
- Preserve declared cohort factor levels and reject conflicting
  contracts.
- Separate corrected temporal analysis, historical-method re-execution
  and measurement-bound reference replay. Corrected sampling and
  numerical plateau handling intentionally change some historical
  cycles. Exact replay requires saved cycle boundaries; legacy execution
  alone cannot promise it.
- Correct attribution of the six saddle observations to Nyikos (2005),
  and withdraw unsupported legacy numbers. Reference overlays require
  source-compatible units, species, gait and mask definitions; reports
  enable no overlay by default.
- Add HR/RR workbook import with original cells and source positions,
  image metadata registration without invented temperatures, bounded
  archive extraction, source inventories and explicit-key modality
  linking. Identical files retain identities.
- Add Shiny comparison uploads, temporal profile selection, real report
  downloads, selected-mask CSV/report exports, failed-upload state
  clearing and a configurable 128 MiB upload default. Application launch
  restores previous options.
- Render reports in isolated temporary directories and replace completed
  outputs only after success. Add unit/availability tables and
  provenance. Treat recording names and metadata as literal report text.
  Foot report plots and timing tables use separate readable panels;
  missing provenance is explicit.
- Add `jsonlite`, `digest` and `fs` imports; `readxl`, `archive` and
  fixture-only `writexl` are optional dependencies. The successor API
  snapshot is reviewed independently of the frozen 0.1.0 contract.
  Declare Shiny 1.6.0, bslib 0.5.0 and testthat 3.2.0 minimums for the
  application accessibility and test mocking APIs used by this version.

## pressR 0.1.0

### Initial release

#### Parsers

- [`pr_read_ascii()`](https://cttir.github.io/pressR/reference/pr_read_ascii.md):
  Parse ASCII pressure data exports.
- [`pr_read_csv()`](https://cttir.github.io/pressR/reference/pr_read_csv.md):
  Parse generic CSV pressure data (wide or long).
- [`pr_read_forcesensor()`](https://cttir.github.io/pressR/reference/pr_read_forcesensor.md):
  Parse force sensor data.
- [`pr_read_mask()`](https://cttir.github.io/pressR/reference/pr_read_mask.md):
  Parse region mask files.
- [`pr_read_auto()`](https://cttir.github.io/pressR/reference/pr_read_auto.md):
  Auto-detect and dispatch.

#### Sensor Layouts

- [`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md):
  Construct custom layouts.
- [`pr_layout_insole()`](https://cttir.github.io/pressR/reference/pr_layout_insole.md),
  [`pr_layout_platform()`](https://cttir.github.io/pressR/reference/pr_layout_platform.md),
  [`pr_layout_mat()`](https://cttir.github.io/pressR/reference/pr_layout_mat.md),
  [`pr_layout_saddle()`](https://cttir.github.io/pressR/reference/pr_layout_saddle.md),
  [`pr_layout_seat()`](https://cttir.github.io/pressR/reference/pr_layout_seat.md),
  [`pr_layout_glove()`](https://cttir.github.io/pressR/reference/pr_layout_glove.md):
  predefined layouts.
- [`pr_layout_list()`](https://cttir.github.io/pressR/reference/pr_layout_list.md)
  lists available layouts.
- [`pr_validate_layout()`](https://cttir.github.io/pressR/reference/pr_validate_layout.md)
  validates a layout.

#### S3 classes

- `pr_layout`, `pr_trial`, `pr_dataset`, `pr_cop`, `pr_mask`.

#### Region Masks

- [`pr_mask()`](https://cttir.github.io/pressR/reference/pr_mask.md),
  [`pr_mask_default()`](https://cttir.github.io/pressR/reference/pr_mask_default.md),
  [`pr_mask_apply()`](https://cttir.github.io/pressR/reference/pr_mask_apply.md),
  [`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md),
  [`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md),
  [`pr_mask_foot_auto()`](https://cttir.github.io/pressR/reference/pr_mask_foot_auto.md).

#### Per-frame and trial analysis

- [`pr_calc_peak_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_peak_pressure.md),
  [`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md),
  [`pr_calc_force()`](https://cttir.github.io/pressR/reference/pr_calc_force.md),
  [`pr_calc_contact_area()`](https://cttir.github.io/pressR/reference/pr_calc_contact_area.md),
  [`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md),
  [`pr_calc_loaded_rate()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_rate.md),
  [`pr_calc_pti()`](https://cttir.github.io/pressR/reference/pr_calc_pti.md),
  [`pr_calc_impulse()`](https://cttir.github.io/pressR/reference/pr_calc_impulse.md),
  [`pr_calc_contact_time()`](https://cttir.github.io/pressR/reference/pr_calc_contact_time.md),
  [`pr_calc_cop_path()`](https://cttir.github.io/pressR/reference/pr_calc_cop_path.md),
  [`pr_calc_cop_excursion()`](https://cttir.github.io/pressR/reference/pr_calc_cop_excursion.md).
- [`pr_summary()`](https://cttir.github.io/pressR/reference/pr_summary.md):
  comprehensive trial summary.
- [`pr_calc_symmetry_index()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_index.md),
  [`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md).

#### Application-specific analysis

- Gait:
  [`pr_calc_gait_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_gait_cycles.md),
  [`pr_calc_rollover()`](https://cttir.github.io/pressR/reference/pr_calc_rollover.md).
- Saddle:
  [`pr_calc_saddle_bridge()`](https://cttir.github.io/pressR/reference/pr_calc_saddle_bridge.md),
  [`pr_calc_saddle_slip()`](https://cttir.github.io/pressR/reference/pr_calc_saddle_slip.md).
- Seating:
  [`pr_calc_seat_hotspot()`](https://cttir.github.io/pressR/reference/pr_calc_seat_hotspot.md).

#### Reference thresholds

- [`pr_ref_saddle()`](https://cttir.github.io/pressR/reference/pr_ref_saddle.md),
  [`pr_ref_diabetic_foot()`](https://cttir.github.io/pressR/reference/pr_ref_diabetic_foot.md),
  [`pr_ref_wheelchair()`](https://cttir.github.io/pressR/reference/pr_ref_wheelchair.md).

#### Visualisation

- [`pr_plot_heatmap()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap.md),
  [`pr_plot_heatmap_masked()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap_masked.md),
  [`pr_plot_3d()`](https://cttir.github.io/pressR/reference/pr_plot_3d.md),
  [`pr_plot_force_time()`](https://cttir.github.io/pressR/reference/pr_plot_force_time.md),
  [`pr_plot_pressure_time()`](https://cttir.github.io/pressR/reference/pr_plot_pressure_time.md),
  [`pr_plot_cop()`](https://cttir.github.io/pressR/reference/pr_plot_cop.md),
  [`pr_plot_cop_butterfly()`](https://cttir.github.io/pressR/reference/pr_plot_cop_butterfly.md),
  [`pr_plot_contact_area()`](https://cttir.github.io/pressR/reference/pr_plot_contact_area.md),
  [`pr_plot_regional_bar()`](https://cttir.github.io/pressR/reference/pr_plot_regional_bar.md),
  [`pr_plot_symmetry()`](https://cttir.github.io/pressR/reference/pr_plot_symmetry.md),
  [`pr_plot_comparison()`](https://cttir.github.io/pressR/reference/pr_plot_comparison.md),
  [`pr_plot_saddle_report()`](https://cttir.github.io/pressR/reference/pr_plot_saddle_report.md),
  [`pr_plot_foot_report()`](https://cttir.github.io/pressR/reference/pr_plot_foot_report.md).

#### Export and reporting

- [`pr_export_csv()`](https://cttir.github.io/pressR/reference/pr_export_csv.md),
  [`pr_export_report()`](https://cttir.github.io/pressR/reference/pr_export_report.md).

#### Batch processing

- [`pr_batch_summary()`](https://cttir.github.io/pressR/reference/pr_batch_summary.md),
  [`pr_merge_trials()`](https://cttir.github.io/pressR/reference/pr_merge_trials.md).

#### Shiny application

- [`pr_run_app()`](https://cttir.github.io/pressR/reference/pr_run_app.md):
  interactive 6-tab data explorer.

#### Example data

- [`pr_example_trial()`](https://cttir.github.io/pressR/reference/pr_example_trial.md),
  [`pr_example_files()`](https://cttir.github.io/pressR/reference/pr_example_files.md).

#### Utilities

- [`pr_interpolate()`](https://cttir.github.io/pressR/reference/pr_interpolate.md),
  [`pr_filter_time()`](https://cttir.github.io/pressR/reference/pr_filter_time.md),
  [`pr_downsample()`](https://cttir.github.io/pressR/reference/pr_downsample.md).
