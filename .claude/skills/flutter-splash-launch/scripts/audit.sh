#!/usr/bin/env bash
# Read-only audit of a Flutter app's launch handoff on iOS AND Android:
# the native splash artwork and the layout that decides its on-screen size,
# splash-generator leftovers, what the entry point awaits before runApp, the
# first route and the loaders that could paint the first Flutter frame.
# Prints facts only — SKILL.md and reference/native-splash.md explain how to
# read them. Changes nothing.
#
# Usage (from anywhere inside the Flutter project):   audit.sh
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 1
h() { printf '\n== %s ==\n' "$1"; }
none() { echo "  (none)"; }
# Pixel size of an image as WxH, from `file` (PNG "800 x 400", JPEG "800x400").
dims() { file "$1" 2>/dev/null | grep -oE '[0-9]+ ?x ?[0-9]+' | head -1 | tr -d ' '; }

[ -f pubspec.yaml ] || { echo "No pubspec.yaml at $root — run inside a Flutter project."; exit 1; }
echo "Flutter project '$(awk '/^name:/ {print $2; exit}' pubspec.yaml)' — $root"

# ------------------------------------------------------------ generator ----
h "Splash generator (native files below are what actually ships)"
if grep -qE '^[[:space:]]+flutter_native_splash:' pubspec.yaml; then
  grep -nE '^[[:space:]]+flutter_native_splash:' pubspec.yaml | sed 's/^/  pubspec.yaml:/'
else
  echo "  flutter_native_splash is NOT a dependency"
fi
if [ -f flutter_native_splash.yaml ]; then
  echo "  flutter_native_splash.yaml present (may be stale if the package was removed):"
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' flutter_native_splash.yaml | sed 's/^/    /'
fi
grep -nE '^flutter_native_splash:' pubspec.yaml | sed 's/^/  config inside pubspec.yaml:/'
calls=$(grep -rnE 'FlutterNativeSplash\.(preserve|remove)' lib 2>/dev/null)
if [ -n "$calls" ]; then echo "$calls" | sed 's/^/  /'; else echo "  no FlutterNativeSplash.preserve/remove calls — the native splash lasts until the first Flutter frame"; fi

