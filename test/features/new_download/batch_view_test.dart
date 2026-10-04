import 'dart:math' as math;

import 'package:drift/drift.dart' hide isNull;
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
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_footer.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_item_tile.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_view.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/url_input_bar.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

class _Resolver extends Mock implements MediaResolver {}

/// Every row state: ready ×2, invalid, duplicate, playlist, failed (private,
/// with no retry) and failed (offline, with retry).
const _links = '''
https://youtu.be/AAAAAAAAAAA
https://example.com/invalid-stream/99
https://youtu.be/BBBBBBBBBBB
https://youtu.be/AAAAAAAAAAA
https://www.youtube.com/playlist?list=PLabcdefghij12
https://youtu.be/PPPPPPPPPPP
https://youtu.be/OOOOOOOOOOO
''';

/// The Multiple-links tab inside the real app, at phone and desktop sizes,
/// in both languages and at 2× text: no overflow, every state rendered.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    registerFallbackValue(const ParsedLink.unsupported(''));
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
      return switch (id) {
        'PPPPPPPPPPP' => const Result.failure(
          AppFailure(type: FailureType.privateVideo),
        ),
        'OOOOOOOOOOO' => const Result.failure(
          AppFailure(type: FailureType.noInternet),
        ),
        _ => Result.success(
          ResolvedLink.single(
            MediaInfo(
              videoId: id,
              url: 'https://www.youtube.com/watch?v=$id',
              title: 'A long video title that will not fit on one line $id',
              channel: 'Blender Foundation',
              duration: const Duration(minutes: 12, seconds: 14),
            ),
          ),
        ),
      };
    });
    await getIt.unregister<MediaResolver>();
    getIt.registerLazySingleton<MediaResolver>(() => resolver);
  });
  tearDown(() => getIt.reset());

  for (final (name, size, language, scale) in [
    ('phone', const Size(390, 844), null, 1.0),
    ('desktop', const Size(1280, 800), null, 1.0),
    ('phone ar', const Size(390, 844), 'ar', 1.0),
    ('desktop ar', const Size(1280, 800), 'ar', 1.0),
    ('phone 2x text', const Size(390, 844), null, 2.0),
    ('desktop 2x text', const Size(1280, 800), null, 2.0),
  ]) {
    testWidgets('every row state lays out: $name', (tester) async {
      await getIt<SettingsRepo>().update(
        (s) => s.copyWith(languageCode: language),
      );
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = buildAppRouter()..go(AppRoutes.newDownload);
      await tester.pumpWidget(
        TubeDownloaderApp(
          config: const AppConfig.development(),
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      // As a drop or the clipboard banner delivers them.
      tester
          .element(find.byType(UrlInputBar))
          .read<LinkInputCubit>()
          .receive(_links);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BatchFooter), findsOneWidget);
      // The rows start below the editor on phones and the list is lazy:
      // step through to the end so every row is built and laid out. (Moving
      // the position directly — a drag over the links box would scroll the
      // box's own text.)
      final list = find
          .descendant(
            of: find.byType(BatchView),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(list).position;
      while (position.pixels < position.maxScrollExtent) {
        position.jumpTo(
          math.min(position.pixels + 300, position.maxScrollExtent),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BatchItemTile), findsWidgets);
    });
  }
}
