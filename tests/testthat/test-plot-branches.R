# Branch coverage for plotting functions across R/plot-*.R.

test_that("pr_plot_heatmap supports each summary type", {
  tr <- pr_example_trial("insole")
  for (ty in c("mpp", "mvp", "pti", "contact")) {
    expect_s3_class(pr_plot_heatmap(tr, type = ty), "ggplot")
  }
})

test_that("pr_plot_heatmap errors on out-of-range frame", {
  tr <- pr_example_trial("custom")
  expect_error(pr_plot_heatmap(tr, frame = 0))
  expect_error(pr_plot_heatmap(tr, frame = tr$n_frames + 1))
})

test_that("pr_plot_heatmap errors on unknown palette", {
  expect_error(pr_plot_heatmap(pr_example_trial("custom"), palette = "rainbow"))
})

test_that("pr_plot_heatmap with show_regions overlays layout regions", {
  p <- pr_plot_heatmap(pr_example_trial("saddle_horse"), show_regions = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("pr_plot_heatmap_masked draws user-supplied masks", {
  tr <- pr_example_trial("saddle_horse")
  masks <- pr_mask_saddle_6(tr$layout)
  expect_s3_class(pr_plot_heatmap_masked(tr, masks = masks), "ggplot")
})

test_that("pr_plot_heatmap_masked falls back to layout regions when NULL", {
  expect_s3_class(
    pr_plot_heatmap_masked(pr_example_trial("saddle_horse"), masks = NULL),
    "ggplot"
  )
})

test_that("pr_plot_cop supports velocity coloring", {
  p <- pr_plot_cop(pr_example_trial("saddle_horse"), color_by = "velocity")
  expect_s3_class(p, "ggplot")
})

test_that("pr_plot_cop can omit the layout backdrop", {
  expect_s3_class(
    pr_plot_cop(pr_example_trial("saddle_horse"), show_layout = FALSE),
    "ggplot"
  )
})

test_that("pr_plot_cop_butterfly builds across cycles", {
  expect_s3_class(pr_plot_cop_butterfly(pr_example_trial("insole")), "ggplot")
})

test_that("pr_plot_cop_butterfly falls back when no cycles", {
  layout <- pr_layout_insole()
  tr <- pr_trial(matrix(0, 50, layout$n_sensors),
                 time = seq(0, by = 0.02, length.out = 50), layout = layout)
  p <- pr_plot_cop_butterfly(tr)
  expect_s3_class(p, "ggplot")
})

test_that("force/pressure/contact plots draw cycle bands when requested", {
  tr <- pr_example_trial("insole")
  expect_s3_class(pr_plot_force_time(tr, show_cycles = TRUE), "ggplot")
  expect_s3_class(pr_plot_pressure_time(tr, show_cycles = TRUE), "ggplot")
  expect_s3_class(pr_plot_contact_area(tr, show_cycles = TRUE), "ggplot")
})

test_that("pr_plot_regional_bar errors on missing parameter or bad data", {
  tr <- pr_example_trial("saddle_horse")
  reg <- pr_calc_regional(tr)
  expect_error(pr_plot_regional_bar(reg, "nonexistent"))
  expect_error(pr_plot_regional_bar(list(), "mpp"))
})

test_that("pr_plot_regional_bar draws threshold lines", {
  tr <- pr_example_trial("saddle_horse")
  reg <- pr_calc_regional(tr)
  p <- pr_plot_regional_bar(reg, "mpp", thresholds = pr_ref_saddle())
  expect_s3_class(p, "ggplot")
})

test_that("pr_plot_symmetry covers all parameters", {
  tr <- pr_example_trial("saddle_horse")
  for (par in c("peak_pressure", "mean_pressure", "force", "contact_area")) {
    expect_s3_class(pr_plot_symmetry(tr, par), "ggplot")
  }
})

test_that("pr_plot_comparison difference errors on layout mismatch", {
  a <- pr_example_trial("insole")
  b <- pr_example_trial("saddle_horse")
  expect_error(pr_plot_comparison(a, b, type = "difference"))
})

test_that("pr_plot_foot_report builds for an insole trial", {
  expect_true(inherits(pr_plot_foot_report(pr_example_trial("insole")),
                       c("patchwork", "ggplot")))
})

test_that("pr_plot_foot_report auto-segments a platform trial", {
  expect_true(inherits(pr_plot_foot_report(pr_example_trial("platform")),
                       c("patchwork", "ggplot")))
})

test_that("pr_plot_3d returns a plotly object", {
  p <- pr_plot_3d(pr_example_trial("saddle_horse"))
  expect_s3_class(p, "plotly")
})

test_that("pr_plot_3d accepts a frame and alternate palette", {
  p <- pr_plot_3d(pr_example_trial("custom"), frame = 1, palette = "jet")
  expect_s3_class(p, "plotly")
})
