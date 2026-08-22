# ---------------------------------------------------------------------------
# Provenance and design integrity.
#
# A cohort analysis is only reproducible if two claims hold: the table you
# are analysing is byte-for-byte the table you analysed last time, and the
# design it encodes is the design you think it is. Both claims are usually
# made in prose ("431 recordings, 19 horses, fully crossed") and never
# checked. The functions here make them executable:
#
#   pr_lock_table()        record what a table is
#   pr_verify_lock()       assert it still is
#   pr_validate_summary()  two-tier rule table: hard aborts, soft warns
#   pr_factor_contract()   assert the level sets of the design factors
#   pr_design_gaps()       observed cells against the full crossing
#
# Nothing here touches a pr_trial or a pressure matrix. These are data-frame
# functions, deliberately, so they work on a design table, a per-recording
# summary, a joined analysis frame, or anything else on the way to a model.
#
# Hashing contract
# ----------------
# The content hash is md5 (tools::md5sum(), the only hash in base R) over a
# byte stream this file writes itself, column by column, rather than over
# utils::write.csv() output or a serialize() dump. Both of those are
# unstable in ways that would make a lock file fail for the wrong reason:
#
#   * write.csv() renders doubles as decimal text. R 4.3.0 changed how
#     as.character() formats doubles, so the same numbers can produce
#     different characters under different R versions, and decimal text
#     does not round-trip a double in any case.
#   * serialize() writes the R version that produced the stream into its own
#     header, so the same object hashes differently under R 4.3 and R 4.6.
#
# The stream written here is: a fixed magic string, then per column an NA
# mask (one byte per row) followed by the values as big-endian IEEE-754
# doubles / 4-byte big-endian integers / NUL-terminated UTF-8 strings. Byte
# order is pinned, so x86 and ARM agree; doubles keep every bit, so no
# formatting decision enters; and NAs are carried by the mask rather than by
# a sentinel value, so `NA` and `0` never collide. Column names and types
# are recorded in the lock file but are NOT part of the content hash, which
# is what lets pr_verify_lock() report a pure rename as "columns changed,
# content unchanged".
# ---------------------------------------------------------------------------

# Lock file format version. Part of the hashed stream, so bumping it
# invalidates old locks on purpose rather than silently accepting them.
.pv_lock_version <- 1L

# Internal: a single non-empty string.
.pv_check_string <- function(x, arg, call = rlang::caller_env()) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort("{.arg {arg}} must be a single non-empty string.",
                   call = call)
  }
  invisible(x)
}

# Internal: a data frame, with the message naming what was passed instead.
.pv_check_df <- function(x, arg = "x", call = rlang::caller_env()) {
  if (!is.data.frame(x)) {
    cli::cli_abort(
      c("{.arg {arg}} must be a {.cls data.frame}.",
        x = "Got {.cls {class(x)[1]}}."),
      call = call
    )
  }
  invisible(x)
}

# Internal: column names usable as a lock key. Tabs and newlines would break
# the line-oriented lock file, and an unnamed or duplicated column makes the
# per-column record ambiguous.
.pv_check_colnames <- function(x, call = rlang::caller_env()) {
  nms <- names(x)
  if (is.null(nms) || anyNA(nms) || !all(nzchar(nms))) {
    cli::cli_abort("Every column of {.arg x} must have a name.", call = call)
  }
  bad <- nms[grepl("[\t\r\n]", nms)]
  if (length(bad) > 0L) {
    cli::cli_abort(
      c("Column name{?s} {.val {bad}} contain{?s/} a tab or newline.",
        i = "A lock file records one column per line; rename first."),
      call = call
    )
  }
  dup <- unique(nms[duplicated(nms)])
  if (length(dup) > 0L) {
    cli::cli_abort("Column name{?s} {.val {dup}} {?is/are} duplicated.",
                   call = call)
  }
  invisible(nms)
}

# Internal: stable type label. typeof() is used rather than class() because
# it is a property of the SEXP and has not changed across R versions, while
# class() picks up implicit and newly added classes. The factor and time
# classes are named explicitly because their storage type alone would lose
# the distinction that matters to a reader of the lock file.
.pv_col_type <- function(col) {
  if (is.factor(col)) return("factor")
  cl <- class(col)[1L]
  if (cl %in% c("Date", "POSIXct", "POSIXlt", "difftime")) return(cl)
  typeof(col)
}

# Internal: reduce one column to a bare atomic vector for hashing. Factors
# become their labels, times become seconds, and every other attribute is
# dropped so that a tibble and a data.frame carrying the same numbers hash
# alike. `dim` is preserved so a matrix column keeps its shape.
.pv_canon_col <- function(col) {
  if (is.factor(col)) return(as.character(col))
  if (inherits(col, "POSIXlt")) return(as.numeric(as.POSIXct(col)))
  if (inherits(col, c("Date", "POSIXct"))) return(as.numeric(col))
  if (inherits(col, "difftime")) return(as.numeric(col, units = "secs"))
  d <- dim(col)
  attributes(col) <- NULL
  if (!is.null(d)) dim(col) <- d
  col
}

