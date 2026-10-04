---
name: flutter-flavors
description: Set up, audit or repair development/production build flavours in a Flutter app on BOTH iOS and Android — each flavour's Dart entry point (main_dev / main_prod), app ID (".dev" suffix) and app name so both install side by side; on iOS the build configurations, schemes, target-level FLUTTER_TARGET/FLAVOR and an "Archive Only Production" build phase so Xcode Archive / TestFlight can never ship dev; on Android productFlavors, applicationIdSuffix, resValue app_name, ${applicationId} authorities, per-flavour google-services, a Gradle flavour/entry guard and release signing; plus removing leftover CocoaPods once every plugin is a Swift package. Use whenever a request mentions flavors/flavours, schemes, build configurations, main_dev/main_prod, FLUTTER_TARGET, Generated.xcconfig, --flavor, applicationIdSuffix, bundle identifier, side-by-side install, per-flavour app name or icon, "which flavour does Archive / TestFlight / App Distribution ship", pod deintegrate, or "All plugins found for ios are Swift Packages".
---

# Flutter flavours — iOS + Android

Proven end to end on a production Flutter app (Flutter 3.47, Xcode 27, AGP 8.11 /
Gradle 8.14, September 2026): archives and APKs were built and inspected before
and after every change. Platform detail, snippets and gotchas:
**[reference/ios.md](reference/ios.md)** · **[reference/android.md](reference/android.md)**.
Scripts are in `scripts/` next to this file; from the project root, `S=.claude/skills/flutter-flavors/scripts`.
Portable: copy this whole folder into another project's `.claude/skills/` (or `~/.claude/skills/` for every project).

## The one idea

A flavour is four things that must always travel together: **Dart entry file,
app ID, app name, native build configuration**. Left alone, the entry file is
chosen by whatever the last CLI command wrote (iOS `Generated.xcconfig`) or
whatever `-t` somebody typed (Android). So:

1. Where the native build system can pin the entry file, pin it (iOS: target-level
   `FLUTTER_TARGET` + `FLAVOR` per build configuration — beats `Generated.xcconfig`).
2. Where it cannot (Android), make every CLI / CI / IDE invocation pass
   `--flavor X -t lib/main_x.dart`, and add a guard that fails a mismatched release.
3. Give each flavour its own app ID and name so they install side by side, and
   make the store build refuse to be anything but production.

## Workflow (do it in this order)

1. **Audit, read-only:** `bash $S/audit.sh` (add `--fast` to skip xcodebuild).
   It prints entry files, IDE configs, per-configuration iOS settings (target
   level and resolved), schemes, `Generated.xcconfig`, CocoaPods/SPM state,
   entitlements/Firebase/URL types, Android flavours/manifest/signing, CI
   release commands, identity-bound packages and hard-coded app IDs.
2. **Review with the user and WAIT for confirmation** before touching
   `project.pbxproj`, `Info.plist`, schemes, `build.gradle(.kts)` or the manifest.
   Walk the checklist below; ask about the dev name (long home-screen labels
   get truncated — check it on the smallest supported device) and whether a
   dev build may ever be distributed (decides how strict the guards are).
3. **Baseline the production artefacts** before editing:
   `bash $S/verify-archive.sh Runner --save before-ios.json` and
   `bash $S/verify-apk.sh production --save before-android.json -- <CI flags>`.
4. **Apply, one concern per commit:** (a) entry-point pinning + guards,
   (b) app ID + name + schemes (side-by-side), (c) CocoaPods removal.
   Close Xcode first, and expect an IDE to auto-run `flutter pub get` when
   `pubspec.yaml` is saved.
5. **Verify after each commit:** production artefact `--baseline` identical;
   a dev release/archive is refused by the guard; both apps installed side by
   side (simulator / emulator screenshot); `flutter test`.
6. **Hand the owner the device-only steps:** first dev run on a physical iPhone
   registers the new App ID (automatic signing); delete the old dev-built app
   that sits under the production ID once, reinstall production from the store.

## Target state

| | iOS | Android |
|---|---|---|
| Dart entry per flavour | `FLUTTER_TARGET` at **target** level on every Runner configuration | only `-t` on CLI / CI / IDE → Gradle guard |
| Flavour name for Flutter | `FLAVOR` at target level (else `appFlavor` leaks from the last run) | the productFlavor name |
| App ID | `PRODUCT_BUNDLE_IDENTIFIER`, dev = `<prod>.dev` | `applicationIdSuffix = ".dev"` |
| App name | `APP_DISPLAY_NAME` per config; `CFBundleDisplayName = $(APP_DISPLAY_NAME)` | `resValue("string", "app_name", …)`; `android:label="@string/app_name"` |
| Store-build guard | "Archive Only Production" = first build phase | Gradle flavour ↔ entry check |
| Launchers | each flavour scheme's Test/Launch/Analyze → `Debug-<f>`, Profile/Archive → `Release-<f>` | `.vscode/launch.json` / run configs pass `--flavor` **and** `--target` |
| Per-app resources | — | provider authorities `${applicationId}.…` |
| Firebase | one `GoogleService-Info.plist` per bundle ID | `google-services.json` per flavour or listing both packages |
| Dependency manager | SPM only (`flutter: config: enable-swift-package-manager: true`) | Gradle |

## Commands

