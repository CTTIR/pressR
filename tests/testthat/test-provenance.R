# Helpers -------------------------------------------------------------------

# A small, fully specified frame that exercises every hashable storage type
# including NA in each. Its md5 is asserted below as a literal, so any change
# to the canonical byte stream fails loudly instead of silently invalidating
# every lock file in the wild.
pv_tiny <- function() {
  data.frame(
    a = c(1L, 2L, NA_integer_),
    b = c(0.1, -2.5, NA_real_),
    c = c("x", NA, "z"),
    d = c(TRUE, FALSE, NA),
    stringsAsFactors = FALSE
  )
}

# The 44 non-empty cells of the real cohort design
# (data/tidy_data/design.rds: 431 rows, Saddle x Pad x Weight x Mode), with
# their observed replicate counts. Committed as literals so CI, which has no
# access to the study drive, still regression-tests against the real design's
# structure rather than against an invented one.
pv_design_cells <- c(
  "K F KG00 MH 9",  "K F KG00 MS 9",  "K F KG40 MH 9",  "K F KG40 MS 9",
  "K F KG60 MH 9",  "K F KG60 MS 9",  "K F KG80 MH 6",  "K F KG80 MS 6",
  "K K KG00 MG 8",  "K K KG00 MH 19", "K K KG00 MS 19", "K K KG40 MG 8",
  "K K KG40 MH 19", "K K KG40 MS 19", "K K KG60 MG 8",  "K K KG60 MH 19",
  "K K KG60 MS 19", "K K KG80 MG 6",  "K K KG80 MH 11", "K K KG80 MS 11",
  "S F KG00 MG 8",  "S F KG00 MH 9",  "S F KG00 MS 9",  "S F KG40 MG 8",
  "S F KG40 MH 9",  "S F KG40 MS 9",  "S F KG60 MG 8",  "S F KG60 MH 9",
  "S F KG60 MS 9",  "S F KG80 MG 8",  "S F KG80 MH 9",  "S F KG80 MS 9",
  "W W KG00 MG 8",  "W W KG00 MH 8",  "W W KG00 MS 9",  "W W KG40 MG 8",
  "W W KG40 MH 9",  "W W KG40 MS 9",  "W W KG60 MG 8",  "W W KG60 MH 9",
  "W W KG60 MS 9",  "W W KG80 MG 6",  "W W KG80 MH 6",  "W W KG80 MS 6"
)

# Expand those cells back into a 431-row design table.
pv_design <- function() {
  parts <- do.call(rbind, strsplit(pv_design_cells, " ", fixed = TRUE))
  n <- as.integer(parts[, 5])
  data.frame(
    Saddle = rep(parts[, 1], n),
    Pad = rep(parts[, 2], n),
    Weight = rep(parts[, 3], n),
    Mode = rep(parts[, 4], n),
    stringsAsFactors = FALSE
  )
}

pv_lock_path <- function() tempfile(pattern = "pv_", fileext = ".lock")


# pr_lock_table -------------------------------------------------------------

test_that("pr_lock_table records shape, names and types in the sidecar", {
  x <- pv_tiny()
  path <- pv_lock_path()
  lock <- pr_lock_table(x, path)

  expect_equal(readLines(path), c(
    "# pressR table lock -- written by pr_lock_table(); do not hand-edit.",
    "lock_version: 1",
    "algo: md5",
    "nrow: 3",
    "ncol: 4",
    "content: ba1f02237c16ea3a28c59290915f0c70",
    "column: a\tinteger",
    "column: b\tdouble",
    "column: c\tcharacter",
    "column: d\tlogical"
  ))

  expect_equal(lock$nrow, 3L)
  expect_equal(lock$ncol, 4L)
  expect_equal(lock$columns[[1]], c("a", "b", "c", "d"))
  expect_equal(lock$types[[1]],
               c("integer", "double", "character", "logical"))
  expect_equal(lock$content, "ba1f02237c16ea3a28c59290915f0c70")
  unlink(path)
})

test_that("the content hash is a fixed value, not merely self-consistent", {
  # If this literal ever has to change, every lock file previously written
  # by pressR has been invalidated: bump .pv_lock_version deliberately.
  expect_equal(
    pr_lock_table(pv_tiny(), pv_lock_path())$content,
    "ba1f02237c16ea3a28c59290915f0c70"
  )
  expect_equal(
    pr_lock_table(data.frame(g = 1:3), pv_lock_path())$content,
    "192ede83c3173d1b3a03a410dcc25e96"
  )
  # Integer and double columns holding the same numbers hash differently:
  # storage type is part of the stream, so as.integer() cannot slip through.
  expect_equal(
    pr_lock_table(data.frame(g = as.numeric(1:3)), pv_lock_path())$content,
    "09ec14b9ee5ff090bb2d1fe5dfce0828"
  )
})

