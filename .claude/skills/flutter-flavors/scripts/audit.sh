#!/usr/bin/env bash
# Read-only audit of a Flutter app's flavour setup on iOS AND Android.
# Prints facts only — SKILL.md explains how to read them. Changes nothing.
#
# Usage (from anywhere inside the Flutter project):
#   audit.sh              full audit (resolves each iOS configuration with xcodebuild: ~5 s each)
#   audit.sh --fast       skip the xcodebuild pass
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 1
fast=0; [ "${1:-}" = "--fast" ] && fast=1
h() { printf '\n== %s ==\n' "$1"; }
none() { echo "  (none)"; }

pkg=$(awk '/^name:/ {print $2; exit}' pubspec.yaml)
ver=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)
echo "Flutter project '$pkg', pubspec version $ver"
echo "$root"

h "Dart entry points"
ls lib/main*.dart 2>/dev/null | sed 's/^/  /' || none

h "IDE run configurations (each must pass --flavor AND --target)"
if [ -f .vscode/launch.json ]; then
  grep -E '"name"|"program"|--flavor|--target|"-t"|development|production|staging' .vscode/launch.json | sed 's/^ */  /'
else
  echo "  no .vscode/launch.json"
fi
ls .run/*.xml 2>/dev/null | sed 's/^/  Android Studio: /'

# ------------------------------------------------------------------ iOS ----
if [ -d ios/Runner.xcodeproj ]; then
  h "iOS — Runner target-level settings (the level that beats Generated.xcconfig)"
  python3 "$here/pbxproj_flavors.py" show | sed 's/^/  /'

  if [ "$fast" = 0 ]; then
    h "iOS — what Xcode resolves per configuration"
    configs=$(xcodebuild -project ios/Runner.xcodeproj -list 2>/dev/null |
      awk '/Build Configurations:/{f=1;next} /^[[:space:]]*$/{f=0} f{gsub(/^ +/,"");print}')
    printf '  %-22s %-30s %-18s %-22s %-12s %s\n' CONFIGURATION BUNDLE_ID APP_DISPLAY_NAME FLUTTER_TARGET FLAVOR MIN_IOS
    for c in $configs; do
      xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration "$c" -showBuildSettings 2>/dev/null |
        awk -v c="$c" -F' = ' '/^ +(PRODUCT_BUNDLE_IDENTIFIER|APP_DISPLAY_NAME|FLUTTER_TARGET|FLAVOR|IPHONEOS_DEPLOYMENT_TARGET) =/{
            gsub(/^ +/, "", $1); v[$1] = $2 }
          END { printf "  %-22s %-30s %-18s %-22s %-12s %s\n", c, v["PRODUCT_BUNDLE_IDENTIFIER"],
            (v["APP_DISPLAY_NAME"] == "" ? "-" : v["APP_DISPLAY_NAME"]), v["FLUTTER_TARGET"], v["FLAVOR"],
            v["IPHONEOS_DEPLOYMENT_TARGET"] }'
    done
  fi

  h "iOS — Info.plist names"
  for k in CFBundleDisplayName CFBundleName; do
    printf '  %-20s %s\n' "$k" "$(/usr/libexec/PlistBuddy -c "Print :$k" ios/Runner/Info.plist 2>/dev/null || echo '-')"
  done
  for s in ios/Runner/*.lproj/InfoPlist.strings; do
    [ -f "$s" ] && grep -H "CFBundleDisplayName" "$s" | sed 's/^/  localized override: /'
  done

  h "iOS — schemes (action → configuration; SPM 'prepare' pre-action)"
  for s in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
    [ -f "$s" ] || continue
    python3 - "$s" <<'PY'
import re, sys, os
t = open(sys.argv[1]).read()
acts = " ".join(f"{a}={m}" for a in ["Test", "Launch", "Profile", "Analyze", "Archive"]
                for m in re.findall(r'<' + a + r'Action\s+buildConfiguration = "([^"]+)"', t))
pre = "yes" if "xcode_backend.sh&quot; prepare" in t or "xcode_backend.sh\" prepare" in t else "no"
print(f"  {os.path.basename(sys.argv[1])[:-9]:14} {acts}  prepare={pre}")
PY
  done

  h "iOS — Generated.xcconfig (written by the LAST flutter command, not by the scheme)"
  if [ -f ios/Flutter/Generated.xcconfig ]; then
    grep -E '^(FLUTTER_TARGET|FLAVOR|FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER)=' ios/Flutter/Generated.xcconfig | sed 's/^/  /'
    gv="$(sed -n 's/^FLUTTER_BUILD_NAME=//p' ios/Flutter/Generated.xcconfig)+$(sed -n 's/^FLUTTER_BUILD_NUMBER=//p' ios/Flutter/Generated.xcconfig)"
    [ "$gv" = "$ver" ] || echo "  ⚠ version $gv ≠ pubspec $ver — an Xcode Archive now would ship the OLD number; run a flutter command first"
  else
    echo "  missing — run flutter pub get"
  fi

  h "iOS — dependency managers"
  if [ -f ios/Podfile ]; then echo "  Podfile: present"; else echo "  Podfile: none"; fi
  [ -f ios/Podfile.lock ] && echo "  Podfile.lock pods: $(awk '/^PODS:/{f=1;next} /^$/{f=0} f && /^  - /{sub(/^  - /,""); printf "%s; ", $0}' ios/Podfile.lock)"
  grep -H 'Pods' ios/Flutter/*.xcconfig ios/Runner.xcworkspace/contents.xcworkspacedata 2>/dev/null | sed 's/^/  Pods reference: /'
  spm=ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
  [ -f "$spm" ] && echo "  Swift-package plugins: $(grep -c '\.package(name:' "$spm") (incl. FlutterFramework)"
  echo "  pubspec enable-swift-package-manager: $(grep -E '^\s+enable-swift-package-manager:' pubspec.yaml | awk '{print $2}' || true)"
  echo "  global flutter config: $(flutter config --list 2>/dev/null | grep -i 'swift-package' | xargs || echo '?')"

  h "iOS — capabilities and files keyed to the bundle ID"
  ents=$(find ios -name '*.entitlements' -not -path '*/Pods/*' -not -path '*/ephemeral/*' 2>/dev/null)
  if [ -n "$ents" ]; then
    for e in $ents; do echo "  $e: $(grep -o '<key>[^<]*</key>' "$e" | sed 's/<[^>]*>//g' | tr '\n' ' ')"; done
  else
    echo "  entitlements: none (no push / associated domains / keychain groups / app groups)"
  fi
  find ios -iname 'GoogleService-Info*.plist' -not -path '*/Pods/*' 2>/dev/null | sed 's/^/  Firebase: /'
  for k in CFBundleURLTypes UIBackgroundModes BGTaskSchedulerPermittedIdentifiers; do
    /usr/libexec/PlistBuddy -c "Print :$k" ios/Runner/Info.plist >/dev/null 2>&1 && echo "  Info.plist has $k"
  done
fi

# -------------------------------------------------------------- Android ----
gradle=$(ls android/app/build.gradle.kts android/app/build.gradle 2>/dev/null | head -1)
if [ -n "$gradle" ]; then
  h "Android — flavours, IDs, names, signing ($gradle)"
  grep -n -E 'namespace|applicationId|applicationIdSuffix|flavorDimensions|create\(|productFlavors|resValue|signingConfig|google-services|isProduction|isMinifyEnabled|minifyEnabled|flavorEntryPoints|GradleException' "$gradle" | sed 's/^/  /'

  h "Android — manifest label and per-app authorities"
  m=android/app/src/main/AndroidManifest.xml
  grep -n -E 'android:label|android:authorities' "$m" | sed 's/^/  /'
  grep -n 'android:authorities' "$m" | grep -v 'applicationId' | sed 's/^/  ⚠ fixed authority (dev + prod cannot both install): /'

  h "Android — source sets (per-flavour resources, icons, google-services.json)"
  ls android/app/src | sed 's/^/  /'
  find android/app -name google-services.json -not -path '*/build/*' 2>/dev/null | while read -r f; do
    echo "  $f: $(grep -o '"package_name": *"[^"]*"' "$f" | sed 's/.*: *//' | tr '\n' ' ')"
  done

  h "Android — release signing"
  if [ -f android/key.properties ]; then echo "  key.properties: present"; else echo "  key.properties: none"; fi
  grep -n -E 'signingConfigs\.getByName\("debug"\)|signingConfig = signingConfigs.debug' "$gradle" >/dev/null &&
    echo "  ⚠ release is signed with the DEBUG key (fine for App Distribution / side-loading, rejected by Play)"
