@Tags(['golden'])
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/url_input_bar.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

import '../helpers/load_app_fonts.dart';

class _Resolver extends Mock implements MediaResolver {}

const _links = '''
https://youtu.be/AAAAAAAAAAA
https://youtu.be/BBBBBBBBBBB
https://example.com/invalid-stream/99
https://youtu.be/AAAAAAAAAAA
https://youtu.be/PPPPPPPPPPP
''';

const _titles = {
  'AAAAAAAAAAA': ('Server Components Explained', 'Frontend Lab', 18),
  'BBBBBBBBBBB': ('Building a Raytracer from Scratch', 'Systems Lab', 42),
};

/// The Multiple-links tab with every row state.
/// Record on macOS: flutter test --update-goldens --tags golden
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    registerFallbackValue(const ParsedLink.unsupported(''));
    await loadAppFonts();
  });

  setUp(() async {
    await setupGetIt(
      const AppConfig.development(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    await getIt<SettingsRepo>().load();
    final resolver = _Resolver();
    when(() => resolver.resolve(any())).thenAnswer((invocation) async {
      final id = (invocation.positionalArguments.single as ParsedVideo).videoId;
      final known = _titles[id];
      if (known == null) {
        return const Result.failure(AppFailure(type: FailureType.privateVideo));
      }
      return Result.success(
        ResolvedLink.single(
          MediaInfo(
            videoId: id,
            url: 'https://www.youtube.com/watch?v=$id',
            title: known.$1,
            channel: known.$2,
            duration: Duration(minutes: known.$3, seconds: 15),
          ),
        ),
      );
    });
    await getIt.unregister<MediaResolver>();
    getIt.registerLazySingleton<MediaResolver>(() => resolver);
  });
  tearDown(() => getIt.reset());

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Size size,
    String? language,
  }) async {
    await getIt<SettingsRepo>().update(
      (s) => s.copyWith(languageCode: language),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildAppRouter()..go(AppRoutes.newDownload);
    await tester.pumpWidget(
      TubeDownloaderApp(config: const AppConfig.development(), router: router),
    );
    await tester.pumpAndSettle();
    tester
        .element(find.byType(UrlInputBar))
        .read<LinkInputCubit>()
        .receive(_links);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(TubeDownloaderApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets(
    'desktop · dark · Multiple links',
    (t) => render(t, name: 'desktop_dark_batch', size: const Size(1280, 900)),
  );
  testWidgets(
    'phone · dark · Multiple links',
    (t) => render(t, name: 'phone_dark_batch', size: const Size(390, 844)),
  );
  testWidgets(
    'phone · dark · Arabic · Multiple links',
    (t) => render(
      t,
      name: 'phone_dark_ar_batch',
      size: const Size(390, 844),
      language: 'ar',
    ),
  );
}
