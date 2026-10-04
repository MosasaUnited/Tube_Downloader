import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/link_file_reader.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';

class _Resolver extends Mock implements MediaResolver {}

class _Settings extends Mock implements SettingsRepo {}

class _Enqueue extends Mock implements EnqueueDownloadsUseCase {}

class _Clipboard extends Mock implements ClipboardService {}

class _Files extends Mock implements LinkFileReader {}

const _a = 'https://youtu.be/AAAAAAAAAAA';
const _b = 'https://youtu.be/BBBBBBBBBBB';
const _c = 'https://youtu.be/CCCCCCCCCCC';
const _playlist = 'https://www.youtube.com/playlist?list=PLabcdefghij12';
const _bad = 'https://example.com/invalid-stream/99';

MediaInfo _media(String id, {bool live = false}) => MediaInfo(
  videoId: id,
  url: 'https://www.youtube.com/watch?v=$id',
  title: 'Video $id',
  channel: 'Blender',
  duration: const Duration(minutes: 10),
  isLive: live,
);

void main() {
  late _Resolver resolver;
  late _Settings settings;
  late _Enqueue enqueue;
  late _Clipboard clipboard;
  late _Files files;

  /// Resolves in call order; each call stays open until the test completes it.
  late List<(String, Completer<Result<ResolvedLink>>)> calls;
  late int inFlight;
  late int maxInFlight;

  setUpAll(() {
    registerFallbackValue(const ParsedLink.unsupported(''));
    registerFallbackValue(<DownloadRequest>[]);
  });

  setUp(() {
    resolver = _Resolver();
    settings = _Settings();
    enqueue = _Enqueue();
    clipboard = _Clipboard();
    files = _Files();
    calls = [];
    inFlight = 0;
    maxInFlight = 0;
    when(() => settings.current).thenReturn(const AppSettings());
    when(() => resolver.resolve(any())).thenAnswer((invocation) {
      final link = invocation.positionalArguments.single as ParsedVideo;
      final completer = Completer<Result<ResolvedLink>>();
      calls.add((link.videoId, completer));
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      return completer.future.whenComplete(() => inFlight--);
    });
    when(() => enqueue(any())).thenAnswer(
      (invocation) async => Result.success(
        EnqueueSummary(
          added: (invocation.positionalArguments.single as List).length,
          skipped: 0,
        ),
      ),
    );
  });

  BatchLinksCubit build() =>
      BatchLinksCubit(resolver, enqueue, settings, clipboard, files);

  /// Completes the next open resolve call.
  Future<void> answer(Result<ResolvedLink> result) async {
    final open = calls.where((c) => !c.$2.isCompleted).first;
    open.$2.complete(result);
    await pumpEventQueue();
  }

  Future<void> ok(String id, {bool live = false}) =>
      answer(Result.success(ResolvedLink.single(_media(id, live: live))));

  List<(BatchItemStatus, int?)> statuses(BatchLinksCubit c) => [
    for (final i in c.state.items) (i.status, i.duplicateOf),
  ];

  test('rows: ready, invalid, duplicate, playlist — fetched one at a time, '
      'in order, never a duplicate', () async {
    final cubit = build()..append('$_a\n$_bad\n$_b\n$_a\n$_playlist');
    expect(statuses(cubit), [
      (BatchItemStatus.resolving, null),
      (BatchItemStatus.invalid, null),
      (BatchItemStatus.resolving, null),
      (BatchItemStatus.duplicate, 1),
      (BatchItemStatus.playlist, null),
    ]);
    await pumpEventQueue();
    await ok('AAAAAAAAAAA');
    await ok('BBBBBBBBBBB');

    expect(calls.map((c) => c.$1), ['AAAAAAAAAAA', 'BBBBBBBBBBB']);
    expect(maxInFlight, 1);
    expect(statuses(cubit).first, (BatchItemStatus.ready, null));
    expect(cubit.state.items[2].status, BatchItemStatus.ready);
    expect(
      cubit.state.items[3].media?.title,
      'Video AAAAAAAAAAA',
      reason: 'a duplicate shows what it duplicates',
    );
    expect(cubit.state.readyItems, hasLength(2));
    await cubit.close();
  });

  test('a live video fails as liveNotSupported and offers no retry', () async {
    final cubit = build()..append(_a);
    await pumpEventQueue();
    await ok('AAAAAAAAAAA', live: true);
    final item = cubit.state.items.single;
    expect(
      (item.status, item.failure?.type, item.canRetry),
      (BatchItemStatus.failed, FailureType.liveNotSupported, false),
    );
    await cubit.close();
  });

  test('an offline failure can be retried; a private video cannot', () async {
    final cubit = build()..append('$_a $_b');
    await pumpEventQueue();
    await answer(
      const Result.failure(AppFailure(type: FailureType.noInternet)),
    );
    await answer(
      const Result.failure(AppFailure(type: FailureType.privateVideo)),
    );
    expect(cubit.state.items.map((i) => i.canRetry), [true, false]);

    cubit.retry('AAAAAAAAAAA');
    expect(cubit.state.items.first.status, BatchItemStatus.resolving);
    await pumpEventQueue();
    await ok('AAAAAAAAAAA');
    expect(cubit.state.items.first.status, BatchItemStatus.ready);
    await cubit.close();
  });

  test('typing is analyzed after a pause, not on every key', () {
    fakeAsync((async) {
      final cubit = build()..setText('https://youtu.be/AAAA');
      cubit.setText(_a);
      expect(cubit.state.items, isEmpty);
      async.elapse(BatchLinksCubit.analyzeDelay);
      expect(cubit.state.items.single.status, BatchItemStatus.resolving);
      async.flushMicrotasks();
      expect(calls.single.$1, 'AAAAAAAAAAA', reason: 'never the half link');
      unawaited(cubit.close());
    });
  });

  test('a video edited away and back is not fetched again', () async {
    final cubit = build()..append(_a);
    await pumpEventQueue();
    await ok('AAAAAAAAAAA');
    cubit
      ..clear()
      ..append(_a);
    await pumpEventQueue();
    expect(calls, hasLength(1));
    expect(cubit.state.items.single.status, BatchItemStatus.ready);
    await cubit.close();
  });

  test('remove cuts the row\'s link out of the text', () async {
    final cubit = build()..append('$_a\n$_bad\n$_b');
    cubit.remove(2);
    expect(cubit.state.text, '$_a\n$_b');
    expect(cubit.state.items.map((i) => i.input), [_a, _b]);
    await cubit.close();
  });

  test('download queues ready rows with their quality, then leaves only '
      'what needs attention in the box', () async {
    final cubit = build()..append('$_a\n$_bad\n$_b\n$_c');
    await pumpEventQueue();
    await ok('AAAAAAAAAAA');
    await ok('BBBBBBBBBBB');
    // _c still resolving.
    const mp3 = FormatSelector(
      kind: MediaKind.audio,
      container: OutContainer.mp3,
      audioKbps: 320,
    );
    cubit.setOverride('BBBBBBBBBBB', mp3);

    final result = await cubit.download();

    expect((result! as Success<EnqueueSummary>).data.added, 2);
    final sent =
        verify(() => enqueue(captureAny())).captured.single
            as List<DownloadRequest>;
    expect(sent.map((r) => (r.media.videoId, r.format.kind)), [
      ('AAAAAAAAAAA', MediaKind.video),
      ('BBBBBBBBBBB', MediaKind.audio),
    ]);
    expect(cubit.state.text, '$_bad\n$_c');
    expect(cubit.state.enqueuing, isFalse);
    await cubit.close();
  });

  test('Video ↔ Audio resets the default quality and drops overrides', () {
    final cubit = build()
      ..setOverride(
        'AAAAAAAAAAA',
        const FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: 480,
        ),
      )
      ..setKind(MediaKind.audio);
    expect(cubit.state.format.kind, MediaKind.audio);
    expect(cubit.state.overrides, isEmpty);
    unawaited(cubit.close());
  });

  test(
    'import: appends the file, reports a failure, ignores a cancel',
    () async {
      final cubit = build();
      when(() => files.pickText())
          .thenAnswer((_) async => const Result.success(_a));
      expect(await cubit.importFile(), isNull);
      expect(cubit.state.text, _a);

      when(() => files.pickText())
          .thenAnswer((_) async => const Result.success(null));
      expect(await cubit.importFile(), isNull);
      expect(cubit.state.text, _a);

      when(() => files.pickText()).thenAnswer(
        (_) async => const Result.failure(
          AppFailure(type: FailureType.permissionDenied),
        ),
      );
      expect((await cubit.importFile())?.type, FailureType.permissionDenied);
      await cubit.close();
    },
  );

  test('closing while a fetch is open emits nothing afterwards', () async {
    final cubit = build()..append(_a);
    await pumpEventQueue();
    await cubit.close();
    await ok('AAAAAAAAAAA');
    expect(cubit.state.items.single.status, BatchItemStatus.resolving);
  });
}
