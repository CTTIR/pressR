# ---------------------------------------------------------------------------
# Cohort layer.
#
# A study is not a heap of trials: it is a design (which units exist, which
# subjects they belong to) plus the claim that the design is what the analyst
# thinks it is. The functions here turn a `pr_dataset` into that design table,
# subset it by metadata, and — most importantly — assert the resulting counts
# so that a silently dropped recording fails the pipeline instead of quietly
# changing a published number.
# ---------------------------------------------------------------------------

# Internal: coerce a pr_dataset / list of trials to a plain list of trials.
#
# Every internal helper below takes `call`, so that a failure is reported
# against the exported function the user actually called rather than against
# the helper.
.cohort_trials <- function(dataset, arg = "dataset",
                           call = rlang::caller_env()) {
  trials <- if (inherits(dataset, "pr_dataset")) dataset$trials else dataset
  ok <- is.list(trials) && !is.data.frame(trials) &&
    all(vapply(trials, inherits, logical(1), "pr_trial"))
  if (!ok) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls pr_dataset} or a list of
       {.cls pr_trial} objects.",
      call = call
    )
  }
  trials
}

# Internal: a human-readable name for one trial, for use in messages.
.cohort_trial_label <- function(trial, i) {
  md <- trial$metadata
  for (nm in c("trial_id", "file_label", "subject_id")) {
    v <- md[[nm]]
    if (!is.null(v) && length(v) == 1L && !is.na(v) &&
        nzchar(as.character(v))) {
      return(as.character(v))
    }
  }
  paste0("trial ", i)
}

# Internal: combine a list of length-1 metadata values into one vector,
# keeping Date/POSIXct classes that unlist() would strip.
.cohort_combine <- function(vals) {
  # A bare NA of any type carries no class information: `pr_trial()` fills
  # absent metadata with NA_character_, which must not mask a Date column.
  cls <- unique(unlist(lapply(vals, function(v) {
    if (length(v) == 1L && is.na(v) && !inherits(v, c("Date", "POSIXct"))) {
      NULL
    } else {
      class(v)[1]
    }
  })))
  if (length(cls) == 1L && cls %in% c("Date", "POSIXct")) {
    proto <- Filter(function(v) inherits(v, cls), vals)[[1]]
    na_val <- proto
    na_val[1] <- NA
    return(do.call(c, lapply(vals, function(v) {
      if (inherits(v, cls)) v else na_val
    })))
  }
  unlist(vals, use.names = FALSE)
}

# Internal: pull one metadata field across trials as a single vector.
# `strict = FALSE` returns NULL instead of aborting on non-scalar values.
.cohort_field <- function(trials, field, strict = TRUE,
                          call = rlang::caller_env()) {
  vals <- lapply(trials, function(t) {
    v <- t$metadata[[field]]
    if (is.null(v)) return(NA)
    if (is.factor(v)) as.character(v) else v
  })
  bad <- which(!vapply(
    vals, function(v) is.atomic(v) && length(v) == 1L, logical(1)
  ))
  if (length(bad) > 0L) {
    if (!strict) return(NULL)
    cli::cli_abort(c(
      "Metadata field {.val {field}} is not a single value in every trial.",
      x = "Trial{?s} {bad} do{?es/} not hold exactly one value for it.",
      i = "A design table needs one scalar per trial; drop the field from
           {.arg fields} or reduce it before building the table."
    ), call = call)
  }
  .cohort_combine(vals)
}

# Internal: most common value, ties broken by first appearance.
.cohort_modal <- function(x) {
  keep <- x[!is.na(x)]
  if (length(keep) == 0L) return(x[1])
  u <- unique(keep)
  counts <- vapply(u, function(v) sum(keep == v), integer(1))
  u[which.max(counts)]
}

# Internal: validate an expected-count argument.
.cohort_count_arg <- function(x, arg, call = rlang::caller_env()) {
  if (is.null(x)) return(NULL)
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < 0 ||
      x != trunc(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single non-negative whole number, not
       {.val {x}}.",
      call = call
    )
  }
  as.integer(x)
}

