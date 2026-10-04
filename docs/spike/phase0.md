# Phase 0 — engine spike results

Status: **local checks complete — awaiting the owner's go/no-go** (2026-10-04). Windows, physical-device background transfer and notarization are still open (see the checklist).

## Go / no-go summary

| Gate | Result | Recommendation |
|---|---|---|
| (a) 1080p video + audio via `youtube_explode_dart` | ✅ macOS (3 fixtures, 1080p), ✅ iOS simulator, ✅ Android emulator (720p cap) — only with the **app-defined `visionOs` client**; package defaults 403 on audio | **GO** — ship `EngineConfig.ytClients = [visionOs]`; keep the yt-dlp desktop fallback in reserve |
| (c) FFmpeg merge + MP3 (`ffmpeg_kit_flutter_new_audio` 2.5.4) | ✅ builds and runs on macOS, iOS simulator, Android emulator; merge `-c copy` < 1 s; lame MP3 works; macOS +33 MB | **GO** for 3 platforms; Windows pending |
| (b) Transport | Chunked HTTP: 8 workers × 4 MB ≈ 68 % of the line; **stall timeout + chunk retry mandatory** (17-min stall observed); `background_downloader` not evaluated yet | **GO** with `ChunkedHttpTransport` everywhere for v1 foreground downloads; evaluate `background_downloader` for mobile background in Phase 2 on physical devices |
| Resolver robustness | One transient `WatchPage` failure on Android, succeeded on retry | Resolver retries transient failures with backoff (already in the plan) |


Fixtures are Blender Foundation open movies (CC-BY), so every download in this spike is licensed for it:
`aqz-KE-bpKQ` (Big Buck Bunny, 4K60), `eRsGyueVLvQ` (Sintel), `R6MlUcmOul8` (Tears of Steel).

Probe code: `spike/engine_probe/` (pure Dart, `dart run bin/probe.dart`, `dart run bin/throughput.dart`).

## (a) Engine — which client yields fetchable adaptive streams

`youtube_explode_dart` 3.1.0, macOS host, 2026-10-04. "Pull" = ranged GET of the first 2 MB of the chosen stream.

