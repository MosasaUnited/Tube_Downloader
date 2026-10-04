# Native splash — how to read it, and what it draws

`S=.claude/skills/flutter-splash-launch/scripts` (from the project root). `bash $S/audit.sh` prints every fact
this page asks you to read. This page tells you what those facts mean.

The goal of this page is two numbers per platform: **which image**, and **what logical size, centred where**.
The Dart launch screen repaints exactly that.

## iOS — `LaunchScreen.storyboard`

1. **Which storyboard.**
   - It is named by `UILaunchStoryboardName` in `ios/Runner/Info.plist`, usually `LaunchScreen`.
   - A `UILaunchScreen` **dictionary** instead means there is no storyboard. It gives only a background colour or image name, and the image is drawn centred at its natural size.
2. **The image view that holds the logo.** Read its `contentMode` and its constraints:
   - **All four edges pinned to the superview, and `contentMode="center"`** (the `flutter_native_splash` default). The image is drawn at its natural size and is **never scaled**.
     - Natural size in points = the **@1x pixel size** in `Assets.xcassets/<name>.imageset/`.
     - Example: `LaunchImage.png` is 200×100, so the logo is drawn at 200×100 pt, centred on the whole screen.
   - **`scaleAspectFit` / `scaleAspectFill`**: the image fills the view's frame, so compute the size from the view's constraints.
   - **Explicit width/height constraints**: use them. Centring comes from `centerX`/`centerY` constraints to the superview.
3. **Background.** `<color key="backgroundColor" …>` on the root view, and/or a full-bleed background image (`LaunchBackground`, often 1×1).
4. **The `<resources>` section.** `<image name="LaunchImage" width="800" height="400"/>` there is Interface Builder's design-time record of the source pixels. It is **not** the drawn size.
5. **Cache trap.** iOS caches the launch screen snapshot. After changing the storyboard or its images, **delete the app and restart the simulator/device**, or you are looking at the old one.

## Android below 12 (API ≤ 30) — `LaunchTheme` → `windowBackground`

1. **The theme.** In `android/app/src/main/AndroidManifest.xml`, the activity's `android:theme` is usually `@style/LaunchTheme`, defined in `res/values/styles.xml`.
2. **The layer list.** `android:windowBackground` points at `@drawable/launch_background` (look in `drawable/` and `drawable-v21/`). Each `<item>` holds either:
   - `<bitmap android:gravity="fill" …>`: the background, or
   - `<bitmap android:gravity="center" android:src="@drawable/splash"/>`: the logo.
3. **Size.** `gravity="center"` draws the bitmap at its density-scaled natural size. **The mdpi file's pixel size is the dp size.**
   - Example: `drawable-mdpi/splash.png` at 200×100 is drawn at 200×100 dp.
   - Check the other densities follow 1.5x / 2x / 3x / 4x: `hdpi` 300×150, `xhdpi` 400×200, `xxhdpi` 600×300, `xxxhdpi` 800×400. A density that breaks the ratio draws at a different size on those devices.
4. **Night mode.** `values-night/styles.xml` may define a different parent or background.
5. **Window flags.**
   - `windowFullscreen`, `windowDrawsSystemBarBackgrounds` and `windowLayoutInDisplayCutoutMode` decide whether the window, and so its centre, includes the status bar.
   - Flutter itself draws edge-to-edge. If the two disagree, the logo shifts vertically by about half the status-bar height at the handoff.
   - Only a frame-by-frame capture settles this (see *Verify*).

## Android 12+ (API ≥ 31) — the SplashScreen API

On API 31+, the system splash **replaces** `windowBackground` for the launch. The launch theme's `values-v31/styles.xml` (and `values-night-v31`) sets:

| Attribute | Meaning |
|---|---|
| `android:windowSplashScreenBackground` | the background colour |
| `android:windowSplashScreenAnimatedIcon` | the centred icon drawable (a PNG, vector or AVD) |
| `android:windowSplashScreenIconBackgroundColor` | *optional*: a filled circle behind the icon |
| `android:windowSplashScreenBrandingImage` | *optional*: an image at the bottom of the screen, where the progress bar would go |

**Size rules.** These are AOSP; the drawable's intrinsic pixel size is **ignored**:

| Icon background? | Drawable is scaled to | Visible (masked) area |
|---|---|---|
| no | **288×288 dp** | centred circle of **192 dp** diameter |
| yes | **240×240 dp** | centred circle of **160 dp** diameter |

`flutter_native_splash` emits `android12splash.png` at 960² (mdpi) up to 3840² (xxxhdpi). None of those pixels change the on-screen size: it is always 288 dp without an icon background.

**Masking.** Check whether any opaque content of the art falls **outside** the 192 dp circle (160 dp with a background):
- **If it does**, the OS clips it. The Dart side must `ClipOval` a 192 dp box around a 288 dp image.
- **If the art sits inside the circle** (the usual case, generators pad it), painting the whole 288 dp square on the same background colour is pixel-identical, and no clip is needed.
- To check, look at the image: the circle is the middle two-thirds of the square.

**OEM caveat.** Samsung One UI and some other skins draw the icon at a non-AOSP size. Compare on a real device when one is available.

**The API cut-off is 31** (Android 12), matching the `-v31` resource qualifier. Android 12L is API 32 and is already covered.

## Which artwork on which device

| Device | Native art | Dart `LaunchArtwork` |
|---|---|---|
| iOS | storyboard image, @1x size | `wide` (or whatever the storyboard shows) |
| Android API ≤ 30 | `launch_background` centre bitmap, mdpi size | usually the same art as iOS |
| Android API ≥ 31 | `windowSplashScreenAnimatedIcon`, 288/240 dp | its own variant |
| Android, SDK level unknown (channel failed) | — | fall back to the pre-12 variant |

## Verify on devices

A warm launch leaves the launch screen within a frame or two, so **test a fresh install**, where caches are empty and the wait is real.

**Clearing the cache without losing login state.** Deleting the app also wipes the user's configured base URL and login state. If that matters, clear only the cache keys instead:
- do it from inside the running app (for example by evaluating `SharedPreferences.remove` through the VM service);
- then terminate and relaunch.

Do **not** edit the prefs plist of a live simulator app: `cfprefsd` caches and rewrites it.

**Capture the handoff frame by frame, then compare.**

```bash
# iOS simulator: launch, then grab frames as fast as simctl allows (~3/s)
xcrun simctl terminate booted <bundle.id>; xcrun simctl launch booted <bundle.id>
for i in $(seq -w 1 20); do xcrun simctl io booted screenshot "frame_$i.png" >/dev/null 2>&1; done

# Android emulator
adb shell am force-stop <app.id>; adb shell am start -n <app.id>/.MainActivity
for i in $(seq -w 1 20); do adb exec-out screencap -p > "frame_$i.png"; done
```

Read the frames. Find the last native-splash frame and the first Dart frame, and compare the logo's bounding box in both. It must not move or change size; only the bar may appear.

**The run-through:**
1. Fresh install: native splash → the same logo, unmoved → the bar fades in → the first screen.
2. Warm relaunch: no bar ever visible.
3. RTL culture: the indeterminate bar sweeps right to left.
4. iPad / tablet: the logo is the same pt/dp size.
5. Android API 30 **and** API 33+ emulators.
6. A real OEM device if available.

Launching a debug build from the IDE also works. The tooling adds seconds before the first frame, but the handoff itself looks the same.
