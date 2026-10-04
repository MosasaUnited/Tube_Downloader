import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

/// The legal task lifecycle. DownloadRepo.transition rejects anything else,
/// so a bug elsewhere can never leave a task in an impossible state.
abstract final class TaskStateMachine {
  static const Map<TaskStatus, Set<TaskStatus>> allowed = {
    TaskStatus.queued: {
      TaskStatus.resolving,
      TaskStatus.paused,
      TaskStatus.cancelled,
    },
    TaskStatus.resolving: {
      TaskStatus.downloadingVideo,
      TaskStatus.downloadingAudio,
      // Every leg is already on disk (recovered after a crash): straight to
      // the FFmpeg step, or done.
      TaskStatus.merging,
      TaskStatus.converting,
      TaskStatus.completed,
      TaskStatus.queued, // backoff, or recovery after a crash
      TaskStatus.paused,
      TaskStatus.failed,
      TaskStatus.cancelled,
    },
    TaskStatus.downloadingVideo: {
      TaskStatus.downloadingAudio,
      TaskStatus.completed, // single muxed leg
      TaskStatus.resolving, // stream expired: fresh URL, resume at offset
      TaskStatus.queued,
      TaskStatus.paused,
      TaskStatus.failed,
      TaskStatus.cancelled,
    },
    TaskStatus.downloadingAudio: {
      TaskStatus.merging,
      TaskStatus.converting,
      TaskStatus.completed, // audio-only without transcode
      TaskStatus.resolving,
      TaskStatus.queued,
      TaskStatus.paused,
      TaskStatus.failed,
      TaskStatus.cancelled,
    },
    // FFmpeg runs to the end: no pause. `queued` is crash recovery only.
    TaskStatus.merging: {
      TaskStatus.completed,
      TaskStatus.failed,
      TaskStatus.cancelled,
      TaskStatus.queued,
    },
    TaskStatus.converting: {
      TaskStatus.completed,
      TaskStatus.failed,
      TaskStatus.cancelled,
      TaskStatus.queued,
    },
    TaskStatus.paused: {TaskStatus.queued, TaskStatus.cancelled},
    TaskStatus.failed: {TaskStatus.queued, TaskStatus.cancelled},
    TaskStatus.completed: {},
    TaskStatus.cancelled: {},
  };

  static bool canTransition(TaskStatus from, TaskStatus to) =>
      allowed[from]!.contains(to);

  static void ensure(TaskStatus from, TaskStatus to) {
    if (!canTransition(from, to)) throw IllegalTransitionException(from, to);
  }
}

final class IllegalTransitionException implements Exception {
  const IllegalTransitionException(this.from, this.to);
  final TaskStatus from;
  final TaskStatus to;

  @override
  String toString() => 'IllegalTransitionException(${from.name} → ${to.name})';
}
