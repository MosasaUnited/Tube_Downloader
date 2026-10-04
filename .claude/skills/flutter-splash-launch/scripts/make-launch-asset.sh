#!/usr/bin/env bash
# Writes a launch-screen copy of native splash art at <scale>x (default 4x) its
# LOGICAL size — sharp up to 4.0 dpr, cheap to decode before runApp.
#
#   make-launch-asset.sh <source> <logical-width> <logical-height> <out> [scale]
#   e.g. make-launch-asset.sh assets/images/splash_12.png 288 288 assets/images/splash_12_launch.png
#
# Refuses to distort (aspect-ratio mismatch), to upscale (the source is already
# small enough — use it as-is) and to overwrite the source. Uses sips (macOS)
# or ImageMagick.
set -euo pipefail
[ $# -ge 4 ] || { sed -n '2,10p' "$0"; exit 1; }
src=$1; w=$2; h=$3; out=$4; scale=${5:-4}
[ -f "$src" ] || { echo "No such file: $src"; exit 1; }
[ "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")" != "$(cd "$(dirname "$out")" 2>/dev/null && pwd)/$(basename "$out")" ] ||
  { echo "Refusing to overwrite the source: $out"; exit 1; }

size=$(file "$src" | grep -oE '[0-9]+ ?x ?[0-9]+' | head -1 | tr -d ' ')
sw=${size%x*}; sh=${size#*x}
pw=$((w * scale)); ph=$((h * scale))

if [ $((sw * h)) -ne $((sh * w)) ]; then
  echo "Aspect ratio differs: source ${sw}x${sh}, logical ${w}x${h} — the copy would be distorted."
  exit 2
fi
if [ "$sw" -le "$pw" ]; then
  echo "Source is ${sw}x${sh}, already ≤ ${scale}x of ${w}x${h} (${pw}x${ph}) — use it as-is."
  exit 3
fi

if command -v sips >/dev/null 2>&1; then
  sips -z "$ph" "$pw" "$src" --out "$out" >/dev/null
elif command -v magick >/dev/null 2>&1; then
  magick "$src" -resize "${pw}x${ph}!" "$out"
elif command -v convert >/dev/null 2>&1; then
  convert "$src" -resize "${pw}x${ph}!" "$out"
else
  echo "Needs sips (macOS) or ImageMagick."
  exit 1
fi
echo "$out  $(file "$out" | grep -oE '[0-9]+ ?x ?[0-9]+' | head -1 | tr -d ' ')  (= ${w}x${h} logical at ${scale}x, from ${sw}x${sh})"
