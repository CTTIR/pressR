.require_optional <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) cli::cli_abort("Install {.pkg {package}} to use this importer.")
}

#' Inventory Study Source Files Without Changing Them
#' @param path Source directory.
#' @param hash Compute SHA-256 content identifiers (default TRUE).
#' @return A tibble with paths, sizes, roles, hashes and duplicate flags.
#' @export
#' @examples
#' src <- tempfile("pressr-study-")
#' dir.create(src)
#' writeLines(c("time,s1", "0,1"), file.path(src, "trial.csv"))
#' writeLines("Trial notes", file.path(src, "notes.txt"))
#' pr_inventory(src)
#' unlink(src, recursive = TRUE)
pr_inventory <- function(path, hash = TRUE) {
  if (!dir.exists(path)) cli::cli_abort("Source directory does not exist.")
  .tp_check_flag(hash, "hash")
  files <- sort(list.files(path, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE))
  files <- files[!file.info(files)$isdir]
  ext <- tolower(tools::file_ext(files))
  role <- ifelse(ext %in% c("asc", "csv", "txt"), "measurement_candidate",
    ifelse(ext %in% c("xls", "xlsx"), "workbook",
      ifelse(ext %in% c("jpg", "jpeg", "png", "tif", "tiff"), "image",
        ifelse(ext %in% c("7z", "zip", "tar", "gz"), "archive",
          ifelse(ext %in% c("rds", "rda", "rdata"), "reference_object", "attachment")
        )
      )
    )
  )
  role[startsWith(basename(files), "._") | basename(files) == ".DS_Store"] <- "metadata_sidecar"
  hashes <- if (hash) vapply(files, digest::digest, character(1), algo = "sha256", file = TRUE) else rep(NA_character_, length(files))
  relative <- substring(files, nchar(sub("/$", "", path)) + 2L)
  tibble::tibble(
    path = files, relative_path = relative,
    bytes = unname(file.info(files)$size), role = role, sha256 = unname(hashes),
    duplicate_content = !is.na(hashes) & (duplicated(hashes) | duplicated(hashes, fromLast = TRUE))
  )
}

.asset_time <- function(x, numeric_time_unit) {
  out <- rep(NA_real_, length(x))
  clock <- grepl("^[0-9]+:[0-9]{2}:[0-9]{2}([.][0-9]+)?$", x) & !is.na(x)
  out[clock] <- vapply(strsplit(x[clock], ":", fixed = TRUE), function(z) {
    z <- as.numeric(z)
    if (z[2] >= 60 || z[3] >= 60) NA_real_ else sum(z * c(3600, 60, 1))
  }, numeric(1))
  if (!is.null(numeric_time_unit)) {
    scale <- switch(numeric_time_unit,
      seconds = 1,
      excel_days = 86400,
      cli::cli_abort("numeric_time_unit must be NULL, 'seconds' or 'excel_days'.")
    )
    out[!clock] <- suppressWarnings(as.numeric(x[!clock])) * scale
  }
  out
}

