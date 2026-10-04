import 'dart:async';

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
import 'package:tube_downloader/features/new_download/domain/size_estimator.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';

class _Resolver extends Mock implements MediaResolver {}

class _Settings extends Mock implements SettingsRepo {}

class _Enqueue extends Mock implements EnqueueDownloadsUseCase {}

const _link = ParsedLink.playlist(
  playlistId: 'PLabcdefghij12',
  url: 'https://www.youtube.com/playlist?list=PLabcdefghij12',
);
const _playlist = PlaylistInfo(
  playlistId: 'PLabcdefghij12',
  url: 'u',
  title: 'Lo-fi: Beats / Vol. 1',
  channel: 'Chill',
);

MediaInfo _video(int n, {String? title}) => MediaInfo(
  videoId: 'vid$n',
  url: 'https://www.youtube.com/watch?v=vid$n',
  title: title ?? 'Track $n',
  channel: 'Chill',
  duration: const Duration(minutes: 3),
);

void main() {
  late _Resolver resolver;
  late _Settings settings;
  late _Enqueue enqueue;
  late StreamController<Result<MediaInfo>> items;

  setUpAll(() {
    registerFallbackValue(_link);
    registerFallbackValue(<DownloadRequest>[]);
  });

  setUp(() {
    resolver = _Resolver();
    settings = _Settings();
    enqueue = _Enqueue();
    items = StreamController<Result<MediaInfo>>();
    when(() => settings.current).thenReturn(const AppSettings());
    when(() => resolver.resolve(any())).thenAnswer(
      (_) async => const Result.success(ResolvedLink.playlist(_playlist)),
    );
    when(() => resolver.playlistItems(any())).thenAnswer((_) => items.stream);
    when(() => enqueue(any(), group: any(named: 'group'))).thenAnswer(
      (_) async => const Result.success(EnqueueSummary(added: 2, skipped: 0)),
    );
  });

  Future<PlaylistCubit> loaded(
    List<Result<MediaInfo>> results, {
    bool close = true,
  }) async {
    final cubit = PlaylistCubit(
      resolver,
      enqueue,
      settings,
      newId: () => 'group-1',
    );
    await cubit.fetch(_link);
    results.forEach(items.add);
    if (close) await items.close();
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    ); // batch flush
    return cubit;
  }

  PlaylistReady ready(PlaylistCubit c) => c.state as PlaylistReady;

  test(
    'items stream in; private / deleted entries are disabled and unselected',
    () async {
      final cubit = await loaded([
        Result.success(_video(1)),
        Result.success(_video(2, title: '[Private video]')),
        Result.success(_video(3)),
      ]);

      final s = ready(cubit);
      expect(s.loadingMore, isFalse);
      expect(s.rows.map((r) => (r.index, r.selected, r.unavailable)), [
        (1, true, false),
        (2, false, true),
        (3, true, false),
      ]);
      expect((s.selectedCount, s.availableCount), (2, 2));
      expect(
        s.format,
        const FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: 1080,
        ),
      );
      await cubit.close();
    },
  );

  test('toggle / select all never select an unavailable row; filter narrows the list', () async {
    final cubit = await loaded([
      Result.success(_video(1)),
      Result.success(_video(2, title: '[Deleted video]')),
      Result.success(_video(3)),
    ]);

    cubit.toggle(1);
    expect(ready(cubit).selectedCount, 1);
    cubit.toggle(2);
    expect(ready(cubit).rows[1].selected, isFalse, reason: 'unavailable');
    cubit.selectAll(true);
    expect(ready(cubit).selectedCount, 2);

    cubit.setFilter('track 3');
    expect(ready(cubit).visibleRows.single.index, 3);
    await cubit.close();
  });

  test(
    'switching to audio resets the format and drops per-row overrides',
    () async {
      final cubit = await loaded([Result.success(_video(1))]);
      cubit.setOverride(
        1,
        const FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: 360,
        ),
      );
      expect(ready(cubit).rows.single.formatOverride, isNotNull);

      cubit.setKind(MediaKind.audio);
      final s = ready(cubit);
      expect(
        s.format,
        const FormatSelector(
          kind: MediaKind.audio,
          container: OutContainer.mp3,
          audioKbps: 192,
        ),
      );
      expect(s.rows.single.formatOverride, isNull);
      await cubit.close();
    },
  );

  test('download: one request per selected row (overrides win) in a group with a safe subfolder', () async {
    final cubit = await loaded([
      Result.success(_video(1)),
      Result.success(_video(2)),
      Result.success(_video(3)),
    ]);
    cubit.toggle(2);
    const low = FormatSelector(
      kind: MediaKind.video,
      container: OutContainer.mp4,
      maxHeight: 360,
    );
    cubit.setOverride(3, low);

    await cubit.download();

    final captured = verify(
      () => enqueue(captureAny(), group: captureAny(named: 'group')),
    ).captured;
    final requests = captured[0] as List<DownloadRequest>;
    final group = captured[1] as DownloadGroup;
    expect(requests.map((r) => (r.media.videoId, r.playlistIndex)), [
      ('vid1', 1),
      ('vid3', 3),
    ]);
    expect(requests.last.format, low);
    expect(
      group.subDir,
      'Lo-fi - Beats - Vol. 1',
      reason: 'sanitized playlist title',
    );
    expect((group.id, group.total), ('group-1', 2));
    expect(ready(cubit).enqueuing, isFalse);
    await cubit.close();
  });

  test('no subfolder when the toggle is off', () async {
    final cubit = await loaded([Result.success(_video(1))]);
    cubit.setSubfolder(false);
    await cubit.download();
    final group =
        verify(() => enqueue(any(), group: captureAny(named: 'group')))
                .captured
                .single
            as DownloadGroup;
    expect(group.subDir, isNull);
    await cubit.close();
  });

  test('an item-stream failure keeps the rows already loaded', () async {
    final cubit = await loaded([
      Result.success(_video(1)),
      const Result.failure(AppFailure(type: FailureType.serverUnreachable)),
    ]);
    final s = ready(cubit);
    expect(s.rows, hasLength(1));
    expect(s.itemsFailure?.type, FailureType.serverUnreachable);
    await cubit.close();
  });

  test('closing stops the item stream (no emit after close)', () async {
    final cubit = await loaded([Result.success(_video(1))], close: false);
    await cubit.close();
    items.add(Result.success(_video(2)));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(items.hasListener, isFalse);
  });

  test('size estimate: duration × typical bitrate of the chosen quality', () {
    const d = Duration(minutes: 10);
    expect(
      SizeEstimator.estimate(
        d,
        const FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: 1080,
        ),
      ),
      600 * (4500 + 128) * 1000 ~/ 8,
    );
    expect(
      SizeEstimator.estimate(
        d,
        const FormatSelector(
          kind: MediaKind.audio,
          container: OutContainer.mp3,
          audioKbps: 192,
        ),
      ),
      600 * 192 * 1000 ~/ 8,
    );
    expect(
      SizeEstimator.estimate(
        null,
        const FormatSelector(
          kind: MediaKind.audio,
          container: OutContainer.m4a,
        ),
      ),
      isNull,
    );
  });
}
