import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_state.dart';

/// The Downloads tab: the filtered queue (playlists grouped), counts for the
/// filter chips, the queue's health, and which task the details pane shows.
/// Durable state comes from drift streams; every command goes to the queue.
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(this._repo, this._queue, this._files)
    : super(const DownloadsState());

  final DownloadRepo _repo;
  final DownloadQueueService _queue;
  final FileLauncher _files;

  StreamSubscription<List<DownloadTask>>? _tasksSub;
  StreamSubscription<List<GroupSummary>>? _groupsSub;
  StreamSubscription<Map<TaskFilter, int>>? _countsSub;
  StreamSubscription<QueueHealth>? _healthSub;

  List<DownloadTask> _tasks = const [];
  Map<String, GroupSummary> _groups = const {};

  /// Starts listening (called once by the screen's provider).
  void start() {
    _groupsSub = _repo.watchGroups().listen((groups) {
      _groups = {for (final g in groups) g.group.id: g};
      _rebuild();
    });
    _countsSub = _repo.watchCounts().listen((counts) {
      if (!isClosed) emit(state.copyWith(counts: counts));
    });
    emit(state.copyWith(health: _queue.currentHealth));
    _healthSub = _queue.health.listen((health) {
      if (!isClosed) emit(state.copyWith(health: health));
    });
    _watchTasks();
  }

  Future<void> setFilter(TaskFilter filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter));
    await _tasksSub?.cancel();
    if (isClosed) return;
    _watchTasks();
  }

  void toggleGroup(String groupId) {
    final expanded = {...state.expandedGroups};
    if (!expanded.remove(groupId)) expanded.add(groupId);
    emit(state.copyWith(expandedGroups: expanded));
  }

  void select(String taskId) => emit(state.copyWith(selectedId: taskId));

  Future<void> pause(String id) => _queue.pause(id);
  Future<void> resume(String id) => _queue.resume(id);
  Future<void> cancel(String id) => _queue.cancel(id);
  Future<void> retry(String id) => _queue.retry(id);
  Future<void> pauseAll() => _queue.pauseAll();
  Future<void> resumeAll() => _queue.resumeAll();
  Future<int> clearCompleted() => _queue.clearFinished();

  bool get canOpenFiles => _files.isSupported;

  /// The failure to report, or null when it opened.
  Future<AppFailure?> openFile(DownloadTask task) async =>
      task.outputPath == null ? null : _files.open(task.outputPath!);

  Future<AppFailure?> revealFile(DownloadTask task) async =>
      task.outputPath == null ? null : _files.reveal(task.outputPath!);

  /// Pauses every queued or running download of the playlist.
  Future<void> pauseGroup(String groupId) async {
    for (final task in _groupTasks(groupId)) {
      if (task.status == TaskStatus.queued || task.status.isActive) {
        await _queue.pause(task.id);
      }
    }
  }

  /// Resumes every paused download of the playlist.
  Future<void> resumeGroup(String groupId) async {
    for (final task in _groupTasks(groupId)) {
      if (task.status == TaskStatus.paused) await _queue.resume(task.id);
    }
  }

  void _watchTasks() {
    _tasksSub = _repo.watchTasks(state.filter).listen((tasks) {
      _tasks = tasks;
      _rebuild();
    });
  }

  Iterable<DownloadTask> _groupTasks(String groupId) =>
      _tasks.where((t) => t.groupId == groupId);

  /// Tasks in queue order; a playlist's tasks gather under one group entry
  /// at the position of its first task.
  void _rebuild() {
    if (isClosed) return;
    final items = <QueueItem>[];
    final groupIndex = <String, int>{};
    for (final task in _tasks) {
      final summary = task.groupId == null ? null : _groups[task.groupId];
      if (summary == null) {
        items.add(QueueItem.task(task));
        continue;
      }
      final at = groupIndex[summary.group.id];
      if (at == null) {
        groupIndex[summary.group.id] = items.length;
        items.add(QueueItem.group(summary: summary, tasks: [task]));
      } else {
        final group = items[at] as GroupQueueItem;
        items[at] = group.copyWith(tasks: [...group.tasks, task]);
      }
    }
    emit(
      state.copyWith(
        items: items,
        loaded: true,
        selectedId: _keepSelection(items),
      ),
    );
  }

  /// The selected task while it is still listed, else the first one (the
  /// pane is never empty while there is something to show).
  String? _keepSelection(List<QueueItem> items) {
    final tasks = DownloadsState(items: items).allTasks;
    final selected = state.selectedId;
    if (selected != null && tasks.any((t) => t.id == selected)) {
      return selected;
    }
    return tasks.firstOrNull?.id;
  }

  @override
  Future<void> close() async {
    await _tasksSub?.cancel();
    await _groupsSub?.cancel();
    await _countsSub?.cancel();
    await _healthSub?.cancel();
    return super.close();
  }
}
