import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';

part 'format_option.freezed.dart';

/// One row of the quality picker ("1080p · 60fps · MP4 · ~245 MB").
@freezed
abstract class FormatOption with _$FormatOption {
  const factory FormatOption({
    required MediaKind kind,

    /// YouTube's quality label ("1080p60") — shown as is; a letterboxed film
    /// labelled 1080p may be 800 px tall (docs/spike/phase0.md).
    required String label,
    required OutContainer container,
    required FormatSelector selector,
    int? height,
    int? fps,
    String? videoCodec,
    String? audioCodec,
    int? bitrateKbps,

    /// Video + audio bytes (or audio only); null when the manifest omits it.
    int? estimatedBytes,

    /// Separate video and audio streams → FFmpeg merge.
    @Default(false) bool requiresMerge,

    /// MP3 output → FFmpeg transcode.
    @Default(false) bool requiresTranscode,
  }) = _FormatOption;
}
