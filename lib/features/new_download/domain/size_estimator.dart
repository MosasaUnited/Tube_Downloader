import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';

/// Approximate file size from duration and quality — for playlist rows, where
/// fetching every video's manifest would cost one request per video (and
/// invite rate limits). Shown with "~"; the real size is known once the task
/// resolves. Bitrates are typical YouTube H.264 averages.
abstract final class SizeEstimator {
  static const _videoKbps = {
    2160: 18000,
    1440: 9000,
    1080: 4500,
    720: 2500,
    480: 1200,
    360: 700,
    240: 400,
    144: 200,
  };
  static const _aacKbps = 128;

  static int? estimate(Duration? duration, FormatSelector format) {
    if (duration == null || duration == Duration.zero) return null;
    final kbps = switch (format.kind) {
      MediaKind.audio => format.audioKbps ?? _aacKbps,
      MediaKind.video => _videoFor(format.maxHeight) + _aacKbps,
    };
    return (duration.inMilliseconds / 1000 * kbps * 1000 / 8).round();
  }

  static int _videoFor(int? maxHeight) {
    if (maxHeight == null) return _videoKbps[1080]!;
    final tier = _videoKbps.keys
        .where((h) => h <= maxHeight)
        .fold<int?>(null, (best, h) => best == null || h > best ? h : best);
    return _videoKbps[tier ?? 144]!;
  }
}
