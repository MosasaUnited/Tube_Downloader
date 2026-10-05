import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/data/platform/http_thumbnail_store.dart';

void main() {
  late HttpServer server;
  late Directory support;
  late HttpThumbnailStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('thumbs');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/ok.jpg':
          response.add(List.filled(5000, 7));
        case '/huge.jpg':
          response.add(List.filled(3 * 1024 * 1024, 1));
        default:
          response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
    store = HttpThumbnailStore(supportDirectory: () async => support);
  });
  tearDown(() async {
    store.close();
    await server.close(force: true);
    await support.delete(recursive: true);
  });

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  test('saves the picture under thumbs/<videoId>.jpg, atomically', () async {
    final path = await store.save('abcdefghijk', url('/ok.jpg'));
    expect(path, '${support.path}/thumbs/abcdefghijk.jpg');
    expect(await File(path!).length(), 5000);
    expect(File('$path.part').existsSync(), isFalse);

    await store.delete(path);
    expect(File(path).existsSync(), isFalse);
    await store.delete(path); // already gone: no error
  });

  test(
    'best effort: a 404, an oversized body or no server give null',
    () async {
      expect(await store.save('a', url('/missing.jpg')), isNull);
      expect(await store.save('b', url('/huge.jpg')), isNull);
      expect(await store.save('c', 'http://127.0.0.1:1/x.jpg'), isNull);
      expect(Directory('${support.path}/thumbs').listSync(), isEmpty);
    },
  );
}
