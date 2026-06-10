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
