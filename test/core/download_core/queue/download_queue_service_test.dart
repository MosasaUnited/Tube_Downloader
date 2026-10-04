import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/repos/library_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/repos/network_monitor.dart';
import 'package:tube_downloader/core/download_core/domain/services/backoff_policy.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_job.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/queue_types.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';

import 'fakes.dart';

const _video1080 = FormatSelector(
  kind: MediaKind.video,
  container: OutContainer.mp4,
  maxHeight: 1080,
);
const _mp3 = FormatSelector(
  kind: MediaKind.audio,
  container: OutContainer.mp3,
  audioKbps: 192,
);

DownloadRequest _request(String n, {FormatSelector format = _video1080}) =>
    DownloadRequest(
      media: MediaInfo(
        videoId: 'vid$n',
        url: 'https://www.youtube.com/watch?v=vid$n',
        title: 'Video $n',
        channel: 'Blender',
      ),
      format: format,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late DownloadRepoImpl repo;
  late LibraryRepoImpl library;
  late SettingsRepoImpl settings;
  late FakeFileSystem fs;
  late FakeTransport transport;
  late FakeMuxer muxer;
  late FakeResolver resolver;
  late FakeNetwork network;
  late RecordingActivity activity;
  late ResolveGate gate;
  late DownloadQueueService queue;
  late List<TaskOutcome> outcomes;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DownloadRepoImpl(db);
    library = LibraryRepoImpl(db);
    settings = SettingsRepoImpl(db);
    await settings.load();
    fs = FakeFileSystem();
    transport = FakeTransport(fs);
    muxer = FakeMuxer(fs);
    resolver = FakeResolver();
    network = FakeNetwork(NetState.wifi);
    activity = RecordingActivity();
    gate = ResolveGate(minSpacing: Duration.zero);
    queue = DownloadQueueService(
      JobDeps(
        repo: repo,
        library: library,
        settings: settings,
        resolver: resolver,
        transport: transport,
        muxer: muxer,
        fs: fs,
        checkpointEvery: Duration.zero,
      ),
      network: network,
      gate: gate,
      activity: activity,
      backoff: BackoffPolicy(
        networkRetryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
      ),
    );
    outcomes = [];
    queue.outcomes.listen(outcomes.add);
    await queue.start();
  });

  tearDown(() async {
    transport.release();
    await queue.dispose();
    await db.close();
  });

  Future<String> enqueue(DownloadRequest r) async =>
      (await queue.enqueue([r]) as Success<List<String>>).data.single;
  Future<DownloadTask> task(String id) async => (await repo.task(id))!;
  Future<TaskStatus> status(String id) async => (await task(id)).status;

  test(
    'a video goes resolve → video → audio → merge → publish → library',
    () async {
      final id = await enqueue(_request('1'));
      await until(
        () async => await status(id) == TaskStatus.completed,
        reason: 'completed',
      );

      final done = await task(id);
      expect(done.outputPath, '/downloads/Video 1 - Blender.mp4');
      expect(fs.files[done.outputPath], 1100, reason: 'merged video + audio');
      expect(fs.workDirs, isNot(contains(id)), reason: 'work folder removed');
      expect((await library.all()).single.path, done.outputPath);
      expect(muxer.merges, 1);
      expect((await repo.watchEvents(id).first).map((e) => e.type), [
        EventType.requested,
        EventType.resolved,
        EventType.videoStarted,
        EventType.videoDone,
        EventType.audioStarted,
        EventType.audioDone,
        EventType.mergeStarted,
        EventType.completed,
      ]);
      expect(outcomes.single, isA<TaskCompleted>());
    },
  );

  test('MP3: one audio leg, converted, published as .mp3', () async {
    resolver.legs = const [LegKind.audio];
    final id = await enqueue(_request('1', format: _mp3));
    await until(() async => await status(id) == TaskStatus.completed);

    expect((await task(id)).outputPath, endsWith('.mp3'));
    expect(muxer.conversions, 1);
    expect(muxer.merges, 0);
  });

  test('never more running tasks than maxConcurrent', () async {
    await settings.update((s) => s.copyWith(maxConcurrent: 2));
    transport.hold = Completer<void>();
    final ids = [for (var i = 0; i < 4; i++) await enqueue(_request('$i'))];

    await until(() => queue.running.length == 2, reason: 'two slots filled');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(queue.running.length, 2);

    transport.release();
    for (final id in ids) {
      await until(() async => await status(id) == TaskStatus.completed);
    }
  });

  test('holds the OS activity assertion only while jobs run', () async {
    await settings.update((s) => s.copyWith(maxConcurrent: 2));
    transport.hold = Completer<void>();
    final ids = [for (var i = 0; i < 3; i++) await enqueue(_request('$i'))];

    await until(() => queue.running.length == 2, reason: 'two slots filled');
    expect(activity.calls, ['begin'], reason: 'one assertion for all jobs');

    transport.release();
    for (final id in ids) {
      await until(() async => await status(id) == TaskStatus.completed);
    }
    await until(() => activity.calls.last == 'end', reason: 'released');
    // A slot freed and refilled may end and begin again, but never twice in
    // a row: begin/end strictly alternate.
    for (var i = 0; i < activity.calls.length; i++) {
      expect(activity.calls[i], i.isEven ? 'begin' : 'end');
    }
  });

  test(
    'an expired stream is re-resolved once and resumed at its offset',
    () async {
      transport.script[137] = [
        const AppFailure(type: FailureType.streamExpired),
      ];
      final id = await enqueue(_request('1'));
      await until(() async => await status(id) == TaskStatus.completed);

      expect(
        resolver.targetCalls.where((l) => l == LegKind.video),
        hasLength(2),
      );
      final videoStarts = transport.starts
          .where((j) => j.target.itag == 137)
          .toList();
      expect(
        videoStarts.last.resumeFrom,
        500,
        reason: 'resumed at the bytes already on disk',
      );
      expect(
        (await repo.watchEvents(id).first).map((e) => e.type),
        contains(EventType.reResolved),
      );
    },
  );

  test('network failures back off and retry, counting attempts', () async {
    transport.script[137] = [
      const AppFailure(type: FailureType.serverUnreachable),
      const AppFailure(type: FailureType.serverUnreachable),
    ];
    final id = await enqueue(_request('1'));
    await until(() async => await status(id) == TaskStatus.completed);

    expect((await task(id)).attempt, 2);
    expect(
      (await repo.watchEvents(id).first).where(
        (e) => e.type == EventType.retried,
      ),
      hasLength(2),
    );
  });

  test('when retries run out the task fails with the real cause', () async {
    transport.script[137] = List.filled(
      5,
      const AppFailure(type: FailureType.serverUnreachable),
      growable: true, // the fake consumes one per attempt
    );
    final id = await enqueue(_request('1'));
    await until(() async => await status(id) == TaskStatus.failed);

    expect((await task(id)).failure?.type, FailureType.serverUnreachable);
    expect(outcomes.single, isA<TaskFailedOutcome>());
  });

  test(
    'a rate limit sets the global cooldown and re-queues with a backoff',
    () async {
      transport.script[137] = [const AppFailure(type: FailureType.rateLimited)];
      final id = await enqueue(_request('1'));
      await until(
        () async => (await task(id)).notBefore != null,
        reason: 're-queued with backoff',
      );

      final waiting = await task(id);
      expect(waiting.status, TaskStatus.queued);
      expect(gate.cooldownUntil, isNotNull);
      expect(
        waiting.notBefore!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(20, 40),
        reason: '30 s ±20 %',
      );
      expect(queue.currentHealth.cooldownUntil, isNotNull);
    },
  );

  test('a final failure (private video) fails at once, no retry', () async {
    resolver.planFailure = const AppFailure(type: FailureType.privateVideo);
    final id = await enqueue(_request('1'));
    await until(() async => await status(id) == TaskStatus.failed);

    expect((await task(id)).attempt, 0);
    expect(resolver.plans, 1);
  });

  test(
    'not enough free space fails as storageFull before downloading',
    () async {
      fs.free = 10;
      final id = await enqueue(_request('1'));
      await until(() async => await status(id) == TaskStatus.failed);
      expect((await task(id)).failure?.type, FailureType.storageFull);
    },
  );

  test('pause keeps the bytes; resume continues from them', () async {
    transport.hold = Completer<void>();
    final id = await enqueue(_request('1'));
    await until(() => queue.running.contains(id));
    await until(
      () async => fs.files.values.any((v) => v > 0),
      reason: 'bytes on disk',
    );

    await queue.pause(id);
    await until(() async => await status(id) == TaskStatus.paused);
    final paused = await task(id);
    expect(paused.pauseReason, PauseReason.user);
    expect(fs.files['/work/$id/video.part'], 500);

    transport.release();
    await queue.resume(id);
    await until(() async => await status(id) == TaskStatus.completed);
    expect(
      transport.starts.where((j) => j.target.itag == 137).last.resumeFrom,
      500,
    );
  });

  test('cancel stops the task and deletes its work folder', () async {
    transport.hold = Completer<void>();
    final id = await enqueue(_request('1'));
    await until(() => queue.running.contains(id));

    await queue.cancel(id);
    await until(() async => await status(id) == TaskStatus.cancelled);
    expect(fs.workDirs, isNot(contains(id)));
    expect(fs.files.keys.where((k) => k.startsWith('/work/$id')), isEmpty);
  });

  test('going offline pauses running work; coming back resumes it', () async {
    transport.hold = Completer<void>();
    final id = await enqueue(_request('1'));
    await until(() => queue.running.contains(id));

    network.set(NetState.offline);
    await until(() async => await status(id) == TaskStatus.paused);
    expect((await task(id)).pauseReason, PauseReason.offline);
    expect(queue.currentHealth.offline, isTrue);

    transport.release();
    network.set(NetState.wifi);
    await until(() async => await status(id) == TaskStatus.completed);
  });

  test('Wi-Fi only: nothing starts on cellular until Wi-Fi returns', () async {
    await settings.update((s) => s.copyWith(wifiOnly: true));
    network.set(NetState.cellular);
    await until(() => queue.currentHealth.waitingForWifi);

    final id = await enqueue(_request('1'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await status(id), TaskStatus.queued);

    network.set(NetState.wifi);
    await until(() async => await status(id) == TaskStatus.completed);
  });
}
