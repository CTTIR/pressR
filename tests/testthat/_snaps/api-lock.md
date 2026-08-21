# exported API surface is unchanged

    Code
      cat(sigs, sep = "\n")
    Output
      pr_batch_summary(dataset)
      pr_calc_contact_area(trial, threshold = 0)
      pr_calc_contact_time(trial, threshold = 0)
      pr_calc_cop(trial, threshold = 0)
      pr_calc_cop_excursion(trial, threshold = 0)
      pr_calc_cop_path(trial, threshold = 0)
      pr_calc_force(trial)
      pr_calc_gait_cycles(trial, force_threshold = 20, min_stance_ms = 200, min_swing_ms = 100)
      pr_calc_impulse(trial)
      pr_calc_loaded_rate(trial, threshold = 0)
      pr_calc_mean_pressure(trial, threshold = 0)
      pr_calc_peak_pressure(trial, threshold = 0)
      pr_calc_pti(trial)
      pr_calc_regional(trial, masks = NULL, parameters = c("mpp", "mvp", "max_force", "contact_area", "pti_mean"), threshold = 0)
      pr_calc_rollover(trial, cycles = NULL, n_points = 51L)
      pr_calc_saddle_bridge(trial, masks = NULL, bridge_threshold = 0.5)
      pr_calc_saddle_slip(trial, masks = NULL, slip_threshold = 15)
      pr_calc_seat_hotspot(trial, threshold = 4.7, duration_s = 0)
      pr_calc_symmetry_index(trial, parameter = c("peak_pressure", "mean_pressure", "force", "contact_area"))
      pr_cop(x, y, time)
      pr_dataset(trials, group_var = "condition", name = "dataset")
      pr_downsample(trial, factor = 2L)
      pr_example_files(type = c("insole", "saddle", "platform", "all"))
      pr_example_trial(type = c("insole", "platform", "saddle_horse", "saddle_bicycle", "wheelchair", "custom"), duration_s = NULL, sampling_hz = 50, seed = 42)
      pr_export_csv(trial, path, what = c("summary", "regional", "pressure", "cop"), masks = NULL)
      pr_export_report(trial, output_file, format = c("html", "pdf"), template = c("generic", "saddle", "foot"), masks = NULL, thresholds = NULL)
      pr_filter_time(trial, from = 0, to = Inf)
      pr_interpolate(trial, factor = 2L)
      pr_layout(grid_rows, grid_cols, active, coords_mm, regions = list(), sensor_area_cm2 = 1, pressure_range = c(0, 600), pressure_unit = "kPa", name = "custom", description = "", manufacturer = "", model = "")
      pr_layout_glove()
      pr_layout_insole(size = c("standard", "wide"))
      pr_layout_list()
      pr_layout_mat(size = c("16", "32"))
      pr_layout_platform(model = c("st", "xl", "cl"))
      pr_layout_saddle(type = c("horse", "bicycle"))
      pr_layout_seat(type = c("wheelchair", "car", "office"))
      pr_mask(mask_matrix, name, layout)
      pr_mask_apply(trial, masks = NULL)
      pr_mask_default(layout)
      pr_mask_foot_auto(trial, n_regions = 7L, threshold = 1)
      pr_mask_saddle_6(layout)
      pr_mask_symmetry(layout, axis = c("vertical", "horizontal"))
      pr_merge_trials(..., group_var = "condition")
      pr_plot_3d(trial, frame = NULL, palette = "viridis")
      pr_plot_comparison(trial_a, trial_b, type = c("heatmap", "difference", "parameters"), labels = c("A", "B"))
      pr_plot_contact_area(trial, show_cycles = FALSE)
      pr_plot_cop(trial, show_layout = TRUE, color_by = c("time", "velocity"))
      pr_plot_cop_butterfly(trial, cycles = NULL)
      pr_plot_foot_report(trial)
      pr_plot_force_time(trial, show_cycles = FALSE)
      pr_plot_heatmap(trial, frame = NULL, type = c("mpp", "mvp", "pti", "contact"), show_regions = FALSE, palette = "viridis", range = NULL, interpolate = FALSE, title = NULL)
      pr_plot_heatmap_masked(trial, masks = NULL, frame = NULL, type = c("mpp", "mvp", "pti", "contact"), palette = "viridis", range = NULL, title = NULL)
      pr_plot_pressure_time(trial, show_cycles = FALSE)
      pr_plot_regional_bar(regional_data, parameter = "mpp", thresholds = NULL)
      pr_plot_saddle_report(trial, thresholds = NULL)
      pr_plot_symmetry(trial, parameter = c("peak_pressure", "mean_pressure", "force", "contact_area"))
      pr_read_ascii(path, layout = NULL, sampling_hz = NULL, separator = "auto", skip = NULL, verbose = TRUE)
      pr_read_auto(path, layout = NULL, verbose = TRUE)
      pr_read_csv(path, format = c("wide", "long"), layout = NULL, time_col = NULL, sampling_hz = 100, verbose = TRUE)
      pr_read_forcesensor(path, force_cols = NULL, time_col = "time", verbose = TRUE)
      pr_read_mask(path, layout = NULL, name = "imported", verbose = TRUE)
      pr_ref_diabetic_foot()
      pr_ref_saddle(source = c("vonpeinen2010", "monkemoller2005", "werner2002"))
      pr_ref_wheelchair()
      pr_run_app(trial = NULL, ...)
      pr_summary(trial, threshold = 0)
      pr_trial(pressure, time, layout, metadata = list(), sampling_hz = NULL)
      pr_validate_layout(layout)

# registered S3 methods are unchanged

    Code
      cat(methods, sep = "\n")
    Output
      [.pr_dataset
      as.data.frame.pr_trial
      c.pr_dataset
      length.pr_dataset
      plot.pr_layout
      plot.pr_trial
      print.pr_cop
      print.pr_dataset
      print.pr_layout
      print.pr_mask
      print.pr_saddle_bridge
      print.pr_saddle_slip
      print.pr_trial
      print.summary.pr_layout
      summary.pr_dataset
      summary.pr_layout
      summary.pr_trial

# declared dependencies are unchanged

    Code
      cat(out, sep = "\n")
    Output
      Depends:
        R (>= 4.1.0)
      Imports:
        DT
        bslib
        cli
        dplyr
        ggplot2
        patchwork
        plotly
        readr
        rlang
        shiny
        stats
        tibble
        tidyr
        tools
        utils

