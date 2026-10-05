import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';
import 'package:tube_downloader/core/widgets/progress_track.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/presentation/task_labels.dart';

/// One download in the queue, in any state: thumbnail, title, format, a
/// status line (live speed and time left while running), the progress bar
/// and the actions that state allows. [onTap] opens its details.
class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final DownloadTask task;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = windowClassOf(context) == WindowClass.compact;
    final showProgress =
        task.status != TaskStatus.completed &&
        task.status != TaskStatus.failed &&
        !(task.status == TaskStatus.queued && task.doneBytes == 0);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
        side: BorderSide(
          color: selected ? ColorsManager.accent : colors.border,
          width: selected ? 2 : Dimens.borderWidth,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimens.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MediaThumbnail(
                    url: task.media.thumbnailUrl,
                    width: compact ? 104 : 128,
                    duration: task.media.duration,
                  ),
                  horizontalSpace(Dimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.media.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Styles.font14Bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        verticalSpace(Dimens.space4),
                        FormatChip(formatSelectorLabel(task.format)),
                        verticalSpace(Dimens.space4),
                        TaskStatusLine(task: task),
                      ],
                    ),
                  ),
                  _Actions(task: task, compact: compact),
                ],
              ),
              if (showProgress) ...[
                verticalSpace(Dimens.space12),
                TaskProgress(task: task),
              ],
              if (task.status == TaskStatus.failed && compact) ...[
                verticalSpace(Dimens.space8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        context.read<DownloadsCubit>().retry(task.id),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.actionRetry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "↓ 18.4 MB/s · 38s left" while downloading, otherwise the status in its
/// colour ("Waiting for Wi-Fi", the failure sentence, "Completed · 245 MB").
class TaskStatusLine extends StatelessWidget {
  const TaskStatusLine({required this.task, super.key});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = TaskLabels.color(task);
    final downloading =
        task.status == TaskStatus.downloadingVideo ||
        task.status == TaskStatus.downloadingAudio;
    final live = context.select(
      (LiveProgressCubit c) => downloading ? c.state[task.id] : null,
    );
    final eta = live?.eta;
    final text = switch (task.status) {
      _ when live != null && live.bytesPerSecond > 0 => [
        formatSpeed(live.bytesPerSecond),
        if (eta != null) l10n.timeLeft(formatDuration(eta)),
      ].join(' · '),
      TaskStatus.completed when task.totalBytes != null =>
        '${l10n.statusCompleted} · ${formatBytes(task.totalBytes!)}',
      _ => TaskLabels.status(context, task),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(TaskLabels.icon(task), size: Dimens.iconSmall, color: color),
        horizontalSpace(Dimens.space4),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Styles.font12Bold.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The bar, "1.4 GB of 2.1 GB" and the percentage. Rebuilds alone on each
/// live tick (it selects only its own task's progress).
class TaskProgress extends StatelessWidget {
  const TaskProgress({required this.task, super.key});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = context.select((LiveProgressCubit c) => c.state[task.id]);
    final fraction = TaskLabels.fraction(task, live);
    final done = live?.doneBytes ?? task.doneBytes;
    final total = live?.totalBytes ?? task.totalBytes;
    final muted = Styles.font12Regular.copyWith(color: colors.textSecondary);
    final bar = ProgressTrack(value: fraction, color: TaskLabels.color(task));
    // While FFmpeg works, the byte counts are done and say nothing new.
    if (task.status == TaskStatus.merging ||
        task.status == TaskStatus.converting) {
      return bar;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        verticalSpace(Dimens.space4),
        Row(
          children: [
            Expanded(
              child: Text(
                total == null
                    ? formatBytes(done)
                    : context.l10n.sizeOfTotal(
                        formatBytes(done),
                        formatBytes(total),
                      ),
                style: muted,
              ),
            ),
            if (fraction != null)
              Text(
                formatPercent(fraction),
                style: Styles.font12Bold.copyWith(
                  color: TaskLabels.color(task),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The icon buttons a state allows (merging can't be paused; a failed task
/// retries; a finished one opens).
class _Actions extends StatelessWidget {
  const _Actions({required this.task, required this.compact});

  final DownloadTask task;
  final bool compact;

  Future<void> _report(BuildContext context, Future<AppFailure?> run) async {
    final failure = await run;
    if (context.mounted && failure != null) {
      showFailureSnackBar(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DownloadsCubit>();
    final id = task.id;
    final buttons = switch (task.status) {
      TaskStatus.queued ||
      TaskStatus.resolving ||
      TaskStatus.downloadingVideo ||
      TaskStatus.downloadingAudio => [
        _Action(Icons.pause, l10n.actionPause, () => cubit.pause(id)),
        _Action(Icons.close, l10n.actionCancel, () => cubit.cancel(id)),
      ],
      TaskStatus.merging || TaskStatus.converting => [
        _Action(Icons.close, l10n.actionCancel, () => cubit.cancel(id)),
      ],
      TaskStatus.paused => [
        _Action(Icons.play_arrow, l10n.actionResume, () => cubit.resume(id)),
        _Action(Icons.close, l10n.actionCancel, () => cubit.cancel(id)),
      ],
      TaskStatus.failed => [
        if (!compact)
          _Action(Icons.refresh, l10n.actionRetry, () => cubit.retry(id)),
        _Action(
          Icons.delete_outline,
          l10n.actionRemove,
          () => cubit.cancel(id),
        ),
      ],
      TaskStatus.completed when cubit.canOpenFiles => [
        _Action(
          Icons.play_circle_outline,
          l10n.actionOpen,
          () => _report(context, cubit.openFile(task)),
        ),
        if (cubit.canRevealFiles)
          _Action(
            Icons.folder_open_outlined,
            l10n.actionShowInFolder,
            () => _report(context, cubit.revealFile(task)),
          ),
      ],
      TaskStatus.completed || TaskStatus.cancelled => const <_Action>[],
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in buttons)
          IconButton(
            tooltip: b.label,
            onPressed: b.onPressed,
            icon: Icon(b.icon),
          ),
      ],
    );
  }
}

class _Action {
  const _Action(this.icon, this.label, this.onPressed);

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}
