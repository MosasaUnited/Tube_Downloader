// Phase-0 engine spike (throwaway — never imported by the real app).
//
// Runs unattended on launch: for each CC-BY fixture, resolve with the
// app-defined visionOS client, download the best H.264 video-only stream
// (<= 1080p) and the best AAC audio stream with 4 parallel ranged chunks,
// merge them with FFmpeg (-c copy), verify the result with FFprobe, convert
// one audio track to MP3, then print a JSON report and exit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const visionOsClient = YoutubeApiClient({
  'context': {
    'client': {
      'clientName': 'VISIONOS',
      'clientVersion': '1.02',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice17,1',
      'osName': 'visionOS',
      'osVersion': '26.5.23O471',
      'userAgent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/26.0 Safari/605.1.15',
      'hl': 'en',
      'timeZone': 'UTC',
      'utcOffsetMinutes': 0,
    },
  },
}, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

/// Blender Foundation open movies (CC-BY): Tears of Steel, Sintel, Big Buck Bunny.
/// Override per run: --dart-define=FIXTURES=R6MlUcmOul8 --dart-define=MAX_HEIGHT=720
final fixtures = const String.fromEnvironment('FIXTURES', defaultValue: 'R6MlUcmOul8,eRsGyueVLvQ,aqz-KE-bpKQ').split(',');
const maxHeight = int.fromEnvironment('MAX_HEIGHT', defaultValue: 1080);

// Measured best on macOS: 8 workers x 4 MB (docs/spike/phase0.md).
const chunkBytes = 4 * 1024 * 1024;
const workers = 8;
const stallTimeout = Duration(seconds: 20);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Engine spike running…')))));
  unawaited(_runSpike());
}

Future<void> _runSpike() async {
  final report = <String, Object?>{
    'platform': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'startedAt': DateTime.now().toIso8601String(),
    'fixtures': <Object?>[],
  };
  final out = Directory('${(await getApplicationSupportDirectory()).path}/spike');
  await out.create(recursive: true);
  _log({'event': 'outputDir', 'path': out.path});

  final yt = YoutubeExplode();
  final http = HttpClient()..maxConnectionsPerHost = workers * 2;
  try {
    for (final (i, id) in fixtures.indexed) {
      final result = await _runFixture(yt, http, id, out, convertMp3: i == 0);
      (report['fixtures']! as List<Object?>).add(result);
      _log(result);
    }
  } on Object catch (e, s) {
    report['fatal'] = '$e';
    _log({'event': 'fatal', 'error': '$e', 'stack': '$s'.split('\n').take(5).join(' | ')});
  } finally {
    yt.close();
    http.close(force: true);
  }
  report['finishedAt'] = DateTime.now().toIso8601String();
  final file = File('${out.path}/report-${Platform.operatingSystem}.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  _log({'event': 'report', 'path': file.path});
  exit(report.containsKey('fatal') ? 1 : 0);
}

Future<Map<String, Object?>> _runFixture(
  YoutubeExplode yt,
  HttpClient http,
  String id,
  Directory out, {
  required bool convertMp3,
}) async {
  final r = <String, Object?>{'id': id};
  try {
    final video = await _retry('videos.get', () => yt.videos.get(id), r);
    r['title'] = video.title;
    r['durationS'] = video.duration?.inSeconds;

    final sw = Stopwatch()..start();
    final manifest = await _retry(
      'getManifest',
      () => yt.videos.streams.getManifest(id, ytClients: [visionOsClient]),
      r,
    );
    r['manifestMs'] = sw.elapsedMilliseconds;

    final v = manifest.videoOnly
        .where((s) =>
            s.container == StreamContainer.mp4 &&
            s.videoCodec.startsWith('avc1') &&
            s.videoResolution.height <= maxHeight)
        .sortByVideoQuality()
        .firstOrNull;
    final a = manifest.audioOnly
        .where((s) => s.container == StreamContainer.mp4)
        .sortByBitrate()
        .firstOrNull; // sortByBitrate is descending
    if (v == null || a == null) {
      r['error'] = 'no avc1<=${maxHeight}p video or mp4 audio (video=${v != null}, audio=${a != null})';
      return r;
    }
    r['video'] = {'quality': v.qualityLabel, 'codec': v.videoCodec, 'bytes': v.size.totalBytes};
    r['audio'] = {'kbps': a.bitrate.kiloBitsPerSecond.round(), 'codec': a.audioCodec, 'bytes': a.size.totalBytes};

    final vFile = File('${out.path}/$id.video.mp4.part');
    final aFile = File('${out.path}/$id.audio.m4a.part');
    r['videoDownload'] = await _timed(() => _downloadParallel(http, v.url, v.size.totalBytes, vFile));
    r['audioDownload'] = await _timed(() => _downloadParallel(http, a.url, a.size.totalBytes, aFile));

    final merged = '${out.path}/$id.mp4';
    sw.reset();
    final mergeSession = await FFmpegKit.executeWithArguments([
      '-y', '-i', vFile.path, '-i', aFile.path, //
      '-map', '0:v:0', '-map', '1:a:0', '-c', 'copy', '-movflags', '+faststart', merged,
    ]);
    final mergeRc = await mergeSession.getReturnCode();
    r['merge'] = {
      'ok': ReturnCode.isSuccess(mergeRc),
      'rc': mergeRc?.getValue(),
      'ms': sw.elapsedMilliseconds,
      if (!ReturnCode.isSuccess(mergeRc)) 'log': ((await mergeSession.getAllLogsAsString()) ?? '').split('\n').reversed.take(8).toList(),
    };
    if (ReturnCode.isSuccess(mergeRc)) {
      r['probe'] = await _probe(merged, expectedSeconds: video.duration?.inSeconds);
    }

    if (convertMp3) {
      final mp3 = '${out.path}/$id.mp3';
      sw.reset();
      final s = await FFmpegKit.executeWithArguments(['-y', '-i', aFile.path, '-vn', '-c:a', 'libmp3lame', '-b:a', '192k', mp3]);
      final rc = await s.getReturnCode();
      r['mp3'] = {
        'ok': ReturnCode.isSuccess(rc),
        'ms': sw.elapsedMilliseconds,
        if (ReturnCode.isSuccess(rc)) 'probe': await _probe(mp3, expectedSeconds: video.duration?.inSeconds),
      };
    }
    await vFile.delete();
    await aFile.delete();
  } on Object catch (e) {
    r['error'] = '${e.runtimeType}: ${'$e'.split('\n').first}';
  }
  return r;
}

/// The resolver's retry policy in miniature: transient YouTube failures are
/// retried with backoff (2 s, 4 s, 8 s); each failed attempt is recorded.
Future<T> _retry<T>(String what, Future<T> Function() run, Map<String, Object?> r) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await run();
    } on Object catch (e) {
      (r['retries'] ??= <String>[]) as List<String>;
      (r['retries']! as List<String>).add('$what #$attempt: ${e.runtimeType}');
      if (attempt >= 4) rethrow;
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
    }
  }
}

