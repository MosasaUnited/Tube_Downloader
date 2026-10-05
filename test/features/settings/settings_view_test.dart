import 'dart:math' as math;

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/settings/presentation/screens/settings_screen.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/name_template_dialog.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../../helpers/app_harness.dart';

/// Every Settings section and the file-name dialog at phone and desktop
/// sizes, in both languages and at 2× text — no overflow.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    await setupGetIt(const AppConfig.development(), database: testDatabase());
    await getIt<SettingsRepo>().load();
    // Above 3 at once shows the warning line too.
    await getIt<SettingsRepo>().update((s) => s.copyWith(maxConcurrent: 4));
  });
  tearDown(() => getIt.reset());

  for (final (name, size, language, scale) in [
    ('phone', const Size(390, 844), null, 1.0),
    ('desktop', const Size(1280, 820), null, 1.0),
    ('phone ar', const Size(390, 844), 'ar', 1.0),
    ('desktop ar', const Size(1280, 820), 'ar', 1.0),
    ('phone 2x text', const Size(390, 844), null, 2.0),
    ('desktop 2x text', const Size(1280, 820), null, 2.0),
  ]) {
    testWidgets('every section lays out: $name', (tester) async {
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
      final router = buildAppRouter()..go(AppRoutes.settings);
      await tester.pumpWidget(
        TubeDownloaderApp(
          config: const AppConfig.development(),
          router: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final list = find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      // The file-name dialog, from its Edit button.
      final edit = find.widgetWithText(
        TextButton,
        language == 'ar' ? 'تعديل' : 'Edit',
      );
      await tester.scrollUntilVisible(edit, 200, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(NameTemplateDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4)); // outside: dismiss
      await tester.pumpAndSettle();

      final position = tester.state<ScrollableState>(list).position;
      while (position.pixels < position.maxScrollExtent) {
        position.jumpTo(
          math.min(position.pixels + 300, position.maxScrollExtent),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await unmountApp(tester);
    });
  }
}
