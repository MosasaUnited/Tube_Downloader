---
name: flutter-splash-launch
description: Build, audit or repair the app-launch handoff in a Flutter app on iOS AND Android — the native splash (LaunchScreen.storyboard / launch_background.xml / the Android 12+ windowSplashScreenAnimatedIcon) handing over to a Dart launch screen that repaints the SAME logo at the SAME size and position plus a bottom progress bar, so launch reads as one continuous splash instead of "splash → white screen with a spinner → first screen". Covers reading the native splash geometry, picking the Android 12+ artwork through an SDK-level method channel, a right-sized 4x launch asset, decoding the logo before runApp (precache without a BuildContext), scoping the launch loader to the first route's gate instead of the shared in-app loader, the bar's delayed reveal, and the tests. Use whenever a request mentions splash, splash screen, launch screen, native splash, flutter_native_splash, LaunchScreen.storyboard, LaunchImage, launch_background, android12splash, windowSplashScreen*, "white screen at startup", "white screen / spinner / loading dots between splash and login", "blank or white flash on launch", "the logo jumps after the splash", app launching, startup loader, first frame, "progress bar on launch", or "make the splash match on Android 12".
---

# Flutter splash → launch screen handoff

Built on a production Flutter app (Flutter 3.47, September 2026), where a
fresh install showed a white screen with three loading dots between the native
splash and the login form while the login translations loaded (up to 10 s).
It was replaced by this pattern, then **owner-tested on a device**. Unit and
widget tests are part of the recipe.

- **Detail:** native geometry and gotchas are in **[reference/native-splash.md](reference/native-splash.md)**. Code templates and tests are in **[reference/dart.md](reference/dart.md)**.
- **Scripts:** they live in `scripts/`. From the project root, `S=.claude/skills/flutter-splash-launch/scripts`.
- **Portable:** copy this whole folder into another project's `.claude/skills/`.

## The one idea

The native splash stays up until Flutter paints its **first frame**. So:
- everything `main()` awaits before `runApp` makes the native splash last longer;
- everything after `runApp` (translations, auth check, remote config) needs a Dart screen.

Make that Dart screen a **continuation** of the native splash: same background, same artwork, same on-screen size, same centre. The only new thing that appears is a progress bar. The handoff is then invisible, however long the wait.

Four things must agree, and each fails silently:

1. **Artwork.** Use the exact image the native layer draws **on this device**. iOS, Android < 12 and Android 12+ can each differ.
2. **Geometry.** Use the size the **OS** draws it at, not the file's pixel size. Centre it on the **full screen**, not the safe area.
3. **First frame.** Decode the image **before `runApp`**. Otherwise frame 1 is a logo-less white screen, which is the very flash being removed.
4. **Scope.** Only the launch path uses this screen. The app's in-app loaders stay as they are.

## Workflow (do it in this order)

1. **Audit, read-only:** `bash $S/audit.sh`. It prints:
   - each platform's native splash artwork, its pixel sizes and layout attributes;
   - `flutter_native_splash` leftovers;
   - what the entry point awaits before `runApp`;
   - the initial route;
   - existing loaders and `loadingWidget:` sites.
2. **Find the white screen in code; don't guess.** Work out which widget paints the first frame after the native splash. Usually it is either:
   - the **loader of the first route's gate** (localization, auth or remote-config scope), or
   - a **root widget that swaps `MaterialApp` for a spinner**. That second shape is a bug of its own; see the rules below.
3. **Agree the look with the user, and WAIT.** Recommend:
   - **indeterminate** bar (a single request has no honest percentage);
   - bar colour = the logo's dominant colour on a light track;
   - Android 12+ gets its own artwork **if its native splash differs**;
   - **no text**: the strings may be exactly what is loading. Ask even about a screen-reader label; one owner asked for none.
4. **Implement** from [reference/dart.md](reference/dart.md), one piece at a time:
   1. an SDK-level channel (Android only);
   2. the 4x launch asset: `bash $S/make-launch-asset.sh <src> <w> <h> <out>`;
   3. a `LaunchArtwork` value object;
   4. the precache in the bootstrap, before `runApp`;
   5. `LaunchLoadingScreen`;
   6. wire it as the first gate's `loadingWidget`, plus any pre-init fallback.
