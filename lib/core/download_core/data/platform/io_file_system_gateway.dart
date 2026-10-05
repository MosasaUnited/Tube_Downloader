import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';
import 'package:tube_downloader/core/download_core/data/platform/media_publisher.dart';
import 'package:tube_downloader/core/download_core/data/platform/volume_space_probe.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';

/// [FileSystemGateway] on `dart:io`.
///
/// Partial files live under Application Support (`work/<taskId>/`), never in
/// the user's folders; a finished file is moved into the save folder:
/// Settings' choice, else Downloads/Tube Downloader on desktop and the app's
/// Documents on iOS (shown in the Files app); on Android finished files go
/// through MediaStore to Movies / Music › Tube Downloader ([MediaPublisher]).
class IoFileSystemGateway implements FileSystemGateway {
  IoFileSystemGateway(
    this._settings, {
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? defaultSaveDirectory,
    this._probe = const PlatformVolumeSpaceProbe(),
    MediaPublisher? mediaPublisher,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _defaultSaveDirectory = defaultSaveDirectory ?? _platformSaveDirectory,
       // Android: finished files go to the public media folders.
       _mediaPublisher =
           mediaPublisher ??
           (Platform.isAndroid ? const ChannelMediaPublisher() : null);

  final SettingsRepo _settings;
  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _defaultSaveDirectory;
  final VolumeSpaceProbe _probe;
  final MediaPublisher? _mediaPublisher;

  static const appFolderName = 'Tube Downloader';

  static Future<Directory> _platformSaveDirectory() async {
    if (Platform.isMacOS || Platform.isWindows) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory(
          '${downloads.path}${Platform.pathSeparator}$appFolderName',
        );
      }
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> _workRoot() async => Directory(
    '${(await _supportDirectory()).path}${Platform.pathSeparator}work',
  );

  @override
  Future<String> workDir(String taskId) async {
    final dir = Directory(
      '${(await _workRoot()).path}${Platform.pathSeparator}$taskId',
    );
    await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<List<String>> workDirTaskIds() async {
    final root = await _workRoot();
    if (!root.existsSync()) return const [];
    return [
      await for (final entity in root.list())
        if (entity is Directory)
          entity.uri.pathSegments.where((s) => s.isNotEmpty).last,
    ];
  }

  @override
  Future<void> deleteWorkDir(String taskId) async {
    final dir = Directory(
      '${(await _workRoot()).path}${Platform.pathSeparator}$taskId',
    );
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  @override
  Future<int> fileLength(String path) async {
    final file = File(path);
    return file.existsSync() ? file.length() : 0;
  }

  @override
  Future<bool> exists(String path) async => File(path).existsSync();

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<Result<void>> deletePublished(String path) async {
    try {
      await deleteFile(path);
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  @override
  Future<Result<String>> publish({
    required String sourcePath,
    required String fileName,
    String? subDir,
  }) async {
    try {
      final saveRoot = _settings.current.saveDirectory;
      final media = _mediaPublisher;
      if (media != null && saveRoot == null) {
        return Result.success(
          await media.publish(
            sourcePath: sourcePath,
            fileName: fileName,
            subDir: subDir,
          ),
        );
      }
      var dir = saveRoot == null
          ? await _defaultSaveDirectory()
          : Directory(saveRoot);
      if (subDir != null) {
        dir = Directory('${dir.path}${Platform.pathSeparator}$subDir');
      }
      await dir.create(recursive: true);
      final target = _unusedPath(dir, fileName);
      await _move(File(sourcePath), target);
      return Result.success(target);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  /// Never overwrite: "Name.mp4", "Name (2).mp4", "Name (3).mp4"…
  static String _unusedPath(Directory dir, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    var path = '${dir.path}${Platform.pathSeparator}$fileName';
    for (var n = 2; File(path).existsSync(); n++) {
      path = '${dir.path}${Platform.pathSeparator}$stem ($n)$ext';
    }
    return path;
  }

  /// A rename is instant on one volume; across volumes (a save folder on
  /// another disk) it fails, so copy then delete.
  static Future<void> _move(File source, String target) async {
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      await source.delete();
    }
  }

  @override
  Future<int?> freeBytes() async => (await space())?.freeBytes;

  @override
  Future<StorageSpace?> space() async {
    final dir = await saveDirectory();
    return dir == null ? null : _probe.spaceOf(dir);
  }

  @override
  Future<String?> saveDirectory() async {
    final chosen = _settings.current.saveDirectory;
    if (chosen != null) return chosen;
    try {
      return (await _defaultSaveDirectory()).path;
    } on Object catch (e) {
      // Display only (Settings, the storage meter): unknown is fine.
      debugPrint('IoFileSystemGateway: no default folder (${e.runtimeType})');
      return null;
    }
  }
}
