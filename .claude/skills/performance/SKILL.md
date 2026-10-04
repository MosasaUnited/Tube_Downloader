---
name: performance
description: Flutter build-performance rules for this codebase — widget classes instead of _buildX() helper methods, const constructors, controller lifecycle, builder-based lists with stable keys, no work inside build(), throttled download-progress rebuilds, RepaintBoundary only where measured, and decode-size limits on every network thumbnail. Use whenever writing or refactoring any widget, screen, list, card, progress bar, thumbnail, animation, scroll view or tab, and whenever a request mentions jank, lag, slow scrolling, rebuilds, frame drops, memory, performance, "the list stutters", "progress makes the UI lag", DevTools, or profile mode. Trigger without being asked — the slow version compiles and renders identically.
---

# Performance

## `build()` only allocates the tree

- No sorting, filtering, grouping, JSON parsing, byte/ETA formatting loops, regex compilation or `getIt` look-ups inside `build`. Do it once in the cubit (emit the prepared list) or in `initState`.
- Controllers (`ScrollController`, `TextEditingController`, `TabController`, `FocusNode`) are created in `initState` / a field and disposed in `dispose` — never in `build`.
- `const` constructors and `const` children everywhere the analyzer allows. A `const` subtree is skipped on rebuild.

## Widget classes, never `_buildX()` helpers

A `Widget _buildHeader()` method re-runs every time its parent rebuilds and can never be `const`. A `class _Header extends StatelessWidget` gets its own element, rebuild boundary, `const`-ability and a DevTools name. Write UI as widget classes from the start.

## Download progress

- The queue emits live progress at most **4×/s per task** (`ProgressThrottler`). Never bypass it with a raw byte-callback → `emit`.
- A row listens to **its own** task: `BlocSelector<DownloadsCubit, DownloadsState, LiveProgress?>((s) => s.liveFor(task.id))`. A 50-item playlist must not rebuild 50 rows when one byte counter moves.
- Wrap the animating progress track/ring in a `RepaintBoundary` — it repaints on its own clock inside a static card.

## Lists

- Data lists are `ListView.builder` / `.separated` / `SliverList` — never `ListView(children: [...])`. Playlist rows (can be hundreds) and the library grid are lazy.
- Stable `ValueKey(item.id)` on every data row so reorders, removals and status changes relocate elements instead of rebuilding them.
- `itemExtent` / `prototypeItem` only when rows are genuinely fixed-height.

## Images — thumbnails everywhere

Every network thumbnail sets `cacheWidth` (`(logicalWidth * devicePixelRatio).round()`). A 1280×720 thumbnail decoded at full size holds ~3.5 MB; a 96px-wide row needs ~100 KB, and a 48-row playlist is the difference between smooth and an OOM on a mid-range phone. Library thumbnails are local files — same rule via `Image.file(cacheWidth:)`. Go through the shared `MediaThumbnail` widget, which applies it. SVG assets use `flutter_svg`.

## Rebuild scope

- `BlocSelector` / `buildWhen` when a widget needs one field; `context.read` for one-shot reads outside `build`.
- `RepaintBoundary` where DevTools' repaint rainbow shows a cascade (progress, skeleton shimmer, `flutter_animate` loops) — not everywhere; each one is a layer.
- Never animate `Opacity` on a large subtree; use `FadeTransition` / `flutter_animate`'s `.fadeIn()`. Hide with `Visibility` / `Offstage`.

## Measure

Only in `--profile` mode. Measure before and after — the bottleneck is rarely where it looks.
