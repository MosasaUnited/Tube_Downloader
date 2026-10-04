@Tags(['network'])
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/yte_media_resolver.dart';
import 'package:tube_downloader/core/download_core/data/muxer/ffmpeg_kit_muxer.dart';
import 'package:tube_downloader/core/download_core/data/platform/io_file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/repos/library_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/data/transport/chunked_http_transport.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/repos/network_monitor.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_job.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';
import 'package:tube_downloader/core/error/result.dart';

import '../core/download_core/queue/fakes.dart' show FakeNetwork, until;

/// The real pipeline against real YouTube: resolver (visionOS client) →
/// chunked transport → file gateway → queue → library. Audio-only M4A needs
/// no FFmpeg, so it runs on the VM. Fixture: Tears of Steel (CC-BY).
/// Local only: flutter test --tags network test/e2e
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('enqueue → download → publish → library, for real', () async {
    final root = await Directory.systemTemp.createTemp('e2e');
    final db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsRepoImpl(db);
    await settings.load();
    final repo = DownloadRepoImpl(db);
    final library = LibraryRepoImpl(db);
    final transport = ChunkedHttpTransport();
    final gate = ResolveGate();
    final resolver = YteMediaResolver(gate: gate);
    final queue = DownloadQueueService(
      JobDeps(
        repo: repo,
        library: library,
        settings: settings,
        resolver: resolver,
        transport: transport,
        muxer: FfmpegKitMuxer(), // not reached for M4A
        fs: IoFileSystemGateway(
          settings,
          supportDirectory: () async => Directory('${root.path}/support'),
          defaultSaveDirectory: () async => Directory('${root.path}/Downloads'),
        ),
      ),
      network: FakeNetwork(NetState.wifi),
      gate: gate,
    );
    final speeds = <double>[];
    queue.live.listen(
      (m) => speeds.addAll(m.values.map((p) => p.bytesPerSecond)),
    );
    await queue.start();

    final sw = Stopwatch()..start();
    final ids = await queue.enqueue([
      const DownloadRequest(
        media: MediaInfo(
          videoId: 'R6MlUcmOul8',
          url: 'https://www.youtube.com/watch?v=R6MlUcmOul8',
          title: 'Tears of Steel',
          channel: 'Blender',
          duration: Duration(seconds: 734),
        ),
        format: FormatSelector(
          kind: MediaKind.audio,
          container: OutContainer.m4a,
        ),
      ),
    ]);
    final id = (ids as Success<List<String>>).data.single;
    await until(
      () async {
        final status = (await repo.task(id))!.status;
        if (status == TaskStatus.failed) {
          fail('failed: ${(await repo.task(id))!.failure}');
        }
        return status == TaskStatus.completed;
      },
      reason: 'download completed',
      timeout: const Duration(minutes: 4),
    );

    final task = (await repo.task(id))!;
    final file = File(task.outputPath!);
    expect(file.path, '${root.path}/Downloads/Tears of Steel - Blender.m4a');
    expect(
      file.lengthSync(),
      greaterThan(10 * 1024 * 1024),
      reason: '~11.9 MB of AAC',
    );
    expect((await library.all()).single.path, file.path);
    expect(
      Directory('${root.path}/support/work/$id').existsSync(),
      isFalse,
      reason: 'work folder removed',
    );
    // ignore: avoid_print — the measured numbers are the point of this test.
    print(
      'E2E: ${(file.lengthSync() / 1048576).toStringAsFixed(1)} MB in ${sw.elapsed.inSeconds}s, '
      'peak ${(speeds.fold<double>(0, (a, b) => a > b ? a : b) / 1048576).toStringAsFixed(2)} MB/s',
    );

    await queue.dispose();
    resolver.close();
    transport.close();
    await db.close();
    await root.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
