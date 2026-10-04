import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';

/// Puts the queue back together after the app was killed mid-download.
/// Runs in bootstrap BEFORE the queue starts.
class RecoveryService {
  RecoveryService({required this._repo, required this._fs});

  final DownloadRepo _repo;
  final FileSystemGateway _fs;

  static const _interrupted = {
    TaskStatus.resolving,
    TaskStatus.downloadingVideo,
    TaskStatus.downloadingAudio,
    TaskStatus.merging,
    TaskStatus.converting,
  };

  /// Returns how many tasks were recovered.
  Future<int> run() async {
    final tasks = await _repo.tasksWithStatus(_interrupted);
    for (final task in tasks) {
      // The file on disk is the truth: checkpoints lag by up to 5 s.
      for (final leg in task.legs) {
        var length = await _fs.fileLength(leg.tmpPath);
        final total = leg.totalBytes;
        if (total != null && length > total) {
          await _fs.deleteFile(leg.tmpPath);
          length = 0;
        }
        await _repo.saveLeg(
          task.id,
          leg.copyWith(
            doneBytes: length,
            completed: total != null && length == total,
          ),
        );
      }
      // Back to the queue: downloads resume from the file length, and a task
      // whose legs are all on disk goes straight to FFmpeg again.
      await _repo.transition(
        task.id,
        TaskStatus.queued,
        event: EventType.resumed,
        eventArgs: {'recovered': true},
      );
    }

    // Work folders of tasks that are finished or gone.
    final live = (await _repo.tasksWithStatus({
      TaskStatus.queued,
      TaskStatus.paused,
      TaskStatus.failed,
      ..._interrupted,
    })).map((t) => t.id).toSet();
    for (final id in await _fs.workDirTaskIds()) {
      if (!live.contains(id)) await _fs.deleteWorkDir(id);
    }
    return tasks.length;
  }
}
