# Tests for R/reference.R: all source arms and required columns,
# plus a snapshot regression lock on the von Peinen 2010 thresholds.

test_that("pr_ref_saddle returns each documented source", {
  v1 <- pr_ref_saddle("vonpeinen2010")
  v2 <- pr_ref_saddle("monkemoller2005")
  v3 <- pr_ref_saddle("werner2002")
  expect_equal(nrow(v1), 6L)
  expect_equal(nrow(v2), 3L)
  expect_equal(nrow(v3), 3L)
  for (v in list(v1, v2, v3)) {
    expect_true(all(c("region", "parameter", "threshold", "unit",
                      "interpretation", "source") %in% names(v)))
  }
})

test_that("pr_ref_saddle default equals vonpeinen2010", {
  expect_identical(pr_ref_saddle(), pr_ref_saddle("vonpeinen2010"))
})

test_that("pr_ref_saddle vonpeinen thresholds are stable", {
  expect_snapshot_value(pr_ref_saddle("vonpeinen2010"), style = "json2")
})

test_that("pr_ref_diabetic_foot has four rows with thresholds", {
  df <- pr_ref_diabetic_foot()
  expect_s3_class(df, "tbl_df")
  expect_equal(nrow(df), 4L)
  expect_true(all(df$threshold > 0))
})

test_that("pr_ref_wheelchair reports mmHg thresholds", {
  wc <- pr_ref_wheelchair()
  expect_equal(nrow(wc), 3L)
  expect_true(all(wc$unit == "mmHg"))
})
