import 'dart:async';

import 'package:clock/clock.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/repos/activity_assertion.dart';
import 'package:tube_downloader/core/download_core/domain/repos/network_monitor.dart';
import 'package:tube_downloader/core/download_core/domain/services/backoff_policy.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_job.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Owns the running downloads. A lazy singleton — NOT a cubit — so work
/// survives screens closing (state-safety skill). Cubits send it commands and
/// read durable state from the repo's watch streams plus [live] progress.
class DownloadQueueService {
  DownloadQueueService(
    this._d, {
    required this._network,
    required this._gate,
    BackoffPolicy? backoff,
    this._activity = const NoActivityAssertion(),
  }) : _backoff = backoff ?? BackoffPolicy();

  final JobDeps _d;
  final NetworkMonitor _network;
  final ResolveGate _gate;
  final BackoffPolicy _backoff;

  /// Held while any job runs (macOS App Nap would otherwise throttle a
  /// download whose window is in the background).
  final ActivityAssertion _activity;
  bool _activityHeld = false;

  final _jobs = <String, DownloadJob>{};
  final _live = <String, LiveProgress>{};
  final _liveController =
      StreamController<Map<String, LiveProgress>>.broadcast();
  final _outcomeController = StreamController<TaskOutcome>.broadcast();
  final _healthController = StreamController<QueueHealth>.broadcast();

  QueueHealth _health = const QueueHealth();
  NetState _net = NetState.other;
  int _rateLimitStrikes = 0;
  bool _started = false;
  bool _pumping = false;
  bool _pumpAgain = false;
  Timer? _wake;
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<NetState>? _netSub;

  Clock get _clock => _d.clock;
  AppSettings get _settings => _d.settings.current;

  /// Live progress of running tasks (≤ 4 updates/s per task).
  Stream<Map<String, LiveProgress>> get live => _liveController.stream;
  Map<String, LiveProgress> get liveSnapshot => Map.unmodifiable(_live);

  /// Completed / failed tasks (notifications, snackbars).
  Stream<TaskOutcome> get outcomes => _outcomeController.stream;

  Stream<QueueHealth> get health => _healthController.stream;
  QueueHealth get currentHealth => _health;

  /// Ids of tasks running right now.
  Set<String> get running => _jobs.keys.toSet();

  /// Starts pumping. Call after RecoveryService.run().
  Future<void> start() async {
    if (_started) return;
    _net = await _network.current();
    _started = true;
    _settingsSub = _d.settings.watch().listen((_) => _onConditionsChanged());
    _netSub = _network.watch().listen((state) {
      _net = state;
      _onConditionsChanged();
    });
    await _onConditionsChanged();
  }

  Future<Result<List<String>>> enqueue(
    List<DownloadRequest> requests, {
    DownloadGroup? group,
  }) async {
    final result = await _d.repo.enqueue(requests, group: group);
    _schedulePump();
    return result;
  }

  Future<void> pause(String id) async {
    final job = _jobs[id];
    if (job != null) return job.pause(PauseReason.user);
    await _d.repo.transition(
      id,
      TaskStatus.paused,
      pauseReason: PauseReason.user,
      event: EventType.paused,
    );
  }

  Future<void> resume(String id) async {
    await _d.repo.transition(id, TaskStatus.queued, event: EventType.resumed);
    _schedulePump();
  }

  Future<void> cancel(String id) async {
    final job = _jobs[id];
    if (job != null) return job.cancel();
    await _d.repo.transition(
      id,
      TaskStatus.cancelled,
      event: EventType.cancelled,
    );
    await _d.fs.deleteWorkDir(id);
  }

  /// A failed task, tried again now.
  Future<void> retry(String id) async {
    await _d.repo.transition(id, TaskStatus.queued, event: EventType.retried);
    _schedulePump();
  }

