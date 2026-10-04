import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';

/// One stream from a manifest, reduced to what selection needs — so the
/// selection rules below are pure and unit-tested without YouTube.
class StreamCandidate {
  const StreamCandidate({
    required this.itag,
    required this.leg,
    required this.container,
    required this.bytes,
    required this.kbps,
    this.codec = '',
    this.height,
    this.fps,
    this.qualityLabel = '',
    this.url,
  });

  final int itag;

  /// The signed stream URL (absent in unit-test fixtures).
  final Uri? url;
  final LegKind leg;

  /// 'mp4' or 'webm'.
  final String container;
  final int bytes;
  final int kbps;

  /// Video codec for video/muxed legs ("avc1.640028", "av01…", "vp9"), audio
  /// codec for audio legs ("mp4a.40.2", "opus").
  final String codec;

  /// YouTube's QUALITY CLASS (the number in "1080p60"), not the pixel height:
  /// a letterboxed 1920×800 film is "1080p", and so is a portrait 1080×1920
  /// Short. Selection by pixel height would mis-rank both.
  final int? height;
  final int? fps;
  final String qualityLabel;

  bool get isH264 => codec.startsWith('avc1');
}

/// Picker rows, leg plans and stream picks for a selector.
abstract final class YteFormatMapper {
  static const mp3Bitrates = [320, 192, 128];

  // ── picker rows ──────────────────────────────────────────────────────────

  static List<FormatOption> options(List<StreamCandidate> streams) {
    final videos = streams.where((s) => s.leg == LegKind.video).toList();
    final muxed = streams.where((s) => s.leg == LegKind.muxed).toList();
    return [
      ...videos.isNotEmpty
          ? _videoOptions(videos, streams)
          : _muxedOptions(muxed),
      ..._audioOptions(streams),
    ];
  }

  /// One row per height, best variant first: H.264 in MP4 plays everywhere;
  /// AV1 in MP4 next; VP9 in WebM for heights with neither (e.g. 4K).
  static List<FormatOption> _videoOptions(
    List<StreamCandidate> videos,
    List<StreamCandidate> all,
  ) {
    final heights = videos.map((v) => v.height ?? 0).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final rows = <FormatOption>[];
    for (final height in heights) {
      final atHeight = videos.where((v) => v.height == height).toList()
        ..sort(_byPreference);
      final best = atHeight.first;
      final container = best.container == 'webm'
          ? OutContainer.webm
          : OutContainer.mp4;
      final audio = _bestAudio(all, container);
      final selector = FormatSelector(
        kind: MediaKind.video,
        container: container,
        maxHeight: height,
        preferHighFps: (best.fps ?? 30) > 30,
        codec: best.isH264
            ? VideoCodecPreference.h264
            : VideoCodecPreference.any,
      );
      rows.add(
        FormatOption(
          kind: MediaKind.video,
          label: best.qualityLabel.isNotEmpty
              ? best.qualityLabel
              : '${height}p',
          container: container,
          selector: selector,
          height: height,
          fps: best.fps,
          videoCodec: best.codec,
          audioCodec: audio?.codec,
          estimatedBytes: audio == null ? best.bytes : best.bytes + audio.bytes,
          requiresMerge: true,
        ),
      );
    }
    return rows;
  }

