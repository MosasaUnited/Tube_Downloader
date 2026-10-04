import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/result.dart';

/// The durable download queue. Every status change goes through [transition],
/// which validates it against TaskStateMachine and writes the status and its
/// timeline event in one transaction.
abstract interface class DownloadRepo {
  /// Adds tasks (and the playlist [group]) atomically; returns the task ids.
  Future<Result<List<String>>> enqueue(
    List<DownloadRequest> requests, {
    DownloadGroup? group,
  });

  Stream<List<DownloadTask>> watchTasks(TaskFilter filter);
  Stream<DownloadTask?> watchTask(String id);
  Stream<List<GroupSummary>> watchGroups();
  Stream<List<DownloadEvent>> watchEvents(String taskId);

  Future<DownloadTask?> task(String id);
  Future<DownloadGroup?> group(String id);
  Future<List<DownloadTask>> tasksWithStatus(Set<TaskStatus> statuses);

  /// The first queued task (by position) whose backoff has passed, skipping
  /// [running] ids.
  Future<DownloadTask?> nextRunnable(
    DateTime now, {
    Set<String> running = const {},
  });

  Future<Result<DownloadTask>> transition(
    String id,
    TaskStatus to, {
    PauseReason? pauseReason,
    AppFailure? failure,
    DateTime? notBefore,
    String? outputPath,
    bool countAttempt = false,
    EventType? event,
    Map<String, Object?> eventArgs = const {},
  });

  /// Checkpoints one leg (created on first save).
  Future<void> saveLeg(String taskId, TransferLeg leg);

  /// Replaces the task's legs (a new plan after re-resolving).
  Future<void> replaceLegs(String taskId, List<TransferLeg> legs);

  Future<void> addEvent(DownloadEvent event);

  /// `videoId|formatKey` pairs already in the queue (not cancelled).
  Future<Set<String>> existingKeys(
    Iterable<(String videoId, String formatKey)> keys,
  );

  /// Removes completed / cancelled tasks from the queue (the library keeps
  /// its rows). Returns how many were removed.
  Future<int> clearFinished();
}
