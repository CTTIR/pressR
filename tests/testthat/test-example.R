# Coverage for R/example.R: every synthetic trial type, parameter overrides,
# the file writer for each type, and a structural snapshot lock.

test_that("pr_example_trial builds every documented type", {
  for (ty in c("insole", "platform", "saddle_horse", "saddle_bicycle",
               "wheelchair", "custom")) {
    tr <- pr_example_trial(ty)
    expect_s3_class(tr, "pr_trial")
    expect_true(tr$n_frames > 0L)
    expect_true(tr$n_sensors > 0L)
  }
})

test_that("pr_example_trial respects duration and sampling overrides", {
  tr <- pr_example_trial("custom", duration_s = 1, sampling_hz = 20)
  expect_equal(tr$n_frames, 20L)
})

test_that("pr_example_trial is reproducible for a fixed seed", {
  a <- pr_example_trial("insole", seed = 7)
  b <- pr_example_trial("insole", seed = 7)
  expect_equal(a$pressure, b$pressure)
})

test_that("pr_example_trial seed changes the data", {
  a <- pr_example_trial("insole", seed = 1)
  b <- pr_example_trial("insole", seed = 2)
  expect_false(isTRUE(all.equal(a$pressure, b$pressure)))
})

test_that("pr_example_files writes a single-type ASCII file", {
  for (ty in c("insole", "saddle", "platform")) {
    path <- pr_example_files(ty)
    expect_true(file.exists(path))
    expect_match(path, "\\.asc$")
  }
})

test_that("pr_example_files('all') returns a directory of samples", {
  dir <- pr_example_files("all")
  expect_true(dir.exists(dir))
  files <- list.files(dir, pattern = "\\.asc$")
  expect_true(length(files) >= 3L)
})

test_that("written sample file round-trips through the ASCII parser", {
  path <- pr_example_files("insole")
  tr <- pr_read_ascii(path, verbose = FALSE)
  expect_equal(tr$n_sensors, 99L)
})

test_that("example insole summary is structurally stable", {
  # Lock the set of summary columns and their sign profile as a regression.
  s <- pr_summary(pr_example_trial("insole", seed = 42))
  expect_snapshot_value(names(s), style = "json2")
  expect_true(s$mpp > 0 && s$max_force > 0)
})
