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
test_that("verified observations cite their DOI and page", {
  saddle <- pr_ref_saddle()
  expect_true(all(grepl("doi:10.21836/PEM20050301", saddle$source, fixed = TRUE)))
  expect_true(all(grepl("p.187", saddle$source, fixed = TRUE)))
  # The abstract states N/cm2; stored kPa values are ten times larger.
  expect_equal(saddle$threshold / 10, c(3.45, 3.03, 3.10, 1.32, 1.14, 1.00))
  foot <- pr_ref_diabetic_foot()
  verified <- foot$source[foot$status == "verified_source"]
  expect_match(verified, "doi:10.1016/S1067-2516(98)80066-5", fixed = TRUE)
  expect_match(verified, "p.303", fixed = TRUE)
  expect_match(pr_ref_saddle("werner2002")$source[1], "doi:10.21836/PEM20020201", fixed = TRUE)
  expect_match(pr_ref_saddle("monkemoller2005")$source_url[1], "10.21836/PEM20050201", fixed = TRUE)
})
