import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/library_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/thumbnail_store.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/features/library/domain/usecases/check_missing_files_use_case.dart';
import 'package:tube_downloader/features/library/domain/usecases/delete_library_items_use_case.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_state.dart';

class _Fs extends Mock implements FileSystemGateway {}

class _Thumbs extends Mock implements ThumbnailStore {}

class _Files extends Mock implements FileLauncher {}

class _Clipboard extends Mock implements ClipboardService {}

LibraryItem _item(
  String id, {
  String title = 'Video',
  MediaKind kind = MediaKind.video,
  int bytes = 100,
  int daysAgo = 0,
  String? thumb,
}) => LibraryItem(
  id: id,
  videoId: 'v$id',
  sourceUrl: 'https://www.youtube.com/watch?v=v$id',
  title: title,
  channel: 'قناة الاختبار',
  kind: kind,
  container: kind == MediaKind.audio ? OutContainer.mp3 : OutContainer.mp4,
  path: '/lib/$id.${kind == MediaKind.audio ? 'mp3' : 'mp4'}',
  bytes: bytes,
  completedAt: DateTime(2026, 10, 5).subtract(Duration(days: daysAgo)),
  height: kind == MediaKind.video ? 1080 : null,
  thumbPath: thumb,
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    registerFallbackValue(<String>[]);
  });

  late AppDatabase db;
  late LibraryRepoImpl library;
  late _Fs fs;
  late _Thumbs thumbs;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    library = LibraryRepoImpl(db);
    fs = _Fs();
    thumbs = _Thumbs();
    when(() => thumbs.delete(any())).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  Future<void> seed(List<LibraryItem> items) async {
    for (final i in items) {
      await library.add(i);
    }
  }

  group('CheckMissingFilesUseCase', () {
    test('flags files gone from disk and clears the flag when back', () async {
      await seed([_item('a'), _item('b'), _item('c')]);
      await library.setMissing({'c'}, missing: true);
      when(
        () => fs.exists(any()),
      ).thenAnswer((i) async => i.positionalArguments.single != '/lib/a.mp4');

      expect(await CheckMissingFilesUseCase(library, fs)(), 2);
      final missing = {for (final i in await library.all()) i.id: i.missing};
      expect(missing, {'a': true, 'b': false, 'c': false});
    });
  });

  group('DeleteLibraryItemsUseCase', () {
    test('from disk: files, then thumbnails, then rows', () async {
      await seed([_item('a', thumb: '/thumbs/va.jpg'), _item('b')]);
      when(() => fs.deletePublished(any()))
          .thenAnswer((_) async => const Result.success(null));

      final result = await DeleteLibraryItemsUseCase(library, fs, thumbs)(
        await library.all(),
        fromDisk: true,
      );
      expect(result, isA<Success<void>>());
      verify(() => fs.deletePublished('/lib/a.mp4')).called(1);
      verify(() => fs.deletePublished('/lib/b.mp4')).called(1);
      verify(() => thumbs.delete('/thumbs/va.jpg')).called(1);
      expect(await library.all(), isEmpty);
    });

    test('library only: the files stay', () async {
      await seed([_item('a')]);
      await DeleteLibraryItemsUseCase(library, fs, thumbs)(
        await library.all(),
        fromDisk: false,
      );
      verifyNever(() => fs.deletePublished(any()));
      expect(await library.all(), isEmpty);
    });

    test('a file that cannot be deleted keeps its row', () async {
      await seed([_item('a')]);
      when(() => fs.deletePublished(any())).thenAnswer(
        (_) async => const Result.failure(
          AppFailure(type: FailureType.permissionDenied),
        ),
      );
      final result = await DeleteLibraryItemsUseCase(library, fs, thumbs)(
        await library.all(),
        fromDisk: true,
      );
      expect(
        (result as Failure<void>).failure.type,
        FailureType.permissionDenied,
      );
      expect(await library.all(), hasLength(1));
    });
  });

  group('LibraryCubit', () {
    late _Files files;
    late _Clipboard clipboard;

    setUp(() {
      files = _Files();
      clipboard = _Clipboard();
      when(() => fs.exists(any())).thenAnswer((_) async => true);
      when(() => files.saveToPhotos(any())).thenAnswer((_) async => null);
      when(() => files.canReveal).thenReturn(true);
      when(() => files.canSaveToPhotos).thenReturn(true);
    });

    LibraryCubit build() => LibraryCubit(
      library,
      files,
      clipboard,
      CheckMissingFilesUseCase(library, fs),
      DeleteLibraryItemsUseCase(library, fs, thumbs),
    );

    test('counts per kind, the kind filter, and sorting', () async {
      await seed([
        _item('a', title: 'Beta', bytes: 300, daysAgo: 2),
        _item('b', title: 'Alpha', kind: MediaKind.audio, bytes: 900),
        _item('c', title: 'Gamma', bytes: 100, daysAgo: 1),
      ]);
      final cubit = build()..start();
      await pumpEventQueue();
      expect(
        (
          cubit.state.countOf(null),
          cubit.state.countOf(MediaKind.video),
          cubit.state.countOf(MediaKind.audio),
        ),
        (3, 2, 1),
      );
      expect(cubit.state.visible.map((i) => i.id), ['b', 'c', 'a']);

      cubit
        ..setKind(MediaKind.video)
        ..setSort(LibrarySort.name);
      await pumpEventQueue();
      expect(cubit.state.visible.map((i) => i.title), ['Beta', 'Gamma']);

      cubit.setSort(LibrarySort.size);
      await pumpEventQueue();
      expect(cubit.state.visible.map((i) => i.id), ['a', 'c']);
      await cubit.close();
    });

    test('search waits for a pause in typing, and folds Arabic', () {
      fakeAsync((async) {
        unawaited(seed([_item('a', title: 'دَرْسُ البرمجة'), _item('b')]));
        async.flushMicrotasks();
        final cubit = build()..start();
        async.flushMicrotasks();
        expect(cubit.state.matches, hasLength(2));

        cubit.setQuery('درس');
        async.flushMicrotasks();
        expect(cubit.state.matches, hasLength(2), reason: 'not yet');
        async
          ..elapse(LibraryCubit.searchDelay)
          ..flushMicrotasks();
        expect(cubit.state.matches.single.id, 'a');
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('selection: long-press starts it; Photos gets videos only; a '
        'delete ends it', () async {
      await seed([_item('a'), _item('b', kind: MediaKind.audio)]);
      when(() => fs.deletePublished(any()))
          .thenAnswer((_) async => const Result.success(null));
      final cubit = build()..start();
      await pumpEventQueue();

      cubit.toggle('a');
      expect(cubit.state.selecting, isTrue);
      expect(cubit.state.selected, {'a'});
      cubit.selectAll();
      expect(cubit.state.selected, {'a', 'b'});
      expect(cubit.state.selectedBytes, 200);

      final saved = await cubit.saveToPhotos(cubit.state.selectedItems);
      expect((saved as Success<int>).data, 1);
      verify(() => files.saveToPhotos(['/lib/a.mp4'])).called(1);

      await cubit.delete(cubit.state.selectedItems, fromDisk: true);
      await pumpEventQueue();
      expect(cubit.state.selecting, isFalse);
      expect(cubit.state.matches, isEmpty);
      await cubit.close();
    });

    test('a file found missing on start is flagged in the list', () async {
      await seed([_item('a')]);
      when(() => fs.exists(any())).thenAnswer((_) async => false);
      final cubit = build()..start();
      await pumpEventQueue();
      expect(cubit.state.matches.single.missing, isTrue);
      await cubit.close();
    });

    test('closed before the list arrives: nothing is emitted', () async {
      await seed([_item('a')]);
      final cubit = build()..start();
      await cubit.close();
      await pumpEventQueue();
      expect(cubit.state.loaded, isFalse);
    });
  });
}
