import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/progress_track.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_state.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';

/// Why the queue isn't moving (offline, waiting for Wi-Fi, YouTube's rate
/// limit) — nothing when it is.
class QueueHealthBanner extends StatelessWidget {
  const QueueHealthBanner({required this.health, super.key});

  final QueueHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cooldown = health.cooldownUntil;
    final (icon, text) = switch (health) {
      QueueHealth(offline: true) => (Icons.cloud_off, l10n.healthOffline),
      QueueHealth(waitingForWifi: true) => (Icons.wifi_off, l10n.healthWifi),
      _ when cooldown != null && cooldown.isAfter(clock.now()) => (
        Icons.hourglass_top,
        l10n.healthCooldown(formatTimeOfDay(cooldown.toLocal())),
      ),
      _ => (null, null),
    };
    if (icon == null || text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.space12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColorsManager.warning.withValues(alpha: 0.12),
          border: Border.all(
            color: ColorsManager.warning.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.space12),
          child: Row(
            children: [
              Icon(icon, color: ColorsManager.warning),
              horizontalSpace(Dimens.space12),
              Expanded(
                child: Text(
                  text,
                  style: Styles.font14Regular.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phones: "● Downloads queue  18.4 MB/s", "3 active · 2 queued · 1 failed",
/// what is left to download and one bar for all unfinished downloads.
class QueueSummaryCard extends StatelessWidget {
  const QueueSummaryCard({required this.state, super.key});

  final DownloadsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final live = context.watch<LiveProgressCubit>();
    final unfinished = state.allTasks.where(
      (t) => !t.status.isFinal && t.status != TaskStatus.failed,
    );
    var done = 0;
    var total = 0;
    for (final DownloadTask t in unfinished) {
      final p = live.state[t.id];
      done += p?.doneBytes ?? t.doneBytes;
      total += p?.totalBytes ?? t.totalBytes ?? 0;
    }
    final speed = live.bytesPerSecond;
    final counts = [
      l10n.queueActiveCount(state.countOf(TaskFilter.active)),
      l10n.queueQueuedCount(state.countOf(TaskFilter.queued)),
      if (state.countOf(TaskFilter.failed) > 0)
        l10n.queueFailedCount(state.countOf(TaskFilter.failed)),
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.circle,
                  size: Dimens.space12,
                  color: ColorsManager.accent,
                ),
                horizontalSpace(Dimens.space8),
                Expanded(
                  child: Text(
                    l10n.queueTitle,
                    style: Styles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (speed > 0)
                  Text(
                    formatSpeed(speed),
                    style: Styles.font14Bold.copyWith(
                      color: ColorsManager.accent,
                    ),
                  ),
              ],
            ),
            verticalSpace(Dimens.space8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: Dimens.space12,
              runSpacing: Dimens.space4,
              children: [
                Text(
                  counts,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (total > done)
                  Text(
                    l10n.sizeLeft(formatBytes(total - done)),
                    style: Styles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (total > 0) ...[
              verticalSpace(Dimens.space12),
              ProgressTrack(value: done / total),
            ],
          ],
        ),
      ),
    );
  }
}
