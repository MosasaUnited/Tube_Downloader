import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/library/presentation/widgets/library_item_views.dart';
import 'package:tube_downloader/features/library/presentation/widgets/selection_bar.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../../helpers/app_harness.dart';
import 'library_seed.dart';

/// The Library tab in the real app: grid, list and selection at phone and
/// desktop sizes, in both languages and at 2× text — no overflow.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

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

  for (final (name, size, language, scale) in [
    ('phone', const Size(390, 844), null, 1.0),
    ('desktop', const Size(1440, 900), null, 1.0),
    ('phone ar', const Size(390, 844), 'ar', 1.0),
    ('desktop ar', const Size(1440, 900), 'ar', 1.0),
    ('phone 2x text', const Size(390, 844), null, 2.0),
    ('desktop 2x text', const Size(1440, 900), null, 2.0),
  ]) {
    testWidgets('grid, list and selection lay out: $name', (tester) async {
      await tester.runAsync(
        () => getIt<SettingsRepo>().update(
          (s) => s.copyWith(languageCode: language),
        ),
      );
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = buildAppRouter()..go(AppRoutes.library);
      await tester.pumpWidget(
        TubeDownloaderApp(
          config: const AppConfig.development(),
          router: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LibraryCard), findsWidgets);

      // Select: long-press a card, then the bar must fit.
      await tester.longPress(find.byType(LibraryCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionBar), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The list view, still selecting.
      await tester.tap(find.byIcon(Icons.view_list_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryListTile), findsWidgets);
      await tester.drag(
        find.byType(LibraryListTile).first,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await unmountApp(tester);
    });
  }
}
