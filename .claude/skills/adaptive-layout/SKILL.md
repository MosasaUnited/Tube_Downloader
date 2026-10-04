---
name: adaptive-layout
description: The one layout system for phones, tablets and desktop windows — width-based WindowClass (compact < 600, medium 600–1023, expanded ≥ 1024) via windowClassOf(context), isLargeScreen(context) for phone-vs-tablet decisions, the AdaptiveShell (bottom navigation / 72px rail / 240px sidebar), two-pane master/detail on expanded windows, pushed detail screens on compact, card pairs instead of SliverGrid, and window-resize testing. Use whenever a request mentions layout, responsive, adaptive, desktop, macOS window, Windows window, tablet, iPad, phone size, sidebar, rail, bottom navigation, two columns, master/detail, side pane, grid, breakpoints, minimum window size, "looks wrong when I resize the window", or "blank space under cards". Trigger without being asked — a layout that only works at the size you tested is the default outcome.
---

# Adaptive layout

## One breakpoint helper (`lib/core/helpers/breakpoints.dart`)

```dart
enum WindowClass { compact, medium, expanded }
const double kCompactMaxWidth = 600;    // Material window-size classes
const double kExpandedMinWidth = 1024;

WindowClass windowClassOf(BuildContext context) { /* from MediaQuery.sizeOf(context).width */ }
bool isLargeScreen(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= kCompactMaxWidth;
```

- **Layout structure** (shell, panes, column counts) branches on `windowClassOf(context)` — **width**, because a desktop window can be short and wide (1200×500), which `shortestSide` would call a phone.
- **Density / sizing of a component** on mobile hardware ("iPad size" vs "phone size") uses `isLargeScreen(context)`.
- Never an ad-hoc `MediaQuery.of(context).size.width > 700`. Never `flutter_screenutil`. Inside a subtree that only knows its own box, use `LayoutBuilder` constraints.

## The shell (`features/shell/AdaptiveShell`)

| WindowClass | Navigation | Notes |
|---|---|---|
| compact | bottom `NavigationBar` (New · Downloads · Library · Settings), Downloads badge | phones in portrait |
| medium | 72px `NavigationRail` + content | tablets portrait, narrow windows |
| expanded | 240px sidebar (logo, nav, storage meter + save folder) collapsible to the 72px rail, top bar (title, search, theme) | desktop (min window 1024×680), tablets landscape |

Tabs are `StatefulShellRoute.indexedStack` branches — each tab keeps its state; don't add `AutomaticKeepAliveClientMixin` on top.

## Master / detail

- **expanded**: Downloads shows the queue + a detail pane side by side (`Row` of `Expanded(flex: 3)` list and a fixed-max-width pane); selecting a row updates the pane, no navigation.
- **compact / medium**: tapping a row pushes the task-details screen.
- The same `TaskDetailsContent` widget renders in both — the pane and the screen are thin hosts.

## Grids and card rows

- Library grid: column count from width (`compact` 2, `medium` 3, `expanded` 4–5), built lazily.
- Cards whose height depends on text (titles wrap to two lines, Arabic is taller) are laid out as **pairs/rows of `Expanded` inside `IntrinsicHeight`**, never `SliverGrid` + `childAspectRatio` — a fixed aspect ratio clips at 2.0 text scale and leaves blank bands in the other language. Thumbnail-only tiles with a fixed 16:9 image plus a capped two-line title may use a builder grid with `mainAxisExtent` computed from the text scale.
- Forms and option cards cap their width (`ConstrainedBox(maxWidth: …)`) on expanded windows instead of stretching a radio row across 1400px.

## Desktop specifics

- `window_manager`: minimum 1024×680, remember size/position.
- Hover states on rows and cards (`MouseRegion` / `InkWell` hover colour from `context.colors.surfaceRaised`), tooltips on every icon button, keyboard shortcuts (⌘/Ctrl+V into the URL field, ⌘/Ctrl+F library search, Esc closes panes).
- Desktop density: rows 72px comfortable, 56px compact when the window height < 700.

## Done means

Resize the desktop window from the minimum up to full screen; run phone portrait + landscape and a tablet; check both locales and text scale 2.0. Say which were actually checked.
