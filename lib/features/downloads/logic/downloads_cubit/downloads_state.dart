import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';

part 'downloads_state.freezed.dart';

/// One entry of the queue list: a single download, or a playlist with the
/// downloads of it that match the current filter.
@freezed
sealed class QueueItem with _$QueueItem {
  const factory QueueItem.task(DownloadTask task) = TaskQueueItem;
  const factory QueueItem.group({
    required GroupSummary summary,
    required List<DownloadTask> tasks,
  }) = GroupQueueItem;
}

@freezed
abstract class DownloadsState with _$DownloadsState {
  const factory DownloadsState({
    @Default(TaskFilter.all) TaskFilter filter,
    @Default(<QueueItem>[]) List<QueueItem> items,

    /// Per filter, for the chips.
    @Default(<TaskFilter, int>{}) Map<TaskFilter, int> counts,
    @Default(QueueHealth()) QueueHealth health,
    @Default(<String>{}) Set<String> expandedGroups,

    /// The task in the details pane (wide windows).
    String? selectedId,

    /// False until the first list arrives (no empty-state flash).
    @Default(false) bool loaded,
  }) = _DownloadsState;
}

extension DownloadsStateX on DownloadsState {
  int countOf(TaskFilter filter) => counts[filter] ?? 0;

  /// Every task in the list, groups' children included, in order.
  Iterable<DownloadTask> get allTasks sync* {
    for (final item in items) {
      switch (item) {
        case TaskQueueItem(:final task):
          yield task;
        case GroupQueueItem(:final tasks):
          yield* tasks;
      }
    }
  }
}
