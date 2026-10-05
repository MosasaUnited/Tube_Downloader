# Tube_Downloader

A Flutter app for **macOS, Windows, Android and iOS** that downloads YouTube videos to local
storage: a single video, a whole playlist, or a batch of links. It has a download queue
(pause, resume, retry) and a library of finished files. English and Arabic (right-to-left).

## Features

- **New Download**
  - Single video, with a quality picker.
  - Playlist: pick the videos, one quality for all, per-video overrides.
  - Multiple links: paste them, import a `.txt` file, or drop files on the window (desktop).
- **Downloads:** filters with counts, playlist groups, a details pane with each download's
  timeline. Downloads retry with backoff and resume after a restart.
- **Library:** grid or list, search that handles Arabic, video/audio filter, open, share,
  Save to Photos (phones). Thumbnails are kept offline, and missing files are flagged.
- **Settings:** save location, default qualities, downloads at once, file-name pattern,
  Wi-Fi only, notifications, light/dark theme, English/العربية.
- Video and audio are merged with FFmpeg; audio can be converted to MP3.

## Status

In development, not released.

- **macOS:** verified end to end, including a real download driven through the app.
- **Android and iOS:** the builds compile; not yet tested on devices.
- **Windows:** not built yet.

The app is sideloaded, not published to a store; see [docs/release.md](docs/release.md).

## Run it

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

flutter run --flavor development -t lib/main_dev.dart   # macOS, iOS, Android
flutter run -d windows -t lib/main_dev.dart             # Windows (no flavours)
```

There is no `lib/main.dart`; always pass `-t`.

## Tests

```bash
flutter test --exclude-tags golden,network   # what CI runs
flutter test --tags golden                   # screenshot tests (macOS)
flutter test --tags network                  # against real YouTube
```

## How it's built

The app follows Clean Architecture: `data` → `domain` → `logic` (Cubit with freezed states)
→ `presentation`. The download engine is shared by all features and lives in
`lib/core/download_core`:

- a resolver built on `youtube_explode_dart`;
- an HTTP transport that downloads in parallel chunks;
- FFmpeg for merging and converting;
- a queue with crash recovery, stored in drift (SQLite).

## Docs

- [CLAUDE.md](CLAUDE.md): architecture, conventions and engine notes.
- [docs/spike/phase0.md](docs/spike/phase0.md): what was learned about the YouTube engine.
- [docs/release.md](docs/release.md): building and signing releases.

## Please note

Respect YouTube's Terms of Service and creators' rights: download only content you own or
have permission to download.

Third-party licences, which the app also lists under Settings › Open-source licenses:

- FFmpeg and FFmpegKit, under the LGPL-3.0 (used unmodified and dynamically linked);
- the Almarai font, under the SIL OFL 1.1.
