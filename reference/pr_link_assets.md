# Link Study Assets Using Explicit Acquisition Keys

Identifiers are never inferred from matching bytes or nearby timestamps.
Duplicate content retains separate identities and is flagged for review.
A recording must be unique on the supplied keys; multiple assets require
an explicit one-to-many relationship. Missing keys are always rejected.

## Usage

``` r
pr_link_assets(
  recordings,
  assets,
  by,
  relationship = c("one-to-one", "one-to-many"),
  allow_unmatched = FALSE
)
```

## Arguments

- recordings:

  Data frame with recording_id and the acquisition keys.

- assets:

  Data frame with asset_id and the same keys. Optional sha256 values are
  used only to flag duplicate content, never to assign identity.

- by:

  Non-empty character vector of shared key column names.

- relationship:

  Either one-to-one (default) or one-to-many.

- allow_unmatched:

  Keep unmatched assets with a status flag.

## Value

One row per asset, with recording_id, asset_id, acquisition keys,
link_status and duplicate_content. Unused recording IDs are an
attribute.

## Examples

``` r
recordings <- data.frame(
  recording_id = c("R1", "R2"),
  subject = c("S01", "S02"),
  session = c(1, 1)
)
assets <- data.frame(
  asset_id = c("A1", "A2"),
  subject = c("S02", "S01"),
  session = c(1, 1)
)
pr_link_assets(recordings, assets, by = c("subject", "session"))
#> # A tibble: 2 × 6
#>   asset_id subject session recording_id link_status           duplicate_content
#>   <chr>    <chr>     <dbl> <chr>        <chr>                 <lgl>            
#> 1 A1       S02           1 R2           matched_explicit_keys FALSE            
#> 2 A2       S01           1 R1           matched_explicit_keys FALSE            
```
