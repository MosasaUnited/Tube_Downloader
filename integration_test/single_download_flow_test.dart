import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/recovery_service.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

/// A real download driven through the UI, inside the real app: paste a link,
/// Fetch, pick 360p, Download — then the queue resolves, downloads both legs,
/// merges them with FFmpeg and publishes the file. Fixture: Tears of Steel
/// (Blender Foundation, CC-BY). Needs the network.
///   flutter test integration_test/single_download_flow_test.dart -d macos --flavor development
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Pumps frames (real time passes in integration tests) until [finder]
  /// shows up — never pumpAndSettle: the loading shimmer animates forever.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) fail('timed out waiting for $finder');
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('paste → Fetch → 360p → Download → merged MP4 in the save folder', (
    tester,
  ) async {
    final saveDir = await Directory.systemTemp.createTemp('tube_it_save');
    await setupGetIt(
      const AppConfig.development(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    final settings = getIt<SettingsRepo>();
    await settings.load();
    await settings.update(
      (s) => s.copyWith(saveDirectory: saveDir.path, clipboardWatch: false),
    );
    await getIt<RecoveryService>().run();
    await getIt<DownloadQueueService>().start();

    await tester.pumpWidget(
      TubeDownloaderApp(
        config: const AppConfig.development(),
        router: buildAppRouter(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/R6MlUcmOul8',
    );
    await tester.pump();
    await tester.tap(find.text('Fetch'));
    await waitFor(tester, find.text('360p'));

    // The test window is small: scroll each target into view before tapping
    // (a tap on an off-screen widget only logs a warning).
    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(finder);
      await tester.pump();
    }

    debugPrint('[it] step: formats shown');
    await tapVisible(find.text('360p'));
    debugPrint('[it] step: 360p tapped');
    await tapVisible(find.textContaining('Download ·'));
    debugPrint('[it] step: download tapped');
    await waitFor(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 15),
    );
    final snack = tester.widgetList<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    );
    expect(
      snack.map((t) => t.data),
      contains('Download started'),
      reason: 'snackbar said: ${snack.map((t) => t.data).join(' / ')}',
    );

    // The queue takes it from here: resolve, two legs, FFmpeg merge, publish.
    final repo = getIt<DownloadRepo>();
    final queue = getIt<DownloadQueueService>();
    final started = DateTime.now();
    final end = started.add(const Duration(minutes: 4));
    var lastReport = started;
    // The task's own timeline shows which step took the time.
    Future<void> dumpEvents() async {
      final all = await repo.watchTasks(TaskFilter.all).first;
      for (final task in all) {
        for (final e in await repo.watchEvents(task.id).first) {
          // ignore: avoid_print — diagnostics for a long-running device test.
          print(
            '[it] event ${e.type.name} at t+'
            '${e.at.difference(started).inMilliseconds / 1000}s',
          );
        }
      }
    }

    DownloadTask? done;
    while (done == null) {
      if (DateTime.now().isAfter(end)) {
        await dumpEvents();
        fail('download did not complete');
      }
      // Real time, not tester.pump: a live pump waits for a frame, and macOS
      // sends none while the window is hidden or the display sleeps.
      await Future<void>.delayed(const Duration(seconds: 1));
      final all = await repo.watchTasks(TaskFilter.all).first;
      final failed = all.where((t) => t.status.name == 'failed');
      if (failed.isNotEmpty) {
        await dumpEvents();
        fail('download failed: ${failed.first.failure}');
      }
      done = all.where((t) => t.status.name == 'completed').firstOrNull;
      if (DateTime.now().difference(lastReport) > const Duration(seconds: 10)) {
        lastReport = DateTime.now();
        final live = queue.liveSnapshot.values
            .map((p) => '${p.doneBytes}/${p.totalBytes}')
            .join(',');
        // ignore: avoid_print — diagnostics for a long-running device test.
        print(
          '[it] t+${DateTime.now().difference(started).inSeconds}s '
          'tasks=${all.map((t) => t.status.name).join(',')} health=${queue.currentHealth} live=$live',
        );
        if (queue.currentHealth.offline) {
          fail('the queue believes the device is offline');
        }
      }
    }

    await dumpEvents();

    final file = File(done.outputPath!);
    expect(file.parent.path, saveDir.path);
    expect(file.path, endsWith('.mp4'));
    final info = (await FFprobeKit.getMediaInformation(file.path))
        .getMediaInformation()!;
    final streams = info.getStreams().map((s) => s.getType()).toSet();
    expect(
      streams,
      containsAll({'video', 'audio'}),
      reason: 'merged by FFmpeg inside the app',
    );
    expect(double.parse(info.getDuration()!), closeTo(734, 2));

    await getIt.reset();
    await saveDir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
