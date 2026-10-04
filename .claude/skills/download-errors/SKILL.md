---
name: download-errors
description: How a failure travels and is shown (DOWNLOAD-ERRORS) — FailureMapper.map(e) → Result.failure(AppFailure) → a failure state that carries the AppFailure → showFailureSnackBar / showFailureDialog / ErrorEmptyState, with messages resolved from ARB by FailureType. Covers youtube_explode exceptions (unavailable, private, age-restricted, rate-limited 429, unsupported link), HTTP 403 stream expiry, offline vs server-unreachable, disk full, permission denied, FFmpeg failure and silent cancellation. Use whenever writing or editing any repo impl, resolver, transport, muxer, file-system gateway, use case, failure state, catch block or error UI, and whenever a request mentions error, failure, exception, catch, retry, "download failed", "link not supported", 403, 429, rate limit, offline, no internet, storage full, permission, FFmpeg error, snackbar or error dialog. Trigger without being asked — a raw exception string compiles and shows up in production as "SocketException: OS Error…".
---

# Download errors

**One typed value travels every layer.** Nothing technical — an exception's `toString()`, a stack, an HTTP body, an FFmpeg log line — ever reaches the UI. The technical detail goes to `debugPrint` (muted in production by the logging policy) and to `task_events` as a failure *type*, never as English text.

## The pieces (`lib/core/error/`)

| Piece | Role |
|---|---|
| `FailureType` (enum) | `noInternet`, `serverUnreachable`, `rateLimited`, `unsupportedLink`, `videoUnavailable`, `privateVideo`, `ageRestricted`, `liveNotSupported`, `streamExpired`, `storageFull`, `permissionDenied`, `ffmpegFailed`, `cancelled`, `unknown`. Extension: `isSilent` (only `cancelled`), `isRetryable`. |
| `AppFailure` (freezed) | `type`, optional `debug` (logs only — never rendered), optional `retryAfter`. Value equality, so a repeated failure is not a new state. |
| `Result<T>` (freezed) | `success(T)` \| `failure(AppFailure)`. Every repo / resolver / gateway method that can fail returns it (or a `Stream` of it). Contracts never `throw`. |
| `FailureMapper.map(Object e, [StackTrace? s])` | The **only** place exceptions become failures. Logs the technical detail with `debugPrint`, returns an `AppFailure`. |
| `failure_presenter.dart` (`lib/core/helpers/`) | `showFailureSnackBar(context, f)`, `showFailureDialog(context, f)`, `failureMessage(context, f)` → `context.l10n.failure<Type>`. Silent for `cancelled`; drops a repeat of the message already on screen. |
| `ErrorEmptyState(failure:, onRetry:)` (`lib/core/widgets/`) | A whole-screen failure (resolve failed, library unreadable): the empty-state illustration + localized message + Retry. |

## Mapping table (keep `FailureMapper` and its test in sync with it)

| Input | `FailureType` |
|---|---|
| `CancelledException` (ours) | `cancelled` — silent |
| `UnsupportedLinkException` (ours, from `LinkParser`), `ArgumentError(name: 'idOrUrl')` from `VideoId` / `PlaylistId` | `unsupportedLink` (any other `ArgumentError` is `unknown`) |
| `FfmpegException` (ours, non-zero return code) | `ffmpegFailed` |
| `HttpStatusException` (ours): 403 / 410 | `streamExpired` — the queue re-resolves the leg once before surfacing it |
| `HttpStatusException`: 429 · 404 · 5xx | `rateLimited` · `videoUnavailable` · `serverUnreachable` |
| `RequestLimitExceededException`; any youtube_explode message containing "not a bot" (the sign-in bot check) | `rateLimited` |
| `VideoRequiresPurchaseException`, `VideoUnavailableException` | `videoUnavailable` |
| `VideoUnplayableException` — reason mentions "ongoing live stream" / "confirm your age" / "private" / other | `liveNotSupported` / `ageRestricted` (explicitly unsupported — never retried) / `privateVideo` / `videoUnavailable` |
| `TransientFailureException` (e.g. "Failed to retrieve initial data from WatchPage" — seen once on Android, fine on retry) | `serverUnreachable` (retryable) |
| `SocketException` / package:http `ClientException` whose text is a failed host lookup or "network is unreachable" | `noInternet` |
| other `SocketException` / `ClientException`, `HandshakeException`, `TimeoutException` (incl. the transport's stall timeout), `HttpException` | `serverUnreachable` (retryable) |
| `FileSystemException` errno 28 ENOSPC (POSIX) / 112 or 39 (Windows) | `storageFull` |
| `FileSystemException` errno 13 EACCES or 1 EPERM (POSIX) / 5 (Windows) | `permissionDenied` (errno 5 on POSIX is EIO → `unknown`) |
| anything else | `unknown` |

`ClientException` is matched by type **name** so the app does not depend on `package:http` (banned — it never makes requests with it); the mapper test pins it with a stand-in class. The offline/server split is a synchronous heuristic; the queue's `NetworkMonitor` separately pauses tasks with the `offline` reason.

Exception class names belong to `youtube_explode_dart` 3.x — re-check them when bumping the package; the mapper test pins each one.

## The flow

```dart
// data — the only try/catch
Future<Result<ResolvedLink>> resolve(ParsedLink link) async {
  try {
    return Result.success(await _resolveInternal(link));
  } on Object catch (e, s) {
    return Result.failure(FailureMapper.map(e, s));
  }
}

// logic — pass it through unchanged
final result = await _resolver.resolve(link);
if (isClosed) return;
result.when(
  success: (l) => emit(SingleLinkState.resolved(l)),
  failure: (f) => emit(SingleLinkState.failure(f)),
);

// presentation — exactly one presenter per failure branch
BlocListener<SingleLinkCubit, SingleLinkState>(
  listenWhen: (p, c) => c is SingleLinkFailure,
  listener: (context, state) => showFailureSnackBar(context, (state as SingleLinkFailure).failure),
  child: …,
);
```

## Rules

- **Never** `AppFailure(type: FailureType.unknown, debug: e.toString())` in a cubit or widget — call `FailureMapper.map(e)` (the review gate blocks building a failure from `e.toString()`/`'$e'` outside the mapper).
- **Never** call `showErrorSnackBar` / a raw `SnackBar` with failure text — go through `showFailureSnackBar`.
- A download task's failure is **state**, not a toast: the queue persists `failure_type` on the task and the card renders it (icon + localized reason + Retry). Toasts are for the action the user just took (resolve, enqueue, delete, open, reveal).
- Local validation (empty URL field, bad file-name template) is an `invalidInput` state with its own ARB key, not an `AppFailure`.
- Every `FailureType` has `failure<Type>` keys in **both** `app_en.arb` and `app_ar.arb`; the l10n test enumerates `FailureType.values`.
- Tests: `failure_mapper_test.dart` (one case per row above + "no exception text in `failureMessage`"), presenter test (silent for `cancelled`, dedupe).
