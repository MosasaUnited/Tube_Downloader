import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';

/// Bytes and speed of running tasks, by task id, from the queue (≤ 4 updates
/// a second, never written to drift). Widgets read it with a `BlocSelector`
/// on their own id, so a tick rebuilds one progress bar — not the list.
class LiveProgressCubit extends Cubit<Map<String, LiveProgress>> {
  LiveProgressCubit(DownloadQueueService queue) : super(queue.liveSnapshot) {
    _sub = queue.live.listen((live) {
      if (!isClosed) emit(live);
    });
  }

  late final StreamSubscription<Map<String, LiveProgress>> _sub;

  /// Total speed of everything running.
  double get bytesPerSecond =>
      state.values.fold(0, (sum, p) => sum + p.bytesPerSecond);

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
