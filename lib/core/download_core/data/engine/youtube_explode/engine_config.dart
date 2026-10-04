import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/app_youtube_clients.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// How the resolver talks to YouTube. Injected (never hard-coded at a call
/// site) so a client change is one edit — and, after v1, a remote override.
class EngineConfig {
  const EngineConfig({
    required this.manifestClients,
    this.manifestCacheTtl = const Duration(seconds: 30),
  });

  /// Clients for stream manifests, tried as one request (youtube_explode
  /// merges them). If they fail, the resolver falls back to the package
  /// defaults and offers only the muxed (360p) stream.
  final List<YoutubeApiClient> manifestClients;

  /// How long a manifest is reused between plan() and the first target().
  final Duration manifestCacheTtl;

  static const defaults = EngineConfig(
    manifestClients: [AppYoutubeClients.visionOs],
  );
}
