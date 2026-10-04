import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/error/app_failure.dart';

part 'queue_types.freezed.dart';

/// A task's end, for notifications and snackbars.
@freezed
sealed class TaskOutcome with _$TaskOutcome {
  const factory TaskOutcome.completed({
    required String taskId,
    required String title,
    required String path,
  }) = TaskCompleted;
  const factory TaskOutcome.failed({
    required String taskId,
    required String title,
    required AppFailure failure,
  }) = TaskFailedOutcome;
}

/// Why the queue is not starting work right now (the Downloads header shows it).
@freezed
abstract class QueueHealth with _$QueueHealth {
  const factory QueueHealth({
    @Default(false) bool offline,
    @Default(false) bool waitingForWifi,
    DateTime? cooldownUntil,
  }) = _QueueHealth;
}
