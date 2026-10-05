import 'package:get_it/get_it.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/incoming_links.dart';
import 'package:tube_downloader/core/platform/link_file_reader.dart';
import 'package:tube_downloader/core/platform/share_intent_service.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_cubit.dart';

void registerNewDownloadDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<ClipboardService>(ClipboardService.new)
    ..registerLazySingleton<LinkFileReader>(LinkFileReader.new)
    ..registerLazySingleton<IncomingLinks>(
      IncomingLinks.new,
      dispose: (links) => links.dispose(),
    )
    ..registerLazySingleton<ShareIntentService>(
      () => ShareIntentService(getIt()),
      dispose: (service) => service.dispose(),
    )
    ..registerLazySingleton<EnqueueDownloadsUseCase>(
      () => EnqueueDownloadsUseCase(getIt(), getIt()),
    )
    ..registerFactory<LinkInputCubit>(
      () => LinkInputCubit(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory<SingleLinkCubit>(
      () => SingleLinkCubit(getIt(), getIt(), getIt()),
    )
    ..registerFactory<PlaylistCubit>(
      () => PlaylistCubit(getIt(), getIt(), getIt()),
    )
    ..registerFactory<BatchLinksCubit>(
      () => BatchLinksCubit(getIt(), getIt(), getIt(), getIt(), getIt()),
    );
}
