@Tags(['golden'])
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../helpers/load_app_fonts.dart';

/// The shell at real window sizes in both themes and both languages.
/// Record on macOS: flutter test --update-goldens --tags golden
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadAppFonts();
  });

  setUp(() async {
    await setupGetIt(
      const AppConfig.development(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    await getIt<SettingsRepo>().load();
  });
  tearDown(() => getIt.reset());

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Size size,
    required String route,
    ThemePreference theme = ThemePreference.dark,
    String? language,
  }) async {
    await getIt<SettingsRepo>().update(
      (s) => s.copyWith(theme: theme, languageCode: language),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final GoRouter router = buildAppRouter();
    await tester.pumpWidget(
      TubeDownloaderApp(config: const AppConfig.development(), router: router),
    );
    router.go(route);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(TubeDownloaderApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets(
    'desktop · dark · New',
    (t) => render(
      t,
      name: 'desktop_dark_new',
      size: const Size(1280, 820),
      route: AppRoutes.newDownload,
    ),
  );
  testWidgets(
    'desktop · light · Settings',
    (t) => render(
      t,
      name: 'desktop_light_settings',
      size: const Size(1280, 820),
      route: AppRoutes.settings,
      theme: ThemePreference.light,
    ),
  );
  testWidgets(
    'desktop · dark · Arabic · Settings',
    (t) => render(
      t,
      name: 'desktop_dark_ar_settings',
      size: const Size(1280, 820),
      route: AppRoutes.settings,
      language: 'ar',
    ),
  );
  testWidgets(
    'phone · dark · Downloads',
    (t) => render(
      t,
      name: 'phone_dark_downloads',
      size: const Size(390, 844),
      route: AppRoutes.downloads,
    ),
  );
}
