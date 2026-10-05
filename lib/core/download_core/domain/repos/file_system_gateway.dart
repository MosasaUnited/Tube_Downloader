import 'package:tube_downloader/core/error/result.dart';

/// Every file-system operation the download core needs, so domain code
/// never touches `dart:io` (and tests use an in-memory fake).
abstract interface class FileSystemGateway {
  /// Folder for a task's partial files, created if missing.
  Future<String> workDir(String taskId);

  /// Task ids that have a work folder (for orphan cleanup).
  Future<List<String>> workDirTaskIds();
  Future<void> deleteWorkDir(String taskId);

  /// Length of [path] in bytes; 0 when it does not exist.
  Future<int> fileLength(String path);
  Future<bool> exists(String path);
  Future<void> deleteFile(String path);

  /// Deletes a finished file the user saved (Library › Delete); a file that
  /// is already gone counts as deleted.
  Future<Result<void>> deletePublished(String path);

  /// Moves a finished file into the save location under [fileName] (and
  /// [subDir]); never overwrites — a clash gets " (2)", " (3)"… Returns the
  /// final path.
  Future<Result<String>> publish({
    required String sourcePath,
    required String fileName,
    String? subDir,
  });

  /// Free space where downloads are saved; null when the platform can't say.
  Future<int?> freeBytes();
}
