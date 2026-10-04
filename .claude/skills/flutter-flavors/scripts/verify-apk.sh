#!/usr/bin/env bash
# Build (or just inspect) a Flutter Android release APK and report what is
# really inside it: package, label, version, ABIs, the Dart entry file compiled
# into libapp.so, and the signing certificate.
#
# Usage (from anywhere inside the Flutter project):
#   verify-apk.sh <flavor> [-t lib/main_x.dart] [--save f.json] [--baseline f.json] [-- <extra flutter build args>]
#   verify-apk.sh --inspect <file.apk> [--symbols <dir>] [--save f.json] [--baseline f.json]
#
#   Build mode runs: flutter build apk --release --flavor <flavor> -t <target> <extra>
#   (default target: the lib/main_*.dart whose suffix starts the flavour name,
#   production -> main_prod.dart, development -> main_dev.dart).
#   --symbols   the --split-debug-info folder. An --obfuscate build strips the
#               library paths from libapp.so, so the entry file can only be read
#               from its symbols; build mode picks the folder up from <extra>.
#   --save/--baseline keep or compare the report as JSON; exit 2 on a difference.
#
# Env: ENTRY_GLOB (default "lib/main*.dart") — candidate Dart entry files.
# Needs: an Android SDK (build-tools aapt2 + apksigner), unzip; Java for
# apksigner (falls back to reading a v1 signature with openssl).
set -uo pipefail

usage="usage: verify-apk.sh <flavor>|--inspect <apk> [-t target] [--symbols dir] [--save f.json] [--baseline f.json] [-- args]"
flavor="" apk="" target="" save="" baseline="" symbols=""
extra=()
if [ "${1:-}" = "--inspect" ]; then apk="${2:?$usage}"; shift 2; else flavor="${1:?$usage}"; shift; fi
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--target) target="$2"; shift 2 ;;
    --symbols) symbols="$2"; shift 2 ;;
    --save) save="$2"; shift 2 ;;
    --baseline) baseline="$2"; shift 2 ;;
    --) shift; extra=("$@"); break ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done
for a in ${extra[@]+"${extra[@]}"}; do
  case "$a" in --split-debug-info=*) [ -n "$symbols" ] || symbols="${a#--split-debug-info=}" ;; esac
done

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
pkg=$(awk '/^name:/ {print $2; exit}' "$root/pubspec.yaml")

# --- find aapt2 (ANDROID_HOME, ANDROID_SDK_ROOT, local.properties, default) ---
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$sdk" ] && [ -f "$root/android/local.properties" ]; then
  sdk=$(sed -n 's/^sdk.dir=//p' "$root/android/local.properties")
