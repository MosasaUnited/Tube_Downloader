# Dart side — templates, wiring, tests

These templates are the code that shipped in the origin app, with its names replaced by placeholders:

| Placeholder | Meaning |
|---|---|
| `AppImages` | the project's asset-path constants |
| `AppColors` | the project's colour constants |
| `<app.id>` | the Android `applicationId` / package |
| `LoginView` | whatever gate owns the first route |

The origin repo's copy lives at:
- `lib/core/helpers/launch_artwork.dart`
- `lib/features/login/presentation/widgets/launch_loading_screen.dart`
- `lib/core/app_bootstrap.dart`
- `android/app/src/main/kotlin/**/MainActivity.kt`
- `test/launch_artwork_test.dart`
- `test/launch_loading_screen_test.dart`
- `test/first_launch_localization_test.dart`

Follow the host project's conventions over these templates: its colour and asset constants, its logging, its folder rules. For example, keep `LaunchArtwork` out of any feature folder if `core/` may not import features; the bootstrap needs it.

## 1. Android SDK level over a method channel (only if Android 12+ art differs)

`Platform.operatingSystemVersion` on Android is the **kernel** string, not the API level. A tiny channel is lighter than a device-info package added for one integer.

```kotlin
// MainActivity.kt — inside configureFlutterEngine, after super.configureFlutterEngine(...)
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
    .setMethodCallHandler { call, result ->
        if (call.method == "androidSdkInt") result.success(Build.VERSION.SDK_INT)
        else result.notImplemented()
    }
// companion object:  const val DEVICE_INFO_CHANNEL = "<app.id>/device_info"
// import android.os.Build
```

```dart
// In whatever startup service the bootstrap already awaits (e.g. an AppInfoService):
@visibleForTesting
static const MethodChannel deviceInfoChannel = MethodChannel('<app.id>/device_info');

int? _androidSdkInt;
int? get androidSdkInt => _androidSdkInt;   // null on iOS or on failure

Future<void> initialize() async {
  // …existing work…
  if (Platform.isAndroid) {
    try {
      _androidSdkInt = await deviceInfoChannel.invokeMethod<int>('androidSdkInt');
    } catch (e) {
      debugPrint('Error getting the Android SDK level: $e'); // null → pre-12 art
    }
  }
}
```

## 2. The launch asset

Copy the native art at **4x** its logical size, so it stays sharp up to 4.0 dpr but is still cheap to decode:

```bash
bash $S/make-launch-asset.sh assets/images/splash_12.png 288 288 assets/images/splash_12_launch.png   # → 1152²
```

- **iOS / Android < 12 art** is usually already a 4x file, e.g. an 800×400 source drawn at 200×100. Reuse it.
- **Asset constant:** add one, with a comment naming the source file and the regeneration command.

## 3. `LaunchArtwork` — one value object per native variant

```dart
@immutable
class LaunchArtwork {
  const LaunchArtwork._({required this.asset, required this.size});

  final String asset;
  final Size size; // the size the OS draws it at — deliberately fixed, not from MediaQuery

  static const wide = LaunchArtwork._(asset: AppImages.splashLogo, size: Size(200, 100));
  static const android12 = LaunchArtwork._(asset: AppImages.android12LaunchLogo, size: Size(288, 288));

  static const int android12SdkInt = 31; // same cut-off as the -v31 resources
  static const Duration _precacheTimeout = Duration(milliseconds: 300);

  static LaunchArtwork forDevice({required bool isAndroid, required int? androidSdkInt}) {
    final isAndroid12OrLater = isAndroid && androidSdkInt != null && androidSdkInt >= android12SdkInt;
    return isAndroid12OrLater ? android12 : wide;
  }

  static LaunchArtwork get current => forDevice(
    isAndroid: Platform.isAndroid,
    androidSdkInt: AppInfoService.instance.androidSdkInt,
  );

  // The ONE place the provider is built: the precache and the widget must share its cache key.
  ImageProvider provider(double devicePixelRatio) =>
      ResizeImage(AssetImage(asset), width: (size.width * devicePixelRatio).round());

  // precacheImage() without a BuildContext — none exists before runApp.
  Future<void> precache() async {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;

    final stream = provider(view.devicePixelRatio).resolve(ImageConfiguration(
      bundle: rootBundle,
      devicePixelRatio: view.devicePixelRatio,
      platform: defaultTargetPlatform,
    ));
    final loaded = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, _) {
        if (!loaded.isCompleted) loaded.complete();
        // Keep the image alive until the first frame has subscribed to it.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          image.dispose();
          stream.removeListener(listener);
        });
      },
      onError: (error, _) {
        if (!loaded.isCompleted) loaded.complete();
        stream.removeListener(listener);
        debugPrint('Launch logo precache failed: $error');
      },
    );
    stream.addListener(listener);
    await loaded.future.timeout(_precacheTimeout, onTimeout: () {});
  }
}
```

- **One platform only:** with a single native variant, drop `forDevice`, `current` and the channel. Keep `provider` and `precache`.
- **Masked art:** if the Android 12 art has content outside the 192 dp circle, wrap the 288 dp image in `ClipOval(child: SizedBox.square(dimension: 192, child: OverflowBox(maxWidth: 288, maxHeight: 288, child: …)))`.

## 4. Bootstrap — decode before `runApp`

```dart
await AppInfoService.instance.initialize();   // resolves the SDK level
await LaunchArtwork.current.precache();       // native splash still covers the screen; capped
// …remaining pre-runApp steps…
runApp(const App());
```

If the project documents its startup order (a CLAUDE.md pipeline, say), add the step there too.

## 5. `LaunchLoadingScreen`

