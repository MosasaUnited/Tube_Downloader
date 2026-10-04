import 'package:get_it/get_it.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';

/// Repos and services of the shared download core. Registered against their
/// domain CONTRACTS so cubits never see an implementation.
void registerDownloadCoreDependencies(GetIt getIt) {
  getIt.registerLazySingleton<SettingsRepo>(() => SettingsRepoImpl(getIt()));
}
