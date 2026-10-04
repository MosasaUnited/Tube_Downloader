import 'package:get_it/get_it.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/engine_config.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/yte_media_resolver.dart';
import 'package:tube_downloader/core/download_core/data/muxer/ffmpeg_kit_muxer.dart';
import 'package:tube_downloader/core/download_core/data/platform/connectivity_network_monitor.dart';
import 'package:tube_downloader/core/download_core/data/platform/io_file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/repos/library_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/transport/chunked_http_transport.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_muxer.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_transport.dart';
import 'package:tube_downloader/core/download_core/domain/repos/network_monitor.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_job.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/recovery_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';

/// The shared download core. Everything is registered against its domain
/// CONTRACT so cubits never see an implementation, and every implementation
/// can be swapped (a desktop yt-dlp resolver, a background transport).
void registerDownloadCoreDependencies(GetIt getIt) {
  getIt
    // Data
    ..registerLazySingleton<SettingsRepo>(() => SettingsRepoImpl(getIt()))
    ..registerLazySingleton<DownloadRepo>(
      () => DownloadRepoImpl(getIt<AppDatabase>()),
    )
    ..registerLazySingleton<LibraryRepo>(
      () => LibraryRepoImpl(getIt<AppDatabase>()),
    )
    ..registerLazySingleton<FileSystemGateway>(
      () => IoFileSystemGateway(getIt()),
    )
    ..registerLazySingleton<NetworkMonitor>(ConnectivityNetworkMonitor.new)
    // Engine — one gate paces every YouTube call app-wide.
    ..registerLazySingleton<ResolveGate>(ResolveGate.new)
    ..registerLazySingleton<EngineConfig>(() => EngineConfig.defaults)
    ..registerLazySingleton<MediaResolver>(
      () => YteMediaResolver(gate: getIt(), config: getIt()),
      dispose: (resolver) => resolver.close(),
    )
    ..registerLazySingleton<MediaTransport>(
      ChunkedHttpTransport.new,
      dispose: (transport) => (transport as ChunkedHttpTransport).close(),
    )
    ..registerLazySingleton<MediaMuxer>(FfmpegKitMuxer.new)
    // Services
    ..registerLazySingleton<JobDeps>(
      () => JobDeps(
        repo: getIt(),
        library: getIt(),
        settings: getIt(),
        resolver: getIt(),
        transport: getIt(),
        muxer: getIt(),
        fs: getIt(),
      ),
    )
    ..registerLazySingleton<DownloadQueueService>(
      () => DownloadQueueService(getIt(), network: getIt(), gate: getIt()),
      dispose: (queue) => queue.dispose(),
    )
    ..registerLazySingleton<RecoveryService>(
      () => RecoveryService(repo: getIt(), fs: getIt()),
    );
}
