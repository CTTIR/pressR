# pressR 0.2.0 (development)

* Standardize the named v5 package logo across README, documentation pages
  and available application headers, with matching light and dark artwork.


This is an explicitly versioned successor. Version 0.1.0 and its manuscript
contract remain preserved at commit 5f5b370 and in the baseline audit records.

* Recognize Novel Pliance content through automatic import and temporary upload
  filenames; reject malformed numeric fields and contradictory sampling rates.
* Make generic ASCII and CSV imports strict. Missing sensor values no longer become
  zero; mismatched widths are no longer padded or truncated. Exported timestamps
  and sensor IDs round-trip without default-rate substitution.
  Inferred layouts now align named wide columns and reject incompatible long-form
  sensor identities. Optional Pliance channel order uses exact field matching.
* Refuse numeric text outside the supported nonzero magnitude range
  `1e-290` to `1e290`, and conversions with gross disagreement or underflow.
  These checks prevent observed parser corruption at extreme values and cost
  additional import time; exact binary replay uses version 2 bundles.
* Validate stored layout and trial dimensions before analysis. Use scaled
  arithmetic when finite measurements would otherwise overflow or underflow,
  and report unrepresentable results explicitly. Missing saddle regions yield
  an unknown bridge result instead of a negative finding.
* Add checksum-verified bundles preserving typed metadata and full layout context.
  Version 2 additionally preserves exact binary measurements and timing; the CSV
  remains an inspection/exchange view. Version 1 reading retains its decimal
  precision limitations. Bundle input must come from a trusted source.
* Preserve existing CSV/report outputs after reported replacement failures,
  including on Windows; retain and report a backup if restoration fails. Refuse
  symbolic-link destinations using the portable `fs` dependency. Archive member
  aliases no longer silently overwrite an earlier selected member.
* Correct force-sensor units, unknown calibration, grid-coordinate plots, mask
  indexing, and all-zero summaries. Coordinate exports use `x`, `y` and an explicit
  unit; rollover uses `cop_x`, `cop_y` and `coordinate_unit`. Interpolation exposes
  `x_grid`/`y_grid`, not fictitious millimetres. COP paths use adjacent valid frames;
  mean velocity is weighted by observed time. Duplicate COP timestamps are rejected.
* Preserve declared cohort factor levels and reject conflicting contracts.
* Separate corrected temporal analysis, historical-method re-execution and
  measurement-bound reference replay. Corrected sampling and numerical plateau
  handling intentionally change some historical cycles. Exact replay requires
  saved cycle boundaries; legacy execution alone cannot promise it.
* Correct attribution of the six saddle observations to Nyikos (2005), and withdraw
  unsupported legacy numbers. Reference overlays require source-compatible units,
  species, gait and mask definitions; reports enable no overlay by default.
* Add HR/RR workbook import with original cells and source positions, image metadata
  registration without invented temperatures, bounded archive extraction, source
  inventories and explicit-key modality linking. Identical files retain identities.
* Add Shiny comparison uploads, temporal profile selection, real report downloads,
  selected-mask CSV/report exports, failed-upload state clearing and a configurable
  128 MiB upload default. Application launch restores previous options.
* Render reports in isolated temporary directories and replace completed outputs
  only after success. Add unit/availability tables and provenance.
  Treat recording names and metadata as literal report text. Foot report plots
  and timing tables use separate readable panels; missing provenance is explicit.
* Add `jsonlite`, `digest` and `fs` imports; `readxl`, `archive` and fixture-only `writexl`
  are optional dependencies. The successor API snapshot is reviewed independently
  of the frozen 0.1.0 contract.
  Declare Shiny 1.6.0, bslib 0.5.0 and testthat 3.2.0 minimums for the application
  accessibility and test mocking APIs used by this version.

# pressR 0.1.0

## Initial release

### Parsers

* `pr_read_ascii()`: Parse ASCII pressure data exports.
* `pr_read_csv()`: Parse generic CSV pressure data (wide or long).
* `pr_read_forcesensor()`: Parse force sensor data.
* `pr_read_mask()`: Parse region mask files.
* `pr_read_auto()`: Auto-detect and dispatch.

### Sensor Layouts

* `pr_layout()`: Construct custom layouts.
* `pr_layout_insole()`, `pr_layout_platform()`, `pr_layout_mat()`,
  `pr_layout_saddle()`, `pr_layout_seat()`, `pr_layout_glove()`:
  predefined layouts.
* `pr_layout_list()` lists available layouts.
* `pr_validate_layout()` validates a layout.

### S3 classes

* `pr_layout`, `pr_trial`, `pr_dataset`, `pr_cop`, `pr_mask`.

### Region Masks

* `pr_mask()`, `pr_mask_default()`, `pr_mask_apply()`,
  `pr_mask_saddle_6()`, `pr_mask_symmetry()`, `pr_mask_foot_auto()`.

### Per-frame and trial analysis

* `pr_calc_peak_pressure()`, `pr_calc_mean_pressure()`,
  `pr_calc_force()`, `pr_calc_contact_area()`, `pr_calc_cop()`,
  `pr_calc_loaded_rate()`, `pr_calc_pti()`, `pr_calc_impulse()`,
  `pr_calc_contact_time()`, `pr_calc_cop_path()`,
  `pr_calc_cop_excursion()`.
* `pr_summary()`: comprehensive trial summary.
* `pr_calc_symmetry_index()`, `pr_calc_regional()`.

### Application-specific analysis

* Gait: `pr_calc_gait_cycles()`, `pr_calc_rollover()`.
* Saddle: `pr_calc_saddle_bridge()`, `pr_calc_saddle_slip()`.
* Seating: `pr_calc_seat_hotspot()`.

### Reference thresholds

* `pr_ref_saddle()`, `pr_ref_diabetic_foot()`,
  `pr_ref_wheelchair()`.

### Visualization

* `pr_plot_heatmap()`, `pr_plot_heatmap_masked()`, `pr_plot_3d()`,
  `pr_plot_force_time()`, `pr_plot_pressure_time()`,
  `pr_plot_cop()`, `pr_plot_cop_butterfly()`,
  `pr_plot_contact_area()`, `pr_plot_regional_bar()`,
  `pr_plot_symmetry()`, `pr_plot_comparison()`,
  `pr_plot_saddle_report()`, `pr_plot_foot_report()`.

### Export and reporting

* `pr_export_csv()`, `pr_export_report()`.

### Batch processing

* `pr_batch_summary()`, `pr_merge_trials()`.

### Shiny application

* `pr_run_app()`: interactive 6-tab data explorer.

### Example data

* `pr_example_trial()`, `pr_example_files()`.

### Utilities

* `pr_interpolate()`, `pr_filter_time()`, `pr_downsample()`.
