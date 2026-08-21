# Tests for R/dataset-cohort.R: design tables, cohort filtering, count
# assertions and dataset validation.

grid16 <- function() pr_layout_mat("16")

# A 1x1 layout, so that cohort-shaped fixtures with realistic frame counts
# stay cheap.
tiny_layout <- function() {
  pr_layout(
    1, 1, matrix(TRUE, 1, 1),
    data.frame(sensor_id = 1L, row = 1L, col = 1L, x_mm = 0, y_mm = 0),
    name = "tiny"
  )
}

mk_trial <- function(meta = list(), n = 4L, layout = grid16(),
                     value = 1, time = NULL) {
  if (is.null(time)) time <- seq(0, (n - 1) / 50, by = 1 / 50)
  pr_trial(
    matrix(value, n, layout$n_sensors),
    time = time, layout = layout, metadata = meta
  )
}

study_ds <- function() {
  pr_dataset(list(
    mk_trial(list(ID = "ID001", Saddle = "K", Pad = "F", Weight = "KG00",
                  Mode = "MH"), n = 4L),
    mk_trial(list(ID = "ID001", Saddle = "K", Pad = "F", Weight = "KG00",
                  Mode = "MS"), n = 6L),
    mk_trial(list(ID = "ID002", Saddle = "S", Pad = "K", Weight = "KG40",
                  Mode = "MS"), n = 11L)
  ), name = "study")
}

# ---- pr_design_table ------------------------------------------------------

test_that("pr_design_table reproduces the study design shape and values", {
  d <- pr_design_table(study_ds(),
                       fields = c("ID", "Saddle", "Pad", "Weight", "Mode"))

  expect_s3_class(d, "tbl_df")
  expect_equal(dim(d), c(3L, 7L))
  expect_equal(
    names(d),
    c("ID", "Saddle", "Pad", "Weight", "Mode", "n_frames", "duration_s")
  )
  expect_equal(d$ID, c("ID001", "ID001", "ID002"))
  expect_equal(d$Mode, c("MH", "MS", "MS"))
  expect_equal(d$n_frames, c(4L, 6L, 11L))
  expect_type(d$n_frames, "integer")
  # duration is diff(range(time)) = (n - 1) / 50, as in the study
  expect_equal(d$duration_s, c(0.06, 0.10, 0.20))
  expect_equal(as.vector(table(d$Mode)), c(1L, 2L))
})

test_that("pr_design_table keeps the field order it was given", {
  d <- pr_design_table(study_ds(), fields = c("Mode", "ID"))
  expect_equal(names(d), c("Mode", "ID", "n_frames", "duration_s"))
})

test_that("auto field detection drops the empty pr_trial defaults", {
  d <- pr_design_table(study_ds())
  # subject_id / trial_id / date / condition / notes are all NA here and
  # must not appear; `system` is filled from the layout model.
  expect_false(any(c("subject_id", "trial_id", "date", "condition", "notes")
                   %in% names(d)))
  expect_equal(names(d)[1:5],
               c("ID", "Saddle", "Pad", "Weight", "Mode"))
  expect_equal(tail(names(d), 2), c("n_frames", "duration_s"))
})

test_that("auto detection keeps a default field once it is populated", {
  ds <- pr_dataset(list(
    mk_trial(list(ID = "ID001", condition = "walk")),
    mk_trial(list(ID = "ID002", condition = "trot"))
  ))
  d <- pr_design_table(ds)
  expect_true("condition" %in% names(d))
  expect_equal(d$condition, c("walk", "trot"))
})

test_that("pr_design_table preserves Date fields and mixed presence", {
  ds <- pr_dataset(list(
    mk_trial(list(ID = "ID001", date = as.Date("2024-03-01"))),
    mk_trial(list(ID = "ID002"))
  ))
  d <- pr_design_table(ds, fields = c("ID", "date"))
  expect_s3_class(d$date, "Date")
  expect_equal(d$date, as.Date(c("2024-03-01", NA)))
})