#' Import a Study Workbook and Its HR/RR Series
#'
#' Keeps every sheet as source cells and records row numbers for normalized
#' observations. Recognizes Polar-style HR headers, including headers below
#' session metadata, and duration/offline RR exports. Unknown sheets remain
#' available as attachments. No observations are silently removed or aligned.
#' @param path Excel workbook path.
#' @param numeric_time_unit NULL by default: ambiguous numeric times remain
#'   unavailable. Set 'seconds' or 'excel_days' only with source evidence.
#' @return A list with sheets, heart_rate, rr_intervals and a sheet manifest.
#' @export
#' @examplesIf requireNamespace("readxl", quietly = TRUE) && requireNamespace("writexl", quietly = TRUE)
#' hr <- data.frame(Time = c("00:00:01", "00:00:02", "00:00:03"), HR = c(92, 95, 97))
#' names(hr)[2] <- "HR (bpm)"
#' path <- tempfile(fileext = ".xlsx")
#' writexl::write_xlsx(list(session = hr), path)
#' workbook <- pr_read_workbook(path)
#' workbook$manifest
#' workbook$heart_rate[c("time_s", "hr_bpm")]
#' unlink(path)
pr_read_workbook <- function(path, numeric_time_unit = NULL) {
  .require_optional("readxl")
  if (!file.exists(path)) cli::cli_abort("Workbook does not exist.")
  sheet_names <- readxl::excel_sheets(path)
  sheets <- hr <- rr <- manifest <- list()
  for (sn in sheet_names) {
    d <- readxl::read_excel(path,
      sheet = sn, col_names = FALSE, col_types = "text",
      range = readxl::cell_limits(c(1, 1), c(NA, NA)),
      trim_ws = FALSE, .name_repair = "minimal"
    )
    names(d) <- paste0("column_", seq_len(ncol(d)))
    sheets[[sn]] <- d
    h <- if (nrow(d)) as.matrix(d[seq_len(min(30L, nrow(d))), , drop = FALSE]) else matrix(character(), 0, 0)
    type <- "attachment"
    header <- NA_integer_
    for (i in seq_len(nrow(h))) {
      nms <- tolower(trimws(h[i, ]))
      nms[is.na(nms)] <- ""
      if (any(grepl("^hr.*bpm|^herzfrequenz.*bpm", nms))) {
        type <- "heart_rate"
        header <- i
        break
      }
      if (any(grepl("^duration$|^rr.*ms", nms)) && any(nms == "offline")) {
        type <- "rr_intervals"
        header <- i
        break
      }
    }
    if (!is.na(header) && header < nrow(d)) {
      rows <- seq.int(header + 1L, nrow(d))
      nms <- tolower(trimws(as.character(d[header, ])))
      measurement <- if (type == "heart_rate") "^hr.*bpm|^herzfrequenz.*bpm" else "^duration$|^rr.*ms"
      columns <- which(grepl(measurement, nms))
      # A sheet may contain several side-by-side exports. Keep each series
      # with its source column instead of silently choosing or merging one.
      for (k in seq_along(columns)) {
        column <- columns[k]
        left <- if (k == 1L) 1L else columns[k - 1L] + 1L
        right <- if (k == length(columns)) ncol(d) else columns[k + 1L] - 1L
        pull <- function(pattern, side = c("any", "before", "after")) {
          side <- match.arg(side)
          ix <- which(grepl(pattern, nms))
          ix <- ix[ix >= left & ix <= right]
          if (side == "before") ix <- ix[ix < column]
          if (side == "after") ix <- ix[ix > column]
          if (length(ix) > 1L) ix <- ix[which.min(abs(ix - column))]
          if (!length(ix)) {
            return(rep(NA_character_, length(rows)))
          }
          as.character(d[[ix]][rows])
        }
        base <- tibble::tibble(
          source_sheet = sn, source_row = rows, source_column = column,
          series_id = paste(sn, column, sep = ":"),
          session_id = tools::file_path_sans_ext(basename(path))
        )
        if (type == "heart_rate") {
          base$time_raw <- pull("^time$|^zeit", "before")
          base$time_s <- .asset_time(trimws(base$time_raw), numeric_time_unit)
          base$hr_bpm <- suppressWarnings(as.numeric(d[[column]][rows]))
          base$speed_kmh <- suppressWarnings(as.numeric(pull("^speed|^geschwindigkeit", "after")))
          base$valid_measurement <- is.finite(base$hr_bpm) & base$hr_bpm > 0
          hr[[length(hr) + 1L]] <- base
        } else {
          base$rr_ms <- suppressWarnings(as.numeric(d[[column]][rows]))
          off <- toupper(trimws(pull("^offline$")))
          base$offline <- ifelse(off %in% c("TRUE", "1"), TRUE, ifelse(off %in% c("FALSE", "0"), FALSE, NA))
          base$valid_measurement <- is.finite(base$rr_ms) & base$rr_ms > 0
          rr[[length(rr) + 1L]] <- base
        }
      }
    }
    manifest[[sn]] <- tibble::tibble(sheet = sn, role = type, source_rows = nrow(d), source_columns = ncol(d), header_row = header)
  }
  empty <- tibble::tibble(
    source_sheet = character(), source_row = integer(), source_column = integer(),
    series_id = character(), session_id = character(), valid_measurement = logical()
  )
  if (!length(hr)) hr <- list(tibble::add_column(empty, time_raw = character(), time_s = double(), hr_bpm = double(), speed_kmh = double()))
  if (!length(rr)) rr <- list(tibble::add_column(empty, rr_ms = double(), offline = logical()))
  list(
    source = normalizePath(path), sha256 = digest::digest(path, algo = "sha256", file = TRUE),
    sheets = sheets, heart_rate = dplyr::bind_rows(hr), rr_intervals = dplyr::bind_rows(rr),
    manifest = dplyr::bind_rows(manifest), numeric_time_unit = numeric_time_unit
  )
}

