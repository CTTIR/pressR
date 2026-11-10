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
