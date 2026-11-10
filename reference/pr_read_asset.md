# Register an Image or Other Study Attachment

Reads embedded metadata when ExifTool is installed. Radiometric payload
and calibration presence are reported separately; display colours are
never interpreted as temperatures. No source files are written.

## Usage

``` r
pr_read_asset(path, exiftool = Sys.which("exiftool"))
```

## Arguments

- path:

  Source file.

- exiftool:

  ExifTool executable, or an empty string for basic registration.

## Value

Source identity, embedded metadata and calibration availability.

## Examples

``` r
path <- tempfile(fileext = ".txt")
writeLines("Session protocol", path)
# An empty `exiftool` registers the file without reading embedded metadata.
asset <- pr_read_asset(path, exiftool = "")
asset$metadata_status
#> [1] "metadata_tool_unavailable"
asset$temperature_status
#> [1] "unavailable"
unlink(path)
```
