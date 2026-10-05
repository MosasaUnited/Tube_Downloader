import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tube_downloader/core/download_core/data/platform/windows_disk_space.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';

/// Free / total bytes of the volume holding a path. Dart has no portable API:
/// macOS, iOS and Android answer over the Runner's
/// `com.tubedownloader.app/storage` channel; Windows is asked directly
/// (GetDiskFreeSpaceExW).
abstract interface class VolumeSpaceProbe {
  /// null when the platform can't say.
  Future<StorageSpace?> spaceOf(String path);
}

class PlatformVolumeSpaceProbe implements VolumeSpaceProbe {
  const PlatformVolumeSpaceProbe();

  static const _channel = MethodChannel('com.tubedownloader.app/storage');

  @override
  Future<StorageSpace?> spaceOf(String path) async {
    final existing = nearestExisting(path);
    try {
      if (Platform.isWindows) return windowsDiskSpace(existing);
      final values = await _channel.invokeMapMethod<String, int>('space', {
        'path': existing,
      });
      final free = values?['free'];
      final total = values?['total'];
      return free == null || total == null
          ? null
          : StorageSpace(freeBytes: free, totalBytes: total);
    } on MissingPluginException {
      return null; // Tests, or a Runner without the channel.
    } on Object catch (e) {
      debugPrint('VolumeSpaceProbe: ${e.runtimeType}');
      return null;
    }
  }

  /// The save folder may not exist before the first download: measure the
  /// closest folder above it that does.
  @visibleForTesting
  static String nearestExisting(String path) {
    var dir = Directory(path);
    while (!dir.existsSync() && dir.parent.path != dir.path) {
      dir = dir.parent;
    }
    return dir.path;
  }
}
