# iOS flavours — recipe, verification, gotchas

`S=.claude/skills/flutter-flavors/scripts` (from the project root). Every step below was run and
verified on a real project; the "Worked example" at the end has its values.

## How a Flutter iOS flavour actually resolves

- `flutter run|build --flavor X` builds the Xcode **scheme `X`** with the
  configuration **`<Mode>-X`** (`Debug-development`, `Release-production`, …).
  Both must exist; `Profile` is often a single shared config.
- The CLI first rewrites `ios/Flutter/Generated.xcconfig` (`FLUTTER_TARGET`,
  `FLAVOR`, `FLUTTER_BUILD_NAME/NUMBER`, `DART_DEFINES`). Xcode's build script
  (`xcode_backend.sh build`) compiles `FLUTTER_TARGET` and passes `-dFlavor=$FLAVOR`
  (which also sets the `FLUTTER_APP_FLAVOR` define behind `appFlavor`).
- **An Xcode Product > Archive does not run the CLI.** It uses whatever the last
  `flutter` command left in `Generated.xcconfig` — unless the Runner **target**
  sets the value itself: target-level build settings beat the base xcconfig.
- Check what wins with `xcodebuild -project ios/Runner.xcodeproj -target Runner
  -configuration <C> -showBuildSettings | grep -E 'FLUTTER_TARGET|FLAVOR'`.

## Step 1 — pin the Dart entry point and flavour per configuration

```bash
for c in Debug-production Release-production Profile; do
  python3 $S/pbxproj_flavors.py set $c FLUTTER_TARGET=lib/main_prod.dart FLAVOR=production; done
for c in Debug-development Release-development; do
  python3 $S/pbxproj_flavors.py set $c FLUTTER_TARGET=lib/main_dev.dart FLAVOR=development; done
python3 $S/pbxproj_flavors.py show
```
Verify: `bash $S/verify-archive.sh Runner` while `Generated.xcconfig` still says
the dev file (run `flutter run --flavor development` first) → the report must
list only the production entry file.

## Step 2 — "Archive Only Production" guard

```bash
python3 $S/pbxproj_flavors.py add-guard --configuration Release-production \
    --entry main_prod.dart --flavor production
```
Adds `scripts/archive-guard.sh` as the **first** build phase of Runner
(`alwaysOutOfDate = 1`, so no "runs every build" warning). It acts only when
`ACTION=install` (Xcode Archive and `flutter build ipa`) and fails unless the
configuration, the entry file and `FLAVOR` are all production. Rerunning
`add-guard` updates the script in place. It deliberately also blocks
`flutter build ipa --flavor development`; loosen it if a dev app is distributed.
Verify: `bash $S/verify-archive.sh development` → "✗ ARCHIVE FAILED … Only the
production release can be archived".

## Step 3 — side-by-side install (own bundle ID + name)

```bash
for c in Debug-development Release-development; do
  python3 $S/pbxproj_flavors.py set $c PRODUCT_BUNDLE_IDENTIFIER=com.example.app.dev "APP_DISPLAY_NAME=My App Dev"; done
for c in Debug-production Release-production Profile; do
  python3 $S/pbxproj_flavors.py set $c "APP_DISPLAY_NAME=My App"; done
python3 $S/pbxproj_flavors.py scheme development Test=Debug-development Launch=Debug-development \
    Profile=Release-development Analyze=Debug-development Archive=Release-development
```
- In `ios/Runner/Info.plist` change the one line under `CFBundleDisplayName` to
  `<string>$(APP_DISPLAY_NAME)</string>` by hand (an Edit, not `plutil -replace`,
  which re-serialises the whole file). `INFOPLIST_KEY_CFBundleDisplayName` does
  **not** work here: it only applies when Xcode generates the Info.plist.
- If `*.lproj/InfoPlist.strings` sets `CFBundleDisplayName`, it overrides the
  plist per language — give each flavour its own value there too.
- Check every scheme: a flavour scheme whose Profile/Test points at the other
  flavour's configuration builds the other app. Put Archive on a **Release**
  configuration (a Debug-configuration Archive runs the SPM prepare pre-action
  without `FLUTTER_ROOT` and dies with `/packages/flutter_tools/bin/xcode_backend.sh:
  No such file`).
- `flutter run --flavor development` needs nothing else: the CLI reads the bundle
  ID from the build settings.
- Verify on the simulator:
  ```bash
  flutter build ios --flavor development -t lib/main_dev.dart --simulator --debug
  xcrun simctl install booted build/ios/iphonesimulator/*.app
  xcrun simctl launch booted com.example.app.dev
  xcrun simctl terminate booted com.example.app.dev; xcrun simctl io booted screenshot home.png
  ```
  A standalone debug build takes 10–25 s to leave the white launch screen.
- Owner, on a phone: the first dev run registers the new App ID (automatic
  signing, needs an account allowed to create identifiers); delete the old
  dev-built app that lives under the production ID once.

## Step 4 — remove leftover CocoaPods (only when every plugin is SPM)

Preconditions: `Podfile.lock` lists only `Flutter`; `ios/Flutter/Flutter.podspec`
vendors `path/to/nothing`; every plugin appears in
`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`.

