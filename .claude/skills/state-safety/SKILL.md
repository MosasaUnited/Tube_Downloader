---
name: state-safety
description: Cubit liveness and state-shape rules for this codebase — the "if (isClosed) return;" guard after every await that precedes an emit, cancelling stream subscriptions (download progress, drift watch streams, connectivity) in close(), freezed sealed-union states, side effects outside build, and sequence-asserted tests. Use whenever creating or editing any Cubit, state class, emit call, stream subscription, async load / fetch / resolve / enqueue / delete / refresh method, or when a bug mentions "Cannot emit new states after calling close", StateError, "crash when leaving the screen while a download is running", a progress bar that keeps updating after the screen closed, or a state that never updates. Trigger without being asked — the missing guard compiles, passes analyze, and only fails when the user leaves the screen mid-request.
---

# State safety (Cubit)

Feature cubits are `registerFactory` per route, so leaving a screen **closes the cubit while its work is still in flight**. `emit` after `close()` throws `StateError('Cannot emit new states after calling close')`; `runZonedGuarded` turns that into log noise and a silently skipped tail of the method. In this app the long-lived work is the download queue: cubits observe it through **streams**, so a forgotten subscription is the most likely leak.

## 1. Cancel every subscription in `close()`

Cubits here mostly listen — drift `watch()` streams (tasks, groups, library, settings), `DownloadQueueService.live` progress, connectivity. Hold each `StreamSubscription` in a field and cancel it:

```dart
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(this._repo, this._queue) : super(const DownloadsState.loading());

  final DownloadRepo _repo;
  final DownloadQueueService _queue;
  StreamSubscription<List<DownloadTask>>? _tasksSub;
  StreamSubscription<Map<String, LiveProgress>>? _liveSub;

  void start() {
    _tasksSub = _repo.watchTasks(const TaskFilter.all()).listen(_onTasks);
    _liveSub = _queue.live.listen(_onLive);
  }

  @override
  Future<void> close() async {
    await _tasksSub?.cancel();
    await _liveSub?.cancel();
    return super.close();
  }
}
```

Cancelling in `close()` beats guarding every callback. The same goes for `Timer`s and `.then(...)` chains.

## 2. The guard after every `await`

After **every** `await` that is followed by an `emit` — the second and third awaits too, inside `try`/`catch`/`finally`:

```dart
Future<void> resolve(String input) async {
  emit(const SingleLinkState.resolving());
  final result = await _resolver.resolve(LinkParser.parse(input));
  if (isClosed) return; // the screen may have been left while resolving
  result.when(
    success: (link) => emit(SingleLinkState.resolved(link)),
    failure: (f) => emit(SingleLinkState.failure(f)),
  );
}
```

- Two awaits → two guards.
- Never "fix" it by wrapping the method in a `try/catch` that swallows the `StateError` — that hides real failures too.
- `DownloadQueueService` is a lazy singleton, **not** a cubit: it never closes, so it owns the long-running work and cubits only send it commands. Don't move queue logic into a cubit to "simplify" — it would die with the screen.

## 3. State shape and side effects

- One `freezed` sealed union per cubit; no `equatable`, no nullable-field bags. Failure states carry the typed `AppFailure`, never a string (`download-errors` skill).
- Re-emitting a value-equal state is a no-op — design states so a real change is a real inequality.
- No `BuildContext` in a cubit. Navigation, dialogs and snackbars run from the widget via `BlocListener`.
- Live progress arrives up to 4×/s: rebuild the smallest subtree (`BlocSelector` on the one task's progress), never the whole list.

## 4. Tests

- Assert the **sequence** of states (`blocTest` / `emitsInOrder`), not just the last one.
- Test the failure path of every public method.
- Guard test: start the call, `await cubit.close()` before the mocked future completes, and expect no error.
- Subscription test: close the cubit, then push to the source stream — expect no emission and no error.
