@Tags(['golden'])
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../helpers/app_harness.dart';
import '../helpers/load_app_fonts.dart';

/// The Settings tab. Record on macOS: flutter test --update-goldens --tags golden
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadAppFonts();
  });

  setUp(() async {
    await setupGetIt(const AppConfig.development(), database: testDatabase());
    await getIt<SettingsRepo>().load();
  });
  tearDown(() => getIt.reset());

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Size size,
    String? language,
  }) async {
    await tester.runAsync(
      () => getIt<SettingsRepo>().update(
        (s) => s.copyWith(languageCode: language, maxConcurrent: 4),
      ),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildAppRouter()..go(AppRoutes.settings);
    await tester.pumpWidget(
      TubeDownloaderApp(config: const AppConfig.development(), router: router),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(TubeDownloaderApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    await unmountApp(tester);
  }

  testWidgets(
    'desktop · dark · Settings',
    (t) =>
        render(t, name: 'desktop_dark_settings', size: const Size(1280, 1100)),
  );
  testWidgets(
    'phone · dark · Arabic · Settings',
    (t) => render(
      t,
      name: 'phone_dark_ar_settings',
      size: const Size(390, 1100),
      language: 'ar',
    ),
  );
}
