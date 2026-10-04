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
import 'package:tube_downloader/core/download_core/domain/services/download_job.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/recovery_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';
import 'package:tube_downloader/core/error/result.dart';

import 'fakes.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late DownloadRepoImpl repo;
  late FakeFileSystem fs;
  late RecoveryService recovery;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DownloadRepoImpl(db);
    fs = FakeFileSystem();
    recovery = RecoveryService(repo: repo, fs: fs);
  });
  tearDown(() => db.close());

  /// A task interrupted in [status] with the given legs, as a crash leaves it.
  Future<String> interrupted(TaskStatus status, List<TransferLeg> legs) async {
    final id = (await repo.enqueue([
      const DownloadRequest(
        media: MediaInfo(
          videoId: 'vid1',
          url: 'https://www.youtube.com/watch?v=vid1',
          title: 'Video',
          channel: 'C',
        ),
        format: FormatSelector(
          kind: MediaKind.video,
          container: OutContainer.mp4,
          maxHeight: 1080,
        ),
      ),
    ]) as Success<List<String>>).data.single;
    await repo.replaceLegs(id, legs);
    fs.workDirs.add(id);
    final path = <TaskStatus>[TaskStatus.resolving];
    if (status != TaskStatus.resolving) path.add(TaskStatus.downloadingVideo);
    if (status == TaskStatus.downloadingAudio || status == TaskStatus.merging) {
      path.add(TaskStatus.downloadingAudio);
    }
    if (status == TaskStatus.merging) path.add(TaskStatus.merging);
    for (final s in path) {
      await repo.transition(id, s);
    }
    return id;
  }

  test(
    'a download in progress goes back to the queue with checkpoints from disk',
    () async {
      final id = await interrupted(TaskStatus.downloadingVideo, const [
        TransferLeg(
          kind: LegKind.video,
          tmpPath: '/work/x/video.part',
          totalBytes: 1000,
          itag: 137,
        ),
        TransferLeg(kind: LegKind.audio, tmpPath: '/work/x/audio.part'),
      ]);
      fs.files['/work/x/video.part'] = 640; // the last checkpoint said 0

      expect(await recovery.run(), 1);

      final task = (await repo.task(id))!;
      expect(task.status, TaskStatus.queued);
      expect(task.legs.first.doneBytes, 640);
      expect(task.legs.first.completed, isFalse);
    },
  );

  test('a file longer than its stream is discarded', () async {
    final id = await interrupted(TaskStatus.downloadingVideo, const [
      TransferLeg(
        kind: LegKind.video,
        tmpPath: '/work/x/video.part',
        totalBytes: 1000,
      ),
    ]);
    fs.files['/work/x/video.part'] = 1500;

    await recovery.run();

    expect((await repo.task(id))!.legs.single.doneBytes, 0);
    expect(fs.files, isNot(contains('/work/x/video.part')));
  });

  test(
    'a crash during the merge re-runs FFmpeg without downloading again',
    () async {
      final id = await interrupted(TaskStatus.merging, const [
        TransferLeg(
          kind: LegKind.video,
          tmpPath: '/work/m/video.part',
          totalBytes: 1000,
          itag: 137,
        ),
        TransferLeg(
          kind: LegKind.audio,
          tmpPath: '/work/m/audio.part',
          totalBytes: 100,
          itag: 140,
        ),
      ]);
      fs.files
        ..['/work/m/video.part'] = 1000
        ..['/work/m/audio.part'] = 100;
      await recovery.run();

      final settings = SettingsRepoImpl(db);
      await settings.load();
      final resolver = FakeResolver();
      final transport = FakeTransport(fs);
      final muxer = FakeMuxer(fs);
      final queue = DownloadQueueService(
        JobDeps(
          repo: repo,
          library: LibraryRepoImpl(db),
          settings: settings,
          resolver: resolver,
          transport: transport,
          muxer: muxer,
          fs: fs,
        ),
        network: FakeNetwork(NetState.wifi),
        gate: ResolveGate(minSpacing: Duration.zero),
      );
      await queue.start();
      await until(
        () async => (await repo.task(id))!.status == TaskStatus.completed,
      );
      await queue.dispose();

      expect(
        transport.starts,
        isEmpty,
        reason: 'both legs were already complete on disk',
      );
      expect(
        resolver.plans,
        0,
        reason: 'the recorded legs are reused, not re-planned',
      );
      expect(muxer.merges, 1);
    },
  );

  test('work folders of finished or unknown tasks are deleted', () async {
    final id = await interrupted(TaskStatus.resolving, const []);
    fs.workDirs.addAll({'gone-task', id});

    await recovery.run();

    expect(fs.workDirs, {id});
  });
}
