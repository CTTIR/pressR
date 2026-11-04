test_that("version 2 bundles retain exact measurement and reference identities", {
  root <- withr::local_tempdir()
  layout <- pr_layout_from_index_map(matrix(1:2, 1, 2))
  pressure <- matrix(c(pi, 1 / 3, 1 + 2^-52, 1e-100, 1e100, 5e-162), ncol = 2)
  trial <- pr_trial(pressure, (0:2) / 10, layout, sampling_hz = 10)
  trial$metadata$condition <- factor("b", levels = c("a", "b"))
  trial$metadata$trial_id <- "synthetic-001"
  before <- serialize(trial, NULL)
  cycles <- data.frame(cycle = 1L, start_idx = 1L, end_idx = 3L, duration_s = .2)
  reference <- pr_lock_cycles(trial, cycles)
  path <- file.path(root, "bundle")
  pr_write_bundle(trial, path)
  restored <- pr_read_bundle(path)
  expect_identical(serialize(trial, NULL), before)
  expect_identical(restored, trial)
  expect_identical(pr_lock_cycles(restored, cycles), reference)
  manifest <- jsonlite::read_json(file.path(path, "manifest.json"), simplifyVector = TRUE)
  expect_identical(manifest$version, 2L)
  expect_true("measurements.rds" %in% names(manifest$sha256))
  writeBin(as.raw(1:4), file.path(path, "measurements.rds"))
  expect_error(pr_read_bundle(path), "checksum mismatch")
})

test_that("version 1 bundles remain readable with their decimal precision contract", {
  root <- withr::local_tempdir()
  layout <- pr_layout_from_index_map(matrix(1:2, 1, 2))
  trial <- pr_trial(matrix(1:6, ncol = 2), 0:2, layout, sampling_hz = 1)
  path <- file.path(root, "legacy")
  pr_write_bundle(trial, path)
  manifest <- jsonlite::read_json(file.path(path, "manifest.json"), simplifyVector = TRUE)
  manifest$version <- 1L
  manifest$sha256$measurements.rds <- NULL
  jsonlite::write_json(manifest, file.path(path, "manifest.json"), auto_unbox = TRUE)
  unlink(file.path(path, "measurements.rds"))
  restored <- pr_read_bundle(path)
  expect_equal(restored$pressure, trial$pressure)
  expect_equal(restored$time, trial$time)
  expect_identical(restored$metadata, trial$metadata)
})

test_that("bundles preserve supported empty trials and finite binary endpoints", {
  root <- withr::local_tempdir()
  layout <- pr_layout_from_index_map(matrix(1:2, 1, 2))
  empty <- pr_trial(matrix(numeric(), nrow = 0, ncol = 2), numeric(), layout)
  pr_write_bundle(empty, file.path(root, "empty"))
  expect_identical(pr_read_bundle(file.path(root, "empty")), empty)
  values <- c(.Machine$double.xmin, .Machine$double.xmax,
    .Machine$double.xmin * 2^-52, - .Machine$double.xmin)
  trial <- pr_trial(matrix(values, ncol = 2), c(0, 1), layout, sampling_hz = 1)
  pr_write_bundle(trial, file.path(root, "endpoints"))
  expect_identical(pr_read_bundle(file.path(root, "endpoints")), trial)
  trial$sampling_hz <- NA_real_
  pr_write_bundle(trial, file.path(root, "unknown-rate"))
  expect_identical(pr_read_bundle(file.path(root, "unknown-rate")), trial)
})

test_that("bundle metadata is validated rather than silently recomputed", {
  root <- withr::local_tempdir()
  path <- file.path(root, "bundle")
  pr_write_bundle(pr_example_trial("custom"), path)
  meta_path <- file.path(path, "metadata.rds")
  metadata <- readRDS(meta_path)
  metadata$n_frames <- metadata$n_frames + 1L
  saveRDS(metadata, meta_path, version = 3)
  manifest_path <- file.path(path, "manifest.json")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  manifest$sha256$metadata.rds <- digest::digest(meta_path, algo = "sha256", file = TRUE)
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE)
  expect_error(pr_read_bundle(path), "Trial dimensions")
})

test_that("invalid manifests fail before loading the bundle payload", {
  root <- withr::local_tempdir()
  path <- file.path(root, "bundle")
  pr_write_bundle(pr_example_trial("custom"), path)
  original <- jsonlite::read_json(file.path(path, "manifest.json"), simplifyVector = TRUE)
  for (field in c("frames", "sensors", "measurement_unit", "coordinate_unit", "sensor_ids", "sha256")) {
    manifest <- original
    manifest[[field]] <- NULL
    jsonlite::write_json(manifest, file.path(path, "manifest.json"), auto_unbox = TRUE)
    expect_error(pr_read_bundle(path), "Bundle manifest has invalid", info = field)
  }
  for (value in list(-1, 2.5, c(1, 2), "10")) {
    manifest <- original
    manifest$frames <- value
    jsonlite::write_json(manifest, file.path(path, "manifest.json"), auto_unbox = TRUE)
    expect_error(pr_read_bundle(path), "invalid dimensions")
  }
})

