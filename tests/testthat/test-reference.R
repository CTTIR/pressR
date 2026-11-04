test_that("saddle observations have the correct attribution and study context", {
  x <- pr_ref_saddle()
  expect_identical(x, pr_ref_saddle("nyikos2005"))
  expect_equal(x$threshold, c(34.5, 30.3, 31, 13.2, 11.4, 10))
  expect_true(all(x$status == "verified_source"))
  expect_true(all(x$species == "equine" & x$gait == "trot"))
  expect_match(x$source[1], "Nyikos")
  for (source in c("vonpeinen2010", "monkemoller2005", "werner2002")) {
    old <- pr_ref_saddle(source)
    expect_true(all(is.na(old$threshold)))
    expect_true(all(old$status == "withdrawn"))
    expect_true(all(c("source_url", "interpretation", "region_scheme") %in% names(old)))
  }
  expect_error(pr_ref_saddle("unknown"))
})
test_that("unverified foot and seating cutoffs cannot become numeric overlays", {
  foot <- pr_ref_diabetic_foot()
  expect_equal(foot$threshold[foot$status == "verified_source"], 700)
  expect_true(all(is.na(foot$threshold[foot$status == "withdrawn"])))
  seat <- pr_ref_wheelchair()
  expect_true(all(is.na(seat$threshold)))
  expect_true(all(seat$status == "withdrawn"))
  expect_true(all(seat$unit == "mmHg"))
})
