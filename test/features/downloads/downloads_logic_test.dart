import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_state.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/task_detail_cubit/task_detail_state.dart';
import 'package:tube_downloader/features/shell/logic/nav_badge_cubit/nav_badge_cubit.dart';

class _Queue extends Mock implements DownloadQueueService {}

class _Files extends Mock implements FileLauncher {}

class _Clipboard extends Mock implements ClipboardService {}

const _format = FormatSelector(
  kind: MediaKind.video,
  container: OutContainer.mp4,
  maxHeight: 1080,
);

DownloadRequest _request(String id, {int? index}) => DownloadRequest(
  media: MediaInfo(
    videoId: id,
    url: 'https://www.youtube.com/watch?v=$id',
    title: 'Video $id',
    channel: 'Blender',
  ),
  format: _format,
  playlistIndex: index,
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late DownloadRepoImpl repo;
  late _Queue queue;
  late _Files files;
  late StreamController<QueueHealth> health;
  var nextId = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    nextId = 0;
    repo = DownloadRepoImpl(db, newId: () => 't${nextId++}');
    queue = _Queue();
    files = _Files();
    health = StreamController<QueueHealth>.broadcast();
    when(() => queue.currentHealth).thenReturn(const QueueHealth());
    when(() => queue.health).thenAnswer((_) => health.stream);
    for (final call in [queue.pause, queue.resume, queue.cancel]) {
      when(() => call(any())).thenAnswer((_) async {});
    }
    when(() => files.canOpen).thenReturn(true);
    when(() => files.canReveal).thenReturn(true);
  });
  tearDown(() async {
    await health.close();
    await db.close();
  });

  Future<void> settle() => pumpEventQueue(times: 40);

  /// a, [playlist: p1 p2 p3], b — the playlist enqueued between them.
  Future<void> seed() async {
    await repo.enqueue([_request('aaaaaaaaaaa')]);
    await repo.enqueue(
      [
        _request('ppppppppp01', index: 1),
        _request('ppppppppp02', index: 2),
        _request('ppppppppp03', index: 3),
      ],
      group: const DownloadGroup(
        id: 'g1',
        playlistId: 'PLabcdefghij12',
        title: 'Lo-fi mix',
        total: 3,
      ),
    );
    await repo.enqueue([_request('bbbbbbbbbbb')]);
  }

  group('DownloadsCubit', () {
    Future<DownloadsCubit> started() async {
      final cubit = DownloadsCubit(repo, queue, files)..start();
      await settle();
      return cubit;
    }

    test('a playlist gathers under one entry, in queue order; the first '
        'task is selected for the pane', () async {
      await seed();
      final cubit = await started();
      final items = cubit.state.items;
      expect(items, hasLength(3));
      expect((items[0] as TaskQueueItem).task.id, 't0');
      final group = items[1] as GroupQueueItem;
      expect(group.summary.group.title, 'Lo-fi mix');
      expect(group.tasks.map((t) => t.playlistIndex), [1, 2, 3]);
      expect((items[2] as TaskQueueItem).task.id, 't4');
      expect(cubit.state.selectedId, 't0');
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.countOf(TaskFilter.queued), 5);
      await cubit.close();
    });

    test(
      'a filter shows only its tasks; the counts stay for every chip',
      () async {
        await seed();
        await repo.transition(
          't2',
          TaskStatus.paused,
          pauseReason: PauseReason.user,
        );
        final cubit = await started();
        await cubit.setFilter(TaskFilter.paused);
        await settle();

        final group = cubit.state.items.single as GroupQueueItem;
        expect(group.tasks.single.id, 't2');
        expect(cubit.state.countOf(TaskFilter.paused), 1);
        expect(cubit.state.countOf(TaskFilter.queued), 4);
        expect(cubit.state.selectedId, 't2', reason: 't0 is no longer listed');
        await cubit.close();
      },
    );

    test(
      'the selection stays while listed and moves on when it goes',
      () async {
        await seed();
        final cubit = await started();
        cubit.select('t4');
        await repo.transition('t0', TaskStatus.cancelled);
        await settle();
        expect(cubit.state.selectedId, 't4');

        await repo.transition('t4', TaskStatus.cancelled);
        await settle();
        expect(cubit.state.selectedId, 't1');
        await cubit.close();
      },
    );

    test('pause / resume a playlist touch only its own tasks', () async {
      await seed();
      await repo.transition(
        't3',
        TaskStatus.paused,
        pauseReason: PauseReason.user,
      );
      final cubit = await started();

      await cubit.pauseGroup('g1');
      verify(() => queue.pause('t1')).called(1);
      verify(() => queue.pause('t2')).called(1);
      verifyNever(() => queue.pause('t3'));
      verifyNever(() => queue.pause('t0'));

      await cubit.resumeGroup('g1');
      verify(() => queue.resume('t3')).called(1);
      verifyNever(() => queue.resume(any(that: isNot('t3'))));
      await cubit.close();
    });

    test('groups expand and collapse; health follows the queue', () async {
      final cubit = await started();
      cubit.toggleGroup('g1');
      expect(cubit.state.expandedGroups, {'g1'});
      cubit.toggleGroup('g1');
      expect(cubit.state.expandedGroups, isEmpty);

      health.add(const QueueHealth(offline: true));
      await settle();
      expect(cubit.state.health.offline, isTrue);
      await cubit.close();
    });

    test('closed before the streams answer: nothing is emitted', () async {
      await seed();
      final cubit = DownloadsCubit(repo, queue, files)..start();
      await cubit.close();
      await settle();
      expect(cubit.state.loaded, isFalse);
    });
  });

  group('TaskDetailCubit', () {
    late _Clipboard clipboard;
    setUp(() {
      clipboard = _Clipboard();
      when(() => clipboard.writeText(any())).thenAnswer((_) async {});
    });

    test('the task and its timeline, live; gone when cleared', () async {
      await repo.enqueue([_request('aaaaaaaaaaa')]);
      final cubit = TaskDetailCubit(repo, queue, files, clipboard)..watch('t0');
      await settle();
      var s = cubit.state as TaskDetailReady;
      expect(s.task.media.videoId, 'aaaaaaaaaaa');
      expect(s.events.map((e) => e.type), [EventType.requested]);

      await repo.transition(
        't0',
        TaskStatus.cancelled,
        event: EventType.cancelled,
      );
      await settle();
      s = cubit.state as TaskDetailReady;
      expect(s.events.last.type, EventType.cancelled);

      await repo.clearFinished();
      await settle();
      expect(cubit.state, const TaskDetailState.gone());
      await cubit.close();
    });

    test('commands go to the queue with the task id; copy puts the link '
        'on the clipboard', () async {
      await repo.enqueue([_request('aaaaaaaaaaa')]);
      final cubit = TaskDetailCubit(repo, queue, files, clipboard)..watch('t0');
      await settle();
      await cubit.pause();
      await cubit.cancel();
      await cubit.copyLink();
      verify(() => queue.pause('t0')).called(1);
      verify(() => queue.cancel('t0')).called(1);
      verify(
        () =>
            clipboard.writeText('https://www.youtube.com/watch?v=aaaaaaaaaaa'),
      ).called(1);
      await cubit.close();
    });

    test('open / reveal need a finished file and report its failure', () async {
      await repo.enqueue([_request('aaaaaaaaaaa')]);
      final cubit = TaskDetailCubit(repo, queue, files, clipboard)..watch('t0');
      await settle();
      expect(await cubit.openFile(), isNull);
      verifyNever(() => files.open(any()));

      for (final to in [
        TaskStatus.resolving,
        TaskStatus.downloadingVideo,
        TaskStatus.merging,
      ]) {
        await repo.transition('t0', to);
      }
      await repo.transition(
        't0',
        TaskStatus.completed,
        outputPath: '/movies/Video.mp4',
      );
      await settle();
      when(() => files.reveal(any())).thenAnswer(
        (_) async => const AppFailure(type: FailureType.fileMissing),
      );
      expect((await cubit.revealFile())?.type, FailureType.fileMissing);
      verify(() => files.reveal('/movies/Video.mp4')).called(1);
      await cubit.close();
    });
  });

  test('NavBadgeCubit counts downloads still in progress', () async {
    await seed();
    await repo.transition('t0', TaskStatus.resolving);
    await repo.transition(
      't1',
      TaskStatus.paused,
      pauseReason: PauseReason.user,
    );
    await repo.transition('t4', TaskStatus.cancelled);
    final cubit = NavBadgeCubit(repo)..start();
    await settle();
    expect(cubit.state, 3, reason: '1 resolving + 2 queued');
    await cubit.close();
  });

  test('enqueue result type sanity', () async {
    expect(
      await repo.enqueue([_request('zzzzzzzzzzz')]),
      isA<Success<List<String>>>(),
    );
  });
}
