# Releasing Tube Downloader

Tube Downloader is distributed outside the stores (sideload): Apple guideline 5.2.3 and
Google Play policy reject YouTube downloaders. Every release is built from the
**production** flavour (`lib/main_prod.dart`, bundle / application ID `com.tubedownloader.app`,
name "Tube DL"). Development builds are never distributed.

Signing material (keystores, certificates, passwords, API keys) **never enters git**: the
review gate blocks key files, and `.gitignore` covers `android/key.properties`, `*.jks`,
`*.keystore`, `*.p12` and `.env`.

Before any release: `flutter analyze --fatal-infos`, `bash .claude/skills/review-gate/scripts/check.sh --tests`
and the network smoke test (`flutter test --tags network`) on the release machine.

Bump `version:` in `pubspec.yaml` first (`1.2.0+12`: name + build number).

---

## Android: split APKs

### One-time: the release keystore

```bash
keytool -genkey -v -keystore ~/keys/tube-downloader-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias tube-downloader
```

Keep the `.jks` and its passwords in your password manager. **Losing it means users must
uninstall to update** (Android refuses an update signed with another key).

Create `android/key.properties` (git-ignored):

```properties
storeFile=/Users/<you>/keys/tube-downloader-release.jks
storePassword=…
keyAlias=tube-downloader
keyPassword=…
```

Without this file, release builds fall back to the debug key (fine for local testing,
never for distribution).

### Build

```bash
flutter build apk --flavor production -t lib/main_prod.dart --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-production-release.apk (+ armeabi-v7a, x86_64)
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-production-release.apk
```

Give users the **arm64-v8a** APK (every phone since ~2017); keep the others for old devices
and emulators. Users enable "Install unknown apps" for their browser or file manager.
Google's developer verification for sideloaded apps (rolling out 2026–27) may require
registering the package name: check before each release.

---

## macOS: notarized DMG

### One-time

- A paid Apple Developer account and a **Developer ID Application** certificate in your
  login keychain (Xcode › Settings › Accounts › Manage Certificates).
- An app-specific password for notarization, stored in the keychain:

  ```bash
  xcrun notarytool store-credentials tube-dl-notary \
    --apple-id <you@example.com> --team-id <TEAMID> --password <app-specific-password>
  ```

- Set `DEVELOPMENT_TEAM` for the Runner target's **Release-production** configuration
  (Xcode › Runner › Signing & Capabilities, "Developer ID" signing, hardened runtime on).

### Build, sign, notarize

```bash
flutter build macos --release --flavor production -t lib/main_prod.dart
APP="build/macos/Build/Products/Release-production/Tube DL.app"

# The FFmpeg frameworks are signed with the app; verify the whole bundle.
codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" /tmp/TubeDL.zip
xcrun notarytool submit /tmp/TubeDL.zip --keychain-profile tube-dl-notary --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"   # "accepted, source=Notarized Developer ID"

hdiutil create -volname "Tube DL" -srcfolder "$APP" -ov -format UDZO "Tube DL.dmg"
codesign --sign "Developer ID Application: <Name> (<TEAMID>)" "Tube DL.dmg"
xcrun notarytool submit "Tube DL.dmg" --keychain-profile tube-dl-notary --wait
xcrun stapler staple "Tube DL.dmg"
```

The app runs **unsandboxed** (Developer ID, no Mac App Store), so it needs no extra
entitlements for user-chosen folders or the network.

---

## Windows: installer

Build on Windows (or the `windows-latest` CI runner); Flutter can't cross-compile it:

```powershell
flutter build windows --release -t lib/main_prod.dart
# → build\windows\x64\runner\Release\
```

Package that folder with **Inno Setup** (`windows/installer/tube_downloader.iss`). Put the
version in the script, then compile with `iscc windows\installer\tube_downloader.iss`.
The script installs per user (no admin prompt) and adds a Start-menu shortcut.

Unsigned installers trigger SmartScreen ("Windows protected your PC" › More info › Run
anyway). A code-signing certificate (`signtool sign /fd SHA256 /tr <timestamp-url> /td SHA256 …`)
on both the app `.exe` and the installer removes most of that friction over time.

> **Not yet verified:** no Windows build has been run (no Windows machine in this setup).
> Expect to fix small issues on the first Windows build: FFmpeg DLL bundling, the
> `GetDiskFreeSpaceExW` FFI call, notifications (AppUserModelID).

---

## iOS: ad-hoc or TestFlight (internal)

Needs your Apple **team ID** and a paid account.

1. Set `DEVELOPMENT_TEAM` for the Runner target (Release-production / Profile).
2. Ad-hoc: register test devices' UDIDs in the developer portal, then

   ```bash
   flutter build ipa --release --flavor production -t lib/main_prod.dart --export-method ad-hoc
   ```

   Install the `.ipa` with Apple Configurator or Xcode › Devices.
3. TestFlight **internal** testing (up to 100 team members, no App Review for internal
   builds): `--export-method app-store`, upload with Transporter, add testers in App Store
   Connect. **External** TestFlight needs Beta App Review, which applies guideline 5.2.3.

The share extension (share a link from Safari or YouTube into Tube DL) is **deferred** (owner
decision 2026-10-05); iOS users copy a link and the app offers it. When it is built it needs an
**App Group** (`group.com.tubedownloader.app`) on both the app and the extension, which also
needs your team ID.

---

## Licences (every platform)

- FFmpeg / FFmpegKit (LGPL-3.0) are used unmodified and dynamically linked; the app's
  licences page (Settings › Open-source licenses) shows the LGPL text and where their
  source is. Don't switch to a `-gpl` FFmpegKit package: GPL codecs would change the
  app's licence obligations.
- Almarai (SIL OFL 1.1): `assets/fonts/OFL.txt` ships with the font and is on the
  licences page.
