import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';

/// The option preselected for the user, from their Settings defaults.
abstract final class DefaultFormatPicker {
  /// The Settings default as a quality cap, for lists without a fetched
  /// manifest (playlists, batches): MP3 at the default bitrate, or MP4 at the
  /// default maximum height.
  static FormatSelector selectorFor(MediaKind kind, AppSettings s) =>
      kind == MediaKind.audio
      ? FormatSelector(
          kind: MediaKind.audio,
          container: OutContainer.mp3,
          audioKbps: s.audioKbps,
        )
      : FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: s.defaultMaxHeight,
        );

  /// Video: the best row at or under the default quality, MP4 first (it plays
  /// everywhere); else the smallest row. Audio: MP3 at the default bitrate,
  /// else M4A, else the first audio row.
  static FormatOption? pick(
    List<FormatOption> options,
    MediaKind kind,
    AppSettings settings,
  ) {
    final ofKind = options.where((o) => o.kind == kind).toList();
    if (ofKind.isEmpty) return null;
    if (kind == MediaKind.audio) {
      return ofKind
              .where(
                (o) =>
                    o.container == OutContainer.mp3 &&
                    o.bitrateKbps == settings.audioKbps,
              )
              .firstOrNull ??
          ofKind.where((o) => o.container == OutContainer.m4a).firstOrNull ??
          ofKind.first;
    }
    final fitting =
        ofKind
            .where((o) => (o.height ?? 0) <= settings.defaultMaxHeight)
            .toList()
          ..sort((a, b) {
            final byHeight = (b.height ?? 0).compareTo(a.height ?? 0);
            if (byHeight != 0) return byHeight;
            return (a.container == OutContainer.mp4 ? 0 : 1).compareTo(
              b.container == OutContainer.mp4 ? 0 : 1,
            );
          });
    return fitting.firstOrNull ??
        (ofKind..sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0)))
            .first;
  }
}
