# Write the synthetic Novel/Pliance saddle recording used by the tests.
#
# Run from the package root:
#   Rscript data-raw/synthetic_saddle.R
#
# The recording is defined in tests/testthat/helper-synthetic-saddle.R, which
# the tests also use as ground truth; this script only writes it to disk. The
# output is identical on every platform, and a test checks that the
# committed file matches what the helper writes.
source(file.path("tests", "testthat", "helper-synthetic-saddle.R"))
write_synthetic_saddle(
  file.path("tests", "testthat", "fixtures", "synthetic_saddle_MS.asc")
)
