import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/entities/stream_target.dart';
import 'package:tube_downloader/core/download_core/domain/repos/activity_assertion.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_muxer.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_transport.dart';
import 'package:tube_downloader/core/download_core/domain/repos/network_monitor.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';

/// In-memory files: path → length.
class FakeFileSystem implements FileSystemGateway {
  final files = <String, int>{};
  final workDirs = <String>{};
  int? free;

  @override
  Future<String> workDir(String taskId) async {
    workDirs.add(taskId);
    return '/work/$taskId';
  }

  @override
  Future<List<String>> workDirTaskIds() async => workDirs.toList();

  @override
  Future<void> deleteWorkDir(String taskId) async {
    workDirs.remove(taskId);
    files.removeWhere((path, _) => path.startsWith('/work/$taskId/'));
  }

  @override
  Future<int> fileLength(String path) async => files[path] ?? 0;

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> deleteFile(String path) async => files.remove(path);

  @override
  Future<Result<String>> publish({
    required String sourcePath,
    required String fileName,
    String? subDir,
  }) async {
    final length = files.remove(sourcePath);
    if (length == null) {
      return const Result.failure(AppFailure(type: FailureType.unknown));
    }
    final dir = subDir == null ? '/downloads' : '/downloads/$subDir';
    final dot = fileName.lastIndexOf('.');
    var path = '$dir/$fileName';
    for (var n = 2; files.containsKey(path); n++) {
      path =
          '$dir/${fileName.substring(0, dot)} ($n)${fileName.substring(dot)}';
    }
    files[path] = length;
    return Result.success(path);
  }

  @override
  Future<int?> freeBytes() async => free;
}

/// Writes half the stream, then waits for [release] (or a stop), then the
/// rest. Scripted failures per itag are consumed one per attempt.
class FakeTransport implements MediaTransport {
  FakeTransport(this.fs);

  final FakeFileSystem fs;
  final starts = <TransferJob>[];
  final script = <int, List<AppFailure>>{};
  Completer<void>? hold;
  final _stops = <String, Completer<void>>{};

  /// Lets every held transfer finish.
  void release() {
    final h = hold;
    hold = null;
    h?.complete();
  }

  @override
  Stream<TransferUpdate> start(TransferJob job) {
    starts.add(job);
    final out = StreamController<TransferUpdate>();
    final stop = _stops[job.jobId] = Completer<void>();
    unawaited(() async {
      final total = job.target.totalBytes;
      final half = max(job.resumeFrom, total ~/ 2);
      fs.files[job.filePath] = half;
      out.add(TransferUpdate.progress(doneBytes: half, totalBytes: total));
      final scripted = script[job.target.itag];
      if (scripted != null && scripted.isNotEmpty) {
        out.add(TransferUpdate.failed(scripted.removeAt(0)));
      } else {
        final h = hold;
        if (h != null) await Future.any([h.future, stop.future]);
        if (stop.isCompleted) {
          out.add(
            const TransferUpdate.failed(
              AppFailure(type: FailureType.cancelled),
            ),
          );
        } else {
          fs.files[job.filePath] = total;
          out.add(TransferUpdate.done(total));
        }
      }
      await out.close();
    }());
    return out.stream;
  }

  @override
  Future<void> stop(String jobId) async {
    final c = _stops[jobId];
    if (c != null && !c.isCompleted) c.complete();
  }
}

class FakeMuxer implements MediaMuxer {
  FakeMuxer(this.fs);

  final FakeFileSystem fs;
  AppFailure? fail;
  int merges = 0;
  int conversions = 0;

  @override
  Stream<MuxUpdate> merge({
    required String jobId,
    required String videoPath,
    required String audioPath,
    required String outputPath,
    Duration? duration,
  }) async* {
    merges++;
    yield const MuxUpdate.progress(0.5);
    if (fail != null) {
      yield MuxUpdate.failed(fail!);
      return;
    }
    fs.files[outputPath] =
        (fs.files[videoPath] ?? 0) + (fs.files[audioPath] ?? 0);
    yield const MuxUpdate.done();
  }

  @override
  Stream<MuxUpdate> toMp3({
    required String jobId,
    required String audioPath,
    required String outputPath,
    required int kbps,
    Duration? duration,
  }) async* {
    conversions++;
    fs.files[outputPath] = (fs.files[audioPath] ?? 0) ~/ 2;
    yield const MuxUpdate.done();
  }

  @override
  Future<void> cancel(String jobId) async {}
}

class FakeResolver implements MediaResolver {
  List<LegKind> legs = const [LegKind.video, LegKind.audio];
  AppFailure? planFailure;
  int videoBytes = 1000;
  int audioBytes = 100;
  final targetCalls = <LegKind>[];
  int plans = 0;

  @override
  Future<Result<List<LegKind>>> plan(
    String videoId,
    FormatSelector selector,
  ) async {
    plans++;
    final f = planFailure;
    return f != null ? Result.failure(f) : Result.success(legs);
  }

  @override
  Future<Result<StreamTarget>> target(
    String videoId,
    FormatSelector selector,
    LegKind leg,
  ) async {
    targetCalls.add(leg);
    return Result.success(
      StreamTarget(
        leg: leg,
        itag: switch (leg) {
          LegKind.video => 137,
          LegKind.audio => 140,
          LegKind.muxed => 18,
        },
        url: Uri.parse('https://example.test/${leg.name}'),
        totalBytes: leg == LegKind.audio ? audioBytes : videoBytes,
        ext: leg == LegKind.audio ? 'm4a' : 'mp4',
      ),
    );
  }

  @override
  Future<Result<ResolvedLink>> resolve(ParsedLink link) =>
      throw UnimplementedError();

  @override
  Stream<Result<MediaInfo>> playlistItems(String playlistId) =>
      throw UnimplementedError();

  @override
  Future<Result<List<FormatOption>>> formats(String videoId) =>
      throw UnimplementedError();

  @override
  void close() {}
}

/// Records begin / end calls in order.
class RecordingActivity implements ActivityAssertion {
  final calls = <String>[];

  @override
  Future<void> begin() async => calls.add('begin');

  @override
  Future<void> end() async => calls.add('end');
}

class FakeNetwork implements NetworkMonitor {
  FakeNetwork(this.state);

  NetState state;
  final _changes = StreamController<NetState>.broadcast();

  void set(NetState next) {
    state = next;
    _changes.add(next);
  }

  @override
  Future<NetState> current() async => state;

  @override
  Stream<NetState> watch() => _changes.stream;
}

/// Polls until [condition] holds (real async: sockets, drift, timers).
Future<void> until(
  FutureOr<bool> Function() condition, {
  String? reason,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting: ${reason ?? 'condition'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
