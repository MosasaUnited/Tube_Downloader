import 'package:flutter/material.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';

/// What the cards, group rows and details pane say about a task — one place,
/// so the three never disagree.
abstract final class TaskLabels {
  static String status(BuildContext context, DownloadTask task) {
    final l10n = context.l10n;
    final failure = task.failure;
    return switch (task.status) {
      TaskStatus.queued when task.notBefore?.isAfter(DateTime.now()) ?? false =>
        l10n.statusRetrying,
      TaskStatus.queued => l10n.statusQueued,
      TaskStatus.resolving => l10n.statusResolving,
      TaskStatus.downloadingVideo => l10n.statusDownloadingVideo,
      TaskStatus.downloadingAudio => l10n.statusDownloadingAudio,
      TaskStatus.merging => l10n.statusMerging,
      TaskStatus.converting => l10n.statusConverting,
      TaskStatus.completed => l10n.statusCompleted,
      TaskStatus.paused => switch (task.pauseReason) {
        PauseReason.waitingForWifi => l10n.statusWaitingWifi,
        PauseReason.offline => l10n.statusWaitingNetwork,
        _ => l10n.statusPaused,
      },
      TaskStatus.failed =>
        failure == null ? l10n.statusFailed : failureMessage(context, failure),
      TaskStatus.cancelled => l10n.statusCancelled,
    };
  }

  /// Short status for the status chip ("Failed", not the whole sentence).
  static String chip(BuildContext context, DownloadTask task) =>
      task.status == TaskStatus.failed
      ? context.l10n.statusFailed
      : status(context, task);

  static Color color(DownloadTask task) => switch (task.status) {
    TaskStatus.resolving ||
    TaskStatus.downloadingVideo ||
    TaskStatus.downloadingAudio => ColorsManager.accent,
    TaskStatus.merging || TaskStatus.converting => ColorsManager.primary,
    TaskStatus.completed => ColorsManager.success,
    TaskStatus.failed => ColorsManager.error,
    TaskStatus.paused when task.pauseReason != PauseReason.user =>
      ColorsManager.warning,
    TaskStatus.queued ||
    TaskStatus.paused ||
    TaskStatus.cancelled => ColorsManager.paused,
  };

  static IconData icon(DownloadTask task) => switch (task.status) {
    TaskStatus.queued => Icons.schedule,
    TaskStatus.resolving => Icons.travel_explore,
    TaskStatus.downloadingVideo ||
    TaskStatus.downloadingAudio => Icons.arrow_downward,
    TaskStatus.merging || TaskStatus.converting => Icons.sync,
    TaskStatus.completed => Icons.check_circle_outline,
    TaskStatus.paused => switch (task.pauseReason) {
      PauseReason.waitingForWifi => Icons.wifi_off,
      PauseReason.offline => Icons.cloud_off,
      _ => Icons.pause_circle_outline,
    },
    TaskStatus.failed => Icons.error_outline,
    TaskStatus.cancelled => Icons.cancel_outlined,
  };

  /// 0–1 for the progress bar: live bytes while running, the checkpoint
  /// otherwise, FFmpeg's own fraction while merging; null = indeterminate.
  static double? fraction(DownloadTask task, LiveProgress? live) {
    if (task.status == TaskStatus.completed) return 1;
    if (task.status == TaskStatus.resolving) return null;
    if (task.status == TaskStatus.merging ||
        task.status == TaskStatus.converting) {
      return live?.muxFraction;
    }
    final total = live?.totalBytes ?? task.totalBytes;
    if (total == null || total == 0) return null;
    return (live?.doneBytes ?? task.doneBytes) / total;
  }

  static String event(BuildContext context, EventType type) {
    final l10n = context.l10n;
    return switch (type) {
      EventType.requested => l10n.eventRequested,
      EventType.resolved => l10n.eventResolved,
      EventType.videoStarted => l10n.eventVideoStarted,
      EventType.videoDone => l10n.eventVideoDone,
      EventType.audioStarted => l10n.eventAudioStarted,
      EventType.audioDone => l10n.eventAudioDone,
      EventType.mergeStarted => l10n.eventMergeStarted,
      EventType.convertStarted => l10n.eventConvertStarted,
      EventType.reResolved => l10n.eventReResolved,
      EventType.paused => l10n.eventPaused,
      EventType.resumed => l10n.eventResumed,
      EventType.retried => l10n.eventRetried,
      EventType.completed => l10n.eventCompleted,
      EventType.failed => l10n.eventFailed,
      EventType.cancelled => l10n.eventCancelled,
    };
  }

  static Color eventColor(EventType type) => switch (type) {
    EventType.completed ||
    EventType.videoDone ||
    EventType.audioDone => ColorsManager.success,
    EventType.failed || EventType.cancelled => ColorsManager.error,
    EventType.reResolved || EventType.paused => ColorsManager.warning,
    EventType.mergeStarted || EventType.convertStarted => ColorsManager.primary,
    _ => ColorsManager.accent,
  };
}
