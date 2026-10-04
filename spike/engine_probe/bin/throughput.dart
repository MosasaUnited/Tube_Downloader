// Phase-0 throughput probe (throwaway): is the visionOs stream throttled per connection?
import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'probe.dart' show visionOsClient;

const _mbyte = 1024 * 1024;

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : 'aqz-KE-bpKQ';
  final yt = YoutubeExplode();
  final http = HttpClient()..maxConnectionsPerHost = 8;
  try {
    stdout.writeln('baseline (Cloudflare 25MB): ${await _baseline(http)}');
    final m = await yt.videos.streams.getManifest(id, ytClients: [visionOsClient]);
    final v = m.videoOnly
        .where((s) => s.container == StreamContainer.mp4 && s.videoResolution.height <= 1080)
        .sortByVideoQuality()
        .first;
    final a = m.audioOnly.where((s) => s.container == StreamContainer.mp4).sortByBitrate().first;
    stdout.writeln('audio pick: ${a.bitrate.kiloBitsPerSecond.round()}kbps ${a.audioCodec}');
    stdout.writeln('video: ${v.qualityLabel} ${(v.size.totalBytes / _mbyte).toStringAsFixed(1)}MB');

    // (a) sequential 10 MB chunks, 30 MB total
    var sw = Stopwatch()..start();
    var total = 0;
    for (var i = 0; i < 3; i++) {
      total += await _range(http, v.url, i * 10 * _mbyte, (i + 1) * 10 * _mbyte - 1);
    }
    stdout.writeln('sequential 3x10MB: ${_rate(total, sw)}');

    // (b) 4 parallel 5 MB chunks starting at 30 MB
    sw = Stopwatch()..start();
    final parts = await Future.wait([
      for (var i = 0; i < 4; i++)
        _range(http, v.url, (30 + i * 5) * _mbyte, (30 + (i + 1) * 5) * _mbyte - 1),
    ]);
    stdout.writeln('parallel 4x5MB: ${_rate(parts.fold(0, (s, b) => s + b), sw)}');

    // (c) one request for 30 MB (does the server cap a single request?)
    sw = Stopwatch()..start();
    final big = await _range(http, v.url, 50 * _mbyte, 80 * _mbyte - 1);
    stdout.writeln('single 30MB request: ${_rate(big, sw)}');
  } finally {
    yt.close();
    http.close(force: true);
  }
}

Future<int> _range(HttpClient http, Uri url, int start, int end) async {
  final u = url.replace(queryParameters: {...url.queryParameters, 'range': '$start-$end'});
  final res = await (await http.getUrl(u)).close();
  if (res.statusCode != 200 && res.statusCode != 206) {
    await res.drain<void>();
    throw HttpException('HTTP ${res.statusCode}', uri: u);
  }
  var got = 0;
  await for (final b in res) {
    got += b.length;
  }
  return got;
}

Future<String> _baseline(HttpClient http) async {
  final sw = Stopwatch()..start();
  final res = await (await http.getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=25000000'))).close();
  var got = 0;
  await for (final b in res) {
    got += b.length;
  }
  return _rate(got, sw);
}

String _rate(int bytes, Stopwatch sw) {
  final s = sw.elapsedMilliseconds / 1000;
  return '${(bytes / _mbyte).toStringAsFixed(1)}MB in ${s.toStringAsFixed(1)}s = '
      '${(bytes / _mbyte / s).toStringAsFixed(2)} MB/s';
}
