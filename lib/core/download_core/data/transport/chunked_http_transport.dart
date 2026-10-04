import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tube_downloader/core/download_core/domain/repos/media_transport.dart';
import 'package:tube_downloader/core/error/app_exceptions.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';

/// Downloads a stream as parallel ranged chunks (docs/spike/phase0.md):
/// YouTube throttles each connection to ~0.5 MB/s, and 8 × 4 MB chunks reach
/// ~70 % of the line.
///
/// Chunks finish out of order but are APPENDED in order, so the file on disk
/// is always a contiguous prefix: resuming means "start from the file
/// length". A chunk that receives nothing for [stallTimeout] is aborted and
/// retried (minutes-long silent stalls were observed). HTTP 403 fails at once
/// as `streamExpired` so the queue can fetch a fresh URL.
class ChunkedHttpTransport implements MediaTransport {
  ChunkedHttpTransport({
    HttpClient? client,
    this.workers = 8,
    this.chunkBytes = 4 * 1024 * 1024,
    this.stallTimeout = const Duration(seconds: 20),
    this.connectTimeout = const Duration(seconds: 15),
    this.maxChunkAttempts = 5,
    this.progressInterval = const Duration(milliseconds: 200),
    Future<void> Function(Duration)? retryDelay,
  }) : _client = client ?? HttpClient(),
       _retryDelay = retryDelay ?? Future<void>.delayed {
    _client
      ..maxConnectionsPerHost = workers * 2
      ..connectionTimeout = connectTimeout
      ..idleTimeout = const Duration(seconds: 15)
      ..autoUncompress = false;
  }

  final HttpClient _client;
  final int workers;
  final int chunkBytes;
  final Duration stallTimeout;
  final Duration connectTimeout;
  final int maxChunkAttempts;
  final Duration progressInterval;
  final Future<void> Function(Duration) _retryDelay;
  final _jobs = <String, _ChunkedJob>{};

  @override
  Stream<TransferUpdate> start(TransferJob job) {
    final controller = StreamController<TransferUpdate>();
    final run = _ChunkedJob(this, job, controller.add);
    _jobs[job.jobId] = run;
    unawaited(
      run.execute().then((update) {
        _jobs.remove(job.jobId);
        controller.add(update);
        return controller.close();
      }),
    );
    return controller.stream;
  }

  @override
  Future<void> stop(String jobId) async => _jobs[jobId]?.cancel();

  /// Releases the connection pool (app shutdown, tests).
  void close() => _client.close(force: true);
}

class _ChunkedJob {
  _ChunkedJob(this._t, this._job, this._emit);

  final ChunkedHttpTransport _t;
  final TransferJob _job;
  final void Function(TransferUpdate) _emit;

  final _requests = <HttpClientRequest>{};
  final _ready =
      <int, Uint8List>{}; // chunk start → bytes, waiting for its turn
  Completer<void> _progressed = Completer<void>();

  /// The user (queue) stopped the job — reported as `cancelled`.
  bool _stoppedByUser = false;

  /// The first real failure — reported as itself, never masked as cancelled.
  Object? _error;
  StackTrace? _errorStack;

  /// Only one flush loop at a time: two pending writes on one
  /// RandomAccessFile throw, and workers DO interleave at every await.
  bool _flushing = false;

  late final int _total = _job.target.totalBytes;
  late int _nextFetch = _job.resumeFrom; // next chunk start to hand out
  late int _written = _job.resumeFrom; // bytes appended to the file
  int _inFlight = 0; // bytes received for chunks not yet written
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _stopping => _stoppedByUser || _error != null;

  void cancel() {
    _stoppedByUser = true;
    _abortAll();
  }

  void _fail(Object error, StackTrace stack) {
    if (_error == null && !_stoppedByUser) {
      _error = error;
      _errorStack = stack;
    }
    _abortAll(); // the job has failed: stop the sibling workers
  }

  void _abortAll() {
    for (final request in _requests.toList()) {
      request.abort();
    }
    _wake();
  }

