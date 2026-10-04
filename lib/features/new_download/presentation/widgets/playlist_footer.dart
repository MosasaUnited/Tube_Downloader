import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/enqueue_result_snackbar.dart';

/// Sticky bar: ~total size · subfolder toggle · "Download N videos".
class PlaylistFooter extends StatelessWidget {
  const PlaylistFooter({required this.state, super.key});

  final PlaylistReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<PlaylistCubit>();
    final count = state.selectedCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Dimens.space16,
          runSpacing: Dimens.space8,
          children: [
            Text(
              l10n.approximately(formatBytes(state.selectedBytes)),
              style: Styles.font20Bold.copyWith(color: ColorsManager.accent),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: state.subfolder, onChanged: cubit.setSubfolder),
                horizontalSpace(Dimens.space8),
                Flexible(
                  child: Text(
                    l10n.playlistSubfolder,
                    style: Styles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: count == 0 || state.enqueuing
                  ? null
                  : () async {
                      final result = await cubit.download();
                      if (context.mounted && result != null) {
                        showEnqueueResult(context, result);
                      }
                    },
              icon: state.enqueuing
                  ? const SizedBox.square(
                      dimension: Dimens.iconSize,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(l10n.playlistDownloadCount(count)),
            ),
          ],
        ),
      ),
    );
  }
}
