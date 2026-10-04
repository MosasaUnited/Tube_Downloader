import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/enqueue_result_snackbar.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/save_destination_row.dart';

/// Sticky bar: "12 ready · 1 invalid · 1 duplicate" · ~size · where it saves
/// · "Download 12 videos".
class BatchFooter extends StatelessWidget {
  const BatchFooter({required this.state, super.key});

  final BatchLinksState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = windowClassOf(context) == WindowClass.compact;
    final count = state.readyItems.length;
    final summary = Wrap(
      spacing: Dimens.space12,
      runSpacing: Dimens.space4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Count(
          label: l10n.batchSummaryReady(count),
          color: ColorsManager.success,
        ),
        if (state.count(BatchItemStatus.invalid) case final n when n > 0)
          _Count(
            label: l10n.batchSummaryInvalid(n),
            color: ColorsManager.error,
          ),
        if (state.count(BatchItemStatus.failed) case final n when n > 0)
          _Count(label: l10n.batchSummaryFailed(n), color: ColorsManager.error),
        if (state.count(BatchItemStatus.duplicate) case final n when n > 0)
          _Count(
            label: l10n.batchSummaryDuplicate(n),
            color: ColorsManager.warning,
          ),
        if (count > 0)
          Text(
            l10n.approximately(formatBytes(state.readyBytes)),
            style: Styles.font16Bold.copyWith(color: ColorsManager.accent),
          ),
      ],
    );
    final button = FilledButton.icon(
      onPressed: count == 0 || state.enqueuing
          ? null
          : () async {
              final result = await context.read<BatchLinksCubit>().download();
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
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, verticalSpace(Dimens.space12), button],
              )
            // The button keeps its place at the end; the counts and the
            // destination share the rest and flow onto a second line at large
            // text sizes instead of squeezing.
            : Row(
                children: [
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Dimens.space24,
                      runSpacing: Dimens.space12,
                      children: [
                        summary,
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: Dimens.destinationWidth,
                          ),
                          child: SaveDestinationRow(
                            folder: state.saveDirectory,
                          ),
                        ),
                      ],
                    ),
                  ),
                  horizontalSpace(Dimens.space16),
                  button,
                ],
              ),
      ),
    );
  }
}

/// "● 12 ready"
class _Count extends StatelessWidget {
  const _Count({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: Dimens.space8, color: color),
        horizontalSpace(Dimens.space4),
        Text(label, style: Styles.font14Bold.copyWith(color: color)),
      ],
    );
  }
}