# Internal: write one canonical column to a binary connection.
.pv_write_col <- function(col, name, con, call = rlang::caller_env()) {
  v <- .pv_canon_col(col)
  if (is.list(v) || is.null(v)) {
    cli::cli_abort(
      c("Column {.val {name}} is a list column and cannot be hashed.",
        i = "Flatten it, or drop it before locking the table."),
      call = call
    )
  }
  na <- is.na(v)
  # One byte per row, written before the values: NA is carried by the mask,
  # never by an in-band sentinel, so no real value can impersonate it.
  writeBin(as.raw(na), con)
  if (is.character(v)) {
    s <- enc2utf8(v)
    s[na] <- ""
    # R strings cannot contain an embedded NUL, so NUL termination is an
    # unambiguous delimiter.
    writeBin(s, con)
  } else if (is.logical(v) || is.integer(v)) {
    i <- as.integer(v)
    i[na] <- 0L
    writeBin(i, con, size = 4L, endian = "big")
  } else if (is.double(v)) {
    d <- v
    d[na] <- 0
    writeBin(d, con, size = 8L, endian = "big")
  } else if (is.complex(v)) {
    z <- v
    z[na] <- complex(real = 0, imaginary = 0)
    writeBin(c(Re(z), Im(z)), con, size = 8L, endian = "big")
  } else {
    cli::cli_abort(
      "Column {.val {name}} has unhashable storage type {.val {typeof(v)}}.",
      call = call
    )
  }
  invisible(NULL)
}

# Internal: md5 of the canonical byte stream for a whole data frame.
.pv_content_hash <- function(x, call = rlang::caller_env()) {
  tmp <- tempfile(pattern = "pr_lock_", fileext = ".bin")
  con <- file(tmp, open = "wb")
  # `open` is read at exit time, so a column that aborts mid-stream still
  # closes the connection, while the normal path closes it once.
  open <- TRUE
  on.exit({
    if (open) try(close(con), silent = TRUE)
    unlink(tmp)
  }, add = TRUE)

  writeBin(paste0("pressR-lock-", .pv_lock_version), con)
  nms <- names(x)
  for (j in seq_along(x)) {
    .pv_write_col(x[[j]], nms[j], con, call = call)
  }
  close(con)
  open <- FALSE
  unname(tools::md5sum(tmp))
}

# Internal: everything a lock records about a table.
.pv_describe <- function(x, call = rlang::caller_env()) {
  list(
    n_row = nrow(x),
    n_col = ncol(x),
    columns = names(x),
    types = vapply(x, .pv_col_type, character(1), USE.NAMES = FALSE),
    content = .pv_content_hash(x, call = call)
  )
}

