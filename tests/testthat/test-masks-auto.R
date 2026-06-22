# Tests for R/masks.R branches not covered by test-mask.R:
# foot auto-segmentation (3 and 7 regions), bad n_regions, and the
# horizontal symmetry axis.

test_that("pr_mask_foot_auto rejects invalid n_regions", {
  trial <- pr_example_trial("platform")
  expect_error(pr_mask_foot_auto(trial, n_regions = 5))
})

test_that("pr_mask_foot_auto returns 3 regions when requested", {
  trial <- pr_example_trial("platform")
  m <- pr_mask_foot_auto(trial, n_regions = 3L, threshold = 1)
  expect_named(m, c("heel", "midfoot", "forefoot"))
  expect_true(all(vapply(m, inherits, logical(1), "pr_mask")))
})

test_that("pr_mask_foot_auto returns 7 anatomical regions", {
  trial <- pr_example_trial("platform")
  m <- pr_mask_foot_auto(trial, n_regions = 7L, threshold = 1)
  expect_length(m, 7L)
  expect_true(all(c("heel", "metatarsal_1", "hallux", "lesser_toes")
                  %in% names(m)))
})

test_that("pr_mask_symmetry horizontal axis names anterior/posterior", {
  sym <- pr_mask_symmetry(pr_layout_saddle("horse"), "horizontal")
  expect_named(sym, c("anterior", "posterior"))
})

test_that("pr_mask_apply returns empty list for region-free layout", {
  layout <- pr_layout_mat("16")
  trial <- pr_trial(matrix(1, 2, layout$n_sensors), time = c(0, 1),
                    layout = layout)
  expect_length(pr_mask_apply(trial), 0L)
})

test_that("pr_mask_apply errors on unnamed mask list", {
  trial <- pr_example_trial("saddle_horse")
  m <- pr_mask_saddle_6(trial$layout)
  names(m) <- NULL
  expect_error(pr_mask_apply(trial, masks = m))
})

test_that("pr_mask_default returns empty list when no regions", {
  expect_length(pr_mask_default(pr_layout_mat("16")), 0L)
})
