# Tests for R/batch.R: pr_batch_summary and pr_merge_trials.

test_that("pr_batch_summary works on a plain list of trials", {
  trials <- list(pr_example_trial("insole", seed = 1),
                 pr_example_trial("insole", seed = 2))
  s <- pr_batch_summary(trials)
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 2L)
  expect_true(all(c("subject_id", "trial_id", "condition", "system",
                    "n_frames", "duration", "mpp") %in% names(s)))
})

test_that("pr_batch_summary rejects non-trial input", {
  expect_error(pr_batch_summary(list(1, 2)))
  expect_error(pr_batch_summary("nope"))
})

test_that("pr_merge_trials accepts trials and lists of trials", {
  ds <- pr_merge_trials(
    pr_example_trial("insole", seed = 1),
    list(pr_example_trial("insole", seed = 2),
         pr_example_trial("insole", seed = 3))
  )
  expect_s3_class(ds, "pr_dataset")
  expect_equal(length(ds), 3L)
})

test_that("pr_merge_trials honors group_var", {
  ds <- pr_merge_trials(pr_example_trial("custom"), group_var = "system")
  expect_equal(ds$group_var, "system")
})

test_that("pr_merge_trials rejects non-trial arguments", {
  expect_error(pr_merge_trials(1, 2))
})