5. **Test** with the templates in [reference/dart.md](reference/dart.md). Then format, analyze, and run the full suite.
6. **Verify on devices** with a **fresh install** (no caches), because a warm launch leaves the screen within a frame or two:
   - iOS simulator;
   - Android < 12 emulator;
   - Android 12+ emulator;
   - RTL if the app has it;
   - a warm relaunch, which must show **no bar**.

   Recipe: [reference/native-splash.md § Verify](reference/native-splash.md#verify-on-devices).

## Target state

| Piece | What it is |
|---|---|
| Native splash | Unchanged. It is the source of truth for artwork and geometry. |
| `LaunchArtwork` | One const per native variant: `{asset, logical size}`.<br>`forDevice(isAndroid, sdkInt)` is a pure function.<br>`provider(dpr)` is the **only** place the `ImageProvider` is built.<br>`precache()` runs with no context. |
| Launch asset | A copy of the native art at **4x** its logical size, e.g. 288 dp → 1152 px. |
| SDK channel | `MainActivity` returns `Build.VERSION.SDK_INT`. It is read once in the bootstrap. A failure means the pre-12 artwork. |
| Bootstrap | `… → device info → LaunchArtwork.current.precache() (capped ~300 ms) → runApp` |
| `LaunchLoadingScreen` | `Material(white)` → `Stack(expand)`:<br>• the logo, `Center`ed on the full screen, fixed logical size, `gaplessPlayback`;<br>• `SafeArea` → bottom-centre indeterminate bar, faded in after ~400 ms. |
| Wiring | The first route gate's `loadingWidget:`, plus the pre-init fallback if there is one. **Not** the shared in-app loader. |

## Native geometry at a glance

| Platform | Drawn by | Logical size on screen |
|---|---|---|
| iOS | `LaunchScreen.storyboard`, an `imageView` pinned to all edges, `contentMode="center"` | the image's **@1x pixel size**, in points |
| Android < 12 | `launch_background.xml` `<bitmap android:gravity="center">` | the **mdpi** file's pixel size, in dp |
| Android ≥ 12 (API 31) | `values-v31` `windowSplashScreenAnimatedIcon` | **288×288 dp** masked to a 192 dp circle.<br>With `windowSplashScreenIconBackgroundColor`: **240×240 dp** masked to 160 dp.<br>The drawable's own pixel size is **ignored**. |

A storyboard that uses `scaleAspectFit` or explicit width/height constraints, or a `UILaunchScreen` Info.plist dictionary, draws differently. Read [reference/native-splash.md](reference/native-splash.md) before copying these numbers.

## Hard-won rules

- **Read the native files, not the generator config.**
  - `flutter_native_splash.yaml` outlives the package: it was removed from `pubspec.yaml` while its generated storyboard, drawables and styles stayed.
  - The native files are what actually ships.
- **Centre on the full screen.** The OS centres its splash on the whole window. A `SafeArea` around the logo shifts it by half the status bar at the handoff.
- **Fixed logical sizes are correct here.** They are a documented exception to any "size from MediaQuery" house rule: the OS draws a fixed pt/dp size, so a screen fraction makes the logo jump.
- **Precache before `runApp`, without a `BuildContext`.**
  - `Image.asset` loads asynchronously, so the first frame is blank without this.
  - Resolve `provider(dpr)` through `ImageConfiguration(bundle: rootBundle, devicePixelRatio: dpr)`.
  - Keep the listener until a post-frame callback, exactly as Flutter's `precacheImage` does.
  - Build the provider in **one function**: `ResizeImage` keys include the decode width, so any drift between the precache and the widget makes the cache miss silently.
- **Cap the precache** (~300 ms). A logo must never hold startup.
- **Ship a 4x copy of the art.** Android 12 generators emit 3840² PNGs, about 59 MB decoded, to decode on the startup path. Decode at `logical × dpr` through `ResizeImage` as well.
- **Delay the bar (~400 ms).** A warm launch (cached data) leaves this screen within a frame or two. Without the delay, the bar blips between splash and first screen.
- **Scope it to the launch path.** Pass it as the first route gate's `loadingWidget`.
  - Restyling the shared in-app loader puts the logo in front of every tab switch.
  - Check that the gate's route has no in-page trigger (for example a language switcher) that would re-show it mid-session.
- **Never swap the root `MaterialApp` for a loader on a state the gate owns.** It unmounts the gate, including its retry, and strands a fresh install on a spinner. This happened, and cost a TestFlight release.
- **Give the gate a ceiling** (e.g. `maxBlockingWait: 10 s`). Past it, render the first screen untranslated or degraded rather than keep the user on the splash.
- **Android SDK level needs native code.** `Platform.operatingSystemVersion` is the kernel string. Use a ~10-line `MethodChannel` rather than adding a device-info package for one integer.

## Checklist (walk it with the user)

- **Dark mode:** `values-night-v31` and `drawable-night-*` variants. Either match them in Dart, or confirm the app forces a light splash.
- **Icon background:** is `windowSplashScreenIconBackgroundColor` set? Then use 240/160 dp, and paint the background circle in Dart too.
- **Branding image** (`windowSplashScreenBrandingImage`): it sits at the bottom, exactly where the bar goes. Move the bar or drop the branding.
- **OEM skins:** Samsung One UI and others size the Android 12 icon differently. Check a real device if one is available.
- **iOS caches launch screens.** After editing the storyboard, delete the app and restart the simulator, or you test the old one.
- **Android < 12:** `windowDrawsSystemBarBackgrounds=false` and `windowFullscreen` affect the window's centre. Compare the handoff frame by frame.
- **iPad / tablets:** the same pt/dp sizes apply. Verify there too.
- **Accessibility:** give the logo a `semanticLabel` in the active culture. Add a bar `semanticsLabel` only if the user wants one.

## This project: desktop targets (macOS + Windows)

macOS and Windows have no native launch screen: the window opens straight onto the first Flutter frame. On desktop the handoff is only the Dart half — precache the launch logo before `runApp`, show `LaunchScreen` (same logo, same progress bar) while bootstrap runs (DB open, `RecoveryService.run()`, queue start), and set the native window background colour (`window_manager` `backgroundColor`, plus `MainFlutterWindow` / `win32_window` background) to the launch background `#0B0D14` so there is no white flash before the first frame. `LaunchArtwork` needs a desktop branch that returns the plain `splash.png`.
