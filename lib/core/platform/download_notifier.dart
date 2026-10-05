import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/platform/notification_service.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/l10n/app_localizations.dart';

/// Turns the queue's outcomes into notifications — when the setting is on and
/// the app is not in front (in front, the Downloads tab already shows it).
class DownloadNotifier {
  DownloadNotifier(
    this._queue,
    this._settings,
    this._notifications, {
    bool Function()? inForeground,
  }) : _inForeground =
           inForeground ??
           (() =>
               WidgetsBinding.instance.lifecycleState ==
               AppLifecycleState.resumed);

  final DownloadQueueService _queue;
  final SettingsRepo _settings;
  final NotificationService _notifications;
  final bool Function() _inForeground;
  StreamSubscription<TaskOutcome>? _sub;

  void start() {
    _sub ??= _queue.outcomes.listen((outcome) => unawaited(_notify(outcome)));
  }

  Future<void> _notify(TaskOutcome outcome) async {
    final settings = _settings.current;
    if (!settings.notifications || _inForeground()) return;
    if (!await _notifications.ensurePermission()) return;
    final code =
        settings.languageCode ??
        PlatformDispatcher.instance.locale.languageCode;
    final l10n = lookupAppLocalizations(
      Locale(
        AppLocalizations.supportedLocales.any((l) => l.languageCode == code)
            ? code
            : 'en',
      ),
    );
    switch (outcome) {
      case TaskCompleted(:final taskId, :final title):
        await _notifications.show(
          id: _idOf(taskId),
          title: l10n.notificationDoneTitle,
          body: title,
          route: AppRoutes.library,
        );
      case TaskFailedOutcome(:final taskId, :final title, :final failure):
        if (failure.isSilent) return;
        await _notifications.show(
          id: _idOf(taskId),
          title: l10n.notificationFailedTitle,
          body: '$title — ${failureText(l10n, failure)}',
          route: AppRoutes.downloads,
        );
    }
  }

  /// A stable positive id per task (one banner per download).
  static int _idOf(String taskId) => taskId.hashCode & 0x7fffffff;

  Future<void> dispose() async => _sub?.cancel();
}