test_that("reported output failures preserve previous bytes", {
  root <- withr::local_tempdir()
  path <- file.path(root, "output.csv")
  writeLines("original user output", path)
  original <- readBin(path, "raw", n = file.info(path)$size)
  expect_error(pressR:::.atomic_output(path, function(tmp) {
    writeLines("partial", tmp)
    stop("writer failed")
  }), "writer failed")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), original)
  expect_error(pressR:::.atomic_output(path, function(tmp) file.create(tmp)), "empty file")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), original)
  real_rename <- pressR:::.rename_output
  n <- 0L
  testthat::local_mocked_bindings(.rename_output = function(from, to) {
    n <<- n + 1L
    if (n == 2L) return(FALSE)
    real_rename(from, to)
  }, .package = "pressR")
  expect_error(pressR:::.atomic_output(path, function(tmp) writeLines("replacement", tmp)), "Could not finalize")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), original)
  expect_identical(list.files(root, all.files = TRUE, no.. = TRUE), "output.csv")
})

test_that("an unsuccessful restore retains and reports the original backup", {
  root <- withr::local_tempdir()
  path <- file.path(root, "output.csv")
  writeLines("original user output", path)
  original <- readBin(path, "raw", n = file.info(path)$size)
  real_rename <- pressR:::.rename_output
  n <- 0L
  testthat::local_mocked_bindings(.rename_output = function(from, to) {
    n <<- n + 1L
    if (n > 1L) return(FALSE)
    real_rename(from, to)
  }, .package = "pressR")
  expect_error(pressR:::.atomic_output(path, function(tmp) writeLines("replacement", tmp)), "original is preserved at")
  backup <- list.files(root, pattern = "^\\.pressr-backup-", all.files = TRUE, full.names = TRUE)
  expect_length(backup, 1L)
  expect_identical(readBin(backup, "raw", n = file.info(backup)$size), original)
})

test_that("ordinary replacement succeeds and invalid destinations stay untouched", {
  root <- withr::local_tempdir()
  path <- file.path(root, "output.csv")
  writeLines("old", path)
  pressR:::.atomic_output(path, function(tmp) writeLines("new", tmp))
  expect_identical(readLines(path), "new")
  expect_error(pressR:::.atomic_output(root, function(tmp) stop("must not run")), "directory")
  for (bad in list(character(), c("a", "b"), NA_character_, "")) {
    expect_error(pressR:::.atomic_output(bad, function(tmp) stop("must not run")), "one nonempty")
  }
})

test_that("dangling and ordinary output links are refused on supported filesystems", {
  root <- withr::local_tempdir()
  link <- file.path(root, "alias")
  supported <- isTRUE(suppressWarnings(file.symlink(file.path(root, "missing"), link)))
  skip_if_not(supported, "Filesystem or account cannot create symbolic links")
  expect_error(suppressWarnings(readLines(link)))
  expect_error(pressR:::.atomic_output(link, function(tmp) stop("must not run")), "symbolic link")
  expect_error(pr_write_bundle(pr_example_trial("custom"), link), "symbolic link")
  expect_true(fs::is_link(link))
  writeLines("source", file.path(root, "missing"))
  expect_error(pressR:::.atomic_output(link, function(tmp) stop("must not run")), "symbolic link")
  expect_identical(readLines(file.path(root, "missing")), "source")
})

test_that("a source filename is not partially matched as a recording path", {
  trial <- pr_example_trial("custom")
  trial$metadata$source_filename <- "sensor.csv"
  expect_silent(pressR:::.protect_recording(trial, "sensor.csv"))
})

test_that("bundle paths are explicit and directory manifests are refused", {
  for (path in list(character(), c("one", "two"), NA_character_, "")) {
    expect_error(pr_read_bundle(path), "one nonempty")
  }
  root <- withr::local_tempdir()
  manifest <- file.path(root, "manifest.json")
  dir.create(manifest)
  expect_true(dir.exists(manifest))
  expect_error(pr_read_bundle(root), "regular file")
})

test_that("POSIX FIFO manifests are refused without reading", {
  # An MSYS mkfifo executable can succeed on Windows while native Windows R
  # cannot see its FIFO. That is not a native filesystem FIFO fixture.
  skip_on_os("windows")
  skip_if_not(nzchar(Sys.which("mkfifo")), "Named pipe fixture needs mkfifo")
  root <- withr::local_tempdir()
  manifest <- file.path(root, "manifest.json")
  expect_identical(system2(Sys.which("mkfifo"), shQuote(manifest)), 0L)
  expect_true(file.exists(manifest))
  expect_identical(as.character(fs::file_info(manifest)$type), "FIFO")
  expect_error(pr_read_bundle(root), "regular file")
})

test_that("archive aliases cannot silently replace an earlier selected member", {
  skip_if_not_installed("archive")
  root <- withr::local_tempdir()
  withr::local_dir(root)
  writeLines("original recording", "one.asc")
  original <- readBin("one.asc", "raw", n = file.info("one.asc")$size)
  utils::tar("aliases.tar", files = c("one.asc", "./one.asc"),
    compression = "none", tar = "internal")
  expect_error(pr_extract_archive("aliases.tar", c("one.asc", "./one.asc"), "out"), "alias")
  expect_false(dir.exists("out"))
  expect_identical(readBin("one.asc", "raw", n = file.info("one.asc")$size), original)
  # A single exact archive path with an ordinary ./ prefix remains usable.
  result <- pr_extract_archive("aliases.tar", "./one.asc", "out")
  expect_identical(result$relative_path, "one.asc")
  expect_identical(readBin("out/one.asc", "raw", n = file.info("out/one.asc")$size), original)
  for (member in c("dir/file:stream", "NUL.txt", "dir/con", "COM1.log",
    "dir/COM\u00b9.txt", "dir/LPT\u00b2.txt", "trailing.", "trailing ", "dir/line\nbreak")) {
    expect_error(pr_extract_archive("aliases.tar", member, "rejected"), "Unsafe", info = member)
    expect_false(dir.exists("rejected"))
  }
})
