import 'package:clock/clock.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/engine_config.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/yte_format_mapper.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/entities/stream_target.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';
import 'package:tube_downloader/core/error/app_exceptions.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// [MediaResolver] on youtube_explode_dart — the only class that knows it.
/// Every YouTube call goes through the shared [ResolveGate] (pacing, 429
/// cooldown); selection rules live in [YteFormatMapper].
class YteMediaResolver implements MediaResolver {
  YteMediaResolver({
    required this._gate,
    YoutubeExplode? youtube,
    this._config = EngineConfig.defaults,
    this._clock = const Clock(),
  }) : _yt = youtube ?? YoutubeExplode();

  final ResolveGate _gate;
  final YoutubeExplode _yt;
  final EngineConfig _config;
  final Clock _clock;
  final _manifests = <String, ({DateTime at, List<StreamCandidate> streams})>{};

  @override
  Future<Result<ResolvedLink>> resolve(ParsedLink link) => _guard(() async {
    return switch (link) {
      ParsedVideo(:final videoId) => ResolvedLink.single(
        _media(await _gate.run(() => _yt.videos.get(videoId))),
      ),
      ParsedPlaylist(:final playlistId) => ResolvedLink.playlist(
        _playlist(await _gate.run(() => _yt.playlists.get(playlistId))),
      ),
      ParsedUnsupported(:final input) => throw UnsupportedLinkException(input),
    };
  });

  @override
  Stream<Result<MediaInfo>> playlistItems(String playlistId) async* {
    try {
      await for (final video in _yt.playlists.getVideos(playlistId)) {
        yield Result.success(_media(video));
      }
    } on Object catch (e, s) {
      yield Result.failure(FailureMapper.map(e, s));
    }
  }

  @override
  Future<Result<List<FormatOption>>> formats(String videoId) => _guard(
    () async {
      final options = YteFormatMapper.options(await _streams(videoId));
      if (options.isEmpty) {
        throw VideoUnavailableException('No downloadable streams for $videoId');
      }
      return options;
    },
  );

  @override
  Future<Result<List<LegKind>>> plan(String videoId, FormatSelector selector) =>
      _guard(() async {
        final legs = YteFormatMapper.plan(await _streams(videoId), selector);
        if (legs == null) {
          throw VideoUnavailableException(
            'No stream matches ${selector.key} for $videoId',
          );
        }
        return legs;
      });

  @override
  Future<Result<StreamTarget>> target(
    String videoId,
    FormatSelector selector,
    LegKind leg,
  ) => _guard(() async {
    final stream = YteFormatMapper.pick(await _streams(videoId), selector, leg);
    final url = stream?.url;
    if (stream == null || url == null) {
      throw VideoUnavailableException('No ${leg.name} stream for $videoId');
    }
    final expire = int.tryParse(url.queryParameters['expire'] ?? '');
    return StreamTarget(
      leg: leg,
      itag: stream.itag,
      url: url,
      totalBytes: stream.bytes,
      ext: leg == LegKind.audio && stream.container == 'mp4'
          ? 'm4a'
          : stream.container,
      expiresAt: expire == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expire * 1000),
    );
  });

  @override
  void close() => _yt.close();

  /// Candidates for [videoId], reused for [EngineConfig.manifestCacheTtl] so
  /// plan() and the first target() share one request; later legs (minutes
  /// later) get a fresh manifest — and with it a fresh, unexpired URL.
  Future<List<StreamCandidate>> _streams(String videoId) async {
    final cached = _manifests[videoId];
    final now = _clock.now();
    if (cached != null &&
        now.difference(cached.at) < _config.manifestCacheTtl) {
      return cached.streams;
    }

    List<StreamCandidate> streams;
    try {
      final manifest = await _gate.run(
        () => _yt.videos.streams.getManifest(
          videoId,
          ytClients: _config.manifestClients,
        ),
      );
      streams = _candidates(manifest);
    } on VideoUnplayableException {
      rethrow; // private / age-restricted / live: final, don't spend another request
    } on Object {
      // The configured clients failed: the package defaults still serve the
      // muxed (360p) stream — their separate audio is 403, so offer muxed only.
      final fallback = await _gate.run(
        () => _yt.videos.streams.getManifest(videoId),
      );
      streams = _candidates(fallback)
          .where((s) => s.leg == LegKind.muxed)
          .toList();
    }
    _manifests[videoId] = (at: now, streams: streams);
    return streams;
  }

  static List<StreamCandidate> _candidates(StreamManifest m) => [
    for (final s in m.videoOnly)
      StreamCandidate(
        itag: s.tag,
        leg: LegKind.video,
        container: s.container.name,
        bytes: s.size.totalBytes,
        kbps: s.bitrate.kiloBitsPerSecond.round(),
        codec: s.videoCodec,
        height: _qualityClass(s.qualityLabel) ?? s.videoResolution.height,
        fps: s.framerate.framesPerSecond.round(),
        qualityLabel: s.qualityLabel,
        url: s.url,
      ),
    for (final s in m.audioOnly)
      StreamCandidate(
        itag: s.tag,
        leg: LegKind.audio,
        container: s.container.name,
        bytes: s.size.totalBytes,
        kbps: s.bitrate.kiloBitsPerSecond.round(),
        codec: s.audioCodec,
        url: s.url,
      ),
    for (final s in m.muxed)
      StreamCandidate(
        itag: s.tag,
        leg: LegKind.muxed,
        container: s.container.name,
        bytes: s.size.totalBytes,
        kbps: s.bitrate.kiloBitsPerSecond.round(),
        codec: s.videoCodec,
        height: _qualityClass(s.qualityLabel) ?? s.videoResolution.height,
        fps: s.framerate.framesPerSecond.round(),
        qualityLabel: s.qualityLabel,
        url: s.url,
      ),
  ];

  static final _qualityLabel = RegExp(r'^(\d+)p');

  /// "1080p60" → 1080. See StreamCandidate.height for why not pixels.
  static int? _qualityClass(String label) =>
      int.tryParse(_qualityLabel.firstMatch(label)?.group(1) ?? '');

  static MediaInfo _media(Video v) => MediaInfo(
    videoId: v.id.value,
    url: 'https://www.youtube.com/watch?v=${v.id.value}',
    title: v.title,
    channel: v.author,
    duration: v.duration,
    thumbnailUrl: v.thumbnails.highResUrl,
    isLive: v.isLive,
    viewCount: v.engagement.viewCount,
    uploadDate: v.uploadDate,
  );

  static PlaylistInfo _playlist(Playlist p) => PlaylistInfo(
    playlistId: p.id.value,
    url: 'https://www.youtube.com/playlist?list=${p.id.value}',
    title: p.title,
    channel: p.author.isEmpty ? null : p.author,
    videoCount: p.videoCount,
    thumbnailUrl: p.thumbnails.highResUrl,
  );

  /// Every public method: exceptions become typed failures, never escape.
  static Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }
}