test_that("pr_design_table handles an empty dataset", {
  d <- pr_design_table(pr_dataset(list()))
  expect_equal(nrow(d), 0L)
  expect_equal(names(d), c("n_frames", "duration_s"))
})

test_that("pr_design_table rejects bad input", {
  expect_error(pr_design_table(list(1, 2)), "pr_dataset")
  expect_error(pr_design_table(study_ds(), fields = 1:3), "character vector")
  expect_error(pr_design_table(study_ds(), fields = "Rider"), "Rider")
  expect_error(pr_design_table(study_ds(), fields = "n_frames"),
               "n_frames")
  ds <- pr_dataset(list(mk_trial(list(ID = "ID001", notes = c("a", "b")))))
  expect_error(pr_design_table(ds, fields = "notes"), "single value")
  # the same non-scalar field is silently skipped by auto detection
  expect_false("notes" %in% names(pr_design_table(ds)))
})

# ---- pr_dataset_filter ----------------------------------------------------

test_that("pr_dataset_filter keeps the matching trials", {
  out <- pr_dataset_filter(study_ds(), ~ .x$Mode == "MS", label = "walk")
  expect_s3_class(out, "pr_dataset")
  expect_equal(length(out), 2L)
  expect_equal(
    vapply(out$trials, function(t) t$metadata$ID, character(1)),
    c("ID001", "ID002")
  )
  expect_equal(out$filter_label, "walk")
  expect_equal(out$filter_history, "walk")
  expect_equal(out$n_trials_before, 3L)
  expect_equal(out$name, "study")
})

test_that("pr_dataset_filter accepts a plain function and chains history", {
  ms <- pr_dataset_filter(study_ds(), function(m) m$Mode == "MS",
                          label = "walk")
  id1 <- pr_dataset_filter(ms, ~ .x$ID == "ID001", label = "ID001 only")
  expect_equal(length(id1), 1L)
  expect_equal(id1$filter_history, c("walk", "ID001 only"))
  expect_equal(id1$n_trials_before, 2L)
})

test_that("pr_dataset_filter asserts unit and subject counts", {
  expect_equal(
    length(pr_dataset_filter(study_ds(), ~ .x$Mode == "MS", label = "walk",
                             n_units = 2, n_subjects = 2)),
    2L
  )
  expect_error(
    pr_dataset_filter(study_ds(), ~ .x$Mode == "MS", label = "walk",
                      n_units = 3),
    class = "pr_cohort_assert_failed"
  )
  expect_error(
    pr_dataset_filter(study_ds(), ~ .x$Mode == "MS", label = "walk",
                      n_subjects = 19),
    class = "pr_cohort_assert_failed"
  )
})

test_that("pr_dataset_filter reports which expectation failed", {
  err <- tryCatch(
    pr_dataset_filter(study_ds(), ~ .x$Mode == "MS", label = "walk",
                      n_units = 170),
    pr_cohort_assert_failed = function(e) e
  )
  expect_equal(err$expected, 170L)
  expect_equal(err$actual, 2L)
  expect_equal(err$label, "walk")
  expect_match(conditionMessage(err), "170")
  expect_match(conditionMessage(err), "168 fewer")
})

test_that("pr_dataset_filter can produce an empty cohort", {
  out <- pr_dataset_filter(study_ds(), ~ .x$Mode == "MX", n_units = 0)
  expect_equal(length(out), 0L)
  expect_equal(out$filter_label, "filter")
})

test_that("pr_dataset_filter treats NA as FALSE with a warning", {
  ds <- pr_dataset(list(
    mk_trial(list(ID = "ID001", Mode = "MS")),
    mk_trial(list(ID = "ID002", Mode = NA_character_))
  ))
  expect_warning(out <- pr_dataset_filter(ds, ~ .x$Mode == "MS"), "NA")
  expect_equal(length(out), 1L)
})

