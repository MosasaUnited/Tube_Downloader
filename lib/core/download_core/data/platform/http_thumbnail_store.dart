import 'dart:async';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:tube_downloader/core/download_core/domain/repos/thumbnail_store.dart';

/// [ThumbnailStore] in `<Application Support>/thumbs/<videoId>.jpg`.
class HttpThumbnailStore implements ThumbnailStore {
  HttpThumbnailStore({
    Future<Directory> Function()? supportDirectory,
    HttpClient? client,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _client = client ?? HttpClient();

  final Future<Directory> Function() _supportDirectory;
  final HttpClient _client;

  /// A thumbnail is ~50–150 KB; anything far bigger isn't one.
  static const _maxBytes = 2 * 1024 * 1024;
  static const _timeout = Duration(seconds: 10);

  @override
  Future<String?> save(String videoId, String url) async {
    try {
      final dir = Directory('${(await _supportDirectory()).path}/thumbs');
      await dir.create(recursive: true);
      final target = File('${dir.path}/$videoId.jpg');
      final partial = File('${target.path}.part');
      final request = await _client.getUrl(Uri.parse(url)).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_timeout)) {
        bytes.add(chunk);
        if (bytes.length > _maxBytes) return null;
      }
      await partial.writeAsBytes(bytes.takeBytes(), flush: true);
      // Atomic: a reader never sees half a picture.
      await partial.rename(target.path);
      return target.path;
    } on Object catch (e) {
      debugPrint('HttpThumbnailStore: $videoId not saved (${e.runtimeType})');
      return null;
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  void close() => _client.close(force: true);
}
