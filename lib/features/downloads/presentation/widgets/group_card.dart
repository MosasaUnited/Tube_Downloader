import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/core/widgets/progress_track.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_state.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/presentation/task_labels.dart';

/// A playlist download: title, "12 of 32 done", overall progress, pause or
/// resume for the whole playlist, and its videos when expanded.
class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.item,
    required this.expanded,
    required this.onOpenTask,
    this.selectedId,
    super.key,
  });

  final GroupQueueItem item;
  final bool expanded;
  final ValueChanged<String> onOpenTask;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<DownloadsCubit>();
    final summary = item.summary;
    final group = summary.group;
    final fraction = group.total == 0 ? 0.0 : summary.completed / group.total;
    final running = item.tasks.any(
      (t) => t.status == TaskStatus.queued || t.status.isActive,
    );
    final paused = item.tasks.any((t) => t.status == TaskStatus.paused);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => cubit.toggleGroup(group.id),
            child: Padding(
              padding: const EdgeInsets.all(Dimens.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(
                            Dimens.radiusButton,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(Dimens.space12),
                          child: Icon(
                            Icons.playlist_play,
                            color: ColorsManager.accent,
                          ),
                        ),
                      ),
                      horizontalSpace(Dimens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: Dimens.space8,
                              runSpacing: Dimens.space4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  group.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Styles.font16Bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                FormatChip(l10n.newDownloadTabPlaylist),
                              ],
                            ),
                            verticalSpace(Dimens.space4),
                            Text(
                              l10n.groupDoneOfTotal(
                                '${summary.completed}',
                                '${group.total}',
                              ),
                              style: Styles.font12Regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (running)
                        IconButton(
                          tooltip: l10n.actionPauseAll,
                          onPressed: () => cubit.pauseGroup(group.id),
                          icon: const Icon(Icons.pause),
                        )
                      else if (paused)
                        IconButton(
                          tooltip: l10n.actionResumeAll,
                          onPressed: () => cubit.resumeGroup(group.id),
                          icon: const Icon(Icons.play_arrow),
                        ),
                      IconButton(
                        tooltip: expanded
                            ? l10n.actionCollapse
                            : l10n.actionExpand,
                        onPressed: () => cubit.toggleGroup(group.id),
                        icon: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                      ),
                    ],
                  ),
                  verticalSpace(Dimens.space12),
                  ProgressTrack(value: fraction, color: ColorsManager.primary),
                  verticalSpace(Dimens.space4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      formatPercent(fraction),
                      style: Styles.font12Bold.copyWith(
                        color: ColorsManager.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (final task in item.tasks)
              _GroupRow(
                task: task,
                selected: task.id == selectedId,
                onTap: () => onOpenTask(task.id),
              ),
        ],
      ),
    );
  }
}

/// "#13  Night Train to Kyoto        Downloading 92%"
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final DownloadTask task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = context.select((LiveProgressCubit c) => c.state[task.id]);
    final fraction = TaskLabels.fraction(task, live);
    final color = TaskLabels.color(task);
    final index = task.playlistIndex;
    final status = [
      TaskLabels.chip(context, task),
      if (task.status.isActive && fraction != null) formatPercent(fraction),
    ].join(' · ');
    return Material(
      color: selected ? colors.surfaceRaised : colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.space16,
            vertical: Dimens.space12,
          ),
          child: Row(
            children: [
              if (index != null) ...[
                Text(
                  formatPlaylistIndex(index),
                  style: Styles.font12Bold.copyWith(color: colors.textMuted),
                ),
                horizontalSpace(Dimens.space12),
              ],
              Expanded(
                child: Text(
                  task.media.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              horizontalSpace(Dimens.space12),
              Flexible(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font12Bold.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
