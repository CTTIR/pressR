# Package index

## Parsers

Read pressure data from various file formats

- [`pr_read_ascii()`](https://cttir.github.io/pressR/reference/pr_read_ascii.md)
  : Read ASCII Pressure Data Export
- [`pr_read_csv()`](https://cttir.github.io/pressR/reference/pr_read_csv.md)
  : Read Pressure Data from CSV
- [`pr_read_forcesensor()`](https://cttir.github.io/pressR/reference/pr_read_forcesensor.md)
  : Read Force Sensor Data
- [`pr_read_mask()`](https://cttir.github.io/pressR/reference/pr_read_mask.md)
  : Read Mask File
- [`pr_read_auto()`](https://cttir.github.io/pressR/reference/pr_read_auto.md)
  : Auto-Detect and Read a Pressure Data File

## Sensor Layouts

Predefined and custom sensor coordinate layouts

- [`pr_layout()`](https://cttir.github.io/pressR/reference/pr_layout.md)
  : Create a Pressure Sensor Layout
- [`pr_layout_insole()`](https://cttir.github.io/pressR/reference/pr_layout_insole.md)
  : Get In-Shoe Pressure Insole Layout
- [`pr_layout_platform()`](https://cttir.github.io/pressR/reference/pr_layout_platform.md)
  : Get Pressure Platform Layout
- [`pr_layout_mat()`](https://cttir.github.io/pressR/reference/pr_layout_mat.md)
  : Get Generic Sensor Mat Layout
- [`pr_layout_saddle()`](https://cttir.github.io/pressR/reference/pr_layout_saddle.md)
  : Get Saddle Pressure Mat Layout
- [`pr_layout_seat()`](https://cttir.github.io/pressR/reference/pr_layout_seat.md)
  : Get Seating Pressure Mat Layout
- [`pr_layout_glove()`](https://cttir.github.io/pressR/reference/pr_layout_glove.md)
  : Get Glove Sensor Layout
- [`pr_layout_list()`](https://cttir.github.io/pressR/reference/pr_layout_list.md)
  : List All Built-In Sensor Layouts
- [`pr_validate_layout()`](https://cttir.github.io/pressR/reference/pr_validate_layout.md)
  : Validate a Pressure Sensor Layout

## S3 Classes

- [`pr_trial()`](https://cttir.github.io/pressR/reference/pr_trial.md) :
  Create a Pressure Trial Object
- [`pr_dataset()`](https://cttir.github.io/pressR/reference/pr_dataset.md)
  : Create a Pressure Dataset
- [`pr_cop()`](https://cttir.github.io/pressR/reference/pr_cop.md) :
  Center of Pressure Object
- [`pr_mask()`](https://cttir.github.io/pressR/reference/pr_mask.md) :
  Create a Region Mask

## Region Masks

- [`pr_mask_default()`](https://cttir.github.io/pressR/reference/pr_mask_default.md)
  : Get Default Region Masks for a Layout
- [`pr_mask_apply()`](https://cttir.github.io/pressR/reference/pr_mask_apply.md)
  : Apply Masks to Extract Regional Pressure Data
- [`pr_mask_foot_auto()`](https://cttir.github.io/pressR/reference/pr_mask_foot_auto.md)
  : Auto-Segment Foot Regions from Pressure Data
- [`pr_mask_saddle_6()`](https://cttir.github.io/pressR/reference/pr_mask_saddle_6.md)
  : Standard 6-Region Saddle Mask
- [`pr_mask_symmetry()`](https://cttir.github.io/pressR/reference/pr_mask_symmetry.md)
  : Split Layout into Left/Right Halves

## Per-Frame Analysis

- [`pr_calc_peak_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_peak_pressure.md)
  : Calculate Peak Pressure Per Frame
- [`pr_calc_mean_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure.md)
  : Calculate Mean Pressure Per Frame
- [`pr_calc_force()`](https://cttir.github.io/pressR/reference/pr_calc_force.md)
  : Calculate Total Force Per Frame
- [`pr_calc_contact_area()`](https://cttir.github.io/pressR/reference/pr_calc_contact_area.md)
  : Calculate Contact Area Per Frame
- [`pr_calc_cop()`](https://cttir.github.io/pressR/reference/pr_calc_cop.md)
  : Calculate Center of Pressure
- [`pr_calc_loaded_rate()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_rate.md)
  : Calculate Fraction of Loaded Sensors Per Frame
- [`pr_calc_pti()`](https://cttir.github.io/pressR/reference/pr_calc_pti.md)
  : Pressure-Time Integral Per Sensor
- [`pr_calc_impulse()`](https://cttir.github.io/pressR/reference/pr_calc_impulse.md)
  : Force-Time Integral (Impulse)
- [`pr_calc_contact_time()`](https://cttir.github.io/pressR/reference/pr_calc_contact_time.md)
  : Total Contact Time
- [`pr_calc_cop_path()`](https://cttir.github.io/pressR/reference/pr_calc_cop_path.md)
  : Total COP Path Length
- [`pr_calc_cop_excursion()`](https://cttir.github.io/pressR/reference/pr_calc_cop_excursion.md)
  : COP Excursion (Anterior-Posterior and Medial-Lateral Range)

## Trial Summary

- [`pr_summary()`](https://cttir.github.io/pressR/reference/pr_summary.md)
  : Summarize Trial Pressure Parameters
- [`pr_calc_symmetry_index()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_index.md)
  : Symmetry Index

## Regional Analysis

- [`pr_calc_regional()`](https://cttir.github.io/pressR/reference/pr_calc_regional.md)
  : Compute Parameters by Region

## Application-Specific Analysis

- [`pr_calc_gait_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_gait_cycles.md)
  : Detect Gait Cycles from Foot Pressure Data
- [`pr_calc_rollover()`](https://cttir.github.io/pressR/reference/pr_calc_rollover.md)
  : Analyze COP Rollover Pattern
- [`pr_calc_saddle_bridge()`](https://cttir.github.io/pressR/reference/pr_calc_saddle_bridge.md)
  : Detect Saddle Bridge Formation
- [`pr_calc_saddle_slip()`](https://cttir.github.io/pressR/reference/pr_calc_saddle_slip.md)
  : Detect Saddle Slip / Asymmetric Loading
- [`pr_calc_seat_hotspot()`](https://cttir.github.io/pressR/reference/pr_calc_seat_hotspot.md)
  : Identify Pressure Hotspots

## Reference Thresholds

- [`pr_ref_saddle()`](https://cttir.github.io/pressR/reference/pr_ref_saddle.md)
  : Saddle Fit Reference Thresholds
- [`pr_ref_diabetic_foot()`](https://cttir.github.io/pressR/reference/pr_ref_diabetic_foot.md)
  : Diabetic Foot Pressure Thresholds
- [`pr_ref_wheelchair()`](https://cttir.github.io/pressR/reference/pr_ref_wheelchair.md)
  : Wheelchair Seating Pressure Thresholds

## Visualization

- [`pr_plot_heatmap()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap.md)
  : Plot Pressure Heatmap
- [`pr_plot_heatmap_masked()`](https://cttir.github.io/pressR/reference/pr_plot_heatmap_masked.md)
  : Plot Pressure Heatmap with Region Overlay
- [`pr_plot_3d()`](https://cttir.github.io/pressR/reference/pr_plot_3d.md)
  : Interactive 3D Pressure Surface
- [`pr_plot_force_time()`](https://cttir.github.io/pressR/reference/pr_plot_force_time.md)
  : Plot Force vs Time
- [`pr_plot_pressure_time()`](https://cttir.github.io/pressR/reference/pr_plot_pressure_time.md)
  : Plot Peak and Mean Pressure vs Time
- [`pr_plot_cop()`](https://cttir.github.io/pressR/reference/pr_plot_cop.md)
  : Plot Center of Pressure Trajectory
- [`pr_plot_cop_butterfly()`](https://cttir.github.io/pressR/reference/pr_plot_cop_butterfly.md)
  : COP Butterfly Plot Across Gait Cycles
- [`pr_plot_contact_area()`](https://cttir.github.io/pressR/reference/pr_plot_contact_area.md)
  : Plot Contact Area vs Time
- [`pr_plot_regional_bar()`](https://cttir.github.io/pressR/reference/pr_plot_regional_bar.md)
  : Regional Parameter Comparison Bar Chart
- [`pr_plot_symmetry()`](https://cttir.github.io/pressR/reference/pr_plot_symmetry.md)
  : Left/Right Symmetry Plot
- [`pr_plot_comparison()`](https://cttir.github.io/pressR/reference/pr_plot_comparison.md)
  : Compare Two Trials
- [`pr_plot_saddle_report()`](https://cttir.github.io/pressR/reference/pr_plot_saddle_report.md)
  : Saddle Fit Report Panel
- [`pr_plot_foot_report()`](https://cttir.github.io/pressR/reference/pr_plot_foot_report.md)
  : Foot Pressure Report Panel
- [`plot(`*`<pr_layout>`*`)`](https://cttir.github.io/pressR/reference/plot.pr_layout.md)
  : Plot a Sensor Layout
- [`plot(`*`<pr_trial>`*`)`](https://cttir.github.io/pressR/reference/plot.pr_trial.md)
  : Plot a Pressure Trial

## Export & Reporting

- [`pr_export_csv()`](https://cttir.github.io/pressR/reference/pr_export_csv.md)
  : Export Analysis Results to CSV
- [`pr_export_report()`](https://cttir.github.io/pressR/reference/pr_export_report.md)
  : Generate an Analysis Report

## Batch Processing

- [`pr_batch_summary()`](https://cttir.github.io/pressR/reference/pr_batch_summary.md)
  : Batch Summary Across Multiple Trials
- [`pr_merge_trials()`](https://cttir.github.io/pressR/reference/pr_merge_trials.md)
  : Merge Trials into a Dataset

## Shiny Application

- [`pr_run_app()`](https://cttir.github.io/pressR/reference/pr_run_app.md)
  : Launch the Interactive Pressure Data Explorer

## Example Data

- [`pr_example_trial()`](https://cttir.github.io/pressR/reference/pr_example_trial.md)
  : Generate a Synthetic Pressure Trial
- [`pr_example_files()`](https://cttir.github.io/pressR/reference/pr_example_files.md)
  : Write Sample Pressure Data Files

## Utilities

- [`pr_interpolate()`](https://cttir.github.io/pressR/reference/pr_interpolate.md)
  : Spatial Interpolation of Pressure Data (for Display)
- [`pr_filter_time()`](https://cttir.github.io/pressR/reference/pr_filter_time.md)
  : Subset a Trial to a Time Window
- [`pr_downsample()`](https://cttir.github.io/pressR/reference/pr_downsample.md)
  : Downsample a Trial

## Cohort Ingest

Read a whole study into one object: a Pliance/Novel .asc reader that
honours the recorded time column and the device channel map, directory
batch reading, and filename-derived metadata.

- [`pr_read_pliance()`](https://cttir.github.io/pressR/reference/pr_read_pliance.md)
  : Read a Novel/Pliance ASCII Export
- [`pr_read_dir()`](https://cttir.github.io/pressR/reference/pr_read_dir.md)
  : Read a Directory of Pressure Exports
- [`pr_meta_from_filename()`](https://cttir.github.io/pressR/reference/pr_meta_from_filename.md)
  : Split Metadata Fields Out of a File Name

## Device Channel Maps

Layouts built from an explicit channel-to-grid index map, for devices
whose channel order is not the grid’s column-major order.

- [`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md)
  : Build a Layout From an Explicit Channel Map
- [`pr_layout_saddle_novel()`](https://cttir.github.io/pressR/reference/pr_layout_saddle_novel.md)
  : Novel/Pliance 16x16 Saddle Mat Layout
- [`pr_channel_order()`](https://cttir.github.io/pressR/reference/pr_channel_order.md)
  : Raw Device Channel Order for a Layout

## Cohort Handling

Design tables, filtering as an assertion, and dataset validation.

- [`pr_design_table()`](https://cttir.github.io/pressR/reference/pr_design_table.md)
  : Cohort Design Table
- [`pr_dataset_filter()`](https://cttir.github.io/pressR/reference/pr_dataset_filter.md)
  : Filter a Dataset by Trial Metadata, With Count Assertions
- [`pr_assert_cohort()`](https://cttir.github.io/pressR/reference/pr_assert_cohort.md)
  : Assert Cohort Size
- [`pr_validate_dataset()`](https://cttir.github.io/pressR/reference/pr_validate_dataset.md)
  : Validate Cohort Homogeneity

## Frame Metrics (whole-grid)

Whole-grid counterparts to the loaded-cell family. See the details on
each for the denominator distinction.

- [`pr_frame_metrics()`](https://cttir.github.io/pressR/reference/pr_frame_metrics.md)
  : Per-Frame Metric Table
- [`pr_calc_mean_pressure_grid()`](https://cttir.github.io/pressR/reference/pr_calc_mean_pressure_grid.md)
  : Whole-Grid Mean Pressure Per Frame
- [`pr_calc_total_pressure()`](https://cttir.github.io/pressR/reference/pr_calc_total_pressure.md)
  : Total Pressure Per Frame
- [`pr_calc_loaded_count()`](https://cttir.github.io/pressR/reference/pr_calc_loaded_count.md)
  : Loaded Cell Count Per Frame
- [`pr_calc_cop_grid()`](https://cttir.github.io/pressR/reference/pr_calc_cop_grid.md)
  : Center of Pressure in Grid Index Units
- [`pr_calc_pci()`](https://cttir.github.io/pressR/reference/pr_calc_pci.md)
  : Peak/Mean Pressure Concentration Index
- [`pr_ref_pci()`](https://cttir.github.io/pressR/reference/pr_ref_pci.md)
  : Pressure Concentration Index Interpretation Bands

## Per-Sensor Maps

Time-averaged per-sensor statistics, feature matrices, and streaming
cohort summaries.

- [`pr_sensor_map()`](https://cttir.github.io/pressR/reference/pr_sensor_map.md)
  : Per-Sensor Statistics Over Time
- [`pr_profile_matrix()`](https://cttir.github.io/pressR/reference/pr_profile_matrix.md)
  : Per-Sensor Feature Matrix for a Dataset
- [`pr_batch_frame_summary()`](https://cttir.github.io/pressR/reference/pr_batch_frame_summary.md)
  : Per-Recording Frame Summary for a Whole Cohort

## Sensor Quality and Gradients

- [`pr_sensor_quality()`](https://cttir.github.io/pressR/reference/pr_sensor_quality.md)
  : Per-Sensor Hardware Quality Across a Cohort
- [`pr_calc_gradient()`](https://cttir.github.io/pressR/reference/pr_calc_gradient.md)
  : Spatial Pressure Gradient Magnitude

## Zones and Symmetry

Row-band masks with an explicit split, zone statistics on the
time-averaged map, and symmetry with a mirror-balance control.

- [`pr_mask_rowbands()`](https://cttir.github.io/pressR/reference/pr_mask_rowbands.md)
  : Row-Band Region Masks With an Explicit Split
- [`pr_calc_regional_map()`](https://cttir.github.io/pressR/reference/pr_calc_regional_map.md)
  : Zone Statistics of the Time-Averaged Sensor Map
- [`pr_calc_symmetry_map()`](https://cttir.github.io/pressR/reference/pr_calc_symmetry_map.md)
  : Left/Right Asymmetry of the Time-Averaged Sensor Map
- [`pr_mask_mirror_balance()`](https://cttir.github.io/pressR/reference/pr_mask_mirror_balance.md)
  : Largest Mirror-Symmetric Subset of a Mask
- [`pr_symmetry_sensitivity()`](https://cttir.github.io/pressR/reference/pr_symmetry_sensitivity.md)
  : Asymmetry Index Across a Family of Masks
- [`pr_calc_cop_masked()`](https://cttir.github.io/pressR/reference/pr_calc_cop_masked.md)
  : Centre of Pressure Per Region

## Temporal Structure

Spectra and oscillation-based stride detection, for continuously loaded
sensors that never unload between contacts.

- [`pr_calc_spectrum()`](https://cttir.github.io/pressR/reference/pr_calc_spectrum.md)
  : Power Spectrum of a Frame-Level Signal
- [`pr_calc_dominant_freq()`](https://cttir.github.io/pressR/reference/pr_calc_dominant_freq.md)
  : Dominant Oscillation Frequency in a Band
- [`pr_calc_stride_cycles()`](https://cttir.github.io/pressR/reference/pr_calc_stride_cycles.md)
  : Segment a Recording into Stride Cycles
- [`pr_calc_phase_map()`](https://cttir.github.io/pressR/reference/pr_calc_phase_map.md)
  : Sensor Map Averaged Over the Stride Cycle
- [`pr_cop_shape()`](https://cttir.github.io/pressR/reference/pr_cop_shape.md)
  : Loop Geometry of a COP Trajectory

## Provenance and Design Integrity

- [`pr_lock_table()`](https://cttir.github.io/pressR/reference/pr_lock_table.md)
  : Lock a Table's Content and Shape
- [`pr_verify_lock()`](https://cttir.github.io/pressR/reference/pr_verify_lock.md)
  : Verify a Table Against Its Lock File
- [`pr_validate_summary()`](https://cttir.github.io/pressR/reference/pr_validate_summary.md)
  : Two-Tier Data Frame Validation
- [`pr_factor_contract()`](https://cttir.github.io/pressR/reference/pr_factor_contract.md)
  : Assert the Level Sets of Design Factors
- [`pr_design_gaps()`](https://cttir.github.io/pressR/reference/pr_design_gaps.md)
  : Observed Design Cells Against the Full Crossing
