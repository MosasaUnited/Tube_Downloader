import 'package:get_it/get_it.dart';
import 'package:tube_downloader/core/platform/download_notifier.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/core/platform/notification_service.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_cubit.dart';
import 'package:tube_downloader/features/shell/logic/nav_badge_cubit/nav_badge_cubit.dart';
import 'package:tube_downloader/features/shell/logic/storage_meter_cubit/storage_meter_cubit.dart';

/// The Downloads tab, and the shell's Downloads badge and storage meter.
void registerDownloadsDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<FileLauncher>(FileLauncher.new)
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<DownloadNotifier>(
      () => DownloadNotifier(getIt(), getIt(), getIt()),
      dispose: (notifier) => notifier.dispose(),
    )
    ..registerFactory<DownloadsCubit>(
      () => DownloadsCubit(getIt(), getIt(), getIt()),
    )
    ..registerFactory<LiveProgressCubit>(() => LiveProgressCubit(getIt()))
    ..registerFactory<TaskDetailCubit>(
      () => TaskDetailCubit(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory<NavBadgeCubit>(() => NavBadgeCubit(getIt()))
    ..registerFactory<StorageMeterCubit>(
      () => StorageMeterCubit(getIt(), getIt(), getIt()),
    );
}
