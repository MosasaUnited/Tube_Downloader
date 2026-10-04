import 'package:flutter/material.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/app_theme.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// The qualities offered when no per-video manifest is fetched (playlists,
/// batches): a cap — the resolver picks the best stream at or under it.
abstract final class QualityLadder {
  static const video = [2160, 1440, 1080, 720, 480, 360];
  static const mp3 = [320, 192, 128];

  static List<FormatSelector> of(MediaKind kind) => kind == MediaKind.audio
      ? [
          const FormatSelector(
            kind: MediaKind.audio,
            container: OutContainer.m4a,
          ),
          for (final k in mp3)
            FormatSelector(
              kind: MediaKind.audio,
              container: OutContainer.mp3,
              audioKbps: k,
            ),
        ]
      : [
          for (final h in video)
            FormatSelector(
              kind: MediaKind.video,
              container: OutContainer.mp4,
              maxHeight: h,
            ),
        ];

  static String label(FormatSelector f) => switch (f.kind) {
    MediaKind.video => '${f.maxHeight ?? 1080}p · MP4',
    MediaKind.audio =>
      f.container == OutContainer.mp3
          ? 'MP3 · ${formatBitrate(f.audioKbps ?? 192)}'
          : 'M4A',
  };
}

/// A compact bordered dropdown over [QualityLadder]. With [defaultLabel], a
/// first entry (value null) means "use the playlist-wide quality".
/// [expanded] fills the given width (labels ellipsize) instead of sizing to
/// the widest item — for phones at large text sizes.
class QualityDropdown extends StatelessWidget {
  const QualityDropdown({
    required this.kind,
    required this.value,
    required this.onChanged,
    this.defaultLabel,
    this.expanded = false,
    super.key,
  });

  final MediaKind kind;
  final FormatSelector? value;
  final ValueChanged<FormatSelector?> onChanged;
  final String? defaultLabel;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ladder = QualityLadder.of(kind);
    // A value from another ladder (e.g. a Settings default not on it) shows as default.
    final current = ladder.contains(value)
        ? value
        : (defaultLabel != null ? null : ladder.first);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(Dimens.radiusChip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimens.space12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<FormatSelector?>(
            value: current,
            isDense: true,
            isExpanded: expanded,
            borderRadius: BorderRadius.circular(Dimens.radiusChip),
            // DropdownButton doesn't merge the ambient text style, so the
            // family is set here — otherwise it falls back to the system font.
            style: Styles.font14Bold.copyWith(
              color: colors.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
            dropdownColor: colors.surfaceRaised,
            onChanged: onChanged,
            items: [
              if (defaultLabel != null)
                DropdownMenuItem<FormatSelector?>(
                  child: Text(
                    defaultLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              for (final f in ladder)
                DropdownMenuItem<FormatSelector?>(
                  value: f,
                  child: Text(
                    QualityLadder.label(f),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
