import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/features/shell/logic/storage_meter_cubit/storage_meter_state.dart';

/// The sidebar's storage meter: the save folder and its free space, re-read
/// when the folder changes and after every finished download.
class StorageMeterCubit extends Cubit<StorageMeterState> {
  StorageMeterCubit(this._fs, this._settings, this._queue)
    : super(const StorageMeterState());

  final FileSystemGateway _fs;
  final SettingsRepo _settings;
  final DownloadQueueService _queue;
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<TaskOutcome>? _outcomesSub;

  void start() {
    var folder = _settings.current.saveDirectory;
    _settingsSub = _settings.watch().listen((s) {
      if (s.saveDirectory == folder) return;
      folder = s.saveDirectory;
      unawaited(refresh());
    });
    _outcomesSub = _queue.outcomes.listen((outcome) {
      if (outcome is TaskCompleted) unawaited(refresh());
    });
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final folder = await _fs.saveDirectory();
    final space = await _fs.space();
    if (!isClosed) emit(StorageMeterState(folder: folder, space: space));
  }

  @override
  Future<void> close() async {
    await _settingsSub?.cancel();
    await _outcomesSub?.cancel();
    return super.close();
  }
}
