import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';

part 'task_detail_state.freezed.dart';

@freezed
sealed class TaskDetailState with _$TaskDetailState {
  const factory TaskDetailState.loading() = TaskDetailLoading;
  const factory TaskDetailState.ready({
    required DownloadTask task,
    @Default(<DownloadEvent>[]) List<DownloadEvent> events,
  }) = TaskDetailReady;

  /// Cleared from the queue while open.
  const factory TaskDetailState.gone() = TaskDetailGone;
}
