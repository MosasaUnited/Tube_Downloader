import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/quality_dropdown.dart';

/// One playlist video: checkbox, #index, thumbnail, title, duration · ~size,
/// and its own quality (wide windows). Unavailable rows are dimmed.
class PlaylistRowTile extends StatelessWidget {
  const PlaylistRowTile({
    required this.row,
    required this.kind,
    required this.estimate,
    super.key,
  });

  final PlaylistRow row;
  final MediaKind kind;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final cubit = context.read<PlaylistCubit>();
    final wide = windowClassOf(context) != WindowClass.compact;
    final duration = row.media.duration;
    final meta = [
      if (duration != null) formatDuration(duration),
      if (estimate != null) l10n.approximately(formatBytes(estimate!)),
    ].join(' · ');
    return Opacity(
      opacity: row.unavailable ? 0.5 : 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
          onTap: row.unavailable ? null : () => cubit.toggle(row.index),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.space8,
              vertical: Dimens.space8,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: row.selected,
                  onChanged: row.unavailable
                      ? null
                      : (_) => cubit.toggle(row.index),
                ),
                if (wide)
                  SizedBox(
                    width: 44,
                    child: Text(
                      formatPlaylistIndex(row.index),
                      style: Styles.font12Bold.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                MediaThumbnail(
                  url: row.media.thumbnailUrl,
                  width: wide ? 128 : 96,
                  duration: duration,
                ),
                horizontalSpace(Dimens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Styles.font14Bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      verticalSpace(Dimens.space4),
                      if (row.unavailable)
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: ColorsManager.warning,
                            ),
                            horizontalSpace(Dimens.space4),
                            Text(
                              l10n.playlistUnavailable,
                              style: Styles.font12Bold.copyWith(
                                color: ColorsManager.warning,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          meta,
                          style: Styles.font12Regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (wide && !row.unavailable) ...[
                  horizontalSpace(Dimens.space12),
                  QualityDropdown(
                    kind: kind,
                    value: row.formatOverride,
                    defaultLabel: l10n.qualityDefault,
                    onChanged: (f) => cubit.setOverride(row.index, f),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
