import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_cubit.dart';

void main() {
  tearDown(() => getIt.reset());

  test('the graph builds and every registered contract resolves', () async {
    await setupGetIt(
      const AppConfig.development(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    await getIt<SettingsRepo>().load();

    expect(getIt<AppConfig>().flavor, AppFlavor.development);
    expect(getIt<SettingsRepo>(), isNotNull);
    expect(
      getIt<AppearanceCubit>(),
      same(getIt<AppearanceCubit>()),
      reason: 'app-root singleton',
    );
  });

  test('a duplicate registration fails loudly', () async {
    await setupGetIt(
      const AppConfig.development(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    expect(
      () => setupGetIt(
        const AppConfig.development(),
        database: AppDatabase(NativeDatabase.memory()),
      ),
      throwsA(anything),
    );
  });

  test('every module file is wired into setupGetIt', () {
    final setup = File('lib/core/di/dependency_injection.dart')
        .readAsStringSync();
    final modules = Directory('lib/core/di/modules')
        .listSync()
        .whereType<File>();
    for (final module in modules) {
      final fn = RegExp(r'void (register\w+Dependencies)\(')
          .firstMatch(module.readAsStringSync())
          ?.group(1);
      expect(
        fn,
        isNotNull,
        reason: '${module.path} declares no register…Dependencies function',
      );
      expect(
        setup,
        contains('$fn('),
        reason: '$fn is never called from setupGetIt',
      );
    }
  });
}