  Future<TransferUpdate> execute() async {
    RandomAccessFile? file;
    try {
      file = await File(_job.filePath).open(mode: FileMode.writeOnlyAppend);
      final length = await file.length();
      if (length != _job.resumeFrom) {
        throw StateError(
          'resumeFrom ${_job.resumeFrom} != file length $length',
        );
      }
      if (_written >= _total) return TransferUpdate.done(_total);
      final out = file;
      await Future.wait(List.generate(_t.workers, (_) => _worker(out)));
      if (_stoppedByUser) throw const CancelledException();
      if (_error != null) {
        Error.throwWithStackTrace(_error!, _errorStack ?? StackTrace.current);
      }
      if (_written != _total) {
        throw StateError('wrote $_written of $_total bytes');
      }
      await out.flush();
      return TransferUpdate.done(_written);
    } on Object catch (e, s) {
      return TransferUpdate.failed(
        FailureMapper.map(_stoppedByUser ? const CancelledException() : e, s),
      );
    } finally {
      await file?.close();
    }
  }

  Future<void> _worker(RandomAccessFile file) async {
    // Never fetch more than this far ahead of the write position: a stalled
    // early chunk must not let the in-memory buffer grow without bound.
    final maxAhead = _t.chunkBytes * _t.workers * 2;
    while (!_stopping && _nextFetch < _total) {
      if (_nextFetch - _written >= maxAhead) {
        await _progressed.future;
        continue;
      }
      final start = _nextFetch;
      final end = min(start + _t.chunkBytes, _total) - 1;
      _nextFetch = end + 1;
      try {
        final bytes = await _fetchWithRetry(start, end);
        if (_stopping) return;
        _ready[start] = bytes;
        await _flushInOrder(file);
      } on Object catch (e, s) {
        _fail(e, s);
        return;
      }
    }
  }

  /// Appends every chunk that is next in line. If a flush is already running
  /// it will pick this chunk up (it re-checks after each write), so return.
  Future<void> _flushInOrder(RandomAccessFile file) async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (!_stopping && _ready.containsKey(_written)) {
        final bytes = _ready.remove(_written)!;
        await file.writeFrom(bytes);
        _inFlight -= bytes.length;
        _written += bytes.length;
        _reportProgress(force: _written >= _total);
        _wake();
      }
    } finally {
      _flushing = false;
    }
  }

  /// Releases workers waiting for the write position to advance.
  void _wake() {
    if (!_progressed.isCompleted) _progressed.complete();
    _progressed = Completer<void>();
  }

  Future<Uint8List> _fetchWithRetry(int start, int end) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _fetch(start, end);
      } on HttpStatusException catch (e) {
        // 403/410: the signed URL expired or the IP changed — re-resolve, don't
        // hammer it. 429: the queue owns the global cooldown.
        const fatal = {403, 410, 429};
        if (fatal.contains(e.statusCode) || attempt >= _t.maxChunkAttempts) {
          rethrow;
        }
      } on Object {
        if (_stopping || attempt >= _t.maxChunkAttempts) rethrow;
      }
      await _t._retryDelay(Duration(milliseconds: 500 * (1 << (attempt - 1))));
      if (_stopping) throw const CancelledException();
    }
  }

  Future<Uint8List> _fetch(int start, int end) async {
    final target = _job.target;
    final uri = target.rangeInQuery
        ? target.url.replace(
            queryParameters: {
              ...target.url.queryParameters,
              'range': '$start-$end',
            },
          )
        : target.url;
    final request = await _t._client.getUrl(uri).timeout(_t.connectTimeout);
    _requests.add(request);
    var received = 0;
    try {
      target.headers.forEach(request.headers.set);
      if (!target.rangeInQuery) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      }
      final response = await request.close().timeout(_t.stallTimeout);
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>().catchError((Object _) {});
        throw HttpStatusException(response.statusCode, uri: uri);
      }
      final builder = BytesBuilder(copy: false);
      await for (final data in response.timeout(_t.stallTimeout)) {
        builder.add(data);
        received += data.length;
        _inFlight += data.length;
        _reportProgress();
      }
      final bytes = builder.takeBytes();
      final expected = end - start + 1;
      if (bytes.length != expected) {
        throw HttpException(
          'short chunk: ${bytes.length} of $expected bytes',
          uri: uri,
        );
      }
      return bytes;
    } on Object {
      _inFlight -= received; // a failed chunk is fetched again from scratch
      request.abort();
      rethrow;
    } finally {
      _requests.remove(request);
    }
  }

  void _reportProgress({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastProgress) < _t.progressInterval) return;
    _lastProgress = now;
    _emit(
      TransferUpdate.progress(
        doneBytes: min(_written + _inFlight, _total),
        totalBytes: _total,
      ),
    );
  }
}
