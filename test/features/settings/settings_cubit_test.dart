import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/folder_picker.dart';
import 'package:tube_downloader/core/platform/notification_service.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_cubit.dart';

class _Fs extends Mock implements FileSystemGateway {}

class _Picker extends Mock implements FolderPicker {}

class _Notifications extends Mock implements NotificationService {}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late SettingsRepoImpl settings;
  late _Fs fs;
  late _Picker picker;
  var folder = '/default/Tube Downloader';

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    settings = SettingsRepoImpl(db);
    await settings.load();
    fs = _Fs();
    picker = _Picker();
    folder = '/default/Tube Downloader';
    when(() => fs.saveDirectory()).thenAnswer((_) async => folder);
    when(() => fs.space()).thenAnswer(
      (_) async => const StorageSpace(freeBytes: 40, totalBytes: 100),
    );
    when(() => picker.isSupported).thenReturn(true);
  });
  tearDown(() => db.close());

  Future<SettingsCubit> started() async {
    final cubit = SettingsCubit(settings, fs, picker, _Notifications())
      ..start();
    await pumpEventQueue();
    return cubit;
  }

  test('shows the save folder and its space; re-reads both when the '
      'folder changes', () async {
    final cubit = await started();
    expect(cubit.state.saveDirectory, '/default/Tube Downloader');
    expect(cubit.state.space?.usedFraction, closeTo(0.6, 1e-9));

    folder = '/Volumes/Media';
    when(() => picker.pick(initialDirectory: any(named: 'initialDirectory')))
        .thenAnswer((_) async => const Result.success('/Volumes/Media'));
    expect(await cubit.pickFolder(), isNull);
    await pumpEventQueue();
    expect(settings.current.saveDirectory, '/Volumes/Media');
    expect(cubit.state.saveDirectory, '/Volumes/Media');
    verify(() => fs.space()).called(2);

    await cubit.resetFolder();
    await pumpEventQueue();
    expect(settings.current.saveDirectory, isNull);
    await cubit.close();
  });

  test(
    'a cancelled picker changes nothing; a failing one is reported',
    () async {
      final cubit = await started();
      when(() => picker.pick(initialDirectory: any(named: 'initialDirectory')))
          .thenAnswer((_) async => const Result.success(null));
      expect(await cubit.pickFolder(), isNull);
      expect(settings.current.saveDirectory, isNull);

      when(() => picker.pick(initialDirectory: any(named: 'initialDirectory')))
          .thenAnswer(
            (_) async => const Result.failure(
              AppFailure(type: FailureType.permissionDenied),
            ),
          );
      expect((await cubit.pickFolder())?.type, FailureType.permissionDenied);
      await cubit.close();
    },
  );

  test('downloads at once stays within 1…5; the pattern is trimmed', () async {
    final cubit = await started();
    await cubit.setMaxConcurrent(9);
    expect(settings.current.maxConcurrent, 5);
    await cubit.setMaxConcurrent(0);
    expect(settings.current.maxConcurrent, 1);
    await cubit.setNameTemplate('  {channel} - {title}  ');
    expect(settings.current.nameTemplate, '{channel} - {title}');
    await pumpEventQueue();
    expect(cubit.state.settings.nameTemplate, '{channel} - {title}');
    await cubit.close();
  });

  test('closed before the storage answers: nothing is emitted', () async {
    final cubit = SettingsCubit(settings, fs, picker, _Notifications())
      ..start();
    await cubit.close();
    await pumpEventQueue();
    expect(cubit.state.saveDirectory, isNull);
  });
}
