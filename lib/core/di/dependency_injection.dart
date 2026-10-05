import 'package:get_it/get_it.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/di/modules/download_core_dependencies.dart';
import 'package:tube_downloader/core/di/modules/downloads_dependencies.dart';
import 'package:tube_downloader/core/di/modules/new_download_dependencies.dart';
import 'package:tube_downloader/core/di/modules/settings_dependencies.dart';

final GetIt getIt = GetIt.instance;

/// The ordered start-up block, then one call per module file in
/// `lib/core/di/modules/` (order inside a module never matters: everything
/// there is lazy or a factory). [database] is injected by tests.
///
/// test/core/di/dependency_injection_test.dart fails on a duplicate
/// registration, an unresolvable type, or a module file nobody calls.
Future<void> setupGetIt(AppConfig config, {AppDatabase? database}) async {
  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<AppDatabase>(
      database ?? AppDatabase(),
      dispose: (db) => db.close(),
    );

  registerDownloadCoreDependencies(getIt);
  registerDownloadsDependencies(getIt);
  registerNewDownloadDependencies(getIt);
  registerSettingsDependencies(getIt);
}
