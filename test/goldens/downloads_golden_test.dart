@Tags(['golden'])
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../features/downloads/downloads_seed.dart';
import '../helpers/app_harness.dart';
import '../helpers/load_app_fonts.dart';

/// The Downloads tab with a download in every state.
/// Record on macOS: flutter test --update-goldens --tags golden
void main() {
  late Map<String, String> ids;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadAppFonts();
  });

  setUp(() async {
    await setupGetIt(const AppConfig.development(), database: testDatabase());
    await getIt<SettingsRepo>().load();
    ids = await seedEveryState(getIt<DownloadRepo>());
  });
  tearDown(() => getIt.reset());

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Size size,
    String? language,
    String? pushTask,
  }) async {
    await tester.runAsync(
      () => getIt<SettingsRepo>().update(
        (s) => s.copyWith(languageCode: language),
      ),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildAppRouter()..go(AppRoutes.downloads);
    await tester.pumpWidget(
      TubeDownloaderApp(config: const AppConfig.development(), router: router),
    );
    // Spinners never settle: fixed frames keep the picture deterministic.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (pushTask != null) {
      unawaited(router.push(AppRoutes.taskDetails(pushTask)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await expectLater(
      find.byType(TubeDownloaderApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    await unmountApp(tester);
  }

  testWidgets(
    'desktop · dark · Downloads with details',
    (t) => render(t, name: 'desktop_dark_queue', size: const Size(1440, 900)),
  );
  testWidgets(
    'desktop · dark · Arabic · Downloads',
    (t) => render(
      t,
      name: 'desktop_dark_ar_queue',
      size: const Size(1440, 900),
      language: 'ar',
    ),
  );
  testWidgets(
    'phone · dark · Downloads',
    (t) => render(t, name: 'phone_dark_queue', size: const Size(390, 844)),
  );
  testWidgets(
    'phone · dark · task details',
    (t) => render(
      t,
      name: 'phone_dark_task_details',
      size: const Size(390, 844),
      pushTask: ids['downloading'],
    ),
  );
}
