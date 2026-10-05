# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Project

`tube_downloader` — a Flutter app for **macOS, Windows, Android and iOS** that downloads online videos (a single video, a whole playlist, or a batch of links) to local storage, with a download queue (progress / pause / resume / retry) and a local library of finished files. English + Arabic (RTL). Bundle / application ID `com.tubedownloader.app` (dev flavour `com.tubedownloader.app.dev`).

There is **no backend**. The app talks to YouTube through `youtube_explode_dart` (metadata, stream manifests, playlists), downloads streams itself, and merges / converts them with FFmpeg. Distribution is sideload only (Apple guideline 5.2.3 and Google Play policy reject YouTube downloaders).

- Implementation plan and decisions: `/Users/mostafasaad/.claude/plans/glimmering-humming-moonbeam.md` (owner-approved 2026-10-04).
- UI source of truth: the Google Stitch export in `../Tube_Downloader_design/` (screens + `DESIGN.md`), reconciled as described in [Design reconciliation](#design-reconciliation).
- Engine findings: [docs/spike/phase0.md](docs/spike/phase0.md).

## Project skills

Skills in [.claude/skills/](.claude/skills/) load themselves when their topic comes up. A skill's `description:` is its only trigger — when one fails to fire, sharpen the description rather than repeating the rule here.

| Skill | Covers |
|---|---|
| `codebase-conventions` | Search the whole of `lib/` by role before building anything; Clean Architecture layer rules; house naming; assets; strings via `context.l10n` |
| `state-safety` | `if (isClosed) return;` after every await; cancel subscriptions in `close()`; freezed states; sequence-asserted tests |
| `performance` | Widget classes over `_buildX()`; lazy lists with stable keys; throttled progress rebuilds; `cacheWidth` on every thumbnail |
| `rtl-a11y` | Directional layout, icon mirroring, bidi-isolated numbers, 2.0 text scale, 48dp targets, semantics |
| `adaptive-layout` | `WindowClass` (compact / medium / expanded), `AdaptiveShell`, master/detail, grids, desktop window rules |
| `download-errors` | `FailureMapper` → `Result.failure(AppFailure)` → failure state → `showFailureSnackBar/Dialog`; the exception → `FailureType` table |
| `review-gate` | Read-only pre-commit gate: `bash .claude/skills/review-gate/scripts/check.sh` |
| `flutter-flavors` | dev/prod flavours on iOS + Android (+ desktop notes) |
| `flutter-splash-launch` | Native splash → Dart launch screen handoff (+ desktop notes) |

## Common commands

Two flavoured entry points — **there is no `lib/main.dart`**; never run without `-t`.

```bash
flutter pub get
flutter gen-l10n                                            # after editing lib/l10n/*.arb
dart run build_runner build --delete-conflicting-outputs   # freezed, json_serializable, drift

# Run (iOS / Android / macOS have flavours; Windows has only -t)
flutter run --flavor development -t lib/main_dev.dart
flutter run --flavor production  -t lib/main_prod.dart
flutter run -d windows -t lib/main_dev.dart

flutter analyze --fatal-infos
flutter test --exclude-tags golden,network      # what CI runs
flutter test --tags network                     # real-YouTube smoke tests, local only
bash .claude/skills/review-gate/scripts/check.sh --tests
```

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) are **not committed**; CI regenerates them. Run both generators after cloning.

