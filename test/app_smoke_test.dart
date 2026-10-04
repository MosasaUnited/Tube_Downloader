import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/settings/presentation/screens/settings_screen.dart';
import 'package:tube_downloader/features/shell/presentation/widgets/app_sidebar.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

/// The real app (DI, drift, router, shell, themes, l10n) at real window sizes.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    await setupGetIt(
      const AppConfig.development(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    await getIt<SettingsRepo>().load();
  });
  tearDown(() => getIt.reset());

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TubeDownloaderApp(
        config: const AppConfig.development(),
        router: buildAppRouter(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop window: extended sidebar, no bottom bar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1280, 820));

    expect(find.byType(AppSidebar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('New Download'), findsWidgets);
  });

  testWidgets('sidebar collapses to the 72px rail and expands back', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1280, 820));

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsOneWidget);
  });

  testWidgets('tablet width: rail without the sidebar toggle', (tester) async {
    await pumpApp(tester, const Size(800, 1100));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.byTooltip('Expand sidebar'), findsNothing);
  });

  testWidgets('phone: bottom navigation, no rail', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('choosing Arabic flips the whole app to RTL', (tester) async {
    await pumpApp(tester, const Size(1280, 820));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(SettingsScreen))),
      TextDirection.ltr,
    );

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(SettingsScreen))),
      TextDirection.rtl,
    );
    expect(
      find.text('الإعدادات'),
      findsWidgets,
      reason: 'Settings title in Arabic',
    );
    expect(
      getIt<SettingsRepo>().current.languageCode,
      'ar',
      reason: 'persisted',
    );
  });
}
