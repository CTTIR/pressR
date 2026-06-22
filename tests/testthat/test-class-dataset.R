# Tests for R/class-dataset.R: dataset constructor, S3 methods, subsetting.

make_ds <- function() {
  pr_dataset(list(
    pr_example_trial("insole", seed = 1),
    pr_example_trial("insole", seed = 2),
    pr_example_trial("insole", seed = 3)
  ), name = "demo")
}

test_that("pr_dataset rejects non-trial elements", {
  expect_error(pr_dataset(list(1, 2, 3)))
  expect_error(pr_dataset("not a list"))
})

test_that("pr_dataset stores trials and count", {
  ds <- make_ds()
  expect_s3_class(ds, "pr_dataset")
  expect_equal(ds$n_trials, 3L)
  expect_equal(ds$name, "demo")
})

test_that("length.pr_dataset returns trial count", {
  expect_equal(length(make_ds()), 3L)
})

test_that("[.pr_dataset subsets and keeps class", {
  ds <- make_ds()
  sub <- ds[1:2]
  expect_s3_class(sub, "pr_dataset")
  expect_equal(length(sub), 2L)
})

test_that("c.pr_dataset combines datasets and bare trials", {
  ds <- make_ds()
  combined <- c(ds, pr_example_trial("custom"))
  expect_s3_class(combined, "pr_dataset")
  expect_equal(length(combined), 4L)
  expect_equal(combined$name, "combined")
})

test_that("summary.pr_dataset delegates to batch summary", {
  ds <- make_ds()
  s <- summary(ds)
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 3L)
})

test_that("print.pr_dataset is invisible", {
  ds <- make_ds()
  expect_invisible(print(ds))
})

test_that("print.pr_dataset handles NA metadata gracefully", {
  layout <- pr_layout_mat("16")
  bare <- pr_trial(matrix(1, 2, layout$n_sensors), time = c(0, 1),
                   layout = layout)
  ds <- pr_dataset(list(bare))
  expect_invisible(print(ds))
})