```bash
# iOS project edits (text-surgical, plutil-checked, idempotent)
python3 $S/pbxproj_flavors.py show
python3 $S/pbxproj_flavors.py set Release-production FLUTTER_TARGET=lib/main_prod.dart FLAVOR=production "APP_DISPLAY_NAME=My App"
python3 $S/pbxproj_flavors.py set Debug-development  FLUTTER_TARGET=lib/main_dev.dart FLAVOR=development \
        PRODUCT_BUNDLE_IDENTIFIER=com.example.app.dev "APP_DISPLAY_NAME=My App Dev"
python3 $S/pbxproj_flavors.py add-guard --configuration Release-production --entry main_prod.dart --flavor production
python3 $S/pbxproj_flavors.py scheme development Test=Debug-development Launch=Debug-development \
        Profile=Release-development Analyze=Debug-development Archive=Release-development
python3 $S/pbxproj_flavors.py unset Release-production IPHONEOS_DEPLOYMENT_TARGET   # e.g. undo an Xcode "recommended" override

# Prove what ships
bash $S/verify-archive.sh Runner --baseline before-ios.json        # unsigned archive, fresh DerivedData
bash $S/verify-archive.sh development                               # must stop at the guard
bash $S/verify-apk.sh production --baseline before-android.json -- --obfuscate --split-debug-info=build/symbols
bash $S/verify-apk.sh --inspect build/app/outputs/flutter-apk/app-development-release.apk
```

## Checklist — things bound to the app ID (walk it with the user)

- **Entitlements / capabilities** (push, associated domains, keychain groups,
  app groups, Sign in with Apple): the new App ID needs each one; automatic
  signing copies them on the first device run if the account may.
- **Push:** APNs topic = bundle ID; FCM needs the Android package in Firebase.
- **Firebase / Crashlytics / Analytics:** a config file per app ID; a missing
  Android client fails `processXxxGoogleServices`.
- **OAuth / deep links:** redirect URIs and `CFBundleURLTypes` schemes are
  registered per app ID; universal links / `webcredentials` AASA list app IDs.
- **Keychain & preferences:** separate per app ID — the dev app starts empty
  (fresh login, new Face ID prompt). Production data is untouched.
- **Stores:** a dev ID has no App Store Connect / Play record; that is the point.
- **Hard-coded IDs** in QA scripts (`simctl get_app_container`), docs, backend
  allow-lists — the audit's last section lists them.
- **Parity:** same `.dev` suffix and the same dev name on both platforms.

## Hard-won rules (details in the references)

- **Prove, don't infer.** Resolved values come from `xcodebuild -showBuildSettings`,
  what shipped comes from the artefact (`verify-*`). Reading Flutter's
  `xcode_backend.dart` alone once produced a confident, wrong answer.
- **Compare content, not diffs.** `pod install`, Flutter migrations and Xcode
  rewrite `project.pbxproj` (objectVersion, comments, phase order) and reorder
  `Info.plist` keys; `plutil -convert json` both sides and compare.
- **Xcode "Update to recommended settings"** adds
  `IPHONEOS_DEPLOYMENT_TARGET = $(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)` to
  every configuration — it silently raised minimum iOS 16.4 → 17.0. Remove them.
- **Stale shared DerivedData** breaks Archive with "Unable to resolve module
  dependency: 'Flutter'" after flipping flavours — Clean Build Folder (⇧⌘K);
  the verify script always uses a fresh DerivedData.
- **Version numbers** in an Xcode Archive come from `Generated.xcconfig` — run a
  flutter command after bumping `pubspec.yaml`.
- **Android Studio's bundled JDK moves** (2026: JDK 25) and Gradle 8.x cannot run
  on it: builds fail with just the Java version as the error. Pin
  `flutter config --jdk-dir=<JDK 17/21>` or upgrade Gradle.

## This project: desktop targets (macOS + Windows)

The workflow above covers iOS + Android. Tube Downloader also ships on desktop:

- **macOS** has the same Xcode structure as iOS (`macos/Runner.xcodeproj`): build configurations `Debug/Release/Profile-<flavour>`, target-level `FLUTTER_TARGET` + `FLAVOR`, `PRODUCT_BUNDLE_IDENTIFIER` `com.tubedownloader.app(.dev)`, `PRODUCT_NAME` per configuration, and shared schemes `development` / `production`. `pbxproj_flavors.py` works on it with `--pbxproj macos/Runner.xcodeproj/project.pbxproj` (the scheme sub-command writes under `ios/` — copy the scheme files to `macos/Runner.xcodeproj/xcshareddata/xcschemes/` and edit `BuildableReference` names). There is no App Store archive here: the release artefact is a Developer-ID-signed, notarized DMG, so the "Archive Only Production" phase guards the DMG script instead.
- **Windows** has no `--flavor`. The entry point is chosen only by `-t lib/main_dev.dart` / `-t lib/main_prod.dart`; the app name/ID live in `windows/runner/Runner.rc` + `main.cpp` (window title) and the installer. Dev and prod install side by side by giving the dev installer its own AppId/product name.
- The two Dart entry files and `AppConfig` are the single source of per-flavour behaviour on all four platforms.
- **Debug configurations are NOT pinned here** (owner decision 2026-10-04): `FLUTTER_TARGET` is set only on `Release-*` and `Profile`, because a pinned Debug configuration makes `flutter test integration_test -d ios|macos` build the app's entry file instead of the test. Archive safety is unchanged — the "Archive Only Production" guard checks the Release build. Verify with `pbxproj_flavors.py show`: Debug rows show `-` for FLUTTER_TARGET.