fi
[ -n "$sdk" ] || sdk="$HOME/Library/Android/sdk"
aapt2=$(ls -d "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)
[ -x "${aapt2:-}" ] || { echo "aapt2 not found under $sdk/build-tools" >&2; exit 1; }

if [ -n "$flavor" ]; then
  if [ -z "$target" ]; then
    # production -> lib/main_prod.dart, development -> lib/main_dev.dart, staging -> lib/main_staging.dart …
    for f in "$root"/lib/main_*.dart; do
      [ -f "$f" ] || continue
      suffix=${f##*/main_}; suffix=${suffix%.dart}
      case "$flavor" in "$suffix"*) target="lib/main_$suffix.dart" ;; esac
    done
  fi
  [ -n "$target" ] && [ -f "$root/$target" ] || { echo "no entry file for flavor '$flavor' — pass -t lib/<file>.dart" >&2; exit 64; }
  echo "▸ flutter build apk --release --flavor $flavor -t $target ${extra[*]+"${extra[*]}"}"
  log=$(mktemp -t verify-apk)
  if ! (cd "$root" && flutter build apk --release --flavor "$flavor" -t "$target" ${extra[@]+"${extra[@]}"}) >"$log" 2>&1; then
    echo "✗ BUILD FAILED"
    grep -E "What went wrong|GradleException|Exception:|error:|FAILURE" -A2 "$log" | head -12
    rm -f "$log"; exit 1
  fi
  rm -f "$log"
  apk="$root/build/app/outputs/flutter-apk/app-${flavor}-release.apk"
  echo "✓ BUILD SUCCEEDED"
fi
[ -f "$apk" ] || { echo "no APK at $apk" >&2; exit 1; }

tmp=$(mktemp -d -t verify-apk)
trap 'rm -rf "$tmp"' EXIT
badging=$("$aapt2" dump badging "$apk" 2>/dev/null)
field() { echo "$badging" | sed -n "s/.*$1='\([^']*\)'.*/\1/p" | head -1; }
package=$(echo "$badging" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")
label=$(echo "$badging" | sed -n "s/^application-label:'\(.*\)'$/\1/p" | head -1)
# ABIs: only the ones holding libflutter.so can run the app. Plugins may add
# other ABI folders (their own .so files), and a device of that ABI will then
# INSTALL the APK and crash at launch.
engine_abis="" other_abis=""
for abi in $(unzip -Z1 "$apk" 'lib/*' 2>/dev/null | awk -F/ '{print $2}' | sort -u); do
  if unzip -Z1 "$apk" "lib/$abi/libflutter.so" >/dev/null 2>&1; then engine_abis="$engine_abis$abi "
  else other_abis="$other_abis$abi "; fi
done
abis="engine: ${engine_abis:-none}${other_abis:+ | plugin-only: $other_abis}"

# Entry file: an AOT snapshot keeps "<package>/<path>" for each library, so a
# candidate shows up only when it was the build's target. --obfuscate strips
# those; the --split-debug-info symbols still name "lib/<path>".
so=$(unzip -Z1 "$apk" 'lib/*/libapp.so' 2>/dev/null | grep arm64 | head -1)
[ -n "$so" ] || so=$(unzip -Z1 "$apk" 'lib/*/libapp.so' 2>/dev/null | head -1)
entries="" found=0
if [ -n "$so" ]; then
  unzip -p "$apk" "$so" > "$tmp/libapp.so"
  strings -a "$tmp/libapp.so" > "$tmp/app.strings"
  source="libapp.so"
  if [ -n "$symbols" ] && ls "$symbols"/*.symbols >/dev/null 2>&1; then
    cat "$symbols"/*.symbols | strings -a >> "$tmp/app.strings"; source="libapp.so + symbols"
  fi
  for f in $root/${ENTRY_GLOB:-lib/main*.dart}; do
    [ -f "$f" ] || continue
    rel=${f#"$root/lib/"}
    n=$(grep -c -E "($pkg|lib)/$rel" "$tmp/app.strings" || true)
    [ "$n" -gt 0 ] && found=1
    entries="$entries$rel=$n "
  done
  if [ "$found" = 0 ]; then
    entries="$entries(no match in $source — obfuscated? pass --symbols <split-debug-info dir>)"
  fi
fi

# Signing certificate: apksigner (v2/v3 — minSdk >= 24 APKs have no v1 block),
# else the v1 block via openssl.
signer=""
apksigner=$(ls -d "$sdk"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
if [ -x "${apksigner:-}" ]; then
  signer=$("$apksigner" verify --print-certs "$apk" 2>/dev/null | sed -n 's/^Signer #1 certificate DN: //p' | head -1)
fi
if [ -z "$signer" ]; then
  cert=$(unzip -Z1 "$apk" 'META-INF/*' 2>/dev/null | grep -E '\.(RSA|EC|DSA)$' | head -1)
  [ -n "$cert" ] && signer=$(unzip -p "$apk" "$cert" | openssl pkcs7 -inform DER -print_certs 2>/dev/null | sed -n 's/^subject=//p' | head -1)
fi
[ -n "$signer" ] || signer="(unknown — apksigner needs Java; no v1 signature block)"
case "$signer" in *"Android Debug"*) signer="$signer  ⚠ DEBUG KEY — Play rejects it; fine for side-loading / App Distribution" ;; esac

echo "  apk            ${apk#"$root/"} ($(du -h "$apk" | cut -f1 | tr -d ' '))"
echo "  package        $package"
echo "  label          $label"
echo "  version        $(field versionName) ($(field versionCode))   minSdk $(echo "$badging" | sed -n "s/^minSdkVersion:'\(.*\)'/\1/p")  targetSdk $(echo "$badging" | sed -n "s/^targetSdkVersion:'\(.*\)'/\1/p")"
echo "  ABIs           $abis"
echo "  Dart entry     ${entries:-"(no libapp.so — not a release/AOT build?)"}"
echo "  signed by      $signer"

python3 - "$tmp/report.json" "$package" "$label" "$(field versionName)" "$(field versionCode)" "$abis" "$entries" "$signer" <<'PY'
import json, sys
keys = ["package", "label", "versionName", "versionCode", "abis", "entries", "signer"]
json.dump(dict(zip(keys, sys.argv[2:])), open(sys.argv[1], "w"), indent=1)
PY
if [ -n "$save" ]; then cp "$tmp/report.json" "$save"; echo "  saved          $save"; fi
if [ -n "$baseline" ]; then
  if python3 - "$baseline" "$tmp/report.json" <<'PY'
import json, sys
a, b = (json.load(open(p)) for p in sys.argv[1:3])
diff = sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))
for k in diff: print(f"  Δ {k}: {a.get(k)!r} -> {b.get(k)!r}")
sys.exit(1 if diff else 0)
PY
  then echo "✓ identical to baseline"; else echo "✗ differs from baseline"; exit 2; fi
fi
