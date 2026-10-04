# Android flavours — recipe, verification, gotchas

`S=.claude/skills/flutter-flavors/scripts` (from the project root). Everything here was built and
inspected on a real project (AGP 8.11, Gradle 8.14.3, Kotlin DSL, JDK 17).

## How a Flutter Android flavour resolves

- `flutter build apk --flavor X -t lib/main_x.dart` runs Gradle task
  `assembleXRelease` with `-Ptarget=lib/main_x.dart` (plus `-Pdart-obfuscation`,
  `-Psplit-debug-info`, `-Ptarget-platform` when those flags are given).
- **There is no per-flavour Dart entry in Gradle.** Without `-t` the Flutter
  plugin compiles `lib/main.dart`; with the wrong `-t` it happily builds flavour
  X from flavour Y's code. Every CLI line, CI/Fastlane lane and IDE run config
  must pass both `--flavor` and `-t` — and a Gradle guard should enforce it.
- Output: `build/app/outputs/flutter-apk/app-<flavor>-release.apk` (the CLI's
  copy) or `build/app/outputs/apk/<flavor>/release/…` (Gradle's own).

## Step 1 — flavours, IDs, names (`android/app/build.gradle.kts`)

```kotlin
android {
    namespace = "com.example.app"          // code package; NOT the install ID
    defaultConfig {
        applicationId = "com.example.app"  // production ID
        versionCode = flutter.versionCode  // from pubspec
        versionName = flutter.versionName
    }
    flavorDimensions += "default"
    productFlavors {
        create("production") {
            dimension = "default"
            resValue("string", "app_name", "My App")
        }
        create("development") {
            dimension = "default"
            applicationIdSuffix = ".dev"                     // installs beside production
            resValue("string", "app_name", "My App Dev")     // keep it equal to iOS's dev name
        }
    }
}
```
and in `AndroidManifest.xml`: `android:label="@string/app_name"`. Remove any
`app_name` from `res/values/strings.xml`, or the build fails on a duplicate resource.

## Step 2 — everything per-app must use `${applicationId}`

Content-provider authorities (FileProvider, plugin providers) must be unique on
the device. A fixed authority means the second flavour fails to install with
`INSTALL_FAILED_CONFLICTING_PROVIDER`. Write them as
`android:authorities="${applicationId}.something"`; the placeholder follows the
`.dev` suffix. `audit.sh` flags every authority without it. Same for any custom
permission names, account types and deep-link hosts that must be app-specific.

## Step 3 — the Gradle flavour ↔ entry guard (tested)

Put this at the top level of `android/app/build.gradle.kts`, after `plugins {}`.
It checks at configuration time, so a mismatch fails in seconds, before anything
compiles:
```kotlin
// Flavour <-> Dart entry-point guard. Android has no per-flavour Dart target:
// the Flutter tool passes `-Ptarget=<file>`, so a release build of one flavour
// from another flavour's main file would otherwise succeed silently.
val flavorEntryPoints = mapOf("production" to "main_prod.dart", "development" to "main_dev.dart")
val flutterTarget = (project.findProperty("target") as String?) ?: "lib/main.dart"
flavorEntryPoints.forEach { (flavor, entry) ->
    val releasingFlavor = gradle.startParameter.taskNames.any {
        it.contains(flavor, ignoreCase = true) && it.contains("Release") &&
            (it.contains("assemble") || it.contains("bundle"))
    }
    if (releasingFlavor && !flutterTarget.endsWith(entry)) {
        throw GradleException(
            "The $flavor release must be built from $entry (got $flutterTarget). " +
                "Run: flutter build apk --flavor $flavor -t lib/$entry"
        )
    }
}
```
Verified: `assembleProductionRelease -Ptarget=lib/main_dev.dart` → "The
production release must be built from main_prod.dart …" in 17 s; production from
`main_prod.dart` and development from `main_dev.dart` both build. Unlike the iOS
archive guard it does not block dev releases (Android dev APKs are commonly
side-loaded); add that if only production may ever be built for release.

## Step 4 — Firebase / google-services

The `com.google.gms.google-services` plugin fails `processDevelopmentReleaseGoogleServices`
when `google-services.json` has no client for the dev package. Options, best first:
1. Register `com.example.app.dev` in the same Firebase project and download a
   `google-services.json` that lists both packages (one file in `android/app/`).
2. Per-flavour files: `android/app/src/production/google-services.json` and
   `android/app/src/development/google-services.json` (dev can be a separate
   Firebase project).
3. What the proving project does: apply the plugin only for production tasks —
   `val isProduction = gradle.startParameter.taskNames.any { it.contains("production", true) }`
   then `if (isProduction) apply(plugin = "com.google.gms.google-services")`.
   Works for CLI/CI builds, but it keys on task names (an IDE sync or a plain
   `assemble` never applies it), and the dev app then has no Firebase at all.
   Acceptable only when the app has no Firebase SDK (it used Firebase App
   Distribution purely as an upload target via Fastlane).

## Step 5 — release signing

Release builds signed with `signingConfigs.getByName("debug")` install fine and
upload to Firebase App Distribution, but **Google Play rejects them**, and the
debug key differs per machine, so an update signed on another Mac/CI won't
install over the old one.

**First ask whether the app is already on Google Play.** If it is, only its
existing (upload) keystore can publish updates — never generate a new one.
If it never was, create an upload key (Play App Signing keeps the real app
signing key and can reset a lost upload key):

```bash
KS=~/.android/<app>-upload.jks                  # OUTSIDE the repo
export KS_PW=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | cut -c1-32)   # never echoed
keytool -genkeypair -keystore "$KS" -storetype PKCS12 -storepass:env KS_PW -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=<App>, O=<Company>"
umask 077
cat > android/key.properties <<EOF
storeFile=$KS
storePassword=$KS_PW
keyAlias=upload
keyPassword=$KS_PW
EOF
unset KS_PW                                       # PKCS12: one password for store and key
```
`android/.gitignore` must cover `key.properties` and `**/*.jks` (Flutter's default does).

`android/app/build.gradle.kts` — release key when `key.properties` exists, debug
fallback (with a warning) when it does not, so local `flutter run --release`
and a CI run without secrets keep working:
```kotlin
import java.util.Properties     // MUST be an import at the top of the file — see gotchas

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null
if (!hasReleaseKey && gradle.startParameter.taskNames.any { it.contains("Release") }) {
    logger.warn("android/key.properties not found: this release build is signed with the DEBUG key.")
}

android {
    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))  // absolute, or relative to android/
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug") }
    }
}
```
Check which key each variant uses without building:
`cd android && ./gradlew :app:signingReport` (run it once with and once without
`key.properties`).

CI (GitHub Actions) — two required secrets, two optional ones (alias / separate
key password, so a different keystore can be swapped in by changing secrets
only); written before the build; warns instead of failing while missing:
```yaml
      - name: Create Android release signing key from secrets
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}          # optional, default "upload"
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}    # optional, default = store password
        run: |
          if [ -z "$ANDROID_KEYSTORE_BASE64" ] || [ -z "$ANDROID_KEYSTORE_PASSWORD" ]; then
            echo "::warning::signing secrets not set, so this APK is signed with a debug key."
            exit 0
          fi
          echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/upload-keystore.jks
          { echo "storeFile=upload-keystore.jks"; echo "storePassword=$ANDROID_KEYSTORE_PASSWORD"
            echo "keyAlias=${ANDROID_KEY_ALIAS:-upload}"
            echo "keyPassword=${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"; } > android/key.properties
```
Swapping keystores later (e.g. the company's official one, before the first
Play upload): point the local `key.properties` at it and update the secrets —
no code change. After the first Play upload, the registered upload key is the
one that must sign; changing it needs an upload-key reset in Play Console.
Add the secrets without printing the password:
```bash
gh secret set ANDROID_KEYSTORE_BASE64 < <(base64 -i "$KS")
gh secret set ANDROID_KEYSTORE_PASSWORD --body "$(sed -n 's/^storePassword=//p' android/key.properties)"
```
Switching an App Distribution channel from debug-signed to release-signed APKs
means every tester uninstalls once (Android refuses an update signed with a
different key); updates are normal afterwards. The Firebase App ID and package
do not change. `verify-apk.sh` prints the signer and warns on `CN=Android Debug`.

## Step 6 — the release command (CI / Fastlane)

The proving project's lane, with the reasons that were measured:
```bash
flutter build apk --release --flavor production --target lib/main_prod.dart \
  --obfuscate --split-debug-info=build/symbols --target-platform android-arm64
```
- `--obfuscate` needs `--split-debug-info`; keep the symbols (CI artefact), or
  obfuscated stack traces cannot be read back (`flutter symbolize`). They are
  also the only way to see which entry file an obfuscated build compiled
  (`verify-apk.sh --symbols build/symbols`).
- `--target-platform android-arm64` cut the APK from ~92 MB to ~31 MB, but
  plugin `.so` files keep `armeabi-v7a/` and `x86_64/` folders, so a 32-bit device
  **installs it and crashes** at launch (`verify-apk.sh` shows "engine: arm64-v8a |
  plugin-only: …"). `ndk.abiFilters` cannot fix it (the Flutter plugin owns them).
- Avoid `--split-per-abi` for a single-APK channel: it rewrites `versionCode` as
  `abi * 1000 + versionCode` (build 45 → 2045), and a versionCode can never go
  back down for installed users.
- Leave icon tree-shaking on; a non-const `IconData` fails the build loudly.

## Step 7 — IDE run configurations

`.vscode/launch.json` — one entry per flavour, each passing both flags:
```json
{ "name": "App Development", "request": "launch", "type": "dart",
  "program": "lib/main_dev.dart", "args": ["--flavor", "development", "--target", "lib/main_dev.dart"] }
```
Android Studio: Run > Edit Configurations > Dart entrypoint + "Build flavor".

## Verify

```bash
bash $S/verify-apk.sh production --save before.json -- --obfuscate --split-debug-info=build/symbols --target-platform android-arm64
bash $S/verify-apk.sh production --baseline before.json -- --obfuscate --split-debug-info=build/symbols --target-platform android-arm64
bash $S/verify-apk.sh development -- --target-platform android-arm64        # different package + label
bash $S/verify-apk.sh --inspect path/to.apk [--symbols build/symbols]
```
Side by side on an emulator: `adb install -r` both APKs, then check
`adb shell pm list packages | grep <base id>` lists two packages.

## Gotchas (all observed)

| Symptom | Cause | Fix |
|---|---|---|
| `FAILURE … What went wrong: 25.0.3` (just a Java version) | Flutter builds with Android Studio's bundled JDK; Android Studio moved it to JDK 25, which Gradle 8.x cannot run on | `flutter config --jdk-dir=$(/usr/libexec/java_home -v 17)` — the same JDK as CI's `setup-java` (fixed the proving project; restart the IDE after). `JAVA_HOME` does NOT override: Flutter prefers `--jdk-dir`, then Android Studio's JDK. Alternative: a Gradle version that supports the new JDK |
| `Unresolved reference: util` on `java.util.Properties()` in `build.gradle.kts` | in the Kotlin DSL, `java` is the Java-extension accessor, not the package | `import java.util.Properties` at the very top of the file, then `Properties()` |
| Production APK built from the dev entry | a `flutter build`/CI line without `-t`, or with the wrong one | Step 3 guard; pass both flags everywhere |
| `processDevelopment…GoogleServices` fails: no client for `…dev` | `google-services.json` lists only production | Step 4 |
| Second flavour won't install: `CONFLICTING_PROVIDER` | fixed provider authority | Step 2 |
| Verified entry shows 0 for every file | `--obfuscate` stripped library paths | `--symbols <split-debug-info dir>` |
| Signer unknown | minSdk ≥ 24 APKs are v2/v3-signed only (no `META-INF/*.RSA`) | `apksigner verify --print-certs` (needs Java; the script uses it) |
| Dev label longer than iOS's | names chosen separately | keep one dev name for both platforms |

## Worked example (the proving project)

| Flavour | applicationId | Label | Entry | Signed |
|---|---|---|---|---|
| production | `com.track.view` | Track View | `lib/main_prod.dart` | upload key (`CN=Track View`) via `key.properties`; debug fallback in CI until the secrets exist |
| development | `com.track.view.dev` | Track View Dev (same as iOS) | `lib/main_dev.dart` | same rule |

Provider authority `${applicationId}.openwith.fileprovider`; google-services
applied to production tasks only (no Firebase SDK in the app); Fastlane lane as in
Step 6 uploads `app-production-release.apk` to Firebase App Distribution.