# Internal: read a lock file back into the same shape .pv_describe() returns.
.pv_read_lock <- function(path, call = rlang::caller_env()) {
  if (!file.exists(path)) {
    cli::cli_abort(
      c("Lock file {.file {path}} does not exist.",
        i = "Create it with {.fn pr_lock_table} first."),
      call = call
    )
  }
  lines <- readLines(path, warn = FALSE)
  lines <- lines[!grepl("^\\s*(#|$)", lines)]
  bad <- !grepl(":", lines, fixed = TRUE)
  if (any(bad)) {
    cli::cli_abort(
      c("Lock file {.file {path}} is malformed.",
        x = "Line{?s} {which(bad)} {?is/are} not {.code key: value}."),
      call = call
    )
  }
  key <- sub("^([^:]+):.*$", "\\1", lines)
  val <- sub("^[^:]+:[ ]?", "", lines)
  one <- function(k) {
    hit <- val[key == k]
    if (length(hit) != 1L) {
      cli::cli_abort(
        c("Lock file {.file {path}} is malformed.",
          x = "Expected exactly one {.field {k}} entry, found {length(hit)}."),
        call = call
      )
    }
    hit
  }
  ver_chr <- one("lock_version")
  ver <- suppressWarnings(as.integer(ver_chr))
  # Bound locally: cli would read a `{.pv_lock_version}` substitution as a
  # style name, because it starts with a dot.
  want <- .pv_lock_version
  if (is.na(ver) || !identical(ver, want)) {
    cli::cli_abort(
      c("Lock file {.file {path}} declares version {.val {ver_chr}}.",
        i = "This pressR writes and reads version {.val {want}} only;
             re-create the lock with {.fn pr_lock_table}."),
      call = call
    )
  }
  cols <- val[key == "column"]
  parts <- strsplit(cols, "\t", fixed = TRUE)
  if (length(cols) > 0L && !all(lengths(parts) == 2L)) {
    cli::cli_abort(
      c("Lock file {.file {path}} is malformed.",
        x = "Every {.field column} line must be {.code name<TAB>type}."),
      call = call
    )
  }
  n_row <- suppressWarnings(as.integer(one("nrow")))
  n_col <- suppressWarnings(as.integer(one("ncol")))
  if (is.na(n_row) || is.na(n_col)) {
    cli::cli_abort(
      c("Lock file {.file {path}} is malformed.",
        x = "{.field nrow} and {.field ncol} must be whole numbers."),
      call = call
    )
  }
  list(
    algo = one("algo"),
    n_row = n_row,
    n_col = n_col,
    columns = vapply(parts, `[`, character(1), 1L),
    types = vapply(parts, `[`, character(1), 2L),
    content = one("content")
  )
}

# Internal: collapse a character vector for the report tibble.
.pv_join <- function(x) {
  if (length(x) == 0L) "" else paste(x, collapse = ", ")
}

#' Lock a Table's Content and Shape
#'
#' Writes a sidecar lock file recording a data frame's row count, column
#' count, column names, column types and a content hash. Committed next to
#' the analysis, it turns "the input has not changed" from an assumption
#' into something [pr_verify_lock()] can check.
#'
#' @details
#' The hash is md5 — [tools::md5sum()] is the only hash function in base R —
#' computed over a byte stream this function writes itself: a fixed magic
#' string, then for each column an `NA` mask of one byte per row followed by
#' the values as big-endian IEEE-754 doubles, 4-byte big-endian integers, or
#' NUL-terminated UTF-8 strings.
#'
#' That stream is used in preference to the two obvious alternatives because
#' both are unstable in ways that would make a lock fail for the wrong
#' reason:
#'
#' * [utils::write.csv()] renders doubles as decimal text. R 4.3.0 changed
#'   how `as.character()` formats doubles, so identical numbers can produce
#'   different bytes under different R versions, and decimal text does not
#'   round-trip a double in any case.
#' * [serialize()] writes the R version that produced the stream into its
#'   own header, so the same object hashes differently under R 4.3 and
#'   R 4.6.
#'
#' Pinning the byte order makes x86 and ARM agree; writing doubles as bits
#' removes every formatting decision; carrying `NA` in a side mask means no
#' real value can impersonate a missing one. Before hashing, each column is
#' reduced to a bare vector — factors to their labels, `Date`/`POSIXct` to
#' seconds, all other attributes dropped — so a [tibble::tibble] and a
#' `data.frame` holding the same numbers hash alike, and a class change is
#' reported through the `types` line rather than as a content change.
#'
#' Column names and types are recorded but are deliberately *not* part of
#' the content hash. That is what lets [pr_verify_lock()] distinguish a pure
#' rename ("columns changed, content unchanged") from an edit to the data.
#'
#' No timestamp is written. Re-locking an unchanged table leaves the file
#' byte-identical, so a lock file under version control produces a diff only
#' when the table really moved.
#'
#' List columns cannot be hashed and are rejected with an error rather than
#' skipped, because a silently unhashed column is worse than no lock at all.
#'
#' @param x A data frame (or [tibble::tibble]) to lock.
#' @param path Path to the lock file to write. The parent directory must
#'   exist. A `.lock` extension is conventional but not required.
#' @param algo Hash algorithm. Only `"md5"` is available, because
#'   [tools::md5sum()] is the only hash in base R and this package takes no
#'   extra dependencies. Anything else is an error.
#'
#' @return Invisibly, a one-row [tibble::tibble] with columns `path`,
#'   `algo`, `nrow`, `ncol`, `columns` (list of character), `types` (list of
#'   character) and `content` (the hash).
#' @family provenance functions
#' @seealso [pr_verify_lock()] to check a table against a lock file.
#' @export
#' @examples
#' design <- data.frame(
#'   ID = c("ID001", "ID001", "ID003"),
#'   Mode = c("MH", "MS", "MG"),
#'   n_frames = c(23432L, 10662L, 8000L)
#' )
#' path <- tempfile(fileext = ".lock")
#' lock <- pr_lock_table(design, path)
#' lock$content
#'
#' # Locking is deterministic: the same table gives the same file.
#' path2 <- tempfile(fileext = ".lock")
#' pr_lock_table(design, path2)
#' identical(readLines(path), readLines(path2))
#'
#' unlink(c(path, path2))
pr_lock_table <- function(x, path, algo = "md5") {
  .pv_check_df(x)
  .pv_check_string(path, "path")
  if (!identical(algo, "md5")) {
    cli::cli_abort(c(
      "{.arg algo} must be {.val md5}, not {.val {algo}}.",
      i = "{.fn tools::md5sum} is the only hash in base R, and pressR takes
           no additional dependencies."
    ))
  }
  .pv_check_colnames(x)
  dir <- dirname(path)
  if (!dir.exists(dir)) {
    cli::cli_abort(c(
      "Directory {.file {dir}} does not exist.",
      i = "Create it before writing the lock file."
    ))
  }

  d <- .pv_describe(x)
  lines <- c(
    "# pressR table lock -- written by pr_lock_table(); do not hand-edit.",
    paste0("lock_version: ", .pv_lock_version),
    paste0("algo: ", algo),
    paste0("nrow: ", d$n_row),
    paste0("ncol: ", d$n_col),
    paste0("content: ", d$content),
    paste0("column: ", d$columns, "\t", d$types)
  )
  writeLines(lines, path)

  invisible(tibble::tibble(
    path = path,
    algo = algo,
    nrow = d$n_row,
    ncol = d$n_col,
    columns = list(d$columns),
    types = list(d$types),
    content = d$content
  ))
}

#' Verify a Table Against Its Lock File
#'
#' Re-derives the properties [pr_lock_table()] recorded and reports exactly
#' which of them changed: row count, column names, column types, or content.
#'
#' @details
#' The four properties are checked independently, so the report separates
#' failures that a shape check would conflate. A renamed column shows as
#' `columns` changed with `content` unchanged. A row filtered out shows as
#' `rows` changed. An `as.integer()` slipped into a pipeline shows as both
#' `types` and `content`, because the storage type is part of the hashed
#' byte stream. Same shape, same names, different numbers shows as `content`
#' alone — the case a `dim()` check misses entirely.
#'
#' This function never aborts and never warns on a mismatch: it returns the
#' verdict and prints the report, leaving the caller to decide. Wrap it in
#' [stopifnot()] to make a script fail, or add it as a rule to
#' [pr_validate_summary()]. Errors *are* raised for the caller's own
#' mistakes — a missing, malformed, or wrong-version lock file — because
#' those are not evidence that the data changed.
#'
#' @param x A data frame to check.
#' @param path Path to a lock file written by [pr_lock_table()].
#'
#' @return Invisibly, a single `TRUE`/`FALSE`. The result carries a
#'   `"report"` attribute: a four-row [tibble::tibble] with columns
#'   `property` (`"rows"`, `"columns"`, `"types"`, `"content"`), `expected`,
#'   `actual` and `passed`.
#' @family provenance functions
#' @seealso [pr_lock_table()] to write the lock file.
#' @export
#' @examples
#' design <- data.frame(
#'   ID = c("ID001", "ID001", "ID003"),
#'   Mode = c("MH", "MS", "MG"),
#'   n_frames = c(23432L, 10662L, 8000L)
#' )
#' path <- tempfile(fileext = ".lock")
#' pr_lock_table(design, path)
#'
#' pr_verify_lock(design, path)
#'
#' # One edited value: same shape, same names, different content.
#' edited <- design
#' edited$n_frames[1] <- 23431L
#' ok <- pr_verify_lock(edited, path)
#' ok
#' attr(ok, "report")
#'
#' unlink(path)
pr_verify_lock <- function(x, path) {
  .pv_check_df(x)
  .pv_check_string(path, "path")
  lock <- .pv_read_lock(path)
  .pv_check_colnames(x)
  now <- .pv_describe(x)

  report <- tibble::tibble(
    property = c("rows", "columns", "types", "content"),
    expected = c(
      as.character(lock$n_row), .pv_join(lock$columns),
      .pv_join(lock$types), lock$content
    ),
    actual = c(
      as.character(now$n_row), .pv_join(now$columns),
      .pv_join(now$types), now$content
    ),
    passed = c(
      identical(lock$n_row, now$n_row),
      identical(lock$columns, now$columns),
      identical(lock$types, now$types),
      identical(lock$content, now$content)
    )
  )
  ok <- all(report$passed)

  if (ok) {
    n_row <- now$n_row
    n_col <- now$n_col
    short <- substr(now$content, 1L, 8L)
    cli::cli_inform(c("v" = paste(
      "Lock verified: {.file {path}} matches {.arg x}",
      "({n_row} row{?s} x {n_col} column{?s}, md5 {.val {short}})."
    )))
    return(invisible(structure(TRUE, report = report)))
  }

  bullets <- c("x" = "Lock mismatch for {.file {path}}.")

  if (!report$passed[1]) {
    delta <- now$n_row - lock$n_row
    txt <- paste0("Rows: locked ", lock$n_row, ", now ", now$n_row,
                  " (", if (delta > 0) "+" else "", delta, ").")
    bullets <- c(bullets, stats::setNames(txt, "*"))
  }
  if (!report$passed[2]) {
    added <- setdiff(now$columns, lock$columns)
    removed <- setdiff(lock$columns, now$columns)
    if (length(added) > 0L) {
      bullets <- c(bullets, "*" = "Columns added: {.val {added}}.")
    }
    if (length(removed) > 0L) {
      bullets <- c(bullets, "*" = "Columns removed: {.val {removed}}.")
    }
    if (length(added) == 0L && length(removed) == 0L) {
      lock_cols <- lock$columns
      now_cols <- now$columns
      bullets <- c(bullets, "*" = paste(
        "Columns reordered: locked {.val {lock_cols}},",
        "now {.val {now_cols}}."
      ))
    }
  }
  if (!report$passed[3]) {
    both <- intersect(lock$columns, now$columns)
    lt <- lock$types[match(both, lock$columns)]
    nt <- now$types[match(both, now$columns)]
    chg <- both[lt != nt]
    if (length(chg) > 0L) {
      msg <- paste0(chg, ": ", lt[lt != nt], " -> ", nt[lt != nt])
      bullets <- c(bullets, "*" = "Type{?s} changed: {.val {msg}}.")
    } else {
      bullets <- c(bullets, "*" = "Column types changed.")
    }
  }
  if (!report$passed[4]) {
    same_shape <- report$passed[1] && report$passed[2] && report$passed[3]
    detail <- if (same_shape) {
      "same shape and names, different values"
    } else {
      "values differ"
    }
    txt <- paste0("Content: ", detail, " (md5 ",
                  substr(lock$content, 1L, 8L), " -> ",
                  substr(now$content, 1L, 8L), ").")
    bullets <- c(bullets, stats::setNames(txt, "*"))
  }
  unchanged <- report$property[report$passed]
  if (length(unchanged) > 0L) {
    bullets <- c(bullets, "i" = "Unchanged: {.field {unchanged}}.")
  }
  cli::cli_inform(bullets)

  invisible(structure(FALSE, report = report))
}

# Internal: evaluate one rule and reduce it to (passed, message).
.pv_run_rule <- function(fn, x, rule, level, call = rlang::caller_env()) {
  if (!is.function(fn)) {
    cli::cli_abort(
      c("Rule {.val {rule}} in {.arg {level}} is not a function.",
        x = "Got {.cls {class(fn)[1]}}."),
      call = call
    )
  }
  res <- tryCatch(fn(x), error = function(e) e)
  if (inherits(res, "error")) {
    return(list(
      passed = FALSE,
      message = paste0("rule errored: ", conditionMessage(res))
    ))
  }
  if (is.character(res)) {
    # Character contract: no strings means nothing to report, i.e. a pass.
    if (length(res) == 0L) {
      return(list(passed = TRUE, message = NA_character_))
    }
    return(list(passed = FALSE, message = paste(res, collapse = "; ")))
  }
  if (is.logical(res)) {
    if (length(res) == 0L) {
      return(list(passed = FALSE, message = "rule returned an empty logical"))
    }
    n_bad <- sum(!res | is.na(res))
    if (n_bad == 0L) {
      return(list(passed = TRUE, message = NA_character_))
    }
    msg <- if (length(res) == 1L) {
      if (is.na(res)) "rule returned NA" else "rule returned FALSE"
    } else {
      paste0(n_bad, " of ", length(res), " elements failed")
    }
    return(list(passed = FALSE, message = msg))
  }
  cli::cli_abort(
    c("Rule {.val {rule}} in {.arg {level}} returned {.cls {class(res)[1]}}.",
      i = "A rule must return a logical vector or a character vector of
           problems."),
    call = call
  )
}

# Internal: validate a named list of rules.
.pv_check_rules <- function(rules, arg, call = rlang::caller_env()) {
  if (is.function(rules)) rules <- list(rules)
  if (!is.list(rules)) {
    cli::cli_abort("{.arg {arg}} must be a named list of functions.",
                   call = call)
  }
  if (length(rules) == 0L) return(list())
  nms <- names(rules)
  if (is.null(nms) || anyNA(nms) || !all(nzchar(nms))) {
    cli::cli_abort(
      c("Every rule in {.arg {arg}} must be named.",
        i = "The name is what appears in the {.field rule} column."),
      call = call
    )
  }
  rules
}

#' Two-Tier Data Frame Validation
#'
#' Runs a set of named predicates over a data frame and returns them as a
#' tibble of results. Rules passed as `hard` abort on failure; rules passed
#' as `soft` warn. Everything is evaluated before anything is signalled, so
#' one failing rule never hides the others.
#'
#' @details
#' The two tiers encode a distinction most validation code loses: some
#' properties are structural (a duplicated key, a negative duration, an
#' unknown condition code) and make every downstream number wrong, while
#' others are worth knowing about but not worth stopping for (an unbalanced
#' cell, an unusually short recording). Collapsing both into [stopifnot()]
#' means either the pipeline halts for cosmetic reasons or the structural
#' checks get commented out.
#'
#' A rule is a function of the data frame returning either:
#'
#' * a logical vector — `TRUE` throughout passes; any `FALSE` or `NA` fails,
#'   and the message counts the failing elements. This lets a rule be
#'   written per row (`function(d) d$n_frames > 0`) or as a single claim
#'   (`function(d) anyDuplicated(d$ID) == 0L`).
#' * a character vector — an empty one passes, and any strings are taken as
#'   the problem description. Use this when the rule can say *what* is
#'   wrong, not merely that something is.
#'
#' A rule that throws is recorded as a failure carrying its error message
#' rather than propagated: a validation run should report on a broken rule,
#' not die inside it.
#'
#' @param x A data frame to validate.
#' @param hard Named list of predicates whose failure aborts. Default
#'   `list()`.
#' @param soft Named list of predicates whose failure warns. Default
#'   `list()`.
#' @param label Character. Name of the table, used in the warning and error
#'   headers. `NULL` (default) uses `"data"`.
#'
#' @return A [tibble::tibble] with one row per rule and columns `rule`,
#'   `level` (`"hard"` or `"soft"`), `passed` (logical) and `message`
#'   (`NA` for a passing rule), hard rules first. When a hard rule fails,
#'   aborts with condition class `pr_validate_failed`, carrying that same
#'   tibble in the condition's `results` field. Soft failures warn with
#'   condition class `pr_validate_soft_failed`.
#' @family provenance functions
#' @seealso [pr_validate_dataset()] for the trial-level homogeneity checks.
#' @export
#' @examples
#' design <- data.frame(
#'   ID = c("ID001", "ID001", "ID003"),
#'   Mode = c("MH", "MS", "MG"),
#'   n_frames = c(23432L, 10662L, 8000L)
#' )
#'
#' res <- pr_validate_summary(
#'   design,
#'   hard = list(
#'     positive_frames = function(d) d$n_frames > 0,
#'     mode_known = function(d) all(d$Mode %in% c("MG", "MH", "MS"))
#'   ),
#'   label = "design"
#' )
#' res
#'
#' # A soft rule warns and is still reported. The real cohort is unbalanced
#' # across Mode (92 / 169 / 170 recordings), which is worth knowing but is
#' # not a reason to stop.
#' unbalanced <- rbind(design, design[2, ])
#' res2 <- suppressWarnings(pr_validate_summary(
#'   unbalanced,
#'   soft = list(balanced = function(d) {
#'     tab <- table(d$Mode)
#'     if (length(unique(as.integer(tab))) == 1L) {
#'       character(0)
#'     } else {
#'       paste0("Mode counts differ: ",
#'              paste(names(tab), as.integer(tab), sep = "=",
#'                    collapse = ", "))
#'     }
#'   }),
#'   label = "design"
#' ))
#' res2$message
#'
#' # A hard failure aborts:
#' try(pr_validate_summary(
#'   design,
#'   hard = list(unique_id = function(d) anyDuplicated(d$ID) == 0L)
#' ))
pr_validate_summary <- function(x, hard = list(), soft = list(),
                                label = NULL) {
  .pv_check_df(x)
  hard <- .pv_check_rules(hard, "hard")
  soft <- .pv_check_rules(soft, "soft")
  if (is.null(label)) label <- "data"
  .pv_check_string(label, "label")

  dup <- intersect(names(hard), names(soft))
  if (length(dup) > 0L) {
    cli::cli_abort(c(
      "Rule name{?s} {.val {dup}} appear{?s/} in both {.arg hard} and
       {.arg soft}.",
      i = "Rule names are the key of the result table and must be unique."
    ))
  }

  rules <- c(hard, soft)
  levels <- c(rep("hard", length(hard)), rep("soft", length(soft)))
  n <- length(rules)

  if (n == 0L) {
    return(tibble::tibble(
      rule = character(0), level = character(0),
      passed = logical(0), message = character(0)
    ))
  }

  passed <- logical(n)
  message <- character(n)
  for (i in seq_len(n)) {
    r <- .pv_run_rule(rules[[i]], x, names(rules)[i], levels[i])
    passed[i] <- r$passed
    message[i] <- r$message
  }

  out <- tibble::tibble(
    rule = names(rules), level = levels,
    passed = passed, message = message
  )

  soft_bad <- out$level == "soft" & !out$passed
  hard_bad <- out$level == "hard" & !out$passed

  # Soft first, so the warnings are visible even when the abort follows.
  if (any(soft_bad)) {
    n_soft <- sum(soft_bad)
    detail <- paste0(out$rule[soft_bad], ": ", out$message[soft_bad])
    cli::cli_warn(
      c("{n_soft} soft validation rule{?s} failed for {.val {label}}.",
        stats::setNames(detail, rep("*", length(detail))),
        i = "Soft rules do not stop the pipeline; check them before
             reporting."),
      class = "pr_validate_soft_failed"
    )
  }
  if (any(hard_bad)) {
    n_hard <- sum(hard_bad)
    detail <- paste0(out$rule[hard_bad], ": ", out$message[hard_bad])
    cli::cli_abort(
      c("{n_hard} hard validation rule{?s} failed for {.val {label}}.",
        stats::setNames(detail, rep("x", length(detail))),
        i = "A hard rule guards a structural property; fix the data rather
             than the rule."),
      class = "pr_validate_failed",
      results = out, label = label
    )
  }

  out
}

# Internal: expected levels of one contracted column, as character.
.pv_expected_levels <- function(e, col, call = rlang::caller_env()) {
  if (is.factor(e)) e <- levels(e)
  if (!is.atomic(e) || length(e) == 0L) {
    cli::cli_abort(
      c("Expected levels for {.val {col}} must be a non-empty vector.",
        x = "Got {.cls {class(e)[1]}} of length {length(e)}."),
      call = call
    )
  }
  e <- as.character(e)
  e <- e[!is.na(e)]
  if (length(e) == 0L) {
    cli::cli_abort(
      "Expected levels for {.val {col}} are all {.code NA}.",
      call = call
    )
  }
  dup <- unique(e[duplicated(e)])
  if (length(dup) > 0L) {
    cli::cli_abort(
      "Expected levels for {.val {col}} repeat {.val {dup}}.",
      call = call
    )
  }
  e
}

# Internal: up to `max_n` id labels for the rows flagged by `hit`.
.pv_row_ids <- function(x, hit, id_cols, max_n = 5L) {
  if (length(id_cols) == 0L || !any(hit)) return(NA_character_)
  idx <- which(hit)
  keep <- utils::head(idx, max_n)
  lab <- do.call(paste, c(
    lapply(id_cols, function(k) as.character(x[[k]])[keep]),
    list(sep = "/")
  ))
  lab <- unique(lab)
  if (length(idx) > length(keep)) lab <- c(lab, "...")
  paste(lab, collapse = ", ")
}

#' Assert the Level Sets of Design Factors
#'
#' Checks that named columns of a data frame carry exactly the levels they
#' are contracted to carry — no unexpected value, no silently absent level,
#' and for `factor` columns the declared order as well. Aborts naming the
#' offending column, the offending values, and the rows they sit in.
#'
#' @details
#' This is the check that catches a typo'd condition code, a level lost to a
#' filter, and a `factor()` call whose `levels =` argument drifted out of
#' step with the data — all of which change a model's reference level or its
#' contrast matrix without changing anything visible in a `head()`.
#'
#' Both directions are enforced, because "exactly" is the point: a value in
#' the data that the contract does not list is an `unexpected_level`, and a
#' level in the contract that never appears in the data is a
#' `missing_level`. The second half is the one that matters after a subset —
#' a design that lost a whole condition still looks perfectly well formed.
#'
#' Order is enforced only where order exists. A `factor` column stores its
#' levels, so `levels(x[[col]])` must equal the contract element by element;
#' a mismatch in order alone is reported as `wrong_order`. A `character`
#' column has no stored order, so only its level *set* is contracted —
#' convert with `factor(x, levels = ...)` first if the order has to be
#' pinned.
#'
#' `NA` values are reported as `missing_value` unless `NA` appears in the
#' contract for that column, in which case they are accepted.
#'
#' @param x A data frame.
#' @param levels_list Named list. Each name is a column of `x`; each element
#'   is the vector of levels that column must carry, in order. A `factor`
#'   may be supplied instead, in which case its `levels()` are used. Include
#'   `NA` to permit missing values in that column.
#' @param id_cols Character vector of column names identifying a row, used
#'   to point at the offending rows in the error message (for example
#'   `"ID"`). `NULL` (default) reports values without row identifiers.
#'
#' @return Invisibly, `x` — so the contract can sit inside a pipeline. On
#'   violation, aborts with condition class `pr_factor_contract_failed`,
#'   carrying a `problems` [tibble::tibble] (columns `column`, `issue`,
#'   `value`, `n_rows`, `ids`) in the condition.
#' @family provenance functions
#' @seealso [pr_design_gaps()] for the combinations those levels do and do
#'   not form.
#' @export
#' @examples
#' design <- data.frame(
#'   ID = c("ID001", "ID001", "ID003", "ID003"),
#'   Mode = c("MG", "MH", "MS", "MH"),
#'   Saddle = c("K", "S", "W", "K")
#' )
#'
#' # Passes and returns the data invisibly:
#' out <- pr_factor_contract(
#'   design,
#'   list(Mode = c("MG", "MH", "MS"), Saddle = c("K", "S", "W")),
#'   id_cols = "ID"
#' )
#' identical(out, design)
#'
#' # A wrong contract fails loudly, naming the column and the values:
#' try(pr_factor_contract(design, list(Mode = c("MG", "MH"))))
pr_factor_contract <- function(x, levels_list, id_cols = NULL) {
  .pv_check_df(x)
  if (!is.list(levels_list) || length(levels_list) == 0L) {
    cli::cli_abort("{.arg levels_list} must be a non-empty named list.")
  }
  cols <- names(levels_list)
  if (is.null(cols) || anyNA(cols) || !all(nzchar(cols))) {
    cli::cli_abort(c(
      "Every element of {.arg levels_list} must be named.",
      i = "The name is the column of {.arg x} it contracts."
    ))
  }
  absent_cols <- setdiff(cols, names(x))
  if (length(absent_cols) > 0L) {
    cli::cli_abort(c(
      "Column{?s} {.val {absent_cols}} named by {.arg levels_list}
       {?is/are} not in {.arg x}.",
      i = "Available column{?s}: {.val {names(x)}}."
    ))
  }
  if (!is.null(id_cols)) {
    if (!is.character(id_cols) || anyNA(id_cols)) {
      cli::cli_abort(
        "{.arg id_cols} must be a character vector or {.code NULL}."
      )
    }
    unknown <- setdiff(id_cols, names(x))
    if (length(unknown) > 0L) {
      cli::cli_abort(c(
        "{.arg id_cols} names column{?s} {.val {unknown}} not in {.arg x}.",
        i = "Available column{?s}: {.val {names(x)}}."
      ))
    }
  }

  problems <- list()
  add <- function(column, issue, value, n_rows, ids) {
    problems[[length(problems) + 1L]] <<- tibble::tibble(
      column = column, issue = issue, value = value,
      n_rows = as.integer(n_rows), ids = ids
    )
  }

  for (col in cols) {
    expect <- .pv_expected_levels(levels_list[[col]], col)
    v <- x[[col]]
    is_fac <- is.factor(v)
    obs_chr <- as.character(v)
    na_hit <- is.na(obs_chr)
    na_allowed <- anyNA(levels_list[[col]])

    if (any(na_hit) && !na_allowed) {
      add(col, "missing_value", NA_character_, sum(na_hit),
          .pv_row_ids(x, na_hit, id_cols))
    }

    present <- unique(obs_chr[!na_hit])
    unexpected <- setdiff(present, expect)
    for (u in unexpected) {
      hit <- !na_hit & obs_chr == u
      add(col, "unexpected_level", u, sum(hit), .pv_row_ids(x, hit, id_cols))
    }

    # A factor declares its levels; a character column does not, so its
    # contract can only be judged against the values actually observed.
    declared <- if (is_fac) levels(v) else present
    lost <- setdiff(expect, declared)
    for (a in lost) {
      add(col, "missing_level", a, 0L, NA_character_)
    }

    if (is_fac) {
      # Levels declared but never used are still part of the contract.
      extra <- setdiff(declared, c(expect, unexpected))
      for (e in extra) {
        add(col, "unexpected_level", e, 0L, NA_character_)
      }
      same_set <- length(lost) == 0L &&
        length(setdiff(declared, expect)) == 0L
      if (same_set && !identical(declared, expect)) {
        add(col, "wrong_order", paste(declared, collapse = " < "),
            NA_integer_, NA_character_)
      }
    }
  }

  if (length(problems) == 0L) return(invisible(x))

  probs <- do.call(rbind, problems)
  n_col_bad <- length(unique(probs$column))
  bullets <- c(
    "Factor contract violated in {n_col_bad} column{?s}."
  )
  for (i in seq_len(nrow(probs))) {
    p <- probs[i, ]
    txt <- switch(
      p$issue,
      unexpected_level = paste0(
        p$column, ": unexpected level ", .pv_q(p$value),
        if (isTRUE(p$n_rows > 0L)) {
          paste0(" in ", p$n_rows, " row(s)")
        } else {
          " among the declared levels"
        },
        if (!is.na(p$ids)) paste0(" [", p$ids, "]") else "",
        "."
      ),
      missing_level = paste0(
        p$column, ": contracted level ", .pv_q(p$value),
        " never appears in the data."
      ),
      missing_value = paste0(
        p$column, ": ", p$n_rows, " missing value(s)",
        if (!is.na(p$ids)) paste0(" [", p$ids, "]") else "",
        "."
      ),
      wrong_order = paste0(
        p$column, ": levels are in the wrong order (", p$value, ")."
      ),
      paste0(p$column, ": ", p$issue, ".")
    )
    bullets <- c(bullets, stats::setNames(txt, "x"))
  }
  bullets <- c(bullets, i = "Fix the data or the contract deliberately: a
                             changed level set changes a model's reference
                             level and its contrasts.")
  cli::cli_abort(bullets, class = "pr_factor_contract_failed",
                 problems = probs)
}

# Internal: quote a value for a plain-text bullet. cli's inline markup is
# not used in the factor-contract bullets because the values are arbitrary
# data and could contain brace characters that glue would try to evaluate.
.pv_q <- function(v) {
  if (is.na(v)) "NA" else paste0("\"", v, "\"")
}

#' Observed Design Cells Against the Full Crossing
#'
#' Crosses the levels of the named factors, counts how many rows fall in
#' each cell, and labels every cell of the crossing as missing,
#' under-represented, balanced, or over-represented. This is what surfaces a
#' nesting or aliasing problem before anything is modelled.
#'
#' @details
#' A design described as "all saddles crossed with all pads" can turn out to
#' be nothing of the sort: one pad may only ever have been used with one
#' saddle, in which case the two factors are aliased and their effects are
#' not separately estimable — a fact no model summary will state out loud.
#' Counting the cells of the full crossing shows it immediately: a factor
#' nested inside another leaves whole blocks of the crossing at `n == 0`.
#'
#' Levels come from `levels()` for a factor column and from the sorted
#' unique non-`NA` values otherwise. Sorting uses `method = "radix"`, which
#' forces C-locale collation, so the row order of the result does not depend
#' on the machine's locale. The crossing is generated by
#' [tidyr::expand_grid()], so the first factor varies slowest and the row
#' order is the natural nesting order.
#'
#' `expected` sets the replicate count a balanced cell should hold. Left
#' `NULL`, it is the most common non-zero cell count — the design's own idea
#' of a full cell — with ties broken towards the larger count, so a tie errs
#' towards reporting cells as under-represented rather than as balanced.
#'
#' Rows with `NA` in any crossing factor cannot be placed in a cell. They
#' are dropped and a warning names how many, because dropping them silently
#' would understate the gaps.
#'
#' @param x A data frame.
#' @param factors Character vector of column names to cross, in the order
#'   they should nest.
#' @param expected Single non-negative whole number: the replicate count a
#'   complete cell should hold. `NULL` (default) uses the modal non-zero
#'   observed count.
#'
#' @return A [tibble::tibble] with one row per cell of the full crossing:
#'   the factor columns (as character), then `n` (rows observed),
#'   `expected`, `delta` (`n - expected`) and `status`, one of `"missing"`
#'   (`n == 0`), `"under"`, `"ok"` or `"over"`.
#' @family provenance functions
#' @seealso [pr_factor_contract()] for the level sets being crossed,
#'   [pr_design_table()] for building `x` from a [pr_dataset].
#' @export
#' @examples
#' design <- data.frame(
#'   Saddle = c("K", "K", "K", "S", "S", "W"),
#'   Pad = c("F", "K", "K", "F", "F", "W")
#' )
#' gaps <- pr_design_gaps(design, c("Saddle", "Pad"))
#' gaps
#'
#' # Pad is nested within Saddle, not crossed with it:
#' sum(gaps$status == "missing")
#'
#' # With an explicit replicate expectation:
#' pr_design_gaps(design, c("Saddle", "Pad"), expected = 2)
pr_design_gaps <- function(x, factors, expected = NULL) {
  .pv_check_df(x)
  if (!is.character(factors) || length(factors) == 0L || anyNA(factors)) {
    cli::cli_abort(
      "{.arg factors} must be a non-empty character vector of column names."
    )
  }
  dup <- unique(factors[duplicated(factors)])
  if (length(dup) > 0L) {
    cli::cli_abort("{.arg factors} repeats {.val {dup}}.")
  }
  unknown <- setdiff(factors, names(x))
  if (length(unknown) > 0L) {
    cli::cli_abort(c(
      "{.arg factors} names column{?s} {.val {unknown}} not in {.arg x}.",
      i = "Available column{?s}: {.val {names(x)}}."
    ))
  }
  if (!is.null(expected)) {
    if (!is.numeric(expected) || length(expected) != 1L || is.na(expected) ||
        expected < 0 || expected != trunc(expected)) {
      cli::cli_abort(
        "{.arg expected} must be a single non-negative whole number or
         {.code NULL}, not {.val {expected}}."
      )
    }
    expected <- as.integer(expected)
  }

  chr <- lapply(factors, function(f) as.character(x[[f]]))
  names(chr) <- factors
  keep <- Reduce(`&`, lapply(chr, function(v) !is.na(v)))
  if (is.null(keep)) keep <- logical(0)
  n_drop <- sum(!keep)
  if (n_drop > 0L) {
    cli::cli_warn(c(
      "{n_drop} row{?s} {?has/have} a missing value in {.arg factors} and
       cannot be placed in a design cell.",
      i = "They are dropped from the counts below."
    ))
    chr <- lapply(chr, function(v) v[keep])
  }

  levs <- lapply(factors, function(f) {
    v <- x[[f]]
    if (is.factor(v)) {
      levels(v)
    } else {
      u <- unique(as.character(v))
      sort(u[!is.na(u)], method = "radix")
    }
  })
  names(levs) <- factors
  empty <- names(levs)[lengths(levs) == 0L]
  if (length(empty) > 0L) {
    cli::cli_abort(
      "Factor{?s} {.val {empty}} {?has/have} no levels; the crossing is
       empty."
    )
  }

  full <- tidyr::expand_grid(!!!levs)

  # Cells are keyed by a control-character join rather than by a data frame
  # merge: it keeps the crossing order exactly as expand_grid() produced it
  # and needs no join-column type negotiation. The ASCII unit separator
  # cannot occur in a level read from a text file.
  sep <- "\x1f"
  key_full <- do.call(paste, c(as.list(full), list(sep = sep)))
  key_obs <- if (length(chr[[1]]) == 0L) {
    character(0)
  } else {
    do.call(paste, c(chr, list(sep = sep)))
  }
  n <- tabulate(match(key_obs, key_full), nbins = length(key_full))

  if (is.null(expected)) {
    nz <- n[n > 0L]
    expected <- if (length(nz) == 0L) {
      0L
    } else {
      tab <- table(nz)
      counts <- as.integer(names(tab))
      # Ties broken towards the larger count: sort the distinct counts
      # descending, then take the first maximum. The larger reference
      # flags the thinner cells as under-represented, which is the
      # direction an integrity check should err in.
      ord <- order(counts, decreasing = TRUE)
      counts[ord][which.max(as.integer(tab)[ord])]
    }
  }

  n <- as.integer(n)
  expected <- as.integer(expected)
  status <- ifelse(
    n == 0L, "missing",
    ifelse(n < expected, "under", ifelse(n > expected, "over", "ok"))
  )

  out <- full
  out$n <- n
  out$expected <- expected
  out$delta <- n - expected
  out$status <- status
  out
}
