import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';

/// The number on the Downloads destination: downloads still in progress
/// (running or waiting their turn).
class NavBadgeCubit extends Cubit<int> {
  NavBadgeCubit(this._repo) : super(0);

  final DownloadRepo _repo;
  StreamSubscription<Map<TaskFilter, int>>? _sub;

  void start() {
    _sub = _repo.watchCounts().listen((counts) {
      if (isClosed) return;
      emit((counts[TaskFilter.active] ?? 0) + (counts[TaskFilter.queued] ?? 0));
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
