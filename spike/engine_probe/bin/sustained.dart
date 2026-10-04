// Phase-0 probe (throwaway): sustained throughput by worker count / chunk size.
import 'dart:io';
import 'dart:math' as math;

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'probe.dart' show visionOsClient;

const _mb = 1024 * 1024;

Future<void> main() async {
  final yt = YoutubeExplode();
  final http = HttpClient()..maxConnectionsPerHost = 16;
  try {
    final m = await yt.videos.streams.getManifest('eRsGyueVLvQ', ytClients: [visionOsClient]);
    final v = m.videoOnly
        .where((s) => s.container == StreamContainer.mp4 && s.videoCodec.startsWith('avc1') && s.videoResolution.height <= 1080)
        .sortByVideoQuality()
        .first;
    final q = v.url.queryParameters;
    stdout.writeln('url keys: ${q.keys.where((k) => const ['n', 'ratebypass', 'c', 'clen', 'expire', 'ip'].contains(k)).map((k) => '$k=${k == 'ip' ? '<redacted>' : q[k]}').join(' ')}');
    stdout.writeln('isThrottled: ${v.isThrottled}');
    for (final (workers, chunkMb) in [(4, 8), (8, 4), (8, 2)]) {
      final sw = Stopwatch()..start();
      var next = 0;
      var got = 0;
      const total = 64 * _mb;
      Future<void> worker() async {
        while (next < total) {
          final start = next;
          next = math.min(start + chunkMb * _mb, total);
          // Await first, then add: `got += await …` reads `got` before the
          // await, so concurrent workers would overwrite each other's counts.
          final n = await _range(http, v.url, start + 10 * _mb, next - 1 + 10 * _mb);
          got += n;
        }
      }
      await Future.wait(List.generate(workers, (_) => worker()));
      final s = sw.elapsedMilliseconds / 1000;
      stdout.writeln('${workers}x${chunkMb}MB sustained 64MB: ${s.toStringAsFixed(1)}s = ${(got / _mb / s).toStringAsFixed(2)} MB/s, stalls retried: $stalls');
      stalls = 0;
    }
  } finally {
    yt.close();
    http.close(force: true);
  }
}

var stalls = 0;

/// Ranged GET with a 20 s stall timeout; a stalled or failed chunk is retried
/// from scratch (up to 5 attempts) — the behaviour the real transport needs.
Future<int> _range(HttpClient http, Uri url, int start, int end) async {
  final u = url.replace(queryParameters: {...url.queryParameters, 'range': '$start-$end'});
  for (var attempt = 1; ; attempt++) {
    HttpClientRequest? req;
    try {
      req = await http.getUrl(u).timeout(const Duration(seconds: 15));
      final res = await req.close().timeout(const Duration(seconds: 20));
      var n = 0;
      await for (final b in res.timeout(const Duration(seconds: 20))) {
        n += b.length;
      }
      if (n != end - start + 1) throw StateError('short chunk');
      return n;
    } on Object {
      stalls++;
      req?.abort();
      if (attempt >= 5) rethrow;
    }
  }
}