#' Register an Image or Other Study Attachment
#'
#' Reads embedded metadata when ExifTool is installed. Radiometric payload and
#' calibration presence are reported separately; display colours are never
#' interpreted as temperatures. No source files are written.
#' @param path Source file.
#' @param exiftool ExifTool executable, or an empty string for basic registration.
#' @return Source identity, embedded metadata and calibration availability.
#' @export
#' @examples
#' path <- tempfile(fileext = ".txt")
#' writeLines("Session protocol", path)
#' # An empty `exiftool` registers the file without reading embedded metadata.
#' asset <- pr_read_asset(path, exiftool = "")
#' asset$metadata_status
#' asset$temperature_status
#' unlink(path)
pr_read_asset <- function(path, exiftool = Sys.which("exiftool")) {
  if (!file.exists(path) || dir.exists(path)) cli::cli_abort("Asset must be an existing file.")
  metadata <- list()
  status <- "metadata_tool_unavailable"
  if (length(exiftool) == 1L && nzchar(exiftool)) {
    err <- tempfile()
    on.exit(unlink(err), add = TRUE)
    txt <- system2(exiftool, c("-json", "-n", shQuote(normalizePath(path))), stdout = TRUE, stderr = err)
    if (!is.null(attr(txt, "status"))) cli::cli_abort("ExifTool could not read asset metadata.")
    metadata <- jsonlite::fromJSON(paste(txt, collapse = "\n"), simplifyVector = FALSE)[[1L]]
    status <- "read"
  }
  payload <- all(c("RawThermalImageWidth", "RawThermalImageHeight") %in% names(metadata))
  calibration <- all(c("PlanckR1", "PlanckR2", "PlanckB", "PlanckF", "PlanckO") %in% names(metadata))
  list(
    source = normalizePath(path), bytes = unname(file.info(path)$size),
    sha256 = digest::digest(path, algo = "sha256", file = TRUE), metadata_status = status,
    metadata = metadata, radiometric_payload = payload, calibration_present = calibration,
    temperature_status = if (payload && calibration) "requires_environment_and_radiometric_decoder" else "unavailable"
  )
}

#' List a Study Archive
#' @param path Archive path supported by libarchive, including 7z.
#' @return A tibble containing archive member names, sizes and dates.
#' @export
#' @examplesIf requireNamespace("archive", quietly = TRUE)
#' src <- tempfile("pressr-src-")
#' dir.create(src)
#' writeLines(c("time,s1", "0,1", "0.02,3"), file.path(src, "trial.csv"))
#' zip <- tempfile(fileext = ".zip")
#' archive::archive_write_dir(zip, src)
#' pr_list_archive(zip)
#' unlink(c(src, zip), recursive = TRUE)
pr_list_archive <- function(path) {
  .require_optional("archive")
  archive::archive(path)
}