test_that("pr_dataset_filter rejects a predicate that is not a flag", {
  # a missing field compares to logical(0)
  expect_error(
    pr_dataset_filter(study_ds(), ~ .x$Rider == "A"),
    "single .*logical"
  )
  expect_error(
    pr_dataset_filter(study_ds(), ~ .x$ID),
    "single .*logical"
  )
  expect_error(pr_dataset_filter(study_ds(), "not a function"))
  expect_error(pr_dataset_filter(study_ds(), ~ TRUE, n_units = -1),
               "non-negative")
  expect_error(pr_dataset_filter(study_ds(), ~ TRUE, n_units = 2.5),
               "whole number")
  expect_error(pr_dataset_filter(study_ds(), ~ TRUE, label = c("a", "b")),
               "single string")
})

# ---- pr_assert_cohort -----------------------------------------------------

test_that("pr_assert_cohort passes on a correct data frame expectation", {
  design <- data.frame(
    ID = c("ID001", "ID001", "ID002"),
    Mode = c("MS", "MH", "MS")
  )
  expect_invisible(
    pr_assert_cohort(design, n_units = 3, n_subjects = 2, subject_col = "ID")
  )
  expect_identical(
    pr_assert_cohort(design, n_units = 3),
    design
  )
  # subject column auto-detected from ID
  expect_invisible(pr_assert_cohort(design, n_subjects = 2))
  # units can be distinct values of a column instead of rows
  expect_invisible(pr_assert_cohort(design, n_units = 2, unit_col = "ID"))
})

test_that("pr_assert_cohort fails loudly on a wrong expectation", {
  design <- data.frame(ID = c("ID001", "ID001", "ID002"))
  err <- tryCatch(
    pr_assert_cohort(design, n_units = 431, label = "all recordings"),
    pr_cohort_assert_failed = function(e) e
  )
  expect_s3_class(err, "pr_cohort_assert_failed")
  expect_equal(err$actual, 3L)
  expect_equal(err$expected, 431L)
  expect_match(conditionMessage(err), "all recordings")
  expect_match(conditionMessage(err), "expected 431")
  expect_match(conditionMessage(err), "found 3")
  expect_match(conditionMessage(err), "428 fewer")

  err2 <- tryCatch(
    pr_assert_cohort(design, n_subjects = 1, subject_col = "ID"),
    pr_cohort_assert_failed = function(e) e
  )
  expect_match(conditionMessage(err2), "1 more")
  expect_match(conditionMessage(err2), "ID001")
})

test_that("pr_assert_cohort counts trials and metadata on a pr_dataset", {
  ds <- study_ds()
  expect_invisible(
    pr_assert_cohort(ds, n_units = 3, n_subjects = 2, subject_col = "ID")
  )
  expect_error(pr_assert_cohort(ds, n_units = 4),
               class = "pr_cohort_assert_failed")
  expect_invisible(pr_assert_cohort(ds, n_units = 2, unit_col = "Mode"))
  # a bare list of trials is accepted too
  expect_invisible(pr_assert_cohort(ds$trials, n_units = 3))
  # the label defaults to the dataset name, then to the filter label
  err <- tryCatch(pr_assert_cohort(ds, n_units = 9),
                  pr_cohort_assert_failed = function(e) e)
  expect_equal(err$label, "study")
  filtered <- pr_dataset_filter(ds, ~ .x$Mode == "MS", label = "walk")
  err2 <- tryCatch(pr_assert_cohort(filtered, n_units = 9),
                   pr_cohort_assert_failed = function(e) e)
  expect_equal(err2$label, "walk")
})

test_that("pr_assert_cohort ignores missing values when counting subjects", {
  design <- data.frame(ID = c("ID001", NA, "ID002", NA))
  expect_invisible(pr_assert_cohort(design, n_subjects = 2,
                                    subject_col = "ID"))
  expect_invisible(pr_assert_cohort(design, n_units = 4))
})