# ------------------------------------------------------------------ iOS ----
if [ -d ios/Runner ]; then
  h "iOS — launch screen"
  plist=ios/Runner/Info.plist
  sbname=$(grep -A1 'UILaunchStoryboardName' "$plist" 2>/dev/null | grep -oE '<string>[^<]+' | sed 's/<string>//')
  if grep -q '<key>UILaunchScreen</key>' "$plist" 2>/dev/null; then
    echo "  Info.plist uses a UILaunchScreen DICTIONARY (no storyboard):"
    sed -n '/<key>UILaunchScreen<\/key>/,/<\/dict>/p' "$plist" | sed 's/^/    /'
  fi
  sb=$(ls ios/Runner/Base.lproj/"${sbname:-LaunchScreen}".storyboard 2>/dev/null)
  if [ -n "$sb" ]; then
    echo "  UILaunchStoryboardName = ${sbname:-?} → $sb"
    grep -oE '<color key="backgroundColor"[^>]*>' "$sb" | head -1 | sed 's/^/  root background: /'
    grep -oE '<imageView [^>]*>' "$sb" | while read -r line; do
      id=$(echo "$line" | grep -oE ' id="[^"]+"' | cut -d'"' -f2)
      img=$(echo "$line" | grep -oE ' image="[^"]+"' | cut -d'"' -f2)
      mode=$(echo "$line" | grep -oE ' contentMode="[^"]+"' | cut -d'"' -f2)
      # The view's own attribute in every constraint that names it — pinned
      # edges vs centre/size constraints decide how the image is drawn.
      attrs=$(grep -oE '<constraint [^>]*>' "$sb" | while read -r c; do
        if echo "$c" | grep -q "firstItem=\"$id\""; then echo "$c" | grep -oE 'firstAttribute="[^"]+"' | cut -d'"' -f2
        elif echo "$c" | grep -q "secondItem=\"$id\""; then echo "$c" | grep -oE 'secondAttribute="[^"]+"' | cut -d'"' -f2
        fi
      done | sort -u | tr '\n' ' ')
      echo "  imageView image=\"$img\" contentMode=$mode constraints: ${attrs:-(none to superview)}"
      for f in ios/Runner/Assets.xcassets/"$img".imageset/*; do
        case "$f" in *.png|*.jpg|*.jpeg|*.pdf) echo "      $(basename "$f")  $(dims "$f")";; esac
      done
    done
    echo "  (contentMode=center + all 4 edges pinned → drawn at the @1x pixel size, in points, centred on the full screen)"
  else
    echo "  no launch storyboard found"
  fi
fi

# -------------------------------------------------------------- Android ----
res=android/app/src/main/res
if [ -d "$res" ]; then
  h "Android — main activity theme"
  grep -nE 'android:theme=' android/app/src/main/AndroidManifest.xml 2>/dev/null | sed 's/^ */  /' || none

  h "Android < 12 — launch_background layer lists (windowBackground)"
  found=0
  for f in "$res"/drawable*/launch_background.xml; do
    [ -f "$f" ] || continue; found=1
    echo "  $f"
    grep -E '<bitmap|<item|android:src|android:gravity|<color' "$f" | grep -v '<!--' | sed 's/^ */    /'
  done
  [ "$found" = 0 ] && none

  h "Android — LaunchTheme per resource qualifier (v31 = Android 12 SplashScreen API)"
  for f in "$res"/values*/styles.xml; do
    [ -f "$f" ] || continue
    items=$(grep -E 'LaunchTheme|windowBackground|windowSplashScreen|windowFullscreen|windowDrawsSystemBarBackgrounds|windowLayoutInDisplayCutoutMode' "$f" | sed 's/^ */    /')
    [ -n "$items" ] && { echo "  $f"; echo "$items"; }
  done
  if grep -rqs 'windowSplashScreenIconBackgroundColor' "$res"/values*-v31/styles.xml; then
    echo "  → icon background SET: Android 12 icon is 240×240 dp, masked to a 160 dp circle"
  else
    echo "  → no icon background: Android 12 icon is 288×288 dp, masked to a 192 dp circle (drawable pixel size ignored)"
  fi

  h "Android — referenced drawables, per density (mdpi px = dp for a centred bitmap)"
  names=$( { cat "$res"/drawable*/launch_background.xml "$res"/values*/styles.xml 2>/dev/null; } |
    grep -oE '@drawable/[A-Za-z0-9_]+' | sed 's#@drawable/##' | sort -u)
  for n in $names; do
    [ "$n" = launch_background ] && continue
    echo "  $n"
    for f in "$res"/drawable*/"$n".*; do
      [ -f "$f" ] && echo "    $(basename "$(dirname "$f")")/$(basename "$f")  $(dims "$f")"
    done
  done
fi

# ----------------------------------------------------------------- Dart ----
h "Dart — entry points"
ls lib/main*.dart 2>/dev/null | sed 's/^/  /' || none

h "Dart — awaited before runApp (each one lengthens the native splash)"
for f in $(grep -rlE 'runApp\(' lib 2>/dev/null); do
  echo "  $f"
  grep -nE '^[[:space:]]*(await |final [^=]+= await |runApp\()' "$f" | sed 's/^/    /'
done

h "Dart — first route"
grep -rnE 'initialLocation:|initialRoute:|^[[:space:]]+home:' lib 2>/dev/null | head -10 | sed 's/^/  /' || none

h "Dart — loaders that could paint the first frame"
grep -rnE --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' \
  'class [A-Za-z0-9_]*(Splash|Launch|Loading|Bootstrap)[A-Za-z0-9_]* ' lib 2>/dev/null | head -15 | sed 's/^/  /'
echo "  loadingWidget: call sites —"
grep -rnE 'loadingWidget:' lib 2>/dev/null | head -15 | sed 's/^/    /'

h "Dart — this pattern already in place?"
hits=$(grep -rlnE 'LaunchArtwork|LaunchLoadingScreen|androidSdkInt' lib android/app/src/main 2>/dev/null)
if [ -n "$hits" ]; then echo "$hits" | sed 's/^/  /'; else echo "  not yet"; fi
