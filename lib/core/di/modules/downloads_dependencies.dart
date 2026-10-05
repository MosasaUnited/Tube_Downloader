import 'package:get_it/get_it.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_cubit.dart';
import 'package:tube_downloader/features/shell/logic/nav_badge_cubit/nav_badge_cubit.dart';

/// The Downloads tab, and the shell's Downloads badge (same counts).
void registerDownloadsDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<FileLauncher>(FileLauncher.new)
    ..registerFactory<DownloadsCubit>(
      () => DownloadsCubit(getIt(), getIt(), getIt()),
    )
    ..registerFactory<LiveProgressCubit>(() => LiveProgressCubit(getIt()))
    ..registerFactory<TaskDetailCubit>(
      () => TaskDetailCubit(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory<NavBadgeCubit>(() => NavBadgeCubit(getIt()));
}