test_that("NA is carried by the mask and cannot be impersonated by zero", {
  x <- pv_tiny()
  zeroed <- x
  zeroed$b[3] <- 0

  h_na <- pr_lock_table(x, pv_lock_path())$content
  h_zero <- pr_lock_table(zeroed, pv_lock_path())$content
  expect_equal(h_zero, "8fe72f9764fc830175b9c73e860ff7f1")
  expect_false(h_na == h_zero)
})

test_that("class wrappers do not change the content hash", {
  x <- pv_tiny()
  # A tibble and a data.frame holding the same values lock identically.
  expect_equal(
    pr_lock_table(tibble::as_tibble(x), pv_lock_path())$content,
    pr_lock_table(x, pv_lock_path())$content
  )

  # A factor hashes as its labels, so the content matches the character
  # column; the difference is reported through `types` instead.
  chr <- data.frame(g = c("a", "b"), stringsAsFactors = FALSE)
  fac <- data.frame(g = factor(c("a", "b")))
  l_chr <- pr_lock_table(chr, pv_lock_path())
  l_fac <- pr_lock_table(fac, pv_lock_path())
  expect_equal(l_fac$content, l_chr$content)
  expect_equal(l_chr$types[[1]], "character")
  expect_equal(l_fac$types[[1]], "factor")
})

test_that("re-locking an unchanged table is byte-identical (no timestamp)", {
  x <- pv_tiny()
  p1 <- pv_lock_path()
  p2 <- pv_lock_path()
  pr_lock_table(x, p1)
  Sys.sleep(0)
  pr_lock_table(x, p2)
  expect_identical(readLines(p1), readLines(p2))
  unlink(c(p1, p2))
})

test_that("pr_lock_table reproduces the real cohort design's shape", {
  design <- pv_design()
  expect_equal(nrow(design), 431L)

  lock <- pr_lock_table(design, pv_lock_path())
  expect_equal(lock$nrow, 431L)
  expect_equal(lock$columns[[1]], c("Saddle", "Pad", "Weight", "Mode"))
  expect_equal(lock$types[[1]], rep("character", 4))
  expect_equal(nchar(lock$content), 32L)
})

test_that("pr_lock_table rejects bad input", {
  expect_error(pr_lock_table(1:10, pv_lock_path()), "must be a")
  expect_error(pr_lock_table(pv_tiny(), pv_lock_path(), algo = "sha256"),
               "md5")
  expect_error(
    pr_lock_table(pv_tiny(), file.path(tempdir(), "no_such_dir", "x.lock")),
    "does not exist"
  )
  # A list column cannot be hashed, and is refused rather than skipped.
  lst <- tibble::tibble(a = 1:2, b = list(1:3, 4:5))
  expect_error(pr_lock_table(lst, pv_lock_path()), "list column")
  # An unnamed or duplicated column makes the per-column record ambiguous.
  dup <- data.frame(a = 1:2, a = 3:4, check.names = FALSE)
  expect_error(pr_lock_table(dup, pv_lock_path()), "duplicated")
})


# pr_verify_lock ------------------------------------------------------------

test_that("pr_verify_lock passes an unchanged table", {
  x <- pv_design()
  path <- pv_lock_path()
  pr_lock_table(x, path)

  expect_message(res <- pr_verify_lock(x, path), "Lock verified")
  expect_true(as.logical(res))
  rep <- attr(res, "report")
  expect_equal(rep$property, c("rows", "columns", "types", "content"))
  expect_true(all(rep$passed))
  expect_equal(rep$expected[1], "431")
  unlink(path)
})

test_that("an edited value changes content alone", {
  x <- pv_tiny()
  path <- pv_lock_path()
  pr_lock_table(x, path)

  edited <- x
  edited$b[1] <- 0.2
  res <- suppressMessages(pr_verify_lock(edited, path))
  expect_false(as.logical(res))
  # Same rows, same names, same types -- only the numbers moved. This is
  # exactly the case a dim() check misses.
  expect_equal(attr(res, "report")$passed, c(TRUE, TRUE, TRUE, FALSE))
})