#' Extract Selected Archive Members Without Overwriting Files
#' @param path Archive path.
#' @param members Character vector of exact member names to extract.
#' @param destination A new directory; existing destinations are rejected.
#' @param max_bytes Maximum total uncompressed bytes, default 1 GiB.
#' @details Selected names must be portable relative file paths. Traversal,
#' Windows device names and stream syntax, control characters and trailing
#' spaces or periods are refused. Aliases cannot overwrite an earlier member.
#' @return An inventory of extracted files with computed SHA-256 identifiers.
#' @export
#' @examplesIf requireNamespace("archive", quietly = TRUE)
#' src <- tempfile("pressr-src-")
#' dir.create(src)
#' writeLines(c("time,s1", "0,1", "0.02,3"), file.path(src, "trial.csv"))
#' zip <- tempfile(fileext = ".zip")
#' archive::archive_write_dir(zip, src)
#' dest <- tempfile("pressr-extract-")
#' pr_extract_archive(zip, members = "trial.csv", destination = dest)
#' unlink(c(src, dest, zip), recursive = TRUE)
pr_extract_archive <- function(path, members, destination, max_bytes = 1024^3) {
  listing <- pr_list_archive(path)
  if (!is.character(members) || !length(members) || anyNA(members) ||
    any(!nzchar(members)) || anyDuplicated(members)) cli::cli_abort("Select unique archive member names explicitly.")
  if (any(grepl("(^/|^[A-Za-z]:|(^|[/\\\\])[.][.]([/\\\\]|$)|\\\\)", members))) cli::cli_abort("Unsafe archive member path.")
  parts <- unlist(strsplit(members, "/", fixed = TRUE), use.names = FALSE)
  parts <- parts[nzchar(parts) & parts != "."]
  devices <- "^(CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3])([.]|$)"
  if (any(grepl('[[:cntrl:]<>:"|?*]', members)) ||
    any(grepl("[ .]$", parts)) || any(grepl(devices, parts, ignore.case = TRUE))) {
    cli::cli_abort("Unsafe archive member name: use portable file paths without device or stream syntax.")
  }
  ix <- match(members, listing$path)
  if (anyNA(ix) || anyDuplicated(listing$path[listing$path %in% members])) cli::cli_abort("Archive member is missing or ambiguous.")
  normalized <- vapply(strsplit(members, "/", fixed = TRUE), function(parts) {
    paste(parts[nzchar(parts) & parts != "."], collapse = "/")
  }, character(1))
  if (any(!nzchar(normalized)) || anyDuplicated(normalized)) {
    cli::cli_abort("Archive member paths alias the same destination.")
  }
  .tp_check_scalar(max_bytes, "max_bytes")
  if (max_bytes < 0 || anyNA(listing$size[ix]) || any(!is.finite(listing$size[ix])) ||
    any(listing$size[ix] < 0) || sum(listing$size[ix]) > max_bytes) cli::cli_abort("Archive extraction exceeds its size budget.")
  if (file.exists(destination)) cli::cli_abort("Extraction destination must be new.")
  if (.is_output_link(destination)) cli::cli_abort("Extraction destination must not be a symbolic link.")
  if (!dir.exists(dirname(destination))) cli::cli_abort("Extraction parent directory does not exist.")
  stage <- tempfile(".pressr-archive-", tmpdir = dirname(destination))
  if (!dir.create(stage)) cli::cli_abort("Could not create extraction staging directory.")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (j in seq_along(members)) {
    target <- file.path(stage, members[j])
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (file.exists(target) || .is_output_link(target)) {
      cli::cli_abort("Archive member paths alias the same destination.")
    }
    input <- archive::archive_read(path, file = members[j], mode = "rb")
    output <- NULL
    written <- 0
    tryCatch({
      open(input, "rb")
      output <- file(target, "wb")
      repeat {
        bytes <- readBin(input, "raw", n = 1024^2)
        if (!length(bytes)) break
        written <- written + length(bytes)
        if (written > listing$size[ix[j]]) cli::cli_abort("Archive member exceeds its declared size.")
        writeBin(bytes, output)
      }
    }, finally = {
      if (isOpen(input)) close(input)
      if (!is.null(output)) close(output)
    })
    if (written != listing$size[ix[j]]) cli::cli_abort("Incomplete archive member.")
  }
  .validate_output_path(destination, new = TRUE)
  if (!.rename_output(stage, destination)) cli::cli_abort("Could not finalize extraction.")
  pr_inventory(destination)
}
