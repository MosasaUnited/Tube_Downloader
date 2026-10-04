import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/quality_dropdown.dart';

/// Select all · Video/Audio · Quality for all · filter. Wraps on narrow windows.
class PlaylistToolbar extends StatelessWidget {
  const PlaylistToolbar({required this.state, super.key});

  final PlaylistReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<PlaylistCubit>();
    final all =
        state.availableCount > 0 && state.selectedCount == state.availableCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Wrap(
          spacing: Dimens.space16,
          runSpacing: Dimens.space12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(Dimens.radiusChip),
              onTap: () => cubit.selectAll(!all),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: all
                        ? true
                        : (state.selectedCount == 0 ? false : null),
                    tristate: true,
                    onChanged: (_) => cubit.selectAll(!all),
                  ),
                  Text(
                    l10n.playlistSelectAll,
                    style: Styles.font14Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  horizontalSpace(Dimens.space8),
                  Text(
                    l10n.playlistSelectedCount(
                      state.selectedCount,
                      state.availableCount,
                    ),
                    style: Styles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SegmentedButton<MediaKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: MediaKind.video,
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(l10n.formatVideoAudio),
                ),
                ButtonSegment(
                  value: MediaKind.audio,
                  icon: const Icon(Icons.music_note_outlined),
                  label: Text(l10n.formatAudioOnly),
                ),
              ],
              selected: {state.kind},
              onSelectionChanged: (s) => cubit.setKind(s.single),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.playlistQualityForAll,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                horizontalSpace(Dimens.space8),
                QualityDropdown(
                  kind: state.kind,
                  value: state.format,
                  onChanged: (f) {
                    if (f != null) cubit.setFormat(f);
                  },
                ),
              ],
            ),
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: cubit.setFilter,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.playlistFilterHint,
                  prefixIcon: const Icon(Icons.filter_list),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
