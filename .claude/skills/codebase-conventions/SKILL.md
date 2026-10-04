---
name: codebase-conventions
description: Makes new code reuse what this repo already has and read like it — search the WHOLE of lib/ by role before building any widget, card, row, chip, dialog, sheet, form field, dropdown, header, empty/error state, cubit, repo, use case, service or helper (shared download widgets may live inside a feature tree, and the download core lives in lib/core/download_core); assets only through the AppImages / AppSvgs / AppIcons constants; strings only through context.l10n (ARB); house naming (routed *Screen, _repo / _repo_impl / _cubit / _state files, package:tube_downloader imports) and the Clean Architecture layer rules. Use before writing ANY new widget, screen, tab, card, dialog, sheet, cubit, repo, entity, use case, model or helper, and whenever a request says add, build, create, new, "like the other screens", "same as X but", "make it match", reuse, duplicate, copy, or merge clones. Trigger without being asked — a second copy compiles, looks right on its own screen and drifts from the rest.
---

# Codebase conventions — reuse before create

The costliest defect in a growing Flutter app is not a bug, it is a **second copy**. Track View (this repo's parent) paid for four dedup refactors — 6 project cards, 7 issue cards, 7 report cards, 28 tab cubits collapsed back into one each — and every clone had drifted and hidden a real bug. Review catches none of it: a clone is all additions and every line looks fine.

## 1. Search by role, across all of `lib/`, before creating the file

Grepping for the name you have in mind, finding nothing and building it is the failure. Search three ways:

1. **By suffix, across the whole tree** — never only `lib/core/widgets/`:
   ```bash
   grep -rnE "^class [A-Za-z0-9_]*(Card|Tile|Row)( |<)" lib --include='*.dart'
   ```
   Same for `Chip`, `Pill`, `Badge`, `Dialog`, `Sheet`, `Field`, `Dropdown`, `Header`, `Bar`, `Section`, `Content`, `Panel`, `Button`, `Menu`, `Track`, `Ring`, `Thumbnail`. Shared components live where their first screen lived until a second feature needs them.
2. **By each noun in the request separately** — "playlist item quality dropdown" means grepping `Playlist`, `Quality`, `Dropdown`, `Format`.
3. **The shared homes**, then the current feature's `presentation/widgets/`:

| Need | Look in |
|---|---|
| Buttons, URL field, segmented tabs, format/status chips, thumbnail, progress track/ring, section card, settings tile, empty/error/skeleton, dialogs, bottom sheet | `lib/core/widgets/` |
| Snackbars, failure presenter, dialogs entry points, formatters (bytes/speed/ETA/duration), spacing, breakpoints | `lib/core/helpers/` |
| Colours, text styles, radii/spacing scale, ThemeExtension | `lib/core/theme/` |
| Anything about resolving links, formats, the queue, transport, FFmpeg, file naming, the library or settings data | `lib/core/download_core/` (domain + data) — **never** a second resolver/queue inside a feature |
| Errors | `lib/core/error/` (`Result`, `AppFailure`, `FailureType`, `FailureMapper`) — `download-errors` skill |

```bash
grep -rnE "^(mixin|abstract class|abstract interface class|sealed class) " lib --include='*.dart'
```

Then **read** what you found. A widget that does 80% of the job is usually one parameter from 100%. **Say what you found and what you decided** — "found `StatusChip`, it has no Duplicate variant → adding `ItemStatus.duplicate`" is reviewable; a silent `DuplicateChip` is not.

### When a new component is the right answer
- Nothing found after all three searches.
- What exists is a different thing that merely looks alike.
- Extending it needs a flag that changes what it *is* — three or more independent booleans is two widgets sharing a coat.

Start feature-local in `presentation/widgets/`; the moment a **second** feature needs it, lift it into `lib/core/widgets/`.

### Sharing a component
- It never `context.read`s a host's cubit. The host injects callbacks (`onPause`, `onRetry`, `onDelete`).
- Surface differences are parameters or enums the component owns, never a fork.

## 2. Clean Architecture layer rules

Per feature: `data/` → `domain/` → `logic/` → `presentation/`. The download core in `lib/core/download_core/` has the same `data/` + `domain/` split.

- `domain/` is pure Dart: entities (freezed), repo **contracts** (`abstract interface class XRepo`), use cases. It imports nothing from `data/`, `logic/`, `presentation/`, Flutter UI, drift, `dart:io` HTTP or any plugin.
- `data/` implements the contracts (`XRepoImpl implements XRepo`), owns drift DAOs, the YouTube resolver, transports, FFmpeg, platform channels. Models map to entities here — entities never carry `@JsonKey` or drift types.
- `logic/` (cubits) depends on **contracts and use cases only**, injected via the constructor — never on an `Impl`, `AppDatabase`, `YoutubeExplode`, `HttpClient` or a plugin.
- Use cases only when they do something: combine repos, enforce a rule (`AnalyzeLinksUseCase`, `EnqueueDownloadsUseCase`). A use case that only forwards one repo call is noise — call the repo.
- `presentation/` composes widgets and dispatches to cubits. No business logic in widgets.

## 3. Values come from the house sources

The review gate blocks the first three on new code.
- **Text:** `Styles.font<size><Weight>` + `.copyWith(color: context.colors.x)`, weights from `FontWeightHelper`. A missing rung is added to `styles.dart`; `copyWith(fontSize:, fontWeight:)` means the rung is missing.
- **Colour:** `ColorsManager.<semanticName>` for brand/status, `context.colors.<token>` for theme-dependent surfaces/text. Raw `Color(...)` lives only in `colors_manager.dart`.
- **Direction:** `EdgeInsetsDirectional` / `AlignmentDirectional`, never a `TextDirection` literal (`rtl-a11y` skill).
- **Everything else:** `verticalSpace` / `horizontalSpace`, `Dimens` radii, `MediaQuery.sizeOf` + `windowClassOf(context)` / `isLargeScreen(context)` (`adaptive-layout` skill), the shared formatters, `flutter_animate`.

## 4. Assets — never invent a path

- Every path is a `static const String` on `AppImages` (`assets/images/`), `AppSvgs` (`assets/svgs/`) or `AppIcons` (`assets/icons/`) in `lib/core/constants/`; call sites use the constant.
- Before adding a constant: the file exists at that exact path **and** its directory is listed under `flutter: assets:` in `pubspec.yaml`. A path that does not resolve throws on the device while analyze and every test stay green.
- Asset missing? **Stop and say so.** Don't substitute a Material icon for a brand asset.

## 5. Strings

Every user-facing string — labels, tooltips, empty states, `Semantics` labels, failure messages — is `context.l10n.<key>` from `lib/l10n/app_en.arb` + `app_ar.arb`. A new key goes into **both** files in the same change (the l10n test fails on a key missing from either). Never concatenate translated fragments — use one ARB message with placeholders (`"downloadCount": "Download {count} videos"` + plural/ICU where needed). Numbers, sizes and dates go through the formatters, which bidi-isolate them.

## 6. House naming

| Thing | Convention |
|---|---|
| Routed widget | `*Screen` — every route in `app_router.dart` |
| Inside a screen | `*View` a composed sub-view, `*Content` a tab or panel body, `*Section` a slice |
| Files | snake_case with one role suffix: `_screen`, `_view`, `_content`, `_section`, `_card`, `_tile`, `_dialog`, `_sheet`, `_config` |
| Domain | `domain/entities/<x>.dart`, `domain/repos/<x>_repo.dart` (contract), `domain/usecases/<verb>_<noun>_use_case.dart` |
| Data | `data/repos/<x>_repo_impl.dart` (never `_repository`), `data/models/<x>_model.dart`, `data/datasources/<x>_datasource.dart` |
| State | `logic/<x>_cubit/<x>_cubit.dart` + `<x>_state.dart` |
| DI | `lib/core/di/modules/<feature>_dependencies.dart` — repos/services `registerLazySingleton`, cubits `registerFactory` |
| Imports | `package:tube_downloader/…` everywhere, never relative |
| Widgets | `StatelessWidget` / `StatefulWidget` — no hooks, no Riverpod; private pieces are `class _Header extends StatelessWidget` in the same file, not `Widget _buildHeader()` |

## Common mistakes
- Treating "grep for the name I imagined found nothing" as proof that nothing exists.
- A cubit that imports `AppDatabase`, `YoutubeExplode` or a `*RepoImpl`.
- A second link parser / format picker / progress bar inside a feature.
- Hand-building an error snackbar instead of `showFailureSnackBar` (`download-errors` skill).