Future<Map<String, Object?>> _probe(String path, {int? expectedSeconds}) async {
  final session = await FFprobeKit.getMediaInformation(path);
  final info = session.getMediaInformation();
  if (info == null) return {'ok': false};
  final duration = double.tryParse(info.getDuration() ?? '');
  final streams = info.getStreams().map((s) => '${s.getType()}:${s.getCodec()}${s.getHeight() != null ? '@${s.getHeight()}p' : ''}').toList();
  return {
    'ok': true,
    'streams': streams,
    'durationS': duration,
    'sizeBytes': int.tryParse(info.getSize() ?? ''),
    if (expectedSeconds != null && duration != null) 'durationDeltaS': (duration - expectedSeconds).abs(),
  };
}

Future<Map<String, Object?>> _timed(Future<int> Function() run) async {
  final sw = Stopwatch()..start();
  stallRetries = 0;
  final bytes = await run();
  final s = sw.elapsedMilliseconds / 1000;
  return {
    'bytes': bytes,
    'seconds': s,
    'mbPerS': double.parse((bytes / 1048576 / s).toStringAsFixed(2)),
    'retries': stallRetries,
  };
}

/// Downloads [total] bytes of [url] as fixed-size ranged chunks fetched by
/// [workers] parallel requests; each chunk is written at its own offset.
Future<int> _downloadParallel(HttpClient http, Uri url, int total, File file) async {
  final raf = await file.open(mode: FileMode.write);
  var next = 0;
  var done = 0;
  var writeQueue = Future<void>.value();

  Future<void> worker() async {
    while (next < total) {
      final start = next;
      next = math.min(start + chunkBytes, total);
      final bytes = await _fetchRange(http, url, start, next - 1);
      // Writes are serialized: one file handle, explicit position per chunk.
      final write = writeQueue.then((_) async {
        await raf.setPosition(start);
        await raf.writeFrom(bytes);
      });
      writeQueue = write;
      await write;
      done += bytes.length;
    }
  }

  try {
    await Future.wait(List.generate(workers, (_) => worker()));
  } finally {
    await raf.close();
  }
  if (done != total) throw StateError('downloaded $done of $total bytes');
  return done;
}

var stallRetries = 0;

/// One ranged chunk. A connection that stops sending bytes for [stallTimeout]
/// is aborted and the chunk retried from scratch (observed: minutes-long stalls).
Future<Uint8List> _fetchRange(HttpClient http, Uri url, int start, int end, {int attempt = 1}) async {
  final u = url.replace(queryParameters: {...url.queryParameters, 'range': '$start-$end'});
  HttpClientRequest? req;
  try {
    req = await http.getUrl(u).timeout(const Duration(seconds: 15));
    final res = await req.close().timeout(stallTimeout);
    if (res.statusCode != 200 && res.statusCode != 206) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: u);
    }
    final builder = BytesBuilder(copy: false);
    await res.timeout(stallTimeout).forEach(builder.add);
    final bytes = builder.takeBytes();
    if (bytes.length != end - start + 1) {
      throw StateError('short chunk ${bytes.length} != ${end - start + 1}');
    }
    return bytes;
  } on Object {
    req?.abort();
    stallRetries++;
    if (attempt >= 5) rethrow;
    await Future<void>.delayed(Duration(seconds: attempt * 2));
    return _fetchRange(http, url, start, end, attempt: attempt + 1);
  }
}

void _log(Map<String, Object?> m) {
  // ignore: avoid_print — spike output is read from stdout.
  print('SPIKE ${jsonEncode(m)}');
}
