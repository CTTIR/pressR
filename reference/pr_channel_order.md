# Raw Device Channel Order for a Layout

Returns the integer permutation that reorders the columns of a raw
device export into the column-major grid order every other `pressR`
function assumes. A reader applies it once:
`pressure <- raw[, pr_channel_order(layout), drop = FALSE]`.

## Usage

``` r
pr_channel_order(layout_or_map)
```

## Arguments

- layout_or_map:

  A [pr_layout](https://cttir.github.io/pressR/reference/pr_layout.md)
  built by
  [`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md)
  (or
  [`pr_layout_saddle_novel()`](https://cttir.github.io/pressR/reference/pr_layout_saddle_novel.md)),
  a channel index matrix as accepted by
  [`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md),
  or an integer vector that already is such a permutation.

## Value

An integer vector of length `layout$n_sensors`.

## Details

Element `k` of the result is the *device channel* that belongs in
pressure column `k`, where column `k` corresponds to
`which(layout$active)[k]` — the same column-major ordering used by
[`pr_mask()`](https://cttir.github.io/pressR/reference/pr_mask.md) and
`.layout_build_coords()`.

## See also

Other channel map functions:
[`pr_layout_from_index_map()`](https://cttir.github.io/pressR/reference/pr_layout_from_index_map.md),
[`pr_layout_saddle_novel()`](https://cttir.github.io/pressR/reference/pr_layout_saddle_novel.md)

## Examples

``` r
pr_channel_order(rbind(c(2L, 1L), c(4L, 3L)))
#> [1] 2 4 1 3

ord <- pr_channel_order(pr_layout_saddle_novel())
length(ord)
#> [1] 256
ord[1:8]
#> [1]  16  32  48  64  80  96 112 128
```