  Future<void> pauseAll() async {
    for (final job in _jobs.values.toList()) {
      await job.pause(PauseReason.user);
    }
    for (final task in await _d.repo.tasksWithStatus({TaskStatus.queued})) {
      await _d.repo.transition(
        task.id,
        TaskStatus.paused,
        pauseReason: PauseReason.user,
        event: EventType.paused,
      );
    }
  }

  Future<void> resumeAll() async {
    for (final task in await _d.repo.tasksWithStatus({TaskStatus.paused})) {
      await _d.repo.transition(
        task.id,
        TaskStatus.queued,
        event: EventType.resumed,
      );
    }
    _schedulePump();
  }

  Future<int> clearFinished() => _d.repo.clearFinished();

  Future<void> dispose() async {
    _wake?.cancel();
    _holdActivity(false);
    await _settingsSub?.cancel();
    await _netSub?.cancel();
    for (final job in _jobs.values.toList()) {
      await job.pause(PauseReason.user);
    }
    await _liveController.close();
    await _outcomeController.close();
    await _healthController.close();
  }

  // ── pumping ──────────────────────────────────────────────────────────────

  /// Network or settings changed: pause/resume for the network gates, then pump.
  Future<void> _onConditionsChanged() async {
    _updateHealth();
    final blockedBy = _blockedReason();
    if (blockedBy != null) {
      for (final job in _jobs.values.toList()) {
        await job.pause(blockedBy);
      }
    } else {
      // Tasks the network paused resume by themselves; user pauses stay.
      for (final task in await _d.repo.tasksWithStatus({TaskStatus.paused})) {
        if (task.pauseReason != null && task.pauseReason != PauseReason.user) {
          await _d.repo.transition(
            task.id,
            TaskStatus.queued,
            event: EventType.resumed,
          );
        }
      }
    }
    _schedulePump();
  }

  PauseReason? _blockedReason() {
    if (_net == NetState.offline) return PauseReason.offline;
    if (_settings.wifiOnly && _net == NetState.cellular) {
      return PauseReason.waitingForWifi;
    }
    return null;
  }

  void _schedulePump() {
    if (!_started) return;
    if (_pumping) {
      _pumpAgain = true;
      return;
    }
    unawaited(_pump());
  }

  /// One pump at a time; a request during a pump runs it again afterwards.
  Future<void> _pump() async {
    _pumping = true;
    try {
      do {
        _pumpAgain = false;
        await _fillSlots();
      } while (_pumpAgain);
    } finally {
      _pumping = false;
    }
  }

  Future<void> _fillSlots() async {
    _updateHealth();
    if (_blockedReason() != null) return;
    final now = _clock.now();
    final cooldown = _gate.cooldownUntil;
    if (cooldown != null && cooldown.isAfter(now)) {
      _wakeAt(cooldown);
      return;
    }
    while (_jobs.length < _settings.maxConcurrent) {
      final next = await _d.repo.nextRunnable(now, running: running);
      if (next == null) {
        await _wakeForBackoff(now);
        return;
      }
      _startJob(next);
    }
  }

  void _startJob(DownloadTask task) {
    final job = DownloadJob(task, _d, onProgress: _onProgress);
    if (_jobs.isEmpty) _holdActivity(true);
    _jobs[task.id] = job;
    unawaited(_runSafely(job).then((result) => _onJobEnd(task, result)));
  }

  /// Begins / ends the OS activity assertion on the first job in and the
  /// last job out — and only ends one that was begun.
  void _holdActivity(bool hold) {
    if (hold == _activityHeld) return;
    _activityHeld = hold;
    unawaited(hold ? _activity.begin() : _activity.end());
  }

  /// A job's own failures arrive as [JobFailed]; anything it THROWS (a bug, a
  /// database error) is reported to the zone handler and still ends the job —
  /// a slot must never stay taken by a dead job.
  Future<JobResult> _runSafely(DownloadJob job) async {
    try {
      return await job.run();
    } on Object catch (error, stack) {
      Zone.current.handleUncaughtError(error, stack);
      return const JobFailed(AppFailure(type: FailureType.unknown));
    }
  }