```dart
class LaunchLoadingScreen extends StatelessWidget {
  const LaunchLoadingScreen({super.key, this.artwork});
  final LaunchArtwork? artwork; // test seam; defaults to this device's variant

  @override
  Widget build(BuildContext context) {
    // Material, not Scaffold: it is often the outermost widget under a gate, and
    // a nested Scaffold re-applies insets.
    return Material(
      color: AppColors.white, // = the native splash background
      child: Stack(
        fit: StackFit.expand,
        children: [
          _LaunchLogo(artwork: artwork ?? LaunchArtwork.current),
          const _LaunchProgressBar(),
        ],
      ),
    );
  }
}

class _LaunchLogo extends StatelessWidget {
  const _LaunchLogo({required this.artwork});
  final LaunchArtwork artwork;

  @override
  Widget build(BuildContext context) {
    return Center( // the FULL screen — no SafeArea
      child: Image(
        image: artwork.provider(MediaQuery.devicePixelRatioOf(context)),
        width: artwork.size.width,
        height: artwork.size.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: '<product name, in the active culture>',
      ),
    );
  }
}

class _LaunchProgressBar extends StatelessWidget {
  const _LaunchProgressBar();
  static const double _width = 200;       // the wide logo's width → one lock-up
  static const double _thickness = 4;
  static const double _bottomOffsetFraction = 0.08;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * _bottomOffsetFraction),
          child: SizedBox(
            width: _width,
            child: LinearProgressIndicator( // indeterminate; mirrors under RTL by itself
              minHeight: _thickness,
              color: AppColors.brand,
              backgroundColor: AppColors.track,
              borderRadius: BorderRadius.circular(_thickness / 2),
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 250.ms), // flutter_animate
        ),
      ),
    );
  }
}
```

- **Animation:** without `flutter_animate`, the same reveal is a `FutureBuilder`/`Timer` flag that flips an `AnimatedOpacity`. Keep the ~400 ms delay either way.
- **Text:** none by default. If the project wants a label before translations exist, pick it by culture from the persisted locale, never from the loading strings.

## 6. Wiring — only the launch path

- **The first route's gate.** Pass the screen as that gate's loader, e.g. `LocalizationScope(loadingWidget: LaunchLoadingScreen(), maxBlockingWait: Duration(seconds: 10), …)`, or the auth gate's `loading:` branch.
- **A pre-init fallback.** Some root widgets show a loader before a cubit's first state, often inside its own `MaterialApp`. Point that at the same screen, and keep the `MaterialApp` so there is `Directionality`, `MediaQuery` and `Material`.
- **Leave the shared in-app loader alone.**
- **Check the gate's route has no in-page action** (such as a language switch) that would bring the splash back mid-session.

## 7. Tests

**Pitfalls, each learned the hard way:**
- **Test surface.** The default surface is 800×600, a *tablet* to a 600-shortest-side breakpoint. Set `tester.view.physicalSize` / `devicePixelRatio` to a phone, with `addTearDown(tester.view.reset)`.
- **`flutter_animate`** starts on a zero-delay timer: `pump(Duration.zero)` before any long `pump`.
- **Never `pumpAndSettle`** with an indeterminate bar on screen; it never settles.
- **End every test** by pumping a `SizedBox` and then `pump(1 s)`, so no reveal timer outlives the test.
- **Real decoding** needs `tester.runAsync`.

```dart
// launch_artwork_test.dart
test('forDevice', () {
  expect(LaunchArtwork.forDevice(isAndroid: false, androidSdkInt: null), same(LaunchArtwork.wide));
  expect(LaunchArtwork.forDevice(isAndroid: true,  androidSdkInt: 30),   same(LaunchArtwork.wide));
  expect(LaunchArtwork.forDevice(isAndroid: true,  androidSdkInt: 31),   same(LaunchArtwork.android12));
  expect(LaunchArtwork.forDevice(isAndroid: true,  androidSdkInt: null), same(LaunchArtwork.wide));
});

test('asset is bundled with 4x pixels', () async {           // per variant
  final bytes = await rootBundle.load(artwork.asset);
  final frame = await (await ui.instantiateImageCodec(bytes.buffer.asUint8List())).getNextFrame();
  expect(frame.image.width, artwork.size.width * 4);
});

testWidgets('precache fills the exact key the screen reads', (tester) async {
  final key = await tester.runAsync(() => LaunchArtwork.android12
      .provider(tester.view.devicePixelRatio).obtainKey(ImageConfiguration(bundle: rootBundle)));
  await tester.runAsync(LaunchArtwork.android12.precache);
  expect(PaintingBinding.instance.imageCache.statusForKey(key!).keepAlive, isTrue);
  await tester.pump(); // releases the listener, as the first frame would
});

// launch_loading_screen_test.dart — per variant, on a phone surface
expect(tester.getSize(find.byType(Image)), artwork.size);
expect(tester.getCenter(find.byType(Image)), Offset(phone.width / 2, phone.height / 2)); // full-screen centre

// the reveal: hidden through a warm launch, then shown
await tester.pump(Duration.zero);
await tester.pump(const Duration(milliseconds: 300)); // opacity of the nearest FadeTransition above the bar == 0
await tester.pump(const Duration(milliseconds: 400)); // == 1

// indeterminate, brand colour, bottom centre, and no text anywhere
expect(tester.widget<LinearProgressIndicator>(bar).value, isNull);
expect(find.byType(Text), findsNothing);

// the gate uses it: pump the first route with a repo that never answers
expect(find.byType(LaunchLoadingScreen), findsOneWidget);
expect(find.byType(TheSharedInAppLoader), findsNothing);
```
