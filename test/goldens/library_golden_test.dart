@Tags(['golden'])
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/library/presentation/widgets/library_item_views.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../features/library/library_seed.dart';
import '../helpers/app_harness.dart';
import '../helpers/load_app_fonts.dart';

/// The Library tab. Record on macOS: flutter test --update-goldens --tags golden
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadAppFonts();
  });

  late Directory files;

  setUp(() async {
    files = await Directory.systemTemp.createTemp('library');
    await setupGetIt(const AppConfig.development(), database: testDatabase());
    await getIt<SettingsRepo>().load();
    await seedLibrary(getIt<LibraryRepo>(), files);
  });
  tearDown(() async {
    await getIt.reset();
    await files.delete(recursive: true);
  });

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Size size,
    String? language,
    bool select = false,
    bool list = false,
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
    final router = buildAppRouter()..go(AppRoutes.library);
    await tester.pumpWidget(
      TubeDownloaderApp(config: const AppConfig.development(), router: router),
    );
    await tester.pumpAndSettle();
    if (list) {
      await tester.tap(find.byIcon(Icons.view_list_outlined));
      await tester.pumpAndSettle();
    }
    if (select) {
      final cards = list
          ? find.byType(LibraryListTile)
          : find.byType(LibraryCard);
      await tester.longPress(cards.first);
      await tester.pumpAndSettle();
      await tester.tap(cards.at(2));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(TubeDownloaderApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    await unmountApp(tester);
  }

  testWidgets(
    'desktop · dark · Library grid',
    (t) => render(t, name: 'desktop_dark_library', size: const Size(1440, 900)),
  );
  testWidgets(
    'phone · dark · Library selecting',
    (t) => render(
      t,
      name: 'phone_dark_library_select',
      size: const Size(390, 844),
      select: true,
    ),
  );
  testWidgets(
    'phone · dark · Arabic · Library list',
    (t) => render(
      t,
      name: 'phone_dark_ar_library_list',
      size: const Size(390, 844),
      language: 'ar',
      list: true,
    ),
  );
}
