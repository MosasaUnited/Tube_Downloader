import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_state.dart';

/// One task's details: the task and its event timeline, both live from
/// drift; commands go to the queue, files to the [FileLauncher].
class TaskDetailCubit extends Cubit<TaskDetailState> {
  TaskDetailCubit(this._repo, this._queue, this._files, this._clipboard)
    : super(const TaskDetailState.loading());

  final DownloadRepo _repo;
  final DownloadQueueService _queue;
  final FileLauncher _files;
  final ClipboardService _clipboard;

  StreamSubscription<DownloadTask?>? _taskSub;
  StreamSubscription<List<DownloadEvent>>? _eventsSub;
  String? _id;

  bool get canOpenFiles => _files.canOpen;
  bool get canRevealFiles => _files.canReveal;

  void watch(String id) {
    _id = id;
    _taskSub = _repo.watchTask(id).listen((task) {
      if (isClosed) return;
      if (task == null) return emit(const TaskDetailState.gone());
      final s = state;
      emit(
        s is TaskDetailReady
            ? s.copyWith(task: task)
            : TaskDetailState.ready(task: task),
      );
    });
    _eventsSub = _repo.watchEvents(id).listen((events) {
      final s = state;
      if (!isClosed && s is TaskDetailReady) emit(s.copyWith(events: events));
    });
  }

  Future<void> pause() => _command(_queue.pause);
  Future<void> resume() => _command(_queue.resume);
  Future<void> cancel() => _command(_queue.cancel);
  Future<void> retry() => _command(_queue.retry);

  Future<AppFailure?> openFile() => _withOutput(_files.open);
  Future<AppFailure?> revealFile() => _withOutput(_files.reveal);

  Future<void> copyLink() async {
    final s = state;
    if (s is TaskDetailReady) await _clipboard.writeText(s.task.media.url);
  }

  Future<void> _command(Future<void> Function(String id) run) async {
    final id = _id;
    if (id != null) await run(id);
  }

  Future<AppFailure?> _withOutput(
    Future<AppFailure?> Function(String path) run,
  ) async {
    final s = state;
    final path = s is TaskDetailReady ? s.task.outputPath : null;
    return path == null ? null : run(path);
  }

  @override
  Future<void> close() async {
    await _taskSub?.cancel();
    await _eventsSub?.cancel();
    return super.close();
  }
}
