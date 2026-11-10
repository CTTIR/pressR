#' Saddle Pressure Reference Observations
#'
#' Source-specific observations, not universal diagnostic cut-offs. The six
#' values formerly attributed to von Peinen are from Nyikos (2005), abstract,
#' p.187: 26 horses measured at trot with six bilateral Novel saddle masks.
#' Unverified legacy entries have withdrawn numeric thresholds (NA).
#' No reference is enabled automatically in reports.
#' @param source Reference identifier. Default 'nyikos2005'.
#' @return A tibble with region, parameter, threshold, unit, interpretation,
#'   source, source_url, status, species, gait and region_scheme.
#' @export
#' @examples
#' pr_ref_saddle()
#' # Withdrawn legacy entries carry no numeric threshold:
#' pr_ref_saddle("werner2002")$threshold
pr_ref_saddle <- function(source = c("nyikos2005", "vonpeinen2010", "monkemoller2005", "werner2002")) {
  source <- match.arg(source)
  if (source == "nyikos2005") {
    return(tibble::tibble(
      region = rep(c("cranial", "middle", "caudal"), 2),
      parameter = rep(c("mpp", "mvp"), each = 3), threshold = c(34.5, 30.3, 31, 13.2, 11.4, 10), unit = "kPa",
      interpretation = "Association observed in 26 horses at trot; not a validated diagnostic rule.",
      source = "Nyikos et al. (2005), Pferdeheilkunde 21:187-198, abstract p.187.",
      source_url = "https://pferdeheilkunde.de/files/20050301.pdf", status = "verified_source",
      species = "equine", gait = "trot", region_scheme = "nyikos_six_masks"
    ))
  }
  source_id <- source
  n <- if (source == "vonpeinen2010") 6L else 3L
  tibble::tibble(
    region = rep(c("cranial", "middle", "caudal"), length.out = n),
    parameter = if (n == 6L) rep(c("mpp", "mvp"), each = 3) else if (source == "werner2002") "mpp" else "mvp",
    threshold = NA_real_, unit = "kPa",
    interpretation = if (source == "vonpeinen2010") "Withdrawn attribution: use Nyikos 2005 for the six source observations." else "Withdrawn: legacy region-specific values are not verified against an exact source table.",
    source = switch(source,
      vonpeinen2010 = "von Peinen et al. (2010), Equine Veterinary Journal.",
      monkemoller2005 = "Moenkemoeller et al. (2005), Pferdeheilkunde.",
      werner2002 = "Werner et al. (2002), Pferdeheilkunde 18:125-140."
    ),
    source_url = switch(source_id,
      vonpeinen2010 = "https://doi.org/10.1111/j.2042-3306.2010.00191.x",
      monkemoller2005 = NA_character_,
      werner2002 = "https://pferdeheilkunde.de/files/20020201.pdf"
    ),
    status = "withdrawn", species = "equine", gait = NA_character_, region_scheme = NA_character_
  )
}

#' Traceable Plantar Pressure Reference Observations
#'
#' Armstrong's 1998 case-control study reported a 70 N/cm2 (700 kPa)
#' forefoot cut-point with limited discrimination using EMED measurements.
#' Other previously supplied values are withdrawn pending exact provenance.
#' @return Reference table; only verified_source rows have usable values.
#' @export
#' @examples
#' ref <- pr_ref_diabetic_foot()
#' ref[ref$status == "verified_source", c("region", "parameter", "threshold", "unit")]
pr_ref_diabetic_foot <- function() {
  tibble::tibble(
    region = c("forefoot", "any plantar", "forefoot", "heel"),
    parameter = c("mpp", "pti_mean", "mpp", "mpp"), threshold = c(700, NA_real_, NA_real_, NA_real_),
    unit = c("kPa", "kPa*s", "kPa", "kPa"),
    interpretation = c("Case-control ROC observation; sensitivity 70%, specificity 65.1%; not a universal clinical cut-off.", rep("Withdrawn: exact legacy value attribution has not been verified.", 3)),
    source = c("Armstrong et al. (1998), J Foot Ankle Surg 37:303-307.", "Caselli et al. (2002), Diabetes Care.", "Veves et al. (1992), Diabetologia.", "Frykberg et al. (1998), Diabetes Care."),
    source_url = c("https://pubmed.ncbi.nlm.nih.gov/9710782/", rep(NA_character_, 3)),
    status = c("verified_source", rep("withdrawn", 3)), species = "human", gait = "walking", region_scheme = "EMED_forefoot"
  )
}

#' Status of Legacy Seating Reference Values
#' @return A reference table with withdrawn numeric values. Physiological
#'   capillary observations do not establish universal seat-interface limits.
#' @export
#' @examples
#' pr_ref_wheelchair()
pr_ref_wheelchair <- function() {
  tibble::tibble(
    region = c("ischial", "ischial", "any"), parameter = c("mpp", "mean_pressure", "mpp"),
    threshold = NA_real_, unit = "mmHg", interpretation = "Withdrawn: no validated universal seat-interface threshold is established by the cited legacy entry.",
    source = c("Sprigle and Sonenblum (2011).", "Landis (1930).", "Stinson et al. (2003)."),
    source_url = NA_character_, status = "withdrawn", species = "human", gait = "seated", region_scheme = NA_character_
  )
}
