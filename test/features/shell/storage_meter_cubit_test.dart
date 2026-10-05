import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/features/shell/logic/storage_meter_cubit/storage_meter_cubit.dart';

class _Fs extends Mock implements FileSystemGateway {}

class _Settings extends Mock implements SettingsRepo {}

class _Queue extends Mock implements DownloadQueueService {}

void main() {
  late _Fs fs;
  late _Settings settings;
  late _Queue queue;
  late StreamController<AppSettings> settingsStream;
  late StreamController<TaskOutcome> outcomes;

  setUp(() {
    fs = _Fs();
    settings = _Settings();
    queue = _Queue();
    settingsStream = StreamController<AppSettings>.broadcast();
    outcomes = StreamController<TaskOutcome>.broadcast();
    when(() => settings.current).thenReturn(const AppSettings());
    when(() => settings.watch()).thenAnswer((_) => settingsStream.stream);
    when(() => queue.outcomes).thenAnswer((_) => outcomes.stream);
    when(() => fs.saveDirectory()).thenAnswer((_) async => '/Downloads/Tube');
    when(() => fs.space()).thenAnswer(
      (_) async => const StorageSpace(freeBytes: 10, totalBytes: 100),
    );
  });
  tearDown(() async {
    await settingsStream.close();
    await outcomes.close();
  });

  test('re-reads on start, a new folder and a finished download — not on '
      'other settings or failures', () async {
    final cubit = StorageMeterCubit(fs, settings, queue)..start();
    await pumpEventQueue();
    expect(cubit.state.folder, '/Downloads/Tube');
    expect(cubit.state.space?.freeBytes, 10);

    settingsStream.add(const AppSettings(maxConcurrent: 3)); // same folder
    outcomes.add(
      const TaskOutcome.failed(
        taskId: 't',
        title: 'x',
        failure: AppFailure(type: FailureType.unknown),
      ),
    );
    await pumpEventQueue();
    verify(() => fs.space()).called(1);

    settingsStream.add(const AppSettings(saveDirectory: '/Volumes/Media'));
    outcomes.add(
      const TaskOutcome.completed(taskId: 't', title: 'x', path: '/p.mp4'),
    );
    await pumpEventQueue();
    verify(() => fs.space()).called(2);
    await cubit.close();
  });
}
