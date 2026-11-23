test_that("pr_summary returns a one-row tibble with expected columns", {
  trial <- pr_example_trial("insole")
  s <- pr_summary(trial)
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 1L)
  expect_true(all(c("mpp", "mvp", "max_force", "mean_force",
                    "max_contact_area", "mean_contact_area",
                    "contact_time", "pti_max", "pti_mean", "impulse",
                    "cop_path_length", "cop_velocity_mean",
                    "cop_range_ap", "cop_range_ml") %in% names(s)))
  expect_true(s$mpp > 0)
})

test_that("pr_calc_symmetry_index returns numeric", {
  si <- pr_calc_symmetry_index(pr_example_trial("saddle_horse"))
  expect_type(si, "double")
  expect_true(is.finite(si))
})

test_that("pr_calc_regional returns one row per region", {
  trial <- pr_example_trial("saddle_horse")
  r <- pr_calc_regional(trial)
  expect_s3_class(r, "tbl_df")
  expect_equal(nrow(r), 6L)
  expect_true("mpp" %in% names(r))
})

test_that("pr_calc_symmetry_index covers every parameter", {
  layout <- pr_layout_mat("16")
  sym <- pr_mask_symmetry(layout)
  pressure <- matrix(0, 4, layout$n_sensors)
  pressure[, sym$left$sensor_cols[1:3]] <- 30
  pressure[, sym$right$sensor_cols[1]] <- 10
  tr <- pr_trial(pressure, seq(0, 0.3, by = 0.1), layout)
  si <- function(l, r) (l - r) / (0.5 * (l + r)) * 100
  expect_equal(pr_calc_symmetry_index(tr, "peak_pressure"), si(30, 10))
  expect_equal(pr_calc_symmetry_index(tr, "mean_pressure"), si(30, 10))
  area <- layout$sensor_area_cm2
  expect_equal(pr_calc_symmetry_index(tr, "contact_area"), si(3 * area, area))
  expect_equal(pr_calc_symmetry_index(tr, "force"), si(90, 10))
})

test_that("pr_calc_symmetry_index treats a side without sensors as zero", {
  co <- data.frame(sensor_id = 1:2, row = 1L, col = 3:4)
  co$x_mm <- co$col * 10
  co$y_mm <- 0
  active <- matrix(c(FALSE, FALSE, TRUE, TRUE), 1, 4)
  right_only <- pr_layout(1, 4, active, co, name = "right_only")
  tr <- pr_trial(matrix(5, 2, 2), c(0, 0.1), right_only)
  expect_equal(pr_calc_symmetry_index(tr, "peak_pressure"), -200)
})
