import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

part 'format_selector.freezed.dart';
part 'format_selector.g.dart';

/// Which codec family to prefer for video. H.264 plays everywhere and muxes
/// into MP4 without re-encoding; [any] allows VP9 / AV1 (WebM) for qualities
/// that have no H.264 rendition, e.g. 4K.
enum VideoCodecPreference { h264, any }

/// WHAT the user asked for, never WHICH stream: itags and URLs expire and are
/// bound to the IP address, so a task stores this selector and every leg is
/// resolved just in time (docs/spike/phase0.md). Persisted as JSON in
/// `download_tasks.format_json` — [v] versions that JSON.
@freezed
abstract class FormatSelector with _$FormatSelector {
  const factory FormatSelector({
    required MediaKind kind,
    required OutContainer container,

    /// Video only; null = the best available.
    int? maxHeight,
    @Default(false) bool preferHighFps,
    @Default(VideoCodecPreference.h264) VideoCodecPreference codec,

    /// MP3 target bitrate (audio + mp3 only).
    int? audioKbps,
    @Default(1) int v,
  }) = _FormatSelector;

  factory FormatSelector.fromJson(Map<String, Object?> json) =>
      _$FormatSelectorFromJson(json);

  const FormatSelector._();

  /// Stable identity for duplicate detection with the video id
  /// (`download_tasks.format_key`).
  String get key =>
      '${kind.name}/${container.name}/${maxHeight ?? 'best'}/${preferHighFps ? 'hfr' : 'std'}/${codec.name}/${audioKbps ?? 0}';

  /// Audio legs only, converted to MP3 by FFmpeg.
  bool get requiresTranscode =>
      kind == MediaKind.audio && container == OutContainer.mp3;
}