  Future<void> _onJobEnd(DownloadTask task, JobResult result) async {
    _jobs.remove(task.id);
    if (_jobs.isEmpty) _holdActivity(false);
    if (_live.remove(task.id) != null && !_liveController.isClosed) {
      _liveController.add(liveSnapshot);
    }
    switch (result) {
      case JobCompleted(:final path):
        _rateLimitStrikes = 0;
        _emitOutcome(
          TaskOutcome.completed(
            taskId: task.id,
            title: task.media.title,
            path: path,
          ),
        );
      case JobStopped():
        break;
      case JobFailed(:final failure):
        await _handleFailure(task, failure);
    }
    _schedulePump();
  }

  /// Retry, back off, pause for the network, or fail for good.
  Future<void> _handleFailure(DownloadTask task, AppFailure failure) async {
    final current = await _d.repo.task(task.id);
    if (current == null) return;
    final now = _clock.now();

    if (failure.type == FailureType.rateLimited) {
      _rateLimitStrikes++;
      if (_rateLimitStrikes <= BackoffPolicy.maxRateLimitStrikes) {
        final cooldown = _backoff.rateLimitCooldown(_rateLimitStrikes);
        _gate.cooldown(cooldown);
        await _requeue(current, now.add(cooldown), failure);
        return;
      }
    } else if (failure.type == FailureType.noInternet &&
        _net == NetState.offline) {
      await _d.repo.transition(
        current.id,
        TaskStatus.paused,
        pauseReason: PauseReason.offline,
        event: EventType.paused,
      );
      return;
    } else if (failure.type.isRetryable) {
      final delay = _backoff.networkRetry(current.attempt);
      if (delay != null) {
        await _requeue(current, now.add(delay), failure);
        return;
      }
    }
    await _d.repo.transition(
      current.id,
      TaskStatus.failed,
      failure: failure,
      event: EventType.failed,
      eventArgs: {'type': failure.type.name},
    );
    _emitOutcome(
      TaskOutcome.failed(
        taskId: task.id,
        title: task.media.title,
        failure: failure,
      ),
    );
  }

  Future<void> _requeue(
    DownloadTask task,
    DateTime notBefore,
    AppFailure failure,
  ) => _d.repo.transition(
    task.id,
    TaskStatus.queued,
    notBefore: notBefore,
    countAttempt: true,
    event: EventType.retried,
    eventArgs: {'type': failure.type.name},
  );

  /// Sleeps until the earliest backoff ends (if anything is waiting).
  Future<void> _wakeForBackoff(DateTime now) async {
    final waiting = await _d.repo.tasksWithStatus({TaskStatus.queued});
    DateTime? earliest;
    for (final t in waiting) {
      final at = t.notBefore;
      if (at != null &&
          at.isAfter(now) &&
          (earliest == null || at.isBefore(earliest))) {
        earliest = at;
      }
    }
    if (earliest != null) _wakeAt(earliest);
  }

  void _wakeAt(DateTime at) {
    _wake?.cancel();
    final delay = at.difference(_clock.now());
    _wake = Timer(delay.isNegative ? Duration.zero : delay, _schedulePump);
  }

  void _onProgress(LiveProgress progress) {
    _live[progress.taskId] = progress;
    if (!_liveController.isClosed) _liveController.add(liveSnapshot);
  }

  void _emitOutcome(TaskOutcome outcome) {
    if (!_outcomeController.isClosed) _outcomeController.add(outcome);
  }

  void _updateHealth() {
    final next = QueueHealth(
      offline: _net == NetState.offline,
      waitingForWifi: _settings.wifiOnly && _net == NetState.cellular,
      cooldownUntil: _gate.cooldownUntil?.isAfter(_clock.now()) ?? false
          ? _gate.cooldownUntil
          : null,
    );
    if (next != _health) {
      _health = next;
      if (!_healthController.isClosed) _healthController.add(next);
    }
  }
}