fi

h "Release build commands in CI / Fastlane (each must pass --flavor AND -t/--target)"
grep -rn -E 'flutter build (apk|appbundle|ipa|ios)' android/fastlane ios/fastlane fastlane .github/workflows codemagic.yaml bitrise.yml 2>/dev/null |
  sed 's/^/  /' | cut -c1-220 || true

h "Packages that depend on the app identity (pubspec)"
grep -n -i -E 'firebase|supabase|onesignal|messaging|google_sign_in|sign_in_with_apple|flutter_appauth|msal|sentry|app_links|uni_links|local_notifications|in_app_purchase' pubspec.yaml | sed 's/^/  /' || none

h "Hard-coded app identifiers outside the native project files"
# Base IDs only (a ".dev" variant is found by searching its base), reverse-DNS shaped.
ids=$( { [ -d ios/Runner.xcodeproj ] && python3 "$here/pbxproj_flavors.py" show 2>/dev/null | awk '{print $4}';
         [ -n "$gradle" ] && sed -n 's/.*applicationId *= *"\([^"]*\)".*/\1/p' "$gradle"; } |
       grep -E '^[a-z][a-z0-9_]*(\.[a-zA-Z0-9_]+)+$' | sed -E 's/\.(dev|development|staging|stg|qa)$//' | sort -u)
[ -n "$ids" ] || none
for id in $ids; do
  echo "  -- $id"
  grep -rnI -F "$id" . --exclude-dir={build,.dart_tool,Pods,ephemeral,.git,node_modules,.symlinks,.gradle} \
      --exclude=project.pbxproj --exclude='build.gradle*' --exclude=google-services.json --exclude='*.kt' --exclude='*.java' 2>/dev/null |
    cut -c1-180 | sed 's/^/  /'
done
echo
