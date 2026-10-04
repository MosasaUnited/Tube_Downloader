import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';

const _format = FormatSelector(
  kind: MediaKind.video,
  container: OutContainer.mp4,
  maxHeight: 1080,
);

DownloadRequest _request(String videoId, {int? index}) => DownloadRequest(
  media: MediaInfo(
    videoId: videoId,
    url: 'https://www.youtube.com/watch?v=$videoId',
    title: 'Video $videoId',
    channel: 'Blender',
  ),
  format: _format,
  playlistIndex: index,
);

void main() {
  late AppDatabase db;
  late DownloadRepoImpl repo;
  var now = DateTime(2026, 10, 4, 12);
  var nextId = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 4, 12);
    nextId = 0;
    repo = DownloadRepoImpl(
      db,
      clock: Clock(() => now),
      newId: () => 'task-${nextId++}',
    );
  });
  tearDown(() => db.close());

  Future<List<String>> enqueue(
    List<DownloadRequest> requests, {
    DownloadGroup? group,
  }) async => (await repo.enqueue(
    requests,
    group: group,
  ) as Success<List<String>>).data;

  test('enqueue: queued tasks in order, a "requested" event each, format survives the round trip', () async {
    final ids = await enqueue([
      _request('aaaaaaaaaaa'),
      _request('bbbbbbbbbbb'),
    ]);
    expect(ids, ['task-0', 'task-1']);

    final tasks = await repo.watchTasks(TaskFilter.all).first;
    expect(tasks.map((t) => t.position), [0, 1]);
    expect(tasks.first.status, TaskStatus.queued);
    expect(tasks.first.format, _format);
    expect((await repo.watchEvents('task-0').first).map((e) => e.type), [
      EventType.requested,
    ]);

    await enqueue([_request('ccccccccccc')]);
    expect(
      (await repo.task('task-2'))!.position,
      2,
      reason: 'positions keep growing',
    );
  });

  test('transitions are validated by the state machine', () async {
    await enqueue([_request('aaaaaaaaaaa')]);

    final illegal = await repo.transition('task-0', TaskStatus.completed);
    expect(
      illegal,
      isA<Failure<DownloadTask>>(),
      reason: 'queued → completed is not a legal move',
    );
    expect(
      (await repo.task('task-0'))!.status,
      TaskStatus.queued,
      reason: 'nothing written',
    );

    final ok = await repo.transition(
      'task-0',
      TaskStatus.resolving,
      event: EventType.resolved,
      eventArgs: {'itag': 137},
    );
    expect((ok as Success<DownloadTask>).data.status, TaskStatus.resolving);
    final events = await repo.watchEvents('task-0').first;
    expect(events.last.type, EventType.resolved);
    expect(events.last.args, {'itag': 137});
  });

  test(
    'pause reason, failure, attempts and backoff are stored with the status',
    () async {
      await enqueue([_request('aaaaaaaaaaa')]);
      await repo.transition(
        'task-0',
        TaskStatus.paused,
        pauseReason: PauseReason.waitingForWifi,
      );
      expect(
        (await repo.task('task-0'))!.pauseReason,
        PauseReason.waitingForWifi,
      );

      await repo.transition('task-0', TaskStatus.queued);
      expect((await repo.task('task-0'))!.pauseReason, isNull);

      await repo.transition('task-0', TaskStatus.resolving);
      await repo.transition(
        'task-0',
        TaskStatus.failed,
        failure: const AppFailure(type: FailureType.privateVideo, debug: 'x'),
      );
      final failed = (await repo.task('task-0'))!;
      expect(failed.failure?.type, FailureType.privateVideo);

      final retryAt = now.add(const Duration(seconds: 30));
      await repo.transition(
        'task-0',
        TaskStatus.queued,
        countAttempt: true,
        notBefore: retryAt,
      );
      final retried = (await repo.task('task-0'))!;
      expect(retried.attempt, 1);
      expect(retried.failure, isNull, reason: 'cleared when leaving failed');
      expect(retried.notBefore, retryAt);
    },
  );

  test(
    'nextRunnable: by position, skipping running tasks and unexpired backoff',
    () async {
      await enqueue([
        _request('aaaaaaaaaaa'),
        _request('bbbbbbbbbbb'),
        _request('ccccccccccc'),
      ]);
      await repo.transition('task-0', TaskStatus.resolving);
      await repo.transition(
        'task-0',
        TaskStatus.queued,
        notBefore: now.add(const Duration(minutes: 1)),
      );

      expect(
        (await repo.nextRunnable(now))?.id,
        'task-1',
        reason: 'task-0 is backing off',
      );
      expect((await repo.nextRunnable(now, running: {'task-1'}))?.id, 'task-2');
      expect(
        (await repo.nextRunnable(now.add(const Duration(minutes: 2))))?.id,
        'task-0',
      );
    },
  );

  test('legs are checkpointed and read back with the task', () async {
    await enqueue([_request('aaaaaaaaaaa')]);
    await repo.saveLeg(
      'task-0',
      const TransferLeg(
        kind: LegKind.video,
        tmpPath: '/w/v.part',
        totalBytes: 100,
        itag: 137,
      ),
    );
    await repo.saveLeg(
      'task-0',
      const TransferLeg(
        kind: LegKind.video,
        tmpPath: '/w/v.part',
        totalBytes: 100,
        doneBytes: 40,
      ),
    );
    await repo.saveLeg(
      'task-0',
      const TransferLeg(
        kind: LegKind.audio,
        tmpPath: '/w/a.part',
        totalBytes: 10,
      ),
    );

    final task = (await repo.task('task-0'))!;
    expect(task.legs.map((l) => l.kind), [LegKind.video, LegKind.audio]);
    expect(task.doneBytes, 40);
    expect(task.totalBytes, 110);

    await repo.replaceLegs('task-0', const [
      TransferLeg(kind: LegKind.muxed, tmpPath: '/w/m.part'),
    ]);
    expect((await repo.task('task-0'))!.legs.single.kind, LegKind.muxed);
  });

  test('filters hide cancelled tasks; existingKeys finds duplicates', () async {
    await enqueue([_request('aaaaaaaaaaa'), _request('bbbbbbbbbbb')]);
    await repo.transition('task-1', TaskStatus.cancelled);

    expect((await repo.watchTasks(TaskFilter.all).first).map((t) => t.id), [
      'task-0',
    ]);
    expect(await repo.watchTasks(TaskFilter.queued).first, hasLength(1));
    expect(
      await repo.existingKeys([
        ('aaaaaaaaaaa', _format.key),
        ('bbbbbbbbbbb', _format.key),
        ('zzzzzzzzzzz', _format.key),
      ]),
      {'aaaaaaaaaaa|${_format.key}'},
      reason: 'a cancelled task is not a duplicate',
    );
  });

  test(
    'playlist groups count their tasks; clearFinished keeps the rest',
    () async {
      const group = DownloadGroup(
        id: 'g1',
        playlistId: 'PL123',
        title: 'Lo-fi',
        total: 3,
      );
      await enqueue([
        _request('aaaaaaaaaaa', index: 1),
        _request('bbbbbbbbbbb', index: 2),
        _request('ccccccccccc', index: 3),
      ], group: group);
      await repo.transition('task-0', TaskStatus.resolving);
      await repo.transition('task-0', TaskStatus.downloadingVideo);
      await repo.transition('task-0', TaskStatus.completed);
      await repo.transition('task-1', TaskStatus.resolving);

      final summary = (await repo.watchGroups().first).single;
      expect([summary.completed, summary.active, summary.failed], [1, 1, 0]);

      expect(await repo.clearFinished(), 1);
      expect((await repo.watchTasks(TaskFilter.all).first).map((t) => t.id), [
        'task-1',
        'task-2',
      ]);
      expect(
        await repo.watchGroups().first,
        hasLength(1),
        reason: 'group still has tasks',
      );
    },
  );
}
