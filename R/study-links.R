#' Link Study Assets Using Explicit Acquisition Keys
#'
#' Identifiers are never inferred from matching bytes or nearby timestamps.
#' Duplicate content retains separate identities and is flagged for review.
#' A recording must be unique on the supplied keys; multiple assets require
#' an explicit one-to-many relationship. Missing keys are always rejected.
#' @param recordings Data frame with recording_id and the acquisition keys.
#' @param assets Data frame with asset_id and the same keys. Optional sha256
#'   values are used only to flag duplicate content, never to assign identity.
#' @param by Non-empty character vector of shared key column names.
#' @param relationship Either one-to-one (default) or one-to-many.
#' @param allow_unmatched Keep unmatched assets with a status flag.
#' @return One row per asset, with recording_id, asset_id, acquisition keys,
#'   link_status and duplicate_content. Unused recording IDs are an attribute.
#' @export
#' @examples
#' recordings <- data.frame(
#'   recording_id = c("R1", "R2"),
#'   subject = c("S01", "S02"),
#'   session = c(1, 1)
#' )
#' assets <- data.frame(
#'   asset_id = c("A1", "A2"),
#'   subject = c("S02", "S01"),
#'   session = c(1, 1)
#' )
#' pr_link_assets(recordings, assets, by = c("subject", "session"))
pr_link_assets <- function(recordings, assets, by, relationship = c("one-to-one", "one-to-many"), allow_unmatched = FALSE) {
  relationship <- match.arg(relationship)
  .tp_check_flag(allow_unmatched, "allow_unmatched")
  if (!is.data.frame(recordings) || !is.data.frame(assets) || !is.character(by) ||
    !length(by) || anyNA(by) || anyDuplicated(by) || any(!nzchar(by)) ||
    any(by %in% c("recording_id", "asset_id"))) {
    cli::cli_abort("Supply explicit acquisition keys and two data frames.")
  }
  validate <- function(d, id) {
    if (!all(c(id, by) %in% names(d))) cli::cli_abort("Required identity or key columns are missing.")
    if (anyNA(d[[id]]) || any(!nzchar(as.character(d[[id]]))) || anyDuplicated(d[[id]])) cli::cli_abort("Source identities must be nonmissing and unique.")
    values <- lapply(d[by], as.character)
    if (any(vapply(values, function(x) anyNA(x) || any(!nzchar(trimws(x))), logical(1)))) cli::cli_abort("Acquisition keys must be complete.")
    vapply(seq_len(nrow(d)), function(i) jsonlite::toJSON(lapply(values, `[`, i), auto_unbox = TRUE), character(1))
  }
  rk <- validate(recordings, "recording_id")
  ak <- validate(assets, "asset_id")
  if (anyDuplicated(rk) || (relationship == "one-to-one" && anyDuplicated(ak))) cli::cli_abort("Ambiguous acquisition keys for the declared relationship.")
  ix <- match(ak, rk)
  if (anyNA(ix) && !allow_unmatched) cli::cli_abort("Some assets have no matching recording; resolve keys or explicitly allow unmatched assets.")
  out <- tibble::as_tibble(assets[c("asset_id", by)])
  out$recording_id <- as.character(recordings$recording_id[ix])
  out$link_status <- ifelse(is.na(ix), "unmatched", "matched_explicit_keys")
  hash <- assets$sha256
  out$duplicate_content <- if (is.null(hash)) {
    rep(FALSE, nrow(out))
  } else {
    !is.na(hash) & nzchar(hash) & (duplicated(hash) | duplicated(hash, fromLast = TRUE))
  }
  attr(out, "unused_recording_ids") <- recordings$recording_id[!seq_len(nrow(recordings)) %in% ix]
  out
}
