#!/usr/bin/env bash
# Build an UNSIGNED Xcode archive of a Flutter app's iOS scheme — exactly what
# Product > Archive does — and report what actually ended up inside it.
#
# Usage (from anywhere inside the Flutter project):
#   verify-archive.sh <scheme>             [--save <info.json>] [--baseline <info.json>]
#   verify-archive.sh --inspect <.xcarchive> [--save <info.json>] [--baseline <info.json>]
#
#   --inspect   skip the build; report on an archive that already exists
#   --save      keep the archived app's Info.plist (as JSON) plus a
#               Frameworks/ listing next to it (<info.json>.frameworks.txt)
#   --baseline  compare against a file written earlier by --save; exits 2 on
#               any difference
#
# Builds use a FRESH DerivedData folder by default. Xcode's shared DerivedData
# can hold stale explicit-module scans after switching schemes/flavours, which
# fails the plugins with "Unable to resolve module dependency: 'Flutter'" even
# though the project is fine. SHARED_DERIVED_DATA=1 reproduces what Xcode's own
# Archive menu would do instead.
#
# Env: ENTRY_GLOB (default "lib/main*.dart") — the candidate Dart entry files.
#
# Exit: 0 archive built (and matches the baseline, if given)
#       1 archive failed (the error lines are printed — a guard phase shows here)
#       2 archive built but differs from the baseline
set -uo pipefail

usage="usage: verify-archive.sh <scheme>|--inspect <archive> [--save f.json] [--baseline f.json]"
scheme="" inspect=""
if [ "${1:-}" = "--inspect" ]; then
  inspect="${2:?$usage}"; shift 2
else
  scheme="${1:?$usage}"; shift
fi
save="" baseline=""
while [ $# -gt 0 ]; do
  case "$1" in
    --save) save="$2"; shift 2 ;;
    --baseline) baseline="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
ios="$root/ios"
if [ -d "$ios/Runner.xcworkspace" ]; then
  container=(-workspace "$ios/Runner.xcworkspace")
else
  container=(-project "$ios/Runner.xcodeproj")
fi
pkg=$(awk '/^name:/ {print $2; exit}' "$root/pubspec.yaml")

tmp=$(mktemp -d -t verify-archive)
trap 'rm -rf "$tmp"' EXIT
log="$tmp/archive.log"

if [ -n "$inspect" ]; then
  archive="$inspect"
  echo "▸ Inspecting $archive"
else
  archive="$tmp/app.xcarchive"
  dd=()
  [ "${SHARED_DERIVED_DATA:-0}" = "1" ] || dd=(-derivedDataPath "$tmp/DerivedData")
  echo "▸ Archiving scheme '$scheme' unsigned (a few minutes)…"
  if ! xcodebuild archive "${container[@]}" -scheme "$scheme" \
      -destination generic/platform=iOS -archivePath "$archive" ${dd[@]+"${dd[@]}"} \
      CODE_SIGNING_ALLOWED=NO >"$log" 2>&1; then
    echo "✗ ARCHIVE FAILED"
    grep -E "error:|\*\* ARCHIVE" "$log" | sort -u | head -10
    exit 1
  fi
  echo "✓ ARCHIVE SUCCEEDED"
fi

app=$(ls -d "$archive/Products/Applications/"*.app)
plist="$app/Info.plist"
read_key() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null || echo "-"; }

echo "  app            $(basename "$app")"
echo "  bundle id      $(read_key CFBundleIdentifier)"
echo "  display name   $(read_key CFBundleDisplayName)"
echo "  version        $(read_key CFBundleShortVersionString) ($(read_key CFBundleVersion))"

# Which Dart entry file was compiled in: AOT snapshots keep each library's
# "<package>/<path>" string, so a candidate entry file shows up only if it
# was the build's target.
echo "  Dart entry     (occurrences in App.framework)"
bin="$app/Frameworks/App.framework/App"
for f in $root/${ENTRY_GLOB:-lib/main*.dart}; do
  [ -f "$f" ] || continue
  rel=${f#"$root/lib/"}
  n=$(strings -a "$bin" | grep -c "$pkg/$rel" || true)
  echo "                 $rel: $n"
done

if [ -e "$app/Frameworks/App.framework/flutter_assets/kernel_blob.bin" ]; then
  echo "  engine         DEBUG (kernel_blob.bin present — will not launch from TestFlight)"
else
  echo "  engine         release (AOT, no kernel_blob.bin)"
fi
frameworks=$(ls "$app/Frameworks")
echo "  Frameworks/    $(echo "$frameworks" | tr '\n' ' ')"

plutil -convert json -o "$tmp/info.json" "$plist"
if [ -n "$save" ]; then
  cp "$tmp/info.json" "$save"
  echo "$frameworks" >"$save.frameworks.txt"
  echo "  saved          $save (+ .frameworks.txt)"
fi

if [ -n "$baseline" ]; then
  python3 - "$baseline" "$tmp/info.json" <<'PY'
import json, sys
a, b = (json.load(open(p)) for p in sys.argv[1:3])
diff = sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))
for k in diff:
    print(f"  Info.plist Δ   {k}: {a.get(k)!r} -> {b.get(k)!r}")
sys.exit(1 if diff else 0)
PY
  plist_same=$?
  fw_same=0
  if [ -f "$baseline.frameworks.txt" ]; then
    if ! diff <(cat "$baseline.frameworks.txt") <(echo "$frameworks") >/dev/null; then
      fw_same=1
      echo "  Frameworks Δ   $(diff <(cat "$baseline.frameworks.txt") <(echo "$frameworks") | grep '^[<>]' | tr '\n' ' ')"
    fi
  fi
  if [ $plist_same -eq 0 ] && [ $fw_same -eq 0 ]; then
    echo "✓ identical to baseline"
  else
    echo "✗ differs from baseline"
    exit 2
  fi
fi