| Client config | Manifest | Best video-only ≤1080p pull | AAC audio pull | Verdict |
|---|---|---|---|---|
| package default | ✅ 2.5–5.4 s | ✅ HTTP 200 | ❌ **HTTP 403** (all 3) | unusable for merge |
| **`visionOs` (app-defined, PR #389 payload)** | ✅ 1.8–4.4 s, up to 2160p listed | ✅ HTTP 200 (all 3) | ✅ HTTP 200 (all 3) | **works** |
| `ios` | ❌ `YoutubeExplodeException … returned 403` | — | — | unusable |
| `tv` | ❌ `VideoUnplayableException` | — | — | unusable |

Notes:
- `visionOs` returns **no muxed stream** (`muxed=0`), so even 360p needs the FFmpeg merge path with this client. Keep the package default client as a muxed-only fallback route.
- Codecs offered at 1080p differ per video (`avc1.64002a`, `av01.0.08m.08`). The format selector must prefer `avc1` + `mp4a` for MP4 output and accept `av01`/`vp9` only when the user picks a quality that has no H.264 rendition (e.g. 4K) — that output is MKV/WebM or needs a re-encode (out of scope for v1).
- `StreamManifest.audioOnly.sortByBitrate()` is **descending** (first = best). The probe initially picked the 49 kbps HE-AAC (`mp4a.40.5`) stream by taking `.last`.

### Full end-to-end run — macOS ✅ (2026-10-04, `spike/engine_spike`, release build)

`visionOs` client → best `avc1` video-only ≤ 1080p + best AAC audio → 4 parallel ranged chunks → `ffmpeg -map 0:v:0 -map 1:a:0 -c copy -movflags +faststart` → FFprobe.

| Fixture | Video leg | Audio leg | Merge | FFprobe of output | Δ duration vs metadata |
|---|---|---|---|---|---|
| Tears of Steel (734 s) | 180.8 MB `avc1.640028` 1080p ✅ | 11.9 MB AAC 128k ✅ | ✅ rc 0, 0.6 s | `h264@800p` (1920×800 letterbox) + `aac` | 0.21 s |
| Sintel (888 s) | 170.2 MB `avc1.640028` ✅ | 14.4 MB ✅ | ✅ 0.5 s | `h264@818p` + `aac` | 0.09 s |
| Big Buck Bunny (635 s) | 257.6 MB `avc1.64002a` ✅ | 10.3 MB ✅ | ✅ 0.8 s | `h264@1080p` + `aac` | 0.38 s |
| MP3 (Tears of Steel audio → lame 192k) | — | — | ✅ 23.7 s | `mp3`, 17.6 MB | 0.21 s |

No 403 mid-transfer on any leg; every duration within the ±1 s pass mark. Throughput in this run was 0.1–0.46 MB/s because the spike had **no stall timeout** (see below) — the sustained-throughput table is the realistic number.
Notes for the format layer: the YouTube quality label ("1080p") is not the pixel height of letterboxed films (800p / 818p) — show the label, not the probed height. Merging is effectively free (< 1 s for ~250 MB); MP3 transcoding is ~30× real time on Apple silicon.

### End-to-end — iOS simulator ✅ (2026-10-04, iPhone 17 / iOS 27, debug build, 8 × 4 MB + 20 s stall timeout)

`ffmpeg_kit_flutter_new_audio` builds for the iOS simulator through SPM with no extra setup (Xcode build 47.7 s).

| Fixture | Video leg | Audio leg | Merge | FFprobe | Δ duration | MP3 |
|---|---|---|---|---|---|---|
| Tears of Steel, 720p cap | 65.0 MB `avc1.4d401f` ✅ 0.39 MB/s, 0 retries | 11.9 MB AAC ✅ 0.26 MB/s | ✅ 0.2 s | `h264@534p` + `aac` | 0.21 s | ✅ 5.6 s, `mp3` |

Simulator networking shares the Mac's connection, so this proves the plugin + engine on iOS, not phone-radio throughput. Device run (and the background-transfer test) still needs a physical iPhone.

### End-to-end — Android emulator ✅ (2026-10-04, Medium Phone API 36.1, arm64-v8a, debug build)

`ffmpeg_kit_flutter_new_audio` pulls `com.antonkarpenko:ffmpeg-kit-audio:2.2.2` from Maven Central; builds with AGP 9.1 / Gradle 9.3.1, minSdk 24.

| Fixture | Video leg | Audio leg | Merge | FFprobe | Δ duration | MP3 |
|---|---|---|---|---|---|---|
| Tears of Steel, 720p cap | 65.0 MB `avc1.4d401f` ✅ 0.58 MB/s, 0 retries | 11.9 MB AAC ✅ 0.22 MB/s | ✅ 0.4 s | `h264@534p` + `aac` | 0.21 s | ✅ 5.6 s |

The **first** emulator run failed before any download with `TransientFailureException: Failed to retrieve initial data from WatchPage` (from `videos.get`). The same calls from the Mac succeeded minutes later (normal 1.28 MB watch page, no consent page, no bot check), and the rerun — with retry + backoff around `videos.get` / `getManifest` — succeeded on the first attempt. Treat `TransientFailureException` as retryable (`FailureType.serverUnreachable`, backoff), never as a hard failure.

## (b) Transport — throughput

Same host and network, `visionOs` 1080p video stream of `aqz-KE-bpKQ`:

| Method | Throughput |
|---|---|
| Baseline: Cloudflare 25 MB download | **2.23 MB/s** (the line) |
| 1 connection, 3 × 10 MB ranges in sequence | 0.52 MB/s |
| 1 connection, single 30 MB range | 0.44 MB/s |
| **4 parallel 5 MB ranges** | **1.54 MB/s (≈ 70 % of the line)** |

**Finding: the stream is throttled per connection (~0.5 MB/s ≈ 4 Mbit/s), and parallel ranged requests bypass it.** A 245 MB 1080p video takes ~8 min on one connection versus ~2.7 min with 4. Design consequence for `MediaTransport`:
- the chunked transport downloads each leg as **N parallel ranged chunks** (start with 4, ≤ 10 MB each, `range=` query parameter for non-Android clients), writes them at their offsets in the `.part` file, and checkpoints completed chunks for resume;
- `background_downloader` must be evaluated with `ParallelDownloadTask`, not a plain `DownloadTask`;
- the global concurrency setting (1–5 tasks) multiplies connections: 3 tasks × 4 chunks = 12 connections. Cap total connections (e.g. 8) in the queue service, not per task.

### Sustained throughput (64 MB per run, stall timeout 20 s + retry), 2026-10-04 ~17:40

Line baseline at the time: **1.53 MB/s**. Stream URLs from `visionOs` carry no `n` and no `ratebypass` parameter; the package reports `isThrottled: true`.

| Workers × chunk | 64 MB in | Rate | % of line |
|---|---|---|---|
| 4 × 8 MB | 82.4 s | 0.78 MB/s | 51 % |
| **8 × 4 MB** | **61.5 s** | **1.04 MB/s** | **68 %** |
| 8 × 2 MB | 64.1 s | 1.00 MB/s | 65 % |

**Decision: the transport defaults to 8 workers × 4 MB chunks per leg**, with a global connection cap in the queue service (so 2 concurrent tasks share ~8–12 connections, not 16). Re-tune per platform in the mobile runs.

(The first print of this table showed 0.19 / 0.13 / 0.12 MB/s because of a probe bug — `got += await …` reads `got` before the await, so concurrent workers overwrote each other's counts. All chunks were length-checked, so the elapsed times above are right. The real transport must never accumulate shared counters that way; the review gate cannot see it, so it goes into the transport's contract tests.)

### Stalls (observed 2026-10-04, macOS)

During the first full-download run, all 4 chunk workers stopped receiving bytes for **~17 minutes** (the `.part` file sat at exactly 8 × 8 MB from 16:44 to 17:01) while a Gradle dependency download on the same machine was also stuck; both recovered at the same time. `dart:io` `HttpClient` has a connection timeout but **no read/idle timeout on an open response stream**, so a hung connection blocks its chunk forever. Transport requirements:
- a per-chunk **stall timeout** (no bytes for 30 s → abort that request, retry the chunk with backoff), implemented with `Stream.timeout` on the response;
- `HttpClient.connectionTimeout` (15 s) and `idleTimeout` set explicitly;
- the queue shows "Waiting for network…" (pause reason `offline`) when every worker of a task is in retry, instead of a frozen progress bar.

## (c) FFmpeg — size (macOS)

`ffmpeg_kit_flutter_new_audio` 2.5.4 builds on macOS with Flutter 3.47.5 / Xcode 27 (no extra steps). Release `.app` of the spike: **73 MB**, of which FFmpeg frameworks ≈ **33 MB** (`libavcodec` 20 MB, `libavfilter` 5.1 MB, `libavformat` 4.2 MB, `libswscale` 1.1 MB, `ffmpegkit` 1.1 MB, `libavutil` 1.0 MB, rest < 1 MB) — inside the +40 MB macOS budget. Notarization not yet checked (needs a Developer ID certificate).

## Still to run

- [x] (a) Full download + FFmpeg merge + FFprobe check on macOS (3 fixtures, 1080p), iOS simulator and Android emulator (1 fixture, 720p).
- [ ] (a) **Windows** — needs a Windows machine/VM or a `windows-latest` CI run of `spike/engine_spike` (add the windows platform with `flutter create --platforms=windows .`).
- [ ] (a) Ineligible fixtures map to the right `FailureType` (private, age-restricted, live, deleted) — needs fixture IDs.
- [ ] (a) Repeat across 2 days / 2 networks.
- [ ] (b) Pause/resume sha256 identity; kill + reconcile; Wi-Fi→cellular 403 → re-resolve → resume — moved to Phase 2 as `ChunkedHttpTransport` contract tests (local Range server) plus a device check.
- [ ] (b) Background download ≥ 10 min on a **physical** Android phone and iPhone; `background_downloader` vs chunked transport + Android foreground service — Phase 2.
- [x] (c) Merge + MP3 on macOS, iOS simulator, Android emulator; macOS size +33 MB.
- [ ] (c) Size delta of an Android release APK per ABI and an iOS release build; Windows build (offline via `FFMPEGKIT_LOCAL_DIR`); **macOS notarization** (needs the owner's Developer ID certificate).

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-04 | Default engine config = `[visionOs]` for manifests; package default kept as a muxed-only fallback | Only config with fetchable adaptive audio + video today. |
| 2026-10-04 | ~~4 parallel ranged requests~~ → **8 workers × 4 MB** per leg, global connection cap in the queue | Sustained test: 1.04 MB/s (68 % of line) vs 0.78 MB/s for 4 × 8 MB. |
| 2026-10-04 | 20 s stall timeout per chunk request + chunk retry (5 attempts, backoff); 15 s connect timeout | 17-minute silent stall on macOS; `HttpClient` has no read timeout. |
| 2026-10-04 | `TransientFailureException` and network errors in the resolver are retried with backoff | Android emulator failed once on `WatchPage`, succeeded on retry. |
| 2026-10-04 | Show YouTube's quality label, not the probed pixel height | Letterboxed films report 800p / 818p for a "1080p" stream. |
| 2026-10-04 | Implemented: `ChunkedHttpTransport` (8 × 4 MB, in-order append, 20 s stall timeout); contract tests against a local server that stalls, 403s and slows | Phase 2. End-to-end through the app pipeline: 11.3 MB M4A in 37 s, peak 1.78 MB/s. |
| 2026-10-04 | Stream height = the quality label's number, not pixels | Tears of Steel's "1080p" is 800 px tall; a portrait Short's "1080p" is 1920 px. |

