// Phase-0 probe (throwaway): does the watch page / metadata call work from this host right now?
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'probe.dart' show visionOsClient;

Future<void> main() async {
  final yt = YoutubeExplode();
  try {
    for (final id in ['R6MlUcmOul8', 'aqz-KE-bpKQ']) {
      try {
        final v = await yt.videos.get(id);
        stdout.writeln('$id videos.get OK: ${v.title} (${v.duration})');
      } on Object catch (e) {
        stdout.writeln('$id videos.get FAIL: ${e.runtimeType}: ${'$e'.split('\n').first}');
      }
      try {
        final m = await yt.videos.streams.getManifest(id, ytClients: [visionOsClient]);
        stdout.writeln('$id manifest OK: videoOnly=${m.videoOnly.length} audioOnly=${m.audioOnly.length}');
      } on Object catch (e) {
        stdout.writeln('$id manifest FAIL: ${e.runtimeType}: ${'$e'.split('\n').first}');
      }
    }
  } finally {
    yt.close();
  }
  // What does the raw watch page look like from here?
  final http = HttpClient();
  final res = await (await http.getUrl(Uri.parse('https://www.youtube.com/watch?v=R6MlUcmOul8&bpctr=9999999999&hl=en'))).close();
  final body = await res.transform(const SystemEncoding().decoder).join();
  stdout.writeln('raw watch page: HTTP ${res.statusCode}, ${body.length} chars, '
      'ytInitialPlayerResponse=${body.contains('ytInitialPlayerResponse')}, '
      'consent=${body.contains('consent.youtube.com')}, '
      'botCheck=${body.contains("not a bot")}');
  http.close(force: true);
}
