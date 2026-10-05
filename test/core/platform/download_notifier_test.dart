import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/platform/download_notifier.dart';
import 'package:tube_downloader/core/platform/notification_service.dart';
import 'package:tube_downloader/core/router/app_router.dart';

class _Queue extends Mock implements DownloadQueueService {}

class _Settings extends Mock implements SettingsRepo {}

class _Notifications extends Mock implements NotificationService {}

void main() {
  late _Queue queue;
  late _Settings settings;
  late _Notifications notifications;
  late StreamController<TaskOutcome> outcomes;
  late List<(String, String, String)> shown;
  var foreground = false;
  var settingsNow = const AppSettings(languageCode: 'en');

  setUp(() {
    queue = _Queue();
    settings = _Settings();
    notifications = _Notifications();
    outcomes = StreamController<TaskOutcome>.broadcast();
    shown = [];
    foreground = false;
    settingsNow = const AppSettings(languageCode: 'en');
    when(() => queue.outcomes).thenAnswer((_) => outcomes.stream);
    when(() => settings.current).thenAnswer((_) => settingsNow);
    when(() => notifications.ensurePermission()).thenAnswer((_) async => true);
    when(
      () => notifications.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        route: any(named: 'route'),
      ),
    ).thenAnswer((i) async {
      shown.add((
        i.namedArguments[#title] as String,
        i.namedArguments[#body] as String,
        i.namedArguments[#route] as String,
      ));
    });
  });
  tearDown(() => outcomes.close());

  DownloadNotifier start() => DownloadNotifier(
    queue,
    settings,
    notifications,
    inForeground: () => foreground,
  )..start();

  const done = TaskOutcome.completed(
    taskId: 't1',
    title: 'Ocean Sunrise',
    path: '/m.mp4',
  );
  const failed = TaskOutcome.failed(
    taskId: 't2',
    title: 'Keynote',
    failure: AppFailure(type: FailureType.privateVideo),
  );

  test('in the background: finished opens Library, failed opens Downloads '
      'with the reason', () async {
    start();
    outcomes
      ..add(done)
      ..add(failed);
    await pumpEventQueue();
    expect(shown, [
      ('Download complete', 'Ocean Sunrise', AppRoutes.library),
      (
        'Download failed',
        'Keynote — This video is private.',
        AppRoutes.downloads,
      ),
    ]);
  });

  test('in Arabic when the app is in Arabic', () async {
    settingsNow = const AppSettings(languageCode: 'ar');
    start();
    outcomes.add(done);
    await pumpEventQueue();
    expect(shown.single.$1, 'اكتمل التنزيل');
  });

  test('nothing in front, with the setting off, without permission, or for '
      'a cancel', () async {
    final notifier = start();
    foreground = true;
    outcomes.add(done);
    await pumpEventQueue();

    foreground = false;
    settingsNow = const AppSettings(notifications: false);
    outcomes.add(done);
    await pumpEventQueue();

    settingsNow = const AppSettings();
    when(() => notifications.ensurePermission()).thenAnswer((_) async => false);
    outcomes.add(done);
    await pumpEventQueue();

    when(() => notifications.ensurePermission()).thenAnswer((_) async => true);
    outcomes.add(
      const TaskOutcome.failed(
        taskId: 't3',
        title: 'x',
        failure: AppFailure(type: FailureType.cancelled),
      ),
    );
    await pumpEventQueue();
    expect(shown, isEmpty);
    await notifier.dispose();
  });
}
