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
    time = seq(0, by = 0.02, length.out = 50), layout = layout
  )
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
  tr$metadata$reference_context <- list(species = "equine", gait = "trot", region_scheme = "nyikos_six_masks")
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
  expect_true(inherits(
    pr_plot_foot_report(pr_example_trial("insole")),
    c("patchwork", "ggplot")
  ))
})

test_that("pr_plot_foot_report auto-segments a platform trial", {
  expect_true(inherits(
    pr_plot_foot_report(pr_example_trial("platform")),
    c("patchwork", "ggplot")
  ))
})

test_that("pr_plot_3d returns a plotly object", {
  p <- pr_plot_3d(pr_example_trial("saddle_horse"))
  expect_s3_class(p, "plotly")
})

test_that("pr_plot_3d accepts a frame and alternate palette", {
  p <- pr_plot_3d(pr_example_trial("custom"), frame = 1, palette = "jet")
  expect_s3_class(p, "plotly")
})

test_that("region overlays draw only region boundaries", {
  layout <- pr_layout_mat("16")
  block <- matrix(FALSE, 16, 16)
  block[1:2, 1:2] <- TRUE
  cols <- list(block = .mask_to_cols(block, layout))
  segs <- .region_outline_df(layout, cols)
  # A 2 x 2 block has a perimeter of eight cell edges and no interior edges.
  expect_equal(nrow(segs), 8L)
  pitch <- 25.4
  co <- layout$coords_mm[cols$block, ]
  half <- c(-1, 1) * pitch / 2
  expect_equal(range(c(segs$x, segs$xend)), range(co$x_mm) + half)
  expect_equal(range(c(segs$y, segs$yend)), range(co$y_mm) + half)
  # The overlay is one segment layer, not one outlined tile per sensor.
  tr <- pr_example_trial("platform")
  masks <- pr_mask_symmetry(tr$layout)
  p <- pr_plot_heatmap_masked(tr, masks = masks)
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(geoms == "GeomSegment"), 1L)
  expect_error(pr_plot_heatmap_masked(tr, masks = unname(masks)), "named list")
})

test_that("composite reports keep their panel order", {
  foot <- pr_plot_foot_report(pr_example_trial("insole"))
  expect_match(foot[[1]]$labels$title, "Maximum Pressure Picture")
  expect_match(foot[[2]]$labels$title, "Regional")
  expect_match(foot[[3]]$labels$title, "force", ignore.case = TRUE)
  expect_match(foot[[4]]$labels$title, "Centre of pressure")
})

test_that("region outlines handle one-row, empty and transposed grids", {
  co <- data.frame(sensor_id = 1:4, row = 1L, col = 1:4)
  co$x_mm <- (co$col - 1) * 10
  co$y_mm <- 0
  strip <- pr_layout(1, 4, matrix(TRUE, 1, 4), co, name = "strip",
    sensor_area_cm2 = 1
  )
  segs <- .region_outline_df(strip, list(pair = 1:2, none = integer()))
  # Two cells in a row: six edges; the single row falls back to the tile.
  expect_equal(nrow(segs), 6L)
  expect_equal(unique(segs$region), "pair")
  expect_equal(range(c(segs$y, segs$yend)), c(-5, 5))
  expect_equal(range(c(segs$x, segs$xend)), c(-5, 15))
  empty <- .region_outline_df(strip, list(none = integer()))
  expect_equal(nrow(empty), 0L)
  # Columns running along y are outlined on the y axis.
  flipped <- co
  flipped$x_mm <- 0
  flipped$y_mm <- (co$col - 1) * 10
  tall <- pr_layout(1, 4, matrix(TRUE, 1, 4), flipped, name = "tall",
    sensor_area_cm2 = 1
  )
  segs <- .region_outline_df(tall, list(pair = 1:2))
  expect_equal(range(c(segs$y, segs$yend)), c(-5, 15))
  # A mask without sensors adds no outline layer.
  tr <- pr_example_trial("saddle_horse")
  grid <- c(tr$layout$grid_rows, tr$layout$grid_cols)
  nothing <- list(none = matrix(FALSE, grid[1], grid[2]))
  p <- pr_plot_heatmap_masked(tr, masks = nothing)
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomSegment" %in% geoms)
})

test_that("force plots and foot reports state what is unavailable", {
  novel <- pr_layout_saddle_novel()
  pressure <- matrix(1, 5, novel$n_sensors)
  tr <- pr_trial(pressure, seq(0, by = 0.02, length.out = 5), novel)
  p <- pr_plot_force_time(tr)
  expect_match(p$labels$title, "Total force")
  layout <- pr_layout_platform("cl")
  flat <- pr_trial(matrix(0, 5, layout$n_sensors),
    seq(0, by = 0.02, length.out = 5), layout
  )
  expect_warning(report <- pr_plot_foot_report(flat))
  expect_match(report[[2]]$labels$title, "No regions available")
})