Order matters — **delete the Podfile before saving `pubspec.yaml`**: an IDE
auto-runs `flutter pub get` on save, and while a Podfile exists Flutter re-adds
`#include? "Pods/…"` lines to `Debug.xcconfig` / `Release.xcconfig`.

```bash
cd ios && pod deintegrate && cd ..      # frameworks, [CP] phases, Pods xcconfig refs, ios/Pods
# pod deintegrate leaves an empty "Pods" PBXGroup: remove it and its line in the main group's children
git rm ios/Podfile ios/Podfile.lock
printf '#include "Generated.xcconfig"\n' > ios/Flutter/Debug.xcconfig
printf '#include "Generated.xcconfig"\n' > ios/Flutter/Release.xcconfig
# remove the <FileRef location = "group:Pods/Pods.xcodeproj"> from ios/Runner.xcworkspace/contents.xcworkspacedata
```
then in `pubspec.yaml`:
```yaml
flutter:
  config:
    enable-swift-package-manager: true   # per project, so no Mac rebuilds a Podfile
```
Verify: `flutter pub get` leaves both xcconfigs alone; after `flutter clean`, a
build shows no "Running pod install" and no "non-standard Podfile" warning; the
production archive is identical to the baseline (`--baseline`).
Keep the old Podfile findable in git history: if a future plugin lacks SPM
support, Flutter restores a *standard* Podfile, whose `project 'Runner', {…}`
block knows only Debug/Profile/Release — CocoaPods then builds every unmapped
flavour configuration as **release**. Paste the old mapping back.

## Gotchas (all observed)

| Symptom | Cause | Fix |
|---|---|---|
| Archive ships `main_dev` | `FLUTTER_TARGET` only in `Generated.xcconfig` | Step 1 |
| Prod build's `appFlavor` says development | `FLAVOR` not pinned per configuration | Step 1 |
| "Unable to resolve module dependency: 'Flutter'" / "'Flutter/Flutter.h' file not found" in plugins during Archive, after switching flavours | stale explicit-module scans in the **shared** DerivedData | Product > Clean Build Folder (⇧⌘K); `verify-archive.sh` uses a fresh DerivedData (`SHARED_DERIVED_DATA=1` to reproduce) |
| Minimum iOS silently jumps (16.4 → 17.0 under Xcode 27) | "Update to recommended settings" adds `IPHONEOS_DEPLOYMENT_TARGET = $(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)` to every configuration | `pbxproj_flavors.py unset <C> IPHONEOS_DEPLOYMENT_TARGET` for each; keep the rest of the upgrade |
| Archive uploads an old build number | `FLUTTER_BUILD_NUMBER` comes from `Generated.xcconfig` | run any flutter command (e.g. `flutter build ios --flavor production -t lib/main_prod.dart --config-only`) after bumping `pubspec.yaml`; `audit.sh` warns |
| `xcode_backend.sh: No such file` in "Run Prepare Flutter Framework Script" | Archive of a Debug configuration | Archive only Release configurations |
| Big pbxproj diff you did not write (objectVersion, `/*  */` comments, `[CP]` phase moved first) | `pod install` / Flutter migration / Xcode rewrite | compare semantics (`pbxproj_flavors.py show`, `plutil -convert json`) |
| Only one scheme has the SPM "prepare" pre-action | the CLI adds it to a scheme the first time it builds that scheme | harmless for Release archives from a fresh DerivedData; build each scheme once with the CLI |
| Scheme points at a configuration that no longer exists (e.g. `Debug`) | leftover from before flavours | point it at real configurations or delete the scheme |
| Release build still prints logs | `print`/`debugPrint` are not stripped in release | gate logging on the flavour config in Dart and verify the prod entry turns it off |
| Upload succeeds, then App Store Connect marks the build invalid: **ITMS-90683 Missing purpose string** (`NSCameraUsageDescription` error, `NSLocationWhenInUseUsageDescription` warning), first build after moving to SPM | Swift packages cannot pick CocoaPods **subspecs**: `file_picker`'s podspec used only `DKImagePickerController/PhotoGallery`, its `Package.swift` links the whole library incl. **DKCamera** (`AVCaptureDevice`, `CLLocationManager`). Apple's scan flags any referenced API, used or not | Add both purpose strings (honest wording if the feature is unused). Note `permission_handler_apple`'s SPM manifest then compiles its camera/location code too — it enables a permission when its Info.plist key exists |
| Re-uploading the same build number after an invalid build | App Store Connect keeps every build number it received for a version, invalid ones included → "Redundant Binary Upload" | bump the build (`flutter build ios … --config-only --build-number 51.1` keeps the visible 51 on iOS only), or the version |

## Worked example (the proving project)

| Config | Bundle ID | Display name | Entry | FLAVOR |
|---|---|---|---|---|
| Debug-production / Release-production / Profile | `com.techno.track.view` | Track View | `lib/main_prod.dart` | production |
| Debug-development / Release-development | `com.techno.track.view.dev` | Track View Dev | `lib/main_dev.dart` | development |

Schemes: `Runner` and `production` archive `Release-production`; `development`
uses only development configurations and its Archive is refused by the guard.
Production archive before vs after every step: identical `Info.plist` and
`Frameworks/` (App, Flutter, objective_c), `main_prod.dart` only, release engine.