# Internal: pull a field/column from a pr_dataset or a data frame.
.cohort_column <- function(x, col, arg, call = rlang::caller_env()) {
  if (!is.character(col) || length(col) != 1L || is.na(col)) {
    cli::cli_abort("{.arg {arg}} must be a single field name.", call = call)
  }
  if (inherits(x, "pr_dataset")) {
    trials <- x$trials
    have <- vapply(trials, function(t) col %in% names(t$metadata), logical(1))
    if (!any(have)) {
      avail <- unique(unlist(lapply(trials, function(t) names(t$metadata))))
      cli::cli_abort(c(
        "No trial carries the metadata field {.val {col}} named by
         {.arg {arg}}.",
        i = "Available metadata field{?s}: {.val {avail}}."
      ), call = call)
    }
    .cohort_field(trials, col, call = call)
  } else {
    if (!col %in% names(x)) {
      cli::cli_abort(c(
        "Column {.val {col}} named by {.arg {arg}} is not in {.arg x}.",
        i = "Available column{?s}: {.val {names(x)}}."
      ), call = call)
    }
    x[[col]]
  }
}

# Internal: the count assertion itself, with the message the whole layer
# exists for. `what` is a singular noun phrase; cli pluralizes it against
# the expected count.
.cohort_assert_count <- function(actual, expected, what, label,
                                 values = NULL,
                                 call = rlang::caller_env()) {
  actual <- as.integer(actual)
  expected <- as.integer(expected)
  if (identical(actual, expected)) return(invisible(TRUE))

  delta <- actual - expected
  direction <- if (delta > 0) "more" else "fewer"
  bullets <- c(
    "Cohort assertion failed for {.val {label}}: expected {expected}
     {what}{cli::qty(expected)}{?s}, found {actual}.",
    x = "{abs(delta)} {direction} than expected."
  )
  if (!is.null(values)) {
    shown <- cli::cli_vec(
      as.character(values),
      style = list("vec-trunc" = 8L)
    )
    bullets <- c(bullets, i = "Observed: {.val {shown}}.")
  }
  bullets <- c(
    bullets,
    i = "Either the expectation is stale or trials were dropped upstream;
         do not relax the expectation without finding out which."
  )
  cli::cli_abort(
    bullets,
    class = "pr_cohort_assert_failed",
    expected = expected, actual = actual, label = label, what = what,
    call = call
  )
}

#' Cohort Design Table
#'
#' Reduces a [pr_dataset] to one row per trial: the chosen metadata fields
#' plus `n_frames` and `duration_s`. This is the study design as a table —
#' the object you count, cross-tabulate, and assert against with
#' [pr_assert_cohort()].
#'
#' `duration_s` is the trial's `duration` field, i.e.
#' `diff(range(time))`, so a 23432-frame recording at 50 Hz gives
#' 468.62 s (not 468.64 s).
#'
#' @param dataset A [pr_dataset] object, or a list of [pr_trial] objects.
#' @param fields Character vector of metadata field names to include, in
#'   the order given. `NULL` (default) auto-detects: every metadata field
#'   that holds a single value in every trial, dropping fields that are
#'   missing (`NA`) throughout — which removes the empty `pr_trial`
#'   defaults such as `notes`. Fields named `n_frames` or `duration_s`
#'   are dropped in auto mode and rejected when named explicitly, because
#'   both columns are recomputed from the trial itself.
#'
#' @return A [tibble::tibble] with one row per trial and columns
#'   `fields`, `n_frames` (integer) and `duration_s` (numeric).
#' @export
#' @family cohort functions
#' @examples
#' layout <- pr_layout_mat("16")
#' mk <- function(id, mode, n) {
#'   pr_trial(
#'     matrix(1, n, layout$n_sensors),
#'     time = seq(0, (n - 1) / 50, by = 1 / 50),
#'     layout = layout,
#'     metadata = list(ID = id, Mode = mode)
#'   )
#' }
#' ds <- pr_dataset(list(mk("ID001", "MS", 4), mk("ID002", "MH", 6)))
#' pr_design_table(ds, fields = c("ID", "Mode"))
pr_design_table <- function(dataset, fields = NULL) {
  trials <- .cohort_trials(dataset)
  reserved <- c("n_frames", "duration_s")

  if (length(trials) == 0L) {
    return(tibble::tibble(n_frames = integer(), duration_s = numeric()))
  }

  auto <- is.null(fields)
  if (auto) {
    fields <- unique(unlist(lapply(trials, function(t) names(t$metadata))))
    fields <- setdiff(fields, reserved)
  } else {
    if (!is.character(fields) || anyNA(fields)) {
      cli::cli_abort(
        "{.arg fields} must be a character vector of metadata field names."
      )
    }
    clash <- intersect(fields, reserved)
    if (length(clash) > 0L) {
      cli::cli_abort(c(
        "{.arg fields} must not name {.val {clash}}.",
        i = "{.val {reserved}} are always computed from the trial itself."
      ))
    }
    known <- unique(unlist(lapply(trials, function(t) names(t$metadata))))
    unknown <- setdiff(fields, known)
    if (length(unknown) > 0L) {
      cli::cli_abort(c(
        "{.arg fields} names metadata field{?s} that no trial carries:
         {.val {unknown}}.",
        i = "Available field{?s}: {.val {known}}."
      ))
    }
  }

  cols <- list()
  for (f in fields) {
    v <- .cohort_field(trials, f, strict = !auto)
    if (is.null(v)) next
    if (auto && all(is.na(v))) next
    cols[[f]] <- v
  }
  cols$n_frames <- vapply(trials, function(t) as.integer(t$n_frames),
                          integer(1))
  cols$duration_s <- vapply(trials, function(t) as.numeric(t$duration),
                            numeric(1))
  tibble::as_tibble(cols)
}