test_that("pr_assert_cohort rejects bad input", {
  design <- data.frame(ID = "ID001")
  expect_error(pr_assert_cohort(1:5, n_units = 5), "pr_dataset")
  expect_error(pr_assert_cohort(design, n_units = 1, unit_col = "Rider"),
               "Rider")
  expect_error(pr_assert_cohort(design, n_subjects = 1,
                                subject_col = "Rider"),
               "Rider")
  expect_error(pr_assert_cohort(data.frame(x = 1), n_subjects = 1),
               "subject_col")
  expect_error(pr_assert_cohort(design, n_units = "3"), "whole number")
  expect_error(pr_assert_cohort(design, n_units = 1, label = 42),
               "single string")
  # no expectation supplied: nothing is checked, x comes back unchanged
  expect_identical(pr_assert_cohort(design), design)
})

# ---- pr_validate_dataset --------------------------------------------------

test_that("pr_validate_dataset returns no problems for a clean cohort", {
  p <- pr_validate_dataset(study_ds())
  expect_s3_class(p, "tbl_df")
  expect_equal(nrow(p), 0L)
  expect_equal(
    names(p),
    c("trial", "trial_label", "check", "expected", "actual", "problem")
  )
})

test_that("pr_validate_dataset flags the odd trial, not the majority", {
  odd <- pr_example_trial("insole")
  ds <- pr_dataset(list(mk_trial(), mk_trial(), odd))
  expect_warning(p <- pr_validate_dataset(ds, strict = FALSE), "cohort")
  expect_equal(unique(p$trial), 3L)
  expect_setequal(p$check, c("n_sensors", "layout_name"))
  expect_equal(p$expected[p$check == "n_sensors"],
               as.character(grid16()$n_sensors))
  expect_equal(p$actual[p$check == "n_sensors"],
               as.character(odd$n_sensors))
  expect_equal(p$actual[p$check == "layout_name"], odd$layout$name)
})

test_that("pr_validate_dataset aborts under strict and carries the table", {
  ds <- pr_dataset(list(mk_trial(), mk_trial(), pr_example_trial("insole")))
  err <- tryCatch(pr_validate_dataset(ds),
                  pr_dataset_invalid = function(e) e)
  expect_s3_class(err, "pr_dataset_invalid")
  expect_s3_class(err$problems, "tbl_df")
  expect_equal(nrow(err$problems), 2L)
  expect_match(conditionMessage(err), "Trial 3")
})

test_that("pr_validate_dataset detects missing, infinite and negative data", {
  layout <- grid16()
  bad <- matrix(1, 3, layout$n_sensors)
  bad[2, 5] <- NA_real_
  na_trial <- pr_trial(bad, time = c(0, 0.02, 0.04), layout = layout)
  neg_trial <- mk_trial(n = 3L, value = -2)
  inf <- matrix(1, 3, layout$n_sensors)
  inf[1, 1] <- Inf
  inf_trial <- pr_trial(inf, time = c(0, 0.02, 0.04), layout = layout)

  p <- pr_validate_dataset(
    pr_dataset(list(mk_trial(n = 3L), na_trial, neg_trial, inf_trial)),
    strict = FALSE
  ) |> suppressWarnings()

  expect_equal(p$trial, c(2L, 3L, 4L))
  expect_equal(p$check, c("missing", "negative", "finite"))
  expect_equal(p$actual[p$check == "missing"], "1")
  expect_equal(p$actual[p$check == "negative"], "-2")
})

test_that("pr_validate_dataset flags non-monotonic time", {
  layout <- grid16()
  tr <- pr_trial(matrix(1, 3, layout$n_sensors), time = c(0, 0.04, 0.02),
                 layout = layout)
  p <- suppressWarnings(
    pr_validate_dataset(pr_dataset(list(mk_trial(n = 3L), tr)),
                        strict = FALSE)
  )
  expect_equal(p$check, "time_order")
  expect_equal(p$trial, 2L)
})

