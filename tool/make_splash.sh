#!/usr/bin/env bash
# Places the launch splash art (rendered by tool/render_icons.sh from
# assets/icon/source/splash_*.svg) into the native splash screens:
#   iOS          LaunchImage, 160 pt (@1x/@2x/@3x)
#   Android <12  drawable-*/launch_image.png, 160 dp
#   Android 12+  drawable-*/splash_icon.png, the 288 dp icon canvas
#                (the mark sits inside the 192 dp circle the system masks)
# Background everywhere: #0B0D14 (storyboard, @color/launch_background).
set -euo pipefail
cd "$(dirname "$0")/.."
./tool/render_icons.sh >/dev/null

mark=assets/icon/splash_mark.png
a12=assets/icon/splash_android12.png
res=android/app/src/main/res
ios=ios/Runner/Assets.xcassets/LaunchImage.imageset

resize() { sips -z "$2" "$2" "$1" --out "$3" >/dev/null; }

resize "$mark" 160 "$ios/LaunchImage.png"
resize "$mark" 320 "$ios/LaunchImage@2x.png"
resize "$mark" 480 "$ios/LaunchImage@3x.png"

for pair in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  density="${pair%%:*}"
  scale="${pair##*:}"
  mkdir -p "$res/drawable-$density"
  resize "$mark" "$(printf '%.0f' "$(echo "160 * $scale" | bc)")" "$res/drawable-$density/launch_image.png"
  resize "$a12" "$(printf '%.0f' "$(echo "288 * $scale" | bc)")" "$res/drawable-$density/splash_icon.png"
done
echo "splash art placed"
