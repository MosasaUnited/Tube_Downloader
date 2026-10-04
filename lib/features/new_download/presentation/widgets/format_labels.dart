import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';

/// Display text for a format row. Technical tokens (resolutions, codecs,
/// containers) are the same in every language, as in system UIs.
abstract final class FormatLabels {
  static String title(FormatOption o) {
    if (o.kind == MediaKind.audio) {
      return o.container == OutContainer.mp3
          ? 'MP3 · ${formatBitrate(o.bitrateKbps ?? 0)}'
          : 'M4A';
    }
    final h = o.height ?? 0;
    final tier = switch (h) {
      >= 2160 => ' 4K',
      >= 1440 => ' 2K',
      >= 1080 => ' Full HD',
      >= 720 => ' HD',
      _ => '',
    };
    return '${h}p$tier';
  }

  /// "MP4 · H.264", "WebM · VP9", "AAC · 128 kbps".
  static String detail(FormatOption o) {
    if (o.kind == MediaKind.audio) {
      final codec = (o.audioCodec ?? '').startsWith('mp4a')
          ? 'AAC'
          : (o.audioCodec ?? '').toUpperCase();
      return o.container == OutContainer.mp3
          ? 'lame'
          : '$codec · ${formatBitrate(o.bitrateKbps ?? 0)}';
    }
    return '${o.container == OutContainer.webm ? 'WebM' : 'MP4'} · ${codec(o.videoCodec)}';
  }

  static String codec(String? raw) {
    final c = raw ?? '';
    if (c.startsWith('avc1')) return 'H.264';
    if (c.startsWith('av01')) return 'AV1';
    if (c.startsWith('vp9') || c.startsWith('vp09')) return 'VP9';
    return c.toUpperCase();
  }
}