test_that("pr_validate_dataset labels trials by their metadata", {
  # trial_id, when present, names the offending trial
  ds <- pr_dataset(list(
    mk_trial(list(trial_id = "ID001_K_F_KG00_MH")),
    mk_trial(list(trial_id = "ID002_K_F_KG00_MH")),
    pr_example_trial("insole")
  ))
  p <- suppressWarnings(pr_validate_dataset(ds, strict = FALSE))
  expect_equal(unique(p$trial_label), "insole_gait")

  # with no identifying metadata the index is used instead
  ds2 <- pr_dataset(list(mk_trial(), mk_trial(),
                         mk_trial(layout = pr_layout_mat("32"))))
  p2 <- suppressWarnings(pr_validate_dataset(ds2, strict = FALSE))
  expect_equal(unique(p2$trial_label), "trial 3")
  expect_setequal(p2$check, c("n_sensors", "layout_name"))
})

test_that("pr_validate_dataset rejects bad input", {
  expect_error(pr_validate_dataset(pr_dataset(list())), "no trials")
  expect_error(pr_validate_dataset(list("a")), "pr_dataset")
  expect_error(pr_validate_dataset(study_ds(), strict = NA), "strict")
})

# ---- ground truth ---------------------------------------------------------

study_design_path <- file.path(
  "/run/media/rh/LaCie 8TB Ext4/Desktop/2025_PR_saddle_analysis",
  "workflow/data/tidy_data/design.rds"
)

test_that("pr_assert_cohort agrees with the study's real design table", {
  skip_if_not(file.exists(study_design_path), "study design.rds unavailable")
  design <- as.data.frame(readRDS(study_design_path))

  expect_invisible(
    pr_assert_cohort(design, n_units = 431, n_subjects = 19,
                     subject_col = "ID", label = "all recordings")
  )
  expect_error(pr_assert_cohort(design, n_units = 430),
               class = "pr_cohort_assert_failed")
  expect_error(pr_assert_cohort(design, n_subjects = 18, subject_col = "ID"),
               class = "pr_cohort_assert_failed")

  ms <- design[design$Mode == "MS", ]
  expect_invisible(
    pr_assert_cohort(ms, n_units = 170, n_subjects = 19, subject_col = "ID")
  )
  mg <- design[design$Mode == "MG", ]
  expect_invisible(
    pr_assert_cohort(mg, n_units = 92, n_subjects = 8, subject_col = "ID")
  )
})

test_that("pr_design_table rebuilds the study's design.rds exactly", {
  skip_if_not(file.exists(study_design_path), "study design.rds unavailable")
  design <- as.data.frame(readRDS(study_design_path))
  layout <- tiny_layout()

  trials <- lapply(seq_len(nrow(design)), function(i) {
    n <- design$n_frames[i]
    pr_trial(
      matrix(0, n, 1L),
      time = seq(0, design$duration_s[i], length.out = n),
      layout = layout,
      metadata = as.list(design[i, c("ID", "Saddle", "Pad", "Weight",
                                     "Mode")])
    )
  })
  ds <- pr_dataset(trials, name = "saddle cohort")

  out <- pr_design_table(ds, fields = c("ID", "Saddle", "Pad", "Weight",
                                        "Mode"))
  expect_equal(dim(out), c(431L, 7L))
  expect_equal(as.data.frame(out), design, tolerance = 1e-8)
  expect_equal(sum(out$n_frames), 5501590)
  expect_equal(as.vector(table(out$Mode)), c(92L, 169L, 170L))
  expect_invisible(
    pr_assert_cohort(out, n_units = 431, n_subjects = 19, subject_col = "ID")
  )

  walk <- pr_dataset_filter(ds, ~ .x$Mode == "MS", label = "MS (walk)",
                            n_units = 170, n_subjects = 19)
  expect_equal(length(walk), 170L)
  expect_error(
    pr_dataset_filter(ds, ~ .x$Mode == "MS", n_units = 169),
    class = "pr_cohort_assert_failed"
  )
  expect_equal(nrow(pr_validate_dataset(ds)), 0L)
})
