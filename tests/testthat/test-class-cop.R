# Tests for R/class-cop.R: pr_cop constructor metrics and print method.

test_that("pr_cop rejects mismatched lengths", {
  expect_error(pr_cop(c(1, 2), c(1, 2, 3), c(1, 2, 3)))
  expect_error(pr_cop(1:3, 1:3, 1:2))
})

test_that("pr_cop computes path length and velocity", {
  cop <- pr_cop(c(0, 3, 3), c(0, 0, 4), c(0, 1, 2))
  # segments: 3 then 4 -> path 7
  expect_equal(cop$path_length, 7)
  expect_equal(cop$velocity_mean, mean(c(3, 4)))
  expect_equal(cop$velocity_max, 4)
  expect_equal(cop$range_x, 3)
  expect_equal(cop$range_y, 4)
})

test_that("pr_cop handles a single point (no trajectory)", {
  cop <- pr_cop(1, 2, 0)
  expect_equal(cop$path_length, 0)
  expect_equal(cop$velocity_mean, 0)
  expect_equal(cop$range_x, 0)
  expect_equal(cop$sway_area, 0)
})

test_that("pr_cop drops NA frames for trajectory metrics", {
  cop <- pr_cop(c(NA, 0, 3), c(NA, 0, 4), c(0, 1, 2))
  expect_equal(cop$path_length, 5)
  expect_length(cop$x, 3)  # original retained in $x
})

test_that("pr_cop computes a positive sway area for >=3 points", {
  set.seed(1)
  cop <- pr_cop(rnorm(20), rnorm(20), seq_len(20))
  expect_true(cop$sway_area > 0)
})

test_that("pr_cop guards zero dt against Inf velocity", {
  cop <- pr_cop(c(0, 1), c(0, 1), c(0, 0))
  expect_true(is.finite(cop$velocity_mean))
  expect_equal(cop$velocity_mean, 0)
})

test_that("print.pr_cop is invisible and prints", {
  cop <- pr_cop(c(0, 1, 2), c(0, 1, 0), c(0, 1, 2))
  expect_invisible(print(cop))
})
