test_that("automatic Pliance dispatch preserves measured data and timing", {
  path <- test_path("fixtures", "ID052_K_K_KG00_MS.asc")
  expected <- pr_read_pliance(path)
  actual <- pr_read_auto(path, verbose = FALSE)
  expect_equal(actual$pressure, expected$pressure)
  expect_identical(actual$time, expected$time)
  tmp <- tempfile()
  on.exit(unlink(tmp))
  file.copy(path, tmp)
  expect_equal(pr_read_auto(tmp, verbose = FALSE)$pressure, expected$pressure)
})

test_that("unknown scale remains visible and explicitly unavailable", {
  tr <- pr_read_pliance(test_path("fixtures", "ID052_K_K_KG00_MS.asc"))
  tiles <- ggplot2::ggplot_build(pr_plot_heatmap(tr))$data[[1L]]
  expect_true(all(is.finite(tiles$xmin) & is.finite(tiles$xmax)))
  expect_true(all(is.na(pr_calc_force(tr))))
  expect_true(is.na(pr_summary(tr)$max_force))
  expect_true(is.na(pr_calc_symmetry_index(tr, "force")))
  expect_identical(pr_calc_cop(tr)$coordinate_unit, "grid_index")
  expect_match(pr_plot_heatmap(tr)$labels$x, "grid")
})

test_that("force inputs remain newtons throughout calculations", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  write.csv(data.frame(time = 0:2, left = 100, right = 200), path, row.names = FALSE)
  tr <- pr_read_forcesensor(path, verbose = FALSE)
  expect_equal(pr_calc_force(tr), rep(300, 3))
  expect_equal(pr_calc_impulse(tr), 600)
  expect_equal(pr_summary(tr)$max_force, 300)
  expect_true(all(is.na(pr_calc_contact_area(tr))))
})

test_that("invalid numerical trials fail at construction", {
  lay <- pr_layout_mat("16")
  p <- matrix(10, 3, lay$n_sensors)
  expect_error(pr_trial(p, c(2, 1, 0), lay), "increasing")
  expect_error(pr_trial(p, c(0, 0, 1), lay), "increasing")
  expect_error(pr_trial(p, c(0, NA, 1), lay), "finite")
  p[1, 1] <- Inf
  expect_error(pr_trial(p, 0:2, lay), "finite")
})

test_that("CSV pressure export automatically restores time and sensor order", {
  tr <- pr_example_trial("insole")
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  pr_export_csv(tr, path, what = "pressure")
  out <- pr_read_auto(path, layout = tr$layout, verbose = FALSE)
  expect_equal(unname(out$pressure), unname(tr$pressure), tolerance = 1e-12)
  expect_equal(out$time, tr$time, tolerance = 1e-12)
  expect_equal(out$sampling_hz, tr$sampling_hz, tolerance = 1e-6)
})
