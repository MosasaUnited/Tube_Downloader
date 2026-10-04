import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/error/result.dart';

/// How many requests went into the queue, and how many were already there.
class EnqueueSummary {
  const EnqueueSummary({required this.added, required this.skipped});
  final int added;
  final int skipped;
}

/// Adds downloads to the queue, skipping any video already queued with the
/// same format (the user pasted it twice, or retried from another screen).
class EnqueueDownloadsUseCase {
  EnqueueDownloadsUseCase(this._queue, this._repo);

  final DownloadQueueService _queue;
  final DownloadRepo _repo;

  Future<Result<EnqueueSummary>> call(
    List<DownloadRequest> requests, {
    DownloadGroup? group,
  }) async {
    final existing = await _repo.existingKeys(
      requests.map((r) => (r.media.videoId, r.format.key)),
    );
    final fresh = [
      for (final r in requests)
        if (!existing.contains('${r.media.videoId}|${r.format.key}')) r,
    ];
    final skipped = requests.length - fresh.length;
    if (fresh.isEmpty) {
      return Result.success(EnqueueSummary(added: 0, skipped: skipped));
    }
    final result = await _queue.enqueue(
      fresh,
      group: group?.copyWith(total: fresh.length),
    );
    return switch (result) {
      Success(:final data) => Result.success(
        EnqueueSummary(added: data.length, skipped: skipped),
      ),
      Failure(:final failure) => Result.failure(failure),
    };
  }
}
