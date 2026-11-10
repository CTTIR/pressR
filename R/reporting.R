#' Summarize Measurements With Explicit Units and Availability
#' @param trial A [pr_trial] object.
#' @return A long table with parameter, value, unit and status.
#' @export
#' @examples
#' pr_summary_long(pr_example_trial("insole"))
pr_summary_long <- function(trial) {
  s <- pr_summary(trial)
  values <- as.numeric(s[1, ])
  tibble::tibble(
    parameter = names(s), value = values, unit = unname(attr(s, "units")),
    status = ifelse(is.finite(values), "available", "unavailable: calibration or measurements missing")
  )
}

#' Report Source and Analysis Provenance
#' @param trial A [pr_trial] object.
#' @return A field/value tibble suitable for reports.
#' @export
#' @examples
#' pr_report_info(pr_example_trial("insole"))
pr_report_info <- function(trial) {
  .validate_trial(trial)
  md <- trial$metadata
  fields <- c(
    package_version = as.character(utils::packageVersion("pressR")),
    recording = .report_field(md, "source_filename", .report_field(md, "trial_id")),
    source_sha256 = .report_field(md, "source_sha256"),
    frames = as.character(trial$n_frames), sampling_hz = as.character(trial$sampling_hz),
    measurement_unit = .measurement_unit(trial), coordinate_unit = .coordinate_unit(trial$layout),
    sensor_area_cm2 = if (is.finite(trial$layout$sensor_area_cm2)) as.character(trial$layout$sensor_area_cm2) else "unknown",
    temporal_profile = .report_field(md, "analysis_profile", "not applied"),
    missing_frames_removed = .report_field(md, "n_frames_dropped", "0"),
    negative_observations = .report_field(md, "negative_values", "0")
  )
  tibble::tibble(field = names(fields), value = unname(fields))
}

.report_field <- function(metadata, name, default = "not recorded") {
  value <- metadata[[name, exact = TRUE]]
  if (is.null(value) || length(value) != 1L || !is.atomic(value) || is.na(value)) {
    return(default)
  }
  value <- as.character(value)
  if (nzchar(value)) value else default
}

# Explicit output formats keep recording names and region labels as text.
# Markdown tables otherwise interpret embedded links, HTML and TeX syntax.
.report_table <- function(x, ...) {
  if (knitr::is_html_output()) {
    previous <- options(htmltools.preserve.raw = FALSE)
    on.exit(options(previous), add = TRUE)
    knitr::asis_output(htmltools::htmlPreserve(
      knitr::kable(x, format = "html", escape = TRUE, ...)
    ))
  } else if (knitr::is_latex_output()) {
    knitr::kable(x, format = "latex", escape = TRUE, longtable = TRUE, ...)
  } else {
    knitr::kable(x, escape = TRUE, ...)
  }
}

.report_regional_table <- function(trial, masks = NULL) {
  x <- pr_calc_regional(trial, masks)
  u <- attr(x, "units")
  names(x)[-1L] <- paste0(names(x)[-1L], " (", unname(u), ")")
  x
}
