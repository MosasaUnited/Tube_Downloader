import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/enqueue_result_snackbar.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/format_option_tile.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/save_destination_row.dart';

/// Video & Audio / Audio only, the quality rows, the destination and the
/// Download button. [includeButton] false leaves the button out (the phone
/// layout pins it to the bottom instead).
class FormatOptionsPanel extends StatelessWidget {
  const FormatOptionsPanel({
    required this.state,
    this.includeButton = true,
    super.key,
  });

  final SingleReady state;
  final bool includeButton;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<SingleLinkCubit>();
    final options = state.options.where((o) => o.kind == state.kind).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onSelectionChanged: (s) => cubit.selectKind(s.single),
            ),
            if (state.selected.requiresMerge) ...[
              verticalSpace(Dimens.space8),
              Text(
                l10n.formatMergeNote,
                style: Styles.font12Regular.copyWith(color: colors.textMuted),
              ),
            ],
            verticalSpace(Dimens.space16),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimens.space8),
                child: FormatOptionTile(
                  key: ValueKey(option.selector.key),
                  option: option,
                  selected: option == state.selected,
                  recommended: option == state.recommended,
                  onTap: () => cubit.select(option),
                ),
              ),
            verticalSpace(Dimens.space8),
            SaveDestinationRow(folder: state.saveDirectory),
            if (includeButton) ...[
              verticalSpace(Dimens.space16),
              DownloadButton(state: state),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Download · ~245 MB"; confirms with a snackbar that jumps to Downloads.
class DownloadButton extends StatelessWidget {
  const DownloadButton({required this.state, super.key});

  final SingleReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bytes = state.selected.estimatedBytes;
    return FilledButton.icon(
      onPressed: state.enqueuing ? null : () => _download(context),
      icon: state.enqueuing
          ? const SizedBox.square(
              dimension: Dimens.iconSize,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download),
      label: Text(
        bytes == null
            ? l10n.actionDownload
            : l10n.downloadWithSize(l10n.approximately(formatBytes(bytes))),
      ),
    );
  }

  static Future<void> _download(BuildContext context) async {
    final result = await context.read<SingleLinkCubit>().download();
    if (context.mounted && result != null) showEnqueueResult(context, result);
  }
}