  static List<FormatOption> _muxedOptions(List<StreamCandidate> muxed) => [
    for (final m in [
      ...muxed,
    ]..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0)))
      FormatOption(
        kind: MediaKind.video,
        label: m.qualityLabel.isNotEmpty ? m.qualityLabel : '${m.height}p',
        container: OutContainer.mp4,
        selector: FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: m.height,
        ),
        height: m.height,
        fps: m.fps,
        videoCodec: m.codec,
        estimatedBytes: m.bytes,
      ),
  ];

  static List<FormatOption> _audioOptions(List<StreamCandidate> all) {
    final aac = _bestAudio(all, OutContainer.m4a);
    final any = _bestAudio(all, null);
    if (any == null) return const [];
    // Duration from the audio stream itself: bytes · 8 / bitrate.
    final seconds = any.kbps > 0 ? any.bytes * 8 / (any.kbps * 1000) : null;
    return [
      if (aac != null && aac.codec.startsWith('mp4a'))
        FormatOption(
          kind: MediaKind.audio,
          label: 'M4A',
          container: OutContainer.m4a,
          selector: const FormatSelector(
            kind: MediaKind.audio,
            container: OutContainer.m4a,
          ),
          audioCodec: aac.codec,
          bitrateKbps: aac.kbps,
          estimatedBytes: aac.bytes,
        ),
      for (final kbps in mp3Bitrates)
        FormatOption(
          kind: MediaKind.audio,
          label: 'MP3',
          container: OutContainer.mp3,
          selector: FormatSelector(
            kind: MediaKind.audio,
            container: OutContainer.mp3,
            audioKbps: kbps,
          ),
          audioCodec: 'mp3',
          bitrateKbps: kbps,
          estimatedBytes: seconds == null
              ? null
              : (seconds * kbps * 1000 / 8).round(),
          requiresTranscode: true,
        ),
    ];
  }

  // ── plans and picks ──────────────────────────────────────────────────────

  /// Legs to download for [selector], or null when the manifest can't serve
  /// it at all.
  static List<LegKind>? plan(
    List<StreamCandidate> streams,
    FormatSelector selector,
  ) {
    if (selector.kind == MediaKind.audio) {
      return pick(streams, selector, LegKind.audio) != null
          ? const [LegKind.audio]
          : null;
    }
    if (pick(streams, selector, LegKind.video) != null &&
        pick(streams, selector, LegKind.audio) != null) {
      return const [LegKind.video, LegKind.audio];
    }
    return pick(streams, selector, LegKind.muxed) != null
        ? const [LegKind.muxed]
        : null;
  }

  /// The stream for one leg: the best one within the selector's limits.
  static StreamCandidate? pick(
    List<StreamCandidate> streams,
    FormatSelector selector,
    LegKind leg,
  ) {
    switch (leg) {
      case LegKind.audio:
        final container = selector.kind == MediaKind.video
            ? selector.container
            : (selector.container == OutContainer.m4a
                  ? OutContainer.m4a
                  : null);
        return _bestAudio(streams, container) ?? _bestAudio(streams, null);
      case LegKind.video:
        final wanted = selector.container == OutContainer.webm ? 'webm' : 'mp4';
        var pool = streams
            .where((s) => s.leg == LegKind.video && s.container == wanted)
            .toList();
        if (selector.codec == VideoCodecPreference.h264 &&
            pool.any((s) => s.isH264)) {
          pool = pool.where((s) => s.isH264).toList();
        }
        return _withinHeight(pool, selector);
      case LegKind.muxed:
        return _withinHeight(
          streams.where((s) => s.leg == LegKind.muxed).toList(),
          selector,
        );
    }
  }

  /// Highest height ≤ maxHeight (fps by preference, then bitrate); if nothing
  /// is that small, the smallest available.
  static StreamCandidate? _withinHeight(
    List<StreamCandidate> pool,
    FormatSelector selector,
  ) {
    if (pool.isEmpty) return null;
    final max = selector.maxHeight;
    final fit = max == null
        ? pool
        : pool.where((s) => (s.height ?? 0) <= max).toList();
    if (fit.isEmpty) {
      return ([
        ...pool,
      ]..sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0))).first;
    }
    fit.sort((a, b) {
      final byHeight = (b.height ?? 0).compareTo(a.height ?? 0);
      if (byHeight != 0) return byHeight;
      final byFps = selector.preferHighFps
          ? (b.fps ?? 0).compareTo(a.fps ?? 0)
          : (a.fps ?? 0).compareTo(b.fps ?? 0);
      return byFps != 0 ? byFps : b.kbps.compareTo(a.kbps);
    });
    return fit.first;
  }

  /// Best audio for an output container: AAC (mp4) for MP4 / M4A, Opus (webm)
  /// for WebM; null container = any.
  static StreamCandidate? _bestAudio(
    List<StreamCandidate> streams,
    OutContainer? container,
  ) {
    final wanted = switch (container) {
      OutContainer.webm => 'webm',
      OutContainer.mp4 || OutContainer.m4a => 'mp4',
      _ => null,
    };
    final pool =
        streams
            .where(
              (s) =>
                  s.leg == LegKind.audio &&
                  (wanted == null || s.container == wanted),
            )
            .toList()
          ..sort((a, b) => b.kbps.compareTo(a.kbps));
    return pool.firstOrNull;
  }

  /// H.264 first, then AV1 (both MP4), then anything; higher fps, then bitrate.
  static int _byPreference(StreamCandidate a, StreamCandidate b) {
    int rank(StreamCandidate s) =>
        s.isH264 ? 0 : (s.container == 'mp4' ? 1 : 2);
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final byFps = (b.fps ?? 0).compareTo(a.fps ?? 0);
    return byFps != 0 ? byFps : b.kbps.compareTo(a.kbps);
  }
}