#' Filter a Dataset by Trial Metadata, With Count Assertions
#'
#' Keeps the trials whose metadata satisfy a predicate, records the filter
#' label on the returned dataset, and — when `n_units` or `n_subjects` are
#' given — asserts that the surviving cohort has exactly the expected size.
#' The assertion is the point: a cohort step that cannot fail cannot protect
#' a result.
#'
#' @param dataset A [pr_dataset] object, or a list of [pr_trial] objects.
#' @param f A predicate applied to each trial's `metadata` list. Either a
#'   function of one argument, or a one-sided formula such as
#'   `~ .x$Mode == "MS"`. It must return a single `TRUE`/`FALSE` per trial;
#'   `NA` is treated as `FALSE` with a warning.
#' @param label Character. Short name for this filter, stored on the result
#'   as `filter_label` and appended to `filter_history`, and used in
#'   assertion messages. Default `NULL` uses `"filter"`.
#' @param n_units Integer. Expected number of trials after filtering, or
#'   `NULL` (default) for no assertion.
#' @param n_subjects Integer. Expected number of distinct subjects after
#'   filtering, or `NULL` (default) for no assertion.
#' @param subject_field Character. Metadata field identifying the subject.
#'   Default `"ID"`.
#'
#' @return A [pr_dataset] containing the surviving trials, with extra
#'   elements `filter_label` and `filter_history`.
#' @export
#' @family cohort functions
#' @examples
#' layout <- pr_layout_mat("16")
#' mk <- function(id, mode) {
#'   pr_trial(matrix(1, 3, layout$n_sensors), time = c(0, 0.02, 0.04),
#'            layout = layout, metadata = list(ID = id, Mode = mode))
#' }
#' ds <- pr_dataset(list(mk("ID001", "MS"), mk("ID001", "MH"),
#'                       mk("ID002", "MS")))
#' walk <- pr_dataset_filter(ds, ~ .x$Mode == "MS", label = "walk",
#'                           n_units = 2, n_subjects = 2)
#' walk$filter_label
pr_dataset_filter <- function(dataset, f, label = NULL, n_units = NULL,
                              n_subjects = NULL, subject_field = "ID") {
  trials <- .cohort_trials(dataset)
  n_units <- .cohort_count_arg(n_units, "n_units")
  n_subjects <- .cohort_count_arg(n_subjects, "n_subjects")
  if (is.null(label)) {
    label <- "filter"
  } else if (!is.character(label) || length(label) != 1L || is.na(label)) {
    cli::cli_abort("{.arg label} must be a single string or {.code NULL}.")
  }

  # Conditions raised inside the closures below must report against
  # pr_dataset_filter(), not against the closure.
  here <- environment()
  fn <- tryCatch(
    rlang::as_function(f),
    error = function(e) {
      cli::cli_abort(c(
        "{.arg f} must be a function of one argument or a one-sided
         formula such as {.code ~ .x$Mode == \"MS\"}.",
        x = conditionMessage(e)
      ), call = here)
    }
  )

  keep <- vapply(seq_along(trials), function(i) {
    v <- fn(trials[[i]]$metadata)
    if (!is.logical(v) || length(v) != 1L) {
      tl <- .cohort_trial_label(trials[[i]], i)
      named <- if (identical(tl, paste0("trial ", i))) {
        ""
      } else {
        paste0(" (", tl, ")")
      }
      cli::cli_abort(c(
        "{.arg f} must return a single {.cls logical} value for every trial.",
        x = "Trial {i}{named} returned {.cls {class(v)[1]}} of length
             {length(v)}.",
        i = "A missing metadata field compares to {.code logical(0)}; guard
             with {.fn isTRUE} or supply a default."
      ), call = here)
    }
    v
  }, logical(1))

  na_idx <- which(is.na(keep))
  if (length(na_idx) > 0L) {
    cli::cli_warn(c(
      "{.arg f} returned {.val {NA}} for {length(na_idx)} trial{?s};
       treating {?it/them} as {.val {FALSE}}.",
      i = "Affected trial{?s}: {.val {na_idx}}."
    ))
    keep[na_idx] <- FALSE
  }

  group_var <- if (inherits(dataset, "pr_dataset")) {
    dataset$group_var
  } else {
    "condition"
  }
  name <- if (inherits(dataset, "pr_dataset")) dataset$name else "dataset"

  out <- pr_dataset(trials[keep], group_var = group_var, name = name)
  history <- if (inherits(dataset, "pr_dataset")) {
    dataset$filter_history
  } else {
    NULL
  }
  out$filter_label <- label
  out$filter_history <- c(history, label)
  out$n_trials_before <- length(trials)

  if (!is.null(n_units) || !is.null(n_subjects)) {
    pr_assert_cohort(
      out,
      n_units = n_units,
      n_subjects = n_subjects,
      subject_col = subject_field,
      label = label
    )
  }
  out
}

#' Assert Cohort Size
#'
#' Checks that a cohort holds exactly the expected number of units (trials
#' or rows) and, optionally, of distinct subjects. Aborts with a message
#' naming the expectation, the actual count, and the shortfall or surplus.
#'
#' Use it as a tripwire around every step that can silently drop data —
#' reading a directory, filtering, joining. A guard that has never fired
#' proves nothing, so give it the real numbers from your design.
#'
#' @param x A [pr_dataset] object, a list of [pr_trial] objects, or a data
#'   frame (for example the output of [pr_design_table()]).
#' @param n_units Integer. Expected number of units, or `NULL` to skip.
#'   A unit is a trial (dataset) or a row (data frame) unless `unit_col`
#'   names a field/column, in which case units are its distinct values.
#' @param n_subjects Integer. Expected number of distinct subjects, or
#'   `NULL` to skip.
#' @param unit_col Character. Field/column whose distinct values are the
#'   units. `NULL` (default) counts trials or rows.
#' @param subject_col Character. Field/column identifying the subject.
#'   `NULL` (default) uses the first of `"subject_id"` or `"ID"` that
#'   exists, and aborts if neither does.
#' @param label Character. Name of the cohort, used in messages. `NULL`
#'   (default) uses the dataset's `filter_label` or `name`, else
#'   `"cohort"`.
#'
#' @return Invisibly returns `x`, so the assertion can sit in a pipeline.
#'   Aborts with condition class `pr_cohort_assert_failed` on mismatch.
#' @export
#' @family cohort functions
#' @examples
#' design <- data.frame(
#'   ID = c("ID001", "ID001", "ID002"),
#'   Mode = c("MS", "MH", "MS")
#' )
#' pr_assert_cohort(design, n_units = 3, n_subjects = 2, subject_col = "ID")
#'
#' # A wrong expectation fails loudly:
#' try(pr_assert_cohort(design, n_units = 431, label = "all recordings"))
pr_assert_cohort <- function(x, n_units = NULL, n_subjects = NULL,
                             unit_col = NULL, subject_col = NULL,
                             label = NULL) {
  if (!inherits(x, "pr_dataset") && !is.data.frame(x)) {
    if (is.list(x) && all(vapply(x, inherits, logical(1), "pr_trial"))) {
      x <- pr_dataset(x)
    } else {
      cli::cli_abort(
        "{.arg x} must be a {.cls pr_dataset}, a list of {.cls pr_trial}
         objects, or a {.cls data.frame}."
      )
    }
  }
  n_units <- .cohort_count_arg(n_units, "n_units")
  n_subjects <- .cohort_count_arg(n_subjects, "n_subjects")

  if (is.null(label)) {
    label <- if (inherits(x, "pr_dataset")) {
      x$filter_label %||% x$name %||% "cohort"
    } else {
      "cohort"
    }
  }
  if (!is.character(label) || length(label) != 1L || is.na(label)) {
    cli::cli_abort("{.arg label} must be a single string or {.code NULL}.")
  }

  if (!is.null(n_units)) {
    if (is.null(unit_col)) {
      actual <- if (inherits(x, "pr_dataset")) length(x$trials) else nrow(x)
      what <- if (inherits(x, "pr_dataset")) "trial" else "row"
      .cohort_assert_count(actual, n_units, what, label)
    } else {
      v <- .cohort_column(x, unit_col, "unit_col")
      u <- unique(v[!is.na(v)])
      .cohort_assert_count(
        length(u), n_units,
        sprintf("distinct %s value", unit_col), label, values = u
      )
    }
  }

  if (!is.null(n_subjects)) {
    if (is.null(subject_col)) {
      known <- if (inherits(x, "pr_dataset")) {
        unique(unlist(lapply(x$trials, function(t) names(t$metadata))))
      } else {
        names(x)
      }
      subject_col <- intersect(c("subject_id", "ID"), known)[1]
      if (is.na(subject_col)) {
        cli::cli_abort(c(
          "Cannot count subjects: {.arg subject_col} is {.code NULL} and
           neither {.val subject_id} nor {.val ID} is present.",
          i = "Name the subject field with {.arg subject_col}."
        ))
      }
    }
    v <- .cohort_column(x, subject_col, "subject_col")
    u <- unique(v[!is.na(v)])
    .cohort_assert_count(
      length(u), n_subjects,
      sprintf("distinct %s value", subject_col), label, values = u
    )
  }

  invisible(x)
}

#' Validate Cohort Homogeneity
#'
#' Checks that every trial in a dataset is analysable together: same sensor
#' count, same layout name, non-empty, and free of missing, infinite or
#' negative pressure values. Anything that would make a cohort-level
#' summary meaningless is reported per trial.
#'
#' The reference sensor count and layout name are the *modal* values across
#' the dataset (ties broken by first appearance), so a single odd recording
#' is flagged rather than the other 430.
#'
#' @param dataset A [pr_dataset] object, or a list of [pr_trial] objects.
#' @param strict Logical. If `TRUE` (default), abort when any problem is
#'   found. If `FALSE`, warn and return the problem table.
#'
#' @return A [tibble::tibble] with one row per problem and columns
#'   `trial` (integer index), `trial_label`, `check`, `expected`, `actual`
#'   and `problem`. Zero rows means the cohort is homogeneous. When
#'   `strict = TRUE` and problems exist, aborts with condition class
#'   `pr_dataset_invalid`, carrying the same tibble in the condition's
#'   `problems` field.
#' @export
#' @family cohort functions
#' @examples
#' layout <- pr_layout_mat("16")
#' mk <- function() {
#'   pr_trial(matrix(1, 3, layout$n_sensors), time = c(0, 0.02, 0.04),
#'            layout = layout)
#' }
#' pr_validate_dataset(pr_dataset(list(mk(), mk())))
#'
#' # A mixed-layout cohort is reported, not silently summarised:
#' odd <- pr_example_trial("insole")
#' problems <- pr_validate_dataset(pr_dataset(list(mk(), mk(), odd)),
#'                                 strict = FALSE)
#' problems$check
pr_validate_dataset <- function(dataset, strict = TRUE) {
  trials <- .cohort_trials(dataset)
  if (!is.logical(strict) || length(strict) != 1L || is.na(strict)) {
    cli::cli_abort("{.arg strict} must be {.code TRUE} or {.code FALSE}.")
  }
  if (length(trials) == 0L) {
    cli::cli_abort(
      "{.arg dataset} contains no trials; there is nothing to validate."
    )
  }

  n_sensors <- vapply(trials, function(t) as.integer(t$n_sensors), integer(1))
  lay_name <- vapply(
    trials, function(t) as.character(t$layout$name %||% NA_character_),
    character(1)
  )
  ref_sensors <- .cohort_modal(n_sensors)
  ref_layout <- .cohort_modal(lay_name)

  rows <- list()
  add <- function(i, check, expected, actual, problem) {
    rows[[length(rows) + 1L]] <<- tibble::tibble(
      trial = as.integer(i),
      trial_label = .cohort_trial_label(trials[[i]], i),
      check = check,
      expected = as.character(expected),
      actual = as.character(actual),
      problem = problem
    )
  }

  for (i in seq_along(trials)) {
    tr <- trials[[i]]
    if (!identical(n_sensors[i], ref_sensors)) {
      add(i, "n_sensors", ref_sensors, n_sensors[i],
          sprintf("sensor count differs from the cohort (%d vs %d)",
                  n_sensors[i], ref_sensors))
    }
    if (!identical(lay_name[i], ref_layout)) {
      add(i, "layout_name", ref_layout, lay_name[i],
          sprintf("layout is '%s', cohort layout is '%s'",
                  lay_name[i], ref_layout))
    }
    if (tr$n_frames == 0L) {
      add(i, "n_frames", "> 0", tr$n_frames, "trial holds no frames")
    }
    if (ncol(tr$pressure) != tr$layout$n_sensors) {
      add(i, "pressure_cols", tr$layout$n_sensors, ncol(tr$pressure),
          "pressure columns do not match the layout's active sensors")
    }
    if (tr$n_frames > 0L) {
      if (anyNA(tr$pressure)) {
        n_na <- sum(is.na(tr$pressure))
        add(i, "missing", 0, n_na,
            sprintf("%d missing pressure value(s)", n_na))
      } else {
        rng <- range(tr$pressure)
        if (!all(is.finite(rng))) {
          add(i, "finite", "finite", paste(rng, collapse = " .. "),
              "pressure contains non-finite values")
        } else if (rng[1] < 0) {
          add(i, "negative", ">= 0", rng[1],
              sprintf("minimum pressure is %g", rng[1]))
        }
      }
      if (tr$n_frames > 1L && any(diff(tr$time) < 0)) {
        add(i, "time_order", "increasing", "decreasing",
            "time is not monotonically increasing")
      }
    }
  }

  problems <- if (length(rows) == 0L) {
    tibble::tibble(
      trial = integer(), trial_label = character(), check = character(),
      expected = character(), actual = character(), problem = character()
    )
  } else {
    dplyr::bind_rows(rows)
  }

  if (nrow(problems) > 0L) {
    shown <- utils::head(problems, 10L)
    bullets <- stats::setNames(
      sprintf("Trial %d (%s) - %s: %s",
              shown$trial, shown$trial_label, shown$check, shown$problem),
      rep("x", nrow(shown))
    )
    header <- "{nrow(problems)} cohort problem{?s} in
               {length(unique(problems$trial))} of {length(trials)} trial{?s}."
    footer <- if (nrow(problems) > nrow(shown)) {
      c(i = "{nrow(problems) - nrow(shown)} further problem{?s} not shown.")
    } else {
      NULL
    }
    if (strict) {
      cli::cli_abort(
        c(header, bullets, footer,
          i = "Call {.code pr_validate_dataset(dataset, strict = FALSE)} for
               the full problem table."),
        class = "pr_dataset_invalid",
        problems = problems
      )
    }
    cli::cli_warn(c(header, bullets, footer))
  }

  problems
}