**Android builds on the owner's network (2026-10-04):** long downloads from Google hosts stall (no bytes, connection kept open), and `download.flutter.io` answers with a mismatched TLS certificate. Flutter's Gradle plugin fetches engine jars from `storage.googleapis.com`, and the multi-ABI debug jars (`armeabi_v7a_debug`, `x86_64_debug`) never finished downloading, which hangs `flutter build apk --debug` in dependency resolution with ~0 % CPU. Until they are cached, build debug APKs for one ABI: `flutter build apk --flavor development -t lib/main_dev.dart --debug --target-platform android-arm64`. (`flutter run` has no `--target-platform` flag — it already builds only for the connected device's ABI, arm64 on the emulator and modern phones.) All three **release** engine jars are cached, so `flutter build apk --flavor production -t lib/main_prod.dart --split-per-abi` is unaffected; profile jars are not cached yet. Diagnose a hung Gradle with `jstack <GradleDaemon pid>` (look for `ParallelResolveArtifactSet` / `SocketInputStream`) and `lsof -a -p <pid> -i TCP`.

## Architecture

### Entry-point pipeline (`lib/core/app_bootstrap.dart`) — order is load-bearing

0. `installLoggingPolicy(config)` — first, before anything can log. Mutes the global `debugPrint` unless `AppConfig.verboseLogging`, and returns the real console, which the two error handlers use. Stream URLs are tied to the user's IP address: never log them in production.
1. `runZonedGuarded` + `FlutterError.onError`.
2. *(Phase 1)* `setupGetIt(config)` → open the drift database → read settings (theme mode, locale) → `runApp`.
3. *(Phase 2)* `RecoveryService.run()` → `DownloadQueueService.start()` — recovery must finish before the queue pumps.

### Layers (Clean Architecture + Track View conventions)

Per feature: `data/` → `domain/` → `logic/` → `presentation/`.

- `domain/` — pure Dart: freezed entities, repo **contracts**, use cases (only where they do something). No Flutter, `dart:io`, drift or plugin imports (review-gate blocks it).
- `data/` — implementations (`XRepoImpl implements XRepo`), drift DAOs, the YouTube resolver, transports, FFmpeg, platform channels.
- `logic/` — Cubits (never full Blocs) with freezed sealed-union states; depend on contracts/use cases injected through the constructor.
- `presentation/` — screens and widgets; no business logic.

The **download core** is shared by four features and lives in `lib/core/download_core/` (`domain/` + `data/`): entities, `TaskStateMachine`, `DownloadQueueService`, `RecoveryService`, resolver/transport/muxer contracts and their implementations, repos, file naming. Features never build a second resolver, queue or progress pipeline.

```
UI (BlocBuilder/BlocSelector) → Cubit → contracts / use cases → *_impl (drift, youtube_explode, HttpClient, FFmpeg)
                                   ↘ DownloadQueueService (lazy singleton: commands in, drift watch + live progress out)
```

### State, DI, routing

- **State:** `flutter_bloc` Cubits only; states are `freezed` sealed unions. `getIt<SomeCubit>()` from `BlocProvider.create`, never constructed inline. One `BlocProvider` at the smallest subtree that needs it; justify any `MultiBlocProvider`.
- **DI:** `get_it`. `setupGetIt()` is the ordered start-up block plus one `register<Feature>Dependencies(getIt)` call per file in `lib/core/di/modules/`. Repos and services `registerLazySingleton`; cubits `registerFactory`; `AppearanceCubit` is an app-root singleton. A DI-graph test fails on duplicate or missing registrations.
- **Routing:** `go_router`, `StatefulShellRoute.indexedStack` with four branches (New · Downloads · Library · Settings) rendered by `AdaptiveShell`; task details is a pushed route on compact windows and a side pane on expanded ones.
- **Persistence:** drift for everything durable — tasks, legs, events, groups, library, settings (single row, incl. theme mode and locale). Live progress is **not** written per tick; it streams from `DownloadQueueService.live`.

### Engine notes (read [docs/spike/phase0.md](docs/spike/phase0.md) before touching the engine)

- `youtube_explode_dart` 3.1.0's default clients get HTTP 403 on adaptive audio. The app defines a `visionOs` `YoutubeApiClient` itself; the client list is injected `EngineConfig`, never hard-coded at a call site.
- Streams are throttled per connection (~0.5 MB/s): the transport downloads each leg as parallel ranged chunks.
- Persist a `FormatSelector` (kind, max height, codec/audio preference, container), **never** itags or URLs — URLs expire and are bound to the IP; each leg is resolved just in time.
- Age-restricted and live videos are explicitly unsupported (`FailureType.ageRestricted` / `liveNotSupported`).
- FFmpeg: `ffmpeg_kit_flutter_new_audio` (LGPL; includes lame for MP3). Merges use `-c copy`.
- **Transport** (`ChunkedHttpTransport`): 8 workers × 4 MB ranged chunks per leg, 20 s stall timeout per chunk with retries, chunks appended IN ORDER so the file is always a contiguous prefix — **resume = file length**. 403/410 fail at once as `streamExpired` (the job re-resolves the leg once); 429 fails as `rateLimited` (the queue sets the global cooldown on the `ResolveGate`). One `RandomAccessFile` must never have two pending writes: a single flusher writes.
- **Quality = YouTube's label class**, not pixel height: "1080p60" → 1080, also for a letterboxed 1920×800 film and a portrait 1080×1920 Short (`StreamCandidate.height`).
- **Job / queue / recovery** (`lib/core/download_core/domain/services/`): `DownloadJob` runs one task end to end; `DownloadQueueService` (lazy singleton) owns slots, backoff, rate-limit strikes, the offline and Wi-Fi-only gates, live progress and outcomes; `RecoveryService` runs in bootstrap before `queue.start()`. On resume a leg continues only if the freshly resolved stream has the same itag and size; otherwise its partial file is discarded.
- Real-YouTube checks are tagged `network`: `flutter test --tags network` (resolver smoke test + an end-to-end M4A download through the real pipeline — 11.3 MB in 37 s on 2026-10-04).
- **iOS/macOS integration tests:** `FLUTTER_TARGET` is pinned at target level on the **Release and Profile** configurations only (owner decision 2026-10-04); Debug configurations follow the CLI `-t`, so on-device tests work: `flutter test integration_test/ffmpeg_muxer_test.dart -d macos --flavor development` (FFmpeg inside the real app — merge, MP3, failure path). The archive guard is unaffected: archives are Release.
- **Long waits in integration tests use real time** (`await Future<void>.delayed(...)`), never `tester.pump(...)`: a live pump waits for a frame, and macOS sends none while the test window is hidden or the display sleeps — the test then stalls for minutes and looks like a slow download or merge. `single_download_flow_test` prints the task's event timeline (merge of a 12-min 360p video: < 1 s).
- **Full-app widget tests** build the app on `testDatabase()` and end with `await unmountApp(tester)` (`test/helpers/app_harness.dart`). `testDatabase()` sets drift's `closeStreamsSynchronously`: by default drift stops a watched query on a zero-length timer, which fake time never runs — the test then fails with "A Timer is still pending" and tearDown's database close hangs with 0 % CPU. Seed data in `setUp` (real time), not in the test body.
- **App Nap:** `DownloadQueueService` holds an `ActivityAssertion` (macOS: `ProcessInfo.beginActivity` over the `com.tubedownloader.app/activity` channel in `MainFlutterWindow.swift`) from the first running job to the last, so a background window keeps full-speed timers and network. Best effort — a failing channel never fails a download.
- **Multiple links:** the text box is the source of truth. `LinkBatchAnalyzer` (pure) splits it into entries (prose ignored, duplicates marked); `BatchLinksCubit` fetches metadata one video at a time and never twice; removing a row edits the text. Drops (`.txt` / `.webloc` / `.url`) and the clipboard banner go through `LinkInputCubit.receive`: one link opens in its tab, several go to Multiple.
- **Library:** finished videos keep a local thumbnail (`ThumbnailStore`, `<Application Support>/thumbs/`, saved by the job before the library row — best effort), so the grid works offline. `CheckMissingFilesUseCase` runs when the Library opens and flags rows whose file was moved or deleted. Deleting removes files (via `FileSystemGateway.deletePublished`, which maps its own errors — the domain never sees `dart:io`), then thumbnails, then rows; a file that can't be deleted keeps its row. `FileLauncher` is the one place for open (all platforms; `open_filex` on phones), show in folder (desktop), share (`share_plus`; pass the tapped widget's rect — iPad requires it) and Save to Photos (`gal`, phones, videos only; iOS needs both `NSPhotoLibrary*UsageDescription` keys, Android ≤ 10 `WRITE_EXTERNAL_STORAGE`). The grid is rows of `Expanded` cards in `IntrinsicHeight` — nothing inside a card may use `LayoutBuilder` (it can't report intrinsic sizes); `MediaThumbnail(width: null)` fills the card instead.
- **Runner channels** (native code we own; keep Dart and native in step): `com.tubedownloader.app/activity` (macOS App Nap), `/storage` ("space" → free/total bytes: Swift in `MainFlutterWindow.swift` and `AppDelegate.swift`, Kotlin `StatFs` in `MainActivity.kt`; Windows asks `GetDiskFreeSpaceExW` through `dart:ffi` in `windows_disk_space.dart`), `/mediastore` (Android "publish"), `/share` (Android share sheet: "initialText" + "shared"). The free-space check in `DownloadJob` (1.1 × what is left + room for the merge) is live wherever `space()` answers.
- **Android files** (owner decision 2026-10-05): finished files go through MediaStore to `Movies|Music/Tube Downloader[/playlist]` on Android 10+ (written pending, then published; no permission); Android 7–9 use the app's external Movies/Music folder + a media scan (no prompt; removed on uninstall). The folder picker is desktop-only. `requestLegacyExternalStorage` lets Android 10 read published files by path.
- **Notifications:** `DownloadNotifier` turns queue outcomes into banners only when the setting is on and the app is not in front; permission is asked when the user turns the setting on and before the first banner. `flutter_local_notifications` needs core-library desugaring on Android. **`connectivity_plus` is pinned to 7.3.1**: 7.3.2 moved Linux to dbus 0.8, which `flutter_local_notifications_linux` (dbus ^0.7.8) can't share — lift the pin when it can.
- **Share target:** Android only for now, through our own `/share` channel (`receive_sharing_intent` 1.9 needs compileSdk 37, above what AGP 9.1 supports). The iOS share extension is deferred (owner decision 2026-10-05; it needs the owner's Apple team and an App Group).
- **Brand assets:** the icon and splash come from SVGs in `assets/icon/source/` ("The Drop Tube", Stitch brand board). `./tool/render_icons.sh` renders them with headless Chrome (it draws the blur filters faithfully); `dart run flutter_launcher_icons` (config `flutter_launcher_icons.yaml`, both flavours share one icon) and `./tool/make_splash.sh` place them. **After `flutter_launcher_icons`, revert its edit to `ios/Runner.xcodeproj/project.pbxproj`**: it wrongly sets `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon` (must stay `YES`). The splash is dark (#0B0D14) with the mark everywhere: iOS storyboard 160 pt, Android `launch_image` 160 dp, Android 12+ `splash_icon` on the 288 dp canvas, and `values-night-v31` too (night outranks the API level).
- **Releases:** [docs/release.md](docs/release.md) (Android keystore via git-ignored `android/key.properties` — debug key when absent; notarized DMG; Inno Setup script `windows/installer/tube_downloader.iss`; iOS ad-hoc / internal TestFlight). Licences Flutter can't collect itself are registered in `lib/core/configs/licenses.dart` (Almarai OFL from `assets/fonts/OFL.txt`, the FFmpeg LGPL source notice).
- **macOS runs unsandboxed** (Developer-ID distribution, no App Store): `app-sandbox` is false in both entitlement files, so the app reads/writes the user's chosen folders and the network without extra entitlements. Its data lives in `~/Library/Application Support/com.tubedownloader.app(.dev)/`.

## Engineering rules (all new code and any refactor)

> **Act like a senior mobile engineer.** Every decision — architecture, naming, state, layout, error handling — is deliberate, defensible, consistent with the codebase, and explained when non-obvious.

### 1. Architecture & paradigms
- **SOLID**, especially Single Responsibility and Dependency Inversion: cubits depend on contracts, never on drift, `HttpClient`, `YoutubeExplode` or a plugin.
- **Patterns:** Factory for construction (engine/transport selection), **Strategy** for variable behaviour (`MediaResolver`, `MediaTransport`, `MediaMuxer` implementations chosen per platform by config) instead of `if (Platform.isX)` ladders in business code.
- **Clean code:** self-documenting names; one method = one responsibility; extract UI into named private widget **classes** (never `Widget _buildX()`).
- **DRY:** search the whole of `lib/` by role before writing a card, chip, dialog, field, empty state or helper (`codebase-conventions` skill). Shared UI in `lib/core/widgets/`, helpers in `lib/core/helpers/`.

### 2. State management
- Cubits only; no `setState` for business state; no business logic in widgets.
- Immutable freezed states; UI reacts only via `BlocBuilder` / `BlocConsumer` / `BlocSelector` / `BlocListener`.
- **Guard every `emit` after an `await` with `if (isClosed) return;`, and cancel every subscription in `close()`** (`state-safety` skill).

### 3. UI / UX & responsiveness
- **Sizing from `MediaQuery.sizeOf` / `LayoutBuilder` only** — `flutter_screenutil` is banned. No raw pixel magic numbers in feature code; use `Dimens` and the spacing helpers.
- **Layout structure branches on `windowClassOf(context)`** (width-based); phone-vs-tablet component density on `isLargeScreen(context)` (`adaptive-layout` skill). Verify every screen from the minimum desktop window (1024×680) to full screen, on phone and tablet.
- **RTL:** never a `TextDirection` literal (except the shared `LtrText` for URLs/paths) or physical padding/alignment (`rtl-a11y` skill).
- **Colours** come from `ColorsManager` (brand/status) and `context.colors` (theme tokens, dark + light). No `Color(0x…)` / `Colors.*` outside `colors_manager.dart`.
- **Spacing** via `verticalSpace` / `horizontalSpace`; **text** via `Styles.font<size><Weight>` + `.copyWith(color: …)`; weights via `FontWeightHelper`. No bare `TextStyle(` / `FontWeight.w600` in feature code.
- **Numbers shown to the user** (sizes, speeds, %, durations, dates) go through `lib/core/helpers/formatters.dart`, which also bidi-isolates them.
- **Animations** via `flutter_animate`; no `lottie` / `rive`.
- **Strings** via `context.l10n.<key>`; every key in both `app_en.arb` and `app_ar.arb`.

### 4. CI/CD & DevOps
- Every PR passes [quality.yml](.github/workflows/quality.yml): code generation, whole-repo format check, `flutter analyze --fatal-infos`, the review gate, `flutter test --exclude-tags golden,network`.
- **Flutter is pinned to 3.47.5.** An SDK upgrade is one deliberate commit that bumps the pin, fixes new diagnostics and re-records goldens on macOS.
- No secrets or environment-specific values in code. Signing material never enters git (review-gate blocks key files).

### 5. Working style
- Explain the "why" for non-trivial code in a one-line comment.
- No black boxes: readability over clever one-liners.
- Refactor within the bounds of the requested change; flag larger refactors as follow-ups.
- Tests are expected **green**; run `flutter test` before and after a change and treat any new failure as yours.

## Library conventions (don't introduce alternatives without approval)

| Concern | Choice |
|---|---|
| State | `flutter_bloc` (Cubit) + `freezed` states |
| DI / routing | `get_it` / `go_router` |
| Models | `json_serializable` for JSON (engine config, `format_json`); `freezed` for entities and states — never `equatable` |
| Results | freezed `Result<T>` + `AppFailure` (`lib/core/error/`) — never `dartz` |
| Persistence | `drift` + `drift_flutter` (no `shared_preferences`, `hive`, `isar`) |
| Engine | `youtube_explode_dart`, own `dart:io` `HttpClient` transport (no `dio`), `ffmpeg_kit_flutter_new_audio` |
| Platform | `path_provider`, `file_picker`, `permission_handler`, `share_plus`, `url_launcher` (desktop open), `open_filex` (mobile open), `window_manager`, `desktop_drop`, `receive_sharing_intent`, `flutter_local_notifications`, `connectivity_plus` |
| UI | `flutter_animate`, `flutter_svg`, bundled **Almarai** (Light 300 / Regular 400 / Bold 700 / ExtraBold 800) |
| Tests | `flutter_test`, `bloc_test`, `mocktail`, `fake_async` + `clock`, drift `NativeDatabase.memory()` |

The review gate's banned list (`banned_reason` in `check.sh`) is the enforced version of this table.

## Design reconciliation

The Stitch mocks invent telemetry the engine cannot provide. **Do not build:** engine/parser/"parallel slots" status badges, the profile avatar and ⚡ button, "estimated download time", "Turbo", threads/chunks counters, socket latency, CDN names, "Save Queue Preset", the Library "Favorites" chip, "Lossless Stream Ready", the storage System/Other split. **Replace:** playlist pagination → a lazy list; "Stream Inspector" log → the real task event timeline; storage card → free/total of the save volume; "Queue & Pipeline" → the route title. Desktop Library/Settings, empty/error/permission states, light theme and RTL were not delivered by Stitch — derive them from the delivered components and verify by running the app.

Tokens: use the brief's named tokens (dark `#0B0D14` / `#141824` / `#1C2130` / `#262C3D`, light `#F6F7FB` / `#FFFFFF` / `#F0F2F8` / `#E3E6EF`, primary `#6C5CE7`, accent `#00C2FF`, success `#22C55E`, warning `#F5A524`, error `#EF4444`, paused `#94A3B8`). Ignore the auto-generated Material 3 tonal set in the Stitch `DESIGN.md` front-matter.
