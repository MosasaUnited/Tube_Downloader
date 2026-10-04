import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/error/app_failure.dart';

part 'download_task.freezed.dart';

/// A request to enqueue one video.
@freezed
abstract class DownloadRequest with _$DownloadRequest {
  const factory DownloadRequest({
    required MediaInfo media,
    required FormatSelector format,
    int? playlistIndex,
  }) = _DownloadRequest;
}

/// One stream of a task and its checkpoint.
@freezed
abstract class TransferLeg with _$TransferLeg {
  const factory TransferLeg({
    required LegKind kind,
    required String tmpPath,
    @Default(0) int doneBytes,
    int? totalBytes,
    int? itag,
    String? ext,
    @Default(false) bool completed,
  }) = _TransferLeg;
}

/// A queued / running / finished download (durable state).
@freezed
abstract class DownloadTask with _$DownloadTask {
  const factory DownloadTask({
    required String id,
    required MediaInfo media,
    required FormatSelector format,
    required TaskStatus status,
    required int position,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? groupId,
    int? playlistIndex,
    PauseReason? pauseReason,
    AppFailure? failure,
    @Default(0) int attempt,
    DateTime? notBefore,
    @Default(<TransferLeg>[]) List<TransferLeg> legs,
    String? outputPath,
    DateTime? completedAt,
  }) = _DownloadTask;

  const DownloadTask._();

  /// Bytes on disk across legs / bytes expected (null when a size is unknown).
  int get doneBytes => legs.fold(0, (sum, l) => sum + l.doneBytes);
  int? get totalBytes => legs.any((l) => l.totalBytes == null) || legs.isEmpty
      ? null
      : legs.fold<int>(0, (sum, l) => sum + l.totalBytes!);
}

/// One playlist download.
@freezed
abstract class DownloadGroup with _$DownloadGroup {
  const factory DownloadGroup({
    required String id,
    required String playlistId,
    required String title,
    required int total,
    String? channel,

    /// Subfolder under the save directory ("playlist subfolders").
    String? subDir,
  }) = _DownloadGroup;
}

/// A group with its live counts ("12 of 32 done").
@freezed
abstract class GroupSummary with _$GroupSummary {
  const factory GroupSummary({
    required DownloadGroup group,
    required int completed,
    required int failed,
    required int active,
  }) = _GroupSummary;
}

/// A timeline entry. [args] holds data (bytes, itag, failure type), never text.
@freezed
abstract class DownloadEvent with _$DownloadEvent {
  const factory DownloadEvent({
    required String taskId,
    required EventType type,
    required DateTime at,
    @Default(<String, Object?>{}) Map<String, Object?> args,
  }) = _DownloadEvent;
}

/// Live, non-persisted progress of a running task (≤ 4 updates/s).
@freezed
abstract class LiveProgress with _$LiveProgress {
  const factory LiveProgress({
    required String taskId,
    required int doneBytes,
    int? totalBytes,
    LegKind? leg,
    @Default(0) double bytesPerSecond,
    Duration? eta,

    /// 0–1 while FFmpeg merges / converts.
    double? muxFraction,
  }) = _LiveProgress;
}

/// The Downloads tabs.
enum TaskFilter { all, active, queued, paused, completed, failed }
