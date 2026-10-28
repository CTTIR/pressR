# pressR (development version)

* Standardize the named v5 package logo across README, documentation pages
  and available application headers, with matching light and dark artwork.

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
