# Theme image assets

The theme picker is the only runtime consumer of the bundled theme image tree. `CafeWeb.ThemeSwitcher` renders one thumbnail for each of the 10 themes from `priv/static/images/themes/{seasons,vibes}/*/thumbs/1.webp`. The static endpoint already serves the `images` directory, so no endpoint or build configuration change is needed.

## Inventory and cleanup

The reference scan covered Elixir, HEEx, JavaScript, CSS, configuration, tests, and documentation. It found 10 thumbnail references, all under `thumbs/1.gif`, and no references to the 15 additional `thumbs/2.gif` through `thumbs/4.gif` files or the 25 full-size `*/1.png` through `*/4.png` files. The full-size PNGs and additional thumbnail GIFs were orphaned assets; the current player uses YouTube for the visual background and the picker uses one thumbnail per theme. All 40 orphaned files were removed.

Every source thumbnail was checked with `ffprobe`: each is a single-frame GIF, with no animation to preserve. The image metadata also reports RGB without alpha. The 10 referenced thumbnails were converted to lossless WebP at their original dimensions, and the HEEx paths now use `.webp`.

| inventory | files | bytes | MiB |
| --- | ---: | ---: | ---: |
| orphaned full-size PNGs before cleanup | 25 | 106,711,643 | 101.77 |
| referenced thumbnail GIFs before conversion | 10 | 76,866 | 0.07 |
| orphaned extra thumbnail GIFs before cleanup | 15 | 106,530 | 0.10 |
| theme tree before cleanup | 50 | 106,895,039 | 101.94 |
| referenced lossless WebP thumbnails after conversion | 10 | 61,298 | 0.06 |
| theme tree after cleanup | 10 | 61,298 | 0.06 |
| bytes removed | 40 files | 106,833,741 | 101.88 |

The final tree is 0.0573% of the measured starting size, a 99.9427% reduction. The large reduction comes from deleting the orphaned full-size PNGs and extra thumbnail GIFs; converting the referenced GIFs saves 15,568 bytes while preserving their pixels.

The commonly quoted `~205 MB` figure does not match this checkout's source asset tree: the exact pre-cleanup tree measured 106,895,039 bytes (101.94 MiB). That larger figure can include Git history or generated copies; this inventory and reduction measure the checked-out `priv/static/images/themes` files only.

## Reproducing the thumbnail conversion

Run `scripts/optimize_theme_images.sh --remove-orphans` from the repository root on the original theme image tree. It requires `ffmpeg`, `ffprobe`, and `cwebp`, converts only the referenced `thumbs/1.gif` files, refuses to flatten any GIF with more than one frame, writes lossless WebP with method 6, verifies that each output is non-empty, and removes each source only after its replacement succeeds. The opt-in cleanup removes the currently unreferenced PNGs and extra thumbnail GIFs; run the script without the flag when only conversion is desired.

## Validation

Each converted WebP was decoded and compared with its source GIF after frame extraction. All 10 files retained their original width and height, and all 10 had byte-identical RGB pixel buffers. FFmpeg reported SSIM `1.000000` for every pair and PSNR `inf` for every pair. Representative originals and WebP outputs were also inspected at their native thumbnail size; no visual difference was visible.

The orphan decision can be rechecked with:

```sh
rg -n --hidden \
  -g '!deps/**' \
  -g '!_build/**' \
  -g '!priv/static/images/themes/**' \
  -g '!docs/theme-images.md' \
  -g '!scripts/optimize_theme_images.sh' \
  -e 'themes/.+\.(png|gif|webp)' \
  -e 'thumbs/.+\.(png|gif|webp)' \
  lib assets config test
```

The only expected matches are the two WebP path expressions in `lib/cafe_web/live/components/theme_switcher.ex`; no full-size PNG or extra thumbnail remains in the static tree.