test_that("a dropped row is reported as a row-count change", {
  x <- pv_design()
  path <- pv_lock_path()
  pr_lock_table(x, path)

  res <- suppressMessages(pr_verify_lock(x[-1, , drop = FALSE], path))
  expect_false(as.logical(res))
  rep <- attr(res, "report")
  expect_equal(rep$passed, c(FALSE, TRUE, TRUE, FALSE))
  expect_equal(rep$expected[1], "431")
  expect_equal(rep$actual[1], "430")
})

test_that("a pure rename changes columns but not content", {
  x <- pv_tiny()
  path <- pv_lock_path()
  pr_lock_table(x, path)

  renamed <- x
  names(renamed)[1] <- "aa"
  res <- suppressMessages(pr_verify_lock(renamed, path))
  expect_false(as.logical(res))
  # Content is deliberately hashed without the names, so the report can say
  # "the values are the same, only the label moved".
  expect_equal(attr(res, "report")$passed, c(TRUE, FALSE, TRUE, TRUE))
})

test_that("a storage-type change is reported as types and content", {
  x <- pv_tiny()
  path <- pv_lock_path()
  pr_lock_table(x, path)

  coerced <- x
  coerced$a <- as.numeric(coerced$a)
  res <- suppressMessages(pr_verify_lock(coerced, path))
  expect_equal(attr(res, "report")$passed, c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(attr(res, "report")$expected[3],
               "integer, double, character, logical")
  expect_equal(attr(res, "report")$actual[3],
               "double, double, character, logical")
})

test_that("column reordering is caught even though the values are equal", {
  x <- pv_tiny()
  path <- pv_lock_path()
  pr_lock_table(x, path)

  res <- suppressMessages(pr_verify_lock(x[, c(2, 1, 3, 4)], path))
  expect_false(as.logical(res))
  expect_false(attr(res, "report")$passed[2])
})

test_that("pr_verify_lock errors on a caller mistake, not a data change", {
  x <- pv_tiny()
  # Missing file, malformed file and wrong version are the caller's problem
  # and must not be reported as evidence that the data moved.
  expect_error(pr_verify_lock(x, file.path(tempdir(), "absent.lock")),
               "does not exist")

  bad <- pv_lock_path()
  writeLines(c("lock_version: 1", "this line has no key"), bad)
  expect_error(pr_verify_lock(x, bad), "malformed")

  old <- pv_lock_path()
  path <- pv_lock_path()
  pr_lock_table(x, path)
  writeLines(sub("^lock_version: 1$", "lock_version: 0", readLines(path)),
             old)
  expect_error(pr_verify_lock(x, old), "version")

  expect_error(pr_verify_lock(1:3, path), "must be a")
  unlink(c(bad, old, path))
})


# pr_validate_summary -------------------------------------------------------

test_that("pr_validate_summary returns one row per rule with hard first", {
  x <- pv_design()
  res <- pr_validate_summary(
    x,
    hard = list(
      rows_431 = function(d) nrow(d) == 431L,
      mode_known = function(d) all(d$Mode %in% c("MG", "MH", "MS"))
    ),
    soft = list(saddle_known = function(d) d$Saddle %in% c("K", "S", "W")),
    label = "design"
  )

  expect_equal(res$rule, c("rows_431", "mode_known", "saddle_known"))
  expect_equal(res$level, c("hard", "hard", "soft"))
  expect_equal(res$passed, c(TRUE, TRUE, TRUE))
  expect_true(all(is.na(res$message)))
})

test_that("a hard failure aborts and carries the full result table", {
  x <- pv_design()
  cnd <- tryCatch(
    pr_validate_summary(
      x,
      hard = list(
        rows_100 = function(d) nrow(d) == 100L,
        mode_known = function(d) all(d$Mode %in% c("MG", "MH", "MS"))
      ),
      label = "design"
    ),
    error = function(e) e
  )
  expect_s3_class(cnd, "pr_validate_failed")
  expect_match(conditionMessage(cnd), "rows_100")
  # Every rule is evaluated before anything is signalled, so the passing
  # rule is still in the table.
  expect_equal(cnd$results$rule, c("rows_100", "mode_known"))
  expect_equal(cnd$results$passed, c(FALSE, TRUE))
  expect_equal(cnd$label, "design")
})

test_that("a soft failure warns and still returns the table", {
  x <- pv_design()
  expect_warning(
    res <- pr_validate_summary(
      x,
      soft = list(mode_balanced = function(d) {
        tab <- table(d$Mode)
        if (length(unique(as.integer(tab))) == 1L) {
          character(0)
        } else {
          paste0("Mode counts differ: ",
                 paste(names(tab), as.integer(tab), sep = "=",
                       collapse = ", "))
        }
      }),
      label = "design"
    ),
    class = "pr_validate_soft_failed"
  )
  # These are the real cohort's mode counts.
  expect_equal(res$passed, FALSE)
  expect_equal(res$message,
               "Mode counts differ: MG=92, MH=169, MS=170")
})

test_that("both rule return contracts work, and per-row rules count", {
  x <- data.frame(n_frames = c(10L, -1L, 0L, 5L))
  res <- suppressWarnings(pr_validate_summary(
    x,
    soft = list(
      logical_rule = function(d) d$n_frames > 0,
      character_rule = function(d) {
        bad <- which(d$n_frames <= 0)
        if (length(bad) == 0L) character(0) else paste0("row ", bad)
      },
      passing_character = function(d) character(0)
    )
  ))
  expect_equal(res$passed, c(FALSE, FALSE, TRUE))
  expect_equal(res$message[1], "2 of 4 elements failed")
  expect_equal(res$message[2], "row 2; row 3")
  expect_true(is.na(res$message[3]))
})

test_that("a rule that throws is reported, not propagated", {
  res <- suppressWarnings(pr_validate_summary(
    pv_tiny(),
    soft = list(broken = function(d) stop("no such column"))
  ))
  expect_false(res$passed)
  expect_match(res$message, "rule errored: no such column")
})

test_that("pr_validate_summary handles the empty case and bad input", {
  res <- pr_validate_summary(pv_tiny())
  expect_equal(nrow(res), 0L)
  expect_equal(names(res), c("rule", "level", "passed", "message"))

  expect_error(pr_validate_summary(1:3), "must be a")
  expect_error(
    pr_validate_summary(pv_tiny(), hard = list(function(d) TRUE)),
    "must be named"
  )
  expect_error(
    pr_validate_summary(pv_tiny(),
                        hard = list(r = function(d) TRUE),
                        soft = list(r = function(d) TRUE)),
    "both"
  )
  expect_error(
    pr_validate_summary(pv_tiny(), hard = list(r = "not a function")),
    "not a function"
  )
  expect_error(
    pr_validate_summary(pv_tiny(), hard = list(r = function(d) 42)),
    "logical vector or a character vector"
  )
})


# pr_factor_contract --------------------------------------------------------

test_that("pr_factor_contract passes on the real design's level sets", {
  design <- pv_design()
  out <- pr_factor_contract(
    design,
    list(
      Saddle = c("K", "S", "W"),
      Pad = c("F", "K", "W"),
      Weight = c("KG00", "KG40", "KG60", "KG80"),
      Mode = c("MG", "MH", "MS")
    )
  )
  expect_identical(out, design)
})

test_that("an unexpected level aborts naming the column, value and rows", {
  design <- pv_design()
  design$ID <- sprintf("ID%03d", seq_len(nrow(design)))

  cnd <- tryCatch(
    pr_factor_contract(design, list(Mode = c("MG", "MH")), id_cols = "ID"),
    error = function(e) e
  )
  expect_s3_class(cnd, "pr_factor_contract_failed")
  expect_match(conditionMessage(cnd), "unexpected level \"MS\"")

  probs <- cnd$problems
  expect_equal(probs$column, "Mode")
  expect_equal(probs$issue, "unexpected_level")
  expect_equal(probs$value, "MS")
  # 170 MS recordings, exactly as in the real cohort.
  expect_equal(probs$n_rows, 170L)
  expect_match(probs$ids, "^ID")
})

test_that("a level that never appears is a violation too", {
  design <- pv_design()
  cnd <- tryCatch(
    pr_factor_contract(design, list(Mode = c("MG", "MH", "MS", "MX"))),
    error = function(e) e
  )
  expect_s3_class(cnd, "pr_factor_contract_failed")
  expect_equal(cnd$problems$issue, "missing_level")
  expect_equal(cnd$problems$value, "MX")
  expect_match(conditionMessage(cnd), "never appears")
})

test_that("factor level order is contracted, character order is not", {
  fac <- data.frame(M = factor(c("a", "b"), levels = c("b", "a")))
  cnd <- tryCatch(pr_factor_contract(fac, list(M = c("a", "b"))),
                  error = function(e) e)
  expect_s3_class(cnd, "pr_factor_contract_failed")
  expect_equal(cnd$problems$issue, "wrong_order")
  expect_equal(cnd$problems$value, "b < a")

  # The same level set in the declared order passes.
  expect_identical(pr_factor_contract(fac, list(M = c("b", "a"))), fac)

  # A character column carries no order, so first-appearance order is
  # irrelevant and only the set is contracted.
  chr <- data.frame(M = c("b", "a"), stringsAsFactors = FALSE)
  expect_identical(pr_factor_contract(chr, list(M = c("a", "b"))), chr)
})

test_that("a factor level declared but unused is still unexpected", {
  fac <- data.frame(M = factor(c("a", "b"), levels = c("a", "b", "c")))
  cnd <- tryCatch(pr_factor_contract(fac, list(M = c("a", "b"))),
                  error = function(e) e)
  expect_equal(cnd$problems$issue, "unexpected_level")
  expect_equal(cnd$problems$value, "c")
  expect_equal(cnd$problems$n_rows, 0L)
})

test_that("NA is a violation unless the contract admits it", {
  x <- data.frame(M = c("a", NA, "b"), ID = c("i1", "i2", "i3"),
                  stringsAsFactors = FALSE)
  cnd <- tryCatch(
    pr_factor_contract(x, list(M = c("a", "b")), id_cols = "ID"),
    error = function(e) e
  )
  expect_equal(cnd$problems$issue, "missing_value")
  expect_equal(cnd$problems$n_rows, 1L)
  expect_equal(cnd$problems$ids, "i2")

  expect_identical(pr_factor_contract(x, list(M = c("a", "b", NA))), x)
})

test_that("pr_factor_contract rejects bad input", {
  x <- pv_design()
  expect_error(pr_factor_contract(1:3, list(a = "b")), "must be a")
  expect_error(pr_factor_contract(x, list()), "non-empty named list")
  expect_error(pr_factor_contract(x, list(c("a", "b"))), "must be named")
  expect_error(pr_factor_contract(x, list(Nope = "a")), "not in")
  expect_error(
    pr_factor_contract(x, list(Mode = c("MG", "MH", "MS")),
                       id_cols = "Nope"),
    "not in"
  )
  expect_error(
    pr_factor_contract(x, list(Mode = c("MG", "MG", "MH", "MS"))),
    "repeat"
  )
  expect_error(pr_factor_contract(x, list(Mode = character(0))),
               "non-empty vector")
})


# pr_design_gaps ------------------------------------------------------------

test_that("pr_design_gaps reproduces the real cohort's design gaps", {
  design <- pv_design()
  gaps <- pr_design_gaps(design, c("Saddle", "Pad", "Weight", "Mode"))

  # 3 saddles x 3 pads x 4 weights x 3 modes = 108 cells; only 44 were run.
  expect_equal(nrow(gaps), 108L)
  expect_equal(sum(gaps$n), 431L)
  expect_equal(unique(gaps$expected), 9L)
  expect_equal(as.integer(table(gaps$status)[
    c("missing", "ok", "over", "under")
  ]), c(64L, 19L, 8L, 17L))

  # The over-represented cells are all the K saddle with the K pad -- the
  # combination every horse was measured on.
  over <- gaps[gaps$status == "over", ]
  expect_equal(unique(over$Saddle), "K")
  expect_equal(unique(over$Pad), "K")
  expect_equal(over$n, c(19L, 19L, 19L, 19L, 19L, 19L, 11L, 11L))
  expect_equal(over$delta, over$n - 9L)
})

test_that("pr_design_gaps exposes the Saddle/Pad nesting", {
  design <- pv_design()
  gaps <- pr_design_gaps(design, c("Saddle", "Pad"))

  expect_equal(nrow(gaps), 9L)
  expect_equal(gaps$Saddle, rep(c("K", "S", "W"), each = 3))
  expect_equal(gaps$Pad, rep(c("F", "K", "W"), times = 3))
  # Pad is nested inside Saddle: S was only ever run with F, W only with W.
  expect_equal(gaps$n, c(66L, 166L, 0L, 104L, 0L, 0L, 0L, 0L, 95L))
  expect_equal(sum(gaps$status == "missing"), 5L)
  expect_equal(
    gaps$status[gaps$n == 0L],
    rep("missing", 5)
  )
})

test_that("a genuinely crossed pair shows no missing cell", {
  design <- pv_design()
  gaps <- pr_design_gaps(design, c("Saddle", "Mode"))
  expect_equal(nrow(gaps), 9L)
  expect_equal(sum(gaps$status == "missing"), 0L)
  expect_equal(sum(gaps$n), 431L)
})

test_that("expected can be given explicitly", {
  design <- data.frame(
    Saddle = c("K", "K", "K", "S", "S", "W"),
    Pad = c("F", "K", "K", "F", "F", "W"),
    stringsAsFactors = FALSE
  )
  gaps <- pr_design_gaps(design, c("Saddle", "Pad"), expected = 2)
  expect_equal(unique(gaps$expected), 2L)
  expect_equal(gaps$n, c(1L, 2L, 0L, 2L, 0L, 0L, 0L, 0L, 1L))
  expect_equal(gaps$status,
               c("under", "ok", "missing", "ok", "missing", "missing",
                 "missing", "missing", "under"))

  # Counts 1 and 2 each occur twice, and the tie breaks towards the larger:
  # a tie should err towards calling a thin cell under-represented.
  expect_equal(unique(pr_design_gaps(design, c("Saddle", "Pad"))$expected),
               2L)
})

test_that("factor levels drive the crossing, including unused ones", {
  x <- data.frame(
    a = factor(c("lo", "hi"), levels = c("lo", "mid", "hi")),
    b = c("p", "q"),
    stringsAsFactors = FALSE
  )
  gaps <- pr_design_gaps(x, c("a", "b"))
  # levels() order is respected, so `mid` sits between `lo` and `hi` and
  # its two empty cells are surfaced rather than being invisible.
  expect_equal(gaps$a, rep(c("lo", "mid", "hi"), each = 2))
  expect_equal(gaps$n, c(1L, 0L, 0L, 0L, 0L, 1L))
  expect_equal(sum(gaps$status == "missing"), 4L)
})

test_that("rows with NA in a crossing factor are dropped with a warning", {
  x <- data.frame(a = c("p", "q", NA), b = c("u", "v", "u"),
                  stringsAsFactors = FALSE)
  expect_warning(gaps <- pr_design_gaps(x, c("a", "b")), "missing value")
  expect_equal(sum(gaps$n), 2L)
  expect_equal(nrow(gaps), 4L)
})

test_that("pr_design_gaps rejects bad input", {
  design <- pv_design()
  expect_error(pr_design_gaps(1:3, "a"), "must be a")
  expect_error(pr_design_gaps(design, character(0)), "non-empty")
  expect_error(pr_design_gaps(design, "Nope"), "not in")
  expect_error(pr_design_gaps(design, c("Mode", "Mode")), "repeats")
  expect_error(pr_design_gaps(design, "Mode", expected = -1), "non-negative")
  expect_error(pr_design_gaps(design, "Mode", expected = 2.5), "whole number")
  expect_error(pr_design_gaps(design, "Mode", expected = c(1, 2)),
               "single non-negative")
})


# Integration with the reader ------------------------------------------------

test_that("a design table from a real recording locks and verifies", {
  path <- test_path("fixtures", "ID052_K_K_KG00_MS.asc")
  skip_if_not(file.exists(path))

  trial <- pr_read_pliance(path)
  design <- pr_design_table(pr_dataset(list(trial)))
  # `source_file` is an absolute path and differs per machine, so it is not
  # part of what a lock should pin.
  design <- design[, setdiff(names(design), "source_file"), drop = FALSE]

  lock_path <- pv_lock_path()
  lock <- pr_lock_table(design, lock_path)
  expect_equal(lock$nrow, 1L)
  expect_true("n_frames" %in% lock$columns[[1]])
  expect_true(as.logical(suppressMessages(pr_verify_lock(design, lock_path))))

  # The truncated fixture is 200 frames at 50 Hz.
  expect_equal(design$n_frames, 200L)

  res <- pr_validate_summary(
    design,
    hard = list(
      frames_positive = function(d) d$n_frames > 0,
      unit_kpa = function(d) all(d$pressure_unit == "kPa")
    ),
    label = "ID052 fixture"
  )
  expect_true(all(res$passed))

  # The filename encodes the design factors; contract them against the
  # cohort's real level sets.
  meta <- pr_meta_from_filename(
    basename(path), c("ID", "Saddle", "Pad", "Weight", "Mode")
  )
  expect_identical(
    pr_factor_contract(
      meta,
      list(Saddle = "K", Pad = "K", Weight = "KG00", Mode = "MS"),
      id_cols = "ID"
    ),
    meta
  )
  unlink(lock_path)
})
