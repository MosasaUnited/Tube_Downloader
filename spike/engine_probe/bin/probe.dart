// Phase-0 engine probe (throwaway). For each client config: fetch the manifest,
// pick the best H.264 video-only stream <= 1080p and the best AAC/m4a audio,
// then pull the first 2 MB of each with a ranged request and report the result.
import 'dart:io';

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

// Blender Foundation open movies (CC-BY): Big Buck Bunny 4K60, Sintel, Tears of Steel.
const _fixtures = ['aqz-KE-bpKQ', 'eRsGyueVLvQ', 'R6MlUcmOul8'];

final _configs = <String, List<YoutubeApiClient>?>{
  'default': null,
  'visionOs': [visionOsClient],
  'ios': [YoutubeApiClient.ios],
  'tv': [YoutubeApiClient.tv],
};

Future<void> main() async {
  final yt = YoutubeExplode();
  final http = HttpClient();
  try {
    for (final id in _fixtures) {
      stdout.writeln('\n=== $id');
      for (final entry in _configs.entries) {
        await _probe(yt, http, id, entry.key, entry.value);
      }
    }
  } finally {
    yt.close();
    http.close(force: true);
  }
}

Future<void> _probe(YoutubeExplode yt, HttpClient http, String id, String name,
    List<YoutubeApiClient>? clients) async {
  final sw = Stopwatch()..start();
  try {
    final manifest = clients == null
        ? await yt.videos.streams.getManifest(id)
        : await yt.videos.streams.getManifest(id, ytClients: clients);
    final ms = sw.elapsedMilliseconds;
    final video = manifest.videoOnly
        .where((s) => s.container == StreamContainer.mp4 && s.videoResolution.height <= 1080)
        .sortByVideoQuality()
        .firstOrNull;
    final audio = manifest.audioOnly
        .where((s) => s.container == StreamContainer.mp4)
        .sortByBitrate()
        .firstOrNull; // sortByBitrate is descending
    final best = manifest.videoOnly.sortByVideoQuality().firstOrNull;
    stdout.writeln('[$name] manifest ${ms}ms · muxed=${manifest.muxed.length} '
        'videoOnly=${manifest.videoOnly.length} audioOnly=${manifest.audioOnly.length} '
        'max=${best?.qualityLabel}');
    if (video != null) {
      stdout.writeln('   video ${video.qualityLabel} ${video.videoCodec} '
          '${_mb(video.size.totalBytes)} → ${await _pull(http, video)}');
    }
    if (audio != null) {
      stdout.writeln('   audio ${audio.bitrate.kiloBitsPerSecond.round()}kbps ${audio.audioCodec} '
          '${_mb(audio.size.totalBytes)} → ${await _pull(http, audio)}');
    }
  } on Object catch (e) {
    stdout.writeln('[$name] ERROR ${e.runtimeType}: ${e.toString().split('\n').first}');
  }
}

/// Ranged GET of the first 2 MB. Non-Android clients take `&range=` in the query.
Future<String> _pull(HttpClient http, StreamInfo s) async {
  const chunk = 2 * 1024 * 1024;
  final url = s.url.replace(queryParameters: {...s.url.queryParameters, 'range': '0-${chunk - 1}'});
  final sw = Stopwatch()..start();
  try {
    final req = await http.getUrl(url);
    final res = await req.close();
    var got = 0;
    await for (final b in res) {
      got += b.length;
    }
    final secs = sw.elapsedMilliseconds / 1000;
    return 'HTTP ${res.statusCode} ${_mb(got)} in ${secs.toStringAsFixed(1)}s '
        '(${(got / 1048576 / (secs == 0 ? 1 : secs)).toStringAsFixed(1)} MB/s)';
  } on Object catch (e) {
    return 'ERROR ${e.runtimeType}';
  }
}

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)}MB';
