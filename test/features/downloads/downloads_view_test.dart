import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/downloads/presentation/screens/task_details_screen.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/group_card.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/task_card.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/task_details_view.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../../helpers/app_harness.dart';
import 'downloads_seed.dart';

/// The Downloads tab in the real app with a download in every state, at
/// phone and desktop sizes, in both languages and at 2× text: every card,
/// the open playlist and the details lay out without overflow.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Map<String, String> ids;

  setUp(() async {
    await setupGetIt(const AppConfig.development(), database: testDatabase());
    await getIt<SettingsRepo>().load();
    // Seeded here, outside the widget test's fake time.
    ids = await seedEveryState(getIt<DownloadRepo>());
  });
  tearDown(() => getIt.reset());

  /// Spinners and indeterminate bars never settle: pump fixed frames.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Steps a scrollable to its end so every lazy child is built.
  Future<void> scrollThrough(WidgetTester tester, Finder scrollable) async {
    final position = tester.state<ScrollableState>(scrollable).position;
    while (position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        math.min(position.pixels + 300, position.maxScrollExtent),
      );
      await tester.pump();
    }
    await frames(tester);
  }

  for (final (name, size, language, scale) in [
    ('phone', const Size(390, 844), null, 1.0),
    ('desktop', const Size(1440, 900), null, 1.0),
    ('phone ar', const Size(390, 844), 'ar', 1.0),
    ('desktop ar', const Size(1440, 900), 'ar', 1.0),
    ('phone 2x text', const Size(390, 844), null, 2.0),
    ('desktop 2x text', const Size(1440, 900), null, 2.0),
  ]) {
    testWidgets('every state lays out: $name', (tester) async {
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
      final router = buildAppRouter()..go(AppRoutes.downloads);
      await tester.pumpWidget(
        TubeDownloaderApp(
          config: const AppConfig.development(),
          router: router,
        ),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);

      final queue = find
          .ancestor(
            of: find.byType(TaskCard).first,
            matching: find.byType(Scrollable),
          )
          .first;
      // Open the playlist, then walk the whole list.
      await scrollThrough(tester, queue);
      await tester.tap(find.byIcon(Icons.expand_more));
      await frames(tester);
      await scrollThrough(tester, queue);
      expect(tester.takeException(), isNull);
      expect(find.byType(GroupCard), findsOneWidget);

      final wide = size.width >= 1024;
      if (wide) {
        expect(find.byType(TaskDetailsView), findsOneWidget);
        await scrollThrough(
          tester,
          find
              .descendant(
                of: find.byType(TaskDetailsView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      } else {
        unawaited(router.push(AppRoutes.taskDetails(ids['downloading']!)));
        await frames(tester);
        expect(find.byType(TaskDetailsScreen), findsOneWidget);
        await scrollThrough(
          tester,
          find
              .descendant(
                of: find.byType(TaskDetailsView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(tester.takeException(), isNull);
      await unmountApp(tester);
    });
  }
}
