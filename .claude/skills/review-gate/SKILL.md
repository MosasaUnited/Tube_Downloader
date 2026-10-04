---
name: review-gate
description: Read-only pre-commit quality gate for this repo — runs dart format, flutter analyze and the house forbidden-pattern checks (raw colours outside ColorsManager, bare TextStyle / raw FontWeight outside Styles, bare print, screenutil .sp/.w/.h, EdgeInsets.only(left/right), TextDirection literals outside LtrText, direct launchUrl, exception text built into an AppFailure, domain/ importing Flutter / dart:io / drift / plugins / outer layers, logic/ importing data/ or engine packages, hand-formatted numbers, missing isClosed guards) on the .dart lines ADDED since origin/main, scans every changed file for committed credentials / key files and pubspec.yaml for new or banned packages, self-tests each of its patterns first, and reports BLOCKING / WORTH FIXING / NOTES without editing anything. Use before every commit, PR, or "is this ready" question, whenever a request says review, check, lint, gate, quality, pre-commit, "run the checks", "anything wrong with my changes", and after finishing any multi-file change. Never fixes code — a gate that edits code to make itself pass is not a gate.
allowed-tools: Bash, Read, Grep, Glob
---

# Review gate (read-only)

Run from the repo root:

```bash
bash .claude/skills/review-gate/scripts/check.sh              # added lines vs origin/main (default)
bash .claude/skills/review-gate/scripts/check.sh --base main  # different base ref (e.g. before a remote exists)
bash .claude/skills/review-gate/scripts/check.sh --tests      # also run flutter test (goldens only on macOS)
bash .claude/skills/review-gate/scripts/check.sh --all        # whole lib/ + test/ — debt sweep, not a gate
```

Exit `0` = no blocking findings (warnings allowed), `1` = blocking, `2` = could not run (no git, no dart/flutter, unresolvable base). On Windows hosts run it from Git Bash.

**It is a merge gate.** `.github/workflows/quality.yml` runs it on every PR next to `flutter analyze --fatal-infos`, a whole-repo format check and `flutter test --exclude-tags golden`; a BLOCKING finding fails the PR.

## What it checks

- **BLOCKING**
  - any changed file that isn't dart-formatted; analyzer *errors* in the changed files;
  - in added `lib/` lines: `Color(0x…)` / `Colors.*` outside `colors_manager.dart`; a bare `TextStyle(` or raw `FontWeight.*` outside `lib/core/theme/`; bare `print(`; `EdgeInsets.only(left|right)` / `fromLTRB`; `TextDirection.ltr|rtl` outside `lib/core/widgets/ltr_text.dart`; screenutil `.sp/.w/.h/.r`; direct `launchUrl(` outside `lib/core/download_core/data/platform/`;
  - an `AppFailure(…)` built from `e.toString()` / `'$e'` outside `failure_mapper.dart` (`download-errors` skill);
  - **Clean Architecture:** a file under `*/domain/*` importing `package:flutter`, `dart:io`/`dart:ui`, drift, `youtube_explode_dart`, an FFmpeg / download / file plugin, or `…/data|logic|presentation/`; a file under `*/logic/*` importing `dart:io`, drift, an engine package or `…/data/` (`codebase-conventions` skill);
  - **a credential-shaped line in any changed file** and **a key file entering git** (`.env*` except `.env.example`, `key.properties`, `*.jks` / `.keystore` / `.p8` / `.p12` / `.pfx`, `id_rsa`-style keys) — covers Android upload keys, iOS/macOS signing exports and Windows code-signing `.pfx`;
  - **a new banned package**: `equatable`, `dartz`/`fpdart`, `lottie`, `rive`, Riverpod/Provider/GetX/MobX/hooks, `flutter_screenutil`, `dio`/`retrofit`/`http`, `isar`/`hive`/`sqflite`/`objectbox`/`shared_preferences`, retired or GPL FFmpeg builds (`ffmpeg_kit_flutter`, `ffmpeg_kit_flutter_new`, `*_gpl`), `webview_flutter*`;
  - **a self-test failure**.
- **WORTH FIXING** — analyzer *warnings*; a BLOCKING pattern on a changed line that only carries an old violation along (the ratchet); `toStringAsFixed(` outside `formatters.dart`; `SizedBox(height|width:)` spacers; physical `Alignment.*Left/Right`; `MultiBlocProvider`; a failure shown by hand instead of `showFailureSnackBar` / `showFailureDialog`; hand-rolled `fromJson`; any other new `pubspec.yaml` dependency (the PR must say why); a `lib/core/` file importing `package:tube_downloader/features/` (only `di/` and `router/` are exempt); a cubit file that awaits and emits with **no** `isClosed` anywhere.
- **NOTES** — analyzer infos, added `TODO`/`FIXME`, `Widget _buildX()` helpers, `setState(`.

Generated code is never gated: `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.config.dart`, `*.gr.dart` and the gen-l10n output `app_localizations*.dart`.

The credential and dependency checks run even when the change touches no `.dart` file.

In the default mode only **added** lines are scanned. **The BLOCKING Dart patterns are ratcheted per file**: a hit blocks only when the file now holds *more* occurrences than at the merge-base; otherwise it is demoted to WORTH FIXING with `[legacy — … count did not grow]`. The repo starts clean, so in practice every new violation blocks. Credentials, key files, banned packages, `AppFailure` text and the layer rules are **not** ratcheted.

**Credentials** are matched case-insensitively in five shapes: a secret-sounding name (`apiKey`, `secret`, `password`, `privateKey`, `…_token`) assigned a quoted literal of 17+ characters with a digit; a 32- or 64-byte base64 literal; a `-----BEGIN … PRIVATE KEY-----` header; `scheme://user:secret@host`; and `KEY=value` lines. The report never echoes the matched line. Carved out: this skill's own folder. A fixture that only *looks* like a key carries `// review-gate: not-a-secret` on its line or the line above.

**Every pattern self-tests before it runs.** Each regex is declared once, in section 0 of `check.sh`, beside `+` samples it must catch and `-` samples it must leave alone; the samples go through the same line filter as the real scan. A pattern that stops catching its own violation, flags a line it must not, or no longer compiles is BLOCKING. **To add a check:** declare `P_…` in section 0 with its samples, then reference the variable at the call site; never inline a regex in the scan loop.

## How to use the output

1. Report the three sections verbatim, with `file:line`. Group by file if it's long.
2. **Do not fix anything.** Say what you would change and let the user decide — this skill runs with read-only tools on purpose.
3. What the script cannot judge, you must: whether tests cover the failure path, whether a device check actually happened, whether a new dependency was necessary, whether a `// ignore:` is justified.
4. A clean run is not "verified" — it proves the diff compiles and follows house patterns, nothing about the engine, the device or the downloaded file.
