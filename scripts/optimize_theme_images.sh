#!/usr/bin/env bash

# Convert the referenced, single-frame theme thumbnails to lossless WebP.
# The source GIFs are intentionally removed after each replacement succeeds.
# Animated GIFs are rejected so this script cannot silently discard motion.

set -euo pipefail

remove_orphans=false

case "${1:-}" in
  "")
    ;;
  --remove-orphans)
    remove_orphans=true
    ;;
  *)
    printf 'usage: %s [--remove-orphans]\n' "$0" >&2
    exit 2
    ;;
esac

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
theme_root="$repo_root/priv/static/images/themes"

for command in ffmpeg ffprobe cwebp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$command" >&2
    exit 1
  fi
done

if [[ ! -d "$theme_root" ]]; then
  printf 'theme image directory not found: %s\n' "$theme_root" >&2
  exit 1
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/vibes-theme-images.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

converted=0

while IFS= read -r -d '' source; do
  frames="$(ffprobe \
    -v error \
    -select_streams v:0 \
    -count_frames \
    -show_entries stream=nb_read_frames \
    -of csv=p=0 \
    "$source")"

  if [[ "$frames" != "1" ]]; then
    printf 'refusing to flatten %s (%s frames)\n' "$source" "${frames:-unknown}" >&2
    exit 1
  fi

  frame_png="$temporary_root/frame-$converted.png"
  candidate="$temporary_root/thumb-$converted.webp"
  target="${source%.gif}.webp"

  ffmpeg \
    -hide_banner \
    -loglevel error \
    -nostdin \
    -y \
    -i "$source" \
    -frames:v 1 \
    "$frame_png"

  cwebp \
    -quiet \
    -lossless \
    -m 6 \
    -metadata none \
    "$frame_png" \
    -o "$candidate"

  if [[ ! -s "$candidate" ]]; then
    printf 'conversion produced an empty file for %s\n' "$source" >&2
    exit 1
  fi

  mv -f "$candidate" "$target"
  rm -f "$source"
  converted=$((converted + 1))
done < <(find "$theme_root" -type f -path '*/thumbs/1.gif' -print0)

if [[ "$remove_orphans" == true ]]; then
  # The current picker has one thumbnail per theme and no full-size image
  # consumer. Keep the cleanup opt-in so adding a future consumer cannot
  # accidentally remove its source asset during a normal conversion run.
  find "$theme_root" -type f -name '*.png' -delete
  find "$theme_root" -type f -name '*.gif' ! -name '1.gif' -delete
  find "$theme_root" -type f -name '*.webp' ! -name '1.webp' -delete
fi

printf 'converted %d single-frame theme thumbnails to lossless WebP\n' "$converted"
