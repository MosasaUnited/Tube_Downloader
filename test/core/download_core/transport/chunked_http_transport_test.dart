import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/data/transport/chunked_http_transport.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/stream_target.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_transport.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

/// A local media server with the behaviours the spike observed on YouTube:
/// ranged requests (query or header), stalls, 403s, slow responses.
class _MediaServer {
  _MediaServer(this.data);

  final Uint8List data;
  late HttpServer _server;
  int requests = 0;
  int bytesServed = 0;
  int maxConcurrent = 0;
  int _current = 0;

  /// Respond with this status to every request.
  int? status;

  /// The next N requests send 1 KB and then hang.
  int stallNext = 0;

  /// Delay before each response body.
  Duration slow = Duration.zero;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((r) => unawaited(_handle(r)));
  }

  Future<void> stop() => _server.close(force: true);

  Uri get url => Uri.parse(
    'http://127.0.0.1:${_server.port}/videoplayback?expire=1&itag=137',
  );

  Future<void> _handle(HttpRequest request) async {
    requests++;
    maxConcurrent = max(maxConcurrent, ++_current);
    final response = request.response;
    try {
      if (status != null) {
        response.statusCode = status!;
        await response.close();
        return;
      }
      final (start, end) = _range(request);
      final slice = Uint8List.sublistView(data, start, end + 1);
      response
        ..statusCode = request.uri.queryParameters.containsKey('range')
            ? HttpStatus.ok
            : HttpStatus.partialContent
        ..contentLength = slice.length;
      if (stallNext > 0) {
        stallNext--;
        response.add(Uint8List.sublistView(slice, 0, min(1024, slice.length)));
        await response.flush();
        await Future<void>.delayed(
          const Duration(seconds: 10),
        ); // the client gives up first
        return;
      }
      if (slow > Duration.zero) await Future<void>.delayed(slow);
      response.add(slice);
      bytesServed += slice.length;
      await response.close();
    } on Object {
      // The client aborted (stall timeout, stop): expected in these tests.
    } finally {
      _current--;
    }
  }

  (int, int) _range(HttpRequest request) {
    final spec =
        request.uri.queryParameters['range'] ??
        request.headers
            .value(HttpHeaders.rangeHeader)!
            .replaceFirst('bytes=', '');
    final parts = spec.split('-').map(int.parse).toList();
    return (parts[0], parts[1]);
  }
}

void main() {
  final data = Uint8List.fromList(
    List.generate(1000000, (i) => (i * 31 + 7) % 251),
  );
  late _MediaServer server;
  late Directory dir;
  late ChunkedHttpTransport transport;

  setUp(() async {
    server = _MediaServer(data);
    await server.start();
    dir = await Directory.systemTemp.createTemp('transport_test');
    transport = ChunkedHttpTransport(
      workers: 4,
      chunkBytes: 64 * 1024,
      stallTimeout: const Duration(milliseconds: 300),
      progressInterval: Duration.zero,
      retryDelay: (_) async {},
    );
  });

  tearDown(() async {
    transport.close();
    await server.stop();
    await dir.delete(recursive: true);
  });

  StreamTarget target({bool rangeInQuery = true}) => StreamTarget(
    leg: LegKind.video,
    itag: 137,
    url: server.url,
    totalBytes: data.length,
    ext: 'mp4',
    rangeInQuery: rangeInQuery,
  );

  Future<List<TransferUpdate>> run(
    String path, {
    StreamTarget? t,
    int resumeFrom = 0,
  }) => transport
      .start(
        TransferJob(
          jobId: 'j',
          target: t ?? target(),
          filePath: path,
          resumeFrom: resumeFrom,
        ),
      )
      .toList();

  test('downloads every byte, in order, with parallel connections', () async {
    // A little latency so requests overlap (from memory they finish instantly).
    server.slow = const Duration(milliseconds: 20);
    final path = '${dir.path}/v.part';
    final updates = await run(path);

    expect(updates.last, const TransferUpdate.done(1000000));
    expect(updates.whereType<TransferProgress>(), isNotEmpty);
    expect(await File(path).readAsBytes(), data);
    expect(
      server.maxConcurrent,
      inInclusiveRange(2, 4),
      reason: 'parallel, but never more than the worker count',
    );
  });

  test(
    'resumes from the file length and fetches only the remaining bytes',
    () async {
      final path = '${dir.path}/v.part';
      await File(path).writeAsBytes(Uint8List.sublistView(data, 0, 300000));

      final updates = await run(path, resumeFrom: 300000);

      expect(updates.last, const TransferUpdate.done(1000000));
      expect(server.bytesServed, 700000);
      expect(await File(path).readAsBytes(), data);
    },
  );

  test(
    'a stalled chunk is aborted after the stall timeout and fetched again',
    () async {
      server.stallNext = 2;
      final path = '${dir.path}/v.part';

      final updates = await run(path);

      expect(updates.last, const TransferUpdate.done(1000000));
      expect(await File(path).readAsBytes(), data);
      expect(
        server.requests,
        greaterThan((data.length / (64 * 1024)).ceil()),
        reason: 'the stalled chunks were retried',
      );
    },
  );

  test(
    '403 fails at once as streamExpired (the queue re-resolves the URL)',
    () async {
      server.status = HttpStatus.forbidden;

      final updates = await run('${dir.path}/v.part');

      final failed = updates.last as TransferFailed;
      expect(failed.failure.type, FailureType.streamExpired);
      expect(
        server.requests,
        lessThanOrEqualTo(4),
        reason: 'no retries on 403 — at most the in-flight workers',
      );
    },
  );

  test('stop() pauses: cancelled failure, and the file is a valid prefix to resume from', () async {
    server.slow = const Duration(milliseconds: 40);
    final path = '${dir.path}/v.part';
    final updates = <TransferUpdate>[];
    final done = Completer<void>();
    transport
        .start(TransferJob(jobId: 'j', target: target(), filePath: path))
        .listen(updates.add, onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await transport.stop('j');
    await done.future;

    expect(
      (updates.last as TransferFailed).failure.type,
      FailureType.cancelled,
    );
    final partial = await File(path).readAsBytes();
    expect(partial.length, lessThan(data.length));
    expect(
      partial,
      Uint8List.sublistView(data, 0, partial.length),
      reason: 'contiguous prefix, no holes',
    );

    // Resume completes the file.
    final resumed = await run(path, resumeFrom: partial.length);
    expect(resumed.last, const TransferUpdate.done(1000000));
    expect(await File(path).readAsBytes(), data);
  });

  test('Range header mode (Android-style URLs)', () async {
    final path = '${dir.path}/v.part';
    final updates = await run(path, t: target(rangeInQuery: false));
    expect(updates.last, const TransferUpdate.done(1000000));
    expect(await File(path).readAsBytes(), data);
  });
}
