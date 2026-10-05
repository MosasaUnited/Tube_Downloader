import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_state.dart';

/// All · Active · Queued · Paused · Completed · Failed, each with its count.
/// Scrolls sideways when the window is narrow.
class QueueFilterBar extends StatelessWidget {
  const QueueFilterBar({required this.state, super.key});

  final DownloadsState state;

  static String labelOf(BuildContext context, TaskFilter filter) {
    final l10n = context.l10n;
    return switch (filter) {
      TaskFilter.all => l10n.filterAll,
      TaskFilter.active => l10n.filterActive,
      TaskFilter.queued => l10n.filterQueued,
      TaskFilter.paused => l10n.filterPaused,
      TaskFilter.completed => l10n.filterCompleted,
      TaskFilter.failed => l10n.filterFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DownloadsCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in TaskFilter.values) ...[
            _FilterChip(
              label: labelOf(context, filter),
              count: state.countOf(filter),
              selected: state.filter == filter,
              alert: filter == TaskFilter.failed,
              onTap: () => cubit.setFilter(filter),
            ),
            horizontalSpace(Dimens.space8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.alert,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;

  /// Failed: the count turns red when there is something to look at.
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected
        ? ColorsManager.onPrimary
        : colors.textSecondary;
    final countColor = alert && count > 0 && !selected
        ? ColorsManager.error
        : (selected
              ? ColorsManager.onPrimary.withValues(alpha: 0.2)
              : colors.surfaceRaised);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ColorsManager.primary : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
          side: BorderSide(
            color: selected ? ColorsManager.primary : colors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Dimens.touchTarget - 8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.space12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: (selected ? Styles.font14Bold : Styles.font14Regular)
                        .copyWith(color: foreground),
                  ),
                  horizontalSpace(Dimens.space8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: countColor,
                      borderRadius: BorderRadius.circular(Dimens.radiusPill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimens.space8,
                        vertical: 2,
                      ),
                      child: Text(
                        '$count',
                        style: Styles.font12Bold.copyWith(
                          color: alert && count > 0 && !selected
                              ? ColorsManager.onPrimary
                              : foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pause all · Resume all · Clear completed.
class QueueControls extends StatelessWidget {
  const QueueControls({super.key});

  Future<void> _clear(BuildContext context) async {
    final cleared = await context.read<DownloadsCubit>().clearCompleted();
    if (context.mounted) {
      showInfoSnackBar(context, context.l10n.clearedCount(cleared));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DownloadsCubit>();
    // Phones: one row of icon buttons under a label, as in the mobile design.
    if (windowClassOf(context) == WindowClass.compact) {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.queueControls.toUpperCase(),
              style: Styles.font12Bold.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.actionPauseAll,
            onPressed: cubit.pauseAll,
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: l10n.actionResumeAll,
            onPressed: cubit.resumeAll,
            icon: const Icon(Icons.play_circle_outline),
          ),
          IconButton(
            tooltip: l10n.actionClearCompleted,
            onPressed: () => _clear(context),
            icon: const Icon(Icons.clear_all),
          ),
        ],
      );
    }
    return Wrap(
      spacing: Dimens.space8,
      runSpacing: Dimens.space8,
      children: [
        TextButton.icon(
          onPressed: cubit.pauseAll,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(l10n.actionPauseAll),
        ),
        TextButton.icon(
          onPressed: cubit.resumeAll,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(l10n.actionResumeAll),
        ),
        TextButton.icon(
          onPressed: () => _clear(context),
          icon: const Icon(Icons.clear_all),
          label: Text(l10n.actionClearCompleted),
        ),
      ],
    );
  }
}
