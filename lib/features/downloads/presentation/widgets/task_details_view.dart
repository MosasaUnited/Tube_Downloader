import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';
import 'package:tube_downloader/core/widgets/progress_track.dart';
import 'package:tube_downloader/core/widgets/status_chip.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_state.dart';
import 'package:tube_downloader/features/downloads/presentation/task_labels.dart';

/// Everything about one download: header, progress ring, actions, the file,
/// the source link, its streams and the timeline of what happened. Used by
/// the side pane (wide windows) and the pushed screen (phones). Needs a
/// [LiveProgressCubit] above it.
class TaskDetailsView extends StatelessWidget {
  const TaskDetailsView({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskDetailCubit>(
      // A new cubit per task: the key below makes a selection change rebuild.
      key: ValueKey(taskId),
      create: (_) => getIt<TaskDetailCubit>()..watch(taskId),
      child: BlocBuilder<TaskDetailCubit, TaskDetailState>(
        builder: (context, state) => switch (state) {
          TaskDetailLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          TaskDetailGone() => EmptyState(
            icon: Icons.inventory_2_outlined,
            title: context.l10n.detailsGone,
          ),
          TaskDetailReady(:final task, :final events) => ListView(
            padding: const EdgeInsets.all(Dimens.space16),
            children: [
              _Header(task: task),
              verticalSpace(Dimens.space16),
              _ProgressBlock(task: task),
              verticalSpace(Dimens.space16),
              _DetailActions(task: task),
              verticalSpace(Dimens.space24),
              _Info(task: task),
              if (task.legs.isNotEmpty) ...[
                verticalSpace(Dimens.space24),
                _SectionTitle(context.l10n.detailsStreams),
                for (final leg in task.legs) _LegRow(leg: leg),
              ],
              verticalSpace(Dimens.space24),
              _SectionTitle(context.l10n.detailsTimeline),
              EventTimeline(events: events),
            ],
          ),
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaThumbnail(
            url: task.media.thumbnailUrl,
            width: constraints.maxWidth,
            duration: task.media.duration,
          ),
          verticalSpace(Dimens.space12),
          Text(
            task.media.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Styles.font18Bold.copyWith(color: colors.textPrimary),
          ),
          verticalSpace(Dimens.space4),
          Text(
            task.media.channel,
            style: Styles.font14Regular.copyWith(color: colors.textSecondary),
          ),
          verticalSpace(Dimens.space8),
          Wrap(
            spacing: Dimens.space8,
            runSpacing: Dimens.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FormatChip(formatSelectorLabel(task.format), highlighted: true),
              StatusChip(
                label: TaskLabels.chip(context, task),
                color: TaskLabels.color(task),
                icon: TaskLabels.icon(task),
                busy: task.status.isActive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The ring: percent, speed, bytes, time left (live while running).
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final live = context.select((LiveProgressCubit c) => c.state[task.id]);
    final fraction = TaskLabels.fraction(task, live);
    final color = TaskLabels.color(task);
    final done = live?.doneBytes ?? task.doneBytes;
    final total = live?.totalBytes ?? task.totalBytes;
    final speed = live?.bytesPerSecond ?? 0;
    final eta = live?.eta;
    final muted = Styles.font12Regular.copyWith(color: colors.textSecondary);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space16),
        child: Column(
          children: [
            ProgressRing(
              value: fraction,
              color: color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    child: Text(
                      fraction == null ? '—' : formatPercent(fraction),
                      style: Styles.font28Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (speed > 0)
                    Text(
                      formatSpeed(speed),
                      style: Styles.font14Bold.copyWith(color: color),
                    ),
                  if (total != null)
                    FittedBox(
                      child: Text(
                        l10n.sizeOfTotal(formatBytes(done), formatBytes(total)),
                        style: muted,
                      ),
                    ),
                ],
              ),
            ),
            verticalSpace(Dimens.space12),
            Text(
              [
                TaskLabels.status(context, task),
                if (eta != null) l10n.timeLeft(formatDuration(eta)),
              ].join(' · '),
              textAlign: TextAlign.center,
              style: Styles.font14Bold.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled buttons for what the state allows.
class _DetailActions extends StatelessWidget {
  const _DetailActions({required this.task});

  final DownloadTask task;

  Future<void> _report(BuildContext context, Future<AppFailure?> run) async {
    final failure = await run;
    if (context.mounted && failure != null) {
      showFailureSnackBar(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<TaskDetailCubit>();
    final cancel = OutlinedButton.icon(
      onPressed: cubit.cancel,
      icon: const Icon(Icons.close),
      label: Text(l10n.actionCancel),
    );
    final buttons = switch (task.status) {
      TaskStatus.queued ||
      TaskStatus.resolving ||
      TaskStatus.downloadingVideo ||
      TaskStatus.downloadingAudio => [
        FilledButton.tonalIcon(
          onPressed: cubit.pause,
          icon: const Icon(Icons.pause),
          label: Text(l10n.actionPause),
        ),
        cancel,
      ],
      TaskStatus.merging || TaskStatus.converting => [cancel],
      TaskStatus.paused => [
        FilledButton.icon(
          onPressed: cubit.resume,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.actionResume),
        ),
        cancel,
      ],
      TaskStatus.failed => [
        FilledButton.icon(
          onPressed: cubit.retry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.actionRetry),
        ),
        OutlinedButton.icon(
          onPressed: cubit.cancel,
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.actionRemove),
        ),
      ],
      TaskStatus.completed when cubit.canOpenFiles => [
        FilledButton.icon(
          onPressed: () => _report(context, cubit.openFile()),
          icon: const Icon(Icons.play_circle_outline),
          label: Text(l10n.actionOpen),
        ),
        OutlinedButton.icon(
          onPressed: () => _report(context, cubit.revealFile()),
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(l10n.actionShowInFolder),
        ),
      ],
      TaskStatus.completed || TaskStatus.cancelled => const <Widget>[],
    };
    return Wrap(
      spacing: Dimens.space8,
      runSpacing: Dimens.space8,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }
}

/// The finished file (when there is one) and the source link.
class _Info extends StatelessWidget {
  const _Info({required this.task});

  final DownloadTask task;

  Future<void> _copy(BuildContext context) async {
    await context.read<TaskDetailCubit>().copyLink();
    if (context.mounted) showInfoSnackBar(context, context.l10n.linkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final value = Styles.font14Regular.copyWith(color: colors.textPrimary);
    final output = task.outputPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (output != null) ...[
          _SectionTitle(l10n.detailsFile),
          LtrText(output, style: value, maxLines: 3),
          verticalSpace(Dimens.space16),
        ],
        _SectionTitle(l10n.detailsSource),
        Row(
          children: [
            const Icon(
              Icons.link,
              size: Dimens.iconSize,
              color: ColorsManager.accent,
            ),
            horizontalSpace(Dimens.space8),
            Expanded(child: LtrText(task.media.url, style: value)),
            IconButton(
              tooltip: l10n.actionCopyLink,
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Video · MP4 · 22.4 MB ✓" — one stream of the task and how far it got.
class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});

  final TransferLeg leg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final (icon, label) = switch (leg.kind) {
      LegKind.video => (Icons.videocam_outlined, l10n.legVideo),
      LegKind.audio => (Icons.music_note_outlined, l10n.legAudio),
      LegKind.muxed => (Icons.movie_outlined, l10n.legMuxed),
    };
    final total = leg.totalBytes;
    final size = total == null
        ? formatBytes(leg.doneBytes)
        : leg.completed
        ? formatBytes(total)
        : l10n.sizeOfTotal(formatBytes(leg.doneBytes), formatBytes(total));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.space4),
      child: Row(
        children: [
          Icon(icon, color: ColorsManager.accent),
          horizontalSpace(Dimens.space12),
          Expanded(
            child: Text(
              [label, ?leg.ext?.toUpperCase(), size].join(' · '),
              style: Styles.font14Regular.copyWith(color: colors.textPrimary),
            ),
          ),
          if (leg.completed)
            const Icon(Icons.check_circle, color: ColorsManager.success)
          else if (total != null && total > 0)
            SizedBox(
              width: Dimens.space48,
              child: ProgressTrack(value: leg.doneBytes / total),
            ),
        ],
      ),
    );
  }
}

/// "14:22:05 ● Video downloaded" — newest last, as it happened.
class EventTimeline extends StatelessWidget {
  const EventTimeline({required this.events, super.key});

  final List<DownloadEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Dimens.radiusButton),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Dimens.space4),
                child: Row(
                  children: [
                    Text(
                      formatTimeOfDay(e.at.toLocal()),
                      style: Styles.font12Regular.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    horizontalSpace(Dimens.space8),
                    Icon(
                      Icons.circle,
                      size: Dimens.space8,
                      color: TaskLabels.eventColor(e.type),
                    ),
                    horizontalSpace(Dimens.space8),
                    Expanded(
                      child: Text(
                        TaskLabels.event(context, e.type),
                        style: Styles.font14Regular.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.space8),
      child: Text(
        text.toUpperCase(),
        style: Styles.font12Bold.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}
