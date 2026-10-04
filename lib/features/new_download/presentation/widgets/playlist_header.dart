import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';

/// Cover, title, channel, "48 videos · 6:12:00", and a loading line while
/// items stream in.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({required this.state, super.key});

  final PlaylistReady state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final playlist = state.playlist;
    final count = playlist.videoCount ?? state.rows.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MediaThumbnail(url: playlist.thumbnailUrl, width: 160),
                horizontalSpace(Dimens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Styles.font20Bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (playlist.channel != null) ...[
                        verticalSpace(Dimens.space4),
                        Text(
                          playlist.channel!,
                          style: Styles.font14Bold.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      verticalSpace(Dimens.space4),
                      Text(
                        '${l10n.playlistVideosCount(count)} · ${formatDuration(state.totalDuration)}',
                        style: Styles.font12Regular.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.loadingMore) ...[
              verticalSpace(Dimens.space12),
              Text(
                l10n.playlistLoadingMore,
                style: Styles.font12Regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              verticalSpace(Dimens.space4),
              const LinearProgressIndicator(
                minHeight: Dimens.progressTrackHeight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
