#!/usr/bin/env bash
# Renders assets/icon/source/*.svg to 1024x1024 PNGs in assets/icon/ with
# headless Chrome (it draws the SVG blur filters faithfully), on a transparent
# background. Then generate the platform icons:
#   dart run flutter_launcher_icons
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for svg in assets/icon/source/*.svg; do
  name="$(basename "$svg" .svg)"
  html="$tmp/$name.html"
  {
    printf '<!doctype html><html><head><style>'
    printf 'html,body{margin:0;background:transparent}svg{display:block}'
    printf '</style></head><body>'
    cat "$svg"
    printf '</body></html>'
  } > "$html"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size=1024,1024 --screenshot="$PWD/assets/icon/$name.png" \
    "file://$html" >/dev/null 2>&1
  echo "assets/icon/$name.png"
done
