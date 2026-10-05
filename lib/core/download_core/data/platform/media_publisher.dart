import 'package:flutter/services.dart';

/// Moves a finished file into the device's public media folders (Android:
/// MediaStore — Movies or Music / Tube Downloader). Returns the new path.
abstract interface class MediaPublisher {
  Future<String> publish({
    required String sourcePath,
    required String fileName,
    String? subDir,
  });
}

/// The Runner's `com.tubedownloader.app/mediastore` channel
/// (MainActivity.kt).
class ChannelMediaPublisher implements MediaPublisher {
  const ChannelMediaPublisher();

  static const _channel = MethodChannel('com.tubedownloader.app/mediastore');

  static const _mime = {
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'm4a': 'audio/mp4',
    'mp3': 'audio/mpeg',
  };

  @override
  Future<String> publish({
    required String sourcePath,
    required String fileName,
    String? subDir,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final mime = _mime[ext] ?? 'application/octet-stream';
    final path = await _channel.invokeMethod<String>('publish', {
      'source': sourcePath,
      'name': fileName,
      'mime': mime,
      'audio': mime.startsWith('audio/'),
      'subDir': subDir,
    });
    if (path == null) throw StateError('MediaStore returned no path');
    return path;
  }
}
